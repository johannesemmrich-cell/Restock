import XCTest
@testable import Restock

/// Beweist den Fix für einen von einem echten DM-Kassenbon gemeldeten Namens-Bug (13.08.2026):
/// "Hakle ToiPa Traumweich 8x130Bl" (Toilettenpapier) wurde von der KI-Namensauflösung (Stufe 5,
/// Apple Intelligence, unzuverlässig für kurze Drogerie-Kürzel) fälschlich zu "Flaschenbürste"
/// "expandiert". Ein deterministischer Wörterbuch-Treffer in Stufe 2 (`expandAbbreviations`)
/// verhindert jetzt, dass diese Zeile überhaupt bei der KI landet.
final class ReceiptAbbreviationExpansionTests: XCTestCase {

    func testToiPaExpandsToToilettenpapier() throws {
        let expanded = try XCTUnwrap(ReceiptParserService.expandAbbreviations("Hakle ToiPa Traumweich 8x130Bl"))
        XCTAssertTrue(expanded.contains("Toilettenpapier"), "Erwartet 'Toilettenpapier' in '\(expanded)'")
        XCTAssertFalse(expanded.contains("Flaschenbürste"), "Darf NICHT zu Flaschenbürste werden (der gemeldete Fehler)")
    }

    func testFlBuersteExpandsToFlaschenbuersteAcrossDotAndSpaceVariants() throws {
        for raw in ["babylove Prem. Fl.buerste 1St", "babylove Prem. Fl buerste 1St", "Fl.bürste"] {
            let expanded = try XCTUnwrap(ReceiptParserService.expandAbbreviations(raw), "Konnte '\(raw)' nicht expandieren")
            XCTAssertTrue(expanded.contains("Flaschenbürste"), "Erwartet 'Flaschenbürste' in '\(expanded)' (Eingabe: '\(raw)')")
        }
    }

    func testPremExpandsToPremium() throws {
        let expanded = try XCTUnwrap(ReceiptParserService.expandAbbreviations("babylove Prem Fl.buerste"))
        XCTAssertTrue(expanded.contains("Premium"), "Erwartet 'Premium' in '\(expanded)'")
    }

    /// Non-Regression: unbekannte Wörter bleiben unangetastet, kein Wörterbuch-Treffer liefert nil.
    func testUnknownWordsReturnNil() {
        XCTAssertNil(ReceiptParserService.expandAbbreviations("Mozzarella Bio 250g"))
    }
}
