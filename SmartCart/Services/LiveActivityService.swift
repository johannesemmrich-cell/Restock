import ActivityKit
import SwiftUI

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<ShoppingActivityAttributes>?

    func start(for store: Store) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if currentActivity != nil { update(for: store); return }
        let attrs = ShoppingActivityAttributes(storeName: store.name, storeEmoji: store.emoji)
        let content = ActivityContent(state: makeState(for: store), staleDate: nil)
        currentActivity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    func update(for store: Store) {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: makeState(for: store), staleDate: nil)
        Task { await activity.update(content) }
    }

    func end(for store: Store) {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: makeState(for: store), staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(4))) }
        currentActivity = nil
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
