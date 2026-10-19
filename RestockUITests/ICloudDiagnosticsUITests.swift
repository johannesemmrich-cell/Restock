import XCTest

/// Issue #156 — Dev-Zeilen „iCloud-Abgleich“ und „Doppelte Läden“ in den Einstellungen samt Detailansichten.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md` (T20–T22; AC-6, AC-7, AC-11).
///
/// Seeds (DEBUG, `SmartCartApp.init()`): `-seedCloudMirrorStatusForUITests` schreibt einen fehlgeschlagenen
/// Export mit Ursache `CD_ShoppingItem` und einen erfolgreichen Import, `-seedDuplicateStoresForUITests` legt
/// „Lidl“ und „Lidl“ (DE, Preset) mit fester UUID an. `tearDown()` räumt beides mit den passenden
/// Aufräum-Argumenten ab (der App-Group-Container überlebt den Test, CLAUDE.md).
/// Argument-Domain-Falle: `-developerMode` wird nur als Startargument gelesen, nie geschrieben.
///
/// Offene Grenze: Der Live-Weg eines echten Export-Ereignisses ist nicht geprüft (gesäter Status).
final class ICloudDiagnosticsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES",
                                   "-clearCloudMirrorStatusForUITests", "-clearDuplicateStoresForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func launchedApp(developerMode: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-developerMode", developerMode ? "YES" : "NO",
                                "-seedCloudMirrorStatusForUITests", "-seedDuplicateStoresForUITests",
                                "-hasCompletedOnboarding", "YES"]
        UITestLaunch.start(app, expecting: tile("Lidl", in: app), description: "Kachel „Lidl“ (Seed)")
        return app
    }

    private func tile(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    private func lidlTileCount(_ app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).count
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    private func openSettings(_ app: XCUIApplication) {
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        XCTAssertTrue(app.buttons["Fertig"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Einstellungen öffnen sich nicht")
    }

    /// Zeile der Dev-Sektion; ihr Label beginnt mit dem Titel, danach folgt der Untertitel.
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: - T20 (AC-6)

    func testFailedExportIsShownWithCause() {
        // GIVEN gesäter fehlgeschlagener Export, Entwicklermodus
        let app = launchedApp(developerMode: true)

        // WHEN Einstellungen geöffnet
        openSettings(app)
        let mirrorRow = row("iCloud-Abgleich", in: app)
        scrollTo(mirrorRow, in: app)

        // THEN Zeile „iCloud-Abgleich“ zeigt „Export fehlgeschlagen“
        XCTAssertTrue(mirrorRow.exists, "Zeile „iCloud-Abgleich“ fehlt im Entwicklermodus")
        let label = mirrorRow.waitForLabel(contains: "Export fehlgeschlagen")
        XCTAssertTrue(label.matched, "Untertitel ohne „Export fehlgeschlagen“, zuletzt: \(label.lastLabel)")

        // THEN Tipp öffnet die Ansicht mit der Ursache „CD_ShoppingItem“
        tapWhenHittable(mirrorRow, "Zeile „iCloud-Abgleich“")
        XCTAssertTrue(app.navigationBars["iCloud-Abgleich"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Ansicht „iCloud-Abgleich“ öffnet sich nicht")
        let cause = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "CD_ShoppingItem")).firstMatch
        XCTAssertTrue(cause.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Ursache „CD_ShoppingItem“ fehlt in der Detailansicht")
    }

    // MARK: - T21 (AC-11)

    func testDuplicatesShownAndNothingChanged() {
        // GIVEN gesätes Preset-Doppel „Lidl“/„Lidl“, Ladenanzahl auf der Startseite vorher
        let app = launchedApp(developerMode: true)
        let before = lidlTileCount(app)
        XCTAssertGreaterThanOrEqual(before, 2, "Seed-Doppel „Lidl“ steht nicht zweimal auf der Startseite")

        // WHEN Zeile „Doppelte Läden“ geöffnet
        openSettings(app)
        let duplicatesRow = row("Doppelte Läden", in: app)
        scrollTo(duplicatesRow, in: app)
        tapWhenHittable(duplicatesRow, "Zeile „Doppelte Läden“")
        XCTAssertTrue(app.navigationBars["Doppelte Läden"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Ansicht „Doppelte Läden“ öffnet sich nicht")

        // THEN „Doppelgruppen“ = 1 und „bliebe“ sichtbar
        let groupTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Doppelgruppen")).firstMatch
        XCTAssertTrue(groupTitle.waitForExistence(timeout: UITestWait.defaultTimeout), "Zähler „Doppelgruppen“ fehlt")
        let groupCount = app.descendants(matching: .any).matching(identifier: "storeDuplicates.groupCount").firstMatch
        XCTAssertTrue(groupCount.waitForExistence(timeout: UITestWait.defaultTimeout), "Wert der Doppelgruppen fehlt")
        XCTAssertEqual(groupCount.label, "1", "Doppelgruppen ≠ 1")
        let keeps = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "bliebe")).firstMatch
        XCTAssertTrue(keeps.waitForExistence(timeout: UITestWait.defaultTimeout), "Markierung „bliebe“ fehlt")

        // THEN nach dem Schließen: Ladenanzahl auf der Startseite unverändert (nichts gelöscht/zusammengeführt)
        tapWhenHittable(app.navigationBars.buttons.firstMatch, "Zurück")
        tapWhenHittable(app.buttons["Fertig"], "„Fertig“")
        XCTAssertTrue(tile("Lidl", in: app).waitUntilHittable().matched, "Startseite nicht zurück")
        XCTAssertEqual(lidlTileCount(app), before, "Ladenanzahl hat sich durch das Öffnen geändert")
    }

    // MARK: - T22 (AC-7)

    func testRowsHiddenOutsideDeveloperMode() {
        // GIVEN Entwicklermodus aus (gesäter Status und Doppel vorhanden)
        let app = launchedApp(developerMode: false)

        // WHEN Einstellungen geöffnet und ganz durchgescrollt
        openSettings(app)
        let mirrorRow = row("iCloud-Abgleich", in: app)
        let duplicatesRow = row("Doppelte Läden", in: app)
        var swipes = 0
        while !mirrorRow.exists && !duplicatesRow.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }

        // THEN keine der beiden Zeilen
        XCTAssertFalse(mirrorRow.exists, "„iCloud-Abgleich“ steht außerhalb des Entwicklermodus")
        XCTAssertFalse(duplicatesRow.exists, "„Doppelte Läden“ steht außerhalb des Entwicklermodus")
    }
}
