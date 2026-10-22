import ActivityKit
import Foundation

/// Wann die Live Activity (Dynamic Island, Sperrbildschirm) läuft — reine Regel, ohne ActivityKit
/// testbar (`LiveActivityPolicyTests`). Beschluss des PO vom 2026-10-22: Start erst beim ersten
/// Abhaken (nicht beim Öffnen der Liste), bleibt beim Wechsel in eine andere App und bei
/// gesperrtem Gerät stehen, endet bei „alles erledigt“, nach `idleLimit` ohne Haken oder – seit
/// dem zweiten Beschluss vom selben Tag – sobald man in der App die Liste verlässt. Vorher
/// startete jedes Öffnen einer Liste mit offenen Artikeln eine Anzeige, auch beim Planen zu Hause.
enum LiveActivityPolicy {
    enum Event: Equatable {
        /// Ladenliste geöffnet (auch nach App-Neustart).
        case listOpened
        /// Ladenliste in der App verlassen (zurück zum Hauptbildschirm). Nicht: App im Hintergrund.
        case listClosed
        /// App kommt in den Vordergrund.
        case appActivated
        /// Ein Artikel wurde abgehakt (Liste, Dynamic Island, Widget).
        case checkedOff
        /// Ein Haken wurde zurückgenommen.
        case unchecked
        /// Offene Artikel haben sich anders geändert (hinzugefügt, gelöscht, Sync).
        case itemsChanged
    }

    enum Action: Equatable {
        case none
        case startOrUpdate
        case end
    }

    /// Ohne Haken so lange gilt der Einkauf als vorbei — dieselbe Grenze wie beim Lernen des
    /// Einkaufswegs (`ShoppingRoute.tripGap`).
    static let idleLimit: TimeInterval = ShoppingRoute.tripGap

    /// `lastCheckOff`: letzter Haken des laufenden Einkaufs in diesem Laden (nil = keiner).
    static func action(
        for event: Event,
        hasActivity: Bool,
        pendingCount: Int,
        lastCheckOff: Date?,
        now: Date
    ) -> Action {
        let shopping = lastCheckOff.map { now.timeIntervalSince($0) <= idleLimit } ?? false
        if pendingCount == 0 { return hasActivity ? .end : .none }
        switch event {
        case .checkedOff:
            return .startOrUpdate
        case .unchecked:
            // Nach „alles erledigt“ einen Haken zurücknehmen: im laufenden Einkauf wieder anzeigen.
            if hasActivity { return shopping ? .startOrUpdate : .end }
            return shopping ? .startOrUpdate : .none
        case .listClosed:
            return hasActivity ? .end : .none
        case .itemsChanged, .listOpened, .appActivated:
            guard hasActivity else { return .none }
            return shopping ? .startOrUpdate : .end
        }
    }

    /// Ab wann eine laufende Anzeige als veraltet gilt: `idleLimit` nach dem letzten Haken.
    /// Dient zugleich als Merkmal für `LiveActivityService.endIdleActivities`.
    static func staleDate(lastCheckOff: Date?, now: Date) -> Date {
        (lastCheckOff ?? now).addingTimeInterval(idleLimit)
    }

    static func isIdle(staleDate: Date?, now: Date) -> Bool {
        guard let staleDate else { return false }
        return now >= staleDate
    }
}

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<ShoppingActivityAttributes>?
    private var lastState: ShoppingActivityAttributes.ContentState?
    /// Der zuletzt getrackte Laden — nur fürs Anzeige-Refresh nach einem Widget-Checkoff
    /// (`handleStoreChanged`). Weak, damit der Service kein gelöschtes Model festhält.
    private weak var trackedStore: Store?

    init() {
        // Darwin-Notification: Intent postet → Hauptapp empfängt → sofortiges Update
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            liveActivityCheckoffCallback,
            "com.johannesemmrich.SmartCart.pendingCheckoff" as CFString,
            nil,
            .deliverImmediately
        )
        // Widget-Checkoff (Homescreen) → Island-Anzeige aus dem Store neu aufbauen,
        // sonst zeigt die Live Activity das gerade erledigte Item weiter an.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            liveActivityStoreChangedCallback,
            "com.johannesemmrich.SmartCart.storeChanged" as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Einziger Einstieg der Ansichten: wendet `LiveActivityPolicy` an.
    func handle(_ event: LiveActivityPolicy.Event, for store: Store, now: Date = Date()) {
        let action = LiveActivityPolicy.action(
            for: event,
            hasActivity: hasActiveActivity(for: store),
            pendingCount: store.pendingItems.count,
            lastCheckOff: store.currentTrip.lastActivity,
            now: now
        )
        switch action {
        case .none: break
        case .startOrUpdate: start(for: store)
        case .end: end(for: store)
        }
    }

    func hasActiveActivity(for store: Store) -> Bool {
        if let currentActivity, currentActivity.attributes.storeName == store.name,
           currentActivity.activityState == .active {
            return true
        }
        return Activity<ShoppingActivityAttributes>.activities
            .contains { $0.attributes.storeName == store.name && $0.activityState == .active }
    }

    /// Beim Wechsel in den Vordergrund: Anzeigen beenden, deren letzter Haken länger als
    /// `LiveActivityPolicy.idleLimit` zurückliegt (Merkmal ist das `staleDate`, siehe dort).
    /// Läuft die App in der Zeit nicht, bleibt die Anzeige als „veraltet“ stehen, bis iOS sie
    /// nach spätestens 8 Stunden selbst beendet.
    func endIdleActivities(now: Date = Date()) {
        for activity in Activity<ShoppingActivityAttributes>.activities
            where activity.activityState == .active
            && LiveActivityPolicy.isIdle(staleDate: activity.content.staleDate, now: now) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            if activity.id == currentActivity?.id {
                currentActivity = nil
                lastState = nil
                trackedStore = nil
            }
        }
    }

    private func staleDate(for store: Store) -> Date {
        LiveActivityPolicy.staleDate(lastCheckOff: store.currentTrip.lastActivity, now: Date())
    }

    func start(for store: Store) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Leere Pending-Liste: keine Activity starten, evtl. verwaiste beenden
        guard !store.pendingItems.isEmpty else {
            end(for: store)
            return
        }

        // Immer nur ein Einkauf zugleich: ein Haken in einem anderen Laden beendet die Anzeige
        // des vorigen, statt sie mit dem Stand dieses Ladens zu überschreiben.
        // Nach einem App-Neustart kennt `currentActivity` sie nicht mehr, daher alle laufenden prüfen.
        for other in Activity<ShoppingActivityAttributes>.activities
            where other.attributes.storeName != store.name && other.activityState == .active {
            Task { await other.end(nil, dismissalPolicy: .immediate) }
        }
        if let current = currentActivity, current.attributes.storeName != store.name {
            currentActivity = nil
            lastState = nil
        }

        // Nach App-Neustart: vorhandene Live Activity wiederfinden statt neue starten. Nur eine
        // noch AKTIVE Activity zählt als Treffer (Issue #40) — end() lässt eine beendete Activity
        // wegen ihrer Dismissal-Gnadenfrist (siehe end() unten) noch bis zu 4s in `.activities`
        // stehen. Ohne diesen Zustandscheck würde ein erneutes Öffnen der Liste innerhalb dieser
        // Frist sich an die sterbende Activity hängen und nur `.update()` auf ihr aufrufen, was
        // ActivityKit auf einer bereits beendeten Activity wirkungslos verwirft.
        if currentActivity == nil {
            currentActivity = Activity<ShoppingActivityAttributes>.activities
                .first(where: { $0.attributes.storeName == store.name && $0.activityState == .active })
        }

        trackedStore = store
        let state = makeState(for: store)
        lastState = state
        let content = ActivityContent(state: state, staleDate: staleDate(for: store))

        if let existing = currentActivity {
            Task { await existing.update(content) }
            return
        }

        let attrs = ShoppingActivityAttributes(storeName: store.name, storeEmoji: store.emoji)
        currentActivity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    func end(for store: Store) {
        let content = ActivityContent(state: makeState(for: store), staleDate: nil)
        let storeName = store.name
        // Alle Live Activities für diesen Store beenden (auch verwaiste aus früheren Sessions)
        for activity in Activity<ShoppingActivityAttributes>.activities
            where activity.attributes.storeName == storeName {
            Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(4))) }
        }
        if let tracked = currentActivity {
            Task { await tracked.end(content, dismissalPolicy: .after(Date().addingTimeInterval(4))) }
        }
        currentActivity = nil
        lastState = nil
        trackedStore = nil
    }

    // Wird von der Darwin-Notification aufgerufen: sofortiges optimistisches Update.
    // Bewusst positionsbasiert (der Island-Tap betrifft immer das angezeigte erste Item) —
    // pendingItemIDs wird im Gleichschritt mitgepflegt, damit der Intent beim nächsten Tap
    // die korrekte nächste UUID aus dem Activity-State queuen kann.
    func handlePendingCheckoff() {
        guard let activity = currentActivity, var state = lastState,
              !state.pendingItemNames.isEmpty else { return }
        state.pendingItemNames.removeFirst()
        if !state.pendingItemIDs.isEmpty { state.pendingItemIDs.removeFirst() }
        state.completedCount += 1
        state.nextItemName = state.pendingItemNames.first
        lastState = state
        // Letztes Item abgehakt → Activity mit finalem State beenden
        // (4s Verzögerung, damit der letzte Haken kurz sichtbar bleibt)
        if state.pendingItemNames.isEmpty {
            let content = ActivityContent(state: state, staleDate: nil)
            Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(4))) }
            currentActivity = nil
            lastState = nil
            return
        }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(LiveActivityPolicy.idleLimit))
        Task { await activity.update(content) }
    }

    /// Best-effort Anzeige-Refresh nach einem Homescreen-Widget-Checkoff (Darwin-Notification
    /// `storeChanged`): Island-State aus dem Store neu aufbauen, abzüglich der noch gequeueten
    /// Island-Checkoff-IDs (die zählen für die Anzeige bereits als erledigt). Reines
    /// Anzeige-Polish — verpufft, wenn die App suspendiert ist, und liest schlimmstenfalls
    /// einen noch nicht cross-process-refreshten Store-Stand (dann bleibt die Anzeige einfach
    /// wie zuvor). Der eigentliche Datenstand wird davon nie berührt.
    func handleStoreChanged() {
        guard currentActivity != nil, let store = trackedStore else { return }
        let queuedIDs = Set(
            (UserDefaults(suiteName: SharedModelContainer.appGroupID)?
                .stringArray(forKey: "pendingCheckoffIDs_\(store.name)") ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        let state = makeState(for: store, excludingQueuedIDs: queuedIDs)
        if state.pendingItemNames.isEmpty {
            end(for: store)
            return
        }
        lastState = state
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(LiveActivityPolicy.idleLimit))
        Task { await activity.update(content) }
    }

    private func makeState(for store: Store, excludingQueuedIDs excluded: Set<UUID> = []) -> ShoppingActivityAttributes.ContentState {
        var pending = store.pendingItems
        if !excluded.isEmpty {
            pending.removeAll { excluded.contains($0.id) }
        }
        // Gleiche "nur kürzlich abgehakt zählt mit"-Fensterung wie StoreDetailView.completionProgress
        // (Store.recentlyCompletedItems) — sonst würde die Live Activity/Dynamic Island einen ganz
        // anderen (nie schrumpfenden) Fortschritt zeigen als der Store-Screen für denselben Store.
        // `excluded` sind noch nicht persistierte, aber schon zur Anzeige als erledigt behandelte
        // Island-Checkoffs — zählen unabhängig vom Zeitfenster immer zu "gerade erledigt".
        let completed = store.recentlyCompletedItems.count + excluded.count
        return .init(
            completedCount: completed,
            totalCount: pending.count + completed,
            nextItemName: pending.first?.name,
            pendingItemNames: pending.map { $0.name },
            pendingItemIDs: pending.map { $0.id },
            storeColorHex: store.colorHex
        )
    }
}

// Freie Funktion als C-Callback — kein Capture nötig, da Singleton
private func liveActivityCheckoffCallback(
    center: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    name: CFNotificationName?,
    object: UnsafeRawPointer?,
    userInfo: CFDictionary?
) {
    Task { @MainActor in
        LiveActivityService.shared.handlePendingCheckoff()
    }
}

private func liveActivityStoreChangedCallback(
    center: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    name: CFNotificationName?,
    object: UnsafeRawPointer?,
    userInfo: CFDictionary?
) {
    Task { @MainActor in
        LiveActivityService.shared.handleStoreChanged()
    }
}
