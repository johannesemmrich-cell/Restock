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

// MARK: - Overdue push deduplication (Issue #30, A3)

/// Merkt sich pro Artikel, für welchen errechneten Termin bereits eine sofortige
/// „Überfällig“-Push-Nachricht geplant wurde. Vorher löste jedes `refreshDueSoon()` (App-Start,
/// jede Änderung an offenen Artikeln oder Kaufdatensätzen) für jeden überfälligen Artikel eine
/// neue Nachricht aus. Jetzt höchstens einmal pro Artikel und Termin: erst ein neuer Kauf
/// verschiebt den Termin und macht den Artikel wieder meldefähig. Ein Eintrag pro Artikelname
/// wird überschrieben, nie angehängt — die Map wächst also nur mit der Zahl verschiedener Artikel.
struct OverdueNotificationLedger {
    static let defaultsKey = "notifiedOverdueReplenishments"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldNotify(_ pattern: ConsumptionPattern) -> Bool {
        notified()[pattern.itemName.lowercased()] != pattern.estimatedNextPurchaseDate.timeIntervalSince1970
    }

    func markNotified(_ pattern: ConsumptionPattern) {
        var map = notified()
        map[pattern.itemName.lowercased()] = pattern.estimatedNextPurchaseDate.timeIntervalSince1970
        defaults.set(map, forKey: Self.defaultsKey)
    }

    private func notified() -> [String: TimeInterval] {
        defaults.dictionary(forKey: Self.defaultsKey) as? [String: TimeInterval] ?? [:]
    }
}

// MARK: - Accepted suggestions removed without purchase (Issue #30, A4)

/// Ein aus dem Banner „Zeit zum Nachkaufen“ übernommener Vorschlag: Name und der Termin, für
/// den er vorgeschlagen wurde (gleiches Format wie `dismissedReplenishments` in `HomeView`).
struct AcceptedReplenishment: Codable, Equatable {
    let itemName: String
    let estimatedNextPurchaseDate: TimeInterval
}

enum ReplenishmentFeedback {
    /// Erkennt übernommene Vorschläge, deren `ShoppingItem` ohne Kauf wieder verschwunden ist,
    /// und wertet sie wie ✕ im Banner. Bewusst hier zentral statt an jeder Löschstelle
    /// (Swipe, Bearbeiten, „Erledigte löschen“, Sync von geteilten Listen …): entscheidend ist
    /// nur, dass das Item weg ist und sich der errechnete Termin nicht verschoben hat.
    ///
    /// - Item existiert noch (offen oder abgehakt) → weiter beobachten.
    /// - Item weg, aber ein anderes offenes Item gleichen Namens steht auf einer Liste → nicht
    ///   mehr beobachten, kein Signal (der Artikel ist ja weiterhin eingeplant).
    /// - Item weg, Termin unverändert → Ablehnung für genau diesen Termin.
    /// - Item weg, Termin verschoben oder kein Vorschlag mehr → es wurde gekauft (abgehakt oder
    ///   per Bon), kein Signal.
    static func resolveAccepted(
        _ accepted: [UUID: AcceptedReplenishment],
        existingItemIDs: Set<UUID>,
        pendingNames: Set<String>,
        patterns: [ConsumptionPattern]
    ) -> (stillTracked: [UUID: AcceptedReplenishment], dismissals: [String: TimeInterval]) {
        let currentDates = Dictionary(
            patterns.map { ($0.itemName.lowercased(), $0.estimatedNextPurchaseDate.timeIntervalSince1970) },
            uniquingKeysWith: { first, _ in first }
        )
        var stillTracked: [UUID: AcceptedReplenishment] = [:]
        var dismissals: [String: TimeInterval] = [:]
        for (id, entry) in accepted {
            if existingItemIDs.contains(id) {
                stillTracked[id] = entry
                continue
            }
            let key = entry.itemName.lowercased()
            guard !pendingNames.contains(key) else { continue }
            if currentDates[key] == entry.estimatedNextPurchaseDate {
                dismissals[key] = entry.estimatedNextPurchaseDate
            }
        }
        return (stillTracked, dismissals)
    }
}
