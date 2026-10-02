import XCTest

/// Issue #14 — echter Durchlauf der Bon-Auflösungs-Messung: Bon aus dem Seed im Review prüfen,
/// ändern/abwählen, speichern, dann Einstellungen → „Bon-Auflösung“ öffnen und die Zahlen lesen.
/// Spec: `docs/specs/services/receipt-resolution-stats.md` (AC-15 bis AC-19).
///
/// Der Seed `-seedReceiptReviewForUITests` (`SmartCartApp.swift`) legt vier Zeilen mit festen
/// Stufen in die App-Gruppe: Zeile 0 `.ai`, Zeilen 1 und 2 `.completed`, Zeile 3 `.history`.
/// Der Zähler liegt im App-Gruppen-Container und überlebt den Test — `tearDown()` räumt ihn über
/// `-clearReceiptResolutionStatsForUITests` und den Seed über `-clearReceiptReviewSeedForUITests` weg.
///
/// Testsprache: deutsch über den Scheme-Test-Action (siehe Kopfkommentar `RestockUITests.swift`).
final class ReceiptResolutionStatsUITests: XCTestCase {

    private enum Seed {
        static let aiLine = 0
        static let lastLine = 3
        /// Position der Option „Anderer Name …“ an der KI-Zeile (siehe `ReceiptReviewUITests.Seed`).
        static let aiLineCustomOptionIndex = 2
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-clearReceiptReviewSeedForUITests",
            "-clearReceiptResolutionStatsForUITests",
        ]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func waitUntilSettled(_ app: XCUIApplication) {
        let isForeground = NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue)
        expectation(for: isForeground, evaluatedWith: app)
        waitForExpectations(timeout: 30)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Startet mit leerem Zähler; `seed` öffnet zusätzlich den Bon-Review.
    private func launch(seed: Bool, developerMode: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-clearReceiptResolutionStatsForUITests"]
        if developerMode { app.launchArguments += ["-developerMode", "YES"] }
        if seed { app.launchArguments += ["-seedReceiptReviewForUITests"] }
        app.launch()
        waitUntilSettled(app)
        return app
    }

    private func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons.matching(NSPredicate(
            format: "identifier == 'gearshape' OR label CONTAINS[c] 'Einstellungen'")).firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 30), "Einstellungen-Knopf (Zahnrad) fehlt auf dem Home-Screen.")
        gear.tap()
    }

    /// Scrollt die Einstellungen, bis der Link da ist; gibt ihn zurück (oder ein nicht existierendes Element).
    private func statsLink(_ app: XCUIApplication) -> XCUIElement {
        let link = app.buttons["Bon-Auflösung"]
        var swipes = 0
        while !link.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        return link
    }

    private func openStatsScreen(_ app: XCUIApplication) {
        openSettings(app)
        let link = statsLink(app)
        XCTAssertTrue(link.exists, "Link „Bon-Auflösung“ fehlt in den Einstellungen (Entwicklermodus).")
        link.tap()
        XCTAssertTrue(app.navigationBars["Bon-Auflösung"].waitForExistence(timeout: 10),
                      "Bildschirm „Bon-Auflösung“ öffnet sich nicht.")
    }

    /// Erste ganze Zahl im Label (Werte können „1“ oder „1 (25 %)“ lauten).
    private func number(_ app: XCUIApplication, _ identifier: String,
                        file: StaticString = #filePath, line: UInt = #line) -> Int? {
        let el = element(app, identifier)
        XCTAssertTrue(el.waitForExistence(timeout: 5), "\(identifier) fehlt.", file: file, line: line)
        let digits = el.label.prefix { $0.isNumber }
        return Int(digits)
    }

    private func saveReviewedReceipt(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 30),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.")
        let save = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        save.tap()
        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        XCTAssertTrue(lidlTile.waitForExistence(timeout: 10), "Nach dem Speichern ist der Home-Screen nicht sichtbar.")
    }

    // MARK: - AC-16: leerer Zustand

    func testStatsScreenWithoutDataShowsSevenStagesAndZeroTotals() {
        let app = launch(seed: false)
        openStatsScreen(app)

        for stage in ["alias", "dictionary", "completed", "history", "ai", "rawText", "nonProduct"] {
            XCTAssertTrue(element(app, "resolutionStage.\(stage)").exists, "Stufenzeile \(stage) fehlt.")
            XCTAssertEqual(number(app, "resolutionStage.\(stage).total"), 0, "Stufe \(stage) müsste leer sein.")
        }
        XCTAssertEqual(number(app, "resolutionStage.all.total"), 0)
    }

    // MARK: - AC-18: echter Durchlauf Review → Speichern → Bildschirm

    func testSavedReceiptIsCountedPerStageWithChangedAndDeselected() {
        let app = launch(seed: true)
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 30))

        // Zeile 0 (Stufe KI) umbenennen → „Geändert“ bei KI.
        let customOption = element(app, "receiptReview.line.\(Seed.aiLine).option.\(Seed.aiLineCustomOptionIndex)")
        XCTAssertTrue(customOption.waitForExistence(timeout: 5), "Option „Anderer Name …“ fehlt.")
        customOption.tap()
        let field = app.textFields["receiptReview.line.\(Seed.aiLine).customNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        let existing = (field.value as? String) ?? ""
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText("Ziegenmilch")

        // Letzte Zeile (Stufe Historie) abwählen → „Abgewählt“ bei Historie.
        let last = element(app, "receiptReview.line.\(Seed.lastLine).checkbox")
        var swipes = 0
        while !last.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(last.isHittable, "Häkchen der letzten Zeile nicht erreichbar.")
        last.tap()

        saveReviewedReceipt(app)
        openStatsScreen(app)

        XCTAssertEqual(number(app, "resolutionStage.all.total"), 4, "Summenzeile = Zeilenzahl des Seeds")
        XCTAssertEqual(number(app, "resolutionStage.ai.total"), 1)
        XCTAssertEqual(number(app, "resolutionStage.ai.changed"), 1, "KI-Zeile wurde umbenannt")
        XCTAssertEqual(number(app, "resolutionStage.completed.total"), 2)
        XCTAssertEqual(number(app, "resolutionStage.completed.changed"), 0)
        XCTAssertEqual(number(app, "resolutionStage.history.total"), 1)
        XCTAssertEqual(number(app, "resolutionStage.history.deselected"), 1, "Letzte Zeile wurde abgewählt")
        XCTAssertEqual(number(app, "resolutionStage.alias.total"), 0)
        XCTAssertEqual(number(app, "resolutionStage.nonProduct.total"), 0, "Nicht-Produkt bleibt in #14 leer (siehe #90)")
    }

    // MARK: - AC-17: Zurücksetzen mit Bestätigung

    func testResetAsksForConfirmationAndClearsOnlyAfterConfirming() {
        let app = launch(seed: true)
        saveReviewedReceipt(app)
        openStatsScreen(app)
        XCTAssertEqual(number(app, "resolutionStage.all.total"), 4, "Vorbedingung: Zahlen stehen")

        let reset = element(app, "resolutionStatsResetButton")
        var swipes = 0
        while !reset.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        reset.tap()
        let cancel = app.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Bestätigungsdialog erscheint nicht.")
        cancel.tap()
        XCTAssertEqual(number(app, "resolutionStage.all.total"), 4, "Nach „Abbrechen“ bleiben die Zahlen")

        reset.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Zurücksetzen'")).allElementsBoundByIndex.last
        XCTAssertNotNil(confirm)
        XCTAssertTrue(confirm!.waitForExistence(timeout: 5))
        confirm!.tap()
        XCTAssertEqual(number(app, "resolutionStage.all.total"), 0, "Nach Bestätigung stehen alle Werte auf 0")
    }

    // MARK: - AC-15: nur im Entwicklermodus

    func testLinkIsNotShownOutsideDeveloperMode() {
        let app = launch(seed: false, developerMode: false)
        openSettings(app)
        XCTAssertFalse(statsLink(app).exists, "Ohne Entwicklermodus darf es keinen Zugang geben.")
    }
}
