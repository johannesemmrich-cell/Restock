import CloudKit
import Foundation

/// Cross-account photo transport for items on shared lists. Deliberately structurally isolated
/// from `SharedStoreService`: different CKRecord type (`SharedItemPhoto`), different actor, zero
/// shared code paths with `syncToCloud`/`mergeIntoRecord`/`merge`/`encodeItems`/`decodeItems`.
///
/// Called ONLY from `EditItemView` when the user actually adds/replaces/removes a photo, or when
/// opening an item whose `hasPhoto` flag is true but whose `photoData` hasn't been downloaded to
/// this device yet — never from the periodic 15s pull loop or from `SyncCoordinator.apply`. This
/// keeps the existing hot-path sync cadence and payload size completely unaffected by this feature:
/// see `ShoppingItem.hasPhoto` (the only photo-related field on that hot path) and
/// `SharedStoreService`'s `SharedItemData`/`encodeItems`/`decodeItems`.
actor SharedItemPhotoService {
    static let shared = SharedItemPhotoService()

    private let container = CKContainer(identifier: "iCloud.com.johannesemmrich.SmartCart")
    private var db: CKDatabase { container.publicCloudDatabase }
    private static let recordType = "SharedItemPhoto"

    private func recordID(for itemID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "photo_\(itemID.uuidString)")
    }

    /// Uploads (or overwrites) the photo for `itemID`. `shareID` is stored for diagnostics only —
    /// lookup is always by the deterministic recordID, never a query.
    ///
    /// Mirrors `SharedStoreService.syncToCloud`'s fetch-then-mutate-then-save pattern: a bare
    /// `CKRecord(recordType:recordID:)` has no server change tag, so saving it when a record
    /// already exists at that ID (i.e. replacing a photo) would throw `.serverRecordChanged` on
    /// every attempt after the first — silently, since callers use `try?`. Fetching first (or
    /// starting fresh only when truly absent) avoids that.
    func push(itemID: UUID, shareID: String, data: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var record: CKRecord
        do {
            record = try await db.record(for: recordID(for: itemID))
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: Self.recordType, recordID: recordID(for: itemID))
        }

        var attempt = 0
        while true {
            record["photoAsset"] = CKAsset(fileURL: tempURL)
            record["shareID"] = shareID as CKRecordValue
            do {
                _ = try await db.save(record)
                return
            } catch let error as CKError where error.code == .serverRecordChanged && attempt == 0 {
                guard let serverRecord = error.serverRecord else { throw error }
                record = serverRecord
                attempt += 1
            }
        }
    }

    /// Fetches the photo bytes for `itemID`, or `nil` if no record exists (never uploaded, or
    /// already deleted).
    func pull(itemID: UUID) async throws -> Data? {
        let record: CKRecord
        do {
            record = try await db.record(for: recordID(for: itemID))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
        guard let asset = record["photoAsset"] as? CKAsset, let fileURL = asset.fileURL else { return nil }
        return try Data(contentsOf: fileURL)
    }

    /// Best-effort delete, mirroring `SharedStoreService.leaveBeforeDeleting`'s fire-and-forget style.
    func delete(itemID: UUID) async {
        _ = try? await db.deleteRecord(withID: recordID(for: itemID))
    }
}
