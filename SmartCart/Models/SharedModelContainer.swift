import Foundation
import SwiftData

/// The ONE shared way to open the app-group SwiftData store, used by every process that
/// touches it: the main app (`SmartCartApp.init`), Siri intents (`AddShoppingItemIntent`)
/// and the homescreen widget (`ShoppingListWidget` + `CheckOffWidgetItemIntent`).
///
/// ⚠️ DO NOT change the schema declaration or the fallback order here without changing it
/// for ALL of them at once — that's the whole point of this helper. Historically, an intent
/// opening the store with a *plain model array* while the app used
/// `Schema(versionedSchema: SchemaV1.self)` made SwiftData treat the store as incompatible
/// and WIPE IT (real data loss, see the migration comments in SmartCartApp.swift).
///
/// Two things must always match what the main app actually ended up using:
/// 1. the schema representation — `Schema(versionedSchema: SchemaV1.self)`, never a plain
///    `[Model.self, …]` array, and
/// 2. whether the store is CloudKit-mirrored — CloudKit first, local-only app-group store
///    as fallback, in exactly this order.
///
/// Lives in Models (not Services) because this file is compiled into the SmartCartWidgets
/// extension target too, which doesn't include most of the Services group.
enum SharedModelContainer {
    static let appGroupID = "group.com.johannesemmrich.SmartCart"
    static let cloudKitContainerID = "iCloud.com.johannesemmrich.SmartCart"

    /// CloudKit-mirrored app-group container first, local app-group container second.
    /// Returns nil only if both fail — callers decide how to degrade (the main app has
    /// further recovery steps, intents/widget just report "not available right now").
    ///
    /// In the WIDGET EXTENSION the CloudKit attempt always fails BY DESIGN: the extension
    /// has no iCloud entitlement, so it deterministically lands on the `.none` fallback and
    /// opens the same app-group SQLite file without mirroring. Do NOT "fix" this by giving
    /// the extension iCloud entitlements — two processes each running their own CloudKit
    /// mirror against the same store create duplicate records. And do NOT add per-process
    /// branching here either: the fallback order IS the mechanism, and it must stay
    /// identical for every process (see the header warning above).
    /// Diagnostic key holding the most recent failure from `make()`, prefixed `[cloud]`/`[local]`
    /// so callers can tell which stage failed — `SmartCartApp.init()` uses the `[cloud]` prefix
    /// specifically to detect "local opened fine, but cloud never got a chance" (see there).
    static let lastFailureKey = "smartcart.lastContainerError"

    static func make() -> ModelContainer? {
        let schema = Schema(versionedSchema: SchemaV1.self)
        backupLocalStoreBeforeFirstCloudAttempt()
        do {
            let cloud = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    groupContainer: .identifier(appGroupID),
                    cloudKitDatabase: .private(cloudKitContainerID)
                )
            )
            // Erfolg löscht einen ggf. stehen gebliebenen Fehler von einem früheren Start —
            // sonst würde SmartCartApp.init() einen veralteten "[cloud]"-Eintrag von VORHIN
            // fälschlich auf DIESEN (eigentlich erfolgreichen) Aufruf beziehen.
            UserDefaults.standard.removeObject(forKey: lastFailureKey)
            return cloud
        } catch {
            logContainerFailure("cloud", error)
        }
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    groupContainer: .identifier(appGroupID),
                    cloudKitDatabase: .none
                )
            )
        } catch {
            logContainerFailure("local", error)
            return nil
        }
    }

    /// `try?` verschluckte diese Fehler früher komplett — bei einem entfernten TestFlight-Tester
    /// ist die Xcode-Konsole ohnehin nicht erreichbar, daher zusätzlich in `.standard` (bewusst
    /// NICHT die App-Gruppe — genau die könnte ja gerade das Problem sein) ablegen, damit der
    /// Grund im Fehlerfall wenigstens über einen Diagnose-Screenshot sichtbar wird.
    private static func logContainerFailure(_ stage: String, _ error: Error) {
        // Die bisherige Kurzform (nur `\(error)`) zeigte nur den generischen Fehlerfall-Namen
        // (z. B. "loadIssueModelContainer") ohne die tatsächliche zugrunde liegende Ursache —
        // zu wenig, um zwischen "Schema-Problem", "Account/Netzwerk-Problem" oder etwas ganz
        // anderem zu unterscheiden. NSError-Bridging + userInfo-Dump holt raus, was Swifts
        // Standard-Interpolation eines SwiftDataError sonst verschluckt (u.a. oft ein
        // verschachtelter NSUnderlyingError mit dem echten CloudKit-/CoreData-Fehlercode).
        let nsError = error as NSError
        let detail = "domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)"
        let full = "[\(stage)] \(error) | \(detail)"
        print("⚠️ SharedModelContainer[\(stage)] failed: \(full)")
        UserDefaults.standard.set(full, forKey: lastFailureKey)
    }

    /// Sicherheitsnetz für Bestandsnutzer, deren Store bisher nie erfolgreich Cloud-gespiegelt
    /// war (z. B. wegen des am 30.07.2026 behobenen Schema-Fehlers) und die jetzt zum ersten Mal
    /// den `.private(...)`-Versuch oben gegen eine bereits bestehende, echte lokale Datei
    /// erleben. Mehrere dokumentierte Apple-Entwickler-Berichte (developer.apple.com/forums,
    /// u.a. Threads 756538/742899/697756) beschreiben genau dabei Datenverlust — u.a. weil
    /// NSPersistentCloudKitContainer die lokalen Datensätze entfernen kann, wenn CloudKit den
    /// iCloud-Account kurzzeitig als nicht verfügbar einstuft. Reine Kopie der Store-Dateien in
    /// einen separaten Ordner, VOR dem ersten Cloud-Versuch — ändert am eigentlichen Ablauf
    /// nichts, gibt aber einen manuellen Wiederherstellungsweg, falls der Übergang doch Daten
    /// verliert. Läuft nur einmal pro Gerät (App-Gruppen-weites Flag, damit nicht jeder der 3
    /// Prozesse separat sichert) — das genau EINE riskante "erste Mal"-Fenster ist der Punkt,
    /// nicht jeder künftige Start.
    private static func backupLocalStoreBeforeFirstCloudAttempt() {
        let suite = UserDefaults(suiteName: appGroupID) ?? .standard
        // "v2": das alte Flag "smartcart.preCloudBackupDone" ist auf Testgeräten bereits gesetzt
        // (lief einmalig, als der lokale Store noch leer war — schützte dadurch beim eigentlich
        // kritischen zweiten Vorfall nichts). Neuer Key erzwingt genau EIN frisches Backup vor dem
        // ersten Kontakt mit dem jetzt korrigierten Schema — unabhängig vom alten Flag-Stand.
        let flagKey = "smartcart.preCloudBackupDone.v2"
        guard suite.bool(forKey: flagKey) == false else { return }
        suite.set(true, forKey: flagKey)

        let fm = FileManager.default
        guard let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let appSupport = groupURL.appendingPathComponent("Library/Application Support")
        guard let files = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else { return }
        let storeFiles = files.filter {
            $0.pathExtension == "store" || $0.lastPathComponent.hasSuffix(".store-wal") || $0.lastPathComponent.hasSuffix(".store-shm")
        }
        guard !storeFiles.isEmpty else { return }

        let backupDir = appSupport.appendingPathComponent("PreCloudBackup")
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        for file in storeFiles {
            try? fm.copyItem(at: file, to: backupDir.appendingPathComponent(file.lastPathComponent))
        }
    }
}
