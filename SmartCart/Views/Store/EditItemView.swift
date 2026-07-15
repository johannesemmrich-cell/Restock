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
    @State private var showDeleteConfirm = false

    init(item: ShoppingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit)
        _note = State(initialValue: item.note)
        _selectedStore = State(initialValue: item.store)
        _assignedTo = State(initialValue: item.assignedTo)
        if let price = item.estimatedPrice {
            _priceText = State(initialValue: String(format: "%.2f", price).replacingOccurrences(of: ".", with: ","))
        } else {
            _priceText = State(initialValue: "")
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
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "eurosign.circle")
                            .foregroundStyle(.secondary)
                        TextField("Preis (optional)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.note.placeholder"), text: $note)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        save()
                    }
                    .fontWeight(.semibold)
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
        item.unit = unit
        item.note = note
        let oldStore = item.store
        let itemID = item.id
        let movedToAnotherStore = oldStore?.id != selectedStore?.id
        item.store = selectedStore
        item.assignedTo = selectedStore?.shareID != nil ? assignedTo : ""
        item.lastModified = Date()

        let rawPrice = priceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let p = Double(rawPrice), p > 0 {
            item.estimatedPrice = p
        } else if rawPrice.isEmpty {
            item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category)
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
