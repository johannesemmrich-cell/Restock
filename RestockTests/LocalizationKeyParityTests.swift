import XCTest
@testable import Restock

/// Issue #99, Punkt 2 (PO-Entscheidung 2026-10-21): Englisch wird ausgeliefert (`en.lproj`), aber kein
/// UI-Test läuft auf Englisch, weil die UI-Tests deutsche Texte prüfen. Statt eines zweiten UI-Laufs
/// sichert dieser Test den häufigsten Fehler ab: ein Schlüssel, der nur in einer der beiden
/// Textdateien steht (vergessene Übersetzung → im anderen Modus erscheint der rohe Schlüssel), und
/// Platzhalter, die nicht zusammenpassen (`%@` gegen `%1$@ %2$@` → Absturz oder falscher Text zur
/// Laufzeit). Gelesen werden die ausgelieferten, kompilierten Tabellen aus dem App-Bundle, nicht die
/// Quelldateien, damit auch ein Build-Fehler der Ressource auffällt.
final class LocalizationKeyParityTests: XCTestCase {
    private static let localizations = ["de", "en"]

    private func table(_ localization: String) throws -> [String: String] {
        let bundle = Bundle.main
        let url = try XCTUnwrap(
            bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization),
            "Localizable.strings für \(localization) fehlt im Bundle \(bundle.bundleIdentifier ?? "?")")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "Tabelle \(localization) nicht lesbar")
        return dict
    }

    /// Platzhalter wie `%@`, `%d`, `%1$@`, `%.1f`, `%lld`; `%%` ist ein literales Prozentzeichen.
    static func placeholders(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[0-9.]*(?:ll|l|h)?[@dfsux]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let cleaned = value.replacingOccurrences(of: "%%", with: "")
        return regex.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
            .map { String(cleaned[Range($0.range, in: cleaned)!]) }
            .sorted()
    }

    func testBothTablesExistAndAreNotEmpty() throws {
        for loc in Self.localizations {
            let t = try table(loc)
            XCTAssertGreaterThan(t.count, 300, "\(loc): unerwartet wenige Schlüssel (\(t.count))")
            let empty = t.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()
            XCTAssertTrue(empty.isEmpty, "\(loc): leere Texte für \(empty)")
        }
    }

    func testGermanAndEnglishHaveTheSameKeys() throws {
        let de = Set(try table("de").keys), en = Set(try table("en").keys)
        XCTAssertEqual(de.subtracting(en).sorted(), [], "nur auf Deutsch vorhanden (englischer Text fehlt)")
        XCTAssertEqual(en.subtracting(de).sorted(), [], "nur auf Englisch vorhanden (deutscher Text fehlt)")
    }

    func testPlaceholdersMatchPerKey() throws {
        let de = try table("de"), en = try table("en")
        var mismatches: [String] = []
        for (key, deValue) in de {
            guard let enValue = en[key] else { continue }
            let a = Self.placeholders(in: deValue), b = Self.placeholders(in: enValue)
            if a != b { mismatches.append("\(key): de \(a) ≠ en \(b)") }
        }
        XCTAssertEqual(mismatches.sorted(), [], "Platzhalter müssen in beiden Sprachen zusammenpassen")
    }

    func testPlaceholderExtraction() {
        XCTAssertEqual(Self.placeholders(in: "Community · %1$@ · %2$@"), ["%1$@", "%2$@"])
        XCTAssertEqual(Self.placeholders(in: "%d von %d erledigt"), ["%d", "%d"])
        XCTAssertEqual(Self.placeholders(in: "100%% Bio, %.1f kg, %lld Stück"), ["%.1f", "%lld"])
        XCTAssertEqual(Self.placeholders(in: "kein Platzhalter"), [])
    }
}
