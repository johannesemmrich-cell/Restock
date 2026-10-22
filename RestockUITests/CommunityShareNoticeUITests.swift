import XCTest

/// Erst-Hinweis vor dem ersten Preisbeitrag (Issue #186).
///
/// Beim ersten Speichern eines Bons mit eingeschaltetem Schalter „Preise anonym mit anderen teilen“
/// erscheint VOR dem Hochladen einmal der Systemhinweis „Preise anonym teilen?“. Der Prüf-Screen bleibt
/// bis zur Entscheidung offen; „Nicht teilen“ schaltet den Schalter aus, „Weiter teilen“ lässt ihn an.
///
/// Argument-Domain-Falle: Diese Klasse setzt nie `-communityPricesNoticeShown` und nie
/// `-communityPricesSharingEnabled` — ein Launch-Argument überlagert jedes Schreiben der App für den
/// ganzen Lauf. Frischer Zustand nur über den Aufräumer `-clearCommunityPricesNoticeForUITests`
/// (entfernt Merker und Schalter-Schlüssel), in `setUp` und `tearDown`.
///
/// Issue #208: Jeder Start, der speichern kann, setzt `-blockCommunityContributionsForUITests`, damit
/// „Weiter teilen“ keinen echten Beitrag an die CloudKit-Entwicklungsumgebung sendet.
///
/// Spec: docs/specs/services/community-prices-erst-hinweis.md (AC-1 bis AC-5, AC-14).
final class CommunityShareNoticeUITests: XCTestCase {

    private enum Text {
        static let reviewTitle = "Bon scannen — Lidl"
        static let noticeTitle = "Preise anonym teilen?"
        static let share = "Weiter teilen"
        static let decline = "Nicht teilen"
        static let sharingSwitch = "Preise anonym mit anderen teilen"
    }

    private static let cleanup = ["-hasCompletedOnboarding", "YES",
                                  "-clearCommunityPricesNoticeForUITests", "-clearReceiptReviewSeedForUITests"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        runCleaner()
    }

    override func tearDown() {
        runCleaner()
        super.tearDown()
    }

    private func runCleaner() {
        let cleaner = XCUIApplication()
        cleaner.launchArguments = Self.cleanup
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    /// Startet mit dem gesäten Lidl-Bon; mit `freshNotice` zusätzlich mit dem Aufräumer (Merker weg).
    private func openedReview(freshNotice: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests",
                                "-blockCommunityContributionsForUITests"]
        if freshNotice { app.launchArguments += ["-clearCommunityPricesNoticeForUITests"] }
        UITestLaunch.start(app, expecting: app.descendants(matching: .any)
                            .matching(identifier: "receiptReview.sectionHeader").firstMatch,
                           description: "Kopfzeile des Bon-Prüf-Screens (Seed)")
        XCTAssertTrue(app.navigationBars[Text.reviewTitle].waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.")
        return app
    }

    private func tapSave(_ app: XCUIApplication) {
        let save = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(save.waitUntilHittable().matched, "Speichern-Knopf nicht antippbar.")
        save.tap()
    }

    /// Hinweis steht, beide Knöpfe da, Prüf-Screen dahinter noch offen (AC-1, AC-4).
    private func assertNoticeShownOverOpenReview(_ app: XCUIApplication) -> XCUIElement {
        let notice = app.alerts[Text.noticeTitle]
        XCTAssertTrue(notice.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Nach dem ersten Speichern erscheint kein Hinweis „\(Text.noticeTitle)“.")
        XCTAssertTrue(notice.buttons[Text.share].exists, "Knopf „\(Text.share)“ fehlt im Hinweis.")
        XCTAssertTrue(notice.buttons[Text.decline].exists, "Knopf „\(Text.decline)“ fehlt im Hinweis.")
        XCTAssertEqual(notice.buttons.count, 2, "Der Hinweis hat nicht genau zwei Knöpfe.")
        XCTAssertTrue(app.navigationBars[Text.reviewTitle].exists,
                      "Der Prüf-Screen hat sich vor der Entscheidung geschlossen.")
        return notice
    }

    private func assertReviewClosed(_ app: XCUIApplication, _ context: String) {
        XCTAssertTrue(app.navigationBars[Text.reviewTitle].waitForNonExistence(timeout: UITestWait.defaultTimeout),
                      "Der Prüf-Screen bleibt \(context) offen.")
        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        XCTAssertTrue(lidlTile.waitForExistence(timeout: UITestWait.defaultTimeout),
                      "Startseite nach dem Schließen nicht sichtbar (\(context)).")
    }

    /// Öffnet die Einstellungen und liefert den Wert des Schalters („0“ aus, „1“ an).
    private func sharingSwitchValue(_ app: XCUIApplication) -> String? {
        let gear = app.buttons["gearshape"]
        XCTAssertTrue(gear.waitUntilHittable().matched, "Zahnrad auf der Startseite nicht antippbar.")
        gear.tap()
        let toggle = app.switches[Text.sharingSwitch]
        var swipes = 0
        while !(toggle.exists && toggle.isHittable) && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(toggle.exists, "Schalter „\(Text.sharingSwitch)“ in den Einstellungen nicht gefunden.")
        return toggle.value as? String
    }

    // MARK: - T1 (AC-1, AC-3, AC-4)

    func testFirstSaveAsksFirstAndDeclineTurnsSharingOff() {
        let app = openedReview(freshNotice: true)
        tapSave(app)

        let notice = assertNoticeShownOverOpenReview(app)
        notice.buttons[Text.decline].tap()

        assertReviewClosed(app, "nach „\(Text.decline)“")
        XCTAssertEqual(sharingSwitchValue(app), "0",
                       "Nach „\(Text.decline)“ steht der Schalter in den Einstellungen nicht auf aus.")
    }

    // MARK: - T2 (AC-2)

    func testKeepSharingClosesScreenAndKeepsSwitchOn() {
        let app = openedReview(freshNotice: true)
        tapSave(app)

        let notice = assertNoticeShownOverOpenReview(app)
        notice.buttons[Text.share].tap()

        assertReviewClosed(app, "nach „\(Text.share)“")
        XCTAssertEqual(sharingSwitchValue(app), "1",
                       "Nach „\(Text.share)“ steht der Schalter in den Einstellungen nicht mehr auf an.")
    }

    // MARK: - T3 (AC-5)

    func testSecondSaveShowsNoNotice() {
        let first = openedReview(freshNotice: true)
        tapSave(first)
        assertNoticeShownOverOpenReview(first).buttons[Text.share].tap()
        assertReviewClosed(first, "nach „\(Text.share)“")
        first.terminate()

        // Zweiter Start OHNE Aufräumer: der Merker aus dem ersten Lauf muss über den Neustart halten.
        let second = openedReview(freshNotice: false)
        tapSave(second)
        assertReviewClosed(second, "beim zweiten Speichern")
        XCTAssertFalse(second.alerts[Text.noticeTitle].exists,
                       "Beim zweiten Speichern erscheint der Hinweis erneut.")
    }
}
