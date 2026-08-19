import XCTest
import SwiftData
@testable import Restock

/// Beweist die Kernanforderung von `deleteRule: .nullify` auf `ShoppingItem.purchaseRecords`
/// (umgestellt von `.cascade` am 19.08.2026, siehe Kommentar dort): PurchaseRecords müssen das
/// Löschen des zugehörigen ShoppingItems (bzw. des ganzen Stores) überleben, weil sie die
/// Datenquelle für storeübergreifende Produkt-Vorschläge (`QuickAddParser.knownProductSuggestions`)
/// sind. Eine unabhängige Review-Runde stellte fest, dass keiner der bestehenden 90 Tests dieses
/// Verhalten tatsächlich prüft — die Suite hätte eine versehentliche Rückkehr zu `.cascade` (oder
/// einen Tippfehler zu `.deny`) nicht bemerkt.
final class PurchaseRecordDeletionTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func testPurchaseRecordSurvivesItemDeletion() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "TestLaden", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "TestArtikel", store: store)
        context.insert(store)
        context.insert(item)
        let record = PurchaseRecord(itemName: item.name, storeName: store.name, quantityAmount: 1, unit: "", actualPrice: nil)
        record.item = item
        context.insert(record)
        try context.save()

        let recordsBefore = try context.fetch(FetchDescriptor<PurchaseRecord>())
        XCTAssertEqual(recordsBefore.count, 1, "Setup fehlgeschlagen — PurchaseRecord wurde nicht gespeichert, Test kann nichts beweisen.")

        context.delete(item)
        try context.save()

        let recordsAfter = try context.fetch(FetchDescriptor<PurchaseRecord>())
        XCTAssertEqual(recordsAfter.count, 1, "PurchaseRecord wurde beim Löschen des Items mitgelöscht — deleteRule ist nicht mehr .nullify.")
        XCTAssertNil(recordsAfter.first?.item, "PurchaseRecord.item sollte nach dem Löschen des Items nil sein.")
        XCTAssertEqual(recordsAfter.first?.itemName, "TestArtikel")
    }

    func testPurchaseRecordSurvivesStoreDeletion() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "TestLaden2", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "TestArtikel2", store: store)
        context.insert(store)
        context.insert(item)
        let record = PurchaseRecord(itemName: item.name, storeName: store.name, quantityAmount: 1, unit: "", actualPrice: nil)
        record.item = item
        context.insert(record)
        try context.save()

        context.delete(store)
        try context.save()

        let recordsAfter = try context.fetch(FetchDescriptor<PurchaseRecord>())
        XCTAssertEqual(recordsAfter.count, 1, "PurchaseRecord wurde beim Löschen des Stores (kaskadiert über ShoppingItem) mitgelöscht.")
        XCTAssertNil(recordsAfter.first?.item)
    }

    func testKnownProductSuggestionsSurviveItemDeletion() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "TestLaden3", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "Hafermilch", store: store)
        context.insert(store)
        context.insert(item)
        let record = PurchaseRecord(itemName: item.name, storeName: store.name, quantityAmount: 1, unit: "", actualPrice: nil)
        record.item = item
        context.insert(record)
        try context.save()

        context.delete(item)
        try context.save()

        let allRecords = try context.fetch(FetchDescriptor<PurchaseRecord>())
        let suggestions = QuickAddParser.knownProductSuggestions(for: "Hafer", in: allRecords, itemNames: [])
        XCTAssertTrue(suggestions.contains("Hafermilch"), "Produktvorschlag ist nach dem Löschen des Items verschwunden — genau der gemeldete Bug (19.08.2026).")
    }
}
