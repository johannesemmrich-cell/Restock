import XCTest
@testable import Restock

/// Issue #162: Der Katalog ist eine Datenressource (`data/price-catalog/catalog.json`), aus der
/// `PriceCatalogEntries.swift` erzeugt wird. Diese Tests prüfen die Regeln am kompilierten Ergebnis:
/// Quelle und Stichtag je Eintrag, keine zwei Einträge mit demselben Namen, normalisierte Namen,
/// aufsteigende Spanne — und die Anzeige im Bearbeiten-Sheet (Spanne, Packung, Quelle).
/// Den Gleichlauf JSON ↔ Swift prüft `scripts/test_price_catalog_build.py` bzw.
/// `scripts/build-price-catalog.py --check`.
final class PriceCatalogDataTests: XCTestCase {

    func testEveryEntryCarriesSourceKindAndDate() {
        let allowed: Set<String> = ["hand", "openprices-de"]
        for entry in PriceCatalog.entries {
            XCTAssertTrue(allowed.contains(entry.sourceKind), "\(entry.names.first ?? "?"): Quelle \(entry.source)")
            XCTAssertNotNil(entry.sourceDate.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression),
                            "\(entry.names.first ?? "?"): Stichtag fehlt in \(entry.source)")
        }
        let kinds = Set(PriceCatalog.entries.map(\.sourceKind))
        XCTAssertTrue(kinds.contains("hand"))
    }

    func testNoTwoEntriesShareAName() {
        var seen: [String: String] = [:]
        for entry in PriceCatalog.entries {
            for name in entry.names {
                XCTAssertNil(seen[name], "Name „\(name)“ steht in zwei Einträgen (\(seen[name] ?? "") und \(entry.names.first ?? ""))")
                seen[name] = entry.names.first ?? name
                XCTAssertEqual(name, name.lowercased().trimmingCharacters(in: .whitespaces), "Name nicht normalisiert: \(name)")
                XCTAssertFalse(name.contains("  "), "doppeltes Leerzeichen: \(name)")
            }
            XCTAssertTrue(entry.low <= entry.typical && entry.typical <= entry.high && entry.low > 0,
                          "Spanne nicht aufsteigend: \(entry.names.first ?? "?")")
            XCTAssertTrue(["g", "ml", "stk"].contains(entry.packageUnit), entry.packageUnit)
            XCTAssertGreaterThan(entry.packageAmount, 0)
        }
    }

    func testSourceParsing() {
        let hand = PriceCatalogEntry(names: ["x"], packageAmount: 1, packageUnit: "stk", low: 1, typical: 1, high: 1, source: "hand-2026-10")
        XCTAssertEqual(hand.sourceKind, "hand")
        XCTAssertEqual(hand.sourceDate, "2026-10")
        let op = PriceCatalogEntry(names: ["x"], packageAmount: 1, packageUnit: "stk", low: 1, typical: 1, high: 1, source: "openprices-de-2026-10")
        XCTAssertEqual(op.sourceKind, "openprices-de")
        XCTAssertEqual(op.sourceDate, "2026-10")
        let odd = PriceCatalogEntry(names: ["x"], packageAmount: 1, packageUnit: "stk", low: 1, typical: 1, high: 1, source: "legacy")
        XCTAssertEqual(odd.sourceKind, "legacy")
        XCTAssertEqual(odd.sourceDate, "")
        XCTAssertEqual(PriceCatalogDisplay.displayDate("2026-10"), "10/2026")
        XCTAssertEqual(PriceCatalogDisplay.displayDate("2026"), "2026")
    }

    /// Spanne und Packung im Bearbeiten-Sheet (Issue #162, Punkt 5): „Katalog: 125 g typisch 1,09 €,
    /// Spanne 0,79 € – 1,79 € · handgepflegt 10/2026“.
    func testSummaryShowsPackageRangeAndSource() throws {
        let entry = try XCTUnwrap(PriceCatalog.match("Mozzarella"))
        let text = PriceCatalogDisplay.summary(for: entry, locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(text.contains("125 g"), text)
        XCTAssertTrue(text.contains("1,09"), text)
        XCTAssertTrue(text.contains("0,79"), text)
        XCTAssertTrue(text.contains("1,79"), text)
        XCTAssertTrue(text.contains("10/2026"), text)
        XCTAssertFalse(text.contains("price.catalog"), "Schlüssel statt Text: \(text)")

        let piece = try XCTUnwrap(PriceCatalog.match("Milch"))
        let pieceText = PriceCatalogDisplay.summary(for: piece, locale: Locale(identifier: "de_DE"))
        XCTAssertFalse(pieceText.contains("1 stk"), pieceText)
        XCTAssertTrue(pieceText.contains("1,20"), pieceText)

        XCTAssertNil(PriceCatalogDisplay.summary(forName: "Qwertzuiopü"))
        XCTAssertNotNil(PriceCatalogDisplay.summary(forName: "Tomatenmark 200g"))
    }

    func testSourceTextUsesLocalizedLabels() {
        let op = PriceCatalogEntry(names: ["x"], packageAmount: 1, packageUnit: "stk", low: 1, typical: 1, high: 1, source: "openprices-de-2026-10")
        XCTAssertTrue(PriceCatalogDisplay.sourceText(for: op).contains("Open Prices"))
        let unknown = PriceCatalogEntry(names: ["x"], packageAmount: 1, packageUnit: "stk", low: 1, typical: 1, high: 1, source: "sonst-2026-10")
        XCTAssertEqual(PriceCatalogDisplay.sourceText(for: unknown), "sonst-2026-10")
    }

    func testLocalizationKeysAreRegistered() {
        let keys = Set(PriceSourceDisplay.allLocalizationKeys)
        for key in PriceCatalogDisplay.allLocalizationKeys { XCTAssertTrue(keys.contains(key), key) }
    }
}
