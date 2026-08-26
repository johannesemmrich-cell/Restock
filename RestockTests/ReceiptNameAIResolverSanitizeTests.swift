import XCTest
@testable import Restock

/// Testet `ReceiptNameAIResolver.sanitize` — die deterministische Nachbearbeitung der
/// KI-Antwort (Stufe 5 der Bon-Namensauflösung). Der eigentliche `LanguageModelSession`-Aufruf
/// selbst ist hier NICHT testbar (Apple Intelligence läuft im Simulator/CI nicht, `isAIAvailable`
/// liefert dort `false`) — das deckt nur die reine Textnachbearbeitung ab, insbesondere den neuen
/// "kein Produkt"-Ausweg (gemeldet 24.08.2026: der Prompt zwang das Modell vorher, für JEDEN
/// Text — auch Tabellen-/Zahlungs-Metadaten-Fragmente — einen Produktnamen zu erfinden, siehe
/// "Pizza Baguette"-Phantom-Positionen).
final class ReceiptNameAIResolverSanitizeTests: XCTestCase {

    private let resolver = ReceiptNameAIResolver.shared

    func testNormalNamePassesThrough() {
        XCTAssertEqual(resolver.sanitize("Sahne"), "Sahne")
    }

    func testWhitespaceAndQuotesAreTrimmed() {
        XCTAssertEqual(resolver.sanitize("  Sahne  "), "Sahne")
        XCTAssertEqual(resolver.sanitize("\"Sahne\""), "Sahne")
    }

    func testEmptyOrTooLongOrMultilineIsRejected() {
        XCTAssertNil(resolver.sanitize(""))
        XCTAssertNil(resolver.sanitize(String(repeating: "a", count: 61)))
        XCTAssertNil(resolver.sanitize("Sahne\nJoghurt"))
    }

    // MARK: - Neuer "kein Produkt"-Ausweg

    func testNonProductSentinelIsRejected() {
        XCTAssertNil(resolver.sanitize(ReceiptNameAIResolver.nonProductSentinel))
    }

    func testNonProductSentinelIsCaseInsensitive() {
        XCTAssertNil(resolver.sanitize(ReceiptNameAIResolver.nonProductSentinel.lowercased()))
    }

    func testNonProductSentinelWithWhitespaceAndQuotesIsRejected() {
        XCTAssertNil(resolver.sanitize("  \(ReceiptNameAIResolver.nonProductSentinel)  "))
        XCTAssertNil(resolver.sanitize("\"\(ReceiptNameAIResolver.nonProductSentinel)\""))
    }

    /// Absicherung: der Vergleich ist ein exakter Gleichheitsvergleich, kein Substring-Check —
    /// ein (hypothetischer) echter Produktname, der den Marker nur enthält, darf nicht
    /// fälschlich verworfen werden.
    func testSentinelAsSubstringOfLongerTextIsNotRejected() {
        XCTAssertEqual(resolver.sanitize("\(ReceiptNameAIResolver.nonProductSentinel) Zusatz"), "\(ReceiptNameAIResolver.nonProductSentinel) Zusatz")
    }
}
