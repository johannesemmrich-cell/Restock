import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]
    @Query private var allRecords: [PurchaseRecord]

    /// Vorausgewählter Store, wenn diese Ansicht aus einer `StoreDetailView` heraus geöffnet
    /// wurde (der "+"-Button dort) — der Aufenthalt im Laden ist ein stärkeres, explizites
    /// Signal als jede Namens-basierte Inferenz und darf nicht von `autoAssign` überschrieben
    /// werden (siehe dort). `nil`, wenn von HomeView aus geöffnet — dort gibt es bewusst keinen
    /// Store-Kontext.
    let presetStore: Store?

    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = ""
    /// Herkunft der Menge (Issue #57), siehe `ShoppingItem.quantitySource`.
    @State private var quantitySource = "user"
    /// Hat der Nutzer Menge oder Einheit selbst angefasst? Nur dann ist die Vorbelegung tabu —
    /// eine eigene, noch unberührte Vorbelegung wird bei jeder Namensänderung neu bewertet.
    @State private var quantityTouchedByUser = false
    @State private var selectedStore: Store?
    @State private var autoAssigned = false
    @State private var note = ""
    /// Selbst gewählte Kategorie (Issue #85); `nil` = automatisch (gemerkte eigene Kategorie des
    /// Ladens, sonst aus dem Namen).
    @State private var chosenCategory: String?
    @State private var showScanner = false
    @FocusState private var isNameFocused: Bool

    init(presetStore: Store? = nil) {
        self.presetStore = presetStore
        _selectedStore = State(initialValue: presetStore)
    }

    private var duplicateWarning: String? {
        guard let store = selectedStore, !name.isEmpty else { return nil }
        let nameLower = name.lowercased()
        guard nameLower.count >= 3 else { return nil }
        let match = store.pendingItems.first { item in
            let n = item.name.lowercased()
            return n == nameLower || (n.count >= 3 && (n.contains(nameLower) || nameLower.contains(n)))
        }
        return match.map { "'\($0.name)' ist bereits in der Liste" }
    }

    /// Bindings für manuelle Eingaben: jedes Schreiben macht die Menge zur eigenen des Nutzers.
    /// Bewusst kein `.onChange(of: quantity)` — das würde die eigene Vorbelegung im selben
    /// Update-Zyklus sofort wieder auf `"user"` zurücksetzen (Spec #57, Implementation Details 1b).
    private var userQuantity: Binding<String> {
        Binding(get: { quantity }, set: { quantity = $0; quantitySource = "user"; quantityTouchedByUser = true })
    }

    private var userUnit: Binding<String> {
        Binding(get: { unit }, set: { unit = $0; quantitySource = "user"; quantityTouchedByUser = true })
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var automaticCategory: String {
        selectedStore?.rememberedCategory(forItemNamed: trimmedName) ?? AssignmentService.category(for: trimmedName)
    }

    private var effectiveCategory: String { chosenCategory ?? automaticCategory }

    private var categoryLabel: String {
        let category = effectiveCategory
        let title: String
        if let store = selectedStore, store.isCustomCategory(category) {
            title = "\(store.categoryEmoji(category)) \(category)"
        } else {
            title = "\(AssignmentService.categoryEmoji(category)) \(AssignmentService.displayCategory(category))"
        }
        return chosenCategory == nil ? "\(String(localized: "category.picker.automatic")): \(title)" : title
    }

    private var nameSuggestions: [String] {
        QuickAddParser.knownProductSuggestions(for: name, in: allRecords, itemNames: activeStores.flatMap { $0.items ?? [] }.map(\.name))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(String(localized: "item.name.placeholder"), text: $name)
                            .focused($isNameFocused)
                            .onChange(of: name) { _, newValue in
                                if !newValue.isEmpty { autoAssign(name: newValue) }
                            }
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.pressable)
                    }

                    if isNameFocused {
                        ProductSuggestionChips(suggestions: nameSuggestions, tint: Color.accent) { picked in
                            name = picked
                        }
                    }

                    HStack(spacing: 6) {
                        QuantityStepperField(quantity: userQuantity, unit: userUnit)
                            .fixedSize()
                        TextField(String(localized: "item.unit.placeholder"), text: userUnit)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hairline))
                        Spacer()
                    }

                    TextField(String(localized: "item.note.placeholder"), text: $note)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "item.category.section")) {
                    NavigationLink {
                        CategoryPickerView(
                            store: selectedStore,
                            selection: Binding(get: { effectiveCategory }, set: { chosenCategory = $0 }),
                            automaticCategory: AssignmentService.category(for: trimmedName)
                        )
                    } label: {
                        HStack {
                            Text(String(localized: "item.category.section"))
                            Spacer()
                            Text(categoryLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityIdentifier("item.categoryRow")
                }

                if let warning = duplicateWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                }

                Section(header: Text(String(localized: "item.store.section"))) {
                    if autoAssigned {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                                .font(.system(size: 13))
                            Text(String(localized: "item.store.auto"))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(activeStores) { store in
                        HStack {
                            Text(store.emoji)
                            Text(store.name)
                            Spacer()
                            if selectedStore?.id == store.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accent)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStore = store
                            autoAssigned = false
                        }
                    }
                    HStack {
                        Text("–")
                        Text(String(localized: "item.store.none"))
                        Spacer()
                        if selectedStore == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accent)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedStore = nil
                        autoAssigned = false
                    }
                }
            }
            .navigationTitle(String(localized: "item.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip() }
                        .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { addItem() } label: { Text(String(localized: "action.add")).toolbarChip(prominent: true) }
                        .buttonStyle(.pressable)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { _, productName in
                if let productName {
                    name = productName
                    autoAssign(name: productName)
                }
            }
        }
        // Eine eigene Kategorie gilt nur in ihrem Laden (Issue #85).
        .onChange(of: selectedStore?.id) {
            if let chosen = chosenCategory, AssignmentService.categoryOrder.contains(chosen) == false,
               selectedStore?.isCustomCategory(chosen) != true {
                chosenCategory = nil
            }
        }
        .devFeedback(context: "Artikel hinzufügen")
    }

    private func autoAssign(name: String) {
        // Ein vorausgewählter Store (aus StoreDetailView geöffnet) ist ein stärkeres Signal als
        // jede Namens-Inferenz — nie überschreiben, auch nicht bei einem erkannten Artikelnamen.
        guard presetStore == nil else {
            applySuggestedQuantity(for: name)
            return
        }
        let store = AssignmentService.assign(itemName: name, to: activeStores, purchaseRecords: allRecords)
        if store != nil {
            selectedStore = store
            autoAssigned = true
        }
        applySuggestedQuantity(for: name)
    }

    /// Mengen-Vorbelegung (Issue #57): eine selbst eingetippte Menge oder Einheit wird nie
    /// überschrieben (F002), sonst entscheidet `AssignmentService.suggestQuantity` bei jeder
    /// Namensänderung neu — eine Vorbelegung aus einem Zwischenstand („Milch" auf dem Weg zu
    /// „Milchreis") bleibt so nicht hängen (F001). Schreibt direkt auf die `@State`-Variablen,
    /// nicht über die berechneten Bindings — die Vorbelegung ist keine Nutzereingabe.
    private func applySuggestedQuantity(for name: String) {
        guard !quantityTouchedByUser else { return }
        let suggestion = AssignmentService.suggestQuantity(
            itemName: name, storeName: selectedStore?.name ?? "", purchaseRecords: allRecords
        )
        quantity = suggestion.quantity
        unit = suggestion.unit
        quantitySource = suggestion.source
    }

    private func addItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let category = AssignmentService.category(for: trimmedName)
        let rawQty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        let qtyAmount = (rawQty > 0 && !rawQty.isNaN) ? rawQty : 1
        let item = ShoppingItem(
            name: trimmedName,
            category: category,
            quantity: quantity.isEmpty ? "1" : quantity,
            quantityAmount: qtyAmount,
            unit: unit,
            note: note,
            store: selectedStore,
            quantitySource: quantitySource
        )
        if let chosen = chosenCategory {
            item.category = chosen
            item.categoryManuallySet = chosen != category
            selectedStore?.rememberCategory(chosen, forItemNamed: trimmedName)
        }
        context.insert(item)
        SyncCoordinator.shared.pushInBackground(selectedStore)
        dismiss()
    }
}
