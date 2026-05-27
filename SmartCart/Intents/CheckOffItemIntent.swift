import AppIntents
import SwiftData
import ActivityKit

struct CheckOffItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächsten Artikel abhaken"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Laden")
    var storeName: String

    init() { storeName = "" }
    init(storeName: String) { self.storeName = storeName }

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: Store.self, ShoppingItem.self, PurchaseRecord.self, FeedbackItem.self, TodoItem.self)
        let ctx = ModelContext(container)

        let stores = try ctx.fetch(FetchDescriptor<Store>())
        guard let store = stores.first(where: { $0.name == storeName }),
              let item = store.pendingItems.first else {
            return .result()
        }

        item.markCompleted()
        store.recordCompletionOrder([item.name])
        try ctx.save()

        let newState = ShoppingActivityAttributes.ContentState(
            completedCount: store.completedItems.count,
            totalCount: store.items.count,
            nextItemName: store.pendingItems.first?.name,
            storeColorHex: store.colorHex
        )

        for activity in Activity<ShoppingActivityAttributes>.activities
            where activity.attributes.storeName == storeName {
            await activity.update(ActivityContent(state: newState, staleDate: nil))
        }

        return .result()
    }
}
