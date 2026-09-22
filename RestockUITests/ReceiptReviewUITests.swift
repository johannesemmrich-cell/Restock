import XCTest

/// Einstieg in den Bon-Prüf-Screen OHNE Kamera und OHNE Texterkennung (Issue #28).
///
/// Der Screen entsteht im echten Betrieb nur am Ende der Kette Teilen-Erweiterung →
/// App-Gruppe → `HomeView.checkPendingReceiptScan()` → Sheet. Kamera und OCR laufen im
/// Simulator nicht deterministisch, also setzt `-seedReceiptReviewForUITests` (DEBUG-only,
/// `SmartCartApp.swift`) den Laden samt festem Bon direkt in die App-Gruppe — der Rest der
/// Kette läuft unverändert durch den Produktcode. Kein Sonderpfad im Produkt, keine
/// Testattrappe: was hier geprüft wird, ist derselbe Weg, den ein Nutzer nimmt.
///
/// WICHTIG — Testsprache: Der Navigationstitel „Bon scannen — Lidl" ist deutscher
/// Produkttext. Dass der Simulator im Testlauf deutsch läuft, steht in `Restock.xcscheme`
/// am `<TestAction>` (`language = "de"`, `region = "DE"`) — siehe Kopfkommentar in
/// `RestockUITests.swift`.
///
/// WICHTIG — Determinismus des festen Bons: Beim Handoff läuft `reResolveAIIfNeeded()` und
/// würde Zeilen erneut durch die Namensauflösung schicken (Wörterbuch, Ähnlichkeitssuche,
/// gelernte Zuordnungen aus FRÜHEREN Läufen). Der feste Bon ist so gebaut, dass jede Zeile
/// entweder als KI-aufgelöst markiert ist oder einen vom Bontext abweichenden Namen trägt —
/// damit ist die Menge der nachzulösenden Zeilen leer und der Bon in jedem Lauf gleich.
/// Details und die Invariante: `docs/specs/testing/receipt-review-test-entry.md`.
final class ReceiptReviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedReceiptReviewForUITests"]
        app.launch()
        return app
    }

    /// Wartet, bis die App wirklich vorn und ansprechbar ist, BEVOR auf das Sheet gewartet wird.
    ///
    /// Nach einem kalten Install ist `launch()` allein kein verlässlicher Startpunkt: In einem
    /// Prüflauf brauchte schon das Hochfahren bis „App idle" rund 9,5 s (Automations-Sitzung
    /// 5,5 s, Idle-Warten weitere 2,5 s), sodass die anschließende Wartezeit auf die
    /// Navigationsleiste fast vollständig vom Start selbst aufgebraucht wurde und der Test
    /// durchfiel, obwohl das Sheet kurz darauf erschien. Gleiches defensives Muster wie das
    /// `hasKeyboardFocus`-Warten in `RestockUITests.swift` (dort Z. 183-185): erst den
    /// Vorbedingungs-Zustand abwarten, dann die eigentliche Prüfung.
    ///
    /// Reine Robustheit — geprüft wird danach exakt dasselbe wie vorher.
    private func waitUntilSettled(_ app: XCUIApplication) {
        let isForeground = NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue)
        expectation(for: isForeground, evaluatedWith: app)
        waitForExpectations(timeout: 20)
    }

    /// Grundgerüst: Der Prüf-Screen erscheint von selbst und trägt alle vier Bon-Zeilen.
    ///
    /// Dass „Speichern" bedienbar ist, ist kein Beiwerk, sondern der Beweis, dass die
    /// Ladenerkennung gegriffen hat: `canSave` bleibt gesperrt, solange der Laden nicht
    /// sicher erkannt wurde (`storeNeedsConfirmation`).
    func testReviewSheetOpensFromShareHandoff() {
        let app = launchedApp()
        waitUntilSettled(app)

        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 20),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.")

        for index in 0...3 {
            XCTAssertTrue(
                app.textFields["receiptReview.line.\(index).nameField"].waitForExistence(timeout: 5),
                "Zeile \(index): Namensfeld fehlt.")
            XCTAssertTrue(app.textFields["receiptReview.line.\(index).priceField"].exists,
                          "Zeile \(index): Preisfeld fehlt.")
        }

        // Die KI-Marke ist je nach SwiftUI-Fassung ein `otherElement` oder ein `staticText` —
        // beide Varianten gelten, geprüft wird ihre Existenz, nicht ihr Elementtyp.
        XCTAssertTrue(app.otherElements["receiptReview.line.0.aiMark"].exists
                        || app.staticTexts["receiptReview.line.0.aiMark"].exists,
                      "Zeile 0 ist als KI-aufgelöst geseedet, trägt aber keine KI-Marke.")

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        XCTAssertTrue(saveButton.isHittable,
                      "Speichern ist gesperrt — der Laden wurde nicht sicher erkannt.")
    }

    /// RED-Nachweis für Issue #23: Der Bontext (die Rohzeile des Kassenbons) ist heute auf
    /// keiner Zeile sichtbar — der Nutzer sieht nur den aufgelösten Namen und kann nicht
    /// prüfen, ob die Auflösung stimmt.
    ///
    /// Die Prüfung schlägt am heutigen Layout absichtlich fehl. `XCTExpectFailure` mit
    /// `strict: true` hält die Prüfstrecke dieses Issues grün UND erzwingt, dass #23 diese
    /// Erwartung entfernt: bleibt sie nach dem Einbau der Bontext-Anzeige stehen, wird der
    /// Test dort rot, weil der erwartete Fehlschlag ausbleibt.
    func testOriginalReceiptTextIsVisibleOnEveryLine() {
        let app = launchedApp()
        waitUntilSettled(app)

        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 20),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.")

        XCTExpectFailure("Bontext erst mit #23 sichtbar", strict: true) {
            for index in 0...3 {
                XCTAssertTrue(app.staticTexts["receiptReview.line.\(index).originalName"].exists,
                              "Zeile \(index): Bontext wird nicht angezeigt.")
            }
        }
    }
}
