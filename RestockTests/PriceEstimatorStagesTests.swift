import XCTest
@testable import Restock

/// Charakterisiert das bisher nirgends dokumentierte Drei-Stufen-Preismodell aus
/// `ShoppingItem.init` (siehe `docs/specs/models/price-estimator-stages.md`, Issue #13):
/// gelernter Preis (`Store.learnedPrices`) schlägt Produkt-Keyword (`PriceEstimator.specificPrices`)
/// schlägt Kategorie-Pauschale (`PriceEstimator` `switch category`). Diese Tests ändern KEIN
/// Verhalten — sie sichern den heutigen Status quo als Regressionsschutz ab, nachdem eine
/// zusätzlich geplante Veraltungsregel für gelernte Preise nach PO-Einwand (Pauschale ist kein
/// nachweislich besserer Rückfall als ein alter echter Preis) komplett nach Issue #49 verschoben
/// wurde.
final class PriceEstimatorStagesTests: XCTestCase {

    // MARK: - AC-1: Stufe 1 (gelernter Preis) schlägt Stufe 2 (Produkt-Keyword)

    func testLearnedPriceTakesPriorityOverProductKeywordAndCategory() {
        let store = Store(name: "Rewe", emoji: "🛒", colorHex: "#654321")
        // "milch" träfe sowohl das specificPrices-Keyword (1.20€) als auch die
        // Kategorie-Pauschale "Milchprodukte" (2.00€) — der gelernte Preis muss trotzdem gewinnen.
        store.learnedPrices["milch"] = 1.50

        let item = ShoppingItem(name: "Milch", category: "Milchprodukte", store: store)

        XCTAssertEqual(item.estimatedPrice, 1.50, "Der gelernte Preis muss Vorrang vor Produkt-Keyword UND Kategorie-Pauschale haben")
        XCTAssertFalse(item.estimatedPriceIsAutoDerived, "Ein gelernter Preis gilt als 'echt', nicht als Schätzung")
    }

    // MARK: - AC-2: Stufe 2 (Produkt-Keyword) schlägt Stufe 3 (Kategorie-Pauschale)

    func testProductKeywordTakesPriorityOverCategoryFallback() {
        // Kein Store übergeben → Stufe 1 entfällt von vornherein.
        let item = ShoppingItem(name: "Milch", category: "Milchprodukte")

        XCTAssertEqual(item.estimatedPrice, 1.20, "Ohne gelernten Preis muss das Produkt-Keyword ('milch') vor der Kategorie-Pauschale ('Milchprodukte', 2.00€) gewinnen")
        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
    }

    // MARK: - AC-3: Stufe 3 (Kategorie-Pauschale) greift ohne Stufe 1/2

    func testCategoryFallbackUsedWhenNoLearnedPriceAndNoKeywordMatch() {
        // Name ohne Keyword-Treffer (gleiche Konvention wie in
        // PriceEstimatorCategoryFallbackTests), kein Store.
        let item = ShoppingItem(name: "artikel ohne keyword-treffer", category: "Milchprodukte")

        XCTAssertEqual(item.estimatedPrice, 2.00, "Ohne gelernten Preis und ohne Keyword-Treffer muss die Kategorie-Pauschale greifen")
        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
    }
}
