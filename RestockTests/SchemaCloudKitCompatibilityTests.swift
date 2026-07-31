import XCTest
import SwiftData
@testable import Restock

/// Reproduziert und beweist die Behebung von `SwiftDataError.loadIssueModelContainer`, das
/// live vom betroffenen Gerät diagnostiziert wurde (30.07.2026, per `cktool export-schema` in
/// Development UND Production bestätigt: kein einziger CloudKit-Record-Typ für Store/
/// ShoppingItem/PurchaseRecord/FeedbackItem existierte, in keiner der beiden Umgebungen, je).
/// Root Cause: SwiftDatas automatische private CloudKit-Spiegelung verlangt zwingend, dass
/// JEDE gespeicherte Eigenschaft entweder optional ist oder einen Standardwert hat. Mehrere
/// Kernfelder (id, name, quantity, isActive, ...) waren das nicht.
final class SchemaCloudKitCompatibilityTests: XCTestCase {
    /// GRÜN mit dem Fix (alle Eigenschaften optional/defaulted). Um zu beweisen, dass dieser
    /// Test die Regression wirklich erkennen würde (ROT ohne den Fix), siehe
    /// `testDemonstratesRedWithoutFix()` unten — der reproduziert den Bug isoliert, ohne die
    /// echten App-Modelle anzufassen.
    func testCloudKitMirroredContainerInitializesForRealSchema() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-cktest-\(UUID().uuidString).store")
        defer { Self.removeStoreFiles(at: tempURL) }

        let config = ModelConfiguration(
            url: tempURL,
            cloudKitDatabase: .private(SharedModelContainer.cloudKitContainerID)
        )

        XCTAssertNoThrow(
            try ModelContainer(for: schema, configurations: config),
            "ModelContainer mit cloudKitDatabase: .private(...) darf für das aktuelle SchemaV1 nicht scheitern — sonst ist die private CloudKit-Spiegelung wieder kaputt."
        )
    }

    /// Isolierter Beweis, dass die Testmethode oben tatsächlich empfindlich für genau diesen
    /// Fehler ist: ein minimales @Model mit einer nicht-optionalen, nicht-defaulteten
    /// Eigenschaft (exakter Fingerabdruck des ursprünglichen Bugs) MUSS beim CloudKit-Öffnen
    /// scheitern. Fasst NICHT die echten App-Modelle an — reine Demonstration der Testmethodik,
    /// damit "der Test wäre eh immer grün" ausgeschlossen ist.
    func testDemonstratesRedWithoutFix() throws {
        let schema = Schema([BrokenCloudKitModel.self])
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("broken-cktest-\(UUID().uuidString).store")
        defer { Self.removeStoreFiles(at: tempURL) }

        let config = ModelConfiguration(
            url: tempURL,
            cloudKitDatabase: .private(SharedModelContainer.cloudKitContainerID)
        )

        XCTAssertThrowsError(
            try ModelContainer(for: schema, configurations: config),
            "Ein Modell mit einer nicht-optionalen Eigenschaft ohne Standardwert MUSS beim CloudKit-Öffnen scheitern — wenn das hier nicht mehr wirft, testet die Methodik oben nichts mehr."
        )
    }

    static func removeStoreFiles(at url: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
        try? fm.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
    }
}

/// NUR für `testDemonstratesRedWithoutFix()` — bewusst nicht Teil des echten Schemas.
@Model
private final class BrokenCloudKitModel {
    var name: String
    init(name: String) { self.name = name }
}
