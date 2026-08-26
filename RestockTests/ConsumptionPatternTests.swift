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

    // "isDueSoon" war ursprünglich ein 7-Tage-Fenster; auf Nutzer-Wunsch (24.08.2026, zu viele
    // gleichzeitige "bald fällig"-Meldungen direkt nach dem Einkaufen) auf 2 Tage verengt — siehe
    // PurchaseRecord.swift. Die Tests unten pinnen die neue Grenze fest, statt sie nur implizit
    // über den Produktionswert mitlaufen zu lassen.
    //
    // WICHTIG für die gewählten Werte: `daysUntilNeeded` rundet über
    // `Calendar.dateComponents([.day], from: Date(), to: ...)` auf VOLLE, bereits verstrichene
    // Kalendertage ab (kein Runden) — und zwischen dem Bau der Test-Fixtures (erster `Date()`-Call
    // in `DateFixtures.daysAgo`) und der Auswertung von `pattern.isDueSoon` (zweiter, späterer
    // `Date()`-Call in `daysUntilNeeded` selbst) vergehen immer ein paar Millisekunden reale
    // Ausführungszeit. Ein rechnerisch "exakt N Tage" entferntes Datum wird dadurch beim Auswerten
    // IMMER als "N-1" gemessen (knapp unter N vollen Tagen). Ein Test, der exakt auf der
    // rechnerischen Ganzzahl-Grenze sitzt (z. B. "exakt 3 Tage" mit der Erwartung "nicht mehr bald
    // fällig"), ist deshalb inhärent brüchig — er testet in Wahrheit N-1, nicht N. Die Werte unten
    // haben deshalb bewusst 1 Tag Sicherheitsabstand zur eigentlich gemeinten Grenze.

    func testNotDueSoonWhenEstimatedDateIsAboutFourDaysOut() throws {
        // Muster: alle 10 Tage, letzter Kauf vor 6 Tagen -> rechnerisch 4 Tage entfernt, gemessen
        // ~3 Tage (siehe Rundungs-Hinweis oben) — in jedem Fall außerhalb des 2-Tage-Fensters
        // (vorher, mit 7 Tagen, wäre das noch "due soon" gewesen).
        let records = [
            record("Kaffee", daysAgo: 16),
            record("Kaffee", daysAgo: 6),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertFalse(pattern.isOverdue)
        XCTAssertFalse(pattern.isDueSoon, "~3 gemessene Tage liegen außerhalb des 2-Tage-Fensters")
    }

    func testDueSoonWhenEstimatedDateIsAboutTwoDaysOut() throws {
        // Muster: alle 10 Tage, letzter Kauf vor 7 Tagen -> rechnerisch 3 Tage entfernt, gemessen
        // ~2 Tage — deckt die inklusive Fenstergrenze ab.
        let records = [
            record("Kaffee", daysAgo: 17),
            record("Kaffee", daysAgo: 7),
        ]
        let pattern = try XCTUnwrap(records.consumptionPattern())
        XCTAssertFalse(pattern.isOverdue)
        XCTAssertTrue(pattern.isDueSoon, "~2 gemessene Tage müssen noch als 'bald fällig' zählen (inklusive Grenze)")
    }

    func testDueSoonWhenEstimatedDateIsAboutOneDayOut() throws {
        // Muster: alle 10 Tage, letzter Kauf vor 9 Tagen -> rechnerisch 1 Tag entfernt, gemessen
        // ~0 Tage (heute fällig).
        let records = [
            record("Kaffee", daysAgo: 19),
            record("Kaffee", daysAgo: 9),
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
