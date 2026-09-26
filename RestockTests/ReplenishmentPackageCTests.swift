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
        XCTAssertEqual(entry.purchaseKey, date(9, 12).timeIntervalSince1970, "Gilt weiter für denselben Kaufzyklus.")
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
        XCTAssertNotNil(snoozes.entries()["milch"], "Kein neuer Kauf → bleibt.")
        snoozes.prune(keeping: [afterPurchase])
        XCTAssertNil(snoozes.entries()["milch"], "Neuer Kauf → aufgeräumt.")
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

    // MARK: - Schlüssel am letzten Kauf (Issue #30, Teil 5, Punkt 1)

    /// Milch alle 8 Tage, zuletzt Sa 19.09. → Termin So 27.09.; in Deutschland (4b) Sa 26.09.
    /// (Alle 7 Tage ab einem Samstag landete wieder auf einem Samstag — dann gäbe es keinen
    /// Unterschied zwischen den Ländern, und der Test prüfte nichts.)
    private func milkRecords() -> [PurchaseRecord] {
        [date(9, 3), date(9, 11), date(9, 19)].map { day in
            let r = PurchaseRecord(itemName: "Milch", storeName: "Edeka")
            r.date = day
            return r
        }
    }

    func testCountryChangeShiftsDateButKeepsPurchaseKey() throws {
        let records = milkRecords()
        let us = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar))
        let de = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))
        XCTAssertNotEqual(us.estimatedNextPurchaseDate, de.estimatedNextPurchaseDate, "Setup: Termin hängt vom Land ab.")
        XCTAssertEqual(us.purchaseKey, de.purchaseKey)
        XCTAssertEqual(de.purchaseKey, date(9, 19).timeIntervalSince1970)
    }

    func testTimeZoneChangeKeepsPurchaseKey() throws {
        // 23:30 und 00:30 UTC am 18./19.09.: in UTC zwei Tage, in Berlin (UTC+2) ein Tag — der
        // zusammengefasste letzte Kauftag beginnt je nach Zeitzone mit einem anderen Datensatz.
        var records = milkRecords().dropLast().map { $0 }
        for day in [date(9, 18, hour: 23).addingTimeInterval(30 * 60), date(9, 19, hour: 0).addingTimeInterval(30 * 60)] {
            let r = PurchaseRecord(itemName: "Milch", storeName: "Edeka")
            r.date = day
            records.append(r)
        }
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let utc = try XCTUnwrap(records.consumptionPattern(calendar: calendar))
        let local = try XCTUnwrap(records.consumptionPattern(calendar: berlin))
        XCTAssertNotEqual(utc.lastPurchaseDate, local.lastPurchaseDate, "Setup: Tagesgrenze hängt von der Zeitzone ab.")
        XCTAssertEqual(utc.purchaseKey, local.purchaseKey)
    }

    func testSnoozeSurvivesCountryChange() throws {
        let records = milkRecords()
        let us = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        snoozes.snooze(us, now: date(9, 26), closedDays: .none, calendar: calendar)

        let de = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))
        snoozes.prune(keeping: [de])
        let entry = try XCTUnwrap(snoozes.entries()["milch"], "Landwechsel ist kein Kauf.")
        XCTAssertTrue(de.applying(entry).isSnoozed)
    }

    func testOverdueNotificationNotRepeatedAfterCountryChange() throws {
        let records = milkRecords()
        let ledger = OverdueNotificationLedger(defaults: defaults)
        ledger.markNotified(try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar)))
        XCTAssertFalse(ledger.shouldNotify(try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))))

        let r = PurchaseRecord(itemName: "Milch", storeName: "Edeka")
        r.date = date(9, 26)
        XCTAssertTrue(ledger.shouldNotify(try XCTUnwrap((records + [r]).consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))), "Neuer Kauf → wieder meldefähig.")
    }

    func testAcceptedSuggestionDeletedAfterCountryChangeIsStillDismissed() throws {
        let records = milkRecords()
        let us = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("US"), calendar: calendar))
        let de = try XCTUnwrap(records.consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))
        let result = ReplenishmentFeedback.resolveAccepted(
            [UUID(): AcceptedReplenishment(itemName: us.itemName, purchaseKey: us.purchaseKey)],
            existingItemIDs: [], pendingNames: [], patterns: [de]
        )
        XCTAssertEqual(result.dismissals, ["milch": de.purchaseKey])
    }

    func testMigrationConvertsCurrentDateKeyedEntriesAndDropsStaleOnes() throws {
        let milk = try XCTUnwrap(milkRecords().consumptionPattern(closedDays: .forCountry("DE"), calendar: calendar))
        let estimated = milk.estimatedNextPurchaseDate.timeIntervalSince1970
        let stale = date(9, 1).timeIntervalSince1970
        let id = UUID()
        let staleID = UUID()

        defaults.set(try JSONEncoder().encode(["milch": estimated, "brot": stale]), forKey: ReplenishmentKeyMigration.dismissedKey)
        defaults.set(["milch": estimated, "butter": stale], forKey: OverdueNotificationLedger.defaultsKey)
        struct LegacySnooze: Encodable { let itemName: String; let baseDate: TimeInterval; let snoozedUntil: TimeInterval }
        defaults.set(try JSONEncoder().encode([
            "milch": LegacySnooze(itemName: "Milch", baseDate: estimated, snoozedUntil: date(10, 1).timeIntervalSince1970),
        ]), forKey: ReplenishmentSnoozes.defaultsKey)
        struct LegacyAccepted: Encodable { let itemName: String; let estimatedNextPurchaseDate: TimeInterval }
        defaults.set(try JSONEncoder().encode([
            id: LegacyAccepted(itemName: "Milch", estimatedNextPurchaseDate: estimated),
            staleID: LegacyAccepted(itemName: "Milch", estimatedNextPurchaseDate: stale),
        ]), forKey: ReplenishmentKeyMigration.acceptedKey)
        defaults.set(["milch|\(estimated)": date(9, 25).timeIntervalSince1970], forKey: ReplenishmentMetrics.shownKey)

        ReplenishmentKeyMigration.runIfNeeded(patterns: [milk], defaults: defaults)

        let key = milk.purchaseKey
        let dismissed = try JSONDecoder().decode([String: TimeInterval].self, from: try XCTUnwrap(defaults.data(forKey: ReplenishmentKeyMigration.dismissedKey)))
        XCTAssertEqual(dismissed, ["milch": key])
        XCTAssertFalse(OverdueNotificationLedger(defaults: defaults).shouldNotify(milk))
        XCTAssertEqual(defaults.dictionary(forKey: OverdueNotificationLedger.defaultsKey) as? [String: TimeInterval], ["milch": key])
        XCTAssertEqual(ReplenishmentSnoozes(defaults: defaults).entries()["milch"], ReplenishmentSnooze(itemName: "Milch", purchaseKey: key, snoozedUntil: date(10, 1).timeIntervalSince1970))
        let accepted = try JSONDecoder().decode([UUID: AcceptedReplenishment].self, from: try XCTUnwrap(defaults.data(forKey: ReplenishmentKeyMigration.acceptedKey)))
        XCTAssertEqual(accepted, [id: AcceptedReplenishment(itemName: "Milch", purchaseKey: key)])
        let metrics = ReplenishmentMetrics(defaults: defaults)
        metrics.recordShown([milk], now: date(9, 26))
        XCTAssertEqual(metrics.count(.shown), 0, "Schon vor dem Update gezeigt — nicht doppelt zählen.")

        // Läuft nur einmal: spätere Einträge werden nicht erneut umgerechnet.
        defaults.set(try JSONEncoder().encode(["milch": estimated]), forKey: ReplenishmentKeyMigration.dismissedKey)
        ReplenishmentKeyMigration.runIfNeeded(patterns: [milk], defaults: defaults)
        let untouched = try JSONDecoder().decode([String: TimeInterval].self, from: try XCTUnwrap(defaults.data(forKey: ReplenishmentKeyMigration.dismissedKey)))
        XCTAssertEqual(untouched, ["milch": estimated])
    }

    // MARK: - Helpers

    // MARK: - C4: Vielleicht auch fällig (bis zum nächsten Besuch im Laden)

    func testVisitGapIsMedianOfRecentVisitDays() {
        // Wöchentlich, zwei Käufe am selben Tag zählen als ein Besuch.
        let dates = [date(8, 1), date(8, 8), date(8, 8, hour: 18), date(8, 15), date(8, 22), date(8, 29)]
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: dates, visitsPerWeek: 3, calendar: calendar), 7)

        // Früher alle 2 Tage, zuletzt 8 Besuche im Wochenabstand: nur die letzten Besuche zählen.
        let old = (0..<6).map { date(6, 1 + 2 * $0) }
        let recent = (0..<8).map { calendar.date(byAdding: .day, value: 7 * $0, to: date(7, 1))! }
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: old + recent, visitsPerWeek: 1, calendar: calendar), 7)
    }

    func testVisitGapFallsBackToVisitFrequencyAndIsClamped() {
        let twoVisits = [date(9, 1), date(9, 8)]
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: twoVisits, visitsPerWeek: 2, calendar: calendar), 3.5)
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: [], visitsPerWeek: 0, calendar: calendar), 7)
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: [], visitsPerWeek: 0.1, calendar: calendar), 28, "Höchstens 4 Wochen.")
        XCTAssertEqual(StoreVisitForecast.visitGapDays(purchaseDates: [], visitsPerWeek: 14, calendar: calendar), 1, "Mindestens 1 Tag.")
    }

    func testItemRunningOutBeforeNextVisitIsSuggestedEvenOutsideBannerWindow() {
        // Alle 10 Tage, zuletzt 12.09. → Termin 22.09., Fenster 2 Tage: am 17.09. nicht im Banner.
        let milk = pattern(gap: 10, last: date(9, 12))
        XCTAssertTrue(due([milk], at: date(9, 17)).isEmpty, "Setup: nicht im Banner.")

        XCTAssertEqual(alsoDue([milk], at: date(9, 17), visitGap: 7).map(\.itemName), ["Milch"],
                       "Nächster Besuch 24.09. — Milch geht vorher aus.")
        XCTAssertTrue(alsoDue([milk], at: date(9, 17), visitGap: 3).isEmpty,
                      "Nächster Besuch 20.09. — Milch reicht noch.")
        XCTAssertTrue(alsoDue([milk], at: date(9, 17), visitGap: 5).isEmpty,
                      "Fällig genau am Tag des nächsten Besuchs — dann reicht es, dort zu kaufen.")
    }

    func testBannerItemsAreAlwaysIncluded() {
        // Termin 22.09., am 21.09. im Banner; nächster Besuch schon am 22.09.
        let milk = pattern(gap: 10, last: date(9, 12))
        XCTAssertEqual(alsoDue([milk], at: date(9, 21), visitGap: 1).count, 1)
        let overdue = pattern(name: "Brot", gap: 4, last: date(9, 12))
        XCTAssertEqual(alsoDue([overdue], at: date(9, 18), visitGap: 1).map(\.itemName), ["Brot"])
    }

    func testAlsoDueUsesTheSameFiltersAsTheBanner() {
        let milk = pattern(gap: 10, last: date(9, 12))
        let now = date(9, 17)
        XCTAssertTrue(alsoDue([milk], at: now, visitGap: 7, belongs: false).isEmpty, "Gehört in einen anderen Laden.")
        XCTAssertTrue(alsoDue([milk], at: now, visitGap: 7, pendingNames: ["milch"]).isEmpty, "Steht schon auf einer Liste.")
        XCTAssertTrue(alsoDue([milk], at: now, visitGap: 7, blocked: ["milch"]).isEmpty, "Nicht mehr vorschlagen.")
        XCTAssertTrue(alsoDue([milk], at: now, visitGap: 7, dismissed: ["milch": milk.purchaseKey]).isEmpty, "A4-Ablehnung.")
        XCTAssertEqual(alsoDue([milk], at: now, visitGap: 7, dismissed: ["milch": milk.purchaseKey - 86400]).count, 1,
                       "Ablehnung eines früheren Kaufzyklus gilt nicht mehr.")

        var twoPurchases = milk
        twoPurchases.purchaseCount = 2
        XCTAssertTrue(alsoDue([twoPurchases], at: now, visitGap: 7).isEmpty, "B2: erst ab 3 Käufen.")
    }

    func testAlsoDueIsSortedByDate() {
        let later = pattern(name: "Milch", gap: 10, last: date(9, 12))   // 22.09.
        let sooner = pattern(name: "Eier", gap: 8, last: date(9, 12))    // 20.09.
        XCTAssertEqual(alsoDue([later, sooner], at: date(9, 17), visitGap: 7).map(\.itemName), ["Eier", "Milch"])
    }

    func testSnoozeInStoreListLastsAtLeastUntilNextVisit() {
        let milk = pattern(gap: 10, last: date(9, 12))
        let now = date(9, 17)
        let nextVisit = StoreVisitForecast.nextVisit(after: now, gapDays: 13, calendar: calendar)
        XCTAssertEqual(nextVisit, date(9, 30))

        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        XCTAssertEqual(snoozes.snooze(milk, now: now, closedDays: .none, calendar: calendar), date(9, 27), "Ohne Mindestdatum wie im Banner.")
        let until = snoozes.snooze(milk, now: now, notBefore: nextVisit, closedDays: .none, calendar: calendar)
        XCTAssertEqual(until, date(9, 30))
        XCTAssertTrue(alsoDue([milk], at: now, visitGap: 13, snoozes: snoozes.entries()).isEmpty,
                      "Nach „Hab noch“ nicht sofort wieder in der Ladenliste.")
    }

    func testTrackAcceptedStoresSuggestionForA4AndCountsIt() throws {
        let milk = pattern(gap: 10, last: date(9, 12))
        let id = UUID()
        ReplenishmentFeedback.trackAccepted(itemID: id, from: milk, defaults: defaults)

        let data = try XCTUnwrap(defaults.data(forKey: ReplenishmentKeyMigration.acceptedKey))
        let map = try JSONDecoder().decode([UUID: AcceptedReplenishment].self, from: data)
        XCTAssertEqual(map, [id: AcceptedReplenishment(itemName: "Milch", purchaseKey: milk.purchaseKey)])
        XCTAssertEqual(ReplenishmentMetrics(defaults: defaults).count(.accepted), 1)
    }

    // MARK: - C5: Gleichwertige Namen

    /// Gelernte Bon-Zuordnungen wie in `ReceiptAliasService` (dort normalisiert nachgeschlagen).
    private let aliases = ReplenishmentItemIdentity { name in
        ["milch 1 5% 1l": "Milch"][name.lowercased().replacingOccurrences(of: ",", with: " ")]
    }

    func testFormalKeyIgnoresCaseSpacesAndEdgePunctuationOnly() {
        let key = ReplenishmentItemIdentity.formalKey
        XCTAssertEqual(key("Milch"), "milch")
        XCTAssertEqual(key("  MILCH  "), "milch")
        XCTAssertEqual(key("Frische   Milch"), "frische milch")
        XCTAssertEqual(key("Milch."), "milch")
        XCTAssertEqual(key("„Milch“"), "milch")
        XCTAssertEqual(key("- Milch -"), "milch")
        XCTAssertEqual(key("H-Milch"), "h-milch", "Satzzeichen im Wort bleiben.")
        XCTAssertEqual(key("Milch 1,5%"), "milch 1,5%", "Inhaltliche Zeichen am Rand bleiben.")
        XCTAssertEqual(key("Eier (10)"), "eier (10)")
        XCTAssertEqual(key("..."), "...", "Nie ein leerer Schlüssel.")
    }

    func testDifferentProductsAreNeverMerged() {
        let names = ["Milch", "H-Milch", "Hafermilch", "Buttermilch", "Milch 1,5%", "Vollmilch"]
        let records = names.flatMap { name in [(9, 1), (9, 8), (9, 15)].map { record(name, $0.0, $0.1) } }
        let patterns = HabitService.patterns(allRecords: records, closedDays: .none, calendar: calendar, identity: aliases)
        XCTAssertEqual(Set(patterns.map(\.itemName)), Set(names))
        XCTAssertTrue(patterns.allSatisfy { $0.purchaseCount == 3 })
    }

    func testFormalVariantsAreMergedUnderTheLatestName() throws {
        let records = [record("milch", 9, 1), record("Milch ", 9, 8), record("  MILCH.", 9, 15), record("Milch", 9, 22)]
        let patterns = HabitService.patterns(allRecords: records, closedDays: .none, calendar: calendar, identity: .formalOnly)
        let milk = try XCTUnwrap(patterns.first)
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(milk.itemName, "Milch", "Angezeigt wird der jüngste Name.")
        XCTAssertEqual(milk.purchaseCount, 4)
        XCTAssertEqual(milk.itemKey, "milch")
    }

    func testConfirmedReceiptAliasCountsTowardsTheListName() throws {
        let records = [record("MILCH 1,5% 1L", 9, 1), record("MILCH 1,5% 1L", 9, 8), record("Milch", 9, 15), record("Milch", 9, 22)]
        XCTAssertEqual(
            HabitService.patterns(allRecords: records, closedDays: .none, calendar: calendar, identity: .formalOnly).count, 2,
            "Ohne bestätigte Zuordnung bleiben Bon-Text und Listenname getrennt."
        )
        let patterns = HabitService.patterns(allRecords: records, closedDays: .none, calendar: calendar, identity: aliases)
        let milk = try XCTUnwrap(patterns.first)
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(milk.itemName, "Milch")
        XCTAssertEqual(milk.purchaseCount, 4)
    }

    func testAliasTargetIsShownEvenIfOnlyReceiptRecordsExist() throws {
        let records = [record("MILCH 1,5% 1L", 9, 1), record("MILCH 1,5% 1L", 9, 8), record("MILCH 1,5% 1L", 9, 15)]
        let milk = try XCTUnwrap(HabitService.patterns(allRecords: records, closedDays: .none, calendar: calendar, identity: aliases).first)
        XCTAssertEqual(milk.itemName, "Milch", "Ein übernommener Vorschlag kommt unter dem bestätigten Namen auf die Liste.")
    }

    func testBacktestUsesMergedHistory() {
        let records = [record("Milch", 9, 1), record("milch ", 9, 8), record("MILCH 1,5% 1L", 9, 15), record("Milch", 9, 22)]
        XCTAssertEqual(HabitService.backtest(allRecords: records, closedDays: .none, calendar: calendar, identity: aliases).evaluated, 1)
        XCTAssertEqual(HabitService.backtest(allRecords: records, closedDays: .none, calendar: calendar, identity: .formalOnly).evaluated, 0)
    }

    func testPendingVariantSuppressesTheSuggestion() {
        let milk = pattern(gap: 10, last: date(9, 12))
        let pending = Set(["MILCH 1,5% 1L"].map(aliases.key))
        XCTAssertTrue(HabitService.notificationCandidates(from: [milk], pendingNames: pending).isEmpty)
        XCTAssertTrue(HabitService.notificationCandidates(from: [milk], pendingNames: [aliases.key(" milch ")]).isEmpty)
        XCTAssertEqual(HabitService.notificationCandidates(from: [milk], pendingNames: [aliases.key("H-Milch")]).count, 1)
    }

    func testBlocklistAndSnoozeMatchFormalVariants() {
        let blocklist = ReplenishmentBlocklist(defaults: defaults)
        blocklist.block("Milch")
        XCTAssertTrue(blocklist.contains(" milch "))
        XCTAssertFalse(blocklist.contains("H-Milch"))
        blocklist.unblock("MILCH.")
        XCTAssertTrue(blocklist.names().isEmpty)

        let milk = pattern(name: "Milch ", gap: 10, last: date(9, 12))
        let snoozes = ReplenishmentSnoozes(defaults: defaults)
        snoozes.snooze(milk, now: date(9, 21), closedDays: .none, calendar: calendar)
        XCTAssertEqual(Array(snoozes.entries().keys), ["milch"])
        snoozes.remove("MILCH")
        XCTAssertTrue(snoozes.entries().isEmpty)
    }

    private func record(_ name: String, _ month: Int, _ day: Int) -> PurchaseRecord {
        let record = PurchaseRecord(itemName: name, storeName: "Rewe")
        record.date = date(month, day)
        return record
    }

    private func alsoDue(
        _ patterns: [ConsumptionPattern],
        at now: Date,
        visitGap: Double,
        belongs: Bool = true,
        snoozes: [String: ReplenishmentSnooze] = [:],
        blocked: Set<String> = [],
        dismissed: [String: TimeInterval] = [:],
        pendingNames: Set<String> = []
    ) -> [ConsumptionPattern] {
        HabitService.dueBeforeNextVisit(
            from: patterns,
            visitGapDays: visitGap,
            now: now,
            calendar: calendar,
            snoozes: snoozes,
            blocked: blocked,
            dismissed: dismissed,
            pendingNames: pendingNames
        ) { _ in belongs }
    }

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
