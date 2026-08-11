import XCTest
import SwiftData
@testable import Restock

/// Testet die reine Kandidatenlisten-Aufbau-Logik für Stufe 5 (Apple Intelligence) des
/// Kassenbon-Namensauflösung — der einzige Teil von `A2` (KI-Prompt-Kontext), der ohne echtes
/// on-device Modell automatisiert testbar ist.
final class ReceiptKnownItemNamesTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func record(_ name: String, store: String, daysAgo: Double) -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: store)
        r.date = Date().addingTimeInterval(-daysAgo * 86400)
        return r
    }

    func testDeduplicatesCaseAndDiacriticInsensitively() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let item = ShoppingItem(name: "Müsli", store: store)
        context.insert(item)

        let records = [record("müsli", store: "Lidl", daysAgo: 1)]
        let names = ReceiptResolutionService.knownItemNames(allRecords: records, store: store)

        XCTAssertEqual(names.count, 1, "\"Müsli\" und \"müsli\" müssen als ein Eintrag zählen, gefunden: \(names)")
    }

    func testCapsAtLimit() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)

        let records = (0..<100).map { record("Artikel \($0)", store: "Lidl", daysAgo: Double($0)) }
        let names = ReceiptResolutionService.knownItemNames(allRecords: records, store: store, limit: 40)

        XCTAssertEqual(names.count, 40)
    }

    func testIncludesPendingStoreItemsNotOnlyPurchaseHistory() throws {
        let context = try makeInMemoryContext()
        let store = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        context.insert(store)
        let pending = ShoppingItem(name: "Burger Brötchen", store: store)
        context.insert(pending)

        let names = ReceiptResolutionService.knownItemNames(allRecords: [], store: store)

        XCTAssertTrue(names.contains("Burger Brötchen"))
    }
}
