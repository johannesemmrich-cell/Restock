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
    @AppStorage("menuPortionsJSON") private var portionsJSON = ""
    @AppStorage("menuAddedDaysJSON") private var addedDaysJSON = ""

    @State private var meals: [String]
    @State private var ingredientsMap: [String: [MealIngredient]]
    @State private var portionsMap: [String: Int]
    @State private var addedDayIndices: Set<Int>
    @State private var loadingDays: Set<Int> = []
    @State private var showAddDay = false
    @State private var checkedIngredients: Set<String> = []
    @State private var toastMessage: String? = nil
    @State private var expandedDays: Set<Int> = []
    @State private var fetchTasks: [Int: Task<Void, Never>] = [:]

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

        // Wenn dieser Decode fehlschlägt (z. B. beim allerersten Start nach dem Umbau von reinen
        // Zutaten-Namen auf MealIngredient mit Menge/Einheit), fällt das auf ein leeres Dict
        // zurück statt zu crashen — der Auto-Heal in .onAppear holt fehlende Tage automatisch
        // per fetchIngredients() neu, sobald die View erscheint.
        let ingStored = UserDefaults.standard.string(forKey: "menuIngredientsJSON") ?? ""
        if let data = ingStored.data(using: .utf8),
           let map = try? JSONDecoder().decode([String: [MealIngredient]].self, from: data) {
            _ingredientsMap = State(initialValue: map)
        } else {
            _ingredientsMap = State(initialValue: [:])
        }

        let portionsStored = UserDefaults.standard.string(forKey: "menuPortionsJSON") ?? ""
        if let data = portionsStored.data(using: .utf8),
           let map = try? JSONDecoder().decode([String: Int].self, from: data) {
            _portionsMap = State(initialValue: map)
        } else {
            _portionsMap = State(initialValue: [:])
        }

        let addedStored = UserDefaults.standard.string(forKey: "menuAddedDaysJSON") ?? ""
        if let data = addedStored.data(using: .utf8),
           let arr = try? JSONDecoder().decode([Int].self, from: data) {
            _addedDayIndices = State(initialValue: Set(arr))
        } else {
            _addedDayIndices = State(initialValue: [])
        }
    }

    // MARK: - Saved recipes helpers

    private var savedRecipes: [SavedRecipe] {
        guard let data = savedRecipesJSON.data(using: .utf8) else { return [] }
        let recipes: [SavedRecipe]
        if let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
            recipes = decoded
        } else if let legacy = try? JSONDecoder().decode([LegacySavedRecipe].self, from: data) {
            // Vor der Portionen-Umstellung gespeicherte Rezepte hatten reine Zutaten-Namen ohne
            // Menge/Einheit — auf eine neutrale Basis-Menge hochrechnen statt sie beim Umbau
            // stillschweigend zu verlieren.
            recipes = legacy.map { old in
                var recipe = SavedRecipe(
                    name: old.name,
                    ingredients: old.ingredients.map { MealIngredient(name: $0, amount: 1, unit: "") }
                )
                recipe.id = old.id
                recipe.usageCount = old.usageCount
                recipe.lastUsed = old.lastUsed
                return recipe
            }
        } else {
            recipes = []
        }
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
            toastMessage = "Bereits gespeichert"
            return
        }
        recipes.append(SavedRecipe(name: meal, ingredients: ings))
        persistSavedRecipes(recipes)
        Haptics.success()
        toastMessage = "\"\(meal)\" gespeichert"
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

    /// Geplante Tage, die noch keine eigene "+ Liste"/Store-Aktion bekommen haben — Basis sowohl
    /// für den Badge-Zustand pro Tag als auch für den globalen "Alle hinzufügen"-Button, der
    /// (anders als früher `addToList()`) nur noch diese Teilmenge verarbeitet und dadurch das
    /// gemeldete Duplikat-Problem (Montag wird beim Dienstag-Hinzufügen erneut eingefügt)
    /// strukturell ausschließt.
    private var remainingDaysToAdd: [Int] {
        plannedIndices.filter { !addedDayIndices.contains($0) && !(ingredientsMap["\($0)"] ?? []).isEmpty }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
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
                    Button { addRemainingDaysToList() } label: {
                        Text("Alle hinzufügen").toolbarChip(prominent: true)
                    }
                    .buttonStyle(.pressable)
                    .disabled(remainingDaysToAdd.isEmpty)
                }
            }
            .sheet(isPresented: $showAddDay) {
                AddDaySheet(
                    meals: $meals,
                    dayNames: dayNamesFull,
                    savedRecipes: savedRecipes
                ) { dayIndex, meal, manual, usedRecipe, portions in
                    meals[dayIndex] = meal
                    portionsMap["\(dayIndex)"] = portions
                    savePlan()
                    savePortions()
                    if let recipe = usedRecipe {
                        ingredientsMap["\(dayIndex)"] = recipe.ingredients
                        saveIngredients()
                        recordUsage(recipe)
                        expandedDays.insert(dayIndex)
                    } else if !manual.isEmpty {
                        ingredientsMap["\(dayIndex)"] = manual.map { MealIngredient(name: $0, amount: 1, unit: "") }
                        saveIngredients()
                        expandedDays.insert(dayIndex)
                    } else {
                        fetchIngredients(for: dayIndex, meal: meal)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
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
                                withAnimation { toastMessage = nil }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
            .onAppear {
                // Auto-Heal: fängt sowohl den Fall ab, dass `ingredientsMap` beim Umbau von
                // reinen Zutaten-Namen auf MealIngredient nicht decodiert werden konnte, als auch
                // einen frisch hinzugefügten Tag ohne Zutaten — beide Fälle sehen identisch aus
                // ("geplant, aber ohne Zutaten") und werden identisch behoben.
                for i in plannedIndices where (ingredientsMap["\(i)"] ?? []).isEmpty && !loadingDays.contains(i) {
                    fetchIngredients(for: i, meal: meals[i])
                }
            }
            .onDisappear {
                for task in fetchTasks.values { task.cancel() }
                fetchTasks.removeAll()
            }
        }
        .devFeedback(context: "Menüplan")
    }

    // MARK: - Shared store-target menu

    /// Gemeinsame "+ Liste"-Aktion für Tageszeilen und gespeicherte Rezepte: ein Menü mit
    /// "Automatisch zuordnen" (pro Zutat via AssignmentService) plus jedem aktiven Laden einzeln
    /// — löst sowohl die Pro-Tag/Pro-Rezept-Zielliste als auch (in Kombination mit
    /// `addedDayIndices`) das Duplikat-Problem, weil jede Zeile ihre eigene, unabhängige
    /// Hinzufügen-Aktion hat statt eines gemeinsamen globalen Ziels.
    @ViewBuilder
    private func storeTargetMenu(alreadyAdded: Bool, onPick: @escaping (Store?) -> Void) -> some View {
        Menu {
            Button {
                onPick(nil)
            } label: {
                Label("Automatisch zuordnen", systemImage: "wand.and.stars")
            }
            if !activeStores.isEmpty {
                Divider()
                ForEach(activeStores) { store in
                    Button {
                        onPick(store)
                    } label: {
                        Text("\(store.emoji) \(store.name)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if alreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                }
                Text(alreadyAdded ? "Auf der Liste" : "+ Liste")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(alreadyAdded ? Color.accent : Color.onButton)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                alreadyAdded ? Color.accent.opacity(0.15) : Color.accent,
                in: RoundedRectangle(cornerRadius: RCRadius.tag)
            )
        }
        .buttonStyle(.pressable)
        // Ohne dieses Disabled bliebe das "Auf der Liste"-Badge ein voll antippbares Menü — ein
        // zweiter Tap hätte `addDayToList` erneut ausgeführt und die Zutaten dieses Tages ein
        // zweites Mal eingefügt (exakt die Art Duplikat, die addedDayIndices verhindern soll).
        // Bewusstes erneutes Hinzufügen bleibt möglich, aber nur über die Portionen-Änderung
        // (portionsBinding setzt addedDayIndices für diesen Tag gezielt zurück).
        .disabled(alreadyAdded)
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
                                    portionsMap.removeValue(forKey: "\(i)")
                                    addedDayIndices.remove(i)
                                    loadingDays.remove(i)
                                }
                                savePlan()
                                saveIngredients()
                                savePortions()
                                saveAddedDays()
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
            if !ings.isEmpty {
                Stepper(
                    "Portionen: \(portions(for: i))",
                    value: portionsBinding(for: i),
                    in: 1...12
                )
                .font(.system(size: 13))
                .padding(.vertical, 2)
            }
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
                // Index-basierte Identität statt id: \.self — eine vom User doppelt getippte
                // Zutat würde sonst zwei ForEach-Zeilen mit identischer Identität erzeugen, was
                // bei der animierten Swipe-/Expand-Logik dieser Zeile zu einem echten Absturz
                // führen kann.
                ForEach(Array(ings.enumerated()), id: \.offset) { _, ingredient in
                    ingredientRow(ingredient, portions: portions(for: i))
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(dayNames[i])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                Text(meals[i])
                    .font(.system(size: 15))
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.65)
                } else if !ings.isEmpty {
                    storeTargetMenu(alreadyAdded: addedDayIndices.contains(i)) { store in
                        addDayToList(i, store: store)
                        checkedIngredients.removeAll()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientRow(_ ingredient: MealIngredient, portions: Int) -> some View {
        let name = ingredient.name
        let isChecked = checkedIngredients.contains(name.lowercased())
        let scaled = ingredient.scaledAmount(forPortions: portions)
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
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14))
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked, color: .secondary)
                if scaled > 0 {
                    Text(formattedQuantity(scaled, unit: ingredient.unit))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let store = autoAssignedStore(for: name) {
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
                Text("Tippe auf \"+ Liste\" um eine Ziel-Liste zu wählen und alle Zutaten direkt einzukaufen. Nach links wischen zum L\u{00F6}schen.")
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
                let names = recipe.ingredients.map(\.name)
                Text(names.prefix(4).joined(separator: ", ") + (names.count > 4 ? "…" : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            // Kein `addedDayIndices`-artiges Tracking hier — anders als Tageszeilen sind
            // gespeicherte Rezepte für wiederholte Nutzung über mehrere Wochen gedacht
            // (usageCount/lastUsed existieren genau dafür), ein "bereits hinzugefügt"-Badge
            // würde dem eigentlichen Zweck entgegenlaufen.
            storeTargetMenu(alreadyAdded: false) { store in
                addRecipeToList(recipe, store: store)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func fetchIngredients(for dayIndex: Int, meal: String) {
        fetchTasks[dayIndex]?.cancel()
        loadingDays.insert(dayIndex)
        expandedDays.insert(dayIndex)
        fetchTasks[dayIndex] = Task {
            let result = await Self.ingredientsWithHardTimeout(for: meal)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loadingDays.remove(dayIndex)
                fetchTasks.removeValue(forKey: dayIndex)
                if !result.items.isEmpty {
                    ingredientsMap["\(dayIndex)"] = result.items
                    saveIngredients()
                }
            }
        }
    }

    /// Äußere Sicherheitsgrenze zusätzlich zum bereits in `MealIngredientService.aiIngredients`
    /// eingebauten 25s-Timeout — falls dieser aus irgendeinem Grund selbst hängt (live
    /// reproduziert: "Zutaten werden erkannt…" blieb über eine Minute stehen, kein Absturz, kein
    /// Ergebnis), darf die Menüplan-UI trotzdem nie für immer hängen bleiben. Reine
    /// Verteidigungslinie — der eigentliche Fix ist, dass `MealIngredientService.ingredients`
    /// jetzt bekannte Gerichte zuerst aus der lokalen Datenbank bedient und den KI-Pfad nur noch
    /// für unbekannte Gerichte überhaupt betritt. Nutzt `withRealTimeout` (RecipeRecognitionService.swift),
    /// NICHT ein TaskGroup-Rennen — ein TaskGroup wartet laut Swifts Structured-Concurrency-Vertrag
    /// auf ALLE Kind-Tasks, bevor es selbst zurückkehrt, würde also von genau der Art hängendem
    /// Aufruf blockiert, vor der diese Funktion eigentlich schützen soll.
    private static func ingredientsWithHardTimeout(
        for meal: String
    ) async -> (items: [MealIngredient], source: MealIngredientService.Source) {
        await withRealTimeout(
            seconds: 30,
            operation: { await MealIngredientService.shared.ingredients(for: meal) },
            onTimeout: { ([], .none) }
        )
    }

    /// Automatische Pro-Zutat-Zuordnung (Kategorie-/Historie-basiert), unabhängig von einer
    /// expliziten Store-Wahl — ersetzt das frühere `resolvedStore(for:)`, das zusätzlich einen
    /// einzigen globalen `targetStore` bevorzugt hätte (jetzt entfallen, siehe `storeTargetMenu`).
    private func autoAssignedStore(for name: String) -> Store? {
        AssignmentService.assign(itemName: name, to: activeStores, purchaseRecords: allRecords) ?? activeStores.first
    }

    private func portions(for dayIndex: Int) -> Int {
        portionsMap["\(dayIndex)"] ?? MealDatabase.baseServings
    }

    private func portionsBinding(for dayIndex: Int) -> Binding<Int> {
        Binding(
            get: { portions(for: dayIndex) },
            set: { newValue in
                portionsMap["\(dayIndex)"] = newValue
                savePortions()
                // Bereits hinzugefügte Mengen spiegeln sonst weiter die alte Portionszahl wider,
                // obwohl das Badge schon "Auf der Liste" zeigt — Markierung zurücksetzen, damit
                // der User bewusst erneut hinzufügt statt eine veraltete Menge unbemerkt stehen
                // zu lassen.
                if addedDayIndices.remove(dayIndex) != nil {
                    saveAddedDays()
                }
            }
        )
    }

    /// Fügt NUR die Zutaten von `dayIndex` ein und markiert diesen Tag als hinzugefügt — behebt
    /// den gemeldeten Bug, dass ein erneuter Tap (z. B. nach Anlegen eines weiteren Tages) auch
    /// bereits hinzugefügte Tage wieder dupliziert hätte (die frühere `addToList()` verarbeitete
    /// immer ALLE geplanten Tage gemeinsam, ohne Markierung).
    private func addDayToList(_ dayIndex: Int, store explicitStore: Store?, showToast: Bool = true) {
        // Verteidigungslinie zusätzlich zu `.disabled(alreadyAdded)` am Menü-Button — verhindert
        // eine Dopplung selbst wenn dieser Pfad je anders als über das Menü erreicht wird.
        guard !addedDayIndices.contains(dayIndex) else { return }
        let ingredients = (ingredientsMap["\(dayIndex)"] ?? [])
            .filter { !checkedIngredients.contains($0.name.lowercased()) }
        guard !ingredients.isEmpty else { return }
        let dayPortions = portions(for: dayIndex)
        var touchedStores: [Store?] = []
        for ingredient in ingredients {
            let scaledAmount = ingredient.scaledAmount(forPortions: dayPortions)
            let finalAmount = scaledAmount > 0 ? scaledAmount : 1
            let category = AssignmentService.category(for: ingredient.name)
            let store = explicitStore ?? autoAssignedStore(for: ingredient.name)
            context.insert(ShoppingItem(
                name: ingredient.name,
                category: category,
                quantity: plainQuantityString(finalAmount),
                quantityAmount: finalAmount,
                unit: ingredient.unit,
                store: store
            ))
            touchedStores.append(store)
        }
        addedDayIndices.insert(dayIndex)
        saveAddedDays()
        Haptics.success()
        SyncCoordinator.shared.pushInBackground(touchedStores)
        if showToast {
            toastMessage = "\"\(meals[dayIndex])\" zur Liste hinzugefügt"
        }
    }

    /// Ersetzt die frühere globale "Zur Liste" (`addToList()`), die bei jedem Tap ALLE geplanten
    /// Tage erneut eingefügt hat. Verarbeitet nur noch `remainingDaysToAdd` (noch nicht
    /// hinzugefügte Tage), immer mit automatischer Pro-Zutat-Zuordnung — eine Sammelaktion kann
    /// nicht sinnvoll pro Tag nach einem Ziel-Laden fragen; wer das braucht, nutzt die einzelne
    /// Tages-Aktion.
    private func addRemainingDaysToList() {
        let remaining = remainingDaysToAdd
        guard !remaining.isEmpty else { return }
        // Erst NACH der gesamten Schleife zurücksetzen, nicht pro Tag: sonst würde ein für Tag A
        // abgehaktes "hab ich schon"-Zutat (checkedIngredients ist global, nicht pro Tag) nach dem
        // Verarbeiten von Tag A wieder aktiv werden und fälschlich bei Tag B erneut mit auf die
        // Liste kommen.
        for dayIndex in remaining {
            addDayToList(dayIndex, store: nil, showToast: false)
        }
        checkedIngredients.removeAll()
        toastMessage = remaining.count == 1 ? "1 Tag zur Liste hinzugefügt" : "\(remaining.count) Tage zur Liste hinzugefügt"
    }

    private func addRecipeToList(_ recipe: SavedRecipe, store explicitStore: Store?) {
        var touchedStores: [Store?] = []
        for ingredient in recipe.ingredients {
            let finalAmount = ingredient.amount > 0 ? ingredient.amount : 1
            let category = AssignmentService.category(for: ingredient.name)
            let store = explicitStore ?? autoAssignedStore(for: ingredient.name)
            context.insert(ShoppingItem(
                name: ingredient.name,
                category: category,
                quantity: plainQuantityString(finalAmount),
                quantityAmount: finalAmount,
                unit: ingredient.unit,
                store: store
            ))
            touchedStores.append(store)
        }
        recordUsage(recipe)
        Haptics.success()
        SyncCoordinator.shared.pushInBackground(touchedStores)
        toastMessage = "\"\(recipe.name)\" zur Liste hinzugefügt"
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

    private func savePortions() {
        if let data = try? JSONEncoder().encode(portionsMap),
           let str = String(data: data, encoding: .utf8) {
            portionsJSON = str
        }
    }

    private func saveAddedDays() {
        if let data = try? JSONEncoder().encode(Array(addedDayIndices).sorted()),
           let str = String(data: data, encoding: .utf8) {
            addedDaysJSON = str
        }
    }
}

// MARK: - Meal Ingredient (shared quantity model)

/// Eine Zutat mit einer Basis-Menge bei `MealDatabase.baseServings` Portionen. Bewusst kein
/// drittes `quantity: String`-Anzeigefeld wie bei `RecognizedIngredient` — hier ist der
/// numerische Wert immer die Quelle der Wahrheit für die Skalierung, ein gespeicherter String
/// würde bei einer Portions-Änderung nur veralten.
struct MealIngredient: Codable, Equatable, Hashable {
    var name: String
    var amount: Double
    var unit: String

    func scaledAmount(forPortions portions: Int, baseServings: Int = MealDatabase.baseServings) -> Double {
        guard baseServings > 0 else { return amount }
        return amount * Double(portions) / Double(baseServings)
    }
}

/// Rein numerischer Mengen-String ohne Einheit (für `ShoppingItem.quantity`, das Anzeigefeld für
/// die reine Zahl) — gleiche Rundungs-Konvention wie an anderen Stellen der App (z. B.
/// `StoreDetailView.quickAdd()`/`historicQuantityHint`): ganze Zahlen ohne Nachkommastelle,
/// sonst eine Nachkommastelle. `amount` kann aus einer von Apple Intelligence gelieferten
/// "amount"-Zahl stammen (`MealIngredientService.parseMealIngredients`) — eine halluzinierte,
/// nicht-endliche oder extrem große Zahl (z. B. "inf"/"1e300", beides gültige `Double`-Literale)
/// würde `Int(amount)` sonst hart abstürzen lassen (gleiche Absturzklasse wie bereits in
/// `RecipeRecognitionService.parseIngredients`s OCR-Fallback erkannt und dort abgesichert).
func plainQuantityString(_ amount: Double) -> String {
    guard amount.isFinite, abs(amount) < Double(Int.max) else { return "1" }
    return amount == Double(Int(amount)) ? "\(Int(amount))" : String(format: "%.1f", amount)
}

/// Menge + Einheit als eine Anzeige-Caption, z. B. "300 g" oder "2×" ohne Einheit.
func formattedQuantity(_ amount: Double, unit: String) -> String {
    let qtyStr = plainQuantityString(amount)
    return unit.isEmpty ? "\(qtyStr)×" : "\(qtyStr) \(unit)"
}

// MARK: - Saved Recipe Model

struct SavedRecipe: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var ingredients: [MealIngredient]
    var usageCount: Int
    var lastUsed: Date?

    init(name: String, ingredients: [MealIngredient]) {
        self.id = UUID()
        self.name = name
        self.ingredients = ingredients
        self.usageCount = 0
        self.lastUsed = nil
    }
}

/// Deckt Rezepte ab, die vor der Portionen-Umstellung gespeichert wurden (reine Zutaten-Namen
/// ohne Menge/Einheit) — Decode-Fallback in `MenuPlanView.savedRecipes`, wenn `[SavedRecipe]`
/// fehlschlägt.
private struct LegacySavedRecipe: Codable {
    var id: UUID
    var name: String
    var ingredients: [String]
    var usageCount: Int
    var lastUsed: Date?
}

// MARK: - Add Day Sheet

private struct AddDaySheet: View {
    @Binding var meals: [String]
    let dayNames: [String]
    let savedRecipes: [SavedRecipe]
    let onSave: (_ dayIndex: Int, _ meal: String, _ manualIngredients: [String], _ recipe: SavedRecipe?, _ portions: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 0
    @State private var mealText = ""
    @State private var manualText = ""
    @State private var selectedRecipe: SavedRecipe? = nil
    @State private var showRecipePicker = false
    @State private var portions = MealDatabase.baseServings

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
                    Stepper("Portionen: \(portions)", value: $portions, in: 1...12)
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
                            Text(ing.name).font(.system(size: 14)).foregroundStyle(.secondary)
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
                        onSave(selectedDay, mealText.trimmingCharacters(in: .whitespaces), manualIngredients, selectedRecipe, portions)
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
                        let names = recipe.ingredients.map(\.name)
                        Text(names.prefix(5).joined(separator: ", ") + (names.count > 5 ? "…" : ""))
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
    /// Basis-Portionszahl, auf die sich jede Menge in `db` bezieht — einzige globale Konstante
    /// statt eines Per-Gericht-Overrides, da die Skalierungs-Mathematik für jede Basis gleich
    /// gut funktioniert und ein Override keinen echten Zusatznutzen hätte.
    static let baseServings = 4

    private static let db: [String: [MealIngredient]] = [
        // Pasta & Italienisch
        "pasta": [
            MealIngredient(name: "Nudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Tomatensoße", amount: 400, unit: "ml"),
            MealIngredient(name: "Parmesan", amount: 60, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
        ],
        "spaghetti": [
            MealIngredient(name: "Spaghetti", amount: 400, unit: "g"),
            MealIngredient(name: "Tomatensoße", amount: 400, unit: "ml"),
            MealIngredient(name: "Parmesan", amount: 60, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
        ],
        "bolognese": [
            MealIngredient(name: "Hackfleisch", amount: 500, unit: "g"),
            MealIngredient(name: "Spaghetti", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 2, unit: "EL"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
        ],
        "pasta bolognese": [
            MealIngredient(name: "Hackfleisch", amount: 500, unit: "g"),
            MealIngredient(name: "Nudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 2, unit: "EL"),
        ],
        "carbonara": [
            MealIngredient(name: "Spaghetti", amount: 400, unit: "g"),
            MealIngredient(name: "Guanciale", amount: 150, unit: "g"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Pecorino", amount: 80, unit: "g"),
            MealIngredient(name: "Pfeffer", amount: 1, unit: "TL"),
        ],
        "lasagne": [
            MealIngredient(name: "Hackfleisch", amount: 400, unit: "g"),
            MealIngredient(name: "Lasagneplatten", amount: 250, unit: "g"),
            MealIngredient(name: "Tomatensoße", amount: 500, unit: "ml"),
            MealIngredient(name: "Béchamelsauce", amount: 300, unit: "ml"),
            MealIngredient(name: "Käse", amount: 150, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
        ],
        "pizza": [
            MealIngredient(name: "Pizzateig", amount: 600, unit: "g"),
            MealIngredient(name: "Tomatensoße", amount: 200, unit: "ml"),
            MealIngredient(name: "Mozzarella", amount: 250, unit: "g"),
            MealIngredient(name: "Oregano", amount: 1, unit: "TL"),
        ],
        "pesto pasta": [
            MealIngredient(name: "Nudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Basilikum", amount: 1, unit: "Bund"),
            MealIngredient(name: "Pinienkerne", amount: 50, unit: "g"),
            MealIngredient(name: "Parmesan", amount: 60, unit: "g"),
            MealIngredient(name: "Olivenöl", amount: 100, unit: "ml"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
        ],
        "aglio e olio": [
            MealIngredient(name: "Spaghetti", amount: 400, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 4, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 100, unit: "ml"),
            MealIngredient(name: "Chili", amount: 1, unit: "Stück"),
            MealIngredient(name: "Petersilie", amount: 1, unit: "Bund"),
        ],
        "pasta arrabiata": [
            MealIngredient(name: "Penne", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Chili", amount: 2, unit: "Stück"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
        ],
        "gnocchi": [
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
            MealIngredient(name: "Mehl", amount: 200, unit: "g"),
            MealIngredient(name: "Eier", amount: 1, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 50, unit: "g"),
            MealIngredient(name: "Salbei", amount: 1, unit: "Bund"),
        ],
        "gnocchi mit salbeibutter": [
            MealIngredient(name: "Gnocchi", amount: 500, unit: "g"),
            MealIngredient(name: "Butter", amount: 80, unit: "g"),
            MealIngredient(name: "Salbei", amount: 1, unit: "Bund"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
        ],
        "risotto": [
            MealIngredient(name: "Risottoreis", amount: 320, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Parmesan", amount: 80, unit: "g"),
            MealIngredient(name: "Butter", amount: 50, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Weißwein", amount: 100, unit: "ml"),
        ],
        "pilzrisotto": [
            MealIngredient(name: "Risottoreis", amount: 320, unit: "g"),
            MealIngredient(name: "Champignons", amount: 300, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Parmesan", amount: 80, unit: "g"),
            MealIngredient(name: "Butter", amount: 50, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Weißwein", amount: 100, unit: "ml"),
        ],
        "ravioli": [
            MealIngredient(name: "Ravioli", amount: 600, unit: "g"),
            MealIngredient(name: "Butter", amount: 60, unit: "g"),
            MealIngredient(name: "Salbei", amount: 1, unit: "Bund"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
        ],
        "tortellini": [
            MealIngredient(name: "Tortellini", amount: 600, unit: "g"),
            MealIngredient(name: "Sahne", amount: 200, unit: "ml"),
            MealIngredient(name: "Schinken", amount: 150, unit: "g"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
        ],
        "flammkuchen": [
            MealIngredient(name: "Flammkuchenteig", amount: 2, unit: "Stück"),
            MealIngredient(name: "Crème fraîche", amount: 200, unit: "g"),
            MealIngredient(name: "Speck", amount: 150, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
        ],
        "tiramisu": [
            MealIngredient(name: "Löffelbiskuits", amount: 200, unit: "g"),
            MealIngredient(name: "Mascarpone", amount: 500, unit: "g"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Zucker", amount: 100, unit: "g"),
            MealIngredient(name: "Espresso", amount: 200, unit: "ml"),
            MealIngredient(name: "Kakao", amount: 2, unit: "EL"),
        ],
        // Fleisch & Klassiker
        "schnitzel": [
            MealIngredient(name: "Schnitzel", amount: 4, unit: "Stück"),
            MealIngredient(name: "Eier", amount: 2, unit: "Stück"),
            MealIngredient(name: "Semmelbrösel", amount: 150, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "wiener schnitzel": [
            MealIngredient(name: "Kalbsschnitzel", amount: 4, unit: "Stück"),
            MealIngredient(name: "Eier", amount: 2, unit: "Stück"),
            MealIngredient(name: "Semmelbrösel", amount: 150, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "braten": [
            MealIngredient(name: "Schweinebraten", amount: 1200, unit: "g"),
            MealIngredient(name: "Möhren", amount: 300, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 200, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
        ],
        "rinderbraten": [
            MealIngredient(name: "Rinderbraten", amount: 1200, unit: "g"),
            MealIngredient(name: "Möhren", amount: 300, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 200, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Rotwein", amount: 250, unit: "ml"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
        ],
        "sauerbraten": [
            MealIngredient(name: "Rindfleisch", amount: 1200, unit: "g"),
            MealIngredient(name: "Rotweinessig", amount: 250, unit: "ml"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Gewürze", amount: 1, unit: "EL"),
            MealIngredient(name: "Kartoffelknödel", amount: 8, unit: "Stück"),
        ],
        "rouladen": [
            MealIngredient(name: "Rindfleischrouladen", amount: 4, unit: "Stück"),
            MealIngredient(name: "Senf", amount: 2, unit: "EL"),
            MealIngredient(name: "Speck", amount: 100, unit: "g"),
            MealIngredient(name: "Gurken", amount: 4, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "königsberger klopse": [
            MealIngredient(name: "Hackfleisch", amount: 600, unit: "g"),
            MealIngredient(name: "Brötchen", amount: 2, unit: "Stück"),
            MealIngredient(name: "Eier", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Kapern", amount: 2, unit: "EL"),
            MealIngredient(name: "Sahne", amount: 200, unit: "ml"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
        ],
        "kassler": [
            MealIngredient(name: "Kassler", amount: 800, unit: "g"),
            MealIngredient(name: "Sauerkraut", amount: 500, unit: "g"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
            MealIngredient(name: "Senf", amount: 2, unit: "EL"),
        ],
        "gulasch": [
            MealIngredient(name: "Rindfleisch", amount: 800, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 3, unit: "Stück"),
            MealIngredient(name: "Paprikapulver", amount: 2, unit: "EL"),
            MealIngredient(name: "Tomatenmark", amount: 2, unit: "EL"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "hähnchen": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
            MealIngredient(name: "Rosmarin", amount: 1, unit: "Bund"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "hühnchen": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
            MealIngredient(name: "Kräuter", amount: 1, unit: "TL"),
        ],
        "steak": [
            MealIngredient(name: "Rindersteak", amount: 4, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 50, unit: "g"),
            MealIngredient(name: "Rosmarin", amount: 1, unit: "Bund"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "burger": [
            MealIngredient(name: "Hackfleisch", amount: 600, unit: "g"),
            MealIngredient(name: "Burger Buns", amount: 4, unit: "Stück"),
            MealIngredient(name: "Salat", amount: 4, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 2, unit: "Stück"),
            MealIngredient(name: "Käse", amount: 4, unit: "Stück"),
            MealIngredient(name: "Ketchup", amount: 4, unit: "EL"),
            MealIngredient(name: "Gurken", amount: 1, unit: "Stück"),
        ],
        "bratwurst": [
            MealIngredient(name: "Bratwurst", amount: 4, unit: "Stück"),
            MealIngredient(name: "Senf", amount: 4, unit: "EL"),
            MealIngredient(name: "Sauerkraut", amount: 400, unit: "g"),
            MealIngredient(name: "Brötchen", amount: 4, unit: "Stück"),
        ],
        "schweinshaxe": [
            MealIngredient(name: "Schweinshaxe", amount: 2, unit: "Stück"),
            MealIngredient(name: "Bier", amount: 500, unit: "ml"),
            MealIngredient(name: "Kartoffelknödel", amount: 8, unit: "Stück"),
            MealIngredient(name: "Sauerkraut", amount: 500, unit: "g"),
        ],
        "weißwurst": [
            MealIngredient(name: "Weißwurst", amount: 8, unit: "Stück"),
            MealIngredient(name: "Süßer Senf", amount: 100, unit: "g"),
            MealIngredient(name: "Brezeln", amount: 4, unit: "Stück"),
        ],
        "grünkohl": [
            MealIngredient(name: "Grünkohl", amount: 1000, unit: "g"),
            MealIngredient(name: "Kassler", amount: 400, unit: "g"),
            MealIngredient(name: "Mettwurst", amount: 4, unit: "Stück"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
            MealIngredient(name: "Senf", amount: 2, unit: "EL"),
        ],
        // Fisch & Meeresfrüchte
        "lachs": [
            MealIngredient(name: "Lachsfilet", amount: 600, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Dill", amount: 1, unit: "Bund"),
            MealIngredient(name: "Butter", amount: 40, unit: "g"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "lachsfilet": [
            MealIngredient(name: "Lachsfilet", amount: 600, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Dill", amount: 1, unit: "Bund"),
            MealIngredient(name: "Butter", amount: 40, unit: "g"),
        ],
        "fisch": [
            MealIngredient(name: "Fischfilet", amount: 600, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 40, unit: "g"),
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
        ],
        "matjes": [
            MealIngredient(name: "Matjesfilet", amount: 4, unit: "Stück"),
            MealIngredient(name: "Äpfel", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Sahne", amount: 200, unit: "ml"),
            MealIngredient(name: "Gurken", amount: 1, unit: "Stück"),
        ],
        "garnelen pfanne": [
            MealIngredient(name: "Garnelen", amount: 500, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Butter", amount: 40, unit: "g"),
            MealIngredient(name: "Chili", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Petersilie", amount: 1, unit: "Bund"),
        ],
        // Asiatisch
        "curry": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Kokosmilch", amount: 400, unit: "ml"),
            MealIngredient(name: "Currypaste", amount: 3, unit: "EL"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
        ],
        "chicken tikka masala": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Joghurt", amount: 200, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Sahne", amount: 200, unit: "ml"),
            MealIngredient(name: "Gewürze", amount: 2, unit: "EL"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Naan", amount: 4, unit: "Stück"),
        ],
        "dal": [
            MealIngredient(name: "Rote Linsen", amount: 300, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Kurkuma", amount: 1, unit: "TL"),
            MealIngredient(name: "Kreuzkümmel", amount: 1, unit: "TL"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
        ],
        "palak paneer": [
            MealIngredient(name: "Paneer", amount: 400, unit: "g"),
            MealIngredient(name: "Spinat", amount: 500, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 300, unit: "g"),
            MealIngredient(name: "Sahne", amount: 100, unit: "ml"),
            MealIngredient(name: "Gewürze", amount: 2, unit: "TL"),
            MealIngredient(name: "Naan", amount: 4, unit: "Stück"),
        ],
        "biryani": [
            MealIngredient(name: "Basmatireis", amount: 400, unit: "g"),
            MealIngredient(name: "Hähnchen", amount: 600, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Joghurt", amount: 150, unit: "g"),
            MealIngredient(name: "Safran", amount: 1, unit: "Prise"),
            MealIngredient(name: "Gewürze", amount: 2, unit: "EL"),
        ],
        "korma": [
            MealIngredient(name: "Hähnchen", amount: 600, unit: "g"),
            MealIngredient(name: "Kokosmilch", amount: 400, unit: "ml"),
            MealIngredient(name: "Cashews", amount: 50, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Gewürze", amount: 2, unit: "EL"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
            MealIngredient(name: "Naan", amount: 4, unit: "Stück"),
        ],
        "ramen": [
            MealIngredient(name: "Ramen-Nudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1200, unit: "ml"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Nori", amount: 2, unit: "Stück"),
            MealIngredient(name: "Frühlingszwiebeln", amount: 3, unit: "Stück"),
            MealIngredient(name: "Schweinefleisch", amount: 300, unit: "g"),
            MealIngredient(name: "Maiskolben", amount: 2, unit: "Stück"),
        ],
        "miso suppe": [
            MealIngredient(name: "Miso-Paste", amount: 4, unit: "EL"),
            MealIngredient(name: "Tofu", amount: 200, unit: "g"),
            MealIngredient(name: "Wakame", amount: 10, unit: "g"),
            MealIngredient(name: "Dashi", amount: 1000, unit: "ml"),
            MealIngredient(name: "Frühlingszwiebeln", amount: 2, unit: "Stück"),
        ],
        "pad thai": [
            MealIngredient(name: "Reisnudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Garnelen", amount: 300, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Sojasprossen", amount: 200, unit: "g"),
            MealIngredient(name: "Frühlingszwiebeln", amount: 3, unit: "Stück"),
            MealIngredient(name: "Erdnüsse", amount: 50, unit: "g"),
            MealIngredient(name: "Fischsauce", amount: 3, unit: "EL"),
        ],
        "nasi goreng": [
            MealIngredient(name: "Reis", amount: 400, unit: "g"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Sojasoße", amount: 4, unit: "EL"),
            MealIngredient(name: "Kecap Manis", amount: 3, unit: "EL"),
            MealIngredient(name: "Chili", amount: 2, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 3, unit: "Zehe"),
            MealIngredient(name: "Garnelen", amount: 300, unit: "g"),
        ],
        "gyoza": [
            MealIngredient(name: "Hackfleisch", amount: 400, unit: "g"),
            MealIngredient(name: "Chinakohl", amount: 300, unit: "g"),
            MealIngredient(name: "Gyoza-Teig", amount: 24, unit: "Stück"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
        ],
        "frühlingsrollen": [
            MealIngredient(name: "Frühlingsrollenteig", amount: 16, unit: "Stück"),
            MealIngredient(name: "Hackfleisch", amount: 300, unit: "g"),
            MealIngredient(name: "Glasnudeln", amount: 100, unit: "g"),
            MealIngredient(name: "Kohl", amount: 300, unit: "g"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
        ],
        "wok gemüse": [
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Brokkoli", amount: 300, unit: "g"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Zuckerschoten", amount: 200, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
        ],
        "teriyaki hähnchen": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 100, unit: "ml"),
            MealIngredient(name: "Mirin", amount: 50, unit: "ml"),
            MealIngredient(name: "Sake", amount: 50, unit: "ml"),
            MealIngredient(name: "Zucker", amount: 2, unit: "EL"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
        ],
        "bibimbap": [
            MealIngredient(name: "Reis", amount: 400, unit: "g"),
            MealIngredient(name: "Spinat", amount: 300, unit: "g"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Zucchini", amount: 200, unit: "g"),
            MealIngredient(name: "Rindfleisch", amount: 400, unit: "g"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Gochujang", amount: 3, unit: "EL"),
            MealIngredient(name: "Sesamöl", amount: 2, unit: "EL"),
        ],
        "sushi": [
            MealIngredient(name: "Sushi-Reis", amount: 400, unit: "g"),
            MealIngredient(name: "Nori", amount: 10, unit: "Stück"),
            MealIngredient(name: "Lachs", amount: 300, unit: "g"),
            MealIngredient(name: "Gurke", amount: 1, unit: "Stück"),
            MealIngredient(name: "Avocado", amount: 1, unit: "Stück"),
            MealIngredient(name: "Reisessig", amount: 3, unit: "EL"),
        ],
        "gebratener reis": [
            MealIngredient(name: "Reis", amount: 400, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Möhren", amount: 150, unit: "g"),
            MealIngredient(name: "Erbsen", amount: 150, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
            MealIngredient(name: "Öl", amount: 2, unit: "EL"),
        ],
        // Mexikanisch
        "chili": [
            MealIngredient(name: "Hackfleisch", amount: 600, unit: "g"),
            MealIngredient(name: "Kidneybohnen", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Chili", amount: 2, unit: "Stück"),
            MealIngredient(name: "Mais", amount: 200, unit: "g"),
        ],
        "chili con carne": [
            MealIngredient(name: "Hackfleisch", amount: 600, unit: "g"),
            MealIngredient(name: "Kidneybohnen", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Chili", amount: 2, unit: "Stück"),
            MealIngredient(name: "Mais", amount: 200, unit: "g"),
        ],
        "tacos": [
            MealIngredient(name: "Taco-Schalen", amount: 8, unit: "Stück"),
            MealIngredient(name: "Hackfleisch", amount: 500, unit: "g"),
            MealIngredient(name: "Käse", amount: 150, unit: "g"),
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomate", amount: 2, unit: "Stück"),
            MealIngredient(name: "Sauerrahm", amount: 200, unit: "g"),
        ],
        "wraps": [
            MealIngredient(name: "Tortillas", amount: 8, unit: "Stück"),
            MealIngredient(name: "Hähnchenbrust", amount: 500, unit: "g"),
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Joghurt", amount: 150, unit: "g"),
        ],
        "wrap": [
            MealIngredient(name: "Tortillas", amount: 4, unit: "Stück"),
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomate", amount: 2, unit: "Stück"),
            MealIngredient(name: "Käse", amount: 150, unit: "g"),
        ],
        "burrito": [
            MealIngredient(name: "Tortillas", amount: 4, unit: "Stück"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
            MealIngredient(name: "Bohnen", amount: 400, unit: "g"),
            MealIngredient(name: "Hackfleisch", amount: 500, unit: "g"),
            MealIngredient(name: "Käse", amount: 150, unit: "g"),
            MealIngredient(name: "Sauerrahm", amount: 200, unit: "g"),
            MealIngredient(name: "Salsa", amount: 200, unit: "g"),
        ],
        "quesadilla": [
            MealIngredient(name: "Tortillas", amount: 8, unit: "Stück"),
            MealIngredient(name: "Käse", amount: 300, unit: "g"),
            MealIngredient(name: "Hähnchen", amount: 400, unit: "g"),
            MealIngredient(name: "Paprika", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Sauerrahm", amount: 150, unit: "g"),
        ],
        "fajitas": [
            MealIngredient(name: "Hähnchenbrust", amount: 600, unit: "g"),
            MealIngredient(name: "Paprika", amount: 3, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Tortillas", amount: 8, unit: "Stück"),
            MealIngredient(name: "Sauerrahm", amount: 150, unit: "g"),
            MealIngredient(name: "Guacamole", amount: 200, unit: "g"),
        ],
        "nachos": [
            MealIngredient(name: "Nachos", amount: 250, unit: "g"),
            MealIngredient(name: "Käsesoße", amount: 200, unit: "g"),
            MealIngredient(name: "Jalapeños", amount: 50, unit: "g"),
            MealIngredient(name: "Sauerrahm", amount: 150, unit: "g"),
            MealIngredient(name: "Guacamole", amount: 200, unit: "g"),
            MealIngredient(name: "Salsa", amount: 200, unit: "g"),
        ],
        "guacamole": [
            MealIngredient(name: "Avocados", amount: 3, unit: "Stück"),
            MealIngredient(name: "Limette", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 1, unit: "Stück"),
            MealIngredient(name: "Koriander", amount: 1, unit: "Bund"),
            MealIngredient(name: "Chili", amount: 1, unit: "Stück"),
        ],
        // Suppen
        "suppe": [
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 100, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Nudeln", amount: 100, unit: "g"),
        ],
        "gemüsesuppe": [
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 150, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Erbsen", amount: 150, unit: "g"),
        ],
        "tomatensuppe": [
            MealIngredient(name: "Tomaten", amount: 800, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
            MealIngredient(name: "Sahne", amount: 100, unit: "ml"),
        ],
        "kartoffelsuppe": [
            MealIngredient(name: "Kartoffeln", amount: 800, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Speck", amount: 100, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Sahne", amount: 100, unit: "ml"),
        ],
        "erbsensuppe": [
            MealIngredient(name: "Erbsen", amount: 500, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Speck", amount: 100, unit: "g"),
            MealIngredient(name: "Kartoffeln", amount: 300, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
        ],
        "linsensuppe": [
            MealIngredient(name: "Linsen", amount: 300, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Möhren", amount: 150, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 100, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Speck", amount: 100, unit: "g"),
        ],
        "kürbissuppe": [
            MealIngredient(name: "Hokkaido-Kürbis", amount: 1000, unit: "g"),
            MealIngredient(name: "Brühe", amount: 500, unit: "ml"),
            MealIngredient(name: "Sahne", amount: 100, unit: "ml"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Kokosmilch", amount: 200, unit: "ml"),
        ],
        "zwiebelsuppe": [
            MealIngredient(name: "Zwiebeln", amount: 4, unit: "Stück"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Weißwein", amount: 100, unit: "ml"),
            MealIngredient(name: "Baguette", amount: 1, unit: "Stück"),
            MealIngredient(name: "Gruyère", amount: 150, unit: "g"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
        ],
        "minestrone": [
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 150, unit: "g"),
            MealIngredient(name: "Zucchini", amount: 200, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Kidneybohnen", amount: 400, unit: "g"),
            MealIngredient(name: "Nudeln", amount: 150, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
        ],
        "hühnersuppe": [
            MealIngredient(name: "Hähnchen", amount: 600, unit: "g"),
            MealIngredient(name: "Brühe", amount: 1500, unit: "ml"),
            MealIngredient(name: "Möhren", amount: 200, unit: "g"),
            MealIngredient(name: "Sellerie", amount: 150, unit: "g"),
            MealIngredient(name: "Nudeln", amount: 150, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
        ],
        "rote bete suppe": [
            MealIngredient(name: "Rote Bete", amount: 600, unit: "g"),
            MealIngredient(name: "Brühe", amount: 800, unit: "ml"),
            MealIngredient(name: "Sahne", amount: 100, unit: "ml"),
            MealIngredient(name: "Apfel", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
        ],
        // Vegetarisch & Vegan
        "falafel": [
            MealIngredient(name: "Kichererbsen", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Kreuzkümmel", amount: 1, unit: "TL"),
            MealIngredient(name: "Koriander", amount: 1, unit: "Bund"),
            MealIngredient(name: "Mehl", amount: 2, unit: "EL"),
        ],
        "hummus": [
            MealIngredient(name: "Kichererbsen", amount: 400, unit: "g"),
            MealIngredient(name: "Tahini", amount: 3, unit: "EL"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 1, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 4, unit: "EL"),
        ],
        "tofu pfanne": [
            MealIngredient(name: "Tofu", amount: 400, unit: "g"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Brokkoli", amount: 300, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
            MealIngredient(name: "Ingwer", amount: 20, unit: "g"),
            MealIngredient(name: "Sesamöl", amount: 2, unit: "EL"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
        ],
        "quinoa bowl": [
            MealIngredient(name: "Quinoa", amount: 250, unit: "g"),
            MealIngredient(name: "Avocado", amount: 1, unit: "Stück"),
            MealIngredient(name: "Kichererbsen", amount: 400, unit: "g"),
            MealIngredient(name: "Gurke", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 2, unit: "Stück"),
            MealIngredient(name: "Spinat", amount: 150, unit: "g"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
        ],
        "buddha bowl": [
            MealIngredient(name: "Süßkartoffeln", amount: 600, unit: "g"),
            MealIngredient(name: "Kichererbsen", amount: 400, unit: "g"),
            MealIngredient(name: "Avocado", amount: 1, unit: "Stück"),
            MealIngredient(name: "Spinat", amount: 150, unit: "g"),
            MealIngredient(name: "Quinoa", amount: 200, unit: "g"),
            MealIngredient(name: "Tahini", amount: 3, unit: "EL"),
        ],
        "vegane bolognese": [
            MealIngredient(name: "Linsen", amount: 300, unit: "g"),
            MealIngredient(name: "Nudeln", amount: 400, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 2, unit: "EL"),
            MealIngredient(name: "Hefeflocken", amount: 3, unit: "EL"),
        ],
        "ratatouille": [
            MealIngredient(name: "Zucchini", amount: 2, unit: "Stück"),
            MealIngredient(name: "Aubergine", amount: 2, unit: "Stück"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
            MealIngredient(name: "Kräuter", amount: 1, unit: "TL"),
        ],
        "shakshuka": [
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 800, unit: "g"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Knoblauch", amount: 2, unit: "Zehe"),
            MealIngredient(name: "Kreuzkümmel", amount: 1, unit: "TL"),
            MealIngredient(name: "Paprikapulver", amount: 1, unit: "TL"),
        ],
        "käsespätzle": [
            MealIngredient(name: "Spätzle", amount: 500, unit: "g"),
            MealIngredient(name: "Bergkäse", amount: 200, unit: "g"),
            MealIngredient(name: "Zwiebeln", amount: 2, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 40, unit: "g"),
        ],
        // Salate
        "salat": [
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 2, unit: "Stück"),
            MealIngredient(name: "Gurken", amount: 1, unit: "Stück"),
            MealIngredient(name: "Olivenöl", amount: 3, unit: "EL"),
            MealIngredient(name: "Essig", amount: 1, unit: "EL"),
        ],
        "caesar salad": [
            MealIngredient(name: "Römersalat", amount: 2, unit: "Stück"),
            MealIngredient(name: "Parmesan", amount: 50, unit: "g"),
            MealIngredient(name: "Croutons", amount: 100, unit: "g"),
            MealIngredient(name: "Caesar Dressing", amount: 150, unit: "ml"),
            MealIngredient(name: "Hähnchenbrust", amount: 400, unit: "g"),
        ],
        "griechischer salat": [
            MealIngredient(name: "Tomaten", amount: 3, unit: "Stück"),
            MealIngredient(name: "Gurken", amount: 1, unit: "Stück"),
            MealIngredient(name: "Oliven", amount: 100, unit: "g"),
            MealIngredient(name: "Feta", amount: 200, unit: "g"),
            MealIngredient(name: "Paprika", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Olivenöl", amount: 4, unit: "EL"),
        ],
        // Frühstück & Brunch
        "pfannkuchen": [
            MealIngredient(name: "Mehl", amount: 250, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Milch", amount: 400, unit: "ml"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Zucker", amount: 1, unit: "EL"),
        ],
        "pancakes": [
            MealIngredient(name: "Mehl", amount: 250, unit: "g"),
            MealIngredient(name: "Eier", amount: 2, unit: "Stück"),
            MealIngredient(name: "Milch", amount: 350, unit: "ml"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
            MealIngredient(name: "Zucker", amount: 2, unit: "EL"),
        ],
        "rührei": [
            MealIngredient(name: "Eier", amount: 8, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Schnittlauch", amount: 1, unit: "Bund"),
            MealIngredient(name: "Salz", amount: 1, unit: "Prise"),
        ],
        "spiegelei": [
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 20, unit: "g"),
            MealIngredient(name: "Salz", amount: 1, unit: "Prise"),
        ],
        "omelette": [
            MealIngredient(name: "Eier", amount: 6, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Käse", amount: 100, unit: "g"),
            MealIngredient(name: "Schnittlauch", amount: 1, unit: "Bund"),
        ],
        "müsli": [
            MealIngredient(name: "Haferflocken", amount: 200, unit: "g"),
            MealIngredient(name: "Milch", amount: 400, unit: "ml"),
            MealIngredient(name: "Banane", amount: 2, unit: "Stück"),
            MealIngredient(name: "Beeren", amount: 200, unit: "g"),
            MealIngredient(name: "Nüsse", amount: 50, unit: "g"),
            MealIngredient(name: "Honig", amount: 2, unit: "EL"),
        ],
        "porridge": [
            MealIngredient(name: "Haferflocken", amount: 200, unit: "g"),
            MealIngredient(name: "Milch", amount: 600, unit: "ml"),
            MealIngredient(name: "Banane", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zimt", amount: 1, unit: "TL"),
            MealIngredient(name: "Honig", amount: 2, unit: "EL"),
        ],
        "haferbrei": [
            MealIngredient(name: "Haferflocken", amount: 200, unit: "g"),
            MealIngredient(name: "Milch", amount: 600, unit: "ml"),
            MealIngredient(name: "Zucker", amount: 2, unit: "EL"),
            MealIngredient(name: "Zimt", amount: 1, unit: "TL"),
        ],
        "overnight oats": [
            MealIngredient(name: "Haferflocken", amount: 200, unit: "g"),
            MealIngredient(name: "Milch", amount: 400, unit: "ml"),
            MealIngredient(name: "Joghurt", amount: 200, unit: "g"),
            MealIngredient(name: "Chiasamen", amount: 2, unit: "EL"),
            MealIngredient(name: "Früchte", amount: 200, unit: "g"),
        ],
        "granola": [
            MealIngredient(name: "Haferflocken", amount: 300, unit: "g"),
            MealIngredient(name: "Honig", amount: 100, unit: "g"),
            MealIngredient(name: "Nüsse", amount: 100, unit: "g"),
            MealIngredient(name: "Kokosöl", amount: 3, unit: "EL"),
            MealIngredient(name: "Trockenfrüchte", amount: 100, unit: "g"),
        ],
        "avocado toast": [
            MealIngredient(name: "Brot", amount: 4, unit: "Stück"),
            MealIngredient(name: "Avocado", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zitrone", amount: 1, unit: "Stück"),
            MealIngredient(name: "Chili", amount: 1, unit: "Prise"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
        ],
        "french toast": [
            MealIngredient(name: "Toastbrot", amount: 8, unit: "Stück"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Milch", amount: 200, unit: "ml"),
            MealIngredient(name: "Zimt", amount: 1, unit: "TL"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Ahornsirup", amount: 4, unit: "EL"),
        ],
        "smoothie bowl": [
            MealIngredient(name: "Gefrorene Beeren", amount: 400, unit: "g"),
            MealIngredient(name: "Banane", amount: 2, unit: "Stück"),
            MealIngredient(name: "Joghurt", amount: 200, unit: "g"),
            MealIngredient(name: "Granola", amount: 100, unit: "g"),
            MealIngredient(name: "Früchte", amount: 200, unit: "g"),
        ],
        "sandwich": [
            MealIngredient(name: "Toastbrot", amount: 8, unit: "Stück"),
            MealIngredient(name: "Aufschnitt", amount: 200, unit: "g"),
            MealIngredient(name: "Käse", amount: 150, unit: "g"),
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomate", amount: 1, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
        ],
        "toast": [
            MealIngredient(name: "Toastbrot", amount: 8, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 30, unit: "g"),
            MealIngredient(name: "Aufschnitt", amount: 150, unit: "g"),
            MealIngredient(name: "Käse", amount: 100, unit: "g"),
        ],
        // Backen
        "brot": [
            MealIngredient(name: "Mehl", amount: 500, unit: "g"),
            MealIngredient(name: "Hefe", amount: 1, unit: "Stück"),
            MealIngredient(name: "Wasser", amount: 300, unit: "ml"),
            MealIngredient(name: "Salz", amount: 1, unit: "TL"),
        ],
        "brötchen": [
            MealIngredient(name: "Mehl", amount: 500, unit: "g"),
            MealIngredient(name: "Hefe", amount: 1, unit: "Stück"),
            MealIngredient(name: "Wasser", amount: 300, unit: "ml"),
            MealIngredient(name: "Salz", amount: 1, unit: "TL"),
            MealIngredient(name: "Butter", amount: 20, unit: "g"),
        ],
        "bananenbrot": [
            MealIngredient(name: "Bananen", amount: 3, unit: "Stück"),
            MealIngredient(name: "Mehl", amount: 300, unit: "g"),
            MealIngredient(name: "Eier", amount: 2, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 100, unit: "g"),
            MealIngredient(name: "Zucker", amount: 100, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        "muffins": [
            MealIngredient(name: "Mehl", amount: 250, unit: "g"),
            MealIngredient(name: "Eier", amount: 2, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 100, unit: "g"),
            MealIngredient(name: "Zucker", amount: 150, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
            MealIngredient(name: "Milch", amount: 100, unit: "ml"),
        ],
        "apfelkuchen": [
            MealIngredient(name: "Äpfel", amount: 4, unit: "Stück"),
            MealIngredient(name: "Mehl", amount: 300, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Butter", amount: 150, unit: "g"),
            MealIngredient(name: "Zucker", amount: 150, unit: "g"),
            MealIngredient(name: "Zimt", amount: 1, unit: "TL"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        "käsekuchen": [
            MealIngredient(name: "Quark", amount: 500, unit: "g"),
            MealIngredient(name: "Eier", amount: 4, unit: "Stück"),
            MealIngredient(name: "Zucker", amount: 150, unit: "g"),
            MealIngredient(name: "Butter", amount: 100, unit: "g"),
            MealIngredient(name: "Mehl", amount: 100, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        "brownies": [
            MealIngredient(name: "Schokolade", amount: 200, unit: "g"),
            MealIngredient(name: "Butter", amount: 150, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Zucker", amount: 200, unit: "g"),
            MealIngredient(name: "Mehl", amount: 100, unit: "g"),
            MealIngredient(name: "Kakao", amount: 30, unit: "g"),
        ],
        "cookies": [
            MealIngredient(name: "Mehl", amount: 300, unit: "g"),
            MealIngredient(name: "Butter", amount: 150, unit: "g"),
            MealIngredient(name: "Zucker", amount: 150, unit: "g"),
            MealIngredient(name: "Eier", amount: 1, unit: "Stück"),
            MealIngredient(name: "Schokoladenstücke", amount: 150, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        "waffel": [
            MealIngredient(name: "Mehl", amount: 250, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Milch", amount: 400, unit: "ml"),
            MealIngredient(name: "Butter", amount: 100, unit: "g"),
            MealIngredient(name: "Zucker", amount: 50, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        "waffeln": [
            MealIngredient(name: "Mehl", amount: 250, unit: "g"),
            MealIngredient(name: "Eier", amount: 3, unit: "Stück"),
            MealIngredient(name: "Milch", amount: 400, unit: "ml"),
            MealIngredient(name: "Butter", amount: 100, unit: "g"),
            MealIngredient(name: "Zucker", amount: 50, unit: "g"),
            MealIngredient(name: "Backpulver", amount: 1, unit: "TL"),
        ],
        // Weitere Klassiker
        "reis": [
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
            MealIngredient(name: "Butter", amount: 20, unit: "g"),
            MealIngredient(name: "Salz", amount: 1, unit: "Prise"),
        ],
        "paella": [
            MealIngredient(name: "Paellareis", amount: 400, unit: "g"),
            MealIngredient(name: "Hähnchen", amount: 500, unit: "g"),
            MealIngredient(name: "Garnelen", amount: 300, unit: "g"),
            MealIngredient(name: "Paprika", amount: 2, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 2, unit: "Stück"),
            MealIngredient(name: "Safran", amount: 1, unit: "Prise"),
            MealIngredient(name: "Brühe", amount: 1000, unit: "ml"),
            MealIngredient(name: "Erbsen", amount: 150, unit: "g"),
        ],
        "moussaka": [
            MealIngredient(name: "Auberginen", amount: 3, unit: "Stück"),
            MealIngredient(name: "Hackfleisch", amount: 500, unit: "g"),
            MealIngredient(name: "Tomaten", amount: 400, unit: "g"),
            MealIngredient(name: "Béchamelsauce", amount: 400, unit: "ml"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Zimt", amount: 1, unit: "TL"),
        ],
        "döner bowl": [
            MealIngredient(name: "Hähnchen", amount: 600, unit: "g"),
            MealIngredient(name: "Joghurt", amount: 200, unit: "g"),
            MealIngredient(name: "Gurken", amount: 1, unit: "Stück"),
            MealIngredient(name: "Tomaten", amount: 2, unit: "Stück"),
            MealIngredient(name: "Zwiebeln", amount: 1, unit: "Stück"),
            MealIngredient(name: "Fladenbrot", amount: 4, unit: "Stück"),
            MealIngredient(name: "Salat", amount: 1, unit: "Stück"),
        ],
        "poke bowl": [
            MealIngredient(name: "Thunfisch", amount: 400, unit: "g"),
            MealIngredient(name: "Reis", amount: 300, unit: "g"),
            MealIngredient(name: "Avocado", amount: 1, unit: "Stück"),
            MealIngredient(name: "Gurke", amount: 1, unit: "Stück"),
            MealIngredient(name: "Edamame", amount: 200, unit: "g"),
            MealIngredient(name: "Sojasoße", amount: 3, unit: "EL"),
            MealIngredient(name: "Sesamöl", amount: 2, unit: "EL"),
        ],
    ]

    static func ingredients(for meal: String) -> [MealIngredient] {
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
