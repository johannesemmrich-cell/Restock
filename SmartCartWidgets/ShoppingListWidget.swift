import WidgetKit
import SwiftUI
import AppIntents
import SwiftData

// MARK: - Data access
//
// The widget runs out-of-process and opens the SAME app-group SwiftData store as the main
// app — always via `SharedModelContainer.make()` (see its warning header: schema mismatches
// here have historically wiped the store). Reads happen at timeline-reload time, writes only
// inside `CheckOffWidgetItemIntent.perform()`. SQLite/WAL handles concurrent app+widget
// access at file level; logical conflicts are resolved by the `lastModified` bump that
// `markCompleted()` does, which wins last-write-wins in `SyncCoordinator.apply()`.

private enum WidgetStoreLoader {
    static func activeStores(in context: ModelContext) -> [Store] {
        let descriptor = FetchDescriptor<Store>(
            predicate: #Predicate<Store> { $0.isActive },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Pending items minus the checkoffs already queued from the Dynamic Island / Lock Screen
    /// (`pendingCheckoffIDs_<storeName>` — item UUIDs, drained on next store access). Without
    /// this adjustment the widget would re-show items the user already checked off in the Live
    /// Activity — and tapping one there AND here would double-count once the queue drains.
    static func effectivePending(for store: Store) -> [ShoppingItem] {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID)
        var pending = store.pendingItems
        let queuedIDs = Set(
            (defaults?.stringArray(forKey: "pendingCheckoffIDs_\(store.name)") ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        if !queuedIDs.isEmpty {
            pending.removeAll { queuedIDs.contains($0.id) }
        }
        // Legacy-Zähler (Queue einer alten App-Version, s. drainPendingCheckoffs): count-basiert.
        let legacyCount = defaults?.integer(forKey: "pendingCheckoffs_\(store.name)") ?? 0
        if legacyCount > 0 {
            pending = Array(pending.dropFirst(legacyCount))
        }
        return pending
    }

    /// Drains the Dynamic-Island checkoff queue into the store — the same semantics as
    /// `StoreDetailView.applyPendingCheckoffs()`: complete exactly the queued item UUIDs;
    /// already-completed IDs (double-drain, sync merge, double-tap duplicates) are no-ops.
    /// Called by the widget's checkoff intent before completing the tapped item, so queue
    /// and direct writes can never double-apply.
    ///
    /// Known micro-window (documented, deliberately no cross-process lock): if the app's
    /// drain and this one read the SAME queue concurrently, both may claim a UUID — the
    /// `!item.isCompleted` guard in whichever runs second turns that into a no-op after the
    /// first save lands, but a truly simultaneous claim could double-record. Accepted.
    static func drainPendingCheckoffs(for store: Store) {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID)

        // UUID-Queue: exakt die gequeueten Items erledigen (nicht "die ersten N" —
        // count-basiert würde nach Widget-Checkoff/Sync-Merge das falsche Item treffen).
        let idKey = "pendingCheckoffIDs_\(store.name)"
        if let queuedIDs = defaults?.stringArray(forKey: idKey), !queuedIDs.isEmpty {
            defaults?.removeObject(forKey: idKey)
            for idString in queuedIDs {
                guard let id = UUID(uuidString: idString),
                      let item = store.items.first(where: { $0.id == id }),
                      !item.isCompleted else { continue }
                item.markCompleted()
                store.recordCompletionOrder([item.name])
            }
        }

        // Legacy (einmaliger Übergang): Zähler-Key einer alten App-Version noch
        // count-basiert drainen, damit ein Update mitten im Einkauf nichts verliert.
        let legacyKey = "pendingCheckoffs_\(store.name)"
        let legacyCount = defaults?.integer(forKey: legacyKey) ?? 0
        if legacyCount > 0 {
            defaults?.removeObject(forKey: legacyKey)
            for _ in 0..<legacyCount {
                guard let item = store.pendingItems.first else { break }
                item.markCompleted()
                store.recordCompletionOrder([item.name])
            }
        }
    }
}

// MARK: - Store entity (widget configuration)

struct StoreEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Laden"
    static var defaultQuery = StoreEntityQuery()

    let id: UUID
    let name: String
    let emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(store: Store) {
        self.id = store.id
        self.name = store.name
        self.emoji = store.emoji
    }
}

struct StoreEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [StoreEntity] {
        guard let container = SharedModelContainer.make() else { return [] }
        let context = ModelContext(container)
        return WidgetStoreLoader.activeStores(in: context)
            .filter { identifiers.contains($0.id) }
            .map(StoreEntity.init)
    }

    func suggestedEntities() async throws -> [StoreEntity] {
        guard let container = SharedModelContainer.make() else { return [] }
        let context = ModelContext(container)
        return WidgetStoreLoader.activeStores(in: context).map(StoreEntity.init)
    }

    /// Sensible default without any user configuration: the store with the most open items.
    func defaultResult() async -> StoreEntity? {
        guard let container = SharedModelContainer.make() else { return nil }
        let context = ModelContext(container)
        let stores = WidgetStoreLoader.activeStores(in: context)
        let best = stores.max { a, b in
            WidgetStoreLoader.effectivePending(for: a).count < WidgetStoreLoader.effectivePending(for: b).count
        }
        return best.map(StoreEntity.init)
    }
}

struct ShoppingListWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Einkaufsliste"
    static var description = IntentDescription("Wähle den Laden, dessen offene Artikel angezeigt werden.")

    @Parameter(title: "Laden")
    var store: StoreEntity?
}

// MARK: - Check-off intent (interactive button)

struct CheckOffWidgetItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Artikel abhaken"
    static var description = IntentDescription("Hakt einen Artikel der Einkaufsliste ab.")
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "Artikel")
    var itemID: String

    @Parameter(title: "Laden")
    var storeID: String

    init() {
        itemID = ""
        storeID = ""
    }

    init(itemID: UUID, storeID: UUID) {
        self.itemID = itemID.uuidString
        self.storeID = storeID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard
            let container = SharedModelContainer.make(),
            let storeUUID = UUID(uuidString: storeID),
            let itemUUID = UUID(uuidString: itemID)
        else { return .result() }
        let context = ModelContext(container)

        let stores = (try? context.fetch(FetchDescriptor<Store>())) ?? []
        guard let store = stores.first(where: { $0.id == storeUUID }) else { return .result() }

        // 1. Erst die aus Dynamic Island/Lock Screen gequeueten Checkoffs anwenden — das
        //    Widget hat sie bereits aus der Anzeige herausgerechnet, also entspricht der
        //    Store danach exakt dem, was der Nutzer beim Tippen gesehen hat. War der
        //    getippte Artikel selbst schon per Island abgehakt, ist er jetzt completed
        //    und Schritt 2 wird ein No-op statt eines Doppel-Abhakens.
        WidgetStoreLoader.drainPendingCheckoffs(for: store)

        // 2. Den getippten Artikel mit ALLEN Seiteneffekten der App abhaken:
        //    markCompleted() setzt completedDate/completedBy, bumpt lastModified (schützt
        //    die Änderung via Last-Write-Wins vor dem nächsten Sync-Pull) und legt den
        //    PurchaseRecord für die Habit-Analyse an.
        if let item = store.items.first(where: { $0.id == itemUUID }), !item.isCompleted {
            item.markCompleted()
            store.recordCompletionOrder([item.name])
        }

        try context.save()

        // 3. Die Widget-Extension kann nicht zu CloudKit pushen und weiß nicht einmal,
        //    welche Läden geteilt sind (shareID liegt in UserDefaults.standard der App).
        //    Flagge setzen — die App pusht beim nächsten Aktivieren alle geteilten Läden
        //    (SyncCoordinator.pushWidgetCheckoffsIfNeeded).
        UserDefaults(suiteName: SharedModelContainer.appGroupID)?
            .set(true, forKey: "widgetDidCheckOffItem")

        // 4. Best-effort Anzeige-Refresh der Live Activity: die Hauptapp (falls sie im
        //    Hintergrund lebt) baut den Island-State aus dem Store neu auf, sonst zeigt
        //    die Island das hier erledigte Item weiter an. Verpufft bei suspendierter
        //    App — dann korrigiert der nächste Store-Besuch die Anzeige.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.johannesemmrich.SmartCart.storeChanged" as CFString),
            nil, nil, true
        )

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline

struct WidgetItemInfo: Identifiable {
    let id: UUID
    let name: String
    let quantityText: String
    let isUrgent: Bool
}

struct WidgetStoreSnapshot {
    let id: UUID
    let name: String
    let emoji: String
    let colorHex: String
    let pendingCount: Int
    let estimatedTotal: Double?
    let items: [WidgetItemInfo]

    static let placeholder = WidgetStoreSnapshot(
        id: UUID(),
        name: "Supermarkt",
        emoji: "🛒",
        colorHex: "#2563EB",
        pendingCount: 4,
        estimatedTotal: 12.40,
        items: [
            WidgetItemInfo(id: UUID(), name: "Milch", quantityText: "2×", isUrgent: false),
            WidgetItemInfo(id: UUID(), name: "Brot", quantityText: "", isUrgent: false),
            WidgetItemInfo(id: UUID(), name: "Äpfel", quantityText: "1 kg", isUrgent: false),
            WidgetItemInfo(id: UUID(), name: "Butter", quantityText: "", isUrgent: false),
        ]
    )
}

struct ShoppingListEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStoreSnapshot?
    var isPlaceholder = false
}

struct ShoppingListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShoppingListEntry {
        ShoppingListEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func snapshot(for configuration: ShoppingListWidgetConfigIntent, in context: Context) async -> ShoppingListEntry {
        loadEntry(for: configuration)
    }

    func timeline(for configuration: ShoppingListWidgetConfigIntent, in context: Context) async -> Timeline<ShoppingListEntry> {
        // Ein Entry reicht: Aktualisierungen kommen ereignisgetrieben über
        // WidgetCenter.reloadAllTimelines() (markCompleted/markPending, Sync-Merge,
        // App-Background, Island-Checkoff, eigener Intent). Der 30-Minuten-Fallback
        // fängt nur Verpasstes ab.
        Timeline(
            entries: [loadEntry(for: configuration)],
            policy: .after(Date().addingTimeInterval(30 * 60))
        )
    }

    private func loadEntry(for configuration: ShoppingListWidgetConfigIntent) -> ShoppingListEntry {
        guard let container = SharedModelContainer.make() else {
            return ShoppingListEntry(date: Date(), snapshot: nil)
        }
        let context = ModelContext(container)
        let stores = WidgetStoreLoader.activeStores(in: context)
        guard !stores.isEmpty else { return ShoppingListEntry(date: Date(), snapshot: nil) }

        // Konfigurierter Laden, sonst der mit den meisten offenen Artikeln
        let store = stores.first(where: { $0.id == configuration.store?.id })
            ?? stores.max { a, b in
                WidgetStoreLoader.effectivePending(for: a).count < WidgetStoreLoader.effectivePending(for: b).count
            }
        guard let store else { return ShoppingListEntry(date: Date(), snapshot: nil) }

        let pending = WidgetStoreLoader.effectivePending(for: store)
        let estimates = pending.compactMap { $0.estimatedLineTotal }
        let items = pending.prefix(4).map { item in
            WidgetItemInfo(
                id: item.id,
                name: item.name,
                quantityText: Self.quantityText(for: item),
                isUrgent: item.isUrgent
            )
        }
        let snapshot = WidgetStoreSnapshot(
            id: store.id,
            name: store.name,
            emoji: store.emoji,
            colorHex: store.colorHex,
            pendingCount: pending.count,
            estimatedTotal: estimates.isEmpty ? nil : estimates.reduce(0, +),
            items: Array(items)
        )
        return ShoppingListEntry(date: Date(), snapshot: snapshot)
    }

    private static func quantityText(for item: ShoppingItem) -> String {
        let qty = item.quantity.trimmingCharacters(in: .whitespaces)
        let unit = item.unit.trimmingCharacters(in: .whitespaces)
        if !unit.isEmpty { return "\(qty) \(unit)" }
        if qty.isEmpty || qty == "1" { return "" }
        return "\(qty)×"
    }
}

// MARK: - Views

private let widgetCurrencyCode = Locale.current.currency?.identifier ?? "EUR"

struct ShoppingListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShoppingListEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
                    .widgetURL(URL(string: "restock://store/\(snapshot.id.uuidString)"))
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            if let snapshot = entry.snapshot, family == .systemSmall {
                // Small: kräftige Ladenfarbe wie die Header-Bänder der App —
                // weißer Text darauf bleibt auch im Dark Mode/StandBy lesbar.
                Rectangle().fill(storeColor(for: snapshot).gradient)
            } else {
                Color(.systemBackground)
            }
        }
    }

    private func storeColor(for snapshot: WidgetStoreSnapshot) -> Color {
        Color(hex: snapshot.colorHex) ?? .blue
    }

    @ViewBuilder
    private func content(for snapshot: WidgetStoreSnapshot) -> some View {
        switch family {
        case .systemSmall:
            SmallShoppingListView(snapshot: snapshot)
        default:
            MediumShoppingListView(snapshot: snapshot)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "cart")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Öffne Restock,\num Läden anzulegen")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: Small — Zusammenfassung

private struct SmallShoppingListView: View {
    let snapshot: WidgetStoreSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(snapshot.emoji)
                    .font(.system(size: 26))
                Spacer()
                if snapshot.pendingCount > 0 {
                    Text("\(snapshot.pendingCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 4)

            Text(snapshot.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if snapshot.pendingCount == 0 {
                Text("Alles erledigt ✓")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(snapshot.items.prefix(2).map(\.name).joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(snapshot.pendingCount == 1 ? "1 Artikel offen" : "\(snapshot.pendingCount) Artikel offen")
                    if let total = snapshot.estimatedTotal {
                        Text("· ≈\(total.formatted(.currency(code: widgetCurrencyCode).precision(.fractionLength(0...2))))")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            }
        }
    }
}

// MARK: Medium — Artikel mit Abhak-Buttons

private struct MediumShoppingListView: View {
    let snapshot: WidgetStoreSnapshot

    private var storeColor: Color { Color(hex: snapshot.colorHex) ?? .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(snapshot.emoji)
                    .font(.system(size: 16))
                Text(snapshot.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(storeColor)
                    .lineLimit(1)
                Spacer()
                if snapshot.pendingCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(snapshot.pendingCount) offen")
                        if let total = snapshot.estimatedTotal {
                            Text("· ≈\(total.formatted(.currency(code: widgetCurrencyCode).precision(.fractionLength(0...2))))")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }

            if snapshot.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                        Text("Alles erledigt!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(snapshot.items) { item in
                        Button(intent: CheckOffWidgetItemIntent(itemID: item.id, storeID: snapshot.id)) {
                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(storeColor)
                                Text(item.name)
                                    .font(.system(size: 13, weight: item.isUrgent ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if item.isUrgent {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                                if !item.quantityText.isEmpty {
                                    Text(item.quantityText)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if snapshot.pendingCount > snapshot.items.count {
                    Text("+\(snapshot.pendingCount - snapshot.items.count) weitere")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Widget declaration

struct ShoppingListWidget: Widget {
    let kind = "com.smartcart.shopping-list-widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ShoppingListWidgetConfigIntent.self,
            provider: ShoppingListProvider()
        ) { entry in
            ShoppingListWidgetView(entry: entry)
        }
        .configurationDisplayName("Einkaufsliste")
        .description("Zeigt die offenen Artikel eines Ladens — direkt abhakbar.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
