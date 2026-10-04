import XCTest

/// Schnell-Eingabe auf der Startseite: Ziel-Karte mit Grund, Bestätigungs-Toast und Umgang mit
/// Artikeln ohne Laden (Karte „Ohne Laden“ + Zuordnen-Sheet). Design: Canvas „Schnell hinzufügen –
/// Vorschläge“ (2026-10-02).
///
/// Seed (`SmartCartApp.seedQuickAddAssignmentForUITestsIfNeeded`): Läden „Lidl“ (Lebensmittel) und
/// „dm“ (Drogerie), keine Standard-Läden, keine gemerkten Korrekturen. Mit `-quickAddSeedStoreless`
/// zusätzlich zwei offene Artikel ohne Laden.
///
/// Die Tests prüfen die Bedienung über `accessibilityIdentifier`s (`quickAdd.*`, `home.unassignedCard`,
/// `unassigned.*`). Die Logik hinter dem Grund („4 von 5 Käufen“, Standard-Laden …) ist in
/// `AssignmentServiceTests` abgedeckt; hier geht es darum, dass der Nutzer sie sieht und bedienen kann.
final class QuickAddAssignmentUITests: XCTestCase {

    private static let placeholder = "Schnell hinzufügen…"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Der App-Group-Container überlebt den einzelnen Test (siehe CLAUDE.md).
    override func tearDown() {
        super.tearDown()
        let cleaner = XCUIApplication()
        cleaner.launchArguments = ["-hasCompletedOnboarding", "YES", "-clearQuickAddAssignmentSeedForUITests"]
        cleaner.launch()
        cleaner.terminate()
    }

    // MARK: - Hilfen

    private func launchedApp(storeless: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-seedQuickAddAssignmentForUITests"]
        if storeless { app.launchArguments.append("-quickAddSeedStoreless") }
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Tippt `text` in das Schnell-Eingabe-Feld der Startseite und wartet auf die Ziel-Karte.
    private func typeIntoQuickAdd(_ text: String, in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields[Self.placeholder]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Schnell-Eingabe-Feld nicht gefunden")
        field.tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        waitForExpectations(timeout: 10)
        field.typeText(text)
        XCTAssertTrue(element(app, "quickAdd.targetCard").waitForExistence(timeout: 5),
                      "Ziel-Karte erscheint nicht, obwohl Text eingegeben wurde")
        return field
    }

    private func labelOf(_ element: XCUIElement, contains text: String, within seconds: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: seconds) == .completed
    }

    private func tile(_ storeName: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(storeName),")).firstMatch
    }

    /// Öffnet die Liste des Ladens über die Kachel auf der Startseite.
    private func openStore(_ storeName: String, in app: XCUIApplication) {
        let t = tile(storeName, in: app)
        XCTAssertTrue(t.waitForExistence(timeout: 15), "Kachel „\(storeName)“ nicht gefunden")
        dismissKeyboard(in: app)
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: t)
        waitForExpectations(timeout: 10)
        t.tap()
    }

    /// Nach dem Hinzufügen bleibt die Tastatur offen (Nutzer kann weitertippen) und verdeckt die
    /// Ladenkacheln im unteren Teil der Startseite. Der Nutzer schließt sie mit der Taste „Fertig“
    /// bei leerem Feld — der Test tut dasselbe.
    private func dismissKeyboard(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let done = keyboard.buttons["Fertig"]
        if done.waitForExistence(timeout: 3) {
            done.tap()
        } else {
            app.textFields[Self.placeholder].typeText("\n")
        }
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: keyboard)
        waitForExpectations(timeout: 10)
    }

    private func closeStore(in app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Zeile der geöffneten Ladenliste (`List` → Cell). Trifft nicht die Ladenkachel, den Toast oder
    /// die Ziel-Karte der Startseite, die den Namen ebenfalls als Text zeigen.
    private func listRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    // MARK: - 2A: Ziel-Karte beim Tippen

    /// Beim Tippen steht sofort da, WOHIN der Artikel geht und WARUM — hier der einzige
    /// Lebensmittel-Laden.
    func testTypingShowsTargetStoreAndReason() {
        let app = launchedApp()
        _ = typeIntoQuickAdd("Nudeln", in: app)

        XCTAssertTrue(labelOf(element(app, "quickAdd.target"), contains: "Lidl"),
                      "Die Ziel-Zeile nennt den Laden nicht")
        let reason = element(app, "quickAdd.reason")
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "Der Grund der Zuordnung fehlt")
        XCTAssertTrue(labelOf(reason, contains: "Lebensmittel"),
                      "Der Grund nennt die Kategorie nicht — bekommen: \(reason.label)")
    }

    /// Ein Laden-Chip überschreibt das Ziel vor dem Hinzufügen; der Grund wird „Von dir gewählt“.
    func testStoreChipOverridesTarget() {
        let app = launchedApp()
        _ = typeIntoQuickAdd("Nudeln", in: app)

        let dmChip = element(app, "quickAdd.storeChip.dm")
        XCTAssertTrue(dmChip.waitForExistence(timeout: 5), "Chip „dm“ fehlt")
        dmChip.tap()

        XCTAssertTrue(labelOf(element(app, "quickAdd.target"), contains: "dm"),
                      "Das Ziel wechselt nach Tippen auf den Chip nicht auf „dm“")
        XCTAssertTrue(labelOf(element(app, "quickAdd.reason"), contains: "Von dir gewählt"),
                      "Der Grund zeigt nicht, dass der Nutzer gewählt hat")
        XCTAssertTrue(dmChip.isSelected, "Der gewählte Chip ist nicht als ausgewählt gekennzeichnet")
    }

    // MARK: - 2B: Bestätigung mit Ändern und Rückgängig

    /// Nach dem Hinzufügen nennt der Toast den Laden und bietet „Laden ändern“ und „Rückgängig“ an.
    func testToastNamesStoreAndOffersChangeAndUndo() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)
        field.typeText("\n")

        let toast = element(app, "quickAdd.toast")
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "Bestätigungs-Toast erscheint nicht")
        let message = element(app, "quickAdd.toast.message")
        XCTAssertTrue(labelOf(message, contains: "Lidl"), "Der Toast nennt den Laden nicht — bekommen: \(message.label)")
        XCTAssertTrue(element(app, "quickAdd.toast.change").exists, "„Laden ändern“ fehlt")
        XCTAssertTrue(element(app, "quickAdd.toast.undo").exists, "„Rückgängig“ fehlt")
    }

    /// „Rückgängig“ räumt den Toast ab und legt den Artikel nicht als Artikel ohne Laden ab.
    func testUndoRemovesToastAndItem() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)
        field.typeText("\n")

        let undo = element(app, "quickAdd.toast.undo")
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "„Rückgängig“ fehlt")
        undo.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element(app, "quickAdd.toast"))
        waitForExpectations(timeout: 5)
        XCTAssertFalse(element(app, "home.unassignedCard").exists,
                       "Nach „Rückgängig“ darf kein Artikel ohne Laden übrig sein")
    }

    /// Der Toast bleibt länger als zwei Sekunden stehen (vorher verschwand er nach zwei Sekunden).
    func testToastStaysVisibleLongerThanTwoSeconds() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)
        field.typeText("\n")

        let toast = element(app, "quickAdd.toast")
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "Bestätigungs-Toast erscheint nicht")
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(toast.exists, "Der Toast ist nach drei Sekunden schon weg")
    }

    // MARK: - 3A/3B: Artikel ohne Laden

    /// „Ohne Laden“ als bewusste Wahl: Der Artikel verschwindet nicht, sondern erscheint als Karte
    /// auf der Startseite.
    func testItemAddedWithoutStoreShowsUnassignedCard() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)

        let none = element(app, "quickAdd.storeChip.none")
        XCTAssertTrue(none.waitForExistence(timeout: 5), "Chip „Ohne Laden“ fehlt")
        none.tap()
        field.typeText("\n")

        let card = element(app, "home.unassignedCard")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Karte „Ohne Laden“ erscheint nicht")
        XCTAssertTrue(labelOf(card, contains: "1 Artikel ohne Laden"),
                      "Die Karte zählt nicht richtig — bekommen: \(card.label)")
    }

    /// Die Karte nennt Anzahl und Namen der offenen Artikel ohne Laden.
    func testUnassignedCardShowsCountAndNames() {
        let app = launchedApp(storeless: true)

        let card = element(app, "home.unassignedCard")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Karte „Ohne Laden“ fehlt")
        XCTAssertTrue(labelOf(card, contains: "2 Artikel ohne Laden"), "Anzahl fehlt — bekommen: \(card.label)")
        XCTAssertTrue(labelOf(card, contains: "Testartikel Eins"), "Name fehlt — bekommen: \(card.label)")
    }

    /// „Alle Vorschläge übernehmen“ ordnet alles zu; das Sheet schließt sich, die Karte verschwindet.
    func testAcceptAllAssignsEverythingAndRemovesCard() {
        let app = launchedApp(storeless: true)

        let card = element(app, "home.unassignedCard")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Karte „Ohne Laden“ fehlt")
        card.tap()

        let acceptAll = element(app, "unassigned.acceptAll")
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 5), "„Alle Vorschläge übernehmen“ fehlt")
        XCTAssertTrue(labelOf(acceptAll, contains: "(2)"), "Zähler stimmt nicht — bekommen: \(acceptAll.label)")
        acceptAll.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element(app, "unassigned.acceptAll"))
        waitForExpectations(timeout: 10)
        expectation(for: gone, evaluatedWith: element(app, "home.unassignedCard"))
        waitForExpectations(timeout: 10)
    }

    /// Ein Tipp auf einen Laden ordnet genau diesen Artikel zu; der andere bleibt offen.
    func testChoosingStoreForOneItemLeavesTheOtherOpen() {
        let app = launchedApp(storeless: true)

        let card = element(app, "home.unassignedCard")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Karte „Ohne Laden“ fehlt")
        card.tap()

        let dmChip = element(app, "unassigned.Testartikel Eins.dm")
        XCTAssertTrue(dmChip.waitForExistence(timeout: 5), "Laden-Chip für „Testartikel Eins“ fehlt")
        dmChip.tap()

        let acceptAll = element(app, "unassigned.acceptAll")
        XCTAssertTrue(acceptAll.waitForExistence(timeout: 5), "„Alle Vorschläge übernehmen“ fehlt")
        XCTAssertTrue(labelOf(acceptAll, contains: "(1)"),
                      "Es ist nicht genau ein Artikel übrig — bekommen: \(acceptAll.label)")
        XCTAssertFalse(element(app, "unassigned.Testartikel Eins.Lidl").exists,
                       "Der zugeordnete Artikel steht noch in der Liste")
    }

    // MARK: - #98 Durchgang 3: das Ende der Kette — der Artikel steht wirklich in der Ladenliste

    /// Nach Return steht der Artikel als offener Artikel in der Liste des Zielladens — nicht nur der
    /// Toast ist erschienen. Gegenprobe: im anderen Laden steht er nicht.
    func testAddedItemAppearsInStoreList() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)
        field.typeText("\n")
        XCTAssertTrue(element(app, "quickAdd.toast").waitForExistence(timeout: 5), "Toast erscheint nicht")

        openStore("Lidl", in: app)
        XCTAssertTrue(listRow("Nudeln", in: app).waitForExistence(timeout: 10),
                      "„Nudeln“ steht nicht in der Liste von Lidl")
        closeStore(in: app)

        openStore("dm", in: app)
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "Liste von dm öffnet nicht")
        XCTAssertFalse(listRow("Nudeln", in: app).waitForExistence(timeout: 3),
                       "„Nudeln“ steht fälschlich auch in der Liste von dm")
    }

    /// „Laden ändern“ im Toast verschiebt den Artikel wirklich, und die Korrektur gilt beim nächsten
    /// Eintippen desselben Namens — für einen anderen Namen nicht.
    func testChangeStoreMovesItemAndRemembersCorrection() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("Nudeln", in: app)
        field.typeText("\n")

        let change = element(app, "quickAdd.toast.change")
        XCTAssertTrue(change.waitForExistence(timeout: 5), "„Laden ändern“ fehlt")
        change.tap()

        // Der Dialog „Zu welchem Laden?“ bietet nur den anderen Laden an. Je nach iOS-Version liegen
        // die Knöpfe in einem Sheet oder direkt in der App; die Kachel „dm,“ zählt nicht.
        let predicate = NSPredicate(format: "label ENDSWITH %@", "dm")
        let inSheet = app.sheets.buttons.matching(predicate).firstMatch
        let inApp = app.buttons.matching(predicate).firstMatch
        let deadline = Date().addingTimeInterval(10)
        while !inSheet.exists && !inApp.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let dmChoice = inSheet.exists ? inSheet : inApp
        XCTAssertTrue(dmChoice.exists, "Dialog bietet „dm“ nicht an")
        XCTAssertFalse(app.sheets.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Lidl")).firstMatch.exists,
                       "Der Dialog bietet den Laden an, in dem der Artikel schon liegt")
        dmChoice.tap()

        XCTAssertTrue(labelOf(element(app, "quickAdd.toast.message"), contains: "dm"),
                      "Der Toast nennt den neuen Laden nicht")

        openStore("dm", in: app)
        XCTAssertTrue(listRow("Nudeln", in: app).waitForExistence(timeout: 10),
                      "„Nudeln“ steht nach der Korrektur nicht in der Liste von dm")
        closeStore(in: app)
        openStore("Lidl", in: app)
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "Liste von Lidl öffnet nicht")
        XCTAssertFalse(listRow("Nudeln", in: app).waitForExistence(timeout: 3),
                       "„Nudeln“ steht nach der Korrektur noch in der Liste von Lidl")
        closeStore(in: app)

        // Die Korrektur ist gemerkt: derselbe Name geht jetzt nach dm — mit dem passenden Grund.
        let again = typeIntoQuickAdd("Nudeln", in: app)
        XCTAssertTrue(labelOf(element(app, "quickAdd.target"), contains: "dm"),
                      "Die gemerkte Korrektur greift beim erneuten Eintippen nicht")
        let reason = element(app, "quickAdd.reason")
        XCTAssertTrue(labelOf(reason, contains: "früher in diesen Laden verschoben"),
                      "Der Grund nennt die Korrektur nicht — bekommen: \(reason.label)")

        // Gegenprobe: Die Korrektur gilt nur für den Namen „Nudeln“.
        again.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        again.typeText("Joghurt")
        XCTAssertTrue(labelOf(element(app, "quickAdd.target"), contains: "Lidl"),
                      "Ein anderer Artikel wird fälschlich nach dm geleitet")
    }

    /// „500 gramm Hackfleisch“: In der Liste steht „Hackfleisch“ als Name und „500 gramm“ als Menge —
    /// ohne „ca. “, weil der Nutzer die Menge selbst getippt hat.
    func testQuantityAndUnitShownInList() {
        let app = launchedApp()
        let field = typeIntoQuickAdd("500 gramm Hackfleisch", in: app)
        XCTAssertTrue(labelOf(element(app, "quickAdd.target"), contains: "Lidl"),
                      "Ziel-Karte nennt Lidl nicht")
        field.typeText("\n")
        XCTAssertTrue(element(app, "quickAdd.toast").waitForExistence(timeout: 5), "Toast erscheint nicht")

        openStore("Lidl", in: app)
        XCTAssertTrue(listRow("Hackfleisch", in: app).waitForExistence(timeout: 10),
                      "„Hackfleisch“ steht nicht als Name in der Liste von Lidl")
        XCTAssertTrue(app.staticTexts["500 gramm"].waitForExistence(timeout: 5),
                      "Die Mengenzeile „500 gramm“ fehlt in der Liste")
        XCTAssertFalse(app.staticTexts["ca. 500 gramm"].exists,
                       "Die selbst getippte Menge ist fälschlich als Annahme („ca. “) markiert")
        XCTAssertFalse(app.staticTexts["500 gramm Hackfleisch"].exists,
                       "Der Rohtext steht als Name in der Liste statt „Hackfleisch“")
    }
}
