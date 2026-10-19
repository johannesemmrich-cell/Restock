import XCTest

/// Issue #156, B2.1 (Entwurf A) — Die Ersteinrichtung wartet höchstens 10 s auf Läden aus iCloud.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md` (T23, T24; AC-14, AC-15).
///
/// Simuliert über DEBUG-Argumente (`SmartCartApp.init()` / `OnboardingView`):
/// `-simulateCloudImportForUITests <s>` (Konto gilt als vorhanden, erster Import erst nach s Sekunden fertig)
/// und `-simulateCloudStoresArriveForUITests <s>` (Konto vorhanden, nach s Sekunden kommen „Lidl“ und „Rewe“
/// über den echten Datenweg an). Ausgangszustand und Aufräumen wie `OnboardingUITests`: Start mit
/// `-clearOnboardingForUITests`, nie mit `-hasCompletedOnboarding` (Argument-Domain-Falle).
///
/// Offene Grenze (Spec AC-20): Der echte iCloud-Import mit eintreffenden Läden ist nur am Gerät belegbar.
final class OnboardingCloudWaitUITests: XCTestCase {

    private static let hint = "Deine Läden werden aus iCloud geladen"

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

    private func hintText(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", Self.hint)).firstMatch
    }

    private func tiles(_ name: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),"))
    }

    // MARK: - T23 (AC-14)

    func testHintAndLockedButtonUntilImportDone() {
        // GIVEN simulierter Import von 4 s, neuer Nutzer
        let app = XCUIApplication()
        app.launchArguments += ["-clearOnboardingForUITests", "-simulateCloudImportForUITests", "4"]

        // WHEN die App startet
        UITestLaunch.start(app, expecting: hintText(app), description: "Hinweis „\(Self.hint) …“")
        let start = app.buttons["Loslegen"]

        // THEN Hinweis sichtbar, „Loslegen“ gesperrt
        XCTAssertTrue(start.exists, "„Loslegen“ fehlt während des Wartens")
        XCTAssertFalse(start.isEnabled, "„Loslegen“ ist aktiv, obwohl der Import noch läuft")

        // THEN spätestens nach 10 s (plus Abfragepuffer) ist „Loslegen“ aktiv und der Hinweis weg
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(hintText(app).exists, "Hinweis steht nach Ende des Wartens noch da")
        XCTAssertTrue(start.waitUntilHittable().matched, "„Loslegen“ nach dem Warten nicht antippbar")
    }

    // MARK: - T24 (AC-15)

    func testArrivingStoresSkipOnboarding() {
        // GIVEN nach 3 s kommen zwei Läden aus „iCloud“ an, neuer Nutzer
        let app = XCUIApplication()
        app.launchArguments += ["-clearOnboardingForUITests", "-simulateCloudStoresArriveForUITests", "3"]

        // WHEN die App startet und die Läden eintreffen
        UITestLaunch.start(app, expecting: tiles("Lidl", in: app).firstMatch, description: "Kachel „Lidl“ (angekommen)")

        // THEN entfällt die Einrichtung, die Startseite zeigt die zwei Läden genau einmal
        XCTAssertFalse(app.buttons["Loslegen"].exists, "Die Einrichtung steht trotz angekommener Läden noch da")
        XCTAssertTrue(tiles("Rewe", in: app).firstMatch.waitUntilHittable().matched, "Kachel „Rewe“ fehlt")
        XCTAssertEqual(tiles("Lidl", in: app).count, 1, "„Lidl“ steht nicht genau einmal auf der Startseite")
        XCTAssertEqual(tiles("Rewe", in: app).count, 1, "„Rewe“ steht nicht genau einmal auf der Startseite")
        XCTAssertFalse(tiles("Edeka", in: app).firstMatch.exists, "Presets wurden zusätzlich angelegt")

        // THEN nach Neustart ohne Argument bleibt die Startseite
        app.terminate()
        let restarted = XCUIApplication()
        restarted.launch()
        XCTAssertTrue(tiles("Lidl", in: restarted).firstMatch.waitUntilHittable().matched,
                      "Nach dem Neustart steht die Startseite nicht (Flag nicht gespeichert?)")
        XCTAssertFalse(restarted.buttons["Loslegen"].exists, "Das Onboarding erscheint nach dem Neustart erneut")
        XCTAssertEqual(tiles("Lidl", in: restarted).count, 1, "„Lidl“ nach dem Neustart nicht genau einmal")
    }
}
