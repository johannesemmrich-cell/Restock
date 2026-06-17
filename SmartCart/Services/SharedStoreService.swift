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

    // MARK: - Publish (owner creates / updates)

    func publish(store: Store) async throws -> String {
        let code = store.shareID ?? Self.generateCode()
        let recordID = CKRecord.ID(recordName: code)

        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        record["storeName"] = store.name as CKRecordValue
        record["storeEmoji"] = store.emoji as CKRecordValue
        record["storeColorHex"] = store.colorHex as CKRecordValue
        record["ownerDevice"] = UIDevice.current.name as CKRecordValue
        record["itemsJSON"] = encodeItems(store.items) as CKRecordValue

        try await db.save(record)
        markSynced(shareID: code)
        return code
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

    func pull(shareID: String) async throws -> (items: [SharedItemData], modifiedAt: Date)? {
        let recordID = CKRecord.ID(recordName: shareID)
        let record = try await db.record(for: recordID)
        let remoteModified = record.modificationDate ?? .distantPast
        let lastSync = lastSyncDate(shareID: shareID)

        guard remoteModified > lastSync else { return nil }

        let items = decodeItems(record["itemsJSON"] as? String ?? "[]")
        return (items, remoteModified)
    }

    // MARK: - Push (upload local items)

    func push(store: Store) async throws {
        guard store.shareID != nil else { return }
        _ = try await publish(store: store)
    }

    // MARK: - Last sync tracking

    func markSynced(shareID: String) {
        UserDefaults.standard.set(Date(), forKey: "lastSync_\(shareID)")
    }

    func lastSyncDate(shareID: String) -> Date {
        UserDefaults.standard.object(forKey: "lastSync_\(shareID)") as? Date ?? .distantPast
    }

    // MARK: - Encode / decode

    func encodeItems(_ items: [ShoppingItem]) -> String {
        let dicts: [[String: Any]] = items.map { item in [
            "id": item.id.uuidString,
            "name": item.name,
            "category": item.category,
            "quantity": item.quantity,
            "quantityAmount": item.quantityAmount,
            "unit": item.unit,
            "isCompleted": item.isCompleted,
            "isUrgent": item.isUrgent,
            "note": item.note,
            "assignedTo": item.assignedTo
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
                quantity: dict["quantity"] as? String ?? "1",
                quantityAmount: dict["quantityAmount"] as? Double ?? 1.0,
                unit: dict["unit"] as? String ?? "",
                isCompleted: dict["isCompleted"] as? Bool ?? false,
                isUrgent: dict["isUrgent"] as? Bool ?? false,
                note: dict["note"] as? String ?? "",
                assignedTo: dict["assignedTo"] as? String ?? ""
            )
        }
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
    let quantity: String
    let quantityAmount: Double
    let unit: String
    let isCompleted: Bool
    let isUrgent: Bool
    let note: String
    let assignedTo: String
}
