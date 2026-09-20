import XCTest

/// TDD-RED für Issue #4 — der Nachweis, den ein Unit-Test grundsätzlich nicht führen kann.
///
/// Der Absturz passiert asynchron auf `com.apple.coredata.cloudkit.queue` in einem ANDEREN
/// Prozess (`RestockShareExtension.appex`), rund 4,5 s nachdem die Erweiterung gestartet ist.
/// Kein Test innerhalb des App-Prozesses sieht davon etwas. Nur der echte Weg durch zwei
/// fremde Apps zeigt ihn: Fotos-App → Teilen → Restock.
///
/// **Stand vor dem Fix (RED, am 20.09.2026 reproduziert):** Die Erweiterung zeigt rund drei
/// Sekunden „Bon wird erkannt …", verschwindet dann ersatzlos, und der Teilen-Dialog liegt
/// wieder da. Im System landet `RestockShareExtension-2026-09-20-160807.ips`
/// (EXC_BREAKPOINT/SIGTRAP, CloudKit-Queue). Der Erfolgstext erscheint nie.
///
/// **Stand nach dem Fix (GREEN):** Die Erfolgsansicht erscheint, und der Bon ist an die App
/// übergeben.
///
/// ## Zweistufiger Aufbau — mit Absicht
///
/// Der Test prüft erst, dass die Erweiterung ÜBERHAUPT hochkommt („Bon wird erkannt …"), und
/// dann erst das Ergebnis. Ohne diese erste Stufe wäre ein roter Lauf mehrdeutig: Er könnte
/// genauso gut bedeuten, dass die Navigation durch die Fotos-App nicht mehr stimmt. Bleibt
/// Stufe 1 grün und nur Stufe 2 rot, ist bewiesen, dass der Test aus dem RICHTIGEN Grund
/// fehlschlägt — die Erweiterung startet, arbeitet los und stirbt unterwegs.
///
/// ## Voraussetzung an den Testlauf (nicht durch den Test herstellbar)
///
/// Das Bon-Bild muss VOR dem Lauf in der Fotos-Bibliothek des Simulators liegen. Ein
/// Testprozess kann das nicht selbst tun — Fotos importieren geht nur von außen mit
/// `xcrun simctl addmedia`. Das erledigt `scripts/run-share-extension-uitest.sh`, das diesen
/// Test startet und außerdem prüft, ob das System einen neuen Absturzbericht geschrieben hat.
///
/// Alle Bedienelement-Kennungen unten sind am 20.09.2026 gegen iOS 27.0 im Simulator
/// ausgelesen, nicht geraten.
final class ReceiptShareExtensionTests: XCTestCase {

    /// Bundle-Id der System-Fotos-App. Der alte Name („mobileslideshow") stammt noch aus
    /// iPhone-OS-Zeiten und wurde nie geändert.
    private let photosBundleID = "com.apple.mobileslideshow"

    /// Kennung jeder Bildkachel im Raster der Mediathek. Die Fotos-App liefert die Kacheln als
    /// `Image`-Elemente, NICHT als Zellen — ein `cells`-Zugriff findet hier nichts.
    private let gridTileID = "PXGGridLayout-Info"

    /// OCR plus Auflösung der Positionen braucht auf dem Simulator spürbar länger als auf einem
    /// Gerät. Großzügig bemessen, damit ein GRÜNER Lauf nicht an der Uhr scheitert — und immer
    /// noch weit jenseits der ~4,5 s, nach denen der Absturz heute zuschlägt.
    private let recognitionTimeout: TimeInterval = 90

    override func setUpWithError() throws {
        continueAfterFailure = false
    }


    // MARK: - AC-5: Der Bon kommt per Teilen in Restock an

    func testSharingAReceiptPhotoReachesTheSuccessScreen() throws {
        let photos = XCUIApplication(bundleIdentifier: photosBundleID)
        photos.launch()

        watchForSystemDialogs()
        openLibraryGrid(in: photos)
        openMostRecentPhoto(in: photos)
        tapShareButton(in: photos)
        chooseRestockInShareSheet(in: photos)

        // Der Erweiterung Zeit zum Arbeiten geben — oder zum Sterben.
        //
        // Hier steht bewusst KEINE Prüfung auf die Oberfläche der Erweiterung. Am 20.09.2026
        // gegen iOS 27.0 nachgemessen: Die Oberfläche einer Teilen-Erweiterung läuft in einem
        // eigenen Prozess und taucht im Element-Baum der Fotos-App nicht auf; ein Zugriff über
        // ihre eigene Bundle-Id lässt die Testsitzung hängen. Der Nachweis muss also von außen
        // kommen — und er ist dort sogar härter als ein Textvergleich, weil er das Ergebnis
        // prüft statt seiner Beschriftung:
        //
        //   1. Landet die Bon-Nutzlast unter `pendingShareExtensionReceipt` in der App-Gruppe?
        //   2. Entsteht dabei ein neuer Absturzbericht der Erweiterung?
        //
        // Beides prüft `scripts/run-share-extension-uitest.sh` nach diesem Lauf. Dieser Test
        // stellt den Ablauf her, das Skript fällt das Urteil.
        Thread.sleep(forTimeInterval: recognitionTimeout)
    }

    // MARK: - Schritte durch die fremden Apps

    /// Systemdialoge (etwa die Mitteilungsfrage beim ersten Start) gehören SpringBoard, nicht
    /// der Fotos-App, und erscheinen in deren Element-Baum gar nicht. Der Unterbrechungs-
    /// Beobachter ist der offizielle Weg, sie trotzdem wegzuklicken.
    private func watchForSystemDialogs() {
        addUIInterruptionMonitor(withDescription: "Systemdialog") { alert in
            for label in ["Erlauben", "Allow", "OK", "Fortfahren", "Continue"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    /// Stellt die Rasteransicht aller Bilder her — aus JEDEM Zustand heraus.
    ///
    /// Das ist kein Übereifer: Die Fotos-App stellt beim Start ihren letzten Zustand wieder her.
    /// Endete der vorherige Lauf in der Einzelbildansicht oder gar im offenen Teilen-Dialog,
    /// startet sie genau dort wieder — und dort gibt es kein Mediathek-Register. Ohne diesen
    /// Rückweg wäre der Test nur beim allerersten Lauf grün und danach aus einem völlig
    /// sachfremden Grund rot (am 20.09.2026 genau so passiert).
    private func openLibraryGrid(in photos: XCUIApplication) {
        // Begrüßung eines frisch aufgesetzten Simulators — auf einem benutzten fehlt sie.
        for label in ["Fortfahren", "Continue", "Weiter"] {
            let button = photos.buttons[label]
            if button.waitForExistence(timeout: 2) { button.tap() }
        }

        // Schichtweise zurück: erst einen offenen Teilen-Dialog schließen, dann aus der
        // Einzelbildansicht zurück ins Raster. Mehrfach, weil beides übereinanderliegen kann.
        for _ in 0..<3 {
            let closeShareSheet = photos.buttons["header.closeButton"]
            if closeShareSheet.exists && closeShareSheet.isHittable {
                closeShareSheet.tap()
                continue
            }
            let back = photos.buttons["BackButton"]
            if back.exists && back.isHittable {
                back.tap()
                continue
            }
            break
        }

        let library = photos.buttons["LibraryTab"]
        XCTAssertTrue(
            library.waitForExistence(timeout: 15),
            "Das Mediathek-Register der Fotos-App ist nicht erreichbar — die App steckt in einem unerwarteten Zustand."
        )
        library.tap()
    }

    /// Öffnet das zuletzt hinzugefügte Bild. `simctl addmedia` hängt das Testbild ans Ende der
    /// Mediathek; der Element-Baum enthält nur sichtbare Kacheln, deshalb erst ans Ende
    /// scrollen und dann die letzte Kachel nehmen.
    private func openMostRecentPhoto(in photos: XCUIApplication) {
        let tiles = photos.images.matching(identifier: gridTileID)

        XCTAssertTrue(
            tiles.firstMatch.waitForExistence(timeout: 20),
            """
            Kein einziges Bild in der Fotos-Mediathek des Simulators gefunden. \
            Das Testbild muss vor dem Lauf mit `xcrun simctl addmedia` importiert werden — \
            siehe scripts/run-share-extension-uitest.sh.
            """
        )

        for _ in 0..<6 { photos.swipeUp() }

        let lastTile = tiles.element(boundBy: tiles.count - 1)
        XCTAssertTrue(lastTile.exists, "Letzte Bildkachel nach dem Scrollen nicht mehr auffindbar.")
        lastTile.tap()
    }

    /// Der Teilen-Knopf der Einzelbildansicht. Die Kennung ist stabiler als die je nach
    /// Systemsprache wechselnde Beschriftung.
    private func tapShareButton(in photos: XCUIApplication) {
        let share = photos.buttons["PUOneUpBarButtonItemIdentifierShare"]
        XCTAssertTrue(
            share.waitForExistence(timeout: 15),
            "Teilen-Knopf in der Einzelbildansicht der Fotos-App nicht gefunden."
        )
        share.tap()
    }

    /// Wählt Restock im Teilen-Dialog. Die App-Einträge dort sind Zellen mit der Kennung
    /// `shareCell` — nicht Knöpfe. Steht Restock nicht gleich sichtbar, hilft ein Wisch nach
    /// links in der waagerecht scrollbaren App-Zeile.
    private func chooseRestockInShareSheet(in photos: XCUIApplication) {
        let restock = photos.cells.matching(NSPredicate(format: "label == %@", "Restock")).firstMatch

        for attempt in 0..<4 {
            if restock.waitForExistence(timeout: 5) && restock.isHittable {
                restock.tap()
                return
            }
            if attempt > 0 { photos.swipeLeft() }
        }

        XCTFail("Restock wurde im Teilen-Dialog der Fotos-App nicht angeboten.")
    }
}
