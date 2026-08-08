import XCTest
@testable import Restock

/// `[PurchaseRecord].consumptionPattern()` (PurchaseRecord.swift) ist die reine Vorhersagelogik
/// hinter "wann wird X wieder gebraucht" — bisher ohne Testabdeckung, obwohl ein Regressionsfehler
/// hier still den ganzen "Bald fällig"-Bereich der Startseite falsch befüllen würde. Alle
/// Zeitpunkte kommen aus `DateFixtures` (relativ zu `Date()`, keine hartkodierte TimeZone), damit
/// die Tests unabhängig von der Zeitzone des ausführenden Rechners/Runners funktionieren.
final class ConsumptionPatternTests: XCTestCase {

    func testReturnsNilWithFewerThanTwoRecords() {
        let single = [PurchaseRecord(itemName: "Milch", storeName: "Edeka")]
        XCTAssertNil(single.consumptionPattern())
        XCTAssertNil(([] as [PurchaseRecord]).consumptionPattern())
    }

    func testAveragesRegularPurchaseInterval() throws {
        // Käufe alle 7 Tage, zuletzt vor 7 Tagen -> nächster Bedarf sollte "heute" sein.
        let records = [
            record("Milch", daysAgo: 21),
            record("Milch", daysAgo: 14),
            record("Milch", daysAgo: 7),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, 7, accuracy: 0.01)
        XCTAssertEqual(pattern.itemName, "Milch")
    }

    func testOverdueWhenEstimatedDateIsInThePast() throws {
        // Muster: alle 5 Tage, letzter Kauf vor 20 Tagen -> längst überfällig.
        let records = [
            record("Zahnpasta", daysAgo: 25),
            record("Zahnpasta", daysAgo: 20),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertTrue(pattern.isOverdue)
        XCTAssertFalse(pattern.isDueSoon)
    }

    func testDueSoonWhenEstimatedDateIsWithinAWeek() throws {
        // Muster: alle 10 Tage, letzter Kauf vor 4 Tagen -> nächster Bedarf in 6 Tagen.
        let records = [
            record("Kaffee", daysAgo: 24),
            record("Kaffee", daysAgo: 14),
            record("Kaffee", daysAgo: 4),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertFalse(pattern.isOverdue)
        XCTAssertTrue(pattern.isDueSoon)
    }

    func testNotDueSoonWhenEstimatedDateIsFarInTheFuture() throws {
        // Muster: alle 30 Tage, letzter Kauf vor 2 Tagen -> nächster Bedarf erst in ~28 Tagen.
        let records = [
            record("Waschmittel", daysAgo: 32),
            record("Waschmittel", daysAgo: 2),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertFalse(pattern.isOverdue)
        XCTAssertFalse(pattern.isDueSoon)
    }

    func testOutlierIntervalIsExcludedFromAverageWithEnoughSamples() throws {
        // Vier reguläre 7-Tage-Intervalle plus ein einzelner 90-Tage-Ausreißer (z.B. Urlaub) --
        // der Ausreißer soll den Schnitt nicht auf ~26 Tage hochziehen.
        let records = [
            record("Milch", daysAgo: 121),
            record("Milch", daysAgo: 31), // 90 Tage Lücke: Ausreißer
            record("Milch", daysAgo: 24),
            record("Milch", daysAgo: 17),
            record("Milch", daysAgo: 10),
            record("Milch", daysAgo: 3),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, 7, accuracy: 1.0)
    }

    // MARK: - Helpers

    private func record(_ name: String, daysAgo: Int) -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: "Edeka")
        r.date = DateFixtures.daysAgo(daysAgo)
        return r
    }
}
