import BackgroundTasks
import Foundation
import SwiftData

// MARK: - Gebündelte Nachkauf-Nachricht (Issue #30, C3)

/// Eine Sammelnachricht „Zeit zum Nachkaufen“: höchstens eine pro Tag, zur typischen
/// Einkaufszeit, mit allen Artikeln, die an diesem Tag fällig werden. Vorher gab es eine
/// Push-Nachricht pro Artikel und für überfällige Artikel zusätzlich eine sofortige.
struct ReplenishmentDigest: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let itemName: String
        /// `ConsumptionPattern.notificationKey` zum Zeitpunkt der Planung.
        let notificationKey: TimeInterval
    }

    let deliveryDate: Date
    let entries: [Entry]

    var itemNames: [String] { entries.map(\.itemName) }

    /// Ein Artikel: der bisherige Text mit Artikelname. Mehrere: Anzahl im Titel, die Namen als
    /// Aufzählung („Milch, Butter und Eier“) im Text.
    var title: String {
        guard entries.count > 1 else { return String(localized: "notification.replenish.title") }
        return String(format: String(localized: "notification.digest.title"), entries.count)
    }

    var body: String {
        guard entries.count > 1 else {
            return String(format: String(localized: "notification.replenish.body"), itemNames.first ?? "")
        }
        return ListFormatter.localizedString(byJoining: itemNames)
    }
}

enum ReplenishmentDigestPlanner {
    /// Uhrzeit der Sammelnachricht — dieselbe wie bisher bei der Nachricht am errechneten Tag.
    static let deliveryHour = 9
    /// So viele Tage im Voraus wird geplant. Den Rest übernimmt der nächste App-Start oder die
    /// Hintergrundaktualisierung (`ReplenishmentBackgroundRefresh`).
    static let horizonDays = 7

    /// Ordnet jeden Artikel der Sammelnachricht seines errechneten Tages zu. Ein Artikel, dessen
    /// Tag schon vorbei ist oder dessen Nachricht heute schon verschickt wurde, kommt in die
    /// nächste noch ausstehende — überfällige Artikel lösen also keine eigene, sofortige
    /// Nachricht mehr aus. Jeder Artikel wird pro Kaufzyklus nur einmal gemeldet (A3, siehe
    /// `OverdueNotificationLedger`), nach „Hab noch“ einmal mehr am verschobenen Termin.
    ///
    /// - Parameter candidates: alle Artikel, die vorgeschlagen werden dürften, unabhängig vom
    ///   Zeitfenster (`HabitService.notificationCandidates`). Die Eignung (B2/B4) wird hier am
    ///   Zustelltag geprüft: Endet die Gewohnheit vorher, gibt es keine Nachricht.
    static func plan(
        candidates: [ConsumptionPattern],
        ledger: OverdueNotificationLedger,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReplenishmentDigest] {
        guard let first = firstSlot(after: now, calendar: calendar),
              let last = calendar.date(byAdding: .day, value: horizonDays - 1, to: first) else { return [] }
        var bySlot: [Date: [ReplenishmentDigest.Entry]] = [:]
        for pattern in candidates where ledger.shouldNotify(pattern) {
            guard let due = slot(on: pattern.estimatedNextPurchaseDate, calendar: calendar) else { continue }
            let delivery = max(due, first)
            guard delivery <= last, HabitService.isEligible(pattern, at: delivery) else { continue }
            bySlot[delivery, default: []].append(
                ReplenishmentDigest.Entry(itemName: pattern.itemName, notificationKey: pattern.notificationKey)
            )
        }
        return bySlot.keys.sorted().map { date in
            let entries = (bySlot[date] ?? []).sorted {
                $0.itemName.localizedCaseInsensitiveCompare($1.itemName) == .orderedAscending
            }
            return ReplenishmentDigest(deliveryDate: date, entries: entries)
        }
    }

    static func slot(on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: deliveryHour, minute: 0, second: 0, of: day)
    }

    /// Die nächste Zustellzeit nach `now`: heute um 9 Uhr, wenn das noch bevorsteht, sonst morgen.
    static func firstSlot(after now: Date, calendar: Calendar) -> Date? {
        guard let today = slot(on: now, calendar: calendar) else { return nil }
        guard today <= now else { return today }
        return calendar.date(byAdding: .day, value: 1, to: today).flatMap { slot(on: $0, calendar: calendar) }
    }
}

/// Die zuletzt geplanten Sammelnachrichten. Ob eine Nachricht zugestellt wurde, erfährt die App
/// nicht — geplant ist aber nicht gleich verschickt: Jede Neuplanung ersetzt die noch
/// ausstehenden Nachrichten, und ein Artikel, der beim Planen schon als gemeldet gälte, fiele
/// dabei ganz heraus. Deshalb landet ein Artikel erst im `OverdueNotificationLedger`, wenn die
/// Zustellzeit seiner Nachricht vorbei ist (`commitDelivered`).
struct ReplenishmentDigestLog {
    static let defaultsKey = "scheduledReplenishmentDigests"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func planned() -> [ReplenishmentDigest] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([ReplenishmentDigest].self, from: data)) ?? []
    }

    func replace(with digests: [ReplenishmentDigest]) {
        defaults.set(try? JSONEncoder().encode(digests), forKey: Self.defaultsKey)
    }

    /// Überträgt alle Nachrichten, deren Zustellzeit vorbei ist, ins Ledger und vergisst sie.
    func commitDelivered(now: Date = Date(), to ledger: OverdueNotificationLedger) {
        let all = planned()
        let delivered = all.filter { $0.deliveryDate <= now }
        guard !delivered.isEmpty else { return }
        for digest in delivered {
            for entry in digest.entries {
                ledger.markNotified(itemName: entry.itemName, notificationKey: entry.notificationKey)
            }
        }
        replace(with: all.filter { $0.deliveryDate > now })
    }

    /// Für „alle Benachrichtigungen löschen“: Was nie zugestellt wird, darf später nicht als
    /// gemeldet gelten.
    func removeAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}

// MARK: - Hintergrundaktualisierung (Issue #30, C3)

/// Plant die Sammelnachrichten auch dann neu, wenn die App tagelang nicht geöffnet wird: Käufe
/// über Widget, Siri oder eine geteilte Liste, abgelaufene „Hab noch“-Verschiebungen und Artikel
/// jenseits des 7-Tage-Horizonts kämen sonst erst beim nächsten Öffnen in die Planung.
/// Registriert wird die Aufgabe über `.backgroundTask(.appRefresh(_:))` in `SmartCartApp`; der
/// Bezeichner steht in `BGTaskSchedulerPermittedIdentifiers` (`Generated-Info.plist`).
enum ReplenishmentBackgroundRefresh {
    static let taskIdentifier = "com.johannesemmrich.Restock.replenishmentRefresh"
    /// Frühestens um 5 Uhr, damit die Nachricht um 9 Uhr auf dem neuesten Stand ist. Wann die
    /// Aufgabe tatsächlich läuft, entscheidet iOS.
    static let earliestHour = 5

    /// Wie in `HomeView.refreshDueSoon()`: nur im Developer Mode (Entscheidung 1 in #30) und nur
    /// mit eingeschalteten Benachrichtigungen (`@AppStorage`-Standard `true`).
    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "developerMode")
            && (defaults.object(forKey: "notificationsEnabled") as? Bool ?? true)
    }

    static func earliestBeginDate(after now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: earliestHour, minute: 0, second: 0, of: now) ?? now
        guard today <= now else { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86400)
    }

    /// Meldet die nächste Aktualisierung an (ersetzt eine bereits angemeldete) oder, wenn die
    /// Funktion aus ist, ab.
    static func schedule(now: Date = Date()) {
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = earliestBeginDate(after: now)
        // Scheitert im Simulator immer und ohne Hintergrundaktualisierung in den Einstellungen —
        // dann plant eben erst der nächste App-Start neu.
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Dieselbe Rechnung wie `HomeView.refreshDueSoon()`, nur ohne Banner. Die Auswertung
    /// übernommener und wieder gelöschter Vorschläge (A4) bleibt der App vorbehalten; bis dahin
    /// gilt ein solcher Artikel hier noch nicht als abgelehnt.
    @MainActor
    static func run(container: ModelContainer, now: Date = Date()) async {
        schedule(now: now)
        guard isEnabled else { return }
        let context = container.mainContext
        guard let records = try? context.fetch(FetchDescriptor<PurchaseRecord>()),
              let pending = try? context.fetch(FetchDescriptor<ShoppingItem>(predicate: #Predicate<ShoppingItem> { !$0.isCompleted }))
        else { return }
        // Wie `HomeView`: offene Artikel in aktiven Läden und ohne Laden.
        let pendingNames = Set(
            pending.filter { $0.store == nil || $0.store?.isActive == true }.map { $0.name.lowercased() }
        )
        let patterns = HabitService.patterns(allRecords: records)
        ReplenishmentKeyMigration.runIfNeeded(patterns: patterns)
        let snoozes = ReplenishmentSnoozes()
        snoozes.prune(keeping: patterns)
        let candidates = HabitService.notificationCandidates(
            from: patterns,
            snoozes: snoozes.entries(),
            blocked: ReplenishmentBlocklist().keys,
            dismissed: ReplenishmentFeedback.storedDismissals(),
            pendingNames: pendingNames
        )
        await NotificationService.shared.scheduleReplenishmentDigests(candidates: candidates, now: now)
    }
}
