import XCTest
@testable import Restock

/// Issue #215: Die Paywall verlinkt Datenschutz und Nutzungsbedingungen (EULA) und nennt die Abo-Angaben.
/// Spec: `docs/specs/views/paywall-rechtslinks.md` (AC-3, AC-4, AC-5). Die URL-Konstanten müssen mit den
/// Store-Texten in `docs/appstore/{de,en}.md` übereinstimmen.
final class PaywallLegalLinksTests: XCTestCase {

    private func storeText(_ language: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("docs/appstore/\(language).md"), encoding: .utf8)
    }

    /// Text zwischen `## <heading>` und der nächsten `## `-Überschrift, leer wenn es sie nicht gibt.
    private func section(_ heading: String, in markdown: String) -> String {
        var lines: [Substring] = []
        var inside = false
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                if inside { break }
                inside = line == "## \(heading)"
                continue
            }
            if inside { lines.append(line) }
        }
        return lines.joined(separator: "\n")
    }

    private func containsURL(_ text: String, _ url: URL) -> Bool {
        text.contains(url.absoluteString)
    }

    private func line(startingWith marker: String, in markdown: String) -> String {
        markdown.split(separator: "\n").first { $0.hasPrefix(marker) }.map(String.init) ?? ""
    }

    // AC-3, AC-5
    func testPrivacyURLMatchesStoreTexts() throws {
        for language in ["de", "en"] {
            let text = try storeText(language)
            XCTAssertTrue(containsURL(section("privacy_url", in: text), PaywallLegalLinks.privacyURL),
                          "\(language).md: privacy_url weicht von PaywallLegalLinks.privacyURL ab")
        }
        // Gegenproben: fremde URL; URL nur unter `## description` zählt nicht.
        let foreign = try XCTUnwrap(URL(string: "https://example.com/fremd"))
        XCTAssertFalse(containsURL(section("privacy_url", in: try storeText("de")), foreign))
        let onlyInDescription = "## description\n\n\(PaywallLegalLinks.privacyURL.absoluteString)\n\n## privacy_url\n\nnichts\n"
        XCTAssertFalse(containsURL(section("privacy_url", in: onlyInDescription), PaywallLegalLinks.privacyURL))
    }

    // AC-3, AC-5
    func testEULAURLMatchesStoreTexts() throws {
        let markers = ["de": "Nutzungsbedingungen (Apples Standard-Lizenzvereinbarung)",
                       "en": "Terms of Use (Apple's standard license agreement)"]
        for (language, marker) in markers {
            let eulaLine = line(startingWith: marker, in: try storeText(language))
            XCTAssertFalse(eulaLine.isEmpty, "\(language).md: Zeile „\(marker)“ fehlt")
            XCTAssertTrue(containsURL(eulaLine, PaywallLegalLinks.termsURL),
                          "\(language).md: EULA-URL weicht von PaywallLegalLinks.termsURL ab")
        }
        let foreign = try XCTUnwrap(URL(string: "https://example.com/fremd"))
        XCTAssertFalse(containsURL(line(startingWith: markers["de"]!, in: try storeText("de")), foreign))
    }

    // AC-4
    func testSubscriptionNoticeMentionsRequiredParts() {
        let text = PaywallLegalLinks.subscriptionNotice(yearlyPrice: "19,99 €", monthlyPrice: "2,49 €")
        for part in ["Restock Pro – Jährlich", "1 Jahr", "19,99 €", "Restock Pro – Monatlich", "1 Monat", "2,49 €",
                     "24 Stunden", "Apple-ID", "kein Abo"] {
            XCTAssertTrue(text.contains(part), "Abo-Text enthält „\(part)“ nicht: \(text)")
        }
    }
}
