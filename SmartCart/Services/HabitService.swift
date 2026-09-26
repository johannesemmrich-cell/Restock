import Foundation
import SwiftData

// MARK: - Gleichwertige Namen (Issue #30, C5)

/// Legt fest, welche Kaufdatensätze zum selben Artikel gehören. Bewusst eng gefasst (Korrektur
/// zu C5 in Issue #30): zusammengeführt werden nur Schreibvarianten DESSELBEN Produkts, nie
/// ähnliche oder verwandte. „Milch“, „H-Milch“, „Hafermilch“ und „Buttermilch“ bleiben getrennt —
/// ein fälschlich zusammengeführter Artikel verfälscht die Vorhersage beider, ein nicht
/// zusammengeführter verliert nur einzelne Käufe. Genau zwei Fälle zählen:
/// 1. Vom Nutzer bestätigte Bon-Zuordnungen (`ReceiptAliasService`): Wer „MILCH 1,5% 1L“ im
///    Bon-Prüfscreen einmal als „Milch“ gespeichert hat, dessen ältere Datensätze mit dem rohen
///    Bon-Text zählen ab dann zu „Milch“. Nur eine Stufe, keine Ketten.
/// 2. Rein formale Unterschiede (`formalKey`): Groß-/Kleinschreibung, überzählige Leerzeichen und
///    Satzzeichen am Rand.
/// Kein Fuzzy-Matching, keine KI, keine Präfix- oder Wortstamm-Regeln.
struct ReplenishmentItemIdentity {
    /// Bestätigter Artikelname für einen Namen, falls er als Bon-Text gelernt wurde.
    let resolveAlias: (String) -> String?

    /// Mit den gelernten Bon-Zuordnungen der App.
    static var current: ReplenishmentItemIdentity {
        ReplenishmentItemIdentity { ReceiptAliasService.shared.resolve($0) }
    }

    /// Nur formale Unterschiede, ohne Bon-Zuordnungen.
    static let formalOnly = ReplenishmentItemIdentity { _ in nil }

    /// Satzzeichen, die nur am Rand ignoriert werden. Bewusst ohne Klammern, `%` und Ziffern —
    /// „Eier (10)“ oder „Milch 1,5%“ tragen dort Inhalt. Im Wortinneren bleibt alles stehen:
    /// „H-Milch“ ist nicht „H Milch“ und schon gar nicht „Milch“.
    private static let edgeCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ".,;:!?*-–—\"'„“”‚‘’"))

    /// Schlüssel für rein formale Unterschiede: klein geschrieben, Leerzeichenfolgen zu einem
    /// Leerzeichen, Leerzeichen und Satzzeichen am Rand entfernt. Alle gespeicherten Nachkauf-
    /// Einträge (Ablehnung, „Hab noch“, Sperrliste, Nachrichten, D1) hängen an diesem Schlüssel
    /// des angezeigten Namens. Für Namen ohne solche Unterschiede ist er identisch mit dem
    /// früheren `lowercased()`, bestehende Einträge bleiben also gültig.
    static func formalKey(_ name: String) -> String {
        let collapsed = name.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: edgeCharacters)
        return trimmed.isEmpty ? collapsed : trimmed
    }

    /// Name, unter dem ein Kauf gezählt wird: die bestätigte Bon-Zuordnung, sonst der Name selbst
    /// (ohne Leerzeichen am Rand).
    func canonicalName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let alias = resolveAlias(trimmed)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !alias.isEmpty else { return trimmed }
        return alias
    }

    /// Artikelschlüssel für einen beliebigen Namen (Kaufdatensatz oder offener Listenartikel).
    func key(_ name: String) -> String {
        Self.formalKey(canonicalName(name))
    }

    /// Kaufdatensätze nach Artikel gruppiert. Angezeigt wird ein Artikel unter dem Namen seines
    /// jüngsten Kaufs (nach Bon-Zuordnung) — dessen `formalKey` ist immer der Gruppenschlüssel.
    func group(_ records: [PurchaseRecord]) -> [(name: String, records: [PurchaseRecord])] {
        Dictionary(grouping: records) { key($0.itemName) }.values.compactMap { members -> (name: String, records: [PurchaseRecord])? in
            guard let latest = members.max(by: { $0.date < $1.date }) else { return nil }
            return (name: canonicalName(latest.itemName), records: members)
        }
    }
}

extension ConsumptionPattern {
    /// Artikelschlüssel (C5) — ersetzt das frühere `itemName.lowercased()`.
    var itemKey: String { ReplenishmentItemIdentity.formalKey(itemName) }
}

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

    /// Ein Muster pro Artikel (gleichwertige Namen zusammengeführt, C5), unabhängig davon, ob
    /// es gerade vorgeschlagen würde.
    static func patterns(
        allRecords: [PurchaseRecord],
        closedDays: RetailClosedDays = .current,
        calendar: Calendar = .current,
        identity: ReplenishmentItemIdentity = .current
    ) -> [ConsumptionPattern] {
        identity.group(allRecords).compactMap { group in
            group.records.consumptionPattern(itemName: group.name, closedDays: closedDays, calendar: calendar)
        }
    }

    // Analyzes purchase records across all items and returns patterns for items
    // that are due for repurchase
    static func dueSoonItems(
        allRecords: [PurchaseRecord],
        now: Date = Date(),
        closedDays: RetailClosedDays = .current,
        identity: ReplenishmentItemIdentity = .current,
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = []
    ) -> [ConsumptionPattern] {
        dueSoonItems(
            from: patterns(allRecords: allRecords, closedDays: closedDays, identity: identity),
            now: now,
            snoozes: snoozes,
            blocked: blocked
        )
    }

    /// C1: Artikel aus `blocked` („Nicht mehr vorschlagen“, Schlüssel `itemKey`) fallen
    /// ganz weg; gilt für einen Artikel noch ein „Hab noch“, zählt dessen verschobener Termin.
    /// Die Eignung (B2/B4) wird weiterhin am errechneten Termin gemessen.
    static func dueSoonItems(
        from patterns: [ConsumptionPattern],
        now: Date = Date(),
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = []
    ) -> [ConsumptionPattern] {
        suggestionCandidates(from: patterns, snoozes: snoozes, blocked: blocked).filter { pattern in
            isEligible(pattern, at: now) && (pattern.isDueSoon(at: now) || pattern.isOverdue(at: now))
        }
    }

    /// Alle Muster ohne „Nicht mehr vorschlagen“, mit „Hab noch“ — noch ohne Eignung und
    /// Zeitfenster. Eine Verschiebung ändert die Eignung nicht (`cycleDays` geht vom errechneten
    /// Termin aus).
    static func suggestionCandidates(
        from patterns: [ConsumptionPattern],
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = []
    ) -> [ConsumptionPattern] {
        patterns.compactMap { pattern in
            let key = pattern.itemKey
            guard !blocked.contains(key) else { return nil }
            return snoozes[key].map { pattern.applying($0) } ?? pattern
        }
    }

    /// C3: Artikel, die in einer Sammelnachricht vorkommen dürfen — wie das Banner ohne
    /// abgelehnte Vorschläge (A4, `dismissed`: `itemKey` → `purchaseKey`) und ohne Artikel, die
    /// schon offen auf einer Liste stehen (`pendingNames`: `ReplenishmentItemIdentity.key`), aber
    /// unabhängig vom Zeitfenster: Die Nachricht für einen erst in fünf Tagen fälligen Artikel
    /// wird schon jetzt geplant.
    static func notificationCandidates(
        from patterns: [ConsumptionPattern],
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = [],
        dismissed: [String: TimeInterval] = [:],
        pendingNames: Set<String> = []
    ) -> [ConsumptionPattern] {
        suggestionCandidates(from: patterns, snoozes: snoozes, blocked: blocked).filter { pattern in
            let key = pattern.itemKey
            return !pendingNames.contains(key) && dismissed[key] != pattern.purchaseKey
        }
    }

    // MARK: Before the next store visit (Issue #30, C4)

    /// C4: „Vielleicht auch fällig“ in einer Ladenliste — Artikel dieses Ladens, die vor dem
    /// nächsten Besuch dort ausgehen. Wer die Liste öffnet, plant den Einkauf, der gerade ansteht;
    /// ein Artikel, der vor dem Besuch danach (jetzt + `visitGapDays`) ausgeht, gehört also schon
    /// auf diesen Einkauf. Zusätzlich alles, was auch das Banner zeigt (Fenster oder überfällig),
    /// damit die Ladenliste nie weniger vorschlägt als der Startbildschirm.
    ///
    /// Filter wie `notificationCandidates` (Sperrliste, „Hab noch“, A4-Ablehnung, schon offen)
    /// plus Eignung (B2/B4). `belongsToStore` entscheidet, ob ein Artikel zu diesem Laden gehört
    /// (in der App: `AssignmentService.assign`, also derselbe Laden, in den `+` im Banner ihn legt).
    static func dueBeforeNextVisit(
        from patterns: [ConsumptionPattern],
        visitGapDays: Double,
        now: Date = Date(),
        calendar: Calendar = .current,
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = [],
        dismissed: [String: TimeInterval] = [:],
        pendingNames: Set<String> = [],
        belongsToStore: (ConsumptionPattern) -> Bool
    ) -> [ConsumptionPattern] {
        let nextVisit = StoreVisitForecast.nextVisit(after: now, gapDays: visitGapDays, calendar: calendar)
        let nextVisitDay = calendar.startOfDay(for: nextVisit)
        return notificationCandidates(
            from: patterns,
            snoozes: snoozes,
            blocked: blocked,
            dismissed: dismissed,
            pendingNames: pendingNames
        )
        .filter { pattern in
            guard isEligible(pattern, at: now) else { return false }
            let runsOutBeforeVisit = calendar.startOfDay(for: pattern.estimatedNextPurchaseDate) < nextVisitDay
            guard runsOutBeforeVisit || pattern.isDueSoon(at: now) || pattern.isOverdue(at: now) else { return false }
            return belongsToStore(pattern)
        }
        .sorted { $0.estimatedNextPurchaseDate < $1.estimatedNextPurchaseDate }
    }

    // MARK: Backtest (Issue #30, D1)

    /// Spielt die Vorhersage rückwirkend über die vorhandene Historie durch: für jeden Kauf, vor
    /// dem es schon genug Käufe gab, wird aus den früheren Käufen der Termin errechnet und mit
    /// dem tatsächlichen Kaufdatum verglichen. Braucht keine zusätzliche Protokollierung und
    /// liefert sofort Werte, auch für Käufe von vor dieser Änderung.
    static func backtest(
        allRecords: [PurchaseRecord],
        closedDays: RetailClosedDays = .current,
        calendar: Calendar = .current,
        identity: ReplenishmentItemIdentity = .current
    ) -> ReplenishmentBacktest {
        var result = ReplenishmentBacktest()
        for (_, records) in identity.group(allRecords) {
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
    static func preferredStore(
        for itemName: String,
        allRecords: [PurchaseRecord],
        stores: [Store],
        identity: ReplenishmentItemIdentity = .current
    ) -> Store? {
        let key = identity.key(itemName)
        let relevantRecords = allRecords.filter { identity.key($0.itemName) == key }
        guard !relevantRecords.isEmpty else { return nil }

        let storeCounts = Dictionary(grouping: relevantRecords) { $0.storeName }
            .mapValues { $0.count }
        guard let preferredStoreName = storeCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        return stores.first { $0.name == preferredStoreName }
    }

    /// Plant die Sammelnachrichten neu (C3). `candidates` aus `notificationCandidates`.
    static func scheduleReplenishmentNotifications(candidates: [ConsumptionPattern]) {
        Task {
            await NotificationService.shared.scheduleReplenishmentDigests(candidates: candidates)
        }
    }
}

// MARK: - Overdue push deduplication (Issue #30, A3)

/// Merkt sich pro Artikel, für welchen Kaufzyklus (`ConsumptionPattern.notificationKey`) bereits
/// eine Push-Nachricht verschickt wurde. Vorher löste jedes `refreshDueSoon()` (App-Start, jede
/// Änderung an offenen Artikeln oder Kaufdatensätzen) für jeden überfälligen Artikel eine neue
/// Nachricht aus. Jetzt höchstens einmal pro Artikel und Zyklus: erst ein neuer Kauf (oder ein
/// „Hab noch“, C1) macht den Artikel wieder meldefähig — ein Wechsel von Land oder Zeitzone, der
/// nur den errechneten Termin verschiebt, dagegen nicht. Seit C3 gilt das für jede Nachricht,
/// nicht nur für überfällige Artikel; Name und Schlüssel bleiben für bestehende Einträge gleich.
/// Eingetragen wird erst nach der Zustellzeit (`ReplenishmentDigestLog.commitDelivered`). Ein
/// Eintrag pro Artikelname wird überschrieben, nie angehängt — die Map wächst also nur mit der
/// Zahl verschiedener Artikel.
struct OverdueNotificationLedger {
    static let defaultsKey = "notifiedOverdueReplenishments"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldNotify(_ pattern: ConsumptionPattern) -> Bool {
        notified()[pattern.itemKey] != pattern.notificationKey
    }

    func markNotified(_ pattern: ConsumptionPattern) {
        markNotified(itemName: pattern.itemName, notificationKey: pattern.notificationKey)
    }

    func markNotified(itemName: String, notificationKey: TimeInterval) {
        var map = notified()
        map[ReplenishmentItemIdentity.formalKey(itemName)] = notificationKey
        defaults.set(map, forKey: Self.defaultsKey)
    }

    private func notified() -> [String: TimeInterval] {
        defaults.dictionary(forKey: Self.defaultsKey) as? [String: TimeInterval] ?? [:]
    }
}

// MARK: - Accepted suggestions removed without purchase (Issue #30, A4)

/// Ein aus dem Banner „Zeit zum Nachkaufen“ übernommener Vorschlag: Name und der Kaufzyklus
/// (`ConsumptionPattern.purchaseKey`), für den er vorgeschlagen wurde (gleiches Format wie
/// `dismissedReplenishments` in `HomeView`).
struct AcceptedReplenishment: Codable, Equatable {
    let itemName: String
    let purchaseKey: TimeInterval
}

enum ReplenishmentFeedback {
    /// Abgelehnte Vorschläge (A4) wie in `HomeView` per `@AppStorage` gespeichert: `itemKey` →
    /// `purchaseKey`.
    static func storedDismissals(defaults: UserDefaults = .standard) -> [String: TimeInterval] {
        guard let data = defaults.data(forKey: ReplenishmentKeyMigration.dismissedKey) else { return [:] }
        return (try? JSONDecoder().decode([String: TimeInterval].self, from: data)) ?? [:]
    }

    /// Merkt sich ein aus einem Vorschlag angelegtes `ShoppingItem` für A4 und zählt die Übernahme
    /// (D1). Gemeinsam für das Banner (`HomeView`) und „Vielleicht auch fällig“ (C4,
    /// `StoreDetailView`) — `HomeView` beobachtet denselben Schlüssel per `@AppStorage`.
    static func trackAccepted(itemID: UUID, from pattern: ConsumptionPattern, defaults: UserDefaults = .standard) {
        var accepted: [UUID: AcceptedReplenishment] = [:]
        if let data = defaults.data(forKey: ReplenishmentKeyMigration.acceptedKey) {
            accepted = (try? JSONDecoder().decode([UUID: AcceptedReplenishment].self, from: data)) ?? [:]
        }
        accepted[itemID] = AcceptedReplenishment(itemName: pattern.itemName, purchaseKey: pattern.purchaseKey)
        defaults.set(try? JSONEncoder().encode(accepted), forKey: ReplenishmentKeyMigration.acceptedKey)
        ReplenishmentMetrics(defaults: defaults).record(.accepted)
    }

    /// Erkennt übernommene Vorschläge, deren `ShoppingItem` ohne Kauf wieder verschwunden ist,
    /// und wertet sie wie ✕ im Banner. Bewusst hier zentral statt an jeder Löschstelle
    /// (Swipe, Bearbeiten, „Erledigte löschen“, Sync von geteilten Listen …): entscheidend ist
    /// nur, dass das Item weg ist und es seitdem keinen neuen Kauf gab.
    ///
    /// - Item existiert noch (offen oder abgehakt) → weiter beobachten.
    /// - Item weg, aber ein anderes offenes Item gleichen Namens steht auf einer Liste → nicht
    ///   mehr beobachten, kein Signal (der Artikel ist ja weiterhin eingeplant).
    /// - Item weg, letzter Kauf unverändert → Ablehnung für genau diesen Kaufzyklus.
    /// - Item weg, neuer Kauf oder kein Vorschlag mehr → es wurde gekauft (abgehakt oder per
    ///   Bon), kein Signal.
    static func resolveAccepted(
        _ accepted: [UUID: AcceptedReplenishment],
        existingItemIDs: Set<UUID>,
        pendingNames: Set<String>,
        patterns: [ConsumptionPattern]
    ) -> (stillTracked: [UUID: AcceptedReplenishment], dismissals: [String: TimeInterval]) {
        let currentKeys = Dictionary(
            patterns.map { ($0.itemKey, $0.purchaseKey) },
            uniquingKeysWith: { first, _ in first }
        )
        var stillTracked: [UUID: AcceptedReplenishment] = [:]
        var dismissals: [String: TimeInterval] = [:]
        for (id, entry) in accepted {
            if existingItemIDs.contains(id) {
                stillTracked[id] = entry
                continue
            }
            let key = ReplenishmentItemIdentity.formalKey(entry.itemName)
            guard !pendingNames.contains(key) else { continue }
            if currentKeys[key] == entry.purchaseKey {
                dismissals[key] = entry.purchaseKey
            }
        }
        return (stillTracked, dismissals)
    }
}

extension ConsumptionPattern {
    /// B5: Ein übernommener Vorschlag kommt mit typischer Menge und Einheit auf die Liste statt
    /// immer mit 1. Für das Banner und „Vielleicht auch fällig“ (C4).
    func makeReplenishmentItem(store: Store?) -> ShoppingItem {
        let amount = typicalQuantity > 0 ? typicalQuantity : 1
        let quantity = amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
        return ShoppingItem(
            name: itemName,
            category: AssignmentService.category(for: itemName),
            quantity: quantity,
            quantityAmount: amount,
            unit: unit,
            store: store
        )
    }
}

// MARK: - Next store visit (Issue #30, C4)

/// Schätzt, wann ein Laden das nächste Mal besucht wird — Grundlage für „Vielleicht auch
/// fällig“ in der Ladenliste.
enum StoreVisitForecast {
    /// Ab so vielen verschiedenen Einkaufstagen in diesem Laden zählt die Historie statt der
    /// Einstellung „Besuchshäufigkeit“ (`Store.visitsPerWeek`).
    static let minimumVisitDays = 3
    /// Nur die letzten Einkaufstage zählen, damit sich ein geänderter Rhythmus schnell auswirkt.
    static let recentVisitDays = 8
    /// Ein Abstand unter 1 Tag ergäbe nie einen Vorschlag über das Banner hinaus, über 4 Wochen
    /// würde fast alles vorgeschlagen.
    static let gapRange: ClosedRange<Double> = 1...28

    /// Üblicher Abstand zwischen zwei Besuchen in Tagen: Median der Abstände zwischen den
    /// letzten Einkaufstagen (mehrere Käufe an einem Tag sind ein Besuch). Mit zu wenig
    /// Historie aus der eingestellten Besuchshäufigkeit.
    /// - Parameter purchaseDates: Kaufzeitpunkte aller `PurchaseRecord`s dieses Ladens.
    static func visitGapDays(purchaseDates: [Date], visitsPerWeek: Double, calendar: Calendar = .current) -> Double {
        let visitDays = Set(purchaseDates.map { calendar.startOfDay(for: $0) }).sorted().suffix(recentVisitDays)
        let gap: Double
        if visitDays.count >= minimumVisitDays {
            let gaps = zip(visitDays, visitDays.dropFirst())
                .map { ($1.timeIntervalSince($0) / 86400).rounded() }
                .sorted()
            let middle = gaps.count / 2
            gap = gaps.count % 2 == 0 ? (gaps[middle - 1] + gaps[middle]) / 2 : gaps[middle]
        } else {
            gap = visitsPerWeek > 0 ? 7 / visitsPerWeek : 7
        }
        return min(gapRange.upperBound, max(gapRange.lowerBound, gap))
    }

    /// Nächster Besuch nach dem gerade geplanten Einkauf.
    static func nextVisit(after now: Date, gapDays: Double, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: Int(gapDays.rounded()), to: now)
            ?? now.addingTimeInterval(gapDays.rounded() * 86400)
    }
}

// MARK: - „Hab noch“ und „Nicht mehr vorschlagen“ (Issue #30, C1)

/// Eine „Hab noch“-Verschiebung. Sie gilt nur, solange der letzte Kauf des Artikels noch
/// `purchaseKey` ist — der nächste Kauf beendet sie.
struct ReplenishmentSnooze: Codable, Equatable {
    /// Artikelname wie im Banner (für die Anzeige in den Einstellungen).
    let itemName: String
    /// Kaufzyklus, für den die Verschiebung gilt (`ConsumptionPattern.purchaseKey`).
    let purchaseKey: TimeInterval
    /// Verschobener Termin (`timeIntervalSince1970`).
    let snoozedUntil: TimeInterval
}

extension ConsumptionPattern {
    /// Kennzeichnet eine Nachricht (A3/C3): ohne „Hab noch“ der Kaufzyklus (`purchaseKey`), mit
    /// „Hab noch“ der gespeicherte verschobene Termin — so kommt am verschobenen Termin noch
    /// einmal eine Nachricht, und jedes weitere „Hab noch“ erlaubt wieder eine. Beide Werte sind
    /// gespeichert statt errechnet und verschieben sich deshalb nicht mit Land oder Zeitzone.
    var notificationKey: TimeInterval {
        isSnoozed ? estimatedNextPurchaseDate.timeIntervalSince1970 : purchaseKey
    }

    /// Übernimmt eine „Hab noch“-Verschiebung, sofern sie noch zu diesem Kaufzyklus gehört.
    func applying(_ snooze: ReplenishmentSnooze) -> ConsumptionPattern {
        guard snooze.purchaseKey == purchaseKey else { return self }
        var copy = self
        copy.originalEstimatedDate = baseEstimatedDate
        copy.estimatedNextPurchaseDate = Date(timeIntervalSince1970: snooze.snoozedUntil)
        return copy
    }
}

/// „Hab noch“ im Banner: verschiebt den Termin um die Hälfte des üblichen Abstands, mindestens
/// 1 und höchstens 14 Tage (Entscheidung in Issue #30, Teil 4). Erneutes „Hab noch“ verschiebt
/// nochmals um die Hälfte. Aus wiederholtem „Hab noch“ wird (noch) nicht gelernt.
struct ReplenishmentSnoozes {
    static let defaultsKey = "snoozedReplenishments"
    static let minimumShiftDays = 1
    static let maximumShiftDays = 14

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func shiftDays(for pattern: ConsumptionPattern) -> Int {
        let half = Int((pattern.averageDaysBetweenPurchases / 2).rounded())
        return max(minimumShiftDays, min(maximumShiftDays, half))
    }

    /// `itemKey` → Verschiebung.
    func entries() -> [String: ReplenishmentSnooze] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ReplenishmentSnooze].self, from: data)) ?? [:]
    }

    /// Verschiebt ab dem angezeigten Termin — bei einem überfälligen Artikel ab jetzt, sonst
    /// stünde er sofort wieder im Banner. Ein Sonntag/Feiertag wird wie in 4b auf den Tag davor
    /// vorgezogen, aber nie auf oder vor den Ausgangstag.
    ///
    /// - Parameter notBefore: frühester verschobener Termin. C4: „Hab noch“ in einer Ladenliste
    ///   heißt „reicht bis zum nächsten Besuch“ — sonst stünde der Artikel dort sofort wieder unter
    ///   „Vielleicht auch fällig“.
    @discardableResult
    func snooze(
        _ pattern: ConsumptionPattern,
        now: Date = Date(),
        notBefore: Date? = nil,
        closedDays: RetailClosedDays = .current,
        calendar: Calendar = .current
    ) -> Date {
        let start = max(pattern.estimatedNextPurchaseDate, now)
        let target = calendar.date(byAdding: .day, value: Self.shiftDays(for: pattern), to: start)
            ?? start.addingTimeInterval(Double(Self.shiftDays(for: pattern)) * 86400)
        var allowsSunday = false
        if case .weekdays(let weekdays) = pattern.mode { allowsSunday = weekdays.contains(1) }
        var until = closedDays.latestOpenDay(onOrBefore: target, after: start, allowSunday: allowsSunday, calendar: calendar)
        // Der Artikel erscheint wieder, sobald der verschobene Termin im Fenster liegt. Bei kurzen
        // Zyklen (Fenster 1 Tag, Verschiebung 1–2 Tage) oder nach dem Vorziehen vor einen
        // Sonntag läge er schon im Moment des Tippens wieder im Fenster und stünde sofort
        // wieder im Banner. Deshalb liegt der verschobene Termin immer mindestens Fenster + 2
        // Tage nach jetzt: so bleibt der Artikel mindestens einen Tag ausgeblendet.
        if let earliest = calendar.date(byAdding: .day, value: pattern.dueWindowDays + 2, to: now), until < earliest {
            until = closedDays.earliestOpenDay(onOrAfter: earliest, allowSunday: allowsSunday, calendar: calendar)
        }
        if let notBefore, calendar.startOfDay(for: until) < calendar.startOfDay(for: notBefore) {
            until = closedDays.earliestOpenDay(onOrAfter: notBefore, allowSunday: allowsSunday, calendar: calendar)
        }
        var map = entries()
        map[pattern.itemKey] = ReplenishmentSnooze(
            itemName: pattern.itemName,
            purchaseKey: pattern.purchaseKey,
            snoozedUntil: until.timeIntervalSince1970
        )
        persist(map)
        return until
    }

    func remove(_ itemName: String) {
        var map = entries()
        map[ReplenishmentItemIdentity.formalKey(itemName)] = nil
        persist(map)
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    /// Entfernt Verschiebungen, deren Kaufzyklus vorbei ist (Artikel inzwischen gekauft) oder
    /// deren Artikel gar kein Muster mehr ergibt.
    /// - Parameter patterns: alle Muster ohne Verschiebung (`HabitService.patterns`).
    func prune(keeping patterns: [ConsumptionPattern]) {
        let current = Dictionary(
            patterns.map { ($0.itemKey, $0.purchaseKey) },
            uniquingKeysWith: { first, _ in first }
        )
        let map = entries()
        let kept = map.filter { current[$0.key] == $0.value.purchaseKey }
        if kept.count != map.count { persist(kept) }
    }

    private func persist(_ map: [String: ReplenishmentSnooze]) {
        defaults.set(try? JSONEncoder().encode(map), forKey: Self.defaultsKey)
    }
}

/// „Nicht mehr vorschlagen“ im Banner: blendet einen Artikel dauerhaft aus, bis er in den
/// Einstellungen (Developer → Ausgeblendete Vorschläge) wieder freigegeben wird. Gespeichert als
/// JSON-`Data`, damit `HomeView` die Liste per `@AppStorage` beobachten kann.
struct ReplenishmentBlocklist {
    static let defaultsKey = "blockedReplenishments"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Artikelnamen wie beim Ausblenden angezeigt, alphabetisch.
    func names() -> [String] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Artikelschlüssel (`itemKey`), wie `HabitService.dueSoonItems(blocked:)` sie erwartet.
    var keys: Set<String> { Set(names().map(ReplenishmentItemIdentity.formalKey)) }

    func contains(_ itemName: String) -> Bool { keys.contains(ReplenishmentItemIdentity.formalKey(itemName)) }

    func block(_ itemName: String) {
        guard !contains(itemName) else { return }
        persist(names() + [itemName])
    }

    func unblock(_ itemName: String) {
        let key = ReplenishmentItemIdentity.formalKey(itemName)
        persist(names().filter { ReplenishmentItemIdentity.formalKey($0) != key })
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func persist(_ names: [String]) {
        defaults.set(try? JSONEncoder().encode(names), forKey: Self.defaultsKey)
    }
}

// MARK: - Migration: Termin → letzter Kauf (Issue #30, Teil 5, Punkt 1)

/// Bis zu dieser Version hingen Ablehnung (A4), „Hab noch“ (C1), die Überfällig-Nachricht (A3)
/// und die D1-Zählung „gezeigt“ am errechneten Termin, seitdem am letzten Kauf
/// (`ConsumptionPattern.purchaseKey`). Rechnet die gespeicherten Einträge einmalig um: Ein
/// Eintrag, dessen Termin noch dem aktuell errechneten entspricht, gehört zum laufenden
/// Kaufzyklus und bekommt dessen Schlüssel; alle anderen waren ohnehin schon abgelaufen und
/// entfallen (bei „gezeigt“ bleiben sie mit ihrem alten Schlüssel liegen, bis sie verfallen).
enum ReplenishmentKeyMigration {
    static let doneKey = "replenishmentKeysByPurchaseDate"
    static let dismissedKey = "dismissedReplenishments"
    static let acceptedKey = "acceptedReplenishments"

    private struct LegacySnooze: Decodable {
        let itemName: String
        let baseDate: TimeInterval
        let snoozedUntil: TimeInterval
    }

    private struct LegacyAccepted: Decodable {
        let itemName: String
        let estimatedNextPurchaseDate: TimeInterval
    }

    /// - Parameter patterns: alle Muster ohne Verschiebung (`HabitService.patterns`), mit
    ///   denselben Schließtagen und demselben Kalender gerechnet wie vor dem Update.
    static func runIfNeeded(patterns: [ConsumptionPattern], defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }
        var current: [String: (estimated: TimeInterval, purchase: TimeInterval)] = [:]
        for pattern in patterns where current[pattern.itemName.lowercased()] == nil {
            current[pattern.itemName.lowercased()] = (
                pattern.estimatedNextPurchaseDate.timeIntervalSince1970,
                pattern.purchaseKey
            )
        }
        func key(for itemKey: String, estimated: TimeInterval) -> TimeInterval? {
            guard let entry = current[itemKey], entry.estimated == estimated else { return nil }
            return entry.purchase
        }

        if let data = defaults.data(forKey: dismissedKey),
           let map = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            var migrated: [String: TimeInterval] = [:]
            for (name, estimated) in map {
                if let purchase = key(for: name, estimated: estimated) { migrated[name] = purchase }
            }
            defaults.set(try? JSONEncoder().encode(migrated), forKey: dismissedKey)
        }

        if let map = defaults.dictionary(forKey: OverdueNotificationLedger.defaultsKey) as? [String: TimeInterval] {
            var migrated: [String: TimeInterval] = [:]
            for (name, estimated) in map {
                if let purchase = key(for: name, estimated: estimated) { migrated[name] = purchase }
            }
            defaults.set(migrated, forKey: OverdueNotificationLedger.defaultsKey)
        }

        if let data = defaults.data(forKey: ReplenishmentSnoozes.defaultsKey),
           let map = try? JSONDecoder().decode([String: LegacySnooze].self, from: data) {
            var migrated: [String: ReplenishmentSnooze] = [:]
            for (name, snooze) in map {
                guard let purchase = key(for: name, estimated: snooze.baseDate) else { continue }
                migrated[name] = ReplenishmentSnooze(
                    itemName: snooze.itemName,
                    purchaseKey: purchase,
                    snoozedUntil: snooze.snoozedUntil
                )
            }
            defaults.set(try? JSONEncoder().encode(migrated), forKey: ReplenishmentSnoozes.defaultsKey)
        }

        if let data = defaults.data(forKey: acceptedKey),
           let map = try? JSONDecoder().decode([UUID: LegacyAccepted].self, from: data) {
            var migrated: [UUID: AcceptedReplenishment] = [:]
            for (id, entry) in map {
                // Ein Eintrag ohne passenden Termin wurde inzwischen gekauft — `resolveAccepted`
                // hätte ihn beim nächsten Löschen ohnehin nicht als Ablehnung gewertet.
                guard let purchase = key(for: entry.itemName.lowercased(), estimated: entry.estimatedNextPurchaseDate) else { continue }
                migrated[id] = AcceptedReplenishment(itemName: entry.itemName, purchaseKey: purchase)
            }
            defaults.set(try? JSONEncoder().encode(migrated), forKey: acceptedKey)
        }

        if var shown = defaults.dictionary(forKey: ReplenishmentMetrics.shownKey) as? [String: TimeInterval] {
            for (oldKey, shownAt) in shown {
                guard let separator = oldKey.lastIndex(of: "|"),
                      let estimated = TimeInterval(oldKey[oldKey.index(after: separator)...]) else { continue }
                let itemKey = String(oldKey[..<separator])
                guard let purchase = key(for: itemKey, estimated: estimated) else { continue }
                shown[ReplenishmentMetrics.shownEntryKey(itemKey: itemKey, purchaseKey: purchase)] = shownAt
            }
            defaults.set(shown, forKey: ReplenishmentMetrics.shownKey)
        }

        defaults.set(true, forKey: doneKey)
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
        /// Ein Vorschlag (Artikel + Kaufzyklus) erschien im Banner — jeder nur einmal gezählt.
        case shown
        /// Per `+` oder „Alle hinzufügen“ übernommen.
        case accepted
        /// „Hab noch“ (C1).
        case snoozed
        /// „Nicht mehr vorschlagen“ (C1).
        case blocked
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
            let key = Self.shownEntryKey(itemKey: pattern.itemKey, purchaseKey: pattern.purchaseKey)
            guard shown[key] == nil else { continue }
            shown[key] = now.timeIntervalSince1970
            newlyShown += 1
        }
        defaults.set(shown, forKey: Self.shownKey)
        record(.shown, times: newlyShown)
    }

    static func shownEntryKey(itemKey: String, purchaseKey: TimeInterval) -> String {
        "\(itemKey)|\(purchaseKey)"
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
