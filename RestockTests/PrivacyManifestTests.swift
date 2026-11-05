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
        ("NSPrivacyCollectedDataTypeCoarseLocation", true),
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

    // AC-3, AC-4 (Issue #175, Standort): Die Filiale der Open-Prices-Beiträge lässt den Aufenthaltsort erkennen.
    func testOpenPricesParagraphNamesApproximateLocation() throws {
        let source = try legalSource()
        let openPrices = try XCTUnwrap(source.components(separatedBy: "**Open Prices").dropFirst().first?
            .components(separatedBy: "\n\n").first, "Abschnitt „Open Prices“ fehlt")
        XCTAssertTrue(openPrices.contains("ungefähren Aufenthaltsort"), "Standort-Satz fehlt (de)")
        XCTAssertTrue(source.contains("ohne Filiale oder Standort"), "Community-Preise bleiben ohne Standort")
        XCTAssertTrue(source.contains("**Datenschutzerklärung**\nStand: Oktober 2026"))
        let page = try String(contentsOf: repoFile("docs/appstore/datenschutz.md"), encoding: .utf8)
        let english = try XCTUnwrap(page.components(separatedBy: "## English").dropFirst().first)
        XCTAssertTrue(english.contains("approximate whereabouts"), "Standort-Satz fehlt (en)")
    }

    // MARK: - Durchgang A2

    private func repoFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    private func infoPlistStrings(_ language: String) throws -> [String: String] {
        let url = repoFile("SmartCart/Resources/\(language).lproj/InfoPlist.strings")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String],
                                 "\(language).lproj/InfoPlist.strings fehlt oder ist nicht lesbar")
        return dict
    }

    // AC-6
    func testInfoPlistStringsExistInGermanAndEnglish() throws {
        let keys = ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]
        let de = try infoPlistStrings("de")
        let en = try infoPlistStrings("en")
        XCTAssertEqual(Set(de.keys), Set(en.keys), "Schlüssel von de und en weichen ab")
        for key in keys {
            XCTAssertFalse((de[key] ?? "").isEmpty, "de: \(key) fehlt oder leer")
            XCTAssertFalse((en[key] ?? "").isEmpty, "en: \(key) fehlt oder leer")
        }
    }

    // AC-6
    func testCameraTextNamesReceiptsBarcodesAndRecipes() throws {
        let de = try infoPlistStrings("de")
        let en = try infoPlistStrings("en")
        let deCamera = de["NSCameraUsageDescription"] ?? ""
        for term in ["Bon", "Barcode", "Rezept"] {
            XCTAssertTrue(deCamera.contains(term), "de Kameratext nennt „\(term)“ nicht")
        }
        let enCamera = (en["NSCameraUsageDescription"] ?? "").lowercased()
        for term in ["receipt", "barcode", "recipe"] {
            XCTAssertTrue(enCamera.contains(term), "en Kameratext nennt „\(term)“ nicht")
        }
        let dePhotos = de["NSPhotoLibraryUsageDescription"] ?? ""
        for term in ["Bon", "Rezept"] {
            XCTAssertTrue(dePhotos.contains(term), "de Fototext nennt „\(term)“ nicht")
        }
        let enPhotos = (en["NSPhotoLibraryUsageDescription"] ?? "").lowercased()
        for term in ["receipt", "recipe"] {
            XCTAssertTrue(enPhotos.contains(term), "en Fototext nennt „\(term)“ nicht")
        }
    }

    // AC-7 (seit Build 38: eine gemeinsame Nummer ≥ 37 statt fest 37, sonst bricht jeder Upload den Test)
    func testBuildNumberIsConsistentAndAtLeast37InBothProjectFiles() throws {
        let yml = try String(contentsOf: repoFile("project.yml"), encoding: .utf8)
        let pbx = try String(contentsOf: repoFile("Restock.xcodeproj/project.pbxproj"), encoding: .utf8)
        let ymlValues = yml.components(separatedBy: "\n")
            .filter { $0.contains("CURRENT_PROJECT_VERSION:") }
            .map { $0.components(separatedBy: ":").last!.trimmingCharacters(in: .whitespaces) }
        let pbxValues = pbx.components(separatedBy: "\n")
            .filter { $0.contains("CURRENT_PROJECT_VERSION =") }
            .map { $0.components(separatedBy: "=").last!.trimmingCharacters(in: CharacterSet(charactersIn: "; \t")) }
        XCTAssertFalse(ymlValues.isEmpty)
        XCTAssertFalse(pbxValues.isEmpty)
        let values = Set(ymlValues + pbxValues)
        XCTAssertEqual(values.count, 1, "project.yml: \(ymlValues), project.pbxproj: \(pbxValues)")
        XCTAssertGreaterThanOrEqual(Int(values.first ?? "") ?? 0, 37, "Build-Nummer: \(values)")
        // Strings-Dateien müssen im App-Ziel registriert sein (Ressourcen-Phase).
        XCTAssertTrue(pbx.contains("InfoPlist.strings in Resources"), "InfoPlist.strings nicht in den Ressourcen")
    }

    // MARK: - Issues #214/#181: Rechtstexte mit Absätzen, kein Swift-Escape in .strings

    private func legalTexts() -> [(LegalDocument, String)] {
        LegalDocument.allCases.map { ($0, LegalView.text(for: $0)) }
    }

    private func blockTexts(_ blocks: [LegalTextBlocks.Block]) -> [String] {
        blocks.compactMap {
            switch $0 {
            case .paragraph(let t), .bullet(let t): return t
            case .divider: return nil
            }
        }
    }

    // AC-1
    func testParagraphsSplitOnBlankLines() {
        XCTAssertEqual(LegalTextBlocks.blocks(from: "A\n\nB"), [.paragraph("A"), .paragraph("B")])
        XCTAssertEqual(LegalTextBlocks.blocks(from: "\n\nA\n \n\t\n\nB\n\n"), [.paragraph("A"), .paragraph("B")])
        XCTAssertEqual(LegalTextBlocks.blocks(from: "A\r\nB\r\n\r\nC\r\rD"), [.paragraph("A\nB"), .paragraph("C"), .paragraph("D")])  // CRLF/CR
    }

    // AC-2
    func testLineBreakInsideParagraphIsKept() {
        XCTAssertEqual(LegalTextBlocks.blocks(from: "Johannes Emmrich\nEichenaue 14\nE-Mail: x"),
                       [.paragraph("Johannes Emmrich\nEichenaue 14\nE-Mail: x")])
    }

    // AC-3
    func testDividerBecomesDividerBlock() {
        XCTAssertEqual(LegalTextBlocks.blocks(from: "A\n\n---\n\nB"), [.paragraph("A"), .divider, .paragraph("B")])
    }

    // AC-4
    func testBulletLinesBecomeBullets() {
        XCTAssertEqual(LegalTextBlocks.blocks(from: "- **X** a\n- Y b"), [.bullet("**X** a"), .bullet("Y b")])
        XCTAssertEqual(LegalTextBlocks.blocks(from: "Einleitung:\n- A\n- B"),
                       [.paragraph("Einleitung:"), .bullet("A"), .bullet("B")])
        XCTAssertEqual(LegalTextBlocks.blocks(from: "-5 %"), [.paragraph("-5 %")])
        XCTAssertEqual(LegalTextBlocks.blocks(from: "- A\n- \n-   \n- B"), [.bullet("A"), .bullet("B")])  // leere Punkte entfallen
    }

    // AC-5
    func testAllThreeDocumentsHaveNoRawMarkdownLeft() {
        var bullets = 0
        for (document, text) in legalTexts() {
            let blocks = LegalTextBlocks.blocks(from: text)
            let dividers = blocks.filter { $0 == .divider }.count
            let sourceDividers = text.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces) == "---" }.count
            XCTAssertEqual(dividers, sourceDividers, "\(document): Trennlinien")
            XCTAssertGreaterThan(dividers, 0, "\(document): keine Trennlinie")
            for block in blocks {
                switch block {
                case .paragraph(let t):
                    XCTAssertFalse(t.isEmpty, "\(document): leerer Absatz")
                    XCTAssertFalse(t.contains("---"), "\(document): --- im Absatz")
                    for line in t.components(separatedBy: "\n") {
                        XCTAssertFalse(line.hasPrefix("- "), "\(document): Listenzeile im Absatz: \(line)")
                    }
                case .bullet(let t):
                    XCTAssertFalse(t.isEmpty, "\(document): leerer Punkt")
                    XCTAssertFalse(t.contains("---"), "\(document): --- im Punkt")
                    if document != .imprint { bullets += 1 }
                case .divider: break
                }
            }
        }
        XCTAssertEqual(bullets, 18, "Aufzählungspunkte in Datenschutz und Nutzungsbedingungen")
    }

    // AC-6
    func testBlocksLoseNoCharacter() {
        for (document, text) in legalTexts() {
            let expected = text.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces) != "---" }
                .map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }
                .joined()
                .filter { !$0.isWhitespace }
            let actual = blockTexts(LegalTextBlocks.blocks(from: text)).joined().filter { !$0.isWhitespace }
            XCTAssertEqual(actual, expected, "\(document): Anzeigetext weicht vom Quelltext ab")
        }
    }

    // AC-7
    func testBoldSurvivesInlineParsing() {
        let result = LegalTextBlocks.attributed("**Datenschutzerklärung**\nStand: Oktober 2026")
        XCTAssertEqual(String(result.characters), "Datenschutzerklärung\nStand: Oktober 2026")
        var boldText = "", plainText = ""
        for run in result.runs {
            let text = String(result[run.range].characters)
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { boldText += text } else { plainText += text }
        }
        XCTAssertEqual(boldText, "Datenschutzerklärung")
        XCTAssertEqual(plainText, "\nStand: Oktober 2026")
    }

    // AC-9
    private func swiftEscapeHits(in text: String) -> Bool { text.contains("\\u{") }

    func testStringsFilesContainNoSwiftEscapes() throws {
        XCTAssertTrue(swiftEscapeHits(in: "\"k\" = \"a \\u{2192} b\";"), "Gegenprobe: Prüffunktion findet nichts")
        let root = repoFile("")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "strings" }
            .filter { !$0.path.contains("/.git/") && !$0.path.contains("/build/") }
        XCTAssertGreaterThanOrEqual(files.count, 4)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(swiftEscapeHits(in: text), "\(file.lastPathComponent) (\(file.deletingLastPathComponent().lastPathComponent)) enthält \\u{ ")
        }
    }

    // AC-10
    func testNoSavedRecipesHintContainsArrow() throws {
        for language in ["de", "en"] {
            let url = repoFile("SmartCart/Resources/\(language).lproj/Localizable.strings")
            let plist = try XCTUnwrap(PropertyListSerialization.propertyList(
                from: Data(contentsOf: url), format: nil) as? [String: String], "\(language) nicht lesbar")
            let value = try XCTUnwrap(plist["menuplan.noSavedRecipes"])
            XCTAssertTrue(value.contains("\u{2192}"), "\(language): Pfeil fehlt: \(value)")
            XCTAssertFalse(value.contains("u{2192}"), "\(language): kaputter Pfeil: \(value)")
            if language == "de" {
                XCTAssertEqual(value, "Noch keine Rezepte gespeichert. Gericht im Wochenplan nach rechts wischen \u{2192} \"Speichern\".")
            }
        }
    }
}
