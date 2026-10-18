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

    // MARK: - Issue #69 — Leerraum innerhalb der Anführungszeichen

    /// F103: Antwortet das Modell mit einem leeren Zitat, darf kein Name aus reinem Leerraum
    /// entstehen — `nil` lässt den Roh-Bontext stehen.
    func testQuotedWhitespaceIsRejected() {
        XCTAssertNil(resolver.sanitize("\" \""))
        XCTAssertNil(resolver.sanitize("\"\""))
        XCTAssertNil(resolver.sanitize("' '"))
        XCTAssertNil(resolver.sanitize(" \"\n\" "))
    }

    func testWhitespaceInsideQuotesIsTrimmed() {
        XCTAssertEqual(resolver.sanitize("\" Sahne \""), "Sahne")
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

    // MARK: - "Bröt." auf allen Zeilen (gemeldet 18.10.2026)

    func testAbbreviationAnswerIsRejected() {
        XCTAssertNil(resolver.sanitize("Bröt."))
        XCTAssertNil(resolver.sanitize("\"Schokol.\""))
    }

    func testDotInsideNameOrAfterNumberIsKept() {
        XCTAssertEqual(resolver.sanitize("Dr. Oetker Pizza"), "Dr. Oetker Pizza")
        XCTAssertEqual(resolver.sanitize("Milch 3.5"), "Milch 3.5")
    }

    /// Der gemeldete dm-Bon: dieselbe Antwort für vier fremde Zeilen wird überall verworfen.
    func testSameUnrelatedAnswerForManyLinesIsDiscarded() {
        let raw = [0: "Ricola Bonbon Salbei", 1: "Mentos Gum 3 Fruity Fresh",
                   2: "Soft&Sicher Pocket 6x8St", 3: "Elmex Zahncr. Sens. Prof. 75ml"]
        let answers = [0: "Bröt.", 1: "Bröt.", 2: "bröt.", 3: "Bröt."]
        XCTAssertTrue(ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers(answers, rawNames: raw).isEmpty)
    }

    /// Gleiche Antwort mit Textbezug bleibt stehen, nur die Zeile ohne Bezug fällt zurück.
    func testRepeatedAnswerIsKeptWhereRawTextSharesAWord() {
        let raw = [0: "dmBio Noisette Schokol", 1: "Schoko Lolli Vollmilch",
                   2: "dmBio Schokolierte Brezeln ZB", 3: "Balea Fuß-Maske Socken"]
        let answers = [0: "Schokolade", 1: "Schokolade", 2: "Schokolade", 3: "Schokolade"]
        let result = ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers(answers, rawNames: raw)
        XCTAssertEqual(result, [0: "Schokolade", 1: "Schokolade", 2: "Schokolade"])
    }

    /// Unterhalb der Schwelle (zwei Zeilen) bleibt alles unverändert, auch ohne Textbezug.
    func testAnswerRepeatedForTwoLinesIsUntouched() {
        let raw = [0: "Balea Tuchmaske Ultra Sensitiv", 1: "SEINZ. Tuchmaske Hydro Effect", 2: "Elmex Zahncr."]
        let answers = [0: "Gesichtsmaske", 1: "Gesichtsmaske", 2: "Zahnpasta"]
        XCTAssertEqual(ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers(answers, rawNames: raw), answers)
    }

    /// Dieselbe Bonzeile mehrfach (gleicher Rohtext) zählt als eine — kein Verwerfen.
    func testIdenticalRawLinesCountOnce() {
        let raw = [0: "Rote Bete", 1: "Rote Bete", 2: "Rote Bete"]
        let answers = [0: "Gemüse", 1: "Gemüse", 2: "Gemüse"]
        XCTAssertEqual(ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers(answers, rawNames: raw), answers)
    }
}
