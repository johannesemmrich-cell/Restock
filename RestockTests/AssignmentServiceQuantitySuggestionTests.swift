import XCTest
@testable import Restock

/// TDD RED (Issue #57, `docs/specs/services/assignment-service-quantity-suggestion.md`): beweist
/// den kompletten Test Plan für `AssignmentService.suggestQuantity(itemName:storeName:
/// purchaseRecords:)` — zum Zeitpunkt dieses Commits gibt es diese Funktion noch nicht, der Build
/// schlägt deshalb mit einem Compile-Fehler fehl ("Type 'AssignmentService' has no member
/// 'suggestQuantity'"), nicht mit einzelnen roten Testläufen. Das IST der RED-Beweis für Swift:
/// eine fehlende Funktion verhindert das Kompilieren der gesamten Testdatei.
final class AssignmentServiceQuantitySuggestionTests: XCTestCase {

    private func store(_ name: String = "Lidl") -> Store {
        Store(name: name, emoji: "🛒", colorHex: "#123456")
    }

    /// `PurchaseRecord.date` wird im Initializer immer auf `Date()` (jetzt) gesetzt — für
    /// Fixtures mit unterschiedlichen Kaufzeitpunkten wird die gespeicherte `var` danach direkt
    /// überschrieben, dieselbe Technik, die auch die übrige Testsuite (`ConsumptionPatternTests`)
    /// für Kaufhistorie-Fixtures verwendet.
    private func record(_ itemName: String, storeName: String, amount: Double, unit: String, daysAgo: Int) -> PurchaseRecord {
        let record = PurchaseRecord(itemName: itemName, storeName: storeName, quantityAmount: amount, unit: unit)
        record.date = DateFixtures.daysAgo(daysAgo)
        return record
    }

    // MARK: - AC-11: Stufe „history" — letzter Kauf im selben Laden, namesRepresentSameItem statt contains()

    func testSuggestsLastPurchaseFromSameStore() {
        // GIVEN ein Kauf desselben Artikels im selben Laden liegt vor
        let purchases = [record("Milch", storeName: "Lidl", amount: 2, unit: "l", daysAgo: 3)]

        // WHEN suggestQuantity aufgerufen wird
        let result = AssignmentService.suggestQuantity(itemName: "Milch", storeName: "Lidl", purchaseRecords: purchases)

        // THEN liefert es dessen Menge/Einheit und source == "history"
        XCTAssertEqual(result.quantity, "2")
        XCTAssertEqual(result.unit, "l")
        XCTAssertEqual(result.source, "history")
    }

    func testIgnoresPurchaseFromDifferentStore() {
        // GIVEN derselbe Artikel wurde nur in einem ANDEREN Laden gekauft
        let purchases = [record("Milch", storeName: "Edeka", amount: 2, unit: "l", daysAgo: 3)]

        // WHEN suggestQuantity mit dem aktuellen Laden aufgerufen wird
        let result = AssignmentService.suggestQuantity(itemName: "Milch", storeName: "Lidl", purchaseRecords: purchases)

        // THEN wird NICHT laden-übergreifend zurückgefallen — Ergebnis ist Stufe "package" oder
        // "none", nie "history"
        XCTAssertNotEqual(result.source, "history", "Ein Kauf in einem anderen Laden darf nicht als Treffer zählen — PO-Entscheidung 2 verlangt 'in diesem Laden'")
    }

    func testUsesNamesRepresentSameItemNotSubstring() {
        // GIVEN ein Kauf von „Eierlikör" liegt vor, der Nutzer tippt „Eier"
        let purchases = [record("Eierlikör", storeName: "Lidl", amount: 1, unit: "Stk", daysAgo: 1)]

        // WHEN suggestQuantity aufgerufen wird
        let result = AssignmentService.suggestQuantity(itemName: "Eier", storeName: "Lidl", purchaseRecords: purchases)

        // THEN wird der Eierlikör-Kauf NICHT als Treffer gewertet (kein contains()-Fehltreffer)
        XCTAssertNotEqual(result.source, "history", "Eierlikör darf nicht als Treffer für Eier zählen — dieselbe Fehlerklasse, gegen die namesRepresentSameItem bereits gebaut wurde")
    }

    func testMatchesQualifierVariantViaNamesRepresentSameItem() {
        // GIVEN ein Kauf von „Bio Eier" liegt vor, der Nutzer tippt „Eier"
        let purchases = [record("Bio Eier", storeName: "Lidl", amount: 10, unit: "Stk", daysAgo: 2)]

        // WHEN suggestQuantity aufgerufen wird
        let result = AssignmentService.suggestQuantity(itemName: "Eier", storeName: "Lidl", purchaseRecords: purchases)

        // THEN liefert es diesen Kauf mit source == "history" (Qualifizierer-Toleranz von namesRepresentSameItem)
        XCTAssertEqual(result.quantity, "10")
        XCTAssertEqual(result.unit, "Stk")
        XCTAssertEqual(result.source, "history")
    }

    func testPicksMostRecentPurchaseNotAverage() {
        // GIVEN mehrere Käufe desselben Artikels im selben Laden mit unterschiedlichen Mengen und Daten liegen vor
        let purchases = [
            record("Milch", storeName: "Lidl", amount: 2, unit: "l", daysAgo: 30),
            record("Milch", storeName: "Lidl", amount: 6, unit: "l", daysAgo: 1),
            record("Milch", storeName: "Lidl", amount: 1, unit: "l", daysAgo: 15),
        ]

        // WHEN suggestQuantity aufgerufen wird
        let result = AssignmentService.suggestQuantity(itemName: "Milch", storeName: "Lidl", purchaseRecords: purchases)

        // THEN liefert es die Menge des Kaufs mit dem spätesten Datum (6, vor 1 Tag), nicht einen
        // Durchschnitt (3)
        XCTAssertEqual(result.quantity, "6", "Muss den zeitlich letzten Kauf liefern, nicht den Durchschnitt")
        XCTAssertEqual(result.unit, "l")
        XCTAssertEqual(result.source, "history")
    }

    // MARK: - AC-12: Stufe „package" — Füllmenge im getippten Namen

    func testFallsBackToPackageSizeWhenNoHistory() {
        // GIVEN keine Kaufhistorie liegt vor, der Name enthält „500G"
        let resultGrams = AssignmentService.suggestQuantity(itemName: "Skyr Natur 500G", storeName: "Lidl", purchaseRecords: [])

        // WHEN/THEN liefert es ("500", "g", "package")
        XCTAssertEqual(resultGrams.quantity, "500")
        XCTAssertEqual(resultGrams.unit, "g")
        XCTAssertEqual(resultGrams.source, "package")

        // Zweites Beispiel aus AC-12: „Cola 0,5L" → ("500", "ml", "package") — Liter wird als
        // Volumen erkannt (nicht als Gewicht), Milliliter normiert.
        let resultMilliliters = AssignmentService.suggestQuantity(itemName: "Cola 0,5L", storeName: "Lidl", purchaseRecords: [])

        XCTAssertEqual(resultMilliliters.quantity, "500")
        XCTAssertEqual(resultMilliliters.unit, "ml")
        XCTAssertEqual(resultMilliliters.source, "package")
    }

    // MARK: - AC-13: Stufe „none" — keine Evidenz

    func testReturnsNoneWhenNoEvidenceAtAll() {
        // GIVEN keine Kaufhistorie und keine Füllmenge im Namen
        let result = AssignmentService.suggestQuantity(itemName: "Kaffee", storeName: "Lidl", purchaseRecords: [])

        // WHEN/THEN liefert es leere Menge, leere Einheit, source == "none"
        XCTAssertEqual(result.quantity, "")
        XCTAssertEqual(result.unit, "")
        XCTAssertEqual(result.source, "none")
    }

    // MARK: - AC-18: WCAG-Kontrastnachweis (rechnerisch, siehe Spec „Implementation Details 4")
    //
    // Dieser einzelne Test ist beim Schreiben bereits GRÜN, nicht Teil des RED-Beweises: er prüft
    // einen bestehenden, unveränderten Farbwert (RCAmber/RCSurface existieren bereits), keinen
    // neuen Code. Das ist laut Spec so vorgesehen — ein reiner Rechen-Nachweis statt einer
    // Sichtprüfung im Simulator. Baut auf demselben WCAG-2.1-Algorithmus wie die private
    // Hilfsfunktion unten, die dafür extra in dieser Datei lebt (kein Produktcode betroffen).

    func testAmberDarkModeContrastMeetsWCAGAA() {
        // GIVEN die RGB-Werte von RCAmber und RCSurface in der Dunkelmodus-Variante
        // (Assets.xcassets/RCAmber.colorset/Contents.json bzw. RCSurface.colorset/Contents.json)
        let amberDark = (r: 0.784, g: 0.604, b: 0.290)
        let surfaceDark = (r: 0.114, g: 0.110, b: 0.086)

        // WHEN das WCAG-Kontrastverhältnis berechnet wird
        let ratio = wcagContrastRatio(amberDark, surfaceDark)

        // THEN ist es >= 4.5 (Level AA für Fließtext, WCAG 2.1 Kriterium 1.4.3)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Color.amber (dark) auf Color.surface (dark) muss WCAG 2.1 AA für Fließtext erfüllen")
    }

    // MARK: - WCAG 2.1 Kontrastformel (relative Luminanz, Testcode — kein Produktcode)

    private func relativeLuminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    private func wcagContrastRatio(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let l1 = relativeLuminance(a)
        let l2 = relativeLuminance(b)
        let (lighter, darker) = l1 > l2 ? (l1, l2) : (l2, l1)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
