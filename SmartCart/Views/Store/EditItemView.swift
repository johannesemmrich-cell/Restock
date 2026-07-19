import SwiftUI
import SwiftData

struct EditItemView: View {
    @Bindable var item: ShoppingItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }) private var activeStores: [Store]

    @State private var name: String
    @State private var quantity: String
    @State private var unit: String
    @State private var note: String
    @State private var priceText: String
    @State private var selectedStore: Store?
    @State private var assignedTo: String
    @State private var category: String
    @State private var showDeleteConfirm = false

    /// The exact string `priceText` was seeded with in `init`, so `save()` can tell whether the
    /// user actually edited the price field (vs. just changing quantity elsewhere in the sheet,
    /// which must not cause the still-correct per-unit `estimatedPrice` to be recomputed from a
    /// now-stale displayed total).
    private let initialPriceText: String

    /// The canonical category list, plus the item's current category if it's a stale/legacy
    /// value not present in `AssignmentService.categoryOrder` — so the Picker always has a
    /// matching option for `category` and never falls back to an unselected/blank state.
    /// Sorted alphabetically (locale-aware) for easier scanning in the Picker; the aisle
    /// order of `AssignmentService.categoryOrder` itself stays untouched for grouped lists.
    private var availableCategories: [String] {
        var categories = AssignmentService.categoryOrder
        if !category.isEmpty, !categories.contains(category) {
            categories.append(category)
        }
        return categories.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    init(item: ShoppingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit)
        _note = State(initialValue: item.note)
        _selectedStore = State(initialValue: item.store)
        _assignedTo = State(initialValue: item.assignedTo)
        _category = State(initialValue: item.category)
        // `item.estimatedPrice` is stored per-unit, but the field here shows/accepts the TOTAL
        // for this line (matching what a user would read off a receipt for e.g. a 6-pack),
        // so scale by quantity for display and divide back out again in `save()`.
        if let total = item.estimatedLineTotal {
            let text = String(format: "%.2f", total).replacingOccurrences(of: ".", with: ",")
            _priceText = State(initialValue: text)
            initialPriceText = text
        } else {
            _priceText = State(initialValue: "")
            initialPriceText = ""
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "item.details.section")) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.name.placeholder"), text: $name)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        QuantityStepperField(quantity: $quantity, unit: $unit)
                            .fixedSize()
                        TextField(String(localized: "item.unit.placeholder"), text: $unit)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hairline))
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "eurosign.circle")
                                .foregroundStyle(.secondary)
                            TextField("Preis (optional)", text: $priceText)
                                .keyboardType(.decimalPad)
                        }
                        Text("Gesamtpreis für die angegebene Menge")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 28)
                    }

                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.note.placeholder"), text: $note)
                    }
                }

                Section("Kategorie") {
                    Picker("Kategorie", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text("\(AssignmentService.categoryEmoji(cat)) \(cat)").tag(cat)
                        }
                    }
                }

                Section(String(localized: "item.store.section")) {
                    ForEach(activeStores) { store in
                        HStack {
                            Text(store.emoji)
                            Text(store.name)
                            Spacer()
                            if selectedStore?.id == store.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(store.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectStore(store) }
                    }
                    HStack {
                        Text("–")
                        Text(String(localized: "item.store.none"))
                        Spacer()
                        if selectedStore == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectStore(nil) }
                }

                if let store = selectedStore, store.shareID != nil {
                    Section(String(localized: "item.assignedto.section")) {
                        HStack {
                            Text("–")
                            Text(String(localized: "item.assignedto.none"))
                            Spacer()
                            if assignedTo.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { assignedTo = "" }

                        ForEach(store.members, id: \.self) { member in
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(.indigo)
                                Text(member)
                                Spacer()
                                if assignedTo == member {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.indigo)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { assignedTo = member }
                        }
                    }
                }

                Section {
                    Button {
                        withAnimation {
                            if item.isCompleted { item.markPending() } else { item.markCompleted() }
                        }
                        Haptics.success()
                        dismiss()
                    } label: {
                        Label(
                            item.isCompleted
                                ? String(localized: "item.action.uncheck")
                                : String(localized: "item.action.check"),
                            systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                        )
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "item.action.delete"), systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "item.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(String(localized: "action.cancel")).toolbarChip() }
                        .buttonStyle(.plain)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text(String(localized: "action.save")).toolbarChip(prominent: true) }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                String(localized: "item.delete.confirm"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "item.action.delete"), role: .destructive) {
                    deleteItem()
                    dismiss()
                }
            }
        }
        .devFeedback(context: "Artikel bearbeiten")
    }

    /// Switching stores can invalidate the current assignment (the new store may not even be
    /// shared, or its member list may not include whoever the item was assigned to before).
    private func selectStore(_ store: Store?) {
        selectedStore = store
        guard let store, store.shareID != nil, store.members.contains(assignedTo) else {
            assignedTo = ""
            return
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity.isEmpty ? "1" : quantity
        let rawQty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        item.quantityAmount = (rawQty > 0 && !rawQty.isNaN) ? rawQty : 1
        let oldUnit = item.unit
        item.unit = unit
        item.note = note
        item.category = category
        // Only lock the category in as a manual override if the user actually picked something
        // different from what the name-based heuristic would auto-detect. If they left it on
        // the auto-detected value, keep it free to re-derive so future keyword-rule tweaks apply.
        item.categoryManuallySet = category != AssignmentService.category(for: item.name)
        let oldStore = item.store
        let itemID = item.id
        let movedToAnotherStore = oldStore?.id != selectedStore?.id
        item.store = selectedStore
        item.assignedTo = selectedStore?.shareID != nil ? assignedTo : ""
        item.lastModified = Date()

        // If the user never touched the price field — even if they changed the quantity elsewhere
        // in this same sheet — `priceText` is still showing the OLD total for the OLD quantity.
        // Re-deriving from it here would silently corrupt the still-correct per-unit
        // `estimatedPrice` (see bug: quantity 2→3 with an untouched "7,00" total must NOT turn
        // 3.50/unit into 2.33/unit). Only recompute when the displayed text actually changed.
        if priceText != initialPriceText {
            let rawPrice = priceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
            if let p = Double(rawPrice), p > 0 {
                // The field holds the TOTAL for this line (see init/UI hint above); `estimatedPrice`
                // is stored canonically per-unit, so divide the quantity back out before saving.
                item.estimatedPrice = item.quantityAmount > 0 ? p / item.quantityAmount : p
                // A manual entry gives the price a real-world origin — never auto-recompute it again.
                item.estimatedPriceIsAutoDerived = false
            } else if rawPrice.isEmpty {
                item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit)
                item.estimatedPriceIsAutoDerived = true
            }
        } else if oldUnit != unit, item.estimatedPriceIsAutoDerived {
            // The price field itself wasn't touched, but the unit was — and this price is still
            // just the catalog/category estimate, so it's safe to recompute for the new unit
            // (e.g. "" → "g" needs the per-gram rate, not the per-package rate). A learned or
            // manually-entered price (estimatedPriceIsAutoDerived == false) is left untouched here,
            // even if it would numerically collide with the old-unit formula.
            item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit)
        }

        Haptics.success()
        dismiss()

        if movedToAnotherStore, let oldStore, let oldShareID = oldStore.shareID {
            // The item just left this store's list — tombstone it there too, or the next
            // sync on `oldStore` will still find it in the remote snapshot and resurrect
            // a duplicate on every other member's device.
            Task {
                await SharedStoreService.shared.recordLocalDeletion(shareID: oldShareID, itemID: itemID)
                await SyncCoordinator.shared.push(store: oldStore)
            }
        }
        syncPush(selectedStore)
    }

    /// Uploads the edited list right away instead of waiting for the store's detail view to
    /// close, so edits (including moving an item to a different shared store) show up elsewhere quickly.
    private func syncPush(_ store: Store?) {
        guard let store, store.shareID != nil else { return }
        Task { await SyncCoordinator.shared.push(store: store) }
    }

    private func deleteItem() {
        let itemID = item.id
        let shareID = item.store?.shareID
        let store = item.store
        guard let shareID, let store else {
            context.delete(item)
            return
        }
        Task {
            // Tombstone before the local delete lands, so a periodic pull racing in between
            // can't see "gone locally, still present remotely" and resurrect it as new.
            await SharedStoreService.shared.recordLocalDeletion(shareID: shareID, itemID: itemID)
            await MainActor.run { context.delete(item) }
            await SyncCoordinator.shared.push(store: store)
        }
    }
}
