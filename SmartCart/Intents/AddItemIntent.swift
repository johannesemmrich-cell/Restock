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

        let item = Self.add(name: itemName, quantity: quantity, unit: unit, in: context)
        try context.save()
        let store = item.store

        let storeInfo = store.map { " für \($0.name)" } ?? ""
        return .result(dialog: "'\(itemName)' wurde zur Einkaufsliste hinzugefügt\(storeInfo).")
    }

    /// Anlegelogik des Siri-Befehls ohne Speicher-Öffnen, Speichern und Dialog — aus `perform()`
    /// ausgelagert, damit sie mit einem In-Memory-Container testbar ist (Issue #98, Durchgang 8).
    /// Ordnet über `AssignmentService.assign` einem aktiven Laden zu (keiner → `store == nil`) und
    /// fügt den Artikel in den Kontext ein; gespeichert wird beim Aufrufer.
    static func add(name: String, quantity: Int, unit: String?, in context: ModelContext) -> ShoppingItem {
        // `add` wirft nicht: scheitert der Laden-Fetch (bisher Abbruch von `perform()`), wird der
        // Artikel ohne Laden angelegt.
        let stores = (try? context.fetch(FetchDescriptor<Store>(predicate: #Predicate { $0.isActive }))) ?? []
        // Nice-to-have für die Store-Zuordnung — ein Fetch-Fehler hier soll das Hinzufügen des
        // Artikels selbst nicht scheitern lassen, deshalb `try?` statt `try`.
        let purchaseRecords = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []
        let category = AssignmentService.category(for: name)
        let store = AssignmentService.assign(itemName: name, to: stores, purchaseRecords: purchaseRecords)

        let qty = Double(quantity)
        let qtyStr = quantity == 1 ? "1" : "\(quantity)"
        let item = ShoppingItem(
            name: name,
            category: category,
            quantity: qtyStr,
            quantityAmount: qty,
            unit: unit ?? "",
            store: store
        )
        context.insert(item)
        return item
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
