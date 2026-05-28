import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

struct MenuPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]

    @AppStorage("menuPlanJSON") private var planJSON = ""
    @AppStorage("menuIngredientsJSON") private var ingredientsJSON = ""

    @State private var meals: [String]
    @State private var ingredientsMap: [String: [String]]   // "0"…"6" → ingredient list
    @State private var loadingDays: Set<Int> = []
    @State private var addedCount = 0
    @State private var showConfirm = false
    @State private var showAddDay = false
    @State private var checkedIngredients: Set<String> = []

    private let dayNames     = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let dayNamesFull = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    init() {
        let mealStored = UserDefaults.standard.string(forKey: "menuPlanJSON") ?? ""
        if let data = mealStored.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data), arr.count == 7 {
            _meals = State(initialValue: arr)
        } else {
            _meals = State(initialValue: Array(repeating: "", count: 7))
        }

        let ingStored = UserDefaults.standard.string(forKey: "menuIngredientsJSON") ?? ""
        if let data = ingStored.data(using: .utf8),
           let map = try? JSONDecoder().decode([String: [String]].self, from: data) {
            _ingredientsMap = State(initialValue: map)
        } else {
            _ingredientsMap = State(initialValue: [:])
        }
    }

    // MARK: - Computed

    private var plannedIndices: [Int] {
        (0..<7).filter { !meals[$0].trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var allIngredients: [String] {
        var result: [String] = []
        var seen = Set<String>()
        for i in plannedIndices {
            for ing in ingredientsMap["\(i)"] ?? [] {
                if seen.insert(ing.lowercased()).inserted { result.append(ing) }
            }
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                mealsSection
                if !allIngredients.isEmpty { ingredientsSection }
            }
            .navigationTitle("Menüplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zur Liste") { addToList() }
                        .fontWeight(.semibold)
                        .disabled((allIngredients.filter { !checkedIngredients.contains($0.lowercased()) }.isEmpty) && loadingDays.isEmpty)
                }
            }
            .alert("Hinzugefügt", isPresented: $showConfirm) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(addedCount) Zutaten wurden zur Einkaufsliste hinzugefügt.")
            }
            .sheet(isPresented: $showAddDay) {
                AddDaySheet(meals: $meals, dayNames: dayNamesFull) { dayIndex, meal, manual in
                    meals[dayIndex] = meal
                    savePlan()
                    if !manual.isEmpty {
                        ingredientsMap["\(dayIndex)"] = manual
                        saveIngredients()
                    } else {
                        fetchIngredients(for: dayIndex, meal: meal)
                    }
                }
            }
        }
        .devFeedback(context: "Menüplan")
    }

    // MARK: - Meals section

    private var mealsSection: some View {
        Section {
            if plannedIndices.isEmpty {
                Label("Noch keine Tage geplant.", systemImage: "fork.knife")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(plannedIndices, id: \.self) { i in
                    dayRow(i)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    meals[i] = ""
                                    ingredientsMap.removeValue(forKey: "\(i)")
                                    loadingDays.remove(i)
                                }
                                savePlan()
                                saveIngredients()
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }

            if plannedIndices.count < 7 {
                Button {
                    showAddDay = true
                } label: {
                    Label("Tag hinzufügen", systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Diese Woche")
        } footer: {
            Text("Erkannte Zutaten können direkt zur Einkaufsliste hinzugefügt werden.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func dayRow(_ i: Int) -> some View {
        HStack(spacing: 12) {
            Text(dayNames[i])
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(meals[i])
                    .font(.system(size: 15))

                if loadingDays.contains(i) {
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.65)
                        Text("Zutaten werden erkannt…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else if let ings = ingredientsMap["\(i)"], !ings.isEmpty {
                    Text(ings.prefix(4).joined(separator: ", ") + (ings.count > 4 ? "…" : ""))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Keine Zutaten erkannt")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let ings = ingredientsMap["\(i)"], !ings.isEmpty {
                Text("\(ings.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.brand, in: Capsule())
            }
        }
    }

    // MARK: - Ingredients section

    private var ingredientsSection: some View {
        let unchecked = allIngredients.filter { !checkedIngredients.contains($0.lowercased()) }.count
        return Section {
            ForEach(allIngredients, id: \.self) { name in
                let isChecked = checkedIngredients.contains(name.lowercased())
                HStack(spacing: 12) {
                    Button {
                        if isChecked {
                            checkedIngredients.remove(name.lowercased())
                        } else {
                            checkedIngredients.insert(name.lowercased())
                        }
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isChecked ? .green : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)

                    Text(name)
                        .font(.system(size: 14))
                        .foregroundStyle(isChecked ? .secondary : .primary)
                        .strikethrough(isChecked, color: .secondary)
                }
            }
        } header: {
            HStack {
                Text("Erkannte Zutaten")
                Spacer()
                Text("\(unchecked) zur Liste")
                    .textCase(nil)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func fetchIngredients(for dayIndex: Int, meal: String) {
        loadingDays.insert(dayIndex)
        Task {
            let result = await MealIngredientService.shared.ingredients(for: meal)
            await MainActor.run {
                loadingDays.remove(dayIndex)
                if !result.names.isEmpty {
                    ingredientsMap["\(dayIndex)"] = result.names
                    saveIngredients()
                }
            }
        }
    }

    private func addToList() {
        let ingredients = allIngredients.filter { !checkedIngredients.contains($0.lowercased()) }
        for name in ingredients {
            let category = AssignmentService.category(for: name)
            let store = AssignmentService.assign(itemName: name, to: activeStores, purchaseRecords: allRecords)
            context.insert(ShoppingItem(name: name, category: category, store: store))
        }
        addedCount = ingredients.count
        checkedIngredients.removeAll()
        Haptics.success()
        showConfirm = true
    }

    private func savePlan() {
        if let data = try? JSONEncoder().encode(meals),
           let str = String(data: data, encoding: .utf8) {
            planJSON = str
        }
    }

    private func saveIngredients() {
        if let data = try? JSONEncoder().encode(ingredientsMap),
           let str = String(data: data, encoding: .utf8) {
            ingredientsJSON = str
        }
    }
}

// MARK: - Add Day Sheet

private struct AddDaySheet: View {
    @Binding var meals: [String]
    let dayNames: [String]
    let onSave: (_ dayIndex: Int, _ meal: String, _ manualIngredients: [String]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 0
    @State private var mealText = ""
    @State private var manualText = ""

    private var availableDays: [(index: Int, name: String)] {
        (0..<7).filter { meals[$0].trimmingCharacters(in: .whitespaces).isEmpty }
            .map { (index: $0, name: dayNames[$0]) }
    }

    private var manualIngredients: [String] {
        manualText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag & Mahlzeit") {
                    Picker("Tag", selection: $selectedDay) {
                        ForEach(availableDays, id: \.index) { day in
                            Text(day.name).tag(day.index)
                        }
                    }
                    TextField("Gericht eingeben…", text: $mealText)
                        .autocorrectionDisabled()
                }

                Section {
                    TextField("Mehl, Eier, Milch…", text: $manualText)
                        .autocorrectionDisabled()
                } header: {
                    Text("Zutaten (optional)")
                } footer: {
                    aiFootnote
                }
            }
            .navigationTitle("Tag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        onSave(selectedDay, mealText.trimmingCharacters(in: .whitespaces), manualIngredients)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(mealText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = availableDays.first { selectedDay = first.index }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var aiFootnote: some View {
        if MealIngredientService.isAIAvailable() {
            Label("Leer lassen — Apple Intelligence erkennt Zutaten automatisch.", systemImage: "apple.intelligence")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Optional: Zutaten kommagetrennt eingeben (Apple Intelligence nicht verfügbar).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Meal Database

enum MealDatabase {
    private static let db: [String: [String]] = [
        "pasta": ["Nudeln", "Tomatensoße", "Parmesan", "Knoblauch", "Olivenöl"],
        "spaghetti": ["Spaghetti", "Tomatensoße", "Parmesan", "Knoblauch", "Olivenöl"],
        "bolognese": ["Hackfleisch", "Spaghetti", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl", "Parmesan"],
        "pasta bolognese": ["Hackfleisch", "Nudeln", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl"],
        "carbonara": ["Spaghetti", "Speck", "Eier", "Parmesan", "Sahne"],
        "lasagne": ["Hackfleisch", "Lasagneplatten", "Tomatensoße", "Béchamelsauce", "Käse", "Zwiebeln"],
        "pizza": ["Pizzateig", "Tomatensoße", "Mozzarella", "Oregano"],
        "schnitzel": ["Schnitzel", "Eier", "Semmelbrösel", "Zitrone", "Kartoffeln"],
        "wiener schnitzel": ["Kalbsschnitzel", "Eier", "Semmelbrösel", "Zitrone", "Kartoffeln"],
        "braten": ["Schweinebraten", "Möhren", "Sellerie", "Zwiebeln", "Kartoffeln", "Brühe"],
        "rinderbraten": ["Rinderbraten", "Möhren", "Sellerie", "Zwiebeln", "Rotwein", "Brühe"],
        "gulasch": ["Rindfleisch", "Zwiebeln", "Paprikapulver", "Tomatenmark", "Brühe", "Kartoffeln"],
        "hähnchen": ["Hähnchenbrust", "Knoblauch", "Olivenöl", "Rosmarin", "Kartoffeln"],
        "hühnchen": ["Hähnchenbrust", "Knoblauch", "Olivenöl", "Kräuter"],
        "chili": ["Hackfleisch", "Kidneybohnen", "Tomaten", "Zwiebeln", "Chili", "Mais"],
        "chili con carne": ["Hackfleisch", "Kidneybohnen", "Tomaten", "Zwiebeln", "Chili", "Mais"],
        "curry": ["Hähnchenbrust", "Kokosmilch", "Currypaste", "Reis", "Paprika", "Zwiebeln"],
        "risotto": ["Risottoreis", "Brühe", "Parmesan", "Butter", "Zwiebeln", "Weißwein"],
        "steak": ["Rindersteak", "Butter", "Rosmarin", "Knoblauch", "Kartoffeln"],
        "burger": ["Hackfleisch", "Burger Buns", "Salat", "Tomaten", "Käse", "Ketchup", "Gurken"],
        "lachs": ["Lachsfilet", "Zitrone", "Dill", "Butter", "Kartoffeln"],
        "lachsfilet": ["Lachsfilet", "Zitrone", "Dill", "Butter"],
        "fisch": ["Fischfilet", "Zitrone", "Butter", "Kartoffeln"],
        "suppe": ["Brühe", "Möhren", "Sellerie", "Zwiebeln", "Nudeln"],
        "gemüsesuppe": ["Möhren", "Sellerie", "Zwiebeln", "Brühe", "Erbsen"],
        "tomatensuppe": ["Tomaten", "Zwiebeln", "Knoblauch", "Brühe", "Sahne"],
        "pfannkuchen": ["Mehl", "Eier", "Milch", "Butter", "Zucker"],
        "pancakes": ["Mehl", "Eier", "Milch", "Butter", "Backpulver", "Zucker"],
        "rührei": ["Eier", "Butter", "Schnittlauch", "Salz"],
        "spiegelei": ["Eier", "Butter", "Salz"],
        "omelette": ["Eier", "Butter", "Käse", "Schnittlauch"],
        "sandwich": ["Toastbrot", "Aufschnitt", "Käse", "Salat", "Tomate", "Butter"],
        "toast": ["Toastbrot", "Butter", "Aufschnitt", "Käse"],
        "salat": ["Salat", "Tomaten", "Gurken", "Olivenöl", "Essig"],
        "caesar salad": ["Römersalat", "Parmesan", "Croutons", "Caesar Dressing", "Hähnchenbrust"],
        "wraps": ["Tortillas", "Hähnchenbrust", "Salat", "Paprika", "Joghurt"],
        "tacos": ["Tacos", "Hackfleisch", "Käse", "Salat", "Tomate", "Sauerrahm"],
        "flammkuchen": ["Flammkuchenteig", "Crème fraîche", "Speck", "Zwiebeln"],
        "käsespätzle": ["Spätzle", "Käse", "Zwiebeln", "Butter"],
        "kartoffelsuppe": ["Kartoffeln", "Brühe", "Speck", "Zwiebeln", "Sahne"],
        "erbsensuppe": ["Erbsen", "Brühe", "Speck", "Kartoffeln", "Zwiebeln"],
        "linsensuppe": ["Linsen", "Brühe", "Möhren", "Sellerie", "Zwiebeln", "Speck"],
        "reis": ["Reis", "Butter", "Salz"],
        "gebratener reis": ["Reis", "Eier", "Möhren", "Erbsen", "Sojasoße", "Öl"],
        "wrap": ["Tortillas", "Salat", "Tomate", "Käse"],
    ]

    static func ingredients(for meal: String) -> [String] {
        let key = meal.trimmingCharacters(in: .whitespaces).lowercased()
        if let exact = db[key] { return exact }
        for (dbKey, value) in db where key.contains(dbKey) || dbKey.contains(key) {
            return value
        }
        return []
    }
}
