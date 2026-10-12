import XCTest

/// Issue #98, Durchgang 5 — echter Durchlauf des Onboardings (Willkommen, Name, Land, Läden, Tutorial).
/// Spec: `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` (AC-1 bis AC-4, AC-9, AC-10).
///
/// Der Test startet bewusst OHNE `-hasCompletedOnboarding`: Als Launch-Argument überlagert es in der
/// Argument-Domain auch das, was `finishOnboarding()` schreibt, und der Test bliebe auf dem letzten
/// Schritt stehen. Den Ausgangszustand stellt `-clearOnboardingForUITests` her (Läden, Artikel,
/// `hasCompletedOnboarding`, `selectedCountry`, Anzeigename). `tearDown()` räumt mit demselben Argument auf.
///
/// Offene Grenzen (Spec AC-13): Kauf, Wiederherstellen und Release-Fehlermeldung der Paywall sind nicht
/// automatisiert geprüft, ebenso der Richtig-Pfad des Dev-Passworts; `StoreSetupView` folgt in Durchgang 6.
/// Testsprache: deutsch über den Scheme-Test-Action (siehe Kopfkommentar `RestockUITests.swift`).
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearOnboardingForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    private func tile(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    private func tapWhenHittable(_ element: XCUIElement, _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = element.waitUntilHittable()
        XCTAssertTrue(result.matched, "\(what) nicht antippbar, zuletzt: \(result.last)", file: file, line: line)
        element.tap()
    }

    // MARK: - AC-1 bis AC-4

    func testOnboardingWalkthroughCreatesChosenStoresAndName() {
        let app = XCUIApplication()
        app.launchArguments += ["-clearOnboardingForUITests"]
        UITestLaunch.start(app, expecting: app.buttons["Loslegen"], description: "„Loslegen“ (Onboarding Schritt 0)")

        // Schritt 0 → 1: Name, „Weiter“ erst bei nicht leerem Feld aktiv.
        app.buttons["Loslegen"].tap()
        XCTAssertTrue(app.staticTexts["Wie heißt du?"].waitForExistence(timeout: UITestWait.defaultTimeout))
        let next = app.buttons["Weiter"]
        XCTAssertTrue(next.waitForExistence(timeout: UITestWait.defaultTimeout))
        XCTAssertFalse(next.isEnabled, "„Weiter“ ist bei leerem Namen aktiv")
        let nameField = app.textFields.firstMatch
        tapWhenHittable(nameField, "Namensfeld")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: nameField)
        waitForExpectations(timeout: 10)
        nameField.typeText("Testperson")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: next)
        waitForExpectations(timeout: 10)
        next.tap()

        // Schritt 2: Land bleibt (kein Landwechsel, Spec Risiken).
        XCTAssertTrue(app.staticTexts["Wo kaufst du ein?"].waitForExistence(timeout: UITestWait.defaultTimeout))
        tapWhenHittable(app.buttons["Weiter"], "„Weiter“ (Land)")

        // Schritt 3: Läden; Beschriftung des Sammelknopfs schaltet um.
        XCTAssertTrue(app.staticTexts["Deine Läden"].waitForExistence(timeout: UITestWait.defaultTimeout))
        tapWhenHittable(app.buttons["Alle auswählen"], "„Alle auswählen“")
        let deselect = app.buttons["Auswahl aufheben"]
        XCTAssertTrue(deselect.waitForExistence(timeout: 5), "Knopf heißt nach „Alle auswählen“ nicht „Auswahl aufheben“")
        deselect.tap()
        XCTAssertTrue(app.buttons["Alle auswählen"].waitForExistence(timeout: 5), "Auswahl wurde nicht geleert")
        app.staticTexts["Lidl"].tap()
        app.staticTexts["Rewe"].tap()
        tapWhenHittable(app.buttons["Einkaufen starten"], "„Einkaufen starten“")

        // Schritt 4: Tutorial.
        XCTAssertTrue(app.staticTexts["So funktioniert Restock"].waitForExistence(timeout: UITestWait.defaultTimeout))
        tapWhenHittable(app.buttons["Los geht's!"], "„Los geht's!“")

        // Startseite: nur die gewählten Läden.
        XCTAssertTrue(tile("Lidl", in: app).waitUntilHittable().matched, "Kachel „Lidl“ fehlt")
        XCTAssertTrue(tile("Rewe", in: app).waitUntilHittable().matched, "Kachel „Rewe“ fehlt")
        XCTAssertFalse(tile("Edeka", in: app).exists, "Nicht gewählter Laden „Edeka“ steht auf der Startseite")
        XCTAssertFalse(tile("DM", in: app).exists, "Nicht gewählter Laden „DM“ steht auf der Startseite")

        // Name angekommen.
        tapWhenHittable(app.buttons["gearshape"], "Zahnrad")
        let profileName = app.textFields["Dein Name"]
        XCTAssertTrue(profileName.waitForExistence(timeout: UITestWait.defaultTimeout), "Feld „Dein Name“ fehlt")
        XCTAssertEqual(profileName.value as? String, "Testperson", "Der Name aus dem Onboarding kam nicht an")

        // Neustart ohne jedes Argument: das Onboarding kehrt nicht wieder.
        app.terminate()
        let restarted = XCUIApplication()
        restarted.launch()
        XCTAssertTrue(tile("Lidl", in: restarted).waitUntilHittable().matched,
                      "Nach dem Neustart steht die Startseite nicht (Flag nicht gespeichert?)")
        XCTAssertFalse(restarted.buttons["Loslegen"].exists, "Das Onboarding erscheint nach dem Neustart erneut")
    }
}
