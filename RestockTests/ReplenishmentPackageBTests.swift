import XCTest
@testable import Restock

/// Issue #30, Paket B + D („Zeit zum Nachkaufen“): gewichteter Abstand (B1), Eignung (B2/B4),
/// Fenster (B3), Verbrauchsrate und typische Menge (B5), Käufe am selben Tag (B6),
/// Wochentagsmuster (4a), Sonntag/Feiertag (4b), Rückblick und Zähler (D1).
///
/// Die Vorhersage bekommt hier einen festen gregorianischen UTC-Kalender und feste Daten
/// übergeben, weil Wochentage und Feiertage geprüft werden. Wo `Date()` mitspielt (Fälligkeit),
/// arbeiten die Tests wie `ConsumptionPatternTests` relativ zu `DateFixtures`.
final class ReplenishmentPackageBTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var metricsDefaults: UserDefaults!
    private let metricsSuite = "ReplenishmentPackageBTests.metrics"

    override func setUp() {
        super.setUp()
        metricsDefaults = UserDefaults(suiteName: metricsSuite)
        metricsDefaults.removePersistentDomain(forName: metricsSuite)
    }

    override func tearDown() {
        metricsDefaults.removePersistentDomain(forName: metricsSuite)
        metricsDefaults = nil
        super.tearDown()
    }

    // MARK: - 4a Wochentagsmuster

    func testMondayWednesdayPatternPredictsNextWednesday() throws {
        // Vier Wochen lang immer Mo + Mi, zuletzt Mo 21.09.2026.
        let dates = [(8, 31), (9, 2), (9, 7), (9, 9), (9, 14), (9, 16), (9, 21)]
        let pattern = try XCTUnwrap(records("Brötchen", dates).consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.mode, .weekdays([2, 4]))
        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(9, 23), "Nach Montag kommt Mittwoch, nicht Donnerstag (Mittelwert 3,5 Tage).")
        XCTAssertEqual(pattern.typicalGapDays, 5)
    }

    func testMondayWednesdayPatternPredictsNextMondayAfterWednesday() throws {
        let dates = [(8, 31), (9, 2), (9, 7), (9, 9), (9, 14), (9, 16), (9, 21), (9, 23)]
        let pattern = try XCTUnwrap(records("Brötchen", dates).consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(9, 28), "Nach Mittwoch kommt der nächste Montag, nicht Samstag.")
    }

    func testBiweeklyPurchaseIsNotTreatedAsWeekdayPattern() throws {
        // Jeden zweiten Samstag: der Samstag kommt nur in jeder zweiten Woche vor.
        let dates = [(7, 25), (8, 8), (8, 22), (9, 5), (9, 19)]
        let pattern = try XCTUnwrap(records("Waschmittel", dates).consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.mode, .interval)
        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(10, 3), "Alle 14 Tage, nicht jeden Samstag.")
    }

    // MARK: - B1 gewichteter Abstand

    func testRecentIntervalsWeighMore() throws {
        // Abstände 20, 20, 10: neuere zählen mehr → über dem einfachen Mittel von 13,3.
        let pattern = try XCTUnwrap(records("Kaffee", [(7, 1), (7, 21), (8, 10), (8, 20)]).consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.mode, .interval)
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, (0.64 * 20 + 0.8 * 20 + 10) / 2.44, accuracy: 0.01)
    }

    // MARK: - B5 Verbrauchsrate und typische Menge

    func testLargerLastPurchaseMovesNextDateOut() throws {
        // Alle 10 Tage 2 Stück (5 Tage pro Stück), zuletzt 6 Stück → reicht 30 Tage.
        let recs = [
            record("Joghurt", 7, 1, quantity: 2),
            record("Joghurt", 7, 11, quantity: 2),
            record("Joghurt", 7, 21, quantity: 2),
            record("Joghurt", 7, 31, quantity: 6),
        ]
        let pattern = try XCTUnwrap(recs.consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.mode, .interval)
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, 10, accuracy: 0.01)
        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(8, 30))
        XCTAssertEqual(pattern.typicalQuantity, 2, "Median der letzten Käufe, nicht der Ausreißer 6.")
    }

    func testMixedUnitsFallBackToInterval() throws {
        let recs = [
            record("Hackfleisch", 7, 1, quantity: 500, unit: "g"),
            record("Hackfleisch", 7, 11, quantity: 1, unit: "kg"),
            record("Hackfleisch", 7, 21, quantity: 500, unit: "g"),
        ]
        let pattern = try XCTUnwrap(recs.consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(7, 31))
        XCTAssertEqual(pattern.unit, "g")
        XCTAssertEqual(pattern.typicalQuantity, 500)
    }

    // MARK: - B6 Käufe am selben Tag

    func testSameDayPurchasesCountOnce() throws {
        let recs = [
            record("Milch", 7, 1),
            record("Milch", 7, 11),
            record("Milch", 7, 11, hour: 18),
            record("Milch", 7, 21),
        ]
        let pattern = try XCTUnwrap(recs.consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.purchaseCount, 3)
        XCTAssertEqual(pattern.averageDaysBetweenPurchases, 10, accuracy: 0.01, "Kein Abstand von 0 Tagen.")
    }

    // MARK: - 4b Sonntag und Feiertage

    func testSundayIsMovedToSaturdayInGermany() throws {
        // Alle 10 Tage, zuletzt Do 17.09.2026 → rechnerisch So 27.09.
        let recs = records("Kaffee", [(8, 28), (9, 7), (9, 17)])

        XCTAssertEqual(recs.consumptionPattern(calendar: calendar)?.estimatedNextPurchaseDate, date(9, 27))
        XCTAssertEqual(recs.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar)?.estimatedNextPurchaseDate, date(9, 27))
        XCTAssertEqual(recs.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar)?.estimatedNextPurchaseDate, date(9, 26))
    }

    func testEasterMondayIsMovedBeforeTheWeekend() throws {
        // Alle 11 Tage, zuletzt Do 26.03.2026 → rechnerisch Ostermontag 06.04.; So 05.04. ist
        // ebenfalls zu → Sa 04.04.
        let recs = records("Kaffee", [(3, 4), (3, 15), (3, 26)])
        let pattern = try XCTUnwrap(recs.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))

        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(4, 4))
    }

    func testHolidayOnWeekdayPatternMovesToSaturday() throws {
        // Mo + Mi, zuletzt Mi 01.04.2026 → nächster Montag ist Ostermontag.
        let dates = [(3, 9), (3, 11), (3, 16), (3, 18), (3, 23), (3, 25), (3, 30), (4, 1)]
        let pattern = try XCTUnwrap(records("Brötchen", dates).consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))

        XCTAssertEqual(pattern.mode, .weekdays([2, 4]))
        XCTAssertEqual(pattern.estimatedNextPurchaseDate, date(4, 4))
    }

    func testGermanPublicHolidays() {
        let easter2026 = RetailClosedDays.easterSunday(year: 2026)
        XCTAssertEqual([easter2026.month, easter2026.day], [4, 5])
        let easter2027 = RetailClosedDays.easterSunday(year: 2027)
        XCTAssertEqual([easter2027.month, easter2027.day], [3, 28])
        for (month, day) in [(1, 1), (4, 3), (4, 6), (5, 1), (5, 14), (5, 25), (10, 3), (12, 25), (12, 26)] {
            XCTAssertTrue(RetailClosedDays.isGermanPublicHoliday(date(month, day), calendar: calendar), "\(day).\(month). ist Feiertag")
        }
        XCTAssertFalse(RetailClosedDays.isGermanPublicHoliday(date(4, 4), calendar: calendar))
        XCTAssertFalse(RetailClosedDays.isGermanPublicHoliday(date(11, 1), calendar: calendar), "Allerheiligen ist nur regional.")
    }

    // MARK: - B2/B4 Eignung

    func testTwoPurchasesAreNotEligible() throws {
        let pattern = try XCTUnwrap(records("Kaffee", [(9, 1), (9, 11)]).consumptionPattern(calendar: calendar))
        XCTAssertEqual(HabitService.ineligibility(of: pattern, at: date(9, 20)), .tooFewPurchases)
    }

    func testIrregularIntervalsAreNotEligible() throws {
        // Abstände 2, 15, 3, 20 Tage: Variationskoeffizient ≈ 0,77.
        let pattern = try XCTUnwrap(records("Kerzen", [(8, 3), (8, 5), (8, 20), (8, 23), (9, 12)]).consumptionPattern(calendar: calendar))

        XCTAssertEqual(pattern.mode, .interval)
        XCTAssertGreaterThan(pattern.intervalVariation, HabitService.maximumIntervalVariation)
        XCTAssertEqual(HabitService.ineligibility(of: pattern, at: date(9, 20)), .irregular)
    }

    func testHabitEndsAfterTwoAndAHalfTypicalGaps() throws {
        // Jeden Montag, zuletzt 21.09.; Gewohnheit endet nach 17,5 Tagen.
        let pattern = try XCTUnwrap(records("Milch", [(8, 31), (9, 7), (9, 14), (9, 21)]).consumptionPattern(calendar: calendar))

        XCTAssertNil(HabitService.ineligibility(of: pattern, at: date(10, 1)), "10 Tage: überfällig, aber noch vorschlagbar.")
        XCTAssertEqual(HabitService.ineligibility(of: pattern, at: date(10, 11)), .habitEnded)
    }

    func testDueSoonItemsRequireThreePurchases() {
        let two = [recordDaysAgo("Kaffee", 19), recordDaysAgo("Kaffee", 9)]
        XCTAssertTrue(HabitService.dueSoonItems(allRecords: two, closedDays: .none).isEmpty)

        let three = [recordDaysAgo("Kaffee", 29)] + two
        XCTAssertEqual(HabitService.dueSoonItems(allRecords: three, closedDays: .none).map(\.itemName), ["Kaffee"])
    }

    // MARK: - B3 Fenster

    func testDueWindowIsTwentyPercentOfCycle() {
        XCTAssertEqual(pattern(cycleDays: 2).dueWindowDays, 1, "Mindestens 1 Tag.")
        XCTAssertEqual(pattern(cycleDays: 10).dueWindowDays, 2)
        XCTAssertEqual(pattern(cycleDays: 30).dueWindowDays, 6)
        XCTAssertEqual(pattern(cycleDays: 90).dueWindowDays, 7, "Höchstens 7 Tage.")
    }

    // MARK: - D1 Rückblick und Zähler

    func testBacktestOnRegularHistory() {
        // Alle 10 Tage, 6 Käufe → die letzten 3 haben je 3 frühere Kauftage.
        let recs = records("Kaffee", [(7, 1), (7, 11), (7, 21), (7, 31), (8, 10), (8, 20)])
        let result = HabitService.backtest(allRecords: recs, closedDays: .none, calendar: calendar)

        XCTAssertEqual(result.evaluated, 3)
        XCTAssertEqual(result.covered, 3)
        XCTAssertEqual(result.withinWindow, 3)
        XCTAssertEqual(try XCTUnwrap(result.meanAbsoluteErrorDays), 0, accuracy: 0.01)
    }

    func testMetricsCountEachSuggestionOnce() {
        let metrics = ReplenishmentMetrics(defaults: metricsDefaults)
        let first = pattern(cycleDays: 7)
        metrics.recordShown([first])
        metrics.recordShown([first])
        XCTAssertEqual(metrics.count(.shown), 1)

        let nextCycle = pattern(cycleDays: 7, lastDaysAgo: 0)
        metrics.recordShown([nextCycle])
        XCTAssertEqual(metrics.count(.shown), 2, "Neuer Termin = neuer Vorschlag.")

        metrics.record(.accepted)
        metrics.record(.removedAfterAccept, times: 2)
        XCTAssertEqual(metrics.count(.accepted), 1)
        XCTAssertEqual(metrics.count(.removedAfterAccept), 2)

        metrics.reset()
        XCTAssertEqual(metrics.count(.shown), 0)
        XCTAssertEqual(metrics.count(.accepted), 0)
    }

    // MARK: - Helpers

    private func date(_ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func record(_ name: String, _ month: Int, _ day: Int, hour: Int = 10, quantity: Double = 1, unit: String = "") -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: "Edeka", quantityAmount: quantity, unit: unit)
        r.date = date(month, day, hour: hour)
        return r
    }

    private func records(_ name: String, _ dates: [(Int, Int)]) -> [PurchaseRecord] {
        dates.map { record(name, $0.0, $0.1) }
    }

    private func recordDaysAgo(_ name: String, _ days: Int) -> PurchaseRecord {
        let r = PurchaseRecord(itemName: name, storeName: "Edeka")
        r.date = DateFixtures.daysAgo(days)
        return r
    }

    private func pattern(cycleDays: Double, lastDaysAgo: Int = 7) -> ConsumptionPattern {
        let last = DateFixtures.daysAgo(lastDaysAgo)
        return ConsumptionPattern(
            itemName: "Milch",
            averageDaysBetweenPurchases: cycleDays,
            averageQuantityPerPurchase: 1,
            lastPurchaseDate: last,
            estimatedNextPurchaseDate: last.addingTimeInterval(cycleDays * 86400)
        )
    }
}
