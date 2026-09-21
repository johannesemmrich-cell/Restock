import XCTest
import SwiftData
@testable import Restock

/// TDD-RED für Issue #4: Die Share Extension stürzt ~4,5 s nach Start ab (SIGTRAP auf
/// `com.apple.coredata.cloudkit.queue`, Crash-Report `RestockShareExtension-2026-09-20-160807.ips`),
/// weil `SharedModelContainer.make()` den Store zuerst mit CloudKit-Spiegelung öffnet — die
/// Extension hat aber kein `com.apple.developer.icloud-services`-Entitlement, und CloudKit bricht
/// den Prozess dann per Assertion ab, statt einen fangbaren Fehler zu werfen.
///
/// Diese Tests schlagen VOR dem Fix bereits beim Übersetzen fehl (die drei geforderten
/// Einstiegspunkte existieren noch nicht) — das ist der RED-Beleg. Sie legen zugleich die
/// Ziel-API fest: Die Verzweigung arbeitet auf einer übergebenen `URL`, nicht direkt auf
/// `Bundle.main`. Nur so sind beide Richtungen prüfbar, ohne einen echten Extension-Prozess
/// starten zu müssen — und nur so lässt sich das größte Risiko dieser Änderung überhaupt
/// absichern (siehe `testDetectionIsFalseForTheMainAppProcess` unten).
///
/// Warum dieses Test-Target der richtige Ort ist: `RestockTests.xctest` liegt in
/// `Restock.app/PlugIns/` und läuft mit `TEST_HOST = Restock.app/Restock` IM App-Prozess.
/// `Bundle.main` ist hier also tatsächlich `Restock.app` — die Prüfung unten ist damit ein
/// echter Nachweis für den App-Prozess und keine Simulation.
final class SharedModelContainerExtensionDetectionTests: XCTestCase {

    // MARK: - Testpfade
    //
    // Bewusst konstruierte URLs statt echter Bundles: Ein `.appex` lässt sich im Testprozess
    // nicht laden, und genau darum arbeitet die Erkennung auf einer URL. Die Pfade entsprechen
    // exakt dem, was die beiden Erweiterungen zur Laufzeit als `Bundle.main.bundleURL` sehen
    // (verifiziert am gebauten Produkt: beide `.appex` liegen in `Restock.app/PlugIns/`).

    private let shareExtensionBundleURL = URL(
        fileURLWithPath: "/private/var/containers/Bundle/Application/ABCDEF/Restock.app/PlugIns/RestockShareExtension.appex",
        isDirectory: true
    )

    private let widgetBundleURL = URL(
        fileURLWithPath: "/private/var/containers/Bundle/Application/ABCDEF/Restock.app/PlugIns/SmartCartWidgets.appex",
        isDirectory: true
    )

    private let mainAppBundleURL = URL(
        fileURLWithPath: "/private/var/containers/Bundle/Application/ABCDEF/Restock.app",
        isDirectory: true
    )

    // MARK: - AC-1: Die Haupt-App darf NIEMALS als Erweiterung gelten

    /// Das größte Risiko dieser Änderung, und der Grund, warum dieser Test zuerst steht:
    /// Würde der App-Prozess fälschlich als Erweiterung erkannt, öffnete die App dauerhaft nur
    /// noch lokal — ohne Fehler, ohne Absturz, ohne sichtbares Symptom. Der Nutzer merkte es
    /// erst Wochen später daran, dass seine Liste auf dem zweiten Gerät nicht mehr ankommt.
    /// Ein symptomloser Fehler braucht einen Test, der ihn hörbar macht.
    func testDetectionIsFalseForTheMainAppProcess() {
        XCTAssertFalse(
            SharedModelContainer.isAppExtension(bundleURL: Bundle.main.bundleURL),
            """
            Der Unit-Test läuft im App-Prozess (TEST_HOST = Restock.app). Wird er hier als \
            App-Erweiterung erkannt, schaltet der Fix die iCloud-Spiegelung der Haupt-App \
            still ab — genau der symptomlose Fehler, den dieser Test verhindern soll. \
            Tatsächliches Bundle: \(Bundle.main.bundleURL.lastPathComponent)
            """
        )
    }

    /// Zweite Absicherung derselben Richtung, diesmal unabhängig davon, wo der Testprozess
    /// tatsächlich läuft: ein fest verdrahteter App-Pfad.
    func testDetectionIsFalseForAnAppBundlePath() {
        XCTAssertFalse(
            SharedModelContainer.isAppExtension(bundleURL: mainAppBundleURL),
            "Ein auf .app endender Bundle-Pfad ist die Haupt-App, keine Erweiterung."
        )
    }

    // MARK: - AC-2: Beide Erweiterungen werden erkannt

    func testDetectionIsTrueForTheShareExtensionBundlePath() {
        XCTAssertTrue(
            SharedModelContainer.isAppExtension(bundleURL: shareExtensionBundleURL),
            "RestockShareExtension.appex ist der Prozess, der in Issue #4 abstürzt — er MUSS erkannt werden."
        )
    }

    /// Das Widget hat dieselbe Ausgangslage (App-Gruppe ohne iCloud-Entitlement), nur ist dort
    /// nie ein Absturz aufgetreten — vermutlich, weil ein Timeline-Aufbau kürzer lebt als die
    /// ~4,5 s bis zur CloudKit-Assertion. Es wird vom selben Fix mitgeheilt; dieser Test hält
    /// fest, dass die Erkennung es einschließt (eigener Nachweis: Folge-Issue #6).
    func testDetectionIsTrueForTheWidgetBundlePath() {
        XCTAssertTrue(
            SharedModelContainer.isAppExtension(bundleURL: widgetBundleURL),
            "SmartCartWidgets.appex muss ebenfalls als Erweiterung erkannt werden."
        )
    }

    /// Groß-/Kleinschreibung von Pfad-Endungen ist auf dem (case-insensitive) Dateisystem des
    /// Simulators und auf iOS-Geräten nicht bedeutungstragend. Ein `.APPEX` ist dasselbe Bundle
    /// wie ein `.appex` — würde es als Haupt-App durchgehen, liefe genau der abstürzende
    /// CloudKit-Pfad wieder an. Der Code behandelt das bereits richtig; dieser Test hält es fest.
    func testDetectionIsCaseInsensitive() {
        let shouting = URL(
            fileURLWithPath: "/private/var/containers/Bundle/Application/ABCDEF/Restock.app/PlugIns/RestockShareExtension.APPEX",
            isDirectory: true
        )
        XCTAssertTrue(
            SharedModelContainer.isAppExtension(bundleURL: shouting),
            "Die Pfad-Endung .APPEX bezeichnet dasselbe Bundle wie .appex und muss ebenso erkannt werden."
        )
    }

    /// Gegenprobe zur Groß-/Kleinschreibung: Entscheidend ist die Endung des Bundles SELBST,
    /// nicht irgendein `.appex` weiter oben im Pfad. Läge eine App-Hülle innerhalb eines
    /// Erweiterungs-Bundles, wäre sie trotzdem eine App — eine Erkennung über „enthält .appex"
    /// würde hier fälschlich `true` liefern und der Haupt-App still die Spiegelung abschalten.
    func testDetectionIgnoresAppexInAnIntermediatePathComponent() {
        let nested = URL(
            fileURLWithPath: "/private/var/containers/Bundle/Application/ABCDEF/Foo.appex/Contents/Bar.app",
            isDirectory: true
        )
        XCTAssertFalse(
            SharedModelContainer.isAppExtension(bundleURL: nested),
            "Nur die Endung des Bundles selbst zählt — ein .appex weiter oben im Pfad darf nicht ausschlagen."
        )
    }

    /// Ein abschließender Schrägstrich ist bei Verzeichnis-URLs üblich und darf das Ergebnis
    /// nicht verändern — `Bundle.bundleURL` liefert genau solche Verzeichnis-URLs.
    func testDetectionIgnoresTrailingSlash() {
        let withSlash = URL(fileURLWithPath: shareExtensionBundleURL.path + "/", isDirectory: true)
        XCTAssertTrue(
            SharedModelContainer.isAppExtension(bundleURL: withSlash),
            "Ein abschließender Schrägstrich darf die Erkennung nicht kippen."
        )
    }

    // MARK: - AC-3: Im App-Prozess bleibt die CloudKit-Spiegelung erste Wahl

    /// In Phase 4 verifiziert (nicht vorausgesetzt): `ModelConfiguration.cloudKitContainerIdentifier`
    /// ist im iOS-27.0-SDK öffentlich lesbar (`public let cloudKitContainerIdentifier: String?`).
    /// Damit ist die Richtung „App spiegelt weiterhin" direkt im Unit-Test beweisbar und hängt
    /// nicht allein am Cross-App-Nachweis. Ein bloßer Test der Erkennung würde einen vertauschten
    /// Vergleich in `make()` nicht bemerken — dieser hier schon.
    func testMainAppStillPrefersTheCloudKitMirroredConfiguration() {
        let configurations = SharedModelContainer.storeConfigurations(forBundleAt: mainAppBundleURL)

        XCTAssertEqual(
            configurations.first?.cloudKitContainerIdentifier,
            SharedModelContainer.cloudKitContainerID,
            "Im App-Prozess muss die ERSTE (bevorzugte) Konfiguration weiterhin die CloudKit-gespiegelte sein."
        )
        XCTAssertEqual(
            configurations.count, 2,
            "Die Haupt-App behält beide Stufen: CloudKit zuerst, lokaler App-Gruppen-Store als Rückfallebene."
        )
        XCTAssertNil(
            configurations.last?.cloudKitContainerIdentifier,
            "Die Rückfallebene der Haupt-App ist der lokale Store ohne Spiegelung."
        )
    }

    // MARK: - AC-4: In Erweiterungen wird CloudKit gar nicht erst versucht

    /// Der Kern des Fixes: Nicht „CloudKit scheitert und wir fangen es auf" — der Versuch selbst
    /// bringt den Prozess um, bevor irgendein `catch` greifen kann. Es darf also gar keine
    /// CloudKit-Konfiguration entstehen.
    func testAppExtensionNeverBuildsACloudKitConfiguration() {
        for (name, url) in [("Share Extension", shareExtensionBundleURL), ("Widget", widgetBundleURL)] {
            let configurations = SharedModelContainer.storeConfigurations(forBundleAt: url)

            XCTAssertEqual(
                configurations.count, 1,
                "\(name): In einer Erweiterung gibt es nur noch eine Stufe — den lokalen App-Gruppen-Store."
            )
            XCTAssertTrue(
                configurations.allSatisfy { $0.cloudKitContainerIdentifier == nil },
                "\(name): Keine einzige Konfiguration darf CloudKit anfordern — der Versuch ist der Absturz."
            )
        }
    }

    /// Schema und Ablageort bleiben in BEIDEN Zweigen identisch. Das ist die Zusage aus der
    /// Datei-Kopfwarnung von `SharedModelContainer`: Abweichende Store-Adressierung je Prozess
    /// hat in diesem Projekt schon einmal echten Datenverlust verursacht. Verzweigt wird
    /// ausschließlich über die Spiegelung, niemals über den Store selbst.
    func testExtensionAndAppOpenTheSameStoreLocation() {
        let appLocal = SharedModelContainer.storeConfigurations(forBundleAt: mainAppBundleURL).last
        let extensionLocal = SharedModelContainer.storeConfigurations(forBundleAt: shareExtensionBundleURL).first

        XCTAssertEqual(
            appLocal?.url, extensionLocal?.url,
            "Erweiterung und Haupt-App müssen exakt dieselbe Store-Datei öffnen — nur mit bzw. ohne Spiegelung."
        )
    }

    // MARK: - AC-4 (zweiter Teil): Das einmalige Sicherungsfenster gehört der Haupt-App

    /// `backupLocalStoreBeforeFirstCloudAttempt()` sichert genau EIN riskantes Fenster pro Gerät:
    /// den allerersten Kontakt mit dem Cloud-Pfad. Das Flag liegt app-gruppenweit. Überspringt
    /// eine Erweiterung künftig CloudKit, fasst sie dieses Fenster nie an — dürfte es also auch
    /// nicht verbrauchen. Täte sie es doch, wäre die Sicherung beim echten ersten App-Start
    /// bereits aufgebraucht und schützte nichts: Wer „Teilen" benutzt, bevor er die App je
    /// gestartet hat, verlöre genau den Schutz, für den das Flag existiert.
    func testPreCloudBackupRunsOnlyInTheMainApp() {
        XCTAssertTrue(
            SharedModelContainer.shouldRunPreCloudBackup(forBundleAt: mainAppBundleURL),
            "Die Haupt-App macht weiterhin die einmalige Sicherung vor ihrem ersten Cloud-Versuch."
        )
        XCTAssertFalse(
            SharedModelContainer.shouldRunPreCloudBackup(forBundleAt: shareExtensionBundleURL),
            "Die Share Extension darf das einmalige Sicherungsfenster nicht verbrauchen — sie berührt den Cloud-Pfad nie."
        )
        XCTAssertFalse(
            SharedModelContainer.shouldRunPreCloudBackup(forBundleAt: widgetBundleURL),
            "Gleiches gilt für das Widget."
        )
    }
}
