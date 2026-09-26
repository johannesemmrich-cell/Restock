import XCTest
@testable import Restock

/// Issue #30, C3: höchstens eine gebündelte Push-Nachricht pro Tag um 9 Uhr statt einer pro
/// Artikel, geplant für die nächsten 7 Tage und per Hintergrundaktualisierung auch ohne
/// App-Start erneuert.
///
/// Feste Daten im September/Oktober 2026 (keine Zeitumstellung) mit festem UTC-Kalender.
final class ReplenishmentDigestTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var defaults: UserDefaults!
    private let suite = "ReplenishmentDigestTests"

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

    // MARK: - Bündelung

    func testItemsDueOnTheSameDayShareOneDigestAtNine() {
        let milk = pattern("Milch", last: date(9, 12))     // fällig 22.09.
        let butter = pattern("Butter", last: date(9, 12))  // fällig 22.09.
        let eggs = pattern("Eier", last: date(9, 14))      // fällig 24.09.

        let digests = plan([milk, butter, eggs], now: date(9, 21))

        XCTAssertEqual(digests.map(\.deliveryDate), [date(9, 22, hour: 9), date(9, 24, hour: 9)])
        XCTAssertEqual(digests.map(\.itemNames), [["Butter", "Milch"], ["Eier"]])
    }

    func testOverdueItemGoesIntoNextDigestInsteadOfImmediatePush() {
        let overdue = pattern("Zahnpasta", last: date(9, 8))  // fällig 18.09.
        let milk = pattern("Milch", last: date(9, 12))        // fällig 22.09.

        let early = plan([overdue, milk], now: date(9, 21, hour: 8))
        XCTAssertEqual(early.map(\.deliveryDate), [date(9, 21, hour: 9), date(9, 22, hour: 9)])
        XCTAssertEqual(early.first?.itemNames, ["Zahnpasta"], "Heute um 9 steht noch aus.")

        let late = plan([overdue, milk], now: date(9, 21, hour: 10))
        XCTAssertEqual(late.count, 1, "Nach 9 Uhr kommt heute keine Nachricht mehr.")
        XCTAssertEqual(late.first?.deliveryDate, date(9, 22, hour: 9))
        XCTAssertEqual(late.first?.itemNames, ["Milch", "Zahnpasta"])
    }

    func testPlanningLooksSevenDaysAhead() {
        let soon = pattern("Milch", gap: 10, last: date(9, 18))    // fällig 28.09. = 7. Tag
        let later = pattern("Mehl", gap: 20, last: date(9, 9))     // fällig 29.09. = 8. Tag

        let digests = plan([soon, later], now: date(9, 21, hour: 10))

        XCTAssertEqual(digests.map(\.itemNames), [["Milch"]])
        XCTAssertEqual(digests.first?.deliveryDate, date(9, 28, hour: 9))
    }

    func testItemWhoseHabitEndsBeforeDeliveryIsSkipped() {
        // Alle 10 Tage, zuletzt 12.09. → Gewohnheit endet nach 25 Tagen, am 07.10. um 10 Uhr.
        let milk = pattern("Milch", last: date(9, 12))
        XCTAssertTrue(HabitService.isEligible(milk, at: date(10, 7)), "Setup: jetzt noch vorschlagbar.")

        XCTAssertEqual(plan([milk], now: date(10, 7, hour: 8)).map(\.itemNames), [["Milch"]])
        XCTAssertTrue(plan([milk], now: date(10, 7)).isEmpty, "Morgen um 9 wäre die Gewohnheit beendet.")
    }

    // MARK: - Einmal pro Kaufzyklus (A3)

    func testDeliveredItemIsNotAnnouncedAgainInTheSameCycle() {
        let milk = pattern("Milch", last: date(9, 12))
        let log = ReplenishmentDigestLog(defaults: defaults)
        log.replace(with: plan([milk], now: date(9, 21)))

        // Vor der Zustellung neu geplant: der Artikel bleibt drin.
        log.commitDelivered(now: date(9, 22, hour: 8), to: ledger)
        XCTAssertEqual(plan([milk], now: date(9, 22, hour: 8)).map(\.itemNames), [["Milch"]])
        XCTAssertEqual(log.planned().count, 1)

        // Nach der Zustellung: kein zweites Mal, auch nicht als überfälliger Artikel.
        log.commitDelivered(now: date(9, 22), to: ledger)
        XCTAssertTrue(log.planned().isEmpty)
        XCTAssertTrue(plan([milk], now: date(9, 22)).isEmpty)
        XCTAssertTrue(plan([milk], now: date(9, 25)).isEmpty)
    }

    func testNewPurchaseMakesItemNotifiableAgain() {
        let milk = pattern("Milch", last: date(9, 12))
        let log = ReplenishmentDigestLog(defaults: defaults)
        log.replace(with: plan([milk], now: date(9, 21)))
        log.commitDelivered(now: date(9, 22), to: ledger)

        let bought = pattern("Milch", last: date(9, 23))
        XCTAssertEqual(plan([bought], now: date(9, 30)).first?.deliveryDate, date(10, 3, hour: 9))
    }

    func testSnoozeAllowsOneMoreNotificationAtTheShiftedDate() {
        let milk = pattern("Milch", last: date(9, 12))
        let log = ReplenishmentDigestLog(defaults: defaults)
        log.replace(with: plan([milk], now: date(9, 21)))
        log.commitDelivered(now: date(9, 22), to: ledger)

        let snoozed = milk.applying(ReplenishmentSnooze(
            itemName: "Milch", purchaseKey: milk.purchaseKey, snoozedUntil: date(9, 27).timeIntervalSince1970
        ))
        let digests = plan([snoozed], now: date(9, 22))
        XCTAssertEqual(digests.first?.deliveryDate, date(9, 27, hour: 9))
        XCTAssertEqual(digests.first?.itemNames, ["Milch"])

        log.replace(with: digests)
        log.commitDelivered(now: date(9, 27), to: ledger)
        XCTAssertTrue(plan([snoozed], now: date(9, 27)).isEmpty, "Am verschobenen Termin nur einmal.")
    }

    func testCountryChangeDoesNotRepeatTheNotification() throws {
        // Gleiche Käufe, anderes Land: Der Termin kann sich verschieben, der Kaufzyklus nicht.
        let records = [date(9, 1), date(9, 11), date(9, 21)].map { day -> PurchaseRecord in
            let record = PurchaseRecord(itemName: "Milch", storeName: "Edeka")
            record.date = day
            return record
        }
        let us = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar))
        let de = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))
        ledger.markNotified(us)
        XCTAssertFalse(ledger.shouldNotify(de))
    }

    // MARK: - Kandidaten

    func testCandidatesIgnoreTheBannerWindowButRespectFeedbackAndOpenItems() {
        let milk = pattern("Milch", last: date(9, 12))
        let flour = pattern("Mehl", gap: 20, last: date(9, 12))
        let butter = pattern("Butter", last: date(9, 12))
        let eggs = pattern("Eier", last: date(9, 12))
        let salt = pattern("Salz", last: date(9, 12))
        let cheese = pattern("Käse", last: date(9, 12))

        let candidates = HabitService.notificationCandidates(
            from: [milk, flour, butter, eggs, salt, cheese],
            blocked: ["butter"],
            dismissed: ["eier": eggs.purchaseKey, "käse": date(9, 1).timeIntervalSince1970],
            pendingNames: ["salz"]
        )

        XCTAssertEqual(
            Set(candidates.map(\.itemName)), ["Milch", "Mehl", "Käse"],
            "Mehl ist erst in 11 Tagen fällig, die Ablehnung von Käse galt einem früheren Kauf."
        )
    }

    // MARK: - Text

    func testSingleItemKeepsItsOwnTextAndSeveralAreListed() {
        let single = ReplenishmentDigest(deliveryDate: date(9, 22, hour: 9), entries: [entry("Milch")])
        XCTAssertTrue(single.body.contains("Milch"))
        XCTAssertFalse(single.title.contains("1"))

        let several = ReplenishmentDigest(
            deliveryDate: date(9, 22, hour: 9),
            entries: [entry("Butter"), entry("Eier"), entry("Milch")]
        )
        XCTAssertTrue(several.title.contains("3"), several.title)
        for name in ["Butter", "Eier", "Milch"] {
            XCTAssertTrue(several.body.contains(name), several.body)
        }
    }

    // MARK: - Hintergrundaktualisierung

    func testBackgroundRefreshRunsBeforeTheMorningDigest() {
        XCTAssertEqual(
            ReplenishmentBackgroundRefresh.earliestBeginDate(after: date(9, 21, hour: 3), calendar: calendar),
            date(9, 21, hour: 5)
        )
        XCTAssertEqual(
            ReplenishmentBackgroundRefresh.earliestBeginDate(after: date(9, 21), calendar: calendar),
            date(9, 22, hour: 5)
        )
    }

    // MARK: - Helpers

    private var ledger: OverdueNotificationLedger { OverdueNotificationLedger(defaults: defaults) }

    private func plan(_ candidates: [ConsumptionPattern], now: Date) -> [ReplenishmentDigest] {
        ReplenishmentDigestPlanner.plan(candidates: candidates, ledger: ledger, now: now, calendar: calendar)
    }

    private func entry(_ name: String) -> ReplenishmentDigest.Entry {
        ReplenishmentDigest.Entry(itemName: name, notificationKey: 0)
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Regelmäßiger Artikel mit 3 Kauftagen, der vorgeschlagen werden darf (B2).
    private func pattern(_ name: String, gap: Double = 10, last: Date) -> ConsumptionPattern {
        ConsumptionPattern(
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
