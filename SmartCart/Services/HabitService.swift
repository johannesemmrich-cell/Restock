import Foundation
import SwiftData

struct HabitService {

    // MARK: Eligibility (Issue #30, B2/B4)

    /// B2: Erst ab 3 Kauftagen gibt es genug Abstände, um Regelmäßigkeit zu beurteilen.
    static let minimumPurchases = 3
    /// B2: Schwanken die Abstände stärker (Standardabweichung > 50 % des Mittelwerts), ist der
    /// Artikel zu unregelmäßig für einen Vorschlag. Gilt nicht im Wochentagsmodus — Mo + Mi
    /// schwankt zwischen 2 und 5 Tagen und ist trotzdem völlig regelmäßig.
    static let maximumIntervalVariation = 0.5
    /// B4: Ohne Kauf über das 2,5-fache des üblichen Abstands gilt die Gewohnheit als beendet.
    static let habitEndedFactor = 2.5

    enum Ineligibility: Equatable {
        case tooFewPurchases
        case irregular
        case habitEnded
    }

    static func ineligibility(of pattern: ConsumptionPattern, at now: Date = Date()) -> Ineligibility? {
        guard pattern.purchaseCount >= minimumPurchases else { return .tooFewPurchases }
        if pattern.mode == .interval && pattern.intervalVariation > maximumIntervalVariation {
            return .irregular
        }
        // Der aktuelle Zyklus kann länger sein als der übliche Abstand (großer letzter Einkauf,
        // B5) — dann verschiebt sich auch das Ende der Gewohnheit entsprechend.
        let gap = max(pattern.typicalGapDays, pattern.averageDaysBetweenPurchases, pattern.cycleDays)
        if now.timeIntervalSince(pattern.lastPurchaseDate) / 86400 > habitEndedFactor * gap {
            return .habitEnded
        }
        return nil
    }

    static func isEligible(_ pattern: ConsumptionPattern, at now: Date = Date()) -> Bool {
        ineligibility(of: pattern, at: now) == nil
    }

    // MARK: Patterns

    /// Ein Muster pro Artikel (Name ohne Groß-/Kleinschreibung), unabhängig davon, ob es gerade
    /// vorgeschlagen würde.
    static func patterns(
        allRecords: [PurchaseRecord],
        closedDays: RetailClosedDays = .current,
        calendar: Calendar = .current
    ) -> [ConsumptionPattern] {
        let grouped = Dictionary(grouping: allRecords) { $0.itemName.lowercased() }
        return grouped.values.compactMap { records in
            records.consumptionPattern(closedDays: closedDays, calendar: calendar)
        }
    }

    // Analyzes purchase records across all items and returns patterns for items
    // that are due for repurchase
    static func dueSoonItems(
        allRecords: [PurchaseRecord],
        now: Date = Date(),
        closedDays: RetailClosedDays = .current
    ) -> [ConsumptionPattern] {
        patterns(allRecords: allRecords, closedDays: closedDays).filter {
            isEligible($0, at: now) && ($0.isDueSoon(at: now) || $0.isOverdue(at: now))
        }
    }

    // MARK: Backtest (Issue #30, D1)

    /// Spielt die Vorhersage rückwirkend über die vorhandene Historie durch: für jeden Kauf, vor
    /// dem es schon genug Käufe gab, wird aus den früheren Käufen der Termin errechnet und mit
    /// dem tatsächlichen Kaufdatum verglichen. Braucht keine zusätzliche Protokollierung und
    /// liefert sofort Werte, auch für Käufe von vor dieser Änderung.
    static func backtest(
        allRecords: [PurchaseRecord],
        closedDays: RetailClosedDays = .current,
        calendar: Calendar = .current
    ) -> ReplenishmentBacktest {
        var result = ReplenishmentBacktest()
        let grouped = Dictionary(grouping: allRecords) { $0.itemName.lowercased() }
        for records in grouped.values {
            let days = PurchaseDay.collapse(records, calendar: calendar)
            guard days.count > minimumPurchases else { continue }
            for index in minimumPurchases..<days.count {
                let purchase = days[index].date
                let cutoff = calendar.startOfDay(for: purchase)
                guard let pattern = records.filter({ $0.date < cutoff })
                    .consumptionPattern(closedDays: closedDays, calendar: calendar) else { continue }
                result.evaluated += 1
                guard isEligible(pattern, at: purchase) else { continue }
                result.covered += 1
                let errorDays = purchase.timeIntervalSince(pattern.estimatedNextPurchaseDate) / 86400
                result.absoluteErrorDays += abs(errorDays)
                // Halber Tag Toleranz: Termin und Kauf haben unterschiedliche Uhrzeiten.
                if abs(errorDays) <= Double(pattern.dueWindowDays) + 0.5 {
                    result.withinWindow += 1
                }
            }
        }
        return result
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

// MARK: - Measurement (Issue #30, D1)

struct ReplenishmentBacktest: Equatable {
    /// Käufe, vor denen es schon mindestens `HabitService.minimumPurchases` Kauftage gab.
    var evaluated = 0
    /// Davon: Der Artikel wäre zu diesem Zeitpunkt vorschlagbar gewesen (Abdeckung).
    var covered = 0
    /// Davon: Der Kauf lag im Vorschlagsfenster um den errechneten Termin (Treffer).
    var withinWindow = 0
    /// Summe der Abweichungen |Kauf − Termin| in Tagen über alle abgedeckten Käufe.
    var absoluteErrorDays = 0.0

    var meanAbsoluteErrorDays: Double? {
        covered > 0 ? absoluteErrorDays / Double(covered) : nil
    }
}

/// Zählt, wie Nutzer auf Vorschläge im Banner reagieren. Nur lokal (UserDefaults) und nur für
/// den Developer Mode gedacht — Grundlage, um Schwellenwerte mit Daten statt nach Gefühl
/// einzustellen.
struct ReplenishmentMetrics {
    enum Event: String, CaseIterable {
        /// Ein Vorschlag (Artikel + Termin) erschien im Banner — jeder nur einmal gezählt.
        case shown
        /// Per `+` oder „Alle hinzufügen“ übernommen.
        case accepted
        /// Per ✕ weggeklickt.
        case dismissed
        /// Übernommen und ohne Kauf wieder von der Liste gelöscht (A4).
        case removedAfterAccept
    }

    static let countsKey = "replenishmentMetricsCounts"
    static let shownKey = "replenishmentMetricsShown"
    /// Gezeigte Vorschläge werden so lange gemerkt, damit derselbe nicht doppelt zählt.
    static let shownRetention: TimeInterval = 180 * 86400

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func count(_ event: Event) -> Int {
        counts()[event.rawValue] ?? 0
    }

    func record(_ event: Event, times: Int = 1) {
        guard times > 0 else { return }
        var map = counts()
        map[event.rawValue, default: 0] += times
        defaults.set(map, forKey: Self.countsKey)
    }

    func recordShown(_ patterns: [ConsumptionPattern], now: Date = Date()) {
        var shown = defaults.dictionary(forKey: Self.shownKey) as? [String: TimeInterval] ?? [:]
        shown = shown.filter { now.timeIntervalSince1970 - $0.value < Self.shownRetention }
        var newlyShown = 0
        for pattern in patterns {
            let key = "\(pattern.itemName.lowercased())|\(pattern.estimatedNextPurchaseDate.timeIntervalSince1970)"
            guard shown[key] == nil else { continue }
            shown[key] = now.timeIntervalSince1970
            newlyShown += 1
        }
        defaults.set(shown, forKey: Self.shownKey)
        record(.shown, times: newlyShown)
    }

    func reset() {
        defaults.removeObject(forKey: Self.countsKey)
        defaults.removeObject(forKey: Self.shownKey)
    }

    private func counts() -> [String: Int] {
        defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
    }
}

// MARK: - Explanation (Issue #30, 4a)

extension ConsumptionPattern {
    /// Warum der Artikel vorgeschlagen wird: „meist Mo. und Mi.“ bzw. „etwa alle 7 Tage“.
    var reasonText: String {
        switch mode {
        case .weekdays(let weekdays):
            let symbols = Calendar.current.shortWeekdaySymbols
            // Montag zuerst, Sonntag zuletzt (Calendar-Wochentage: 1 = Sonntag, 2 = Montag …).
            let names = weekdays
                .sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }
                .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            return String(
                format: String(localized: "replenish.reason.weekdays"),
                ListFormatter.localizedString(byJoining: names)
            )
        case .interval:
            let days = Int(averageDaysBetweenPurchases.rounded())
            guard days > 1 else { return String(localized: "replenish.reason.daily") }
            return String(format: String(localized: "replenish.reason.interval"), days)
        }
    }
}
