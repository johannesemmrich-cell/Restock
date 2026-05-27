import SwiftUI
import SwiftData

struct MenuPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]

    @AppStorage("menuPlanJSON") private var planJSON = ""
    @State private var meals: [String]
    @State private var addedCount = 0
    @State private var showConfirm = false
    @State private var showAddDay = false

    private let dayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let dayNamesFull = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    init() {
        let stored = UserDefaults.standard.string(forKey: "menuPlanJSON") ?? ""
        if let data = stored.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data), arr.count == 7 {
            _meals = State(initialValue: arr)
        } else {
            _meals = State(initialValue: Array(repeating: "", count: 7))
        }
    }

    private var plannedIndices: [Int] {
        (0..<7).filter { !meals[$0].trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if plannedIndices.isEmpty {
                        Label("Noch keine Tage geplant.", systemImage: "fork.knife")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(plannedIndices, id: \.self) { i in
                            HStack(spacing: 12) {
                                Text(dayNames[i])
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)
                                Text(meals[i])
                                    .font(.system(size: 15))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation { meals[i] = "" }
                                    savePlan()
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
                    Text("Bekannte Gerichte → Zutaten werden automatisch erkannt und zur Einkaufsliste hinzugefügt.")
                        .font(.caption)
                }

                let ingredients = allIngredients()
                if !ingredients.isEmpty {
                    Section("Erkannte Zutaten (\(ingredients.count))") {
                        ForEach(ingredients, id: \.self) { name in
                            Label(name, systemImage: "cart")
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .navigationTitle("Menüplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zur Liste") {
                        addToList()
                        showConfirm = true
                    }
                    .fontWeight(.semibold)
                    .disabled(allIngredients().isEmpty)
                }
            }
            .alert("Hinzugefügt", isPresented: $showConfirm) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(addedCount) Zutaten wurden zur Einkaufsliste hinzugefügt.")
            }
            .sheet(isPresented: $showAddDay) {
                AddDaySheet(meals: $meals, dayNames: dayNamesFull, onSave: savePlan)
            }
        }
        .devFeedback(context: "Menüplan")
    }

    private func allIngredients() -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for meal in meals where !meal.trimmingCharacters(in: .whitespaces).isEmpty {
            for ingredient in MealDatabase.ingredients(for: meal) {
                let key = ingredient.lowercased()
                if seen.insert(key).inserted { result.append(ingredient) }
            }
        }
        return result
    }

    private func addToList() {
        let ingredients = allIngredients()
        for name in ingredients {
            let category = AssignmentService.category(for: name)
            let store = AssignmentService.assign(itemName: name, to: activeStores, purchaseRecords: allRecords)
            context.insert(ShoppingItem(name: name, category: category, store: store))
        }
        addedCount = ingredients.count
        Haptics.success()
    }

    private func savePlan() {
        if let data = try? JSONEncoder().encode(meals),
           let str = String(data: data, encoding: .utf8) {
            planJSON = str
        }
    }
}

// MARK: - Add Day Sheet

private struct AddDaySheet: View {
    @Binding var meals: [String]
    let dayNames: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 0
    @State private var mealText = ""

    private var availableDays: [(index: Int, name: String)] {
        (0..<7).filter { meals[$0].trimmingCharacters(in: .whitespaces).isEmpty }
            .map { (index: $0, name: dayNames[$0]) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tag", selection: $selectedDay) {
                    ForEach(availableDays, id: \.index) { day in
                        Text(day.name).tag(day.index)
                    }
                }

                TextField("Gericht eingeben…", text: $mealText)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Tag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        meals[selectedDay] = mealText.trimmingCharacters(in: .whitespaces)
                        onSave()
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
