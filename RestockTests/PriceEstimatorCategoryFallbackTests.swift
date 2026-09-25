import XCTest
@testable import Restock

/// Beweist den Fix für Issue #12: die 26 Kategorie-Pauschalpreise in `PriceEstimator.estimate`
/// kollidierten an mehreren Stellen exakt (am auffälligsten "Obst & Gemüse"/"Lebensmittel" bei
/// beide 2,50€) — siehe `docs/specs/models/price-estimator-category-fallback.md`. Alle 26 Werte
/// müssen danach paarweise verschieden sein, ohne eine amtliche Quelle zu behaupten
/// (PO-Entscheidung 2026-09-25, Alternative 1: nur das Symptom beheben).
final class PriceEstimatorCategoryFallbackTests: XCTestCase {

    // MARK: - AC-1: Alle 26 Kategorie-Pauschalpreise sind paarweise verschieden

    func testAllCategoryFallbackPricesAreDistinct() {
        let prices = AssignmentService.categoryOrder.map {
            PriceEstimator.estimate(for: "artikel ohne keyword-treffer", category: $0, unit: "", quantityAmount: 1)
        }

        XCTAssertEqual(AssignmentService.categoryOrder.count, 26, "Erwartet genau 26 Kategorien in categoryOrder")
        XCTAssertTrue(prices.allSatisfy { $0 != nil }, "Jede der 26 Kategorien muss einen Pauschalpreis liefern")

        let uniquePrices = Set(prices.compactMap { $0 })
        XCTAssertEqual(uniquePrices.count, prices.count, "Alle 26 Kategorie-Pauschalpreise müssen paarweise verschieden sein — aktuell kollidieren mehrere (z. B. 'Obst & Gemüse' und 'Lebensmittel' bei 2,50€)")
    }

    // MARK: - AC-2: Das im Ticket genannte Symptom (Obst & Gemüse == Lebensmittel)

    func testObstUndGemueseDiffersFromLebensmittel() {
        let obstUndGemuese = PriceEstimator.estimate(for: "artikel", category: "Obst & Gemüse", unit: "", quantityAmount: 1)
        let lebensmittel = PriceEstimator.estimate(for: "artikel", category: "Lebensmittel", unit: "", quantityAmount: 1)

        XCTAssertEqual(obstUndGemuese, 2.50)
        XCTAssertEqual(lebensmittel, 2.90)
        XCTAssertNotEqual(obstUndGemuese, lebensmittel)
    }

    // MARK: - AC-3: Milchprodukte / Backwaren / Gewürze & Backen / Konserven

    func testMilchproduktGruppeIstDifferenziert() {
        let milchprodukte = PriceEstimator.estimate(for: "artikel", category: "Milchprodukte", unit: "", quantityAmount: 1)
        let backwaren = PriceEstimator.estimate(for: "artikel", category: "Backwaren", unit: "", quantityAmount: 1)
        let gewuerzeUndBacken = PriceEstimator.estimate(for: "artikel", category: "Gewürze & Backen", unit: "", quantityAmount: 1)
        let konserven = PriceEstimator.estimate(for: "artikel", category: "Konserven", unit: "", quantityAmount: 1)

        XCTAssertEqual(milchprodukte, 2.00)
        XCTAssertEqual(backwaren, 2.20)
        XCTAssertEqual(gewuerzeUndBacken, 3.20)
        XCTAssertEqual(konserven, 1.70)

        let values = [milchprodukte, backwaren, gewuerzeUndBacken, konserven].compactMap { $0 }
        XCTAssertEqual(Set(values).count, values.count, "Alle vier Werte müssen paarweise verschieden sein")
    }

    // MARK: - AC-4: Babybedarf / Küchenausstattung / Textilien / Garten

    func testBabybedarfGruppeIstDifferenziert() {
        let babybedarf = PriceEstimator.estimate(for: "artikel", category: "Babybedarf", unit: "", quantityAmount: 1)
        let kuechenausstattung = PriceEstimator.estimate(for: "artikel", category: "Küchenausstattung", unit: "", quantityAmount: 1)
        let textilien = PriceEstimator.estimate(for: "artikel", category: "Textilien", unit: "", quantityAmount: 1)
        let garten = PriceEstimator.estimate(for: "artikel", category: "Garten", unit: "", quantityAmount: 1)

        XCTAssertEqual(babybedarf, 8.00)
        XCTAssertEqual(kuechenausstattung, 9.50)
        XCTAssertEqual(textilien, 7.00)
        XCTAssertEqual(garten, 7.50)

        let values = [babybedarf, kuechenausstattung, textilien, garten].compactMap { $0 }
        XCTAssertEqual(Set(values).count, values.count, "Alle vier Werte müssen paarweise verschieden sein")
    }

    // MARK: - AC-5: Elektronik / Spielzeug / Sanitär

    func testElektronikGruppeIstDifferenziert() {
        let elektronik = PriceEstimator.estimate(for: "artikel", category: "Elektronik", unit: "", quantityAmount: 1)
        let spielzeug = PriceEstimator.estimate(for: "artikel", category: "Spielzeug", unit: "", quantityAmount: 1)
        let sanitaer = PriceEstimator.estimate(for: "artikel", category: "Sanitär", unit: "", quantityAmount: 1)

        XCTAssertEqual(elektronik, 14.00)
        XCTAssertEqual(spielzeug, 10.00)
        XCTAssertEqual(sanitaer, 11.50)

        let values = [elektronik, spielzeug, sanitaer].compactMap { $0 }
        XCTAssertEqual(Set(values).count, values.count, "Alle drei Werte müssen paarweise verschieden sein")
    }

    // MARK: - AC-6: Tiefkühlkost/Reinigung, Medikamente/Dekoration, Werkzeug/Baumaterial

    func testVerbleibendePaareSindDifferenziert() {
        let tiefkuehlkost = PriceEstimator.estimate(for: "artikel", category: "Tiefkühlkost", unit: "", quantityAmount: 1)
        let reinigung = PriceEstimator.estimate(for: "artikel", category: "Reinigung", unit: "", quantityAmount: 1)
        XCTAssertEqual(tiefkuehlkost, 3.50)
        XCTAssertEqual(reinigung, 3.90)
        XCTAssertNotEqual(tiefkuehlkost, reinigung)

        let medikamente = PriceEstimator.estimate(for: "artikel", category: "Medikamente", unit: "", quantityAmount: 1)
        let dekoration = PriceEstimator.estimate(for: "artikel", category: "Dekoration", unit: "", quantityAmount: 1)
        XCTAssertEqual(medikamente, 6.00)
        XCTAssertEqual(dekoration, 6.50)
        XCTAssertNotEqual(medikamente, dekoration)

        let werkzeug = PriceEstimator.estimate(for: "artikel", category: "Werkzeug", unit: "", quantityAmount: 1)
        let baumaterial = PriceEstimator.estimate(for: "artikel", category: "Baumaterial", unit: "", quantityAmount: 1)
        XCTAssertEqual(werkzeug, 12.00)
        XCTAssertEqual(baumaterial, 13.50)
        XCTAssertNotEqual(werkzeug, baumaterial)
    }

    // MARK: - AC-7: specificPrices bleibt unverändert (Regression, außerhalb des Scopes)

    func testSpecificPricesBleibenUnveraendert() {
        // "Milch" trifft das specificPrices-Keyword, bevor der Kategorie-Fallback überhaupt
        // greift — Kategorie ist absichtlich "Sonstiges" (kein switch-Fall), um zu beweisen,
        // dass der Preis aus specificPrices kommt, nicht aus einem Kategorie-Fallback.
        let price = PriceEstimator.estimate(for: "Milch", category: "Sonstiges", unit: "", quantityAmount: 1)
        XCTAssertEqual(price, 1.20, "specificPrices-Werte dürfen durch diese Änderung nicht angefasst werden")
    }

    // MARK: - AC-8: Unbekannte Kategorie liefert weiterhin nil

    func testUnbekannteKategorieLiefertNil() {
        let price = PriceEstimator.estimate(for: "artikel ohne keyword-treffer", category: "Nicht existierende Kategorie", unit: "", quantityAmount: 1)
        XCTAssertNil(price)
    }
}
