import CryptoKit
import XCTest

/// Issue #145, Durchgang 1 — Richtig-Pfad des Dev-Passworts über die ganze Kette.
/// Spec: `docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md` (AC-1 bis AC-5).
///
/// Der Vergleichshash wird per DEBUG-Argument `-devPasswordHashForUITests` durch den Hash eines
/// Testpassworts ersetzt; `verify()` läuft unverändert. Nie `-developerMode` setzen: als
/// Launch-Argument überlagert es den Schreibvorgang des Entsperrens. Erfolgreiches Entsperren schreibt
/// `developerMode = true` in den App-Container, deshalb räumen Start und `tearDown()` mit
/// `-clearDeveloperModeForUITests` auf.
///
/// Offene Grenze (Spec AC-13): Der Release-Pfad mit dem echten Passwort und festem Hash bleibt ungetestet.
final class DeveloperModeUnlockUITests: XCTestCase {

    private static let testPassword = "uitest-dev-passwort"

    private static var testPasswordHash: String {
        SHA256.hash(data: Data(testPassword.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        let cleaner = XCUIApplication()
        cleaner.launchArguments += ["-hasCompletedOnboarding", "YES", "-clearDeveloperModeForUITests"]
        UITestLaunch.start(cleaner, expecting: cleaner.buttons["gearshape"], description: "Zahnrad (Aufräumer)")
        cleaner.terminate()
    }

    private func launch(clearAndOverride: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        if clearAndOverride {
            app.launchArguments += ["-clearDeveloperModeForUITests",
                                    "-devPasswordHashForUITests", Self.testPasswordHash]
        }
        UITestLaunch.start(app, expecting: app.buttons["gearshape"], description: "Zahnrad")
        return app
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    private func proActive(_ app: XCUIApplication) -> XCUIElement { app.staticTexts["Pro aktiv"] }

    /// Zurück zum Pro-Abschnitt: dort steht immer genau eine der beiden Zeilen. Endet, sobald eine da
    /// ist, damit kein Wischen am Listenanfang das Einstellungs-Sheet schließt.
    private func scrollToProSection(_ app: XCUIApplication) {
        let lockedRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro freischalten")).firstMatch
        var swipes = 0
        while !proActive(app).exists && !lockedRow.exists && swipes < 8 {
            app.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(proActive(app).exists || lockedRow.exists, "Pro-Abschnitt der Einstellungen nicht gefunden")
    }

    private func deactivateRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Developer Mode deaktivieren")).firstMatch
    }

    /// Einstellungen öffnen, zu „Version“ scrollen, Sheet per Mehrfachtipp öffnen, Passwort eingeben.
    private func enterPassword(_ password: String, in app: XCUIApplication) -> XCUIElement {
        let version = app.staticTexts["Version"]
        scrollTo(version, in: app)
        XCTAssertTrue(version.waitUntilHittable().matched, "Zeile „Version“ nicht antippbar")

        // Mehrfachtipp wie im Falsch-Pfad (PaywallUITests): ein Ereignis, eine Wiederholung nach 2,5 s.
        let sheetTitle = app.staticTexts["Developer Mode"]
        for attempt in 0..<2 where !sheetTitle.exists {
            if attempt == 1 { Thread.sleep(forTimeInterval: 2.5) }
            version.tap(withNumberOfTaps: 5, numberOfTouches: 1)
            _ = sheetTitle.waitForExistence(timeout: UITestWait.defaultTimeout)
        }
        XCTAssertTrue(sheetTitle.exists, "Das Sheet „Developer Mode“ erscheint nach fünf Tipps nicht")

        let field = app.secureTextFields["Passwort"]
        tapWhenHittable(field, "Feld „Passwort“")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        field.typeText(password)
        let unlock = app.buttons["Entsperren"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: unlock)
        waitForExpectations(timeout: 10)
        tapWhenHittable(unlock, "„Entsperren“")
        return sheetTitle
    }

    // MARK: - AC-1 bis AC-4 (T1)

    func testCorrectDevPasswordUnlocksAndSurvivesRestart() {
        let app = launch(clearAndOverride: true)
        XCTAssertFalse(app.staticTexts["DEV"].exists, "DEV-Pill steht schon vor dem Entsperren (Altzustand)")
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        let lockedRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Restock Pro freischalten")).firstMatch
        // Die Einstellungen sind eine Form, die nur sichtbare Zeilen in den Baum stellt; seit dem
        // Community-Schalter mit Hinweistext (#163) liegt der Pro-Abschnitt beim Öffnen unter dem Rand,
        // deshalb erst hinscrollen (wie PaywallUITests.testSettingsProRowOpensPaywall).
        scrollTo(lockedRow, in: app)
        XCTAssertTrue(lockedRow.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Zeile „Restock Pro freischalten“ fehlt vor dem Entsperren (Altzustand?)")
        XCTAssertFalse(proActive(app).exists, "„Pro aktiv“ steht schon vor dem Entsperren (Altzustand)")

        let sheetTitle = enterPassword(Self.testPassword, in: app)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheetTitle)
        waitForExpectations(timeout: UITestWait.defaultTimeout)

        let deactivate = deactivateRow(app)
        scrollTo(deactivate, in: app)
        XCTAssertTrue(deactivate.exists, "„Developer Mode deaktivieren“ fehlt nach dem Entsperren")
        scrollToProSection(app)
        XCTAssertTrue(proActive(app).exists, "„Pro aktiv“ fehlt nach dem Entsperren")

        tapWhenHittable(app.buttons["Fertig"], "„Fertig“")
        XCTAssertTrue(app.staticTexts["DEV"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "DEV-Pill fehlt nach dem Entsperren")

        // AC-3: Neustart ohne Clear- und Hash-Argument — der Zustand stand wirklich im Container.
        app.terminate()
        let restarted = launch(clearAndOverride: false)
        XCTAssertTrue(restarted.staticTexts["DEV"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "DEV-Pill fehlt nach dem Neustart")
        tapWhenHittable(restarted.buttons["gearshape"], "Zahnrad nach Neustart")
        XCTAssertTrue(proActive(restarted).waitForExistence(timeout: UITestWait.defaultTimeout),
                      "„Pro aktiv“ fehlt nach dem Neustart")
        let deactivateAfterRestart = deactivateRow(restarted)
        scrollTo(deactivateAfterRestart, in: restarted)
        XCTAssertTrue(deactivateAfterRestart.exists, "„Developer Mode deaktivieren“ fehlt nach dem Neustart")
    }

    // MARK: - AC-5 (T2, Gegenprobe)

    func testWrongPasswordWithOverrideDoesNotUnlock() {
        let app = launch(clearAndOverride: true)
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        let sheetTitle = enterPassword("falsch", in: app)

        XCTAssertTrue(app.staticTexts["Falsches Passwort"].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Keine Fehlermeldung bei falschem Passwort trotz Überschreibung")
        XCTAssertTrue(sheetTitle.exists, "Das Sheet schloss sich trotz falschem Passwort")
        app.buttons["Abbrechen"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheetTitle)
        waitForExpectations(timeout: UITestWait.defaultTimeout)

        scrollToProSection(app)
        XCTAssertFalse(proActive(app).exists, "„Pro aktiv“ steht nach falschem Passwort")
        tapWhenHittable(app.buttons["Fertig"], "„Fertig“")
        XCTAssertFalse(app.staticTexts["DEV"].waitForExistence(timeout: 3), "DEV-Pill steht nach falschem Passwort")
    }
}
