import XCTest
import SwiftData
@testable import Restock

/// Beantwortet die kritischste Frage nach dem Vorfall vom 31.07.2026: übersteht bereits
/// bestehende, rein lokale (nie Cloud-gespiegelte) Store-Daten den Übergang, wenn dieselbe
/// Datei danach zum ERSTEN MAL mit `cloudKitDatabase: .private(...)` geöffnet wird? Genau
/// diesen Übergang durchlaufen Bestandsnutzer/Tester beim Update auf den Schema-Fix — ihre
/// Daten wurden bisher nie erfolgreich gespiegelt (siehe SchemaCloudKitCompatibilityTests),
/// liegen also nur lokal vor.
///
/// Nutzeranforderung, wörtlich: "wenn ältere Versionen dieses Update laden, MÜSSEN ALLE Läden
/// zwingend bleiben." Dieser Test prüft exakt das — offline, deterministisch, ohne echtes
/// Gerät oder echte iCloud-Verbindung nötig (die Schema-/Datei-Validierung von SwiftData läuft
/// synchron und lokal, bevor überhaupt ein Netzwerkzugriff versucht wird).
final class ExistingDataSurvivesCloudEnableTests: XCTestCase {
    func testExistingLocalStoreSurvivesFirstCloudKitOpen() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-cktest-\(UUID().uuidString).store")
        defer { SchemaCloudKitCompatibilityTests.removeStoreFiles(at: tempURL) }

        let distinctiveStoreName = "TestLaden-\(UUID().uuidString)"
        let distinctiveItemName = "TestArtikel-\(UUID().uuidString)"

        // 1. Genau wie ein Bestandsnutzer VOR dem Schema-Fix: lokal-only, Cloud noch nie
        // versucht. Store UND ein zugehöriger ShoppingItem, um auch die @Relationship-Kette
        // (Store.items) mit abzudecken, nicht nur ein einzelnes flaches Modell.
        do {
            let localOnlyConfig = ModelConfiguration(url: tempURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: localOnlyConfig)
            let context = ModelContext(container)
            let store = Store(name: distinctiveStoreName, emoji: "🛒", colorHex: "#123456")
            let item = ShoppingItem(name: distinctiveItemName, store: store)
            context.insert(store)
            context.insert(item)
            try context.save()

            // Sanity-Check: wurde überhaupt etwas gespeichert, bevor wir zur Cloud-Stufe gehen?
            let storesBefore = try context.fetch(FetchDescriptor<Store>())
            XCTAssertEqual(storesBefore.count, 1, "Setup fehlgeschlagen — Store wurde nicht lokal gespeichert, Test kann nichts beweisen.")
        }

        // 2. Dieselbe Datei jetzt zum ERSTEN MAL mit CloudKit-Konfiguration öffnen.
        let cloudContainer = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(url: tempURL, cloudKitDatabase: .private(SharedModelContainer.cloudKitContainerID))
        )
        let cloudContext = ModelContext(cloudContainer)

        let storesAfter = try cloudContext.fetch(FetchDescriptor<Store>())
        XCTAssertTrue(
            storesAfter.contains { $0.name == distinctiveStoreName },
            "Bestehender lokaler Store ist nach dem ersten Cloud-Öffnen verschwunden — genau der Datenverlust, den der Nutzer explizit ausgeschlossen haben will."
        )

        let itemsAfter = try cloudContext.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertTrue(
            itemsAfter.contains { $0.name == distinctiveItemName },
            "Bestehender lokaler ShoppingItem ist nach dem ersten Cloud-Öffnen verschwunden."
        )
    }
}
