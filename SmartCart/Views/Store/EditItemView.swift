import SwiftUI
import SwiftData
import UIKit

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

    @State private var stagedPhotoData: Data?
    @State private var photoChanged = false
    @State private var isLoadingPhoto = false
    /// A single `.sheet(item:)` driven by this, instead of two sibling `.sheet(isPresented:)`
    /// modifiers (one per source), which is a known SwiftUI pitfall: with two independent
    /// `isPresented` bindings on the same view, the system can present the wrong one (observed:
    /// tapping "Aus Bibliothek" opened the camera instead). One optional item makes "which picker,
    /// if any" a single source of truth.
    @State private var activePickerSource: ItemPhotoPickerSource?
    @State private var showFullScreenPhoto = false

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
        _stagedPhotoData = State(initialValue: item.photoData)
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

                photoSection

                Section(String(localized: "item.category.section")) {
                    Picker(String(localized: "item.category.section"), selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text("\(AssignmentService.categoryEmoji(cat)) \(AssignmentService.displayCategory(cat))").tag(cat)
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
                        .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text(String(localized: "action.save")).toolbarChip(prominent: true) }
                    .buttonStyle(.pressable)
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
        .sheet(item: $activePickerSource) { source in
            ItemPhotoPicker(sourceType: source.uiKitSourceType) { image in
                guard let image, let data = PhotoCompressor.compress(image) else { return }
                stagedPhotoData = data
                photoChanged = true
            }
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let stagedPhotoData, let uiImage = UIImage(data: stagedPhotoData) {
                FullScreenPhotoView(image: uiImage) { showFullScreenPhoto = false }
            }
        }
        .task { await loadRemotePhotoIfNeeded() }
    }

    /// A device that only knows a photo exists (`hasPhoto == true`, synced via the hot-path
    /// `itemsJSON` flag) but hasn't downloaded the bytes yet fetches them here — lazily, once,
    /// on opening the sheet. Never runs on a timer, never touches `item.lastModified` (that would
    /// falsely make this item "win" a future last-write-wins merge against a real edit elsewhere).
    private func loadRemotePhotoIfNeeded() async {
        guard stagedPhotoData == nil, item.hasPhoto, let shareID = selectedStore?.shareID else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await SharedItemPhotoService.shared.pull(itemID: item.id) else { return }
        await MainActor.run {
            item.photoData = data
            item.photoLastModified = Date()
            try? context.save()
            stagedPhotoData = data
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        Section(String(localized: "item.photo.section")) {
            if let stagedPhotoData, let uiImage = UIImage(data: stagedPhotoData) {
                HStack {
                    // `.contentShape`/`.onTapGesture` scoped to just the thumbnail, and both
                    // buttons given an explicit `.buttonStyle` — inside a Form row, a plain
                    // `Image` next to un-styled `Button`s can otherwise have its taps misrouted
                    // to one of the buttons (observed: tapping the thumbnail deleted the photo
                    // instead of opening it).
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .onTapGesture { showFullScreenPhoto = true }
                    Spacer()
                    Button(String(localized: "item.photo.replace")) { activePickerSource = .library }
                        .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        self.stagedPhotoData = nil
                        photoChanged = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            } else if isLoadingPhoto {
                HStack {
                    ProgressView()
                    Text(String(localized: "item.photo.loading"))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            activePickerSource = .camera
                        } label: {
                            Label(String(localized: "item.photo.camera"), systemImage: "camera")
                        }
                        .buttonStyle(.borderless)
                    }
                    Button {
                        activePickerSource = .library
                    } label: {
                        Label(String(localized: "item.photo.library"), systemImage: "photo")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
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

        if photoChanged {
            item.photoData = stagedPhotoData
            item.hasPhoto = stagedPhotoData != nil
            item.photoLastModified = Date()
        }

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
                item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
                item.estimatedPriceIsAutoDerived = true
            }
        } else if oldUnit != unit, item.estimatedPriceIsAutoDerived {
            // The price field itself wasn't touched, but the unit was — and this price is still
            // just the catalog/category estimate, so it's safe to recompute for the new unit
            // (e.g. "" → "g" needs the per-gram rate, not the per-package rate). A learned or
            // manually-entered price (estimatedPriceIsAutoDerived == false) is left untouched here,
            // even if it would numerically collide with the old-unit formula.
            item.estimatedPrice = PriceEstimator.estimate(for: item.name, category: item.category, unit: item.unit, quantityAmount: item.quantityAmount)
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

        // Cross-account photo transport runs separately from `syncPush` above — a distinct actor,
        // a distinct CKRecord type, fired only when the user actually changed the photo. Never
        // part of the `itemsJSON` hot path (see `SharedItemPhotoService`).
        if photoChanged, let shareID = selectedStore?.shareID {
            let photoToUpload = stagedPhotoData
            Task {
                if let photoToUpload {
                    try? await SharedItemPhotoService.shared.push(itemID: itemID, shareID: shareID, data: photoToUpload)
                } else {
                    await SharedItemPhotoService.shared.delete(itemID: itemID)
                }
            }
        }
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
            // Best-effort — no-op if this item never had a `SharedItemPhoto` record. Prevents an
            // orphaned CKAsset record from lingering in the public DB forever after the item itself
            // is gone.
            await SharedItemPhotoService.shared.delete(itemID: itemID)
        }
    }
}
