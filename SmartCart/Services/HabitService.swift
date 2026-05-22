import Foundation
import SwiftData

struct HabitService {

    // Analyzes purchase records across all items and returns patterns for items
    // that are due for repurchase
    static func dueSoonItems(allRecords: [PurchaseRecord]) -> [ConsumptionPattern] {
        let grouped = Dictionary(grouping: allRecords) { $0.itemName.lowercased() }
        return grouped.values.compactMap { records in
            records.consumptionPattern()
        }.filter { $0.isDueSoon || $0.isOverdue }
    }

    // Returns the predicted store for an item based on purchase history
    static func preferredStore(for itemName: String, allRecords: [PurchaseRecord], stores: [Store]) -> Store? {
        let nameLower = itemName.lowercased()
        let relevantRecords = allRecords.filter { $0.itemName.lowercased() == nameLower }
        guard !relevantRecords.isEmpty else { return nil }

        let storeCounts = Dictionary(grouping: relevantRecords) { $0.storeName }
            .mapValues { $0.count }
        guard let preferredStoreName = storeCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        return stores.first { $0.name == preferredStoreName }
    }

    // Schedules notifications for items due for repurchase
    static func scheduleReplenishmentNotifications(patterns: [ConsumptionPattern]) {
        Task {
            await NotificationService.shared.scheduleReplenishment(patterns: patterns)
        }
    }
}
