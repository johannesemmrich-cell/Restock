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
    /// Issue #234: In dieser Sitzung in der Auswahl gewählt (nur dann wird ein Gang gemerkt).
    @State private var categoryPicked = false
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
    @AppStorage("developerMode") private var developerMode = false

    /// The exact string `priceText` was seeded with in `init`, so `save()` can tell whether the
    /// user actually edited the price field (vs. just changing quantity elsewhere in the sheet,
    /// which must not cause the still-correct per-unit `estimatedPrice` to be recomputed from a
    /// now-stale displayed total).
    private let initialPriceText: String

    /// Anzeige der gewählten Kategorie: eigene Kategorien des gewählten Ladens (Issue #85) mit
    /// ihrem Emoji und Namen, feste mit dem lokalisierten Namen.
    /// Issue #234: gewählter oder aufgelöster Gang; `nil` = Sonstiges.
    private func currentStation(in store: Store) -> String? {
        if categoryPicked, store.isStationChoice(category) {
            return category == StoreCategories.otherStationMarker ? nil : category
        }
        return store.stationName(forItemNamed: name, category: category, manuallySet: item.categoryManuallySet)
    }

    /// Auswahl-Wert: in Läden mit Gängen der Gang bzw. die Marke, sonst die Kategorie.
    private var pickerSelection: Binding<String> {
        Binding(get: {
            guard let store = selectedStore, store.hasStations else { return category }
            return currentStation(in: store) ?? StoreCategories.otherStationMarker
        }, set: { category = $0; categoryPicked = true })
    }

    /// Nachziehen aus der Auswahl (F002): eine eigene Wahl folgt, sonst nur eine gespeicherte Handwahl,
    /// die `renameStation` schon umgeschrieben hat; `categoryPicked` wird nie neu gesetzt.
    private func followSelection(_ next: String) {
        if let followed = StoreCategories.followedChoice(categoryPicked ? category : nil, next: next) {
            category = followed
        } else if item.categoryManuallySet {
            category = item.category
        }
    }

    private var categoryLabel: String {
        if let store = selectedStore, store.hasStations {
            return currentStation(in: store).map { "\(store.stationEmoji($0)) \($0)" } ?? String(localized: "station.other")
        }
        if let store = selectedStore, store.isCustomCategory(category) {
            return "\(store.categoryEmoji(category)) \(category)"
        }
        return "\(AssignmentService.categoryEmoji(category)) \(AssignmentService.displayCategory(category))"
    }

    init(item: ShoppingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit)
        _note = State(initialValue: item.note)
        _selectedStore = State(initialValue: item.store)
        _assignedTo = State(initialValue: item.assignedTo)
        // Wie überall in der Liste: eine nicht von Hand gesetzte feste (oder leere) Kategorie gilt
        // aus dem Namen; eine von Hand gesetzte oder eigene bleibt.
        let keepsStoredCategory = item.categoryManuallySet
            || (!item.category.isEmpty && !AssignmentService.categoryOrder.contains(item.category))
        _category = State(initialValue: keepsStoredCategory ? item.category : AssignmentService.category(for: item.name))
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
                        // Issue #162: Spanne, typische Packung und Quelle des Katalogeintrags zum
                        // aktuellen Namen — nur Anzeige, der Betrag in der Zeile bleibt der Punktwert.
                        if let catalogText = PriceCatalogDisplay.summary(forName: name) {
                            Text(catalogText)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 28)
                                .accessibilityIdentifier("editItem.catalogSummary")
                        }
                    }

                    HStack {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "item.note.placeholder"), text: $note)
                    }
                }

                if item.priceOrigin == AIPriceEstimation.source {
                    aiPriceSection
                }

                photoSection

                Section(String(localized: "item.category.section")) {
                    NavigationLink {
                        CategoryPickerView(
                            store: selectedStore,
                            selection: pickerSelection,
                            automaticCategory: AssignmentService.category(for: name),
                            itemName: name,
                            onFollow: followSelection
                        )
                    } label: {
                        HStack {
                            Text(String(localized: "item.category.section"))
                            Spacer()
                            Text(categoryLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("item.categoryRow")
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

                if developerMode {
                    priceDiagnosisSection
                }

                Section {
                    Button {
                        withAnimation {
                            // Wie `StoreDetailView.toggle`: auch hier für den Einkaufsweg aufzeichnen
                            // (Issue #79), sonst zählte ein hier zurückgenommener Haken weiter.
                            if item.isCompleted {
                                item.markPending()
                                item.store?.recordUncheck(item)
                            } else {
                                item.markCompleted()
                                item.store?.recordCheckOff(item)
                            }
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

    /// Issue #164: Spanne und angenommene Packung des KI-Preises aus dem Zwischenspeicher, dazu
    /// „Stimmt so“ — macht den KI-Preis zum eigenen Preis (`manual`), ohne Netz.
    @ViewBuilder
    private var aiPriceSection: some View {
        Section(String(localized: "item.price.ai.section")) {
            if let text = Self.aiRangeText(for: item) {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("editItem.aiRange")
            }
            Button {
                AIPriceEstimationService.confirm(item)
                Haptics.success()
            } label: {
                Label(String(localized: "item.price.ai.confirm"), systemImage: "checkmark.seal")
            }
            .accessibilityIdentifier("editItem.aiConfirm")
        }
    }

    /// „Angenommene Packung 125 g, Spanne 0,79 € – 1,79 €“ aus dem Zwischenspeicher; `nil` ohne Eintrag.
    static func aiRangeText(for item: ShoppingItem, cache: AIPriceCache = .shared, locale: Locale = .current) -> String? {
        let request = AIPriceEstimationService.request(for: item)
        guard let guess = cache.entry(for: request.cacheKey)?.guess else { return nil }
        let euro = FloatingPointFormatStyle<Double>.Currency(code: "EUR", locale: locale).precision(.fractionLength(2))
        let package = guess.packageUnit == "stk"
            ? String(localized: "price.catalog.package.piece")
            : "\(guess.packageAmount.formatted(.number.locale(locale).precision(.fractionLength(0...1)))) \(guess.packageUnit)"
        return String(format: String(localized: "item.price.ai.range"), package, guess.low.formatted(euro), guess.high.formatted(euro))
    }

    /// Dev-Diagnose (Issue #151): warum ein gelernter Preis greift oder verworfen wird — aus
    /// derselben Kette wie `ShoppingItem.init`, mit dem aktuellen Zustand und dem gewählten Laden.
    private var priceDiagnosisSection: some View {
        Section(String(localized: "price.diagnosis.section")) {
            ForEach(PriceDiagnosis.lines(for: item, in: selectedStore), id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
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

    /// Preisblock aus `save()`, statisch und testbar (Issue #151); setzt die Quelle im selben Zug
    /// wie den Preis. `item.unit` trägt hier schon die neue Einheit, `oldUnit` die alte.
    static func applyPriceEdit(priceText: String, initialPriceText: String, oldUnit: String,
                               priceCategory: String, to item: ShoppingItem) {
        if priceText != initialPriceText {
            let rawPrice = priceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
            if let p = Double(rawPrice), p > 0 {
                // The field holds the TOTAL for this line (see init/UI hint above); `estimatedPrice`
                // is stored canonically per-unit, so divide the quantity back out before saving.
                item.estimatedPrice = item.quantityAmount > 0 ? p / item.quantityAmount : p
                // A manual entry gives the price a real-world origin — never auto-recompute it again.
                item.estimatedPriceIsAutoDerived = false
                item.priceSource = "manual"
                item.priceSourceDate = nil
            } else if rawPrice.isEmpty {
                let fallback = PriceEstimator.resolve(for: item.name, category: priceCategory, unit: item.unit, quantityAmount: item.quantityAmount)
                item.estimatedPrice = fallback?.price
                item.estimatedPriceIsAutoDerived = true
                item.priceSource = fallback?.source ?? "estimate"
                item.priceSourceDate = nil
            }
        } else if oldUnit != item.unit, item.estimatedPriceIsAutoDerived {
            // The price field itself wasn't touched, but the unit was — and this price is still
            // just the catalog/category estimate, so it's safe to recompute for the new unit
            // (e.g. "" → "g" needs the per-gram rate, not the per-package rate). A learned or
            // manually-entered price (estimatedPriceIsAutoDerived == false) is left untouched here,
            // even if it would numerically collide with the old-unit formula.
            let fallback = PriceEstimator.resolve(for: item.name, category: priceCategory, unit: item.unit, quantityAmount: item.quantityAmount)
            item.estimatedPrice = fallback?.price
            item.priceSource = fallback?.source ?? "estimate"
            item.priceSourceDate = nil
        }
    }

    /// Kategorie aus dem Dialog übernehmen. Issue #234: In Läden mit Gängen wird eine Wahl aus der
    /// Auswahl (Gang oder Sonstiges-Marke) gemerkt; die Marke steht nie in `item.category`.
    private func applyCategory(automaticCategory: String) {
        if categoryPicked, let store = selectedStore, store.isStationChoice(category) {
            let isOther = category == StoreCategories.otherStationMarker
            item.category = isOther ? automaticCategory : category
            item.categoryManuallySet = !isOther
            store.rememberCategory(category, forItemNamed: item.name)
            return
        }
        // Marke aus einem Laden mit Gängen, Artikel wechselt in einen ohne: automatische Kategorie.
        if category == StoreCategories.otherStationMarker { category = automaticCategory }
        // Eine eigene Kategorie gilt nur in ihrem Laden (Issue #85): wechselt der Artikel in einen
        // Laden ohne sie, bekommt er wieder die automatische Kategorie.
        if let oldStore = item.store, oldStore.isCustomCategory(category),
           selectedStore?.isCustomCategory(category) != true {
            category = selectedStore?.rememberedCategory(forItemNamed: item.name) ?? automaticCategory
        }
        let categoryChanged = item.category != category
        item.category = category
        // Only lock the category in as a manual override if the user actually picked something
        // different from what the name-based heuristic would auto-detect. If they left it on
        // the auto-detected value, keep it free to re-derive so future keyword-rule tweaks apply.
        item.categoryManuallySet = category != automaticCategory
        if categoryChanged {
            selectedStore?.rememberCategory(category, forItemNamed: item.name)
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity.isEmpty ? "1" : quantity
        let rawQty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 1
        item.quantityAmount = (rawQty > 0 && !rawQty.isNaN) ? rawQty : 1
        // Sobald der Nutzer die Menge über dieses Formular gespeichert hat, ist sie seine eigene:
        // die „ca."-Markierung verschwindet und aus Rate und Menge wird wieder ein Gesamtpreis
        // (Issue #10, `ShoppingItem.quantitySource`).
        item.quantitySource = "user"
        let oldUnit = item.unit
        item.unit = unit
        item.note = note
        let automaticCategory = AssignmentService.category(for: item.name)
        applyCategory(automaticCategory: automaticCategory)
        let oldStore = item.store
        let itemID = item.id
        let movedToAnotherStore = oldStore?.id != selectedStore?.id
        item.store = selectedStore
        item.assignedTo = selectedStore?.shareID != nil ? assignedTo : ""
        item.lastModified = Date()
        // Eine eigene Kategorie hat keinen Katalogpreis — für die Schätzung zählt die automatische.
        let priceCategory = selectedStore?.isCustomCategory(item.category) == true ? automaticCategory : item.category

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
        Self.applyPriceEdit(priceText: priceText, initialPriceText: initialPriceText, oldUnit: oldUnit,
                            priceCategory: priceCategory, to: item)

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
