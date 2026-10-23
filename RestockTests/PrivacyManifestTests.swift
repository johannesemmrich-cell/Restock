import XCTest
@testable import Restock

/// Issue #175 (Durchgang A1): Das Datenschutz-Manifest muss sagen, was die App wirklich erhebt, und
/// die Datenschutzerklärung in der App muss dazu passen. Gelesen wird das ausgelieferte Manifest aus
/// dem App-Bundle (nicht die Quelle), damit auch ein Build-Fehler der Ressource auffällt.
final class PrivacyManifestTests: XCTestCase {
    /// Die dokumentierte Liste aus `docs/specs/appstore/app-store-auftritt.md` (Tabelle „Deklarierte Datentypen“).
    private static let documented: [(type: String, linked: Bool)] = [
        ("NSPrivacyCollectedDataTypeName", true),
        ("NSPrivacyCollectedDataTypeOtherUserContent", true),
        ("NSPrivacyCollectedDataTypePhotosorVideos", true),
        ("NSPrivacyCollectedDataTypePurchaseHistory", true),
        ("NSPrivacyCollectedDataTypeUserID", true),
        ("NSPrivacyCollectedDataTypeDeviceID", false),
    ]

    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy fehlt im Bundle \(Bundle.main.bundleIdentifier ?? "?")")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            "Manifest nicht lesbar")
    }

    private func legalSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("SmartCart/Views/Settings/LegalView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // AC-1
    func testCollectedDataTypesEqualDocumentedList() throws {
        let entries = try XCTUnwrap(manifest()["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        XCTAssertEqual(entries.count, Self.documented.count, "Anzahl der deklarierten Datentypen")
        for expected in Self.documented {
            let entry = entries.first { $0["NSPrivacyCollectedDataType"] as? String == expected.type }
            XCTAssertNotNil(entry, "\(expected.type) fehlt im Manifest")
            XCTAssertEqual(entry?["NSPrivacyCollectedDataTypeLinked"] as? Bool, expected.linked,
                           "\(expected.type): Verknüpfung")
            XCTAssertEqual(entry?["NSPrivacyCollectedDataTypeTracking"] as? Bool, false,
                           "\(expected.type): Tracking")
            XCTAssertEqual(entry?["NSPrivacyCollectedDataTypePurposes"] as? [String],
                           ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
                           "\(expected.type): Zweck")
        }
    }

    // AC-2
    func testTrackingFalseAndUserDefaultsReasonKept() throws {
        let m = try manifest()
        XCTAssertEqual(m["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((m["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        let apis = try XCTUnwrap(m["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["1C8F.1"])
    }

    // AC-2
    func testNoBarcodeDataTypeDeclared() throws {
        let entries = try XCTUnwrap(manifest()["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = entries.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypeProductInteraction"),
                       "Die EAN an Open Food Facts ist keine Nutzerangabe und wird nicht deklariert")
        XCTAssertEqual(Set(types), Set(Self.documented.map(\.type)))
    }

    // AC-3
    func testManifestIsPartOfBundle() throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let source = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let bundled = try PropertyListSerialization.propertyList(from: Data(contentsOf: source), format: nil) as? NSDictionary
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let original = try Data(contentsOf: root.appendingPathComponent("SmartCart/PrivacyInfo.xcprivacy"))
        let fromSource = try PropertyListSerialization.propertyList(from: original, format: nil) as? NSDictionary
        XCTAssertEqual(bundled, fromSource, "Das Manifest im Bundle weicht von der Quelle ab")
    }

    // AC-4
    func testLegalTextMentionsPhotosAndNoLongerAddOn() throws {
        let source = try legalSource()
        XCTAssertFalse(source.contains("Geteilte Listen Add-on"), "Das Add-on entfällt (PO 2026-10-23)")
        XCTAssertFalse(source.contains("Premium / Add-on"))
        XCTAssertTrue(source.contains("**Datenschutzerklärung**\nStand: Oktober 2026"), "Stand der Datenschutzerklärung")
        XCTAssertTrue(source.contains("**Nutzungsbedingungen**\nStand: Oktober 2026"), "Stand der Nutzungsbedingungen")
        XCTAssertTrue(source.contains("**Fotos geteilter Artikel**"),
                      "Abschnitt „Fotos geteilter Artikel“ fehlt in der Datenschutzerklärung")
        // Open-Prices-Beitrag: Bonfoto, Filiale, Preise und Benutzername gehen an einen Dritten.
        let openPrices = try XCTUnwrap(source.components(separatedBy: "**Open Prices").dropFirst().first?
            .components(separatedBy: "\n\n").first, "Abschnitt „Open Prices“ fehlt")
        for term in ["Bonfoto", "Filiale", "Preis", "Nutzername"] {
            XCTAssertTrue(openPrices.contains(term), "Open Prices nennt „\(term)“ nicht")
        }
        // Pro enthält in 1.0 nur Rezeptplan und Ausgaben-Analyse (HomeView: PaywallRequest).
        XCTAssertFalse(source.contains("Geteilte Listen (Premium)"), "Teilen ist kostenlos")
        XCTAssertFalse(source.contains("Kassenbon-Scan und Preiserfassung (Premium)"), "Bon-Scan ist kostenlos")
        XCTAssertTrue(source.contains("Ausgaben-Analyse (Premium)"))
        XCTAssertTrue(source.contains("- Menüplanung (Premium)"), "Rezeptplan gehört zu Pro")
    }
}
