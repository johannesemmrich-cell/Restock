import CloudKit
import Foundation
import UIKit

actor SharedStoreService {
    static let shared = SharedStoreService()

    private let container = CKContainer(identifier: "iCloud.com.johannesemmrich.SmartCart")
    private var db: CKDatabase { container.publicCloudDatabase }
    private static let recordType = "SharedStore"

    // MARK: - Code generation

    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - Publish / push (owner or member uploads local state)
    //
    // Both the initial "create share" and every subsequent upload go through `syncToCloud`,
    // which always pulls the current remote record first and merges it with the local snapshot
    // (per-item last-write-wins by `lastModified`, tombstone-aware) before saving. This prevents
    // one device's stale local snapshot from clobbering an addition another device already synced.
    // A save can still lose that race against a *third* device that saves in between our fetch and
    // our save; CloudKit detects that itself (default save policy is `.ifServerRecordUnchanged`)
    // and throws `.serverRecordChanged` with the record that won, so we re-merge against that and
    // retry exactly once instead of silently overwriting it.

    @discardableResult
    func publish(store: Store) async throws -> String {
        let (code, _, _, _) = try await syncToCloud(store: store)
        return code
    }

    @discardableResult
    func push(store: Store) async throws -> (items: [SharedItemData], members: [String], deletedIDs: Set<UUID>)? {
        guard store.shareID != nil else { return nil }
        let (_, items, members, deletedIDs) = try await syncToCloud(store: store)
        return (items, members, deletedIDs)
    }

    private func syncToCloud(store: Store) async throws -> (code: String, items: [SharedItemData], members: [String], deletedIDs: Set<UUID>) {
        let code = store.shareID ?? Self.generateCode()
        let recordID = CKRecord.ID(recordName: code)

        var record: CKRecord
        var isNewRecord: Bool
        do {
            record = try await db.record(for: recordID)
            isNewRecord = false
        } catch {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
            isNewRecord = true
        }

        var attempt = 0
        while true {
            let (mergedItems, mergedMembers, mergedDeletedIDs) = mergeIntoRecord(record, store: store, code: code, isNewRecord: isNewRecord)
            do {
                let saved = try await db.save(record)
                markSynced(shareID: code, at: saved.modificationDate ?? Date())
                pruneDeletions(shareID: code, stillPresent: Set(mergedItems.map(\.id)))
                return (code, mergedItems, mergedMembers, mergedDeletedIDs)
            } catch let error as CKError where error.code == .serverRecordChanged && attempt == 0 {
                // Another device saved between our fetch and our save. Re-merge against the
                // record that actually won instead of blindly overwriting it a second time.
                guard let serverRecord = error.serverRecord else { throw error }
                record = serverRecord
                isNewRecord = false
                attempt += 1
            }
        }
    }

    /// Merges local store state into `record` in place and returns the merged items/members/tombstones.
    private func mergeIntoRecord(_ record: CKRecord, store: Store, code: String, isNewRecord: Bool) -> (items: [SharedItemData], members: [String], deletedIDs: Set<UUID>) {
        let remoteItems = decodeItems(record["itemsJSON"] as? String ?? "[]")
        let remoteMembers = decodeMembers(record["membersJSON"] as? String ?? "[]")
        let remoteDeletedIDs = decodeIDs(record["deletedJSON"] as? String ?? "[]")

        let localTombstones = pendingDeletions(shareID: code)
        let allTombstones = localTombstones.union(remoteDeletedIDs)
        let localItems = sharedItemData(from: store.items)
        let mergedItems = merge(local: localItems, remote: remoteItems, tombstones: allTombstones)
        // Always include this device's own display name: whoever pushes is by definition a
        // member. This also self-heals lists whose join-time `addSelfAsMember` write failed
        // (e.g. rejected by CloudKit permissions) — the member appears with their next push.
        let selfName = UserIdentity.displayName
        let mergedMembers = Array(Set(remoteMembers + store.members + [selfName]).filter { !$0.isEmpty }).sorted()
        // Tombstones only grow (a UUID string is ~36 bytes; even thousands of deletions over the
        // list's lifetime stay trivially small), so any device's deletion is visible to every
        // other device's next pull, not just this device's own future syncs.
        let mergedDeletedIDs = remoteDeletedIDs.union(localTombstones)

        record["storeName"] = store.name as CKRecordValue
        record["storeEmoji"] = store.emoji as CKRecordValue
        record["storeColorHex"] = store.colorHex as CKRecordValue
        // Don't stomp the original owner's name every time some other member pushes an edit.
        if isNewRecord {
            record["ownerDevice"] = UserIdentity.displayName as CKRecordValue
        }
        record["itemsJSON"] = encodeItems(mergedItems) as CKRecordValue
        record["membersJSON"] = encodeMembers(mergedMembers) as CKRecordValue
        record["deletedJSON"] = encodeIDs(mergedDeletedIDs) as CKRecordValue
        return (mergedItems, mergedMembers, mergedDeletedIDs)
    }

    /// Per-item last-write-wins merge: an id present in both is resolved by the newer `lastModified`.
    /// Ids the caller has tombstoned (deleted locally or by another device) are dropped entirely.
    private func merge(local: [SharedItemData], remote: [SharedItemData], tombstones: Set<UUID>) -> [SharedItemData] {
        var byID: [UUID: SharedItemData] = [:]
        for item in remote where !tombstones.contains(item.id) {
            byID[item.id] = item
        }
        for item in local where !tombstones.contains(item.id) {
            if let existing = byID[item.id], existing.lastModified > item.lastModified {
                continue
            }
            byID[item.id] = item
        }
        return Array(byID.values)
    }

    // MARK: - Fetch preview (before joining)

    func fetchPreview(shareID: String) async throws -> SharedStorePreview {
        let recordID = CKRecord.ID(recordName: shareID.uppercased())
        let record = try await db.record(for: recordID)
        return SharedStorePreview(
            shareID: shareID.uppercased(),
            storeName: record["storeName"] as? String ?? "Unbekannt",
            storeEmoji: record["storeEmoji"] as? String ?? "🛒",
            storeColorHex: record["storeColorHex"] as? String ?? "#4A90D9",
            ownerDevice: record["ownerDevice"] as? String ?? "Unbekannt",
            modifiedAt: record.modificationDate ?? .distantPast
        )
    }

    // MARK: - Pull (download remote items if newer)

    func pull(shareID: String) async throws -> (items: [SharedItemData], members: [String], deletedIDs: Set<UUID>, modifiedAt: Date)? {
        let recordID = CKRecord.ID(recordName: shareID)
        let record = try await db.record(for: recordID)
        let remoteModified = record.modificationDate ?? .distantPast
        let lastSync = lastSyncDate(shareID: shareID)

        guard remoteModified > lastSync else { return nil }

        let localTombstones = pendingDeletions(shareID: shareID)
        let remoteDeletedIDs = decodeIDs(record["deletedJSON"] as? String ?? "[]")
        let allTombstones = localTombstones.union(remoteDeletedIDs)
        let allRemoteItems = decodeItems(record["itemsJSON"] as? String ?? "[]")
        let items = allRemoteItems.filter { !allTombstones.contains($0.id) }
        let members = decodeMembers(record["membersJSON"] as? String ?? "[]")
        pruneDeletions(shareID: shareID, stillPresent: Set(allRemoteItems.map(\.id)))
        // Not marked synced here: the caller (SyncCoordinator) only advances the watermark once
        // this result has actually been applied and saved into the local SwiftData store, so a
        // failed/interrupted apply doesn't permanently skip the merge that would have fixed it.
        return (items, members, allTombstones, remoteModified)
    }

    // MARK: - Members

    /// Adds the local user's display name to the shared store's remote member list (owner or joiner).
    func addSelfAsMember(shareID: String) async throws -> [String] {
        let recordID = CKRecord.ID(recordName: shareID)
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch {
            return []
        }
        var members = decodeMembers(record["membersJSON"] as? String ?? "[]")
        let name = UserIdentity.displayName
        if !name.isEmpty, !members.contains(name) {
            members.append(name)
            record["membersJSON"] = encodeMembers(members) as CKRecordValue
            try await db.save(record)
        }
        return members
    }

    // MARK: - Push subscriptions (real-time updates)

    /// Creates (or idempotently updates) a silent-push subscription so other members of this
    /// shared store are notified immediately when the record changes, instead of waiting for
    /// the next poll. Requires the Push Notifications + Background Modes (remote-notification)
    /// capabilities and can only be verified on a real device via a signed build.
    func subscribe(shareID: String) async throws {
        let subscriptionID = "sub-\(shareID)"
        let predicate = NSPredicate(format: "recordID = %@", CKRecord.ID(recordName: shareID))
        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try await db.save(subscription)
    }

    func unsubscribe(shareID: String) async {
        try? await db.deleteSubscription(withID: "sub-\(shareID)")
    }

    /// Räumt die Sharing-Verbindung eines geteilten Stores auf (Push-Abmeldung), wenn er lokal
    /// gelöscht wird — dieselbe Aufräum-Logik wie der explizite "Teilen beenden"-Button in
    /// `StoreShareSheet`. No-op ohne shareID (nicht geteilter Store). Gilt gleichermaßen für
    /// Eigentümer und Beigetretene (beide sollten sauber abmelden, statt nur lokal zu
    /// verschwinden); der geteilte CloudKit-Datensatz selbst bleibt für die übrigen Mitglieder
    /// unverändert bestehen — nur die eigene Push-Subscription wird entfernt.
    ///
    /// Nimmt bewusst nur die shareID (String) entgegen, nicht den `Store` selbst: der Aufrufer
    /// soll den lokalen `context.delete(store)` NICHT auf diesen Aufruf verzögern (das öffnete
    /// ein Zeitfenster, in dem der Store — z. B. für geteilte Stores, die eh schon asynchron
    /// laufen — noch in `activeStores` sichtbar ist und durch ein zwischenzeitliches
    /// Sync-Update lokal "wiederauferstehen" könnte, bevor die eigentliche Löschung greift).
    /// Stattdessen: shareID VOR dem Löschen sichern, synchron löschen, diesen Aufruf danach
    /// unabhängig (fire-and-forget) hinterherschicken.
    func leaveBeforeDeleting(shareID: String?) async {
        guard let shareID else { return }
        await unsubscribe(shareID: shareID)
    }

    // MARK: - Last sync tracking

    /// `at` should be the CKRecord's server `modificationDate` whenever available, not this
    /// device's local clock — a locally-skewed clock could set a watermark ahead of the server's
    /// actual timestamp and cause a later, legitimate update from another device to be skipped.
    func markSynced(shareID: String, at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: "lastSync_\(shareID)")
    }

    func lastSyncDate(shareID: String) -> Date {
        UserDefaults.standard.object(forKey: "lastSync_\(shareID)") as? Date ?? .distantPast
    }

    // MARK: - Local deletion tombstones
    //
    // When an item is deleted from a shared store, the deleting device records it here so that
    // a pull-before-push merge (or a plain pull) doesn't resurrect it from the still-stale remote
    // copy before the deletion itself has been pushed. The confirmed set is also merged into the
    // CKRecord's `deletedJSON` on every push, so other devices learn about the deletion even if
    // they never overlap with this device's own local tombstone state.

    func recordLocalDeletion(shareID: String, itemID: UUID) {
        var ids = pendingDeletions(shareID: shareID)
        ids.insert(itemID)
        persistDeletions(shareID: shareID, ids: ids)
    }

    func pendingDeletions(shareID: String) -> Set<UUID> {
        guard let strings = UserDefaults.standard.array(forKey: "deletedTombstones_\(shareID)") as? [String] else { return [] }
        return Set(strings.compactMap(UUID.init))
    }

    private func pruneDeletions(shareID: String, stillPresent: Set<UUID>) {
        let remaining = pendingDeletions(shareID: shareID).intersection(stillPresent)
        persistDeletions(shareID: shareID, ids: remaining)
    }

    private func persistDeletions(shareID: String, ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: "deletedTombstones_\(shareID)")
    }

    // MARK: - Encode / decode

    private func sharedItemData(from items: [ShoppingItem]) -> [SharedItemData] {
        items.map { item in
            SharedItemData(
                id: item.id,
                name: item.name,
                category: item.category,
                categoryManuallySet: item.categoryManuallySet,
                quantity: item.quantity,
                quantityAmount: item.quantityAmount,
                unit: item.unit,
                isCompleted: item.isCompleted,
                isUrgent: item.isUrgent,
                note: item.note,
                assignedTo: item.assignedTo,
                addedBy: item.addedBy,
                completedBy: item.completedBy,
                lastModified: item.lastModified
            )
        }
    }

    func encodeItems(_ items: [SharedItemData]) -> String {
        let dicts: [[String: Any]] = items.map { item in [
            "id": item.id.uuidString,
            "name": item.name,
            "category": item.category,
            "categoryManuallySet": item.categoryManuallySet,
            "quantity": item.quantity,
            "quantityAmount": item.quantityAmount,
            "unit": item.unit,
            "isCompleted": item.isCompleted,
            "isUrgent": item.isUrgent,
            "note": item.note,
            "assignedTo": item.assignedTo,
            "addedBy": item.addedBy,
            "completedBy": item.completedBy,
            "lastModified": item.lastModified.timeIntervalSince1970
        ]}
        guard let data = try? JSONSerialization.data(withJSONObject: dicts),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    func decodeItems(_ json: String) -> [SharedItemData] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            return SharedItemData(
                id: UUID(uuidString: dict["id"] as? String ?? "") ?? UUID(),
                name: name,
                category: dict["category"] as? String ?? "",
                categoryManuallySet: dict["categoryManuallySet"] as? Bool ?? false,
                quantity: dict["quantity"] as? String ?? "1",
                quantityAmount: dict["quantityAmount"] as? Double ?? 1.0,
                unit: dict["unit"] as? String ?? "",
                isCompleted: dict["isCompleted"] as? Bool ?? false,
                isUrgent: dict["isUrgent"] as? Bool ?? false,
                note: dict["note"] as? String ?? "",
                assignedTo: dict["assignedTo"] as? String ?? "",
                addedBy: dict["addedBy"] as? String ?? "",
                // Optional-with-default like every other field: payloads written before this
                // field existed simply decode as "" instead of failing.
                completedBy: dict["completedBy"] as? String ?? "",
                lastModified: (dict["lastModified"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .distantPast
            )
        }
    }

    func encodeMembers(_ members: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: members),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    func decodeMembers(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return arr
    }

    private func encodeIDs(_ ids: Set<UUID>) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ids.map(\.uuidString)),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private func decodeIDs(_ json: String) -> Set<UUID> {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return Set(arr.compactMap(UUID.init))
    }
}

// MARK: - Data types

struct SharedStorePreview {
    let shareID: String
    let storeName: String
    let storeEmoji: String
    let storeColorHex: String
    let ownerDevice: String
    let modifiedAt: Date
}

struct SharedItemData {
    let id: UUID
    let name: String
    let category: String
    // Muss mitreisen: sonst kommt eine manuell gewählte Kategorie beim Partner als "automatisch"
    // an und dessen gruppierte Ansichten leiten sie wieder aus dem Namen ab (andere Sektion!).
    let categoryManuallySet: Bool
    let quantity: String
    let quantityAmount: Double
    let unit: String
    let isCompleted: Bool
    let isUrgent: Bool
    let note: String
    let assignedTo: String
    let addedBy: String
    let completedBy: String
    let lastModified: Date
}
