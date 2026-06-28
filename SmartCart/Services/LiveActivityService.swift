import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<ShoppingActivityAttributes>?
    private var lastState: ShoppingActivityAttributes.ContentState?

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
    }

    func start(for store: Store) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Nach App-Neustart: vorhandene Live Activity wiederfinden statt neue starten
        if currentActivity == nil {
            currentActivity = Activity<ShoppingActivityAttributes>.activities
                .first(where: { $0.attributes.storeName == store.name })
        }

        let state = makeState(for: store)
        lastState = state
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7200))

        if let existing = currentActivity {
            Task { await existing.update(content) }
            return
        }

        let attrs = ShoppingActivityAttributes(storeName: store.name, storeEmoji: store.emoji)
        currentActivity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    func update(for store: Store) {
        let state = makeState(for: store)
        lastState = state
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7200))
        Task { await activity.update(content) }
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
    }

    // Wird von der Darwin-Notification aufgerufen: sofortiges optimistisches Update
    func handlePendingCheckoff() {
        guard let activity = currentActivity, var state = lastState,
              !state.pendingItemNames.isEmpty else { return }
        state.pendingItemNames.removeFirst()
        state.completedCount += 1
        state.nextItemName = state.pendingItemNames.first
        lastState = state
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7200))
        Task { await activity.update(content) }
    }

    private func makeState(for store: Store) -> ShoppingActivityAttributes.ContentState {
        let pending = store.pendingItems
        return .init(
            completedCount: store.completedItems.count,
            totalCount: store.items.count,
            nextItemName: pending.first?.name,
            pendingItemNames: pending.map { $0.name },
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
