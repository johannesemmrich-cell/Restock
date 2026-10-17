import XCTest

/// Issue #150: `CheckOffItemIntent` ist nur der Knopf der Live Activity und darf in Siri, Spotlight und der
/// Kurzbefehle-App nicht auftauchen (ohne laufende Activity tut er bewusst nichts und meldet trotzdem Erfolg).
/// Spec: `docs/specs/services/checkoff-intent-verbergen.md`.
///
/// Geprüft werden die vom Build erzeugten Befehls-Metadaten (`Metadata.appintents/extract.actionsdata`), weil
/// das System genau sie liest, nicht die Swift-Eigenschaft. Test-Host ist `Restock.app` (`TEST_HOST`).
/// **Offene Grenzen:** Die Oberfläche der Kurzbefehle-App und der Tipp auf den Knopf der Live Activity sind
/// nicht automatisiert geprüft; das Metadatenformat ist Build-Ausgabe von Xcode, keine dokumentierte Schnittstelle.
final class CheckOffIntentVisibilityTests: XCTestCase {

    private enum MetadataError: Error, CustomStringConvertible {
        case missingFile(URL)
        case unreadable(URL)
        case missingIntent(String, URL, known: [String])
        case missingFlag(String, URL)

        var description: String {
            switch self {
            case .missingFile(let url): return "Metadaten fehlen: \(url.path)"
            case .unreadable(let url): return "Metadaten nicht als JSON lesbar: \(url.path)"
            case let .missingIntent(name, url, known):
                return "\(name) fehlt in \(url.path); vorhanden: \(known.sorted())"
            case let .missingFlag(name, url): return "isDiscoverable fehlt bei \(name) in \(url.path)"
            }
        }
    }

    private var appMetadata: URL {
        Bundle.main.bundleURL.appendingPathComponent("Metadata.appintents/extract.actionsdata")
    }

    private var widgetMetadata: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("PlugIns/SmartCartWidgets.appex/Metadata.appintents/extract.actionsdata")
    }

    /// Liest `isDiscoverable` eines Befehls; fehlende Datei, fehlender Befehl oder fehlendes Feld sind Fehler.
    private func isDiscoverable(_ intent: String, in url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { throw MetadataError.missingFile(url) }
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actions = root["actions"] as? [String: Any] else { throw MetadataError.unreadable(url) }
        guard let action = actions[intent] as? [String: Any] else {
            throw MetadataError.missingIntent(intent, url, known: Array(actions.keys))
        }
        guard let flag = action["isDiscoverable"] as? Bool else { throw MetadataError.missingFlag(intent, url) }
        return flag
    }

    func testCheckOffIntentIsHiddenInAppAndWidgetMetadata() throws {
        XCTAssertFalse(try isDiscoverable("CheckOffItemIntent", in: appMetadata),
                       "CheckOffItemIntent ist in der App für Siri/Kurzbefehle auffindbar")
        XCTAssertFalse(try isDiscoverable("CheckOffItemIntent", in: widgetMetadata),
                       "CheckOffItemIntent ist in der Widget-Erweiterung für Siri/Kurzbefehle auffindbar")
    }

    /// Gegenprobe: ein kaputtes Lesen darf den Test oben nicht grün machen.
    func testAddIntentStaysDiscoverable() throws {
        XCTAssertTrue(try isDiscoverable("AddShoppingItemIntent", in: appMetadata),
                      "AddShoppingItemIntent muss für Siri auffindbar bleiben")
        XCTAssertThrowsError(try isDiscoverable("GibtEsNichtIntent", in: appMetadata),
                             "Unbekannter Befehl muss ein Fehler sein, kein stilles Ergebnis")
    }
}
