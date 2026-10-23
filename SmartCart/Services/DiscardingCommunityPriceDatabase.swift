#if DEBUG
import CloudKit
import Foundation

/// Issue #208: Ersatz für die öffentliche CloudKit-Datenbank in UI-Tests
/// (`-discardCommunityPricesForUITests`, Auswahl in `CommunityPriceService.defaultDatabase`).
/// Verwirft jeden Beitrag, zählt ihn unter `countKey` in `UserDefaults.standard` und liefert
/// keine Beobachtungen. Nur in DEBUG kompiliert; Aufräumer `-clearDiscardedCommunityPricesForUITests`.
struct DiscardingCommunityPriceDatabase: CommunityPriceDatabase {
    static let countKey = "communityPricesDiscardedSaveCount"

    func save(_ record: CKRecord) async throws -> CKRecord {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: Self.countKey) + 1, forKey: Self.countKey)
        return record
    }

    func fetchCommunityRecords(chain: String, itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord] {
        []
    }

    func fetchCommunityRecordsAllChains(itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord] {
        []
    }
}
#endif
