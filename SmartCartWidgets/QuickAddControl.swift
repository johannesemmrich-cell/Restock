import WidgetKit
import AppIntents
import SwiftData
import SwiftUI

// MARK: - Intent (widget-local, no AssignmentService needed)

struct QuickAddControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Artikel hinzufügen"
    static var description = IntentDescription("Fügt einen Artikel direkt zur SmartCart Einkaufsliste hinzu.")
    static var openAppWhenRun = false

    @Parameter(title: "Artikelname", requestValueDialog: "Was möchtest du hinzufügen?")
    var itemName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Store.self, ShoppingItem.self, PurchaseRecord.self, FeedbackItem.self, TodoItem.self)
        let ctx = ModelContext(container)

        let stores = try ctx.fetch(FetchDescriptor<Store>(predicate: #Predicate { $0.isActive }))
        // Assign to most-visited store (simple heuristic without full AssignmentService)
        let store = stores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek })

        let item = ShoppingItem(
            name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            category: "Lebensmittel",
            quantity: "1",
            quantityAmount: 1.0,
            unit: "",
            store: store
        )
        ctx.insert(item)
        try ctx.save()

        let storeInfo = store.map { " → \($0.name)" } ?? ""
        return .result(dialog: "'\(itemName)' hinzugefügt\(storeInfo).")
    }
}

// MARK: - Control Widget

@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.smartcart.quickadd-control") {
            ControlWidgetButton(action: QuickAddControlIntent()) {
                Label("Hinzufügen", systemImage: "cart.badge.plus")
            }
            .tint(.blue)
        }
        .displayName("Artikel hinzufügen")
        .description("Artikel direkt zur SmartCart Einkaufsliste hinzufügen — ohne die App zu öffnen.")
    }
}
