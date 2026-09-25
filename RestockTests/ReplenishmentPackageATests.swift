import XCTest
import SwiftData
@testable import Restock

/// Fehlerbehebungen aus Issue #30, Paket A („Zeit zum Nachkaufen“):
/// A1 doppelte Mengenskalierung, A2 `markPending()` macht den Kaufdatensatz rückgängig,
/// A3 überfällige Push-Nachricht nur einmal pro Termin, A4 übernommener und ohne Kauf wieder
/// gelöschter Vorschlag zählt wie ✕.
final class ReplenishmentPackageATests: XCTestCase {

    // MARK: - A1

    func testIntervalIsNotScaledByPurchaseQuantity() throws {
        // Alle 7 Tage je 2 Stück: der nächste Bedarf liegt nach 7 Tagen, nicht nach 14.
        let records = [
            record("Joghurt", daysAgo: 21, quantity: 2),
            record("Joghurt", daysAgo: 14, quantity: 2),
            record("Joghurt", daysAgo: 7, quantity: 2),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        // Toleranz 0,05 statt 0,01: `DateFixtures` rechnet in Kalendertagen der lokalen Zeitzone,
        // liegt eine Zeitumstellung in den letzten 21 Tagen, ist ein Abstand 7 ± 1/24 Tage.
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, 7, accuracy: 0.05)
        XCTAssertEqual(pattern.averageQuantityPerPurchase, 2, accuracy: 0.01)
        XCTAssertEqual(
            pattern.estimatedNextPurchaseDate.timeIntervalSince(pattern.lastPurchaseDate) / 86400,
            7, accuracy: 0.05
        )
    }

    // MARK: - A2

    func testMarkPendingRemovesRecordCreatedByMarkCompleted() throws {
        let context = try makeInMemoryContext()
        let item = ShoppingItem(name: "Milch")
        context.insert(item)
        item.markCompleted()
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<PurchaseRecord>()).count, 1, "Setup: Abhaken muss einen Datensatz anlegen.")

        item.markPending()
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<PurchaseRecord>()).count, 0, "Verklicker darf nicht als Kauf im Store bleiben.")
        XCTAssertTrue(item.purchaseRecords?.isEmpty ?? true)
        XCTAssertFalse(item.isCompleted)
    }

    func testMarkPendingKeepsEarlierPurchases() throws {
        let context = try makeInMemoryContext()
        let item = ShoppingItem(name: "Milch")
        context.insert(item)
        let earlier = record("Milch", daysAgo: 10)
        earlier.item = item
        context.insert(earlier)
        item.markCompleted()
        item.markPending()
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PurchaseRecord>())
        XCTAssertEqual(remaining.map(\.id), [earlier.id], "Nur der Datensatz aus diesem Abhaken darf verschwinden.")
    }

    func testMarkPendingKeepsRecordWithReceiptPrice() throws {
        let context = try makeInMemoryContext()
        let item = ShoppingItem(name: "Milch")
        context.insert(item)
        item.markCompleted()
        item.purchaseRecords?.first?.actualPrice = 1.19
        item.markPending()
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<PurchaseRecord>()).count, 1, "Ein Bon-Preis belegt einen echten Kauf.")
    }

    // MARK: - A3

    func testOverdueNotificationOnlyOncePerEstimatedDate() throws {
        let suite = "ReplenishmentPackageATests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let ledger = OverdueNotificationLedger(defaults: defaults)

        let overdue = pattern("Zahnpasta", nextInDays: -3)
        XCTAssertTrue(ledger.shouldNotify(overdue))
        ledger.markNotified(overdue)
        XCTAssertFalse(ledger.shouldNotify(overdue), "Jeder weitere Refresh darf nicht erneut pushen.")
        XCTAssertFalse(ledger.shouldNotify(pattern("zahnpasta", nextInDays: -3, reference: overdue)), "Groß-/Kleinschreibung egal.")

        // Neuer Kauf -> neuer Termin -> wieder meldefähig.
        XCTAssertTrue(ledger.shouldNotify(pattern("Zahnpasta", nextInDays: -1)))
    }

    // MARK: - A4

    func testAcceptedSuggestionDeletedWithoutPurchaseIsDismissed() {
        let milk = pattern("Milch", nextInDays: -1)
        let id = UUID()
        let result = ReplenishmentFeedback.resolveAccepted(
            [id: accepted(milk)], existingItemIDs: [], pendingNames: [], patterns: [milk]
        )
        XCTAssertTrue(result.stillTracked.isEmpty)
        XCTAssertEqual(result.dismissals, ["milch": milk.estimatedNextPurchaseDate.timeIntervalSince1970])
    }

    func testAcceptedSuggestionStillOnListIsKeptTracked() {
        let milk = pattern("Milch", nextInDays: -1)
        let id = UUID()
        let result = ReplenishmentFeedback.resolveAccepted(
            [id: accepted(milk)], existingItemIDs: [id], pendingNames: ["milch"], patterns: [milk]
        )
        XCTAssertEqual(result.stillTracked, [id: accepted(milk)])
        XCTAssertTrue(result.dismissals.isEmpty)
    }

    func testAcceptedSuggestionPurchasedThenDeletedIsNoSignal() {
        // Abgehakt (neuer Datensatz verschiebt den Termin), danach "Erledigte löschen".
        let before = pattern("Milch", nextInDays: -1)
        let afterPurchase = pattern("Milch", nextInDays: 7)
        let result = ReplenishmentFeedback.resolveAccepted(
            [UUID(): accepted(before)], existingItemIDs: [], pendingNames: [], patterns: [afterPurchase]
        )
        XCTAssertTrue(result.stillTracked.isEmpty)
        XCTAssertTrue(result.dismissals.isEmpty)

        let noLongerDue = ReplenishmentFeedback.resolveAccepted(
            [UUID(): accepted(before)], existingItemIDs: [], pendingNames: [], patterns: []
        )
        XCTAssertTrue(noLongerDue.dismissals.isEmpty)
    }

    func testAcceptedSuggestionReplacedBySamePendingItemIsNoSignal() {
        let milk = pattern("Milch", nextInDays: -1)
        let result = ReplenishmentFeedback.resolveAccepted(
            [UUID(): accepted(milk)], existingItemIDs: [], pendingNames: ["milch"], patterns: [milk]
        )
        XCTAssertTrue(result.stillTracked.isEmpty)
        XCTAssertTrue(result.dismissals.isEmpty)
    }

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func record(_ name: String, daysAgo: Int, quantity: Double = 1) -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: "Edeka", quantityAmount: quantity)
        r.date = DateFixtures.daysAgo(daysAgo)
        return r
    }

    /// `reference` übernimmt dessen Termin exakt, damit nur der Name variiert.
    private func pattern(_ name: String, nextInDays: Int, reference: ConsumptionPattern? = nil) -> ConsumptionPattern {
        let next = reference?.estimatedNextPurchaseDate ?? DateFixtures.daysFromNow(nextInDays)
        return ConsumptionPattern(
            itemName: name,
            averageDaysBetweenPurchases: 7,
            averageQuantityPerPurchase: 1,
            lastPurchaseDate: next.addingTimeInterval(-7 * 86400),
            estimatedNextPurchaseDate: next
        )
    }

    private func accepted(_ pattern: ConsumptionPattern) -> AcceptedReplenishment {
        AcceptedReplenishment(
            itemName: pattern.itemName,
            estimatedNextPurchaseDate: pattern.estimatedNextPurchaseDate.timeIntervalSince1970
        )
    }
}
