import XCTest
@testable import Restock

/// Issue #30, Paket C1 („Zeit zum Nachkaufen“): ✕ im Banner wird zu „Hab noch“ (Termin um den
/// halben üblichen Abstand verschieben, 1–14 Tage, gilt bis zum nächsten Kauf) und „Nicht mehr
/// vorschlagen“ (dauerhaft ausblenden, in den Einstellungen umkehrbar).
///
/// Feste Daten im September 2026 (keine Zeitumstellung) mit festem UTC-Kalender; Montag ist der
/// 21.09.2026, der 20.09. und der 27.09. sind Sonntage.
final class ReplenishmentPackageCTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var defaults: UserDefaults!
    private let suite = "ReplenishmentPackageCTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Hab noch: Dauer

    func testShiftIsHalfTheTypicalGapClampedToOneToFourteenDays() {
        XCTAssertEqual(ReplenishmentSnoozes.shiftDays(for: pattern(gap: 10)), 5)
        XCTAssertEqual(ReplenishmentSnoozes.shiftDays(for: pattern(gap: 7)), 4, "3,5 wird aufgerundet.")
        XCTAssertEqual(ReplenishmentSnoozes.shiftDays(for: pattern(gap: 1)), 1, "Mindestens 1 Tag.")
        XCTAssertEqual(ReplenishmentSnoozes.shiftDays(for: pattern(gap: 20)), 10)
        XCTAssertEqual(ReplenishmentSnoozes.shiftDays(for: pattern(gap: 60)), 14, "Höchstens 14 Tage.")
    }

    // MARK: - Hab noch: Verschiebung

    func testSnoozeHidesSuggestionUntilShiftedDateIsDue() {
        // Alle 10 Tage, zuletzt 12.09. → Termin 22.09., Fenster 2 Tage.
        let raw = pattern(gap: 10, last: date(9, 12))
        XCTAssertEqual(due([raw], at: date(9, 21)).count, 1, "Setup: am 21.09. fällig.")

        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        let until = snoozes.snooze(raw, now: date(9, 21), closedDays: .none, calendar: calendar)
        XCTAssertEqual(until, date(9, 27), "Termin 22.09. + 5 Tage.")

        XCTAssertTrue(due([raw], at: date(9, 21), snoozes: snoozes.entries()).isEmpty)
        XCTAssertTrue(due([raw], at: date(9, 24), snoozes: snoozes.entries()).isEmpty)

        let shown = due([raw], at: date(9, 25), snoozes: snoozes.entries())
        XCTAssertEqual(shown.count, 1, "Zwei Tage vor dem verschobenen Termin wieder im Banner.")
        XCTAssertEqual(shown.first?.estimatedNextPurchaseDate, date(9, 27))
        XCTAssertEqual(shown.first?.originalEstimatedDate, date(9, 22))
        XCTAssertEqual(shown.first?.dueWindowDays, 2, "Die Verschiebung vergrößert das Fenster nicht.")
    }

    func testRepeatedSnoozeShiftsAgainFromTheShiftedDate() throws {
        let raw = pattern(gap: 10, last: date(9, 12))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        snoozes.snooze(raw, now: date(9, 21), closedDays: .none, calendar: calendar)

        let shown = try XCTUnwrap(due([raw], at: date(9, 25), snoozes: snoozes.entries()).first)
        let until = snoozes.snooze(shown, now: date(9, 25), closedDays: .none, calendar: calendar)

        XCTAssertEqual(until, date(10, 2), "27.09. + 5 Tage.")
        let entry = try XCTUnwrap(snoozes.entries()["milch"])
        XCTAssertEqual(entry.baseDate, date(9, 22).timeIntervalSince1970, "Gilt weiter für den errechneten Termin.")
    }

    func testSnoozeOfOverdueItemShiftsFromNow() {
        // Termin 22.09., am 28.09. überfällig: ab dem Termin verschoben (27.09.) wäre sofort
        // wieder überfällig — deshalb ab jetzt.
        let raw = pattern(gap: 10, last: date(9, 12))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        let until = snoozes.snooze(raw, now: date(9, 28, hour: 18), closedDays: .none, calendar: calendar)

        XCTAssertEqual(until, date(10, 3, hour: 18))
        XCTAssertTrue(due([raw], at: date(9, 28, hour: 18), snoozes: snoozes.entries()).isEmpty)
    }

    func testSnoozeOfShortCycleOverdueItemDoesNotReappearImmediately() {
        // Alle 3 Tage, zuletzt 15.09. → Termin 18.09., am 20.09. überfällig; Fenster 1 Tag.
        // Halber Abstand (2 Tage) ab jetzt läge sofort wieder im Fenster — deshalb mindestens
        // Fenster + 2 Tage: 23.09.
        let raw = pattern(gap: 3, last: date(9, 15))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        let until = snoozes.snooze(raw, now: date(9, 20), closedDays: .none, calendar: calendar)

        XCTAssertEqual(until, date(9, 23))
        let fiveMinutesLater = date(9, 20).addingTimeInterval(5 * 60)
        XCTAssertTrue(due([raw], at: fiveMinutesLater, snoozes: snoozes.entries()).isEmpty, "Nicht sofort wieder im Banner.")
        XCTAssertTrue(due([raw], at: date(9, 21, hour: 9), snoozes: snoozes.entries()).isEmpty)
        XCTAssertEqual(due([raw], at: date(9, 22), snoozes: snoozes.entries()).count, 1, "Einen Tag vor dem verschobenen Termin wieder da.")
    }

    func testSnoozeEndsWithTheNextPurchase() {
        let raw = pattern(gap: 10, last: date(9, 12))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        snoozes.snooze(raw, now: date(9, 21), closedDays: .none, calendar: calendar)

        // Neuer Kauf am 23.09. → neuer Termin 03.10.; die alte Verschiebung gilt nicht mehr.
        let afterPurchase = pattern(gap: 10, last: date(9, 23))
        let applied = afterPurchase.applying(snoozes.entries()["milch"]!)
        XCTAssertFalse(applied.isSnoozed)
        XCTAssertEqual(applied.estimatedNextPurchaseDate, date(10, 3))

        snoozes.prune(keeping: [raw])
        XCTAssertNotNil(snoozes.entries()["milch"], "Termin unverändert → bleibt.")
        snoozes.prune(keeping: [afterPurchase])
        XCTAssertNil(snoozes.entries()["milch"], "Termin verschoben → aufgeräumt.")
    }

    func testSnoozeAvoidsSundayLikeFourB() {
        // Termin Di 22.09. + 5 Tage = So 27.09. → in Deutschland Sa 26.09.
        let raw = pattern(gap: 10, last: date(9, 12))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        XCTAssertEqual(
            snoozes.snooze(raw, now: date(9, 21), closedDays: .forCountry("DE"), calendar: calendar),
            date(9, 26)
        )
    }

    func testRemoveAndRemoveAllClearSnoozes() {
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        snoozes.snooze(pattern(gap: 10, last: date(9, 12)), now: date(9, 21), closedDays: .none, calendar: calendar)
        snoozes.snooze(pattern(name: "Brot", gap: 4, last: date(9, 18)), now: date(9, 21), closedDays: .none, calendar: calendar)
        XCTAssertEqual(Set(snoozes.entries().keys), ["milch", "brot"])

        snoozes.remove("MILCH")
        XCTAssertEqual(Set(snoozes.entries().keys), ["brot"])
        snoozes.removeAll()
        XCTAssertTrue(snoozes.entries().isEmpty)
    }

    // MARK: - Nicht mehr vorschlagen

    func testBlockedItemIsNeverSuggestedUntilUnblocked() {
        let raw = pattern(gap: 10, last: date(9, 12))
        let blocklist = ReplenishmentBlocklist(defaults: defaults)
        blocklist.block("Milch")

        XCTAssertTrue(due([raw], at: date(9, 21), blocked: blocklist.keys).isEmpty)
        XCTAssertTrue(due([raw], at: date(9, 30), blocked: blocklist.keys).isEmpty, "Auch überfällig nicht.")

        blocklist.unblock("milch")
        XCTAssertEqual(due([raw], at: date(9, 21), blocked: blocklist.keys).count, 1)
    }

    func testBlocklistIsCaseInsensitiveWithoutDuplicates() {
        let blocklist = ReplenishmentBlocklist(defaults: defaults)
        blocklist.block("Milch")
        blocklist.block("milch")
        blocklist.block("Butter")

        XCTAssertEqual(blocklist.names(), ["Butter", "Milch"], "Alphabetisch, Anzeigename bleibt.")
        XCTAssertTrue(blocklist.contains("MILCH"))
        XCTAssertEqual(blocklist.keys, ["milch", "butter"])

        blocklist.removeAll()
        XCTAssertTrue(blocklist.names().isEmpty)
    }

    // MARK: - D1-Zähler

    func testMetricsCountSnoozesAndBlocksSeparately() {
        let metrics = ReplenishmentMetrics(defaults: defaults)
        metrics.record(.snoozed)
        metrics.record(.snoozed)
        metrics.record(.blocked)
        XCTAssertEqual(metrics.count(.snoozed), 2)
        XCTAssertEqual(metrics.count(.blocked), 1)
    }

    // MARK: - Helpers

    private func due(
        _ patterns: [ConsumptionPattern],
        at now: Date,
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = []
    ) -> [ConsumptionPattern] {
        HabitService.dueSoonItems(from: patterns, now: now, snoozes: snoozes, blocked: blocked)
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Regelmäßiger Artikel mit 3 Kauftagen, der vorgeschlagen werden darf (B2).
    private func pattern(name: String = "Milch", gap: Double, last: Date? = nil) -> ConsumptionPattern {
        let last = last ?? date(9, 12)
        return ConsumptionPattern(
            itemName: name,
            averageDaysBetweenPurchases: gap,
            averageQuantityPerPurchase: 1,
            lastPurchaseDate: last,
            estimatedNextPurchaseDate: last.addingTimeInterval(gap * 86400),
            purchaseCount: 3,
            typicalGapDays: gap
        )
    }
}
