import ActivityKit
import Foundation

struct ShoppingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var nextItemName: String?
        var storeColorHex: String
    }

    var storeName: String
    var storeEmoji: String
}
