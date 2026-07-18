import ActivityKit
import Foundation

struct ShoppingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var nextItemName: String?
        var pendingItemNames: [String]
        /// Item-UUIDs parallel zu `pendingItemNames` (gleiche Reihenfolge, gleiche Länge).
        /// Der Island-Checkoff-Intent queued die UUID des angezeigten ersten Items — nicht
        /// eine Position/einen Zähler — damit der spätere Drain exakt DIESES Item erledigt,
        /// auch wenn Widget-Checkoffs oder ein Sync-Merge die Pending-Liste zwischenzeitlich
        /// verschoben haben. Reiner ActivityKit-State, KEIN SwiftData-Schema.
        var pendingItemIDs: [UUID]
        var storeColorHex: String

        init(completedCount: Int, totalCount: Int, nextItemName: String?, pendingItemNames: [String] = [], pendingItemIDs: [UUID] = [], storeColorHex: String) {
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.nextItemName = nextItemName
            self.pendingItemNames = pendingItemNames
            self.pendingItemIDs = pendingItemIDs
            self.storeColorHex = storeColorHex
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            completedCount    = try c.decode(Int.self,    forKey: .completedCount)
            totalCount        = try c.decode(Int.self,    forKey: .totalCount)
            nextItemName      = try c.decodeIfPresent(String.self,   forKey: .nextItemName)
            pendingItemNames  = (try c.decodeIfPresent([String].self, forKey: .pendingItemNames)) ?? []
            pendingItemIDs    = (try c.decodeIfPresent([UUID].self,   forKey: .pendingItemIDs)) ?? []
            storeColorHex     = try c.decode(String.self, forKey: .storeColorHex)
        }
    }

    var storeName: String
    var storeEmoji: String
}
