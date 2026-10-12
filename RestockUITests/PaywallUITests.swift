import XCTest

/// Issue #98, Durchgang 5 — Paywall-Sperre an den drei Auslösern und Falsch-Pfad des Dev-Passworts.
/// Spec: `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` (AC-5 bis AC-9).
///
/// Läuft ohne Premium (`-developerMode NO` überlagert einen gespeicherten Wert). Die Klasse sät und
/// speichert nichts Dauerhaftes (kein Kauf, kein erfolgreiches Passwort) und braucht daher kein Aufräumen.
///
/// Offene Grenzen (Spec AC-13): Kauf, Wiederherstellen und die Release-Fehlermeldung der Paywall werden
/// nur auf Existenz geprüft, nie bedient (im Simulator ist `products` leer; `Restock.storekit` steht in
/// keinem Scheme, der DEBUG-Zweig `dismiss()` ist nicht der Release-Weg). Der Richtig-Pfad des
/// Dev-Passworts ist ungeprüft; der Test kennt das Passwort nicht. `StoreSetupView` folgt in Durchgang 6.
final class PaywallUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchLocked() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO"]
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        return app
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    /// „Paywall steht“: nur Existenz, kein Tipp auf Kaufen oder Wiederherstellen.
    private func assertPaywall(_ app: XCUIApplication, feature: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["Restock Pro"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Paywall-Kopf „Restock Pro“ fehlt", file: file, line: line)
        // Das Label trägt einen Zeilenumbruch („… weiteren\nPro-Features frei.“), deshalb nur Teilstrings,
        // und über alle Elementarten, weil SwiftUI den Text je nach Container unterschiedlich ausweist.
        let title = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "Schalte \(feature)", "Pro-Features frei")).firstMatch
        let anyTitle = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Schalte")).firstMatch
        _ = anyTitle.waitForExistence(timeout: 5)
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Titelzeile „Schalte \(feature) …“ fehlt, gefunden: „\(anyTitle.exists ? anyTitle.label : "nichts")“",
                      file: file, line: line)
        XCTAssertTrue(app.buttons["Käufe wiederherstellen"].exists, "„Käufe wiederherstellen“ fehlt", file: file, line: line)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Jetzt freischalten")).firstMatch.exists,
                      "Kaufknopf „Jetzt freischalten…“ fehlt", file: file, line: line)
    }

    private func closePaywall(_ app: XCUIApplication) {
        tapWhenHittable(app.buttons["Schließen"], "„Schließen“")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Restock Pro"])
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: - AC-5, AC-6

    func testRecipePlanLockedOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife")
        assertPaywall(app, feature: "den Rezeptplan")
        XCTAssertFalse(app.buttons["Tag hinzufügen"].exists, "Der Menüplan öffnet sich trotz Sperre")
        closePaywall(app)
        XCTAssertTrue(app.buttons["fork.knife"].waitUntilHittable().matched, "Startseite nach „Schließen“ nicht bedienbar")
    }

    func testExpensesAnalysisLockedOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["chart.bar"], "chart.bar")
        assertPaywall(app, feature: "die Ausgaben-Analyse")
        closePaywall(app)
        XCTAssertTrue(app.buttons["chart.bar"].waitUntilHittable().matched, "Startseite nach „Schließen“ nicht bedienbar")
    }

    func testSettingsProRowOpensPaywall() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        // Das Label der Zeile enthält auch die Unterzeile („Restock Pro freischalten, Ausgaben-Analyse & …“).
        let proRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro freischalten")).firstMatch
        scrollTo(proRow, in: app)
        XCTAssertTrue(proRow.exists, "Zeile „Restock Pro freischalten“ fehlt in den Einstellungen")
        XCTAssertFalse(app.staticTexts["Pro aktiv"].exists, "„Pro aktiv“ steht ohne Premium")
        proRow.tap()
        assertPaywall(app, feature: "alle Pro-Features")
        closePaywall(app)
        XCTAssertTrue(proRow.waitUntilHittable().matched, "Einstellungen nach „Schließen“ nicht sichtbar")
    }

    // MARK: - AC-7 (Gegenprobe)

    func testPremiumAccessOpensMenuPlanWithoutPaywall() {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO",
                                "-premiumForScreenshots", "-clearMenuPlanForUITests"]
        UITestLaunch.start(app, expecting: app.buttons["fork.knife"], description: "Menüplan-Knopf fork.knife")
        tapWhenHittable(app.buttons["fork.knife"], "fork.knife")
        XCTAssertTrue(app.buttons["Tag hinzufügen"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Menüplan öffnet sich mit Premium nicht")
        XCTAssertFalse(app.staticTexts["Restock Pro"].exists, "Die Paywall erscheint trotz Premium")
    }

    // MARK: - AC-8 (Dev-Passwort, nur Falsch-Pfad)

    func testWrongDevPasswordShowsErrorAndKeepsSheetOpen() {
        let app = launchLocked()
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        let version = app.staticTexts["Version"]
        scrollTo(version, in: app)
        XCTAssertTrue(version.waitUntilHittable().matched, "Zeile „Version“ nicht antippbar")

        // Fünf Tipps mit einer aufgelösten Koordinate (2-s-Fenster); bei verschlucktem Tipp einmal wiederholen.
        let spot = version.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let sheetTitle = app.staticTexts["Developer Mode"]
        for attempt in 0..<2 where !sheetTitle.exists {
            if attempt == 1 { Thread.sleep(forTimeInterval: 2.5) }
            for _ in 0..<5 { spot.tap() }
            _ = sheetTitle.waitForExistence(timeout: UITestWait.defaultTimeout)
        }
        XCTAssertTrue(sheetTitle.exists, "Das Sheet „Developer Mode“ erscheint nach fünf Tipps nicht")

        let field = app.secureTextFields["Passwort"]
        tapWhenHittable(field, "Feld „Passwort“")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        field.typeText("falsch")
        let unlock = app.buttons["Entsperren"]
        tapWhenHittable(unlock, "„Entsperren“")

        XCTAssertTrue(app.staticTexts["Falsches Passwort"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Keine Fehlermeldung bei falschem Passwort")
        XCTAssertTrue(sheetTitle.exists, "Das Sheet schloss sich trotz falschem Passwort")
        XCTAssertFalse(unlock.isEnabled, "Die Eingabe wurde nach dem Fehlversuch nicht geleert")
        app.buttons["Abbrechen"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheetTitle)
        waitForExpectations(timeout: UITestWait.defaultTimeout)
    }
}
