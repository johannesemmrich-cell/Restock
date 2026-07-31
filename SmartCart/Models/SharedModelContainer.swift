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
        print("⚠️ SharedModelContainer[\(stage)] failed: \(error)")
        UserDefaults.standard.set("[\(stage)] \(error)", forKey: lastFailureKey)
    }
}
