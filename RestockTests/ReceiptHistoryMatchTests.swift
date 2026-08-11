import XCTest
@testable import Restock

/// Beweist den Fix für Stufe 4 der Kassenbon-Namensauflösung (`ReceiptParserService.historyMatch`):
/// vorher reines `contains`, erster Treffer gewinnt — jetzt dieselbe Fuzzy-Bewertung (`lcsSimilarity`)
/// wie Stufe 3, bester Treffer gewinnt. Verhindert, dass ein eigener, tatsächlich verwendeter
/// Artikelname (z. B. "Burger Brötchen") an einem schwächeren Zufallstreffer vorbeigeht und bis zur
/// generischen KI-Stufe durchfällt.
final class ReceiptHistoryMatchTests: XCTestCase {
    private func record(_ name: String, store: String) -> PurchaseRecord {
        PurchaseRecord(itemName: name, storeName: store)
    }

    func testFuzzyMatchFoundWhereContainsWouldFail() {
        // "Mzzrll" ist keine Teilzeichenkette von "Mozzarella" und umgekehrt — das alte
        // `contains`-basierte historyMatch hätte hier nichts gefunden.
        let records = [record("Mozzarella", store: "Lidl")]
        let result = ReceiptParserService.historyMatch(for: "Mzzrll", in: records, storeName: "Lidl")
        XCTAssertEqual(result, "Mozzarella")
    }

    func testBestMatchWinsNotFirstInArray() {
        let records = [
            record("Bananenchips", store: "Lidl"),
            record("Burger Brötchen", store: "Lidl")
        ]
        // "Burgr Brotchen" ist dem zweiten Eintrag deutlich ähnlicher als dem ersten, obwohl der
        // erste Eintrag im Array vorne steht.
        let result = ReceiptParserService.historyMatch(for: "Burgr Brotchen", in: records, storeName: "Lidl")
        XCTAssertEqual(result, "Burger Brötchen")
    }

    func testBelowThresholdReturnsNil() {
        let records = [record("Kartoffeln", store: "Lidl")]
        let result = ReceiptParserService.historyMatch(for: "Xyz123", in: records, storeName: "Lidl")
        XCTAssertNil(result)
    }

    func testStoreScopeStillEnforced() {
        // Starker Treffer, aber an einem ANDEREN Store — darf nicht zurückgegeben werden.
        let records = [record("Burger Brötchen", store: "Aldi")]
        let result = ReceiptParserService.historyMatch(for: "Burger Brötchen", in: records, storeName: "Lidl")
        XCTAssertNil(result)
    }
}
