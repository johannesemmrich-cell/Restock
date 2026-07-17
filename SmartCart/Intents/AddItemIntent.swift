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
        // Must mirror SmartCartApp's container setup exactly — this intent runs out-of-process and
        // opens the SAME app-group store file. Two things have to match what the main app actually
        // ended up using: (1) the schema representation (versioned, not a plain array — a mismatch
        // here has already once caused SwiftData to treat this app's store as incompatible and wipe
        // it, see SmartCartApp.swift's migration comments), and (2) whether the store is CloudKit-
        // mirrored — SmartCartApp tries CloudKit first and only falls back to a local-only store if
        // that fails, so this intent must attempt the same CloudKit configuration first rather than
        // always opening with `cloudKitDatabase: .none`, or it could fail (or silently desync) against
        // a store the main app actually opened with CloudKit mirroring enabled.
        let schema = Schema(versionedSchema: SchemaV1.self)
        let groupContainerID = "group.com.johannesemmrich.SmartCart"
        let container: ModelContainer
        if let cloudKitContainer = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                groupContainer: .identifier(groupContainerID),
                cloudKitDatabase: .private("iCloud.com.johannesemmrich.SmartCart")
            )
        ) {
            container = cloudKitContainer
        } else {
            let localConfig = ModelConfiguration(groupContainer: .identifier(groupContainerID), cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: localConfig)
        }
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
