import XCTest
import SwiftData
@testable import Restock

/// Issue #155: Der private iCloud-Abgleich spiegelt jede Entität aus `SchemaV1` als Record-Typ
/// `CD_<Entität>`. In Production legt CloudKit nie Typen oder Felder an, und ein einziger
/// abgelehnter Record lässt den ganzen Export scheitern. Diese Tests halten fest, welche Modelle
/// und Felder gespiegelt werden (T1), und dass der im Repo abgelegte Development-Export
/// `docs/cloudkit/private-schema-aktuell.ckdb` alle davon kennt (T2, T3). Dass derselbe Stand in
/// Production liegt, belegt nur der Werkzeugschritt in `docs/testflight-setup.md`.
final class MirroredSchemaSnapshotTests: XCTestCase {
    private static let deployHint =
        "Gespiegelte Modelle geändert: CloudKit-Schema (Development und Production) vor dem "
        + "TestFlight-Upload ergänzen und deployen (docs/testflight-setup.md)"

    /// Gespeicherte Attribute je Entität (ohne Beziehungen), übernommen aus `SmartCart/Models/`.
    private static let mirroredAttributes: [String: Set<String>] = [
        "Store": [
            "id", "name", "emoji", "colorHex", "visitsPerWeek", "isActive", "isPaused", "categories",
            "countryCode", "isCustom", "itemOrderMap", "learnedPrices", "learnedPriceDates",
            "learnedPriceUnits", "learnedPriceOrigins", "customCategoryEmojis", "customCategoryDates",
            "categoryAssignments", "categoryAssignmentDates", "sortIndex",
        ],
        "ShoppingItem": [
            "id", "name", "category", "categoryManuallySet", "quantity", "quantityAmount", "unit",
            "isCompleted", "isUrgent", "addedDate", "completedDate", "note", "estimatedPrice",
            "estimatedPriceIsAutoDerived", "quantitySource", "priceSource", "priceSourceDate",
            "assignedTo", "addedBy", "completedBy", "lastModified", "photoData", "hasPhoto",
            "photoLastModified",
        ],
        "PurchaseRecord": [
            "id", "itemName", "storeName", "date", "quantityAmount", "unit", "actualPrice",
        ],
        "FeedbackItem": ["id", "context", "text", "priority", "isResolved", "createdAt"],
        "TodoItem": ["id", "title", "notes", "isCompleted", "createdAt"],
    ]

    private var schemaAttributes: [String: Set<String>] {
        let schema = Schema(versionedSchema: SchemaV1.self)
        return Dictionary(uniqueKeysWithValues: schema.entities.map { entity in
            (entity.name, Set(entity.attributes.map(\.name)))
        })
    }

    // MARK: - T1: Modelle gegen feste Liste

    func testT1_mirroredModelsMatchFixedList() {
        XCTAssertEqual(schemaAttributes, Self.mirroredAttributes, Self.deployHint)
    }

    // MARK: - T2: Development-Export kennt alle gespiegelten Typen und Felder

    func testT2_developmentExportContainsAllMirroredTypesAndFields() throws {
        let ckdb = try Self.loadExport()
        var missing: [String] = []
        for (entity, attributes) in schemaAttributes.sorted(by: { $0.key < $1.key }) {
            guard let block = Self.recordTypeBlock("CD_\(entity)", in: ckdb) else {
                missing.append("CD_\(entity) (Typ fehlt, Felder: \(attributes.sorted().joined(separator: ", ")))")
                continue
            }
            let absent = attributes.filter { !Self.block(block, containsField: "CD_\($0)") }
            if !absent.isEmpty {
                missing.append("CD_\(entity): \(absent.sorted().map { "CD_\($0)" }.joined(separator: ", "))")
            }
        }
        XCTAssertTrue(missing.isEmpty, "\(Self.deployHint). Fehlt in private-schema-aktuell.ckdb: \(missing.joined(separator: "; "))")
    }

    // MARK: - T3: optionales Feld TodoItem.notes ist abgedeckt

    /// Felder, die beim ersten Export `nil` sind, legt Development just-in-time nicht an. Das
    /// optionale `notes` muss deshalb ausdrücklich im Schema stehen.
    func testT3_optionalTodoNotesFieldIsInExport() throws {
        XCTAssertTrue(schemaAttributes["TodoItem"]?.contains("notes") == true, "TodoItem.notes nicht mehr gespiegelt")
        let block = try XCTUnwrap(Self.recordTypeBlock("CD_TodoItem", in: try Self.loadExport()),
                                  "\(Self.deployHint). CD_TodoItem fehlt in private-schema-aktuell.ckdb")
        XCTAssertTrue(Self.block(block, containsField: "CD_notes"), "\(Self.deployHint). CD_TodoItem.CD_notes fehlt")
    }

    // MARK: - Hilfen

    private static func loadExport() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/cloudkit/private-schema-aktuell.ckdb")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Text zwischen `RECORD TYPE <name> (` und dem schließenden `);`.
    private static func recordTypeBlock(_ name: String, in ckdb: String) -> String? {
        guard let start = ckdb.range(of: "RECORD TYPE \(name) (") else { return nil }
        let rest = ckdb[start.upperBound...]
        let end = rest.range(of: ");")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// Ein Feld zählt, wenn sein Name allein steht oder als Asset (`_ckAsset`) gespeichert ist.
    private static func block(_ block: String, containsField field: String) -> Bool {
        block.range(of: "(?<![A-Za-z0-9_])\(field)(_ckAsset)?(?![A-Za-z0-9_])", options: .regularExpression) != nil
    }
}
