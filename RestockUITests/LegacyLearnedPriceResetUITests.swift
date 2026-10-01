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
}
