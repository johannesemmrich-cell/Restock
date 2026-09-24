import XCTest
// Für die Pixelmessung des Dimmens (`XCUIScreenshot.image` ist ein `UIImage`).
import UIKit

/// Einstieg in den Bon-Prüf-Screen OHNE Kamera und OHNE Texterkennung (Issue #28) und
/// Prüfstrecke für den Karten-Umbau dieses Screens (Issue #23).
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

    // MARK: - Der gesäte Bon (Quelle: SmartCartApp.seedReceiptReviewForUITestsIfNeeded)

    /// Genau die vier Zeilen, die der Seed in die App-Gruppe legt — als Konstanten hier, damit
    /// jede Erwartung unten am tatsächlichen Fixture hängt und nicht an einer Annahme.
    private enum Seed {
        /// Rohtext, wie er auf dem Bon steht (`originalName`). Zeile 1 ist mit 42 Zeichen die
        /// längste — sie ist der eigentliche Prüffall für AC1 (nie abschneiden).
        static let rawTexts = [
            "MILCH 3,5% FRISCH",
            "BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G",
            "MILCH",
            "BROETCHEN",
        ]
        /// Zeile mit `resolvedByAI = true` — trägt die Art.-50-Kennzeichnung.
        static let aiLine = 0
        /// Einzige Zeile mit drei Listen-Treffern (Hafermilch, Buttermilch, Vollmilch).
        /// Der Seed hat keine Zeile mit KI-Vorschlag UND Treffern zugleich; die Kappung von
        /// fünf auf drei inhaltliche Optionen prüfen deshalb die Unit-Tests
        /// (`ReceiptReviewCardTests`), hier wird die Obergrenze von vier Zeilen geprüft.
        static let suggestionLine = 2
        /// Name des zweiten Listen-Treffers an `suggestionLine` — seit Issue #37 an Option 2
        /// (Option 0 ist die vorausgewählte Zusatzzeile mit dem geltenden Namen "Milch").
        static let secondSuggestion = "Buttermilch"
        /// Aufgelöster Name der KI-Zeile — steht im Bedienhilfen-Label ihres Häkchens.
        static let aiLineName = "Frische Vollmilch 3,5 %"
        /// Letzte Bon-Zeile und ihr Preis — Gegenprobe für „Speichern" mit genau einer
        /// Auswahl; sie liegt am Listenende, wo das Abwählen aller Positionen endet.
        static let lastLine = 3
        static let lastLinePriceText = "1,56 €"
        /// Zugeordneter Artikel und Preis der Zeile `suggestionLine` — nach dem Speichern muss
        /// genau dieser Preis am Artikel in der Liste stehen (AC12).
        static let matchedItemName = "Milch"
        static let matchedItemPriceText = "0,99 €"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Räumt den Seed nach JEDEM Test wieder weg — sonst erbt die Bestandssuite ihn.
    ///
    /// Der App-Group-Container überlebt den einzelnen Test. Im gemeinsamen `xcodebuild
    /// test`-Lauf startet `RestockUITests` direkt nach dieser Klasse und fand den geseedeten
    /// Laden „Lidl" samt sechs Artikeln vor; `testAddStoreAndQuickAddItemShowsPriceWithoutCrash`
    /// fiel daraufhin durch. Auf leerem Gerät ist derselbe Test grün — der Unterschied ist
    /// allein der liegengebliebene Seed. Das Aufräumen gehört deshalb hierher, zu dem Test,
    /// der die Daten anlegt, nicht in die fremde Testklasse.
    override func tearDown() {
        super.tearDown()
        // Dunkelmodus-Tests stellen das Gerät um — zurücksetzen, sonst erbt ihn der nächste Test.
        XCUIDevice.shared.appearance = .light
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearReceiptReviewSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

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
    ///
    /// 30 s statt 20 s: Im RED-Lauf zu #23 fiel der jeweils ERSTE Test der Klasse durch, weil
    /// beim kalten Install schon das Hochfahren die Wartezeit aufbrauchte (35,9 s Gesamtdauer,
    /// Fehler „Sheet ist nicht erschienen", während alle folgenden Tests das Sheet in unter
    /// 5 s sahen). Der Fehlschlag lag am Startzeitpunkt, nicht an der Sache.
    private func waitUntilSettled(_ app: XCUIApplication) {
        let isForeground = NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue)
        expectation(for: isForeground, evaluatedWith: app)
        waitForExpectations(timeout: 30)
    }

    /// Öffnet den Prüf-Screen und gibt die laufende App zurück.
    private func openedReviewSheet(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchedApp()
        waitUntilSettled(app)
        XCTAssertTrue(app.navigationBars["Bon scannen — Lidl"].waitForExistence(timeout: 30),
                      "Das Bon-Prüf-Sheet ist nicht erschienen — Seed oder Handoff greift nicht.",
                      file: file, line: line)
        return app
    }

    /// Sucht ein Element allein über seine Kennung, unabhängig vom Elementtyp.
    ///
    /// SwiftUI bildet dieselbe Karte je nach Fassung als `button`, `other` oder `staticText`
    /// ab — ein typgebundener Zugriff (`app.buttons[…]`) würde am Typ scheitern statt an der
    /// Sache. Geprüft wird die Kennung aus der Spec-Tabelle, nicht der Elementtyp.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Apples Währungsformatierer setzt je nach OS-Version U+00A0/U+202F vor das „€" —
    /// für einen Textvergleich auf ein normales Leerzeichen normalisieren.
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
    }

    /// Leert ein Textfeld über die Löschtaste und tippt den neuen Wert.
    ///
    /// Erst auf den Tastaturfokus warten, dann tippen (Issue #32): ohne dieses Warten scheitert
    /// die Eingabe sporadisch mit „Neither element nor any descendant has keyboard focus".
    private func replaceText(_ field: XCUIElement, with newValue: String, timeout: TimeInterval = 10) {
        field.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: timeout)
        let existing = (field.value as? String) ?? ""
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(newValue)
    }

    /// Tippt ein Element an und scrollt es vorher, falls nötig, in den Sichtbereich.
    ///
    /// Vier Karten mit je bis zu vier Auswahlzeilen sind höher als der Bildschirm — die letzte
    /// Position existiert im Bedienhilfen-Baum (alle Karten liegen in EINER Listenzeile, siehe
    /// Kommentar in `ReceiptScannerView.reviewView`), ist aber nicht antippbar, solange sie
    /// unter dem Rand liegt. Nur Erreichbarkeit, keine Prüfung: Wird das Element nie
    /// antippbar, schlägt der Test mit klarer Meldung fehl statt mit „failed to scroll".
    private func tapScrollingIntoView(
        _ app: XCUIApplication,
        _ target: XCUIElement,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(description) fehlt.", file: file, line: line)
        var swipes = 0
        while !target.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(target.isHittable,
                      "\(description) ist auch nach \(swipes) Wischern nicht antippbar.",
                      file: file, line: line)
        target.tap()
    }

    /// Holt ein nach oben weggescrolltes Element zurück in den Bedienhilfen-Baum.
    ///
    /// Die `List` wirft ihren Abschnittskopf aus dem Baum, sobald er weit genug nach oben
    /// gescrollt ist — ein Zugriff auf `label` scheitert dann mit „No matches found", obwohl die
    /// Kopfzeile sehr wohl existiert. Es wird nur so weit zurückgewischt, bis sie wieder da ist,
    /// nicht bis zum Anschlag: Ein Wisch nach unten am oberen Listenende würde das Sheet zuziehen.
    private func scrollBackUntilFound(
        _ app: XCUIApplication,
        _ target: XCUIElement,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var swipes = 0
        while !target.exists && swipes < 6 {
            app.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(target.exists,
                      "\(description) ist nach \(swipes) Wischern nach oben nicht wieder auffindbar.",
                      file: file, line: line)
    }

    /// Wartet, bis ein Element den erwarteten Textbaustein zeigt — und nennt im Fehlerfall den
    /// tatsächlich gefundenen Text.
    ///
    /// Bewusst statt `expectation(for:)`: Deren Fehlermeldung nennt nur das unerfüllte Prädikat,
    /// nicht den erreichten Zustand. Bei einer Kopfzeile wie „4 Positionen · 2 ausgewählt · …"
    /// ist gerade dieser Zustand die Information, die den Fehler erklärt.
    private func waitUntilLabel(
        of element: XCUIElement,
        contains fragment: String,
        timeout: TimeInterval = 8,
        what: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if labelOf(element, contains: fragment, within: timeout) { return }
        XCTFail("\(what): erwartet wurde \(fragment), angezeigt wird \(element.label)", file: file, line: line)
    }

    /// Wie `waitUntilLabel`, nur als Abfrage ohne Urteil.
    private func labelOf(_ element: XCUIElement, contains fragment: String, within timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label.localizedCaseInsensitiveContains(fragment) { return true }
            usleep(200_000)
        }
        return false
    }

    /// Tippt genau die MITTE eines Elements an.
    ///
    /// `XCUIElement.tap()` tippt nicht die Mitte, sondern einen von XCUITest berechneten
    /// „hittable point" — der darf auf einen Rand ausweichen. Genau das verdeckte die
    /// Regression zu #23: Das Häkchen war im abgewählten Zustand nur noch auf seinem 1,5 pt
    /// dünnen Rahmen antippbar, ein Tipp in die Mitte fiel ins Leere. Ein Test, der das
    /// beweisen soll, muss deshalb die Mitte treffen und nicht den Rand.
    private func tapCenter(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Anteil der Bildpunkte eines Elements, die dunkler als 50 % Helligkeit sind.
    ///
    /// Das ist die einzige von außen belastbare Messung des Dimmens: Deckkraft steht in keiner
    /// Bedienhilfen-Eigenschaft. Im Hellmodus ist die Schrift (`Color.ink`, Helligkeit ≈ 0,11)
    /// auf der Kartenfläche (`Color.surface`, ≈ 0,98) klar unter der Schwelle; bei 40 %
    /// Deckkraft mischt sie sich auf ≈ 0,64 und liegt damit eindeutig darüber. Der Anteil
    /// dunkler Punkte fällt also von „Schrift vorhanden" auf „praktisch keine" — gemessen an
    /// den echten Bildpunkten des Bildschirms, nicht an einem Ersatzmerkmal.
    private func darkPixelShare(of element: XCUIElement) -> Double {
        guard let cgImage = element.screenshot().image.cgImage else { return -1 }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return -1 }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var dark = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (0.299 * Double(pixels[offset])
                             + 0.587 * Double(pixels[offset + 1])
                             + 0.114 * Double(pixels[offset + 2])) / 255
            if luminance < 0.5 { dark += 1 }
        }
        return Double(dark) / Double(width * height)
    }

    // MARK: - Grundgerüst (#28, auf den Karten-Aufbau nachgezogen)

    /// Der Prüf-Screen erscheint von selbst und trägt alle vier Bon-Positionen als Karte.
    ///
    /// Dass „Speichern" bedienbar ist, ist kein Beiwerk, sondern der Beweis, dass die
    /// Ladenerkennung gegriffen hat: `canSave` bleibt gesperrt, solange der Laden nicht
    /// sicher erkannt wurde (`storeNeedsConfirmation`).
    func testReviewSheetOpensFromShareHandoff() {
        let app = openedReviewSheet()

        for index in Seed.rawTexts.indices {
            XCTAssertTrue(element(app, "receiptReview.line.\(index).card").waitForExistence(timeout: 5),
                          "Zeile \(index): Karte fehlt.")
            XCTAssertTrue(element(app, "receiptReview.line.\(index).price").exists,
                          "Zeile \(index): Preiszeile fehlt.")
            XCTAssertTrue(element(app, "receiptReview.line.\(index).checkbox").exists,
                          "Zeile \(index): Häkchen fehlt.")
        }

        XCTAssertTrue(element(app, "receiptReview.line.\(Seed.aiLine).aiMark").exists,
                      "Zeile \(Seed.aiLine) ist als KI-aufgelöst geseedet, trägt aber keine KI-Marke.")

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        XCTAssertTrue(saveButton.isHittable,
                      "Speichern ist gesperrt — der Laden wurde nicht sicher erkannt.")
    }

    // MARK: - AC1: Bontext sichtbar und vollständig

    /// AC1 — der gedruckte Bontext steht auf jeder Karte, unverändert und ungekürzt.
    ///
    /// Das ist die Kernbeschwerde aus Issue #23: Bei „Fisch 1,99" und „Fisch 7,99" war nicht
    /// erkennbar, welche Bon-Zeile gemeint ist. Geprüft wird deshalb nicht nur Existenz,
    /// sondern Zeichengleichheit mit dem gesäten Rohtext — inklusive der 42 Zeichen langen
    /// Hackfleisch-Zeile, an der die heutige Darstellung abschneiden würde.
    func testOriginalReceiptTextIsVisibleOnEveryLine() {
        let app = openedReviewSheet()

        for (index, rawText) in Seed.rawTexts.enumerated() {
            let textElement = element(app, "receiptReview.line.\(index).originalName")
            XCTAssertTrue(textElement.waitForExistence(timeout: 5),
                          "Zeile \(index): Bontext wird nicht angezeigt.")
            XCTAssertEqual(textElement.label, rawText,
                           "Zeile \(index): Bontext weicht vom gedruckten Text ab (abgeschnitten oder umformatiert).")
            XCTAssertFalse(textElement.label.contains("…"),
                           "Zeile \(index): Bontext ist mit Auslassungszeichen gekürzt.")
        }
    }

    // MARK: - AC3: KI-Marke einzeilig

    /// AC3 — die Pille „KI-Vorschlag" bricht nicht mehr um.
    ///
    /// Im Screenshot zu #23 brach sie in vier Zeilen (KI-/Vor/sch/lag). Die Marke ist
    /// 10 pt groß mit je 2 pt Innenabstand oben/unten, einzeilig also rund 18 pt hoch; zwei
    /// Zeilen wären bereits über 28 pt. Die Grenze von 26 pt trennt beide Fälle eindeutig.
    /// Zusätzlich muss die Pille breiter als hoch sein — der Vierfach-Umbruch machte sie
    /// schmal und hoch.
    func testAiMarkStaysOnOneLine() {
        let app = openedReviewSheet()

        let mark = element(app, "receiptReview.line.\(Seed.aiLine).aiMark")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "KI-Marke an der KI-Optionszeile fehlt.")
        XCTAssertLessThan(mark.frame.height, 26,
                          "KI-Marke ist \(mark.frame.height) pt hoch — sie bricht um statt einzeilig zu bleiben.")
        XCTAssertGreaterThan(mark.frame.width, mark.frame.height,
                             "KI-Marke ist höher als breit — typisches Bild des Wort-für-Wort-Umbruchs aus #23.")
    }

    // MARK: - AC2: höchstens vier Auswahlzeilen

    /// AC2 — eine Karte bietet höchstens drei inhaltliche Namen plus „Anderer Name …".
    ///
    /// Geprüft an der Zeile mit drei Listen-Treffern: Option 0 bis 3 existieren, Option 4
    /// existiert nicht. Heute gibt es überhaupt keine Auswahlzeilen, sondern ein Textfeld mit
    /// seitlich weglaufenden Vorschlags-Chips — der Test schlägt deshalb an Option 0 fehl.
    func testCardShowsAtMostFourSelectionOptions() {
        let app = openedReviewSheet()

        for option in 0...3 {
            XCTAssertTrue(
                element(app, "receiptReview.line.\(Seed.suggestionLine).option.\(option)").waitForExistence(timeout: 5),
                "Auswahlzeile \(option) fehlt an der Karte mit drei Listen-Treffern.")
        }
        XCTAssertFalse(
            element(app, "receiptReview.line.\(Seed.suggestionLine).option.4").exists,
            "Die Karte zeigt mehr als vier Auswahlzeilen — die Kappung auf drei inhaltliche Optionen greift nicht.")
    }

    // MARK: - AC5: Listen-Treffer wählen

    /// AC5 — Antippen einer Treffer-Zeile wählt sie aus und macht das sichtbar.
    ///
    /// Die Auswahl IST der Name dieser Position (Variante B, „Auswahl statt Tippen") — es gibt
    /// keine zweite Stelle, an der der gewählte Name stünde. Von außen prüfbar ist sie deshalb
    /// nur über den Auswahl-Zustand der Zeile: die gewählte Optionszeile muss das
    /// Bedienhilfen-Merkmal „ausgewählt" tragen.
    func testTappingListMatchSelectsThatOption() {
        let app = openedReviewSheet()

        // Option 0 ist seit Issue #37 der geltende Name "Milch" (Regel 5 — keiner der drei
        // Treffer entspricht ihm, deshalb vorausgewählte Zusatzzeile). Buttermilch rückt dadurch
        // von Option 1 auf Option 2.
        let option = element(app, "receiptReview.line.\(Seed.suggestionLine).option.2")
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Dritte Auswahlzeile fehlt.")
        XCTAssertTrue(option.label.contains(Seed.secondSuggestion),
                      "Dritte Auswahlzeile trägt nicht den erwarteten Treffer \(Seed.secondSuggestion).")
        option.tap()

        XCTAssertTrue(option.isSelected,
                      "Die angetippte Zeile ist danach nicht als ausgewählt gekennzeichnet.")
        XCTAssertFalse(element(app, "receiptReview.line.\(Seed.suggestionLine).option.0").isSelected,
                       "Die zuvor gewählte Zeile ist weiterhin als ausgewählt gekennzeichnet — es ist keine Einfachauswahl.")
    }

    // MARK: - AC7: eigener Name

    /// AC7 — „Anderer Name …" öffnet ein sofort beschreibbares Feld an dieser Karte.
    ///
    /// Die letzte Auswahlzeile ist immer „Anderer Name …"; an der KI-Zeile ohne Treffer ist das
    /// Option 1 (KI-Vorschlag + eigener Name).
    func testCustomNameOptionOpensFocusedTextField() {
        let app = openedReviewSheet()

        let customOption = element(app, "receiptReview.line.\(Seed.aiLine).option.1")
        XCTAssertTrue(customOption.waitForExistence(timeout: 5), "Auswahlzeile für den eigenen Namen fehlt.")
        customOption.tap()

        let field = app.textFields["receiptReview.line.\(Seed.aiLine).customNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Textfeld für den eigenen Namen erscheint nicht.")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
    }

    /// AC7 / Expected Behavior 3 — jeder Tastenanschlag im Feld „Anderer Name" wirkt sofort.
    ///
    /// Die Spec verlangt „jede Eingabe wird laufend übernommen (kein separater
    /// ‚Übernehmen'-Schritt)". Geprüft wird das MITTEN im Wort und ohne jede Bestätigung: Die
    /// Tastatur bleibt offen, es wird nichts anderes angetippt, keine Eingabetaste gedrückt.
    /// Der Nachweis läuft über das Bedienhilfen-Label des Häkchens, das den Namen nennt, unter
    /// dem die Position gespeichert wird (`line.name`) — der Feldinhalt selbst wäre kein
    /// Beweis, weil er auch bei einer erst am Ende übernommenen Eingabe schon dort stünde.
    func testTypingCustomNameIsAppliedWithEveryKeystroke() {
        let app = openedReviewSheet()
        let line = Seed.aiLine

        let checkbox = element(app, "receiptReview.line.\(line).checkbox")
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5), "Häkchen der KI-Zeile fehlt.")
        XCTAssertTrue(checkbox.label.contains(Seed.aiLineName),
                      "Vorbedingung: Das Häkchen nennt nicht den bisherigen Namen der Position — "
                      + "bekommen: \(checkbox.label)")

        let customOption = element(app, "receiptReview.line.\(line).option.1")
        XCTAssertTrue(customOption.waitForExistence(timeout: 5), "Auswahlzeile für den eigenen Namen fehlt.")
        customOption.tap()

        let field = app.textFields["receiptReview.line.\(line).customNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Textfeld für den eigenen Namen erscheint nicht.")
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)

        // Das Feld ist mit dem bisherigen Namen vorbelegt — leeren, ohne es zu verlassen.
        let existing = (field.value as? String) ?? ""
        if !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }

        // Erste Hälfte des Wortes: schon jetzt, mitten in der Eingabe, muss der Name stehen.
        field.typeText("Ziegen")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Ziegen"), evaluatedWith: checkbox)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(checkbox.label.contains(Seed.aiLineName),
                       "Der alte Name steht noch an der Position — die Eingabe wurde nicht übernommen: \(checkbox.label)")

        // Zweite Hälfte, weiterhin ohne Bestätigung — die Übernahme läuft mit.
        field.typeText("milch")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Ziegenmilch"), evaluatedWith: checkbox)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(app.keyboards.firstMatch.exists,
                      "Die Tastatur ist zu — dann wurde die Eingabe abgeschlossen und der Nachweis "
                      + "der laufenden Übernahme ist keiner mehr.")
    }

    // MARK: - AC9: Preis und Menge ändern

    /// AC9 — „Ändern" öffnet Preis- und Mengenfeld; beide wirken sofort auf die Preiszeile.
    ///
    /// Geprüft wird die Zeile mit 0,99 € und einem Stück: neuer Preis 2,00 € muss in der
    /// Preiszeile erscheinen, nach Umschalten auf „Stück" und Eingabe 4 muss dort „4 St." und
    /// der daraus berechnete Stückpreis 0,50 € stehen — genau die Basis, mit der die App den
    /// Preis lernt.
    func testChangeOpensPriceAndQuantityEditorAndUpdatesSummary() {
        let app = openedReviewSheet()
        let line = Seed.suggestionLine

        let changeButton = element(app, "receiptReview.line.\(line).changeButton")
        XCTAssertTrue(changeButton.waitForExistence(timeout: 5), "Knopf zum Ändern fehlt an der Preiszeile.")
        changeButton.tap()

        let priceField = app.textFields["receiptReview.line.\(line).priceField"]
        let quantityField = app.textFields["receiptReview.line.\(line).quantityField"]
        let modeSwitch = element(app, "receiptReview.line.\(line).quantityMode")
        XCTAssertTrue(priceField.waitForExistence(timeout: 5), "Preisfeld erscheint nach dem Ändern nicht.")
        XCTAssertTrue(quantityField.exists, "Mengenfeld erscheint nach dem Ändern nicht.")
        XCTAssertTrue(modeSwitch.exists, "Umschalter Stück/Gramm erscheint nach dem Ändern nicht.")

        replaceText(priceField, with: "2,00")
        let summary = element(app, "receiptReview.line.\(line).price")
        XCTAssertTrue(normalized(summary.label).contains("2,00 €"),
                      "Preiszeile zeigt den neuen Preis nicht: \(summary.label)")

        modeSwitch.buttons["Stück"].tap()
        replaceText(quantityField, with: "4")
        let updated = normalized(summary.label)
        XCTAssertTrue(updated.contains("4 St."),
                      "Preiszeile zeigt die neue Stückzahl nicht: \(updated)")
        XCTAssertTrue(updated.contains("0,50 €"),
                      "Preiszeile zeigt den neuen Stückpreis nicht: \(updated)")
    }

    // MARK: - AC10/AC11: Kopfzeile

    /// AC11 — die Kopfzeile nennt Anzahl, Auswahl und Summe des gesäten Bons.
    func testSectionHeaderShowsPositionsSelectedAndSum() {
        let app = openedReviewSheet()

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Kopfzeile über den Positionen fehlt.")
        XCTAssertEqual(normalized(header.label).lowercased(),
                       "4 positionen · 4 ausgewählt · 8,73 €",
                       "Kopfzeile zeigt nicht Anzahl, Auswahl und Summe für den gesäten Bon.")
    }

    /// AC10 — Häkchen abwählen senkt Zähler und Summe um genau diese Position.
    ///
    /// Die KI-Zeile kostet 1,19 €; aus 8,73 € werden 7,54 €.
    func testUncheckingCardLowersSelectedCountAndSum() {
        let app = openedReviewSheet()

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Kopfzeile über den Positionen fehlt.")

        let checkbox = element(app, "receiptReview.line.\(Seed.aiLine).checkbox")
        XCTAssertTrue(checkbox.exists, "Häkchen der KI-Zeile fehlt.")
        checkbox.tap()

        let expected = "4 positionen · 3 ausgewählt · 7,54 €"
        expectation(for: NSPredicate(format: "label CONTAINS[c] %@", "3 ausgewählt"), evaluatedWith: header)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(normalized(header.label).lowercased(), expected,
                       "Kopfzeile nach dem Abwählen falsch — erwartet: \(expected)")
    }

    /// AC10, erste Hälfte — die abgewählte Karte dimmt sich sichtbar, und zwar beide Wege.
    ///
    /// Gemessen an den echten Bildpunkten der Preiszeile: Die Karte legt 40 % Deckkraft über
    /// ihren Inhalt, sobald das Häkchen aus ist. Deckkraft ist über die Bedienhilfen-
    /// Schnittstelle nicht abfragbar (kein Merkmal, kein Wert) — ein Ersatzmerkmal („Häkchen
    /// ist aus") würde dagegen nur den Auslöser prüfen, nicht die Wirkung, die der PO sieht.
    /// Deshalb der Bildpunkt-Vergleich; die Zahlen dahinter stehen an `darkPixelShare`.
    /// Bewusst im Hellmodus, wo Schrift dunkel auf heller Fläche steht.
    ///
    /// NICHT geprüft: das Aufhellen beim Wiederanwählen. Ein Tipp in die Mitte eines
    /// abgewählten Häkchens bleibt heute wirkungslos (`Color.clear`-Füllung, siehe Befund zum
    /// Häkchen in `ReceiptReviewCard.checkbox`); ein Tipp auf den 1,5 pt dünnen Rahmen wirkt.
    /// Solange das so ist, wäre jeder Test der Gegenrichtung ein Test der Umgehung, nicht des
    /// Verhaltens — die Lücke ist gemeldet, statt hier festgeschrieben zu werden.
    func testUncheckingCardDimsItVisibly() {
        XCUIDevice.shared.appearance = .light
        let app = openedReviewSheet()
        let line = Seed.aiLine

        let priceRow = element(app, "receiptReview.line.\(line).price")
        XCTAssertTrue(priceRow.waitForExistence(timeout: 5), "Preiszeile der KI-Zeile fehlt.")
        let inked = darkPixelShare(of: priceRow)
        XCTAssertGreaterThan(inked, 0.02,
                             "Messung untauglich: In der Preiszeile steht kaum dunkle Schrift "
                             + "(Anteil \(inked)) — ohne sie kann das Dimmen nicht gemessen werden.")

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.exists, "Kopfzeile über den Positionen fehlt.")
        let checkbox = element(app, "receiptReview.line.\(line).checkbox")
        XCTAssertTrue(checkbox.exists, "Häkchen der KI-Zeile fehlt.")
        tapCenter(of: checkbox)
        waitUntilLabel(of: header, contains: "3 ausgewählt", what: "Kopfzeile nach dem Abwählen")

        let dimmed = darkPixelShare(of: priceRow)
        XCTAssertLessThan(dimmed, inked * 0.25,
                          "Die abgewählte Karte ist nicht sichtbar gedimmt — dunkle Bildpunkte "
                          + "vorher \(inked), nachher \(dimmed).")

        // Gegenrichtung: Wiederanwählen hellt die Karte wieder auf. Ohne diese Prüfung bliebe
        // eine Einbahnstraße unbemerkt — im abgewählten Zustand war das Häkchen nur noch auf
        // seinem Rahmen antippbar, ein Tipp in die MITTE folgenlos.
        tapCenter(of: checkbox)
        waitUntilLabel(of: header, contains: "4 ausgewählt", what: "Kopfzeile nach dem Wiederanwählen")
        let restored = darkPixelShare(of: priceRow)
        XCTAssertGreaterThan(restored, inked * 0.75,
                             "Die wieder angewählte Karte ist nicht wieder aufgehellt — dunkle "
                             + "Bildpunkte am Anfang \(inked), nach dem Wiederanwählen \(restored).")
    }

    // MARK: - Speichern erst ab einer Auswahl (Expected Behavior, letzter Punkt)

    /// Ohne eine einzige ausgewählte Position darf „Speichern" nicht auslösbar sein — mit einer
    /// wieder.
    ///
    /// Das ist die Bedingung `canSave` (`ReceiptScannerView.swift:220`) aus Nutzersicht: Ein
    /// Bon, an dem alles abgewählt ist, hat nichts zu speichern; ein auslösbarer Knopf würde
    /// den Screen kommentarlos schließen und den Bon verwerfen, ohne dass etwas gelernt wurde.
    /// Geprüft werden beide Seiten der Grenze, damit der Test nicht schon dadurch grün wäre,
    /// dass der Knopf immer gesperrt ist: mit GENAU EINER Position offen, mit keiner gesperrt.
    /// Die Kopfzeile dient als Nachweis, dass wirklich der gedachte Zustand vorliegt — sonst
    /// prüfte der Test einen anderen als den beschriebenen Fall.
    func testSaveIsNotTriggerableWithoutAnySelectedPosition() {
        let app = openedReviewSheet()

        let header = element(app, "receiptReview.sectionHeader")
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Kopfzeile über den Positionen fehlt.")
        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        XCTAssertTrue(saveButton.isEnabled,
                      "Vorbedingung: Mit allen vier Positionen ausgewählt muss Speichern offen sein.")

        // Erst DREI der vier Positionen abwählen: An der Grenze „genau eine ausgewählt" muss
        // Speichern offen bleiben — sonst wäre die Sperre unten kein Beweis, sondern nur der
        // Normalzustand eines immer gesperrten Knopfes.
        for index in 0..<(Seed.rawTexts.count - 1) {
            tapScrollingIntoView(app, element(app, "receiptReview.line.\(index).checkbox"),
                                 description: "Häkchen der Zeile \(index)")
        }
        scrollBackUntilFound(app, header, description: "Kopfzeile")
        waitUntilLabel(of: header, contains: "1 ausgewählt",
                       what: "Kopfzeile nach dem Abwählen der ersten drei Positionen")
        XCTAssertEqual(normalized(header.label).lowercased(),
                       "4 positionen · 1 ausgewählt · \(Seed.lastLinePriceText)".lowercased(),
                       "Es liegt nicht der gedachte Zustand vor (genau eine Position ausgewählt).")
        XCTAssertTrue(saveButton.isEnabled,
                      "Mit einer ausgewählten Position muss Speichern offen sein — sonst ließe sich "
                      + "ein Bon mit nur einer geprüften Position nie speichern.")

        // Jetzt die letzte: Ab hier gibt es nichts mehr zu speichern.
        tapScrollingIntoView(app, element(app, "receiptReview.line.\(Seed.lastLine).checkbox"),
                             description: "Häkchen der letzten Zeile")
        scrollBackUntilFound(app, header, description: "Kopfzeile")
        waitUntilLabel(of: header, contains: "0 ausgewählt",
                       what: "Kopfzeile nach dem Abwählen aller Positionen")
        XCTAssertEqual(normalized(header.label).lowercased(), "4 positionen · 0 ausgewählt · 0,00 €",
                       "Es liegt nicht der gedachte Zustand vor (keine Position ausgewählt).")

        XCTAssertFalse(saveButton.isEnabled,
                       "Speichern ist ohne ausgewählte Position weiterhin freigegeben.")

        // `isHittable` ist hier kein Signal: SwiftUI hält einen per `.disabled(true)` gesperrten
        // Knopf weiter sichtbar und damit geometrisch antippbar (im Lauf vom 23.09. nachgemessen).
        // Also wird wirklich getippt — und der Tipp MUSS folgenlos bleiben. Das ist der eigentliche
        // Nutzen-Nachweis: Der Prüf-Screen bleibt offen, statt den Bon ohne eine einzige geprüfte
        // Position abzuschließen. Wäre der Knopf auslösbar, wäre das Sheet nach `save()` weg
        // (der AC12-Test unten sieht den Home-Screen in gut einer Sekunde).
        saveButton.tap()
        let reviewBar = app.navigationBars["Bon scannen — Lidl"]
        XCTAssertFalse(reviewBar.waitForNonExistence(timeout: 3),
                       "Der Tipp auf das gesperrte Speichern hat den Prüf-Screen geschlossen — ohne "
                       + "eine einzige ausgewählte Position hätte er nichts abzuschließen.")
        XCTAssertTrue(normalized(header.label).lowercased().contains("0 ausgewählt"),
                      "Nach dem Tipp auf das gesperrte Speichern zeigt die Kopfzeile: \(header.label)")

        // Gegenrichtung: Eine Position wieder anwählen gibt Speichern wieder frei — sonst wäre der
        // Bon nach einem Fehlgriff endgültig unspeicherbar. Der Tipp geht in die MITTE des
        // Häkchens, nicht auf seinen Rahmen: auf dem Rahmen war das abgewählte Häkchen auch vor
        // dem Fix schon antippbar, in der Mitte nicht.
        let firstCheckbox = element(app, "receiptReview.line.0.checkbox")
        XCTAssertTrue(firstCheckbox.exists, "Häkchen der ersten Zeile fehlt.")
        tapCenter(of: firstCheckbox)
        waitUntilLabel(of: header, contains: "1 ausgewählt", what: "Kopfzeile nach dem Wiederanwählen")
        XCTAssertTrue(saveButton.isEnabled,
                      "Nach dem Wiederanwählen einer Position ist Speichern weiter gesperrt — das "
                      + "Häkchen lässt sich also nur abwählen, nicht wieder anwählen.")
    }

    // MARK: - AC12: Speichern unverändert

    /// AC12 — Speichern schreibt den erkannten Preis weiterhin an den zugeordneten Artikel.
    ///
    /// Regressionsschutz für den unveränderten `save()`-Pfad: Die Zeile „MILCH" ist dem Artikel
    /// „Milch" zugeordnet und kostet 0,99 €; nach dem Speichern muss dieser Betrag in der
    /// Lidl-Liste am Artikel stehen. Vor dem Speichern hat der gesäte Artikel keinen Preis.
    func testSavingStillWritesLearnedPriceToMatchedItem() {
        let app = openedReviewSheet()

        let saveButton = app.buttons["receiptReview.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern-Knopf fehlt.")
        saveButton.tap()

        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        XCTAssertTrue(lidlTile.waitForExistence(timeout: 10), "Nach dem Speichern ist der Home-Screen nicht sichtbar.")
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: lidlTile)
        waitForExpectations(timeout: 5)
        lidlTile.tap()

        XCTAssertTrue(app.staticTexts[Seed.matchedItemName].waitForExistence(timeout: 10),
                      "Artikel \(Seed.matchedItemName) nicht in der Lidl-Liste gefunden.")
        let priceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "0,99")).firstMatch
        XCTAssertTrue(priceText.waitForExistence(timeout: 5),
                      "Der gespeicherte Preis \(Seed.matchedItemPriceText) steht nicht am Artikel — save() schreibt ihn nicht mehr.")
    }

    // MARK: - Dunkelmodus (der im Issue-Screenshot reproduzierte Fall)

    /// AC1 + AC3 im Dunkelmodus — der Screenshot zu #23 stammt genau daher.
    func testOriginalTextAndAiMarkAreReadableInDarkMode() {
        XCUIDevice.shared.appearance = .dark
        let app = openedReviewSheet()

        let longText = element(app, "receiptReview.line.1.originalName")
        XCTAssertTrue(longText.waitForExistence(timeout: 5), "Dunkelmodus: Bontext der langen Zeile fehlt.")
        XCTAssertEqual(longText.label, Seed.rawTexts[1],
                       "Dunkelmodus: Bontext der langen Zeile ist gekürzt oder verändert.")

        let mark = element(app, "receiptReview.line.\(Seed.aiLine).aiMark")
        XCTAssertTrue(mark.exists, "Dunkelmodus: KI-Marke fehlt.")
        XCTAssertLessThan(mark.frame.height, 26,
                          "Dunkelmodus: KI-Marke ist \(mark.frame.height) pt hoch — sie bricht um.")
    }

    /// AC9 im Dunkelmodus — Preis- und Mengenfeld müssen auch dort erscheinen und wirken.
    func testChangeEditorWorksInDarkMode() {
        XCUIDevice.shared.appearance = .dark
        let app = openedReviewSheet()
        let line = Seed.suggestionLine

        let changeButton = element(app, "receiptReview.line.\(line).changeButton")
        XCTAssertTrue(changeButton.waitForExistence(timeout: 5), "Dunkelmodus: Knopf zum Ändern fehlt.")
        changeButton.tap()

        let priceField = app.textFields["receiptReview.line.\(line).priceField"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5), "Dunkelmodus: Preisfeld erscheint nicht.")
        XCTAssertTrue(app.textFields["receiptReview.line.\(line).quantityField"].exists,
                      "Dunkelmodus: Mengenfeld erscheint nicht.")

        replaceText(priceField, with: "3,50")
        let summary = element(app, "receiptReview.line.\(line).price")
        XCTAssertTrue(normalized(summary.label).contains("3,50 €"),
                      "Dunkelmodus: Preiszeile zeigt den neuen Preis nicht: \(summary.label)")
    }
}
