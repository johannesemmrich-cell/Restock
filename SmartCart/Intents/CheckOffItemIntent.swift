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
        let schema = Schema([Store.self, ShoppingItem.self, PurchaseRecord.self, FeedbackItem.self, TodoItem.self])
        // groupContainer: .none required — iOS 26 changed default to .automatic which breaks out-of-process intents
        let config = ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)

        var descriptor = FetchDescriptor<Store>(predicate: #Predicate<Store> { $0.name == storeName })
        descriptor.fetchLimit = 1
        let stores = try ctx.fetch(descriptor)
        guard let store = stores.first,
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
