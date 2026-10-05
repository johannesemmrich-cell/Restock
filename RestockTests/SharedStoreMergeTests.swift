import XCTest
import SwiftData
import CloudKit
@testable import Restock

/// Merge-Logik geteilter Läden ohne CloudKit (Issue #98, Durchgang 4).
///
/// Teil A prüft `SyncCoordinator.apply` (Remote-Stand auf lokalen Laden), Teil B den Push-Merge
/// `SharedStoreService.mergeIntoRecord`/`merge` mit einem echten, aber nie hochgeladenen `CKRecord`.
///
/// OFFENE GRENZE: Echtes Teilen mit zweitem iCloud-Konto, Einladung/Annahme, stille Push-
/// Benachrichtigung, serverseitige Rechte der `publicCloudDatabase` und die Wiederholung nach
/// `serverRecordChanged` in `syncToCloud` sind hier NICHT geprüft — dafür braucht es zwei angemeldete
/// iCloud-Konten auf echten Geräten; Simulator und CI haben das nicht.
@MainActor
final class SharedStoreMergeTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var shareIDs: [String] = []
    private var storeIDs: [UUID] = []
    private var originalContext: ModelContext?

    private let t1 = Date(timeIntervalSince1970: 1_000_000)
    private let t2 = Date(timeIntervalSince1970: 2_000_000)
    private let t3 = Date(timeIntervalSince1970: 3_000_000)
    private var service: SharedStoreService { SharedStoreService.shared }

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        originalContext = SyncCoordinator.shared.modelContext
        SyncCoordinator.shared.modelContext = context
    }

    override func tearDown() {
        SyncCoordinator.shared.modelContext = originalContext
        removeSyncKeys()
        container = nil
        context = nil
    }

    // MARK: - Teil A: SyncCoordinator.apply

    func testApplyAddsMembersWithoutDuplicates() async {
        let store = makeStore()
        store.addMember("Anna")
        await SyncCoordinator.shared.apply(items: [], members: ["Anna", "Ben", " "], modifiedAt: nil, to: store)
        XCTAssertEqual(store.members, ["Anna", "Ben"])
    }

    func testApplyMergesCategoriesAssignmentsAndPrices() async {
        let store = makeStore()
        store.customCategoryEntries = [
            "A": CustomCategoryEntry(emoji: "🥫", date: t1),
            "B": CustomCategoryEntry(emoji: "🍞", date: t3),
        ]
        store.categoryAssignmentEntries = [
            "feta": CategoryAssignmentEntry(category: "A", date: t1),
            "brot": CategoryAssignmentEntry(category: "B", date: t3),
        ]
        store.learnedPrices = ["milch": 1.0, "brot": 3.0]
        store.learnedPriceDates = ["milch": t1, "brot": t3]
        store.learnedPriceUnits = ["milch": "stk", "brot": "stk"]

        await SyncCoordinator.shared.apply(
            items: [], members: [],
            prices: ["milch": 2.0, "brot": 9.0, "käse": 4.0],
            priceDates: ["milch": t2, "brot": t2, "käse": t2],
            priceUnits: ["milch": "stk", "brot": "stk", "käse": "g"],
            categories: [
                "A": CustomCategoryEntry(emoji: "🧀", date: t2),
                "B": CustomCategoryEntry(emoji: "🥖", date: t2),
            ],
            assignments: [
                "feta": CategoryAssignmentEntry(category: "B", date: t2),
                "brot": CategoryAssignmentEntry(category: "A", date: t2),
            ],
            modifiedAt: nil, to: store
        )

        XCTAssertEqual(store.customCategoryEntries["A"]?.emoji, "🧀", "neuerer Remote-Stand gewinnt")
        XCTAssertEqual(store.customCategoryEntries["B"]?.emoji, "🍞", "neuerer lokaler Stand bleibt")
        XCTAssertEqual(store.categoryAssignmentEntries["feta"]?.category, "B")
        XCTAssertEqual(store.categoryAssignmentEntries["brot"]?.category, "B")
        XCTAssertEqual(store.learnedPrices["milch"], 2.0)
        XCTAssertEqual(store.learnedPrices["brot"], 3.0)
        XCTAssertEqual(store.learnedPrices["käse"], 4.0)
        XCTAssertEqual(store.learnedPriceUnits["käse"], "g")
    }

    func testApplyDeletesOnlyTombstonedItems() async throws {
        let store = makeStore()
        let deleted = makeItem(in: store, name: "Weg")
        let kept = makeItem(in: store, name: "Bleibt, fehlt nur remote")
        await SyncCoordinator.shared.apply(items: [], members: [], deletedIDs: [deleted.id], modifiedAt: nil, to: store)
        let names = try context.fetch(FetchDescriptor<ShoppingItem>()).map(\.name)
        XCTAssertEqual(names, [kept.name])
    }

    func testApplyLastWriteWinsPerItem() async {
        let store = makeStore()
        let item = makeItem(in: store, name: "Alt")
        item.lastModified = t2

        await SyncCoordinator.shared.apply(
            items: [remoteItem(id: item.id, name: "Älter", isCompleted: true, lastModified: t1)],
            members: [], modifiedAt: nil, to: store)
        XCTAssertEqual(item.name, "Alt", "älterer Remote-Stand ändert nichts")
        XCTAssertFalse(item.isCompleted)

        await SyncCoordinator.shared.apply(
            items: [remoteItem(id: item.id, name: "Neu", quantity: "3", unit: "kg", isCompleted: true,
                               isUrgent: true, note: "Notiz", assignedTo: "Ben", addedBy: "Anna",
                               completedBy: "Ben", lastModified: t3, hasPhoto: true)],
            members: [], modifiedAt: nil, to: store)
        XCTAssertEqual(item.name, "Neu")
        XCTAssertEqual(item.quantity, "3")
        XCTAssertEqual(item.unit, "kg")
        XCTAssertTrue(item.isCompleted)
        XCTAssertTrue(item.isUrgent)
        XCTAssertEqual(item.note, "Notiz")
        XCTAssertEqual(item.assignedTo, "Ben")
        XCTAssertEqual(item.addedBy, "Anna")
        XCTAssertEqual(item.completedBy, "Ben")
        XCTAssertEqual(item.lastModified, t3)
        XCTAssertTrue(item.hasPhoto)
    }

    func testApplyCreatesUnknownRemoteItemWithSenderCategory() async throws {
        let store = makeStore()
        // Lokal ist für „Feta“ eine eigene Kategorie gemerkt; die des Absenders muss trotzdem gelten.
        store.customCategoryEmojis["Kühltheke"] = "🧊"
        store.categoryAssignments[ShoppingRoute.itemKey("Feta")] = "Kühltheke"
        let id = UUID()

        await SyncCoordinator.shared.apply(
            items: [remoteItem(id: id, name: "Feta", category: "Milchprodukte", categoryManuallySet: true,
                               addedBy: "Anna", lastModified: t2)],
            members: [], modifiedAt: nil, to: store)

        let created = try XCTUnwrap(context.fetch(FetchDescriptor<ShoppingItem>()).first)
        XCTAssertEqual(created.id, id)
        XCTAssertEqual(created.name, "Feta")
        XCTAssertEqual(created.category, "Milchprodukte")
        XCTAssertTrue(created.categoryManuallySet)
        XCTAssertEqual(created.addedBy, "Anna")
        XCTAssertEqual(created.lastModified, t2)
    }

    func testApplyAdvancesWatermarkOnlyAfterSaveAndWithModifiedAt() async {
        let store = makeStore()
        let shareID = register(shareID: "UT-\(UUID().uuidString)", for: store)
        let before = await service.lastSyncDate(shareID: shareID)
        XCTAssertEqual(before, .distantPast)

        await SyncCoordinator.shared.apply(items: [], members: [], modifiedAt: nil, to: store)
        let afterNil = await service.lastSyncDate(shareID: shareID)
        XCTAssertEqual(afterNil, .distantPast, "ohne modifiedAt (Push-Fall) bleibt der Wasserstand")

        await SyncCoordinator.shared.apply(items: [], members: [], modifiedAt: t2, to: store)
        let afterSave = await service.lastSyncDate(shareID: shareID)
        XCTAssertEqual(afterSave, t2)

        // Ohne Kontext bricht `apply` vor dem Speichern ab: der Wasserstand darf nicht vorrücken.
        let orphan = Store(name: "Waise", emoji: "🛒", colorHex: "#000000")
        let orphanShare = register(shareID: "UT-\(UUID().uuidString)", for: orphan)
        SyncCoordinator.shared.modelContext = nil
        await SyncCoordinator.shared.apply(items: [], members: [], modifiedAt: t3, to: orphan)
        let orphanMark = await service.lastSyncDate(shareID: orphanShare)
        XCTAssertEqual(orphanMark, .distantPast)
    }

    func testApplyWithoutShareIDWritesNoWatermark() async {
        let store = makeStore()
        XCTAssertNil(store.shareID)
        await SyncCoordinator.shared.apply(items: [], members: [], modifiedAt: t2, to: store)
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("lastSync_") && $0.contains(store.id.uuidString) }
        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Teil B: Push-Merge

    func testPushMergeKeepsItemsFromBothSides() async throws {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        let local = makeItem(in: store, name: "Nur lokal")
        let remote = remoteItem(id: UUID(), name: "Nur Server", lastModified: t1)
        let record = await makeRecord(code: code, items: [remote])

        let result = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)

        XCTAssertEqual(Set(result.items.map(\.id)), [local.id, remote.id])
        let written = await service.decodeItems(record["itemsJSON"] as? String ?? "[]")
        XCTAssertEqual(Set(written.map(\.id)), [local.id, remote.id])
    }

    func testPushMergeLastWriteWinsBothDirections() async throws {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        let id = UUID()

        let localNewer = makeItem(in: store, name: "Lokal neuer")
        localNewer.id = id
        localNewer.lastModified = t3
        var record = await makeRecord(code: code, items: [remoteItem(id: id, name: "Server älter", lastModified: t1)])
        var result = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)
        XCTAssertEqual(result.items.first { $0.id == id }?.name, "Lokal neuer")

        localNewer.lastModified = t1
        record = await makeRecord(code: code, items: [remoteItem(id: id, name: "Server neuer", lastModified: t3)])
        result = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)
        XCTAssertEqual(result.items.first { $0.id == id }?.name, "Server neuer")
    }

    func testPushMergeTombstonesOnlyGrowAndRemoveItems() async throws {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        let remotelyDeleted = makeItem(in: store, name: "Server hat gelöscht")
        let locallyDeleted = remoteItem(id: UUID(), name: "Lokal gelöscht", lastModified: t1)
        await service.recordLocalDeletion(shareID: code, itemID: locallyDeleted.id)
        let record = await makeRecord(code: code, items: [locallyDeleted], deleted: [remotelyDeleted.id])

        let result = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)

        XCTAssertTrue(result.items.isEmpty, "Artikel mit Vermerk fehlen, auch wenn die Gegenseite sie noch hat")
        XCTAssertEqual(result.deletedIDs, [remotelyDeleted.id, locallyDeleted.id])
        let written = try deletedIDs(in: record)
        XCTAssertEqual(written, [remotelyDeleted.id, locallyDeleted.id])
    }

    func testPushMergeMembersIncludeOwnNameSortedUnique() async throws {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        store.members = ["Ben", "Anna", ""]
        let record = await makeRecord(code: code, members: ["Zed", "Anna", ""])

        let result = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)

        let expected = Set(["Zed", "Anna", "Ben", UserIdentity.displayName]).sorted()
        XCTAssertEqual(result.members, expected)
        let writtenMembers = await service.decodeMembers(record["membersJSON"] as? String ?? "[]")
        XCTAssertEqual(writtenMembers, expected)
    }

    func testPushMergeOwnerOnlyForNewRecord() async {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)

        let fresh = await makeRecord(code: code)
        _ = await service.mergeIntoRecord(fresh, store: store, code: code, isNewRecord: true)
        XCTAssertEqual(fresh["ownerDevice"] as? String, UserIdentity.displayName)

        let existing = await makeRecord(code: code)
        existing["ownerDevice"] = "Besitzer" as CKRecordValue
        _ = await service.mergeIntoRecord(existing, store: store, code: code, isNewRecord: false)
        XCTAssertEqual(existing["ownerDevice"] as? String, "Besitzer")
    }

    func testPushMergeWritesMetadataCategoriesAssignmentsPrices() async {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        store.customCategoryEntries = ["Lokal": CustomCategoryEntry(emoji: "🧊", date: t2)]
        store.categoryAssignmentEntries = ["feta": CategoryAssignmentEntry(category: "Lokal", date: t2)]
        store.learnedPrices = ["milch": 1.5]
        store.learnedPriceDates = ["milch": t2]
        store.learnedPriceUnits = ["milch": "stk"]
        let record = await makeRecord(code: code)
        record["categoriesJSON"] = await service.encodeCategories(["Server": CustomCategoryEntry(emoji: "🥫", date: t1)]) as CKRecordValue
        record["assignmentsJSON"] = await service.encodeAssignments(["brot": CategoryAssignmentEntry(category: "Server", date: t1)]) as CKRecordValue
        record["pricesJSON"] = LearnedPriceSync.encode(.init(prices: ["käse": 4.0], dates: ["käse": t1], units: ["käse": "g"])) as CKRecordValue

        _ = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)

        XCTAssertEqual(record["storeName"] as? String, store.name)
        XCTAssertEqual(record["storeEmoji"] as? String, store.emoji)
        XCTAssertEqual(record["storeColorHex"] as? String, store.colorHex)
        let categories = await service.decodeCategories(record["categoriesJSON"] as? String ?? "{}")
        XCTAssertEqual(Set(categories.keys), ["Lokal", "Server"])
        let assignments = await service.decodeAssignments(record["assignmentsJSON"] as? String ?? "{}")
        XCTAssertEqual(Set(assignments.keys), ["feta", "brot"])
        let prices = LearnedPriceSync.decode(record["pricesJSON"] as? String ?? "{}")
        XCTAssertEqual(prices.prices, ["milch": 1.5, "käse": 4.0])
    }

    // MARK: - Gleichstand (Ist-Verhalten festgehalten, kein Beschluss)

    /// Bei identischem `lastModified` entscheiden Push-Merge (`>`: lokal gewinnt) und `apply`
    /// (`>=`: Remote gewinnt) verschieden. Das ist KEIN Beschluss, dass es so sein soll — bei
    /// identischem Zeitstempel sind die Daten praktisch gleich. Wer die Regel ändert, tut das
    /// bewusst und passt diesen Test an.
    func testTieOnLastModifiedPushLocalWinsApplyRemoteWins() async {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        let item = makeItem(in: store, name: "Lokal")
        item.lastModified = t2
        let tied = remoteItem(id: item.id, name: "Remote", lastModified: t2)

        let record = await makeRecord(code: code, items: [tied])
        let pushed = await service.mergeIntoRecord(record, store: store, code: code, isNewRecord: false)
        XCTAssertEqual(pushed.items.first?.name, "Lokal", "Push-Merge: bei Gleichstand gewinnt lokal")

        await SyncCoordinator.shared.apply(items: [tied], members: [], modifiedAt: nil, to: store)
        XCTAssertEqual(item.name, "Remote", "apply: bei Gleichstand gewinnt Remote")
    }

    // MARK: - Aufräumen

    func testCleanupLeavesNoSyncKeys() async {
        let store = makeStore()
        let code = register(shareID: "UT-\(UUID().uuidString)", for: store)
        await SyncCoordinator.shared.apply(items: [], members: [], modifiedAt: t2, to: store)
        await service.recordLocalDeletion(shareID: code, itemID: UUID())
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "lastSync_\(code)"))
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "deletedTombstones_\(code)"))

        removeSyncKeys()

        XCTAssertNil(UserDefaults.standard.object(forKey: "lastSync_\(code)"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "deletedTombstones_\(code)"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "shareID_\(store.id.uuidString)"))
    }

    // MARK: - Helpers

    private func makeStore() -> Store {
        let store = Store(name: "Testladen", emoji: "🛒", colorHex: "#4A90D9")
        context.insert(store)
        storeIDs.append(store.id)
        return store
    }

    /// Setzt `shareID` (liegt in `UserDefaults.standard`) und merkt sie fürs Aufräumen.
    private func register(shareID: String, for store: Store) -> String {
        store.shareID = shareID
        shareIDs.append(shareID)
        if !storeIDs.contains(store.id) { storeIDs.append(store.id) }
        return shareID
    }

    private func makeItem(in store: Store, name: String) -> ShoppingItem {
        let item = ShoppingItem(name: name, store: store)
        context.insert(item)
        return item
    }

    private func remoteItem(
        id: UUID, name: String, category: String = "", categoryManuallySet: Bool = false,
        quantity: String = "1", unit: String = "", isCompleted: Bool = false, isUrgent: Bool = false,
        note: String = "", assignedTo: String = "", addedBy: String = "", completedBy: String = "",
        lastModified: Date, hasPhoto: Bool = false
    ) -> SharedItemData {
        SharedItemData(
            id: id, name: name, category: category, categoryManuallySet: categoryManuallySet,
            quantity: quantity, quantityAmount: Double(quantity) ?? 1, unit: unit,
            isCompleted: isCompleted, isUrgent: isUrgent, note: note, assignedTo: assignedTo,
            addedBy: addedBy, completedBy: completedBy, lastModified: lastModified, hasPhoto: hasPhoto)
    }

    /// Ein nie hochgeladener `CKRecord` als Server-Stand.
    private func makeRecord(code: String, items: [SharedItemData] = [], members: [String] = [], deleted: [UUID] = []) async -> CKRecord {
        let record = CKRecord(recordType: "SharedStore", recordID: CKRecord.ID(recordName: code))
        record["itemsJSON"] = await service.encodeItems(items) as CKRecordValue
        record["membersJSON"] = await service.encodeMembers(members) as CKRecordValue
        record["deletedJSON"] = jsonArray(deleted.map(\.uuidString)) as CKRecordValue
        return record
    }

    private func jsonArray(_ strings: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: strings),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private func deletedIDs(in record: CKRecord) throws -> Set<UUID> {
        let json = try XCTUnwrap(record["deletedJSON"] as? String)
        let strings = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String])
        return Set(strings.compactMap(UUID.init))
    }

    private func removeSyncKeys() {
        let defaults = UserDefaults.standard
        for id in shareIDs {
            defaults.removeObject(forKey: "lastSync_\(id)")
            defaults.removeObject(forKey: "deletedTombstones_\(id)")
        }
        for id in storeIDs {
            for prefix in ["shareID_", "members_", "isSharedByMe_"] {
                defaults.removeObject(forKey: "\(prefix)\(id.uuidString)")
            }
        }
        shareIDs = []
        storeIDs = []
    }
}
