import XCTest
@testable import Restock

/// Guards the user's top priority for this feature: the existing `itemsJSON` sync hot path
/// (`SharedStoreService.encodeItems`/`decodeItems`) must gain EXACTLY one new scalar key
/// (`hasPhoto`) and nothing else — no bytes, no size growth beyond a single boolean, and old
/// records written before this feature existed must keep decoding correctly.
final class SharedItemDataPhotoRegressionTests: XCTestCase {
    private func makeItem(hasPhoto: Bool = false) -> SharedItemData {
        SharedItemData(
            id: UUID(), name: "Milch", category: "Milchprodukte", categoryManuallySet: false,
            quantity: "1", quantityAmount: 1, unit: "", isCompleted: false, isUrgent: false,
            note: "", assignedTo: "", addedBy: "", completedBy: "", lastModified: Date(),
            hasPhoto: hasPhoto
        )
    }

    /// Canary for the sync hot path: encoding an item without a photo must produce exactly the
    /// pre-existing key set plus one new `hasPhoto: false` key — nothing else changes shape or size.
    func testEncodeItemsWithoutPhotoAddsOnlyHasPhotoKey() async throws {
        let json = await SharedStoreService.shared.encodeItems([makeItem()])
        let data = try XCTUnwrap(json.data(using: .utf8))
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let keys = Set(arr[0].keys)
        let expectedOldKeys: Set<String> = [
            "id", "name", "category", "categoryManuallySet", "quantity", "quantityAmount", "unit",
            "isCompleted", "isUrgent", "note", "assignedTo", "addedBy", "completedBy", "lastModified"
        ]
        XCTAssertEqual(keys, expectedOldKeys.union(["hasPhoto"]))
        XCTAssertEqual(arr[0]["hasPhoto"] as? Bool, false)
    }

    /// A `SharedStore` CKRecord written before this feature existed has no `hasPhoto` key at all.
    /// Must decode exactly like every other pre-existing optional field (defaults to `false`),
    /// not fail or drop the item.
    func testDecodeOldFormatJSONStillWorks() async throws {
        let id = UUID()
        let oldJSON = """
        [{"id":"\(id.uuidString)","name":"Milch","category":"","categoryManuallySet":false,\
        "quantity":"1","quantityAmount":1,"unit":"","isCompleted":false,"isUrgent":false,\
        "note":"","assignedTo":"","addedBy":"","completedBy":"","lastModified":0}]
        """
        let items = await SharedStoreService.shared.decodeItems(oldJSON)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.hasPhoto, false)
    }

    /// Red before `hasPhoto` existed on `SharedItemData`/`decodeItems`, green after.
    func testDecodeItemsSetsHasPhotoTrueWhenPresent() async throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","name":"Milch","hasPhoto":true,"lastModified":0}]
        """
        let items = await SharedStoreService.shared.decodeItems(json)
        XCTAssertEqual(items.first?.hasPhoto, true)
    }

    /// Round trip: encode → decode must preserve `hasPhoto` for both values.
    func testEncodeDecodeRoundTripPreservesHasPhoto() async throws {
        let json = await SharedStoreService.shared.encodeItems([makeItem(hasPhoto: true), makeItem(hasPhoto: false)])
        let decoded = await SharedStoreService.shared.decodeItems(json)
        XCTAssertEqual(decoded.filter(\.hasPhoto).count, 1)
        XCTAssertEqual(decoded.filter { !$0.hasPhoto }.count, 1)
    }
}
