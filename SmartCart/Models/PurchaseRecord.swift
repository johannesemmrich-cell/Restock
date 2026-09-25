import SwiftData
import Foundation

@Model
class PurchaseRecord {
    // Siehe Store.swift für die Begründung: jede gespeicherte Eigenschaft braucht für SwiftDatas
    // automatische CloudKit-Spiegelung entweder optional zu sein oder einen Standardwert zu
    // haben. Echte Werte kommen weiterhin ausschließlich aus init() unten.
    var id: UUID = UUID()
    var itemName: String = ""
    var storeName: String = ""
    var date: Date = Date()
    var quantityAmount: Double = 1
    var unit: String = ""
    var actualPrice: Double?

    var item: ShoppingItem?

    init(itemName: String, storeName: String, quantityAmount: Double = 1, unit: String = "", actualPrice: Double? = nil) {
        self.id = UUID()
        self.itemName = itemName
        self.storeName = storeName
        self.date = Date()
        self.quantityAmount = quantityAmount
        self.unit = unit
        self.actualPrice = actualPrice
    }
}

// MARK: - Consumption analysis

struct ConsumptionPattern {
    /// Wie der nächste Termin errechnet wurde (Issue #30, 4a).
    enum Mode: Equatable {
        /// Aus den gewichteten Kaufabständen bzw. der Verbrauchsrate.
        case interval
        /// Der Artikel wird an festen Wochentagen gekauft (`Calendar`-Wochentage, 1 = Sonntag,
        /// aufsteigend sortiert), z. B. immer Mo + Mi.
        case weekdays([Int])
    }

    let itemName: String
    /// Typischer Kaufabstand in Tagen: gewichteter Mittelwert der Abstände ohne Ausreißer,
    /// neuere Abstände zählen mehr (B1).
    let averageDaysBetweenPurchases: Double
    let averageQuantityPerPurchase: Double
    let lastPurchaseDate: Date
    /// Nächster Termin. Hat „Hab noch“ (C1) ihn verschoben, ist das der verschobene Termin —
    /// der errechnete steht dann in `originalEstimatedDate`.
    var estimatedNextPurchaseDate: Date
    var mode: Mode = .interval
    /// Anzahl verschiedener Kauftage — mehrere Käufe am selben Tag zählen einmal (B6).
    var purchaseCount: Int = 0
    /// Variationskoeffizient der Abstände (Standardabweichung ÷ Mittelwert), Grundlage für B2.
    var intervalVariation: Double = 0
    /// Längster Abstand, der im Muster regulär vorkommt: im Wochentagsmodus die größte Lücke
    /// zwischen den Wochentagen (Mo + Mi → 5), sonst der typische Abstand. Grundlage für B4.
    var typicalGapDays: Double = 0
    /// Menge und Einheit, mit der ein übernommener Vorschlag auf die Liste kommt (B5).
    var typicalQuantity: Double = 1
    var unit: String = ""
    /// C1: Der errechnete Termin, falls „Hab noch“ ihn verschoben hat, sonst `nil`.
    var originalEstimatedDate: Date? = nil

    /// Der errechnete Termin ohne „Hab noch“-Verschiebung. Daran erkennt eine Verschiebung, ob
    /// sie noch gilt: Ein neuer Kauf ändert ihn und beendet damit die Verschiebung.
    var baseEstimatedDate: Date { originalEstimatedDate ?? estimatedNextPurchaseDate }

    var isSnoozed: Bool { originalEstimatedDate != nil }

    /// Länge des aktuellen Zyklus in Tagen: letzter Kauf → errechneter Termin (ohne „Hab noch“).
    var cycleDays: Double {
        baseEstimatedDate.timeIntervalSince(lastPurchaseDate) / 86400
    }

    /// Vorlauf, ab dem ein Artikel als „bald fällig“ gilt. War fest 7, dann (Nutzerwunsch
    /// 24.08.2026, zu viele gleichzeitige Meldungen) fest 2 Tage. Seit Issue #30 (B3) 20 % des
    /// aktuellen Zyklus, mindestens 1 und höchstens 7 Tage: bei 10 Tagen also weiterhin 2 Tage,
    /// bei 30 Tagen 6, bei 3 Tagen 1. Eine „Hab noch“-Verschiebung (C1) vergrößert das Fenster
    /// nicht, weil `cycleDays` vom errechneten Termin ausgeht.
    var dueWindowDays: Int {
        Int(max(1, min(7, (cycleDays * 0.2).rounded())))
    }

    func daysUntilNeeded(from now: Date) -> Int {
        Calendar.current.dateComponents([.day], from: now, to: estimatedNextPurchaseDate).day ?? 0
    }

    var daysUntilNeeded: Int { daysUntilNeeded(from: Date()) }

    func isOverdue(at now: Date) -> Bool { daysUntilNeeded(from: now) < 0 }

    func isDueSoon(at now: Date) -> Bool {
        let days = daysUntilNeeded(from: now)
        return days >= 0 && days <= dueWindowDays
    }

    var isOverdue: Bool { isOverdue(at: Date()) }
    var isDueSoon: Bool { isDueSoon(at: Date()) }
}

extension Array where Element == PurchaseRecord {
    /// Errechnet den nächsten Bedarf aus der Kaufhistorie eines Artikels. Liefert ab 2 Kauftagen
    /// ein Muster; ob es auch vorgeschlagen wird (mind. 3 Käufe, regelmäßig, Gewohnheit nicht
    /// beendet), entscheidet `HabitService.isEligible`.
    ///
    /// - Parameter closedDays: Tage, an denen Läden geschlossen haben; ein Termin darauf wird auf
    ///   den Tag davor vorgezogen (4b). Standard `.none`, damit die reine Rechnung unabhängig vom
    ///   Wochentag testbar bleibt — `HabitService` übergibt die Schließtage des gewählten Landes.
    func consumptionPattern(closedDays: RetailClosedDays = .none, calendar: Calendar = .current) -> ConsumptionPattern? {
        let days = PurchaseDay.collapse(self, calendar: calendar)
        guard days.count >= 2, let first = days.first, let last = days.last else { return nil }

        let intervals = zip(days, days.dropFirst()).map { $1.date.timeIntervalSince($0.date) / 86400 }
        // IQR outlier removal: ignores vacation gaps and double-purchases
        let cleaned = intervals.count >= 4 ? intervals.removingOutliers() : intervals
        let typicalInterval = cleaned.recencyWeightedMean()

        var mode = ConsumptionPattern.Mode.interval
        var gap = typicalInterval
        var next: Date
        if let weekdays = days.fixedWeekdays(calendar: calendar) {
            // 4a: Mo + Mi ergibt abwechselnd 2 und 5 Tage Abstand — jeder Mittelwert läge immer
            // daneben. Nächster Termin ist deshalb schlicht der nächste typische Wochentag.
            mode = .weekdays(weekdays)
            gap = Double(weekdays.longestCyclicGap)
            next = nextDate(after: last.date, onOneOf: weekdays, calendar: calendar)
        } else if let daysPerUnit = days.daysPerUnit() {
            // B5: Verbrauchsrate statt Kaufabstand — wer diesmal 6 statt 2 kauft, braucht
            // entsprechend später wieder welche. Bei gleichbleibender Menge identisch mit dem
            // Kaufabstand (der Abstand wird NICHT zusätzlich mit der Menge multipliziert, A1).
            next = last.date.addingTimeInterval(last.quantity * daysPerUnit * 86400)
        } else {
            next = last.date.addingTimeInterval(typicalInterval * 86400)
        }
        let allowsSunday: Bool
        if case .weekdays(let weekdays) = mode { allowsSunday = weekdays.contains(1) } else { allowsSunday = false }
        next = closedDays.latestOpenDay(onOrBefore: next, after: last.date, allowSunday: allowsSunday, calendar: calendar)

        let typical = days.typicalQuantity()
        return ConsumptionPattern(
            itemName: first.itemName,
            averageDaysBetweenPurchases: typicalInterval,
            averageQuantityPerPurchase: days.map(\.quantity).reduce(0, +) / Double(days.count),
            lastPurchaseDate: last.date,
            estimatedNextPurchaseDate: next,
            mode: mode,
            purchaseCount: days.count,
            intervalVariation: cleaned.coefficientOfVariation(),
            typicalGapDays: gap,
            typicalQuantity: typical.quantity,
            unit: typical.unit
        )
    }
}

/// Alle Käufe eines Artikels an einem Kalendertag, zusammengefasst (B6): Abhaken und Bon-Scan
/// am selben Tag oder zwei Positionen auf einem Bon sind ein Einkauf, kein Abstand von 0 Tagen.
struct PurchaseDay {
    /// Zeitpunkt des ersten Kaufs an diesem Tag.
    let date: Date
    let itemName: String
    var quantity: Double
    /// Einheit wie gespeichert (für die Liste); verglichen wird klein geschrieben und getrimmt.
    var unit: String

    var unitKey: String { unit.trimmingCharacters(in: .whitespaces).lowercased() }

    static func collapse(_ records: [PurchaseRecord], calendar: Calendar) -> [PurchaseDay] {
        var result: [PurchaseDay] = []
        for record in records.sorted(by: { $0.date < $1.date }) {
            let quantity = record.quantityAmount > 0 ? record.quantityAmount : 1
            let unit = record.unit.trimmingCharacters(in: .whitespaces)
            if let lastDay = result.last, calendar.isDate(lastDay.date, inSameDayAs: record.date) {
                if lastDay.unitKey == unit.lowercased() {
                    result[result.count - 1].quantity += quantity
                } else {
                    // Unterschiedliche Einheiten lassen sich nicht addieren — der spätere Kauf gilt.
                    result[result.count - 1].quantity = quantity
                    result[result.count - 1].unit = unit
                }
                continue
            }
            result.append(PurchaseDay(date: record.date, itemName: record.itemName, quantity: quantity, unit: unit))
        }
        return result
    }
}

extension Array where Element == PurchaseDay {
    /// 4a: Fallen in den 8 Wochen bis zum letzten Kauf mindestens 80 % der Käufe auf höchstens
    /// 3 Wochentage, und kommt jeder davon in mindestens 2/3 der Wochen vor, sind das die festen
    /// Einkaufstage des Artikels. Braucht mindestens 4 Käufe über mindestens 2 Wochen.
    /// Verankert am letzten Kauf, nicht an „heute“, damit der errechnete Termin stabil bleibt —
    /// `dismissedReplenishments` und A3/A4 erkennen einen Termin an seinem exakten Wert.
    func fixedWeekdays(calendar: Calendar) -> [Int]? {
        guard let last = last,
              let windowStart = calendar.date(byAdding: .day, value: -56, to: last.date) else { return nil }
        let recent = filter { $0.date > windowStart }
        guard recent.count >= 4, let first = recent.first,
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: first.date)?.start,
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: last.date)?.start,
              let daysBetweenWeeks = calendar.dateComponents([.day], from: firstWeek, to: lastWeek).day
        else { return nil }
        let weekSpan = Int((Double(daysBetweenWeeks) / 7).rounded()) + 1
        guard weekSpan >= 2 else { return nil }

        let byWeekday = Dictionary(grouping: recent) { calendar.component(.weekday, from: $0.date) }
        let ranked = byWeekday.sorted { lhs, rhs in
            lhs.value.count != rhs.value.count ? lhs.value.count > rhs.value.count : lhs.key < rhs.key
        }
        var chosen: [Int] = []
        var covered = 0
        for (weekday, purchases) in ranked.prefix(3) {
            chosen.append(weekday)
            covered += purchases.count
            if Double(covered) >= 0.8 * Double(recent.count) { break }
        }
        guard Double(covered) >= 0.8 * Double(recent.count) else { return nil }
        for weekday in chosen {
            let weeks = Set((byWeekday[weekday] ?? []).compactMap {
                calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start
            })
            guard Double(weeks.count) >= 2.0 / 3.0 * Double(weekSpan) else { return nil }
        }
        return chosen.sorted()
    }

    /// B5: Tage pro Mengeneinheit, gewichtet und ohne Ausreißer. Nur wenn alle Käufe dieselbe
    /// Einheit haben — „500 g“ und „1 Stk“ lassen sich nicht in eine Rate umrechnen.
    func daysPerUnit() -> Double? {
        guard count >= 2, Set(map(\.unitKey)).count == 1 else { return nil }
        let rates = zip(self, dropFirst()).map { previous, current in
            current.date.timeIntervalSince(previous.date) / 86400 / previous.quantity
        }
        let cleaned = rates.count >= 4 ? rates.removingOutliers() : rates
        return cleaned.recencyWeightedMean()
    }

    /// B5: Median der Menge der letzten 5 Käufe mit der Einheit des letzten Kaufs.
    func typicalQuantity() -> (quantity: Double, unit: String) {
        guard let last = last else { return (1, "") }
        let sameUnit = suffix(5).filter { $0.unitKey == last.unitKey }.map(\.quantity).sorted()
        guard !sameUnit.isEmpty else { return (last.quantity, last.unit) }
        return (sameUnit[sameUnit.count / 2], last.unit)
    }
}

private extension Array where Element == Int {
    /// Größte Lücke in Tagen zwischen aufeinanderfolgenden Wochentagen, über das Wochenende
    /// hinweg gerechnet: [Mo, Mi] → max(2, 5) = 5; ein einzelner Wochentag → 7.
    var longestCyclicGap: Int {
        let s = sorted()
        guard let first = s.first, let last = s.last else { return 7 }
        let inner = zip(s, s.dropFirst()).map { $1 - $0 }
        return (inner + [7 - last + first]).max() ?? 7
    }
}

private func nextDate(after date: Date, onOneOf weekdays: [Int], calendar: Calendar) -> Date {
    for offset in 1...7 {
        if let candidate = calendar.date(byAdding: .day, value: offset, to: date),
           weekdays.contains(calendar.component(.weekday, from: candidate)) {
            return candidate
        }
    }
    return date.addingTimeInterval(7 * 86400)
}

// MARK: - Closed days (Issue #30, 4b)

/// Tage, an denen Läden geschlossen haben. Ein errechneter Termin darauf wird auf den Tag davor
/// vorgezogen — vorher einzukaufen ist sicherer als nachher.
struct RetailClosedDays: Equatable {
    var sundays: Bool
    /// Bundesweite gesetzliche Feiertage in Deutschland (regionale bewusst nicht).
    var germanPublicHolidays: Bool

    static let none = RetailClosedDays(sundays: false, germanPublicHolidays: false)

    static func forCountry(_ code: String) -> RetailClosedDays {
        let code = code.uppercased()
        return RetailClosedDays(sundays: ["DE", "AT", "CH"].contains(code), germanPublicHolidays: code == "DE")
    }

    /// Schließtage für das in den Einstellungen gewählte Land (`selectedCountry`, SettingsView).
    static var current: RetailClosedDays {
        forCountry(UserDefaults.standard.string(forKey: "selectedCountry") ?? Locale.current.region?.identifier ?? "DE")
    }

    /// - Parameter allowSunday: `true`, wenn der Artikel im Wochentagsmodus regelmäßig sonntags
    ///   gekauft wird — dann ist ein Sonntag offenbar kein Schließtag für diesen Einkauf. Wird der
    ///   Termin wegen eines Feiertags verschoben, gilt ein dabei erreichter Sonntag trotzdem als zu.
    /// Nie auf oder vor den Tag des letzten Kaufs.
    func latestOpenDay(onOrBefore date: Date, after lastPurchase: Date, allowSunday: Bool, calendar: Calendar) -> Date {
        var result = date
        var shifted = false
        while isClosed(result, sundayAllowed: allowSunday && !shifted, calendar: calendar) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: result),
                  previous > lastPurchase,
                  !calendar.isDate(previous, inSameDayAs: lastPurchase) else { break }
            result = previous
            shifted = true
        }
        return result
    }

    private func isClosed(_ date: Date, sundayAllowed: Bool, calendar: Calendar) -> Bool {
        if sundays && !sundayAllowed && calendar.component(.weekday, from: date) == 1 { return true }
        return germanPublicHolidays && Self.isGermanPublicHoliday(date, calendar: calendar)
    }

    static func isGermanPublicHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day else { return false }
        let fixed = [(1, 1), (5, 1), (10, 3), (12, 25), (12, 26)]
        if fixed.contains(where: { $0.0 == month && $0.1 == day }) { return true }
        // Karfreitag, Ostermontag, Christi Himmelfahrt, Pfingstmontag
        let easter = easterSunday(year: year)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let easterDate = gregorian.date(from: DateComponents(year: year, month: easter.month, day: easter.day)) else { return false }
        return [-2, 1, 39, 50].contains { offset in
            guard let holiday = gregorian.date(byAdding: .day, value: offset, to: easterDate) else { return false }
            let h = gregorian.dateComponents([.month, .day], from: holiday)
            return h.month == month && h.day == day
        }
    }

    /// Ostersonntag nach der gregorianischen Osterformel (Meeus/Jones/Butcher).
    static func easterSunday(year: Int) -> (month: Int, day: Int) {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return (month, day)
    }
}

private extension Array where Element == Double {
    func removingOutliers() -> [Double] {
        let s = sorted()
        let q1 = s[s.count / 4], q3 = s[3 * s.count / 4]
        let iqr = q3 - q1
        let filtered = filter { $0 >= q1 - 1.5 * iqr && $0 <= q3 + 1.5 * iqr }
        return filtered.isEmpty ? self : filtered
    }

    /// B1: gewichteter Mittelwert in zeitlicher Reihenfolge — der neueste Wert zählt 1, jeder
    /// ältere 20 % weniger als sein Nachfolger. Gewohnheitsänderungen wirken so nach wenigen
    /// Käufen statt erst nach Jahren.
    func recencyWeightedMean() -> Double {
        guard !isEmpty else { return 0 }
        var weightedSum = 0.0, weightTotal = 0.0, weight = 1.0
        for value in reversed() {
            weightedSum += value * weight
            weightTotal += weight
            weight *= 0.8
        }
        return weightedSum / weightTotal
    }

    func coefficientOfVariation() -> Double {
        guard count >= 2 else { return 0 }
        let mean = reduce(0, +) / Double(count)
        guard mean > 0 else { return 0 }
        let variance = map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(count)
        return variance.squareRoot() / mean
    }
}
