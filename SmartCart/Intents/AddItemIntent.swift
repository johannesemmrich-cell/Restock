import AppIntents
import SwiftData

// MARK: - Add Shopping Item Intent

struct AddShoppingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Artikel hinzufügen"
    static var description = IntentDescription(
        "Fügt einen Artikel zur Restock Einkaufsliste hinzu.",
        categoryName: "Einkaufsliste"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Artikelname", requestValueDialog: "Was soll ich hinzufügen?")
    var itemName: String

    @Parameter(title: "Menge", default: 1)
    var quantity: Int

    @Parameter(title: "Einheit")
    var unit: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([Store.self, ShoppingItem.self, PurchaseRecord.self, FeedbackItem.self, TodoItem.self])
        let config = ModelConfiguration(schema: schema, groupContainer: .identifier("group.com.johannesemmrich.SmartCart"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let stores = try context.fetch(FetchDescriptor<Store>(predicate: #Predicate { $0.isActive }))
        let category = AssignmentService.category(for: itemName)
        let store = AssignmentService.assign(itemName: itemName, to: stores)

        let qty = Double(quantity)
        let qtyStr = quantity == 1 ? "1" : "\(quantity)"
        let item = ShoppingItem(
            name: itemName,
            category: category,
            quantity: qtyStr,
            quantityAmount: qty,
            unit: unit ?? "",
            store: store
        )
        context.insert(item)
        try context.save()

        let storeInfo = store.map { " für \($0.name)" } ?? ""
        return .result(dialog: "'\(itemName)' wurde zur Einkaufsliste hinzugefügt\(storeInfo).")
    }
}

// MARK: - App Shortcuts

struct SmartCartShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Artikel zu \(.applicationName) hinzufügen",
                "Etwas zu \(.applicationName) hinzufügen",
                "Zur Einkaufsliste in \(.applicationName) hinzufügen",
                "Zur \(.applicationName) Einkaufsliste hinzufügen",
                "Einkaufsliste in \(.applicationName) ergänzen",
                "Neuer Artikel bei \(.applicationName)",
                "Add item to \(.applicationName)",
                "Add to \(.applicationName) shopping list",
            ],
            shortTitle: "Artikel hinzufügen",
            systemImageName: "cart.badge.plus"
        )
    }
}
