import SwiftData
import Foundation

@Model
class PurchaseRecord {
    var id: UUID
    var itemName: String
    var storeName: String
    var date: Date
    var quantityAmount: Double
    var unit: String

    var item: ShoppingItem?

    init(itemName: String, storeName: String, quantityAmount: Double = 1, unit: String = "") {
        self.id = UUID()
        self.itemName = itemName
        self.storeName = storeName
        self.date = Date()
        self.quantityAmount = quantityAmount
        self.unit = unit
    }
}

// MARK: - Consumption analysis

struct ConsumptionPattern {
    let itemName: String
    let averageDaysBetweenPurchases: Double
    let averageQuantityPerPurchase: Double
    let lastPurchaseDate: Date
    let estimatedNextPurchaseDate: Date

    var daysUntilNeeded: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: estimatedNextPurchaseDate).day ?? 0
    }

    var isOverdue: Bool { daysUntilNeeded < 0 }
    var isDueSoon: Bool { daysUntilNeeded >= 0 && daysUntilNeeded <= 7 }
}

extension Array where Element == PurchaseRecord {
    func consumptionPattern(totalQuantityPerPurchase: Double = 1) -> ConsumptionPattern? {
        guard count >= 2 else { return nil }
        let sorted = sorted { $0.date < $1.date }
        var intervals: [Double] = []
        for i in 1..<sorted.count {
            let days = sorted[i].date.timeIntervalSince(sorted[i - 1].date) / 86400
            intervals.append(days)
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let avgQty = sorted.map { $0.quantityAmount }.reduce(0, +) / Double(sorted.count)
        let last = sorted.last!.date

        // If multiple units bought at once, scale interval
        let scaledInterval = avgQty > 1 ? avgInterval * avgQty / totalQuantityPerPurchase : avgInterval
        let nextDate = last.addingTimeInterval(scaledInterval * 86400)

        return ConsumptionPattern(
            itemName: sorted.first!.itemName,
            averageDaysBetweenPurchases: scaledInterval,
            averageQuantityPerPurchase: avgQty,
            lastPurchaseDate: last,
            estimatedNextPurchaseDate: nextDate
        )
    }
}
