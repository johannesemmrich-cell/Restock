import XCTest

/// TDD RED (Issue #11, `docs/specs/models/legacy-price-reset-migration.md`) — AC12/AC13.
/// Durchlauf: App startet mit Altstand (Seed), die Migration läuft im normalen App-Start, danach
/// zeigt die Liste den Altwert „1,56“ nicht mehr. Lookups über Anzeigetexte (Scheme-Sprache de).
final class LegacyLearnedPriceResetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den Test (Projekt-CLAUDE.md) — Seed samt Flag wegräumen.
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearLegacyLearnedPriceSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
    }

    func testLegacyPricesAreResetAfterLaunchButManualPriceStays() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedLegacyLearnedPriceForUITests"]
        app.launch()

        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Altbon,")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Altbon-Kachel nicht auf dem Home-Screen gefunden")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: tile)
        waitForExpectations(timeout: 5)
        tile.tap()

        let control = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2,50")).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Der manuell bepreiste Kontrollartikel muss weiter 2,50 zeigen (AC12)")

        let legacyTexts = app.staticTexts.allElementsBoundByIndex.map { normalized($0.label) }
        XCTAssertFalse(legacyTexts.contains { $0.contains("1,56") },
                       "Kein Altlast-Artikel darf nach dem App-Start noch 1,56 zeigen (AC12)")
    }

    // MARK: - Issue #151: Preisquelle (AC-17, AC-18)

    /// Startet mit dem Altbon-Seed über den Start-Helfer (Gegenprobe auf die Kachel) und öffnet den
    /// Laden. `developerMode` nil = Argument weglassen (AC-17), sonst `-developerMode YES/NO` (AC-18).
    private func launchAltbon(developerMode: Bool? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedLegacyLearnedPriceForUITests"]
        if let developerMode { app.launchArguments += ["-developerMode", developerMode ? "YES" : "NO"] }
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Altbon,")).firstMatch
        UITestLaunch.start(app, expecting: tile, description: "Kachel „Altbon“")
        tile.tap()
        return app
    }

    /// Zeile der geöffneten Ladenliste (`List` → Cell), wie in `ReplenishmentUITests.listRow`.
    private func listRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    /// Alle Texte einer Artikelzeile, normalisiert. Wartet, bis `expected` in einem davon steht, und
    /// liefert den zuletzt gelesenen Stand — unabhängig davon, ob Betrag und Quelle einzeln oder als
    /// Zusammenfassung „<Betrag>, <Quelle>“ im Baum stehen.
    private func rowTexts(_ name: String, waitingFor expected: String, in app: XCUIApplication) -> [String] {
        let row = listRow(name, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „\(name)“ nicht gefunden")
        let result = UITestWait.poll(
            timeout: UITestWait.defaultTimeout,
            read: { row.exists ? row.staticTexts.allElementsBoundByIndex.map { self.normalized($0.label) } : [] },
            done: { texts in texts.contains { $0.contains(expected) } })
        XCTAssertTrue(result.matched, "„\(expected)“ fehlt in der Zeile „\(name)“, zuletzt: \(result.last)")
        return result.last
    }

    /// AC-17: Schätzung, eigener Preis und Altdaten-Preis sind in der Zeile unterscheidbar (vorher
    /// zeigten „Laugenbrötchen groß“ und „Kontrollbrot“ beide nur „2,50 €“).
    ///
    /// Seed-Vorgaben für `SmartCartApp.seedLegacyLearnedPriceForUITestsIfNeeded` (Umsetzung #151):
    /// - „Kontrollbrot“: wie bisher Preis 2,50, Bool `false`, offen, dazu `priceSource = "manual"`.
    /// - NEU vierter Artikel „Altdatenbrot“: `ShoppingItem(name: "Altdatenbrot", quantityAmount: 1,
    ///   store: store)` (Einheit "" = Stück, `quantitySource` "user"), danach von Hand
    ///   `estimatedPrice = 3.20`, `estimatedPriceIsAutoDerived = false`, `priceSource = ""` (Altdaten,
    ///   Anzeige über die Ableitung „gelernt“), offen. Dazu im Laden `learnedPrices["altdatenbrot"] = 3.20`
    ///   und `learnedPriceUnits["altdatenbrot"] = "stk"`: Damit lässt `PriceProvenanceMigration` (läuft
    ///   auf einem frischen Simulator beim ersten Start nach dem Seed, Phase A) das Bool auf `false`, und
    ///   `LegacyLearnedPriceReset` fasst ihn wegen der Bezugsgröße nicht an. 3,20 ≠ Katalogschätzung
    ///   „brot“ 2,50, also nicht mit einer Schätzung verwechselbar.
    /// - „Laugenbrötchen groß“ bleibt unverändert (Altwert 1,56, Bool `false`); die Migration setzt ihn
    ///   auf die Schätzung „brötchen“ 2,50 und `priceSource = "estimate"`.
    func testPriceSourceDistinguishesEstimateManualAndLearned() throws {
        let app = launchAltbon()

        let estimate = rowTexts("Laugenbrötchen groß", waitingFor: "Schätzung", in: app)
        XCTAssertTrue(estimate.contains { $0.hasPrefix("ca. ") && $0.contains("2,50") },
                      "Schätzung muss als „ca. 2,50 €“ erscheinen, gelesen: \(estimate)")

        let manual = rowTexts("Kontrollbrot", waitingFor: "eigener Preis", in: app)
        XCTAssertTrue(manual.contains { $0.contains("2,50") }, "eigener Preis 2,50 fehlt, gelesen: \(manual)")
        XCTAssertFalse(manual.contains { $0.hasPrefix("ca. ") }, "eigener Preis ohne „ca.“, gelesen: \(manual)")
        XCTAssertFalse(manual.contains { $0.contains("Schätzung") }, "eigener Preis ist keine Schätzung: \(manual)")

        let learned = rowTexts("Altdatenbrot", waitingFor: "gelernt", in: app)
        XCTAssertTrue(learned.contains { $0.contains("3,20") }, "Altdaten-Preis 3,20 fehlt, gelesen: \(learned)")
        XCTAssertFalse(learned.contains { $0.hasPrefix("ca. ") }, "Altdaten-Preis ohne „ca.“, gelesen: \(learned)")
        XCTAssertFalse(learned.contains { $0.contains("Schätzung") || $0.contains("eigener Preis") || $0.contains("Bon") },
                       "Altdaten werden nie Bon/eigener Preis/Schätzung: \(learned)")

    }

    /// Öffnet den Bearbeiten-Dialog von „Laugenbrötchen groß“ (Tipp auf die Zeile, wie
    /// `AddItemQuantitySuggestionUITests`) und wartet auf „Speichern“ als Beleg, dass er offen ist.
    private func openEditor(_ name: String, in app: XCUIApplication) {
        let row = listRow(name, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: UITestWait.defaultTimeout), "Zeile „\(name)“ nicht gefunden")
        let ready = row.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „\(name)“ nicht antippbar — zuletzt: \(ready.last)")
        app.staticTexts[name].firstMatch.tap()
        XCTAssertTrue(app.buttons["Speichern"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Bearbeiten-Dialog für „\(name)“ nicht geöffnet")
    }

    /// Sucht den Abschnitt „Preisdiagnose“ im Formular (Groß-/Kleinschreibung egal, Abschnittstitel
    /// können in Versalien erscheinen) und scrollt dafür bis zu sechsmal nach unten (Formular lädt träge).
    private func findDiagnosisHeader(in app: XCUIApplication) -> Bool {
        let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Preisdiagnose")).firstMatch
        for _ in 0..<6 {
            if header.exists { return true }
            app.swipeUp()
        }
        return header.waitForExistence(timeout: 2)
    }

    /// AC-18: Die Preisdiagnose erscheint im Bearbeiten-Dialog nur im Entwicklermodus.
    func testPriceDiagnosisOnlyInDeveloperMode() throws {
        let devApp = launchAltbon(developerMode: true)
        openEditor("Laugenbrötchen groß", in: devApp)
        XCTAssertTrue(findDiagnosisHeader(in: devApp), "Abschnitt „Preisdiagnose“ fehlt im Entwicklermodus")
        // Die Diagnose nennt den gefundenen Schlüssel (kleingeschrieben, anders als der Artikelname).
        let key = devApp.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "laugenbrötchen")).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Diagnose nennt den Schlüssel „laugenbrötchen“ nicht")
        devApp.terminate()

        let userApp = launchAltbon(developerMode: false)
        openEditor("Laugenbrötchen groß", in: userApp)
        XCTAssertFalse(findDiagnosisHeader(in: userApp), "„Preisdiagnose“ darf ohne Entwicklermodus nicht erscheinen")
    }
}
