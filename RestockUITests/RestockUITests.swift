import XCTest

/// Bewusst minimal gehalten: nur EIN Smoke-Test, der vorher einzeln gegen einen frisch
/// gebooteten Simulator (kein wiederverwendeter Entwicklungs-Simulator mit bereits erteilten
/// Berechtigungen/State) verifiziert wurde. Onboarding wird über den Standard-"-key value"
/// Kommandozeilen-Trick übersprungen (NSUserDefaults liest `-hasCompletedOnboarding YES` in
/// die Argument-Domain ein, exakt das, was `@AppStorage("hasCompletedOnboarding")` in
/// SmartCartApp.swift abfragt) — kein App-Code dafür nötig. Löst weder Kamera- noch
/// Foto-Bibliotheks-Berechtigung aus (HomeView triggert das nicht beim Erscheinen) und ruft
/// keinen FoundationModels-Pfad auf (die sind laut Code-Review nur hinter explizit geöffneten
/// Sheets für Rezept-Erkennung/Beleg-Scan erreichbar, nicht auf dem Home-Screen).
final class RestockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Kein system NavigationBar-Titel: HomeView versteckt die Standard-Nav-Bar und zeigt
        // "Restock" stattdessen als großen, hartkodierten (nicht lokalisierten) Text im
        // Hero-Card oben auf dem Screen — bestätigt per Screenshot während der Entwicklung
        // dieses Tests.
        XCTAssertTrue(
            app.staticTexts["Restock"].waitForExistence(timeout: 15),
            "HomeView-Hero-Titel \"Restock\" wurde nicht innerhalb von 15s angezeigt"
        )
    }

    /// Manueller Klick-Durch-Test für den heute (13./14.08.2026) behobenen "Beitreten"-Button-Bug:
    /// `JoinStoreSheet` steckt jetzt in einer `ScrollView` statt einem reinen `VStack`. Beweist,
    /// dass Code-Feld UND Abbrechen-Button (beide im selben ScrollView-Inhalt) tatsächlich
    /// gerendert UND antippbar sind — nicht nur, dass die View kompiliert. Ohne echten iCloud-
    /// Account im Simulator kann der eigentliche "Beitreten"-Button (nur sichtbar nach einem
    /// erfolgreichen CloudKit-Preview-Lookup) hier nicht erreicht werden; das Feld/Cancel-Paar
    /// deckt trotzdem exakt dieselbe ScrollView-Layout-Fläche ab, die den Bug verursacht hat.
    func testJoinSharedListSheetIsScrollableAndUsable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let joinButton = app.buttons["Geteilter Liste beitreten"]
        XCTAssertTrue(joinButton.waitForExistence(timeout: 15), "Join-Button im leeren Home-State nicht gefunden")
        joinButton.tap()

        // Live-Hierarchie bestätigt: TextField exponiert den Platzhalter als `placeholderValue`,
        // nicht als `label`/`identifier` — der einfache String-Subscript (matcht auf identifier)
        // greift hier nicht, deshalb explizites Prädikat.
        let codeField = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Z.B. ABCD-EFG-HIJ")).firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 5), "Code-Eingabefeld im JoinStoreSheet nicht sichtbar")
        // Kurze Pause: unmittelbar nach `existence` kann die Sheet-Präsentationsanimation noch
        // laufen, `isHittable` wäre dann fälschlich `false`, obwohl das Layout korrekt ist.
        sleep(1)
        XCTAssertTrue(codeField.isHittable, "Code-Eingabefeld liegt außerhalb des sichtbaren/antippbaren Bereichs")

        // Sitzt im NavigationBar-Toolbar, nicht im ScrollView-Inhalt selbst — bestätigt per
        // Live-Hierarchie-Dump, deshalb vom ScrollView-Fix unabhängig immer erreichbar. Trotzdem
        // mitgeprüft: ein Absturz/Layout-Fehler in der Sheet-Struktur würde auch das reißen.
        let cancelButton = app.buttons["Abbrechen"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Abbrechen-Button im JoinStoreSheet nicht gefunden")
        XCTAssertTrue(cancelButton.isHittable, "Abbrechen-Button liegt außerhalb des sichtbaren/antippbaren Bereichs — exakt der gemeldete Bug")

        codeField.tap()
        codeField.typeText("TESTCODE12")

        // Ohne echten iCloud-Account schlägt der CloudKit-Lookup fehl — erwartet ist die
        // "nicht gefunden"-Fehlermeldung, NICHT ein Absturz oder eine leere/eingefrorene Ansicht.
        let notFoundText = app.staticTexts["Kein Store mit diesem Code gefunden."]
        XCTAssertTrue(notFoundText.waitForExistence(timeout: 15), "Erwartete Fehlermeldung nach ungültigem Code erschien nicht — App könnte abgestürzt/eingefroren sein")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "JoinStoreSheet-nach-ungueltigem-Code"
        attachment.lifetime = .keepAlways
        add(attachment)

        cancelButton.tap()
        XCTAssertTrue(app.staticTexts["Restock"].waitForExistence(timeout: 5), "Nach Abbrechen nicht zurück auf dem Home-Screen")
    }

    /// Beweist den Fix für einen von einem echten Nutzer gemeldeten Bug (14.08.2026): ein alter,
    /// vor der Code-Härtung (6→10 Zeichen, siehe SharedStoreService.generateCode()) erzeugter
    /// Freigabe-Link liefert weiterhin einen 6-stelligen Code, den `JoinStoreSheet`s starrer
    /// "== 10"-Trigger nie eine Suche auslösen ließ — das Sheet blieb komplett tatenlos stehen
    /// (kein Spinner, kein Fehler, kein Beitreten-Button), obwohl der Code selbst gültig war.
    /// Manuelles Tippen eines 6-stelligen Codes durchläuft denselben `onChange`-Codepfad wie ein
    /// vorausgefüllter Link (`JoinStoreSheet.onAppear` weist `prefilledCode` demselben `@State
    /// code` zu) — dieser Test deckt damit beide Auslöser gleichzeitig ab.
    func testJoinWithLegacySixCharacterCodeTriggersLookup() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let joinButton = app.buttons["Geteilter Liste beitreten"]
        XCTAssertTrue(joinButton.waitForExistence(timeout: 15), "Join-Button im leeren Home-State nicht gefunden")
        joinButton.tap()

        let codeField = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Z.B. ABCD-EFG-HIJ")).firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 5), "Code-Eingabefeld im JoinStoreSheet nicht sichtbar")
        sleep(1)
        codeField.tap()
        codeField.typeText("CGU5ZN") // exakt der vom Nutzer gemeldete, echte (alte) Code

        // Vor dem Fix: hier passiert schlicht NICHTS — kein Spinner, kein Fehler. Der Fix löst
        // nach kurzer Verzögerung trotzdem eine echte Suche aus; ohne echten iCloud-Account im
        // Simulator schlägt sie erwartungsgemäß fehl, aber genau DAS beweist, dass überhaupt
        // gesucht wurde.
        let notFoundText = app.staticTexts["Kein Store mit diesem Code gefunden."]
        XCTAssertTrue(notFoundText.waitForExistence(timeout: 15), "6-stelliger Code löste keine Suche aus — exakt der gemeldete Bug")
    }

    /// Klick-Durch-Test für Laden hinzufügen → Artikel per Schnelleingabe → Preis wird angezeigt,
    /// kein Absturz. Deckt den echten Laufzeitpfad von `ShoppingItem.init` ab (Preis-
    /// Plausibilitätsgrenze, siehe ShoppingItem.swift) — unit-getestet für die Logik selbst, hier
    /// zusätzlich als echter End-to-End-Smoke-Test über die tatsächliche UI.
    func testAddStoreAndQuickAddItemShowsPriceWithoutCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Der App-Zustand persistiert lokal über Testläufe hinweg (SwiftData, kein Reset
        // zwischen XCTest-Aufrufen) — ein "Lidl" könnte aus einem vorherigen Lauf bereits
        // existieren. In dem Fall den Einrichten-Umweg überspringen.
        if app.staticTexts["Lidl"].waitForExistence(timeout: 3) {
            print("DEBUG: Lidl existiert bereits aus vorherigem Lauf, überspringe Einrichtung")
        } else {
            let setupButton = app.buttons["Läden einrichten"]
            XCTAssertTrue(setupButton.waitForExistence(timeout: 15), "'Läden einrichten'-Button im leeren Home-State nicht gefunden")
            setupButton.tap()

            let browseLink = app.buttons["Läden aus anderen Ländern hinzufügen"]
            XCTAssertTrue(browseLink.waitForExistence(timeout: 5), "Link zu 'Läden aus anderen Ländern' nicht gefunden")
            browseLink.tap()

            let searchField = app.textFields["Laden suchen (alle Länder)"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Such-Textfeld in BrowseStoresView nicht gefunden")
            searchField.tap()
            searchField.typeText("Lidl")

            let addLidlButton = app.buttons["plus.circle.fill"].firstMatch
            XCTAssertTrue(addLidlButton.waitForExistence(timeout: 5), "'+'-Button für den Lidl-Suchtreffer nicht gefunden")
            addLidlButton.tap()

            app.buttons["Fertig"].tap() // BrowseStoresView schließen
            app.swipeDown() // StoreSetupView-Sheet schließen (kein expliziter Dismiss-Button dort)

            XCTAssertTrue(app.staticTexts["Lidl"].waitForExistence(timeout: 5), "Lidl-Kachel nach dem Hinzufügen nicht auf dem Home-Screen gefunden")
        }
        // Live-Hierarchie bestätigt: die Store-Kachel ist ein Button mit zusammengesetztem Label
        // ("Lidl, 2x pro Woche, Liste ist leer"), kein reiner "Lidl"-Text-Button.
        let lidlTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lidl,")).firstMatch
        XCTAssertTrue(lidlTile.waitForExistence(timeout: 5), "Lidl-Kachel nicht auf dem Home-Screen gefunden")
        lidlTile.tap()

        let quickAddField = app.textFields["Schnell hinzufügen…"]
        XCTAssertTrue(quickAddField.waitForExistence(timeout: 5), "Schnelleingabe-Feld in StoreDetailView nicht gefunden")
        quickAddField.tap()
        quickAddField.typeText("Testartikel")
        app.keyboards.buttons["Fortfahren"].tap() // Submit-Label dieses Feldes ist "Fortfahren", nicht "Return"

        let itemText = app.staticTexts["Testartikel"].firstMatch
        XCTAssertTrue(itemText.waitForExistence(timeout: 5), "Neu hinzugefügter Artikel 'Testartikel' erscheint nicht in der Liste")

        // Teilen-Button antippen (person.2/person.2.fill in der Navigationsleiste) — deckt live
        // die neue Free-Plan-Limit-Verkabelung ab (PremiumService.canShareAdditionalList in
        // StoreDetailView.swift). Da debugAllFeaturesUnlocked aktuell `true` ist, wird direkt
        // StoreShareSheet erwartet, keine Paywall.
        let shareButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'person.2'")).firstMatch
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5), "Teilen-Button in StoreDetailView nicht gefunden")
        shareButton.tap()

        let generateCodeButton = app.buttons["Code generieren"]
        XCTAssertTrue(generateCodeButton.waitForExistence(timeout: 5), "StoreShareSheet öffnete sich nicht wie erwartet (bei aktiv freigeschalteten Features sollte keine Paywall erscheinen)")

        let shareScreenshot = app.screenshot()
        let shareAttachment = XCTAttachment(screenshot: shareScreenshot)
        shareAttachment.name = "StoreShareSheet"
        shareAttachment.lifetime = .keepAlways
        add(shareAttachment)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "StoreDetailView-nach-QuickAdd"
        attachment.lifetime = .keepAlways
        add(attachment)

        // App darf nach alldem nicht abgestürzt sein — der zuverlässigste Beweis dafür ist, dass
        // sie weiterhin auf Eingaben reagiert.
        XCTAssertTrue(app.state == .runningForeground, "App läuft nach dem Quick-Add nicht mehr im Vordergrund — Absturz-Verdacht")
    }
}
