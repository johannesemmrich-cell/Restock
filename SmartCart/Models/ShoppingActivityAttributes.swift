import ActivityKit
import Foundation

struct ShoppingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var nextItemName: String?
        var pendingItemNames: [String]
        var storeColorHex: String

        init(completedCount: Int, totalCount: Int, nextItemName: String?, pendingItemNames: [String] = [], storeColorHex: String) {
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.nextItemName = nextItemName
            self.pendingItemNames = pendingItemNames
            self.storeColorHex = storeColorHex
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            completedCount    = try c.decode(Int.self,    forKey: .completedCount)
            totalCount        = try c.decode(Int.self,    forKey: .totalCount)
            nextItemName      = try c.decodeIfPresent(String.self,   forKey: .nextItemName)
            pendingItemNames  = (try c.decodeIfPresent([String].self, forKey: .pendingItemNames)) ?? []
            storeColorHex     = try c.decode(String.self, forKey: .storeColorHex)
        }
    }

    var storeName: String
    var storeEmoji: String
}
