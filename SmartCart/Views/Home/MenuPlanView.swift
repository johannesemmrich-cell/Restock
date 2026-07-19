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
    @AppStorage("savedRecipesJSON") private var savedRecipesJSON = ""

    @State private var meals: [String]
    @State private var ingredientsMap: [String: [String]]
    @State private var loadingDays: Set<Int> = []
    @State private var addedCount = 0
    @State private var showConfirm = false
    @State private var showAddDay = false
    @State private var checkedIngredients: Set<String> = []
    @State private var savedRecipeToast: String? = nil
    @State private var expandedDays: Set<Int> = []
    @State private var fetchTasks: [Int: Task<Void, Never>] = [:]
    @State private var targetStore: Store?

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

    // MARK: - Saved recipes helpers

    private var savedRecipes: [SavedRecipe] {
        guard let data = savedRecipesJSON.data(using: .utf8),
              let recipes = try? JSONDecoder().decode([SavedRecipe].self, from: data)
        else { return [] }
        return recipes.sorted {
            if $0.usageCount != $1.usageCount { return $0.usageCount > $1.usageCount }
            return ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
    }

    private func persistSavedRecipes(_ recipes: [SavedRecipe]) {
        if let data = try? JSONEncoder().encode(recipes),
           let str = String(data: data, encoding: .utf8) {
            savedRecipesJSON = str
        }
    }

    private func saveRecipe(dayIndex: Int) {
        let meal = meals[dayIndex].trimmingCharacters(in: .whitespaces)
        let ings = ingredientsMap["\(dayIndex)"] ?? []
        guard !meal.isEmpty, !ings.isEmpty else { return }
        var recipes = savedRecipes
        guard !recipes.contains(where: { $0.name.lowercased() == meal.lowercased() }) else {
            savedRecipeToast = "Bereits gespeichert"
            return
        }
        recipes.append(SavedRecipe(name: meal, ingredients: ings))
        persistSavedRecipes(recipes)
        Haptics.success()
        savedRecipeToast = "\"\(meal)\" gespeichert"
    }

    private func deleteSavedRecipe(_ recipe: SavedRecipe) {
        var recipes = savedRecipes
        recipes.removeAll { $0.id == recipe.id }
        persistSavedRecipes(recipes)
    }

    private func recordUsage(_ recipe: SavedRecipe) {
        var recipes = savedRecipes
        if let idx = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[idx].usageCount += 1
            recipes[idx].lastUsed = Date()
            persistSavedRecipes(recipes)
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
                targetStoreSection
                mealsSection
                savedRecipesSection
            }
            .navigationTitle("Menüplan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Schließen").toolbarChip()
                    }
                    .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { addToList() } label: {
                        Text("Zur Liste").toolbarChip(prominent: true)
                    }
                    .buttonStyle(.pressable)
                    .disabled(allIngredients.filter { !checkedIngredients.contains($0.lowercased()) }.isEmpty && loadingDays.isEmpty)
                }
            }
            .alert("Hinzugefügt", isPresented: $showConfirm) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(addedCount) Zutaten wurden zur Einkaufsliste hinzugefügt.")
            }
            .sheet(isPresented: $showAddDay) {
                AddDaySheet(
                    meals: $meals,
                    dayNames: dayNamesFull,
                    savedRecipes: savedRecipes
                ) { dayIndex, meal, manual, usedRecipe in
                    meals[dayIndex] = meal
                    savePlan()
                    if let recipe = usedRecipe {
                        ingredientsMap["\(dayIndex)"] = recipe.ingredients
                        saveIngredients()
                        recordUsage(recipe)
                        expandedDays.insert(dayIndex)
                    } else if !manual.isEmpty {
                        ingredientsMap["\(dayIndex)"] = manual
                        saveIngredients()
                        expandedDays.insert(dayIndex)
                    } else {
                        fetchIngredients(for: dayIndex, meal: meal)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = savedRecipeToast {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { savedRecipeToast = nil }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: savedRecipeToast)
            .onDisappear {
                for task in fetchTasks.values { task.cancel() }
                fetchTasks.removeAll()
            }
        }
        .devFeedback(context: "Menüplan")
    }

    // MARK: - Target store section

    private var targetStoreSection: some View {
        Section {
            Picker(selection: $targetStore) {
                Text("Automatisch zuordnen").tag(nil as Store?)
                ForEach(activeStores) { store in
                    Text("\(store.emoji) \(store.name)").tag(store as Store?)
                }
            } label: {
                Label("Ziel-Liste", systemImage: "list.bullet")
                    .font(.system(size: 15))
            }
            .pickerStyle(.menu)
        }
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
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation { saveRecipe(dayIndex: i) }
                            } label: {
                                Label("Speichern", systemImage: "bookmark.fill")
                            }
                            .tint(Color.accent)
                        }
                }
            }

            if plannedIndices.count < 7 {
                Button {
                    showAddDay = true
                } label: {
                    Label("Tag hinzufügen", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accent)
                }
            }
        } header: {
            Text("Diese Woche")
        } footer: {
            Text("Nach links wischen → löschen. Nach rechts wischen → Rezept speichern.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func dayRow(_ i: Int) -> some View {
        let ings = ingredientsMap["\(i)"] ?? []
        let isLoading = loadingDays.contains(i)
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedDays.contains(i) },
                set: { if $0 { expandedDays.insert(i) } else { expandedDays.remove(i) } }
            )
        ) {
            if isLoading {
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.65)
                    Text("Zutaten werden erkannt…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if ings.isEmpty {
                Text("Keine Zutaten erkannt")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                // Index-basierte Identität statt id: \.self — ein vom User doppelt getippter
                // Zutatenname (z. B. "Zwiebeln, Mehl, Zwiebeln") würde sonst zwei ForEach-Zeilen
                // mit identischer Identität erzeugen, was bei der animierten Swipe-/Expand-Logik
                // dieser Zeile zu einem echten Absturz führen kann.
                ForEach(Array(ings.enumerated()), id: \.offset) { _, name in
                    ingredientRow(name)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(dayNames[i])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                Text(meals[i])
                    .font(.system(size: 15))
                Spacer()
                if !ings.isEmpty {
                    Text("\(ings.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.onButton)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accent, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                } else if isLoading {
                    ProgressView().scaleEffect(0.65)
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientRow(_ name: String) -> some View {
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
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isChecked ? Color.accent : Color.hairlineStrong)
            }
            .buttonStyle(.pressable)
            Text(name)
                .font(.system(size: 14))
                .foregroundStyle(isChecked ? .secondary : .primary)
                .strikethrough(isChecked, color: .secondary)
            Spacer()
            if let store = resolvedStore(for: name) {
                Text(store.emoji)
                    .font(.system(size: 13))
            }
        }
    }


    // MARK: - Saved recipes section

    private var savedRecipesSection: some View {
        Section {
            if savedRecipes.isEmpty {
                Text("Noch keine Rezepte gespeichert. Gericht im Wochenplan nach rechts wischen \u{2192} \"Speichern\".")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(savedRecipes) { recipe in
                    savedRecipeRow(recipe)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSavedRecipe(recipe)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }
        } header: {
            HStack {
                Text("Gespeicherte Rezepte")
                Spacer()
                if !savedRecipes.isEmpty {
                    Text("\(savedRecipes.count)")
                        .textCase(nil)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !savedRecipes.isEmpty {
                Text("Tippe auf \"+ Liste\" um alle Zutaten direkt einzukaufen. Nach links wischen zum L\u{00F6}schen.")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func savedRecipeRow(_ recipe: SavedRecipe) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(recipe.name)
                        .font(.system(size: 15, weight: .medium))
                    if recipe.usageCount > 0 {
                        Text("\(recipe.usageCount)×")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(Color.accent.opacity(0.4)))
                    }
                }
                Text(recipe.ingredients.prefix(4).joined(separator: ", ") + (recipe.ingredients.count > 4 ? "…" : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                addRecipeToList(recipe)
            } label: {
                Text("+ Liste")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.onButton)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: RCRadius.tag))
            }
            .buttonStyle(.pressable)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func fetchIngredients(for dayIndex: Int, meal: String) {
        fetchTasks[dayIndex]?.cancel()
        loadingDays.insert(dayIndex)
        expandedDays.insert(dayIndex)
        fetchTasks[dayIndex] = Task {
            let result = await MealIngredientService.shared.ingredients(for: meal)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loadingDays.remove(dayIndex)
                fetchTasks.removeValue(forKey: dayIndex)
                if !result.names.isEmpty {
                    ingredientsMap["\(dayIndex)"] = result.names
                    saveIngredients()
                }
            }
        }
    }

    private func resolvedStore(for name: String) -> Store? {
        // targetStore kann eine ungültig gewordene Referenz sein, wenn der Store währenddessen
        // anderswo gelöscht wurde (z. B. Sync-Merge einer geteilten Liste) — nur verwenden, wenn
        // er noch tatsächlich in den aktuell aktiven Stores auftaucht.
        if let targetStore, activeStores.contains(where: { $0.persistentModelID == targetStore.persistentModelID }) {
            return targetStore
        }
        return AssignmentService.assign(itemName: name, to: activeStores, purchaseRecords: allRecords) ?? activeStores.first
    }

    private func addToList() {
        let ingredients = allIngredients.filter { !checkedIngredients.contains($0.lowercased()) }
        var touchedStores: [Store?] = []
        for name in ingredients {
            let category = AssignmentService.category(for: name)
            let store = resolvedStore(for: name)
            context.insert(ShoppingItem(name: name, category: category, store: store))
            touchedStores.append(store)
        }
        addedCount = ingredients.count
        checkedIngredients.removeAll()
        Haptics.success()
        SyncCoordinator.shared.pushInBackground(touchedStores)
        showConfirm = true
    }

    private func addRecipeToList(_ recipe: SavedRecipe) {
        var touchedStores: [Store?] = []
        for name in recipe.ingredients {
            let category = AssignmentService.category(for: name)
            let store = resolvedStore(for: name)
            context.insert(ShoppingItem(name: name, category: category, store: store))
            touchedStores.append(store)
        }
        recordUsage(recipe)
        addedCount = recipe.ingredients.count
        Haptics.success()
        SyncCoordinator.shared.pushInBackground(touchedStores)
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

// MARK: - Saved Recipe Model

struct SavedRecipe: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var ingredients: [String]
    var usageCount: Int
    var lastUsed: Date?

    init(name: String, ingredients: [String]) {
        self.id = UUID()
        self.name = name
        self.ingredients = ingredients
        self.usageCount = 0
        self.lastUsed = nil
    }
}

// MARK: - Add Day Sheet

private struct AddDaySheet: View {
    @Binding var meals: [String]
    let dayNames: [String]
    let savedRecipes: [SavedRecipe]
    let onSave: (_ dayIndex: Int, _ meal: String, _ manualIngredients: [String], _ recipe: SavedRecipe?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 0
    @State private var mealText = ""
    @State private var manualText = ""
    @State private var selectedRecipe: SavedRecipe? = nil
    @State private var showRecipePicker = false

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
                        .onChange(of: mealText) { _, _ in
                            // Clear recipe selection if user types a different name
                            if let r = selectedRecipe, mealText != r.name {
                                selectedRecipe = nil
                            }
                        }
                }

                if !savedRecipes.isEmpty {
                    Section {
                        Button {
                            showRecipePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Color.accent)
                                if let recipe = selectedRecipe {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recipe.name)
                                            .foregroundStyle(.primary)
                                        Text("\(recipe.ingredients.count) Zutaten")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Aus gespeichertem Rezept…")
                                        .foregroundStyle(Color.accent)
                                }
                                Spacer()
                                if selectedRecipe != nil {
                                    Button {
                                        selectedRecipe = nil
                                        manualText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color(.systemGray3))
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    } header: {
                        Text("Gespeicherte Rezepte")
                    }
                }

                if selectedRecipe == nil {
                    Section {
                        TextField("Mehl, Eier, Milch…", text: $manualText)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Zutaten (optional)")
                    } footer: {
                        aiFootnote
                    }
                } else if let recipe = selectedRecipe {
                    Section {
                        ForEach(recipe.ingredients.prefix(6), id: \.self) { ing in
                            Text(ing).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                        if recipe.ingredients.count > 6 {
                            Text("+ \(recipe.ingredients.count - 6) weitere")
                                .font(.system(size: 13)).foregroundStyle(.tertiary)
                        }
                    } header: {
                        Text("Zutaten aus Rezept")
                    }
                }
            }
            .navigationTitle("Tag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                        .buttonStyle(.pressable)
}
                ChipToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(selectedDay, mealText.trimmingCharacters(in: .whitespaces), manualIngredients, selectedRecipe)
                        dismiss()
                    } label: {
                        Text("Hinzufügen").toolbarChip(prominent: true)
                    }
                    .buttonStyle(.pressable)
                    .disabled(mealText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = availableDays.first { selectedDay = first.index }
            }
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerSheet(recipes: savedRecipes) { recipe in
                    selectedRecipe = recipe
                    mealText = recipe.name
                    showRecipePicker = false
                }
            }
        }
        .presentationDetents([.medium, .large])
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

// MARK: - Recipe Picker Sheet

private struct RecipePickerSheet: View {
    let recipes: [SavedRecipe]
    let onSelect: (SavedRecipe) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                Button {
                    Haptics.impact(.light)
                    onSelect(recipe)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recipe.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            if recipe.usageCount > 0 {
                                Text("\(recipe.usageCount)× verwendet")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(recipe.ingredients.prefix(5).joined(separator: ", ") + (recipe.ingredients.count > 5 ? "…" : ""))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .navigationTitle("Rezept auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                        .buttonStyle(.pressable)
}
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Meal Database

enum MealDatabase {
    private static let db: [String: [String]] = [
        // Pasta & Italienisch
        "pasta": ["Nudeln", "Tomatensoße", "Parmesan", "Knoblauch", "Olivenöl"],
        "spaghetti": ["Spaghetti", "Tomatensoße", "Parmesan", "Knoblauch", "Olivenöl"],
        "bolognese": ["Hackfleisch", "Spaghetti", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl", "Parmesan"],
        "pasta bolognese": ["Hackfleisch", "Nudeln", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl"],
        "carbonara": ["Spaghetti", "Guanciale", "Eier", "Pecorino", "Pfeffer"],
        "lasagne": ["Hackfleisch", "Lasagneplatten", "Tomatensoße", "Béchamelsauce", "Käse", "Zwiebeln"],
        "pizza": ["Pizzateig", "Tomatensoße", "Mozzarella", "Oregano"],
        "pesto pasta": ["Nudeln", "Basilikum", "Pinienkerne", "Parmesan", "Olivenöl", "Knoblauch"],
        "aglio e olio": ["Spaghetti", "Knoblauch", "Olivenöl", "Chili", "Petersilie"],
        "pasta arrabiata": ["Penne", "Tomaten", "Knoblauch", "Chili", "Olivenöl"],
        "gnocchi": ["Kartoffeln", "Mehl", "Eier", "Butter", "Salbei"],
        "gnocchi mit salbeibutter": ["Gnocchi", "Butter", "Salbei", "Parmesan"],
        "risotto": ["Risottoreis", "Brühe", "Parmesan", "Butter", "Zwiebeln", "Weißwein"],
        "pilzrisotto": ["Risottoreis", "Champignons", "Brühe", "Parmesan", "Butter", "Zwiebeln", "Weißwein"],
        "ravioli": ["Ravioli", "Butter", "Salbei", "Parmesan"],
        "tortellini": ["Tortellini", "Sahne", "Schinken", "Parmesan"],
        "flammkuchen": ["Flammkuchenteig", "Crème fraîche", "Speck", "Zwiebeln"],
        "tiramisu": ["Löffelbiskuits", "Mascarpone", "Eier", "Zucker", "Espresso", "Kakao"],
        // Fleisch & Klassiker
        "schnitzel": ["Schnitzel", "Eier", "Semmelbrösel", "Zitrone", "Kartoffeln"],
        "wiener schnitzel": ["Kalbsschnitzel", "Eier", "Semmelbrösel", "Zitrone", "Kartoffeln"],
        "braten": ["Schweinebraten", "Möhren", "Sellerie", "Zwiebeln", "Kartoffeln", "Brühe"],
        "rinderbraten": ["Rinderbraten", "Möhren", "Sellerie", "Zwiebeln", "Rotwein", "Brühe"],
        "sauerbraten": ["Rindfleisch", "Rotweinessig", "Zwiebeln", "Möhren", "Gewürze", "Kartoffelknödel"],
        "rouladen": ["Rindfleischrouladen", "Senf", "Speck", "Gurken", "Zwiebeln", "Brühe", "Kartoffeln"],
        "königsberger klopse": ["Hackfleisch", "Brötchen", "Eier", "Zwiebeln", "Kapern", "Sahne", "Brühe"],
        "kassler": ["Kassler", "Sauerkraut", "Kartoffeln", "Senf"],
        "gulasch": ["Rindfleisch", "Zwiebeln", "Paprikapulver", "Tomatenmark", "Brühe", "Kartoffeln"],
        "hähnchen": ["Hähnchenbrust", "Knoblauch", "Olivenöl", "Rosmarin", "Kartoffeln"],
        "hühnchen": ["Hähnchenbrust", "Knoblauch", "Olivenöl", "Kräuter"],
        "steak": ["Rindersteak", "Butter", "Rosmarin", "Knoblauch", "Kartoffeln"],
        "burger": ["Hackfleisch", "Burger Buns", "Salat", "Tomaten", "Käse", "Ketchup", "Gurken"],
        "bratwurst": ["Bratwurst", "Senf", "Sauerkraut", "Brötchen"],
        "schweinshaxe": ["Schweinshaxe", "Bier", "Kartoffelknödel", "Sauerkraut"],
        "weißwurst": ["Weißwurst", "Süßer Senf", "Brezeln"],
        "grünkohl": ["Grünkohl", "Kassler", "Mettwurst", "Kartoffeln", "Senf"],
        // Fisch & Meeresfrüchte
        "lachs": ["Lachsfilet", "Zitrone", "Dill", "Butter", "Kartoffeln"],
        "lachsfilet": ["Lachsfilet", "Zitrone", "Dill", "Butter"],
        "fisch": ["Fischfilet", "Zitrone", "Butter", "Kartoffeln"],
        "matjes": ["Matjesfilet", "Äpfel", "Zwiebeln", "Sahne", "Gurken"],
        "garnelen pfanne": ["Garnelen", "Knoblauch", "Butter", "Chili", "Zitrone", "Petersilie"],
        // Asiatisch
        "curry": ["Hähnchenbrust", "Kokosmilch", "Currypaste", "Reis", "Paprika", "Zwiebeln"],
        "chicken tikka masala": ["Hähnchenbrust", "Joghurt", "Tomaten", "Sahne", "Gewürze", "Zwiebeln", "Knoblauch", "Ingwer", "Naan"],
        "dal": ["Rote Linsen", "Tomaten", "Zwiebeln", "Knoblauch", "Ingwer", "Kurkuma", "Kreuzkümmel", "Reis"],
        "palak paneer": ["Paneer", "Spinat", "Zwiebeln", "Tomaten", "Sahne", "Gewürze", "Naan"],
        "biryani": ["Basmatireis", "Hähnchen", "Zwiebeln", "Joghurt", "Safran", "Gewürze"],
        "korma": ["Hähnchen", "Kokosmilch", "Cashews", "Zwiebeln", "Gewürze", "Reis", "Naan"],
        "ramen": ["Ramen-Nudeln", "Brühe", "Eier", "Nori", "Frühlingszwiebeln", "Schweinefleisch", "Maiskolben"],
        "miso suppe": ["Miso-Paste", "Tofu", "Wakame", "Dashi", "Frühlingszwiebeln"],
        "pad thai": ["Reisnudeln", "Garnelen", "Eier", "Sojasprossen", "Frühlingszwiebeln", "Erdnüsse", "Fischsauce"],
        "nasi goreng": ["Reis", "Eier", "Sojasoße", "Kecap Manis", "Chili", "Knoblauch", "Garnelen"],
        "gyoza": ["Hackfleisch", "Chinakohl", "Gyoza-Teig", "Ingwer", "Knoblauch", "Sojasoße"],
        "frühlingsrollen": ["Frühlingsrollenteig", "Hackfleisch", "Glasnudeln", "Kohl", "Möhren", "Sojasoße"],
        "wok gemüse": ["Paprika", "Brokkoli", "Möhren", "Zuckerschoten", "Sojasoße", "Ingwer", "Reis"],
        "teriyaki hähnchen": ["Hähnchenbrust", "Sojasoße", "Mirin", "Sake", "Zucker", "Reis"],
        "bibimbap": ["Reis", "Spinat", "Möhren", "Zucchini", "Rindfleisch", "Eier", "Gochujang", "Sesamöl"],
        "sushi": ["Sushi-Reis", "Nori", "Lachs", "Gurke", "Avocado", "Reisessig"],
        "gebratener reis": ["Reis", "Eier", "Möhren", "Erbsen", "Sojasoße", "Öl"],
        // Mexikanisch
        "chili": ["Hackfleisch", "Kidneybohnen", "Tomaten", "Zwiebeln", "Chili", "Mais"],
        "chili con carne": ["Hackfleisch", "Kidneybohnen", "Tomaten", "Zwiebeln", "Chili", "Mais"],
        "tacos": ["Taco-Schalen", "Hackfleisch", "Käse", "Salat", "Tomate", "Sauerrahm"],
        "wraps": ["Tortillas", "Hähnchenbrust", "Salat", "Paprika", "Joghurt"],
        "wrap": ["Tortillas", "Salat", "Tomate", "Käse"],
        "burrito": ["Tortillas", "Reis", "Bohnen", "Hackfleisch", "Käse", "Sauerrahm", "Salsa"],
        "quesadilla": ["Tortillas", "Käse", "Hähnchen", "Paprika", "Zwiebeln", "Sauerrahm"],
        "fajitas": ["Hähnchenbrust", "Paprika", "Zwiebeln", "Tortillas", "Sauerrahm", "Guacamole"],
        "nachos": ["Nachos", "Käsesoße", "Jalapeños", "Sauerrahm", "Guacamole", "Salsa"],
        "guacamole": ["Avocados", "Limette", "Zwiebeln", "Tomaten", "Koriander", "Chili"],
        // Suppen
        "suppe": ["Brühe", "Möhren", "Sellerie", "Zwiebeln", "Nudeln"],
        "gemüsesuppe": ["Möhren", "Sellerie", "Zwiebeln", "Brühe", "Erbsen"],
        "tomatensuppe": ["Tomaten", "Zwiebeln", "Knoblauch", "Brühe", "Sahne"],
        "kartoffelsuppe": ["Kartoffeln", "Brühe", "Speck", "Zwiebeln", "Sahne"],
        "erbsensuppe": ["Erbsen", "Brühe", "Speck", "Kartoffeln", "Zwiebeln"],
        "linsensuppe": ["Linsen", "Brühe", "Möhren", "Sellerie", "Zwiebeln", "Speck"],
        "kürbissuppe": ["Hokkaido-Kürbis", "Brühe", "Sahne", "Ingwer", "Zwiebeln", "Kokosmilch"],
        "zwiebelsuppe": ["Zwiebeln", "Brühe", "Weißwein", "Baguette", "Gruyère", "Butter"],
        "minestrone": ["Möhren", "Sellerie", "Zucchini", "Tomaten", "Kidneybohnen", "Nudeln", "Brühe", "Parmesan"],
        "hühnersuppe": ["Hähnchen", "Brühe", "Möhren", "Sellerie", "Nudeln", "Zwiebeln"],
        "rote bete suppe": ["Rote Bete", "Brühe", "Sahne", "Apfel", "Zwiebeln"],
        // Vegetarisch & Vegan
        "falafel": ["Kichererbsen", "Zwiebeln", "Knoblauch", "Kreuzkümmel", "Koriander", "Mehl"],
        "hummus": ["Kichererbsen", "Tahini", "Zitrone", "Knoblauch", "Olivenöl"],
        "tofu pfanne": ["Tofu", "Paprika", "Brokkoli", "Sojasoße", "Ingwer", "Sesamöl", "Reis"],
        "quinoa bowl": ["Quinoa", "Avocado", "Kichererbsen", "Gurke", "Tomaten", "Spinat", "Zitrone"],
        "buddha bowl": ["Süßkartoffeln", "Kichererbsen", "Avocado", "Spinat", "Quinoa", "Tahini"],
        "vegane bolognese": ["Linsen", "Nudeln", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl", "Hefeflocken"],
        "ratatouille": ["Zucchini", "Aubergine", "Paprika", "Tomaten", "Zwiebeln", "Knoblauch", "Olivenöl", "Kräuter"],
        "shakshuka": ["Eier", "Tomaten", "Paprika", "Zwiebeln", "Knoblauch", "Kreuzkümmel", "Paprikapulver"],
        "käsespätzle": ["Spätzle", "Bergkäse", "Zwiebeln", "Butter"],
        // Salate
        "salat": ["Salat", "Tomaten", "Gurken", "Olivenöl", "Essig"],
        "caesar salad": ["Römersalat", "Parmesan", "Croutons", "Caesar Dressing", "Hähnchenbrust"],
        "griechischer salat": ["Tomaten", "Gurken", "Oliven", "Feta", "Paprika", "Zwiebeln", "Olivenöl"],
        // Frühstück & Brunch
        "pfannkuchen": ["Mehl", "Eier", "Milch", "Butter", "Zucker"],
        "pancakes": ["Mehl", "Eier", "Milch", "Butter", "Backpulver", "Zucker"],
        "rührei": ["Eier", "Butter", "Schnittlauch", "Salz"],
        "spiegelei": ["Eier", "Butter", "Salz"],
        "omelette": ["Eier", "Butter", "Käse", "Schnittlauch"],
        "müsli": ["Haferflocken", "Milch", "Banane", "Beeren", "Nüsse", "Honig"],
        "porridge": ["Haferflocken", "Milch", "Banane", "Zimt", "Honig"],
        "haferbrei": ["Haferflocken", "Milch", "Zucker", "Zimt"],
        "overnight oats": ["Haferflocken", "Milch", "Joghurt", "Chiasamen", "Früchte"],
        "granola": ["Haferflocken", "Honig", "Nüsse", "Kokosöl", "Trockenfrüchte"],
        "avocado toast": ["Brot", "Avocado", "Zitrone", "Chili", "Eier"],
        "french toast": ["Toastbrot", "Eier", "Milch", "Zimt", "Butter", "Ahornsirup"],
        "smoothie bowl": ["Gefrorene Beeren", "Banane", "Joghurt", "Granola", "Früchte"],
        "sandwich": ["Toastbrot", "Aufschnitt", "Käse", "Salat", "Tomate", "Butter"],
        "toast": ["Toastbrot", "Butter", "Aufschnitt", "Käse"],
        // Backen
        "brot": ["Mehl", "Hefe", "Wasser", "Salz"],
        "brötchen": ["Mehl", "Hefe", "Wasser", "Salz", "Butter"],
        "bananenbrot": ["Bananen", "Mehl", "Eier", "Butter", "Zucker", "Backpulver"],
        "muffins": ["Mehl", "Eier", "Butter", "Zucker", "Backpulver", "Milch"],
        "apfelkuchen": ["Äpfel", "Mehl", "Eier", "Butter", "Zucker", "Zimt", "Backpulver"],
        "käsekuchen": ["Quark", "Eier", "Zucker", "Butter", "Mehl", "Backpulver"],
        "brownies": ["Schokolade", "Butter", "Eier", "Zucker", "Mehl", "Kakao"],
        "cookies": ["Mehl", "Butter", "Zucker", "Eier", "Schokoladenstücke", "Backpulver"],
        "waffel": ["Mehl", "Eier", "Milch", "Butter", "Zucker", "Backpulver"],
        "waffeln": ["Mehl", "Eier", "Milch", "Butter", "Zucker", "Backpulver"],
        // Weitere Klassiker
        "reis": ["Reis", "Butter", "Salz"],
        "paella": ["Paellareis", "Hähnchen", "Garnelen", "Paprika", "Tomaten", "Safran", "Brühe", "Erbsen"],
        "moussaka": ["Auberginen", "Hackfleisch", "Tomaten", "Béchamelsauce", "Zwiebeln", "Zimt"],
        "döner bowl": ["Hähnchen", "Joghurt", "Gurken", "Tomaten", "Zwiebeln", "Fladenbrot", "Salat"],
        "poke bowl": ["Thunfisch", "Reis", "Avocado", "Gurke", "Edamame", "Sojasoße", "Sesamöl"],
    ]

    static func ingredients(for meal: String) -> [String] {
        let key = meal.trimmingCharacters(in: .whitespaces).lowercased()
        if let exact = db[key] { return exact }
        // Multiple keys can match a given input (e.g. "hähnchen curry" contains both "hähnchen"
        // and "curry"). Dictionary iteration order is randomized per launch, so picking the first
        // match during a plain iteration would make the result non-deterministic across app
        // launches. Instead, deterministically prefer the longest (most specific) matching key,
        // breaking ties alphabetically.
        let match = db
            .filter { key.contains($0.key) || $0.key.contains(key) }
            .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }
            .first
        return match?.value ?? []
    }
}
