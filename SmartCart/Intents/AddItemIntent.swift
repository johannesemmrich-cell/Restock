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
        // This intent runs out-of-process and opens the SAME app-group store file as the main
        // app. It MUST use the shared helper (never a hand-rolled ModelContainer): the schema
        // representation and the CloudKit-first-then-local fallback have to match what the main
        // app actually ended up using — a mismatch here has already once caused SwiftData to
        // treat the app's store as incompatible and wipe it. See SharedModelContainer.swift.
        guard let container = SharedModelContainer.make() else {
            return .result(dialog: "Die Einkaufsliste ist gerade nicht verfügbar. Bitte öffne Restock einmal.")
        }
        let context = ModelContext(container)

        let stores = try context.fetch(FetchDescriptor<Store>(predicate: #Predicate { $0.isActive }))
        // Nice-to-have für die Store-Zuordnung — ein Fetch-Fehler hier soll das Hinzufügen des
        // Artikels selbst nicht scheitern lassen, deshalb `try?` statt `try`.
        let purchaseRecords = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []
        let category = AssignmentService.category(for: itemName)
        let store = AssignmentService.assign(itemName: itemName, to: stores, purchaseRecords: purchaseRecords)

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
