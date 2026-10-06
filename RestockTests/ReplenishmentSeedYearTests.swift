import XCTest
@testable import Restock

/// Issue #115: Der UI-Test-Seed für Nachkauf-Banner und „Vielleicht auch fällig“
/// (`SmartCartApp.replenishmentSeedDaysAgo`) muss an JEDEM Zeitpunkt dasselbe Bild ergeben —
/// die Käufe sind relativ zu „jetzt“ gesetzt, die App rechnet Fälligkeit aber mit Schließtagen
/// (Sonntag/Feiertag, 4b) und ab Uhrzeit (`daysUntilNeeded`). Mit −37/−23/−9 Tagen kippte
/// „Listenreis“ jeden Dienstag ab 13 Uhr in den Banner, und `ReplenishmentUITests` wurde rot.
///
/// Der Test rechnet den Seed für jede Stunde eines Jahres durch (Europe/Berlin, Land DE, also mit
/// Feiertagen und Zeitumstellung) und prüft, was `HabitService` daraus macht.
final class ReplenishmentSeedYearTests: XCTestCase {

    private let bannerItems = ["Bannerbutter", "Bannerquark"]
    private let listItems = ["Listenreis", "Listennudeln"]

    private var berlin: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func records(at now: Date) -> [PurchaseRecord] {
        var result: [PurchaseRecord] = []
        for seed in SmartCartApp.replenishmentSeedDaysAgo {
            for name in seed.items {
                for days in seed.daysAgo {
                    guard let day = berlin.date(byAdding: .day, value: -days, to: now),
                          let noon = berlin.date(bySettingHour: 12, minute: 0, second: 0, of: day) else { continue }
                    let record = PurchaseRecord(itemName: name, storeName: seed.store)
                    record.date = noon
                    result.append(record)
                }
            }
        }
        return result
    }

    private func describe(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = berlin
        formatter.timeZone = berlin.timeZone
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EE dd.MM.yy HH:mm"
        return formatter.string(from: date)
    }

    func testSeedGivesTheSamePictureForEveryHourOfAYear() throws {
        let start = try XCTUnwrap(berlin.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let closedDays = RetailClosedDays.forCountry("DE")
        var failures: [String] = []
        var hours = 0

        for hour in 0..<(365 * 24) {
            let now = start.addingTimeInterval(Double(hour) * 3600)
            hours += 1
            let allRecords = records(at: now)
            let patterns = HabitService.patterns(allRecords: allRecords, closedDays: closedDays, calendar: berlin)
            let banner = Set(HabitService.dueSoonItems(from: patterns, now: now).map(\.itemName))

            for name in bannerItems where !banner.contains(name) {
                failures.append("\(describe(now)): „\(name)“ fehlt im Banner")
            }
            for name in listItems where banner.contains(name) {
                failures.append("\(describe(now)): „\(name)“ steht im Banner")
            }

            let listStoreDates = allRecords.filter { $0.storeName == "Listenladen" }.map(\.date)
            let gap = StoreVisitForecast.visitGapDays(purchaseDates: listStoreDates, visitsPerWeek: 1, calendar: berlin)
            let alsoDue = Set(HabitService.dueBeforeNextVisit(
                from: patterns, visitGapDays: gap, now: now, calendar: berlin
            ) { [listItems] pattern in listItems.contains(pattern.itemName) }.map(\.itemName))
            for name in listItems where !alsoDue.contains(name) {
                failures.append("\(describe(now)): „\(name)“ fehlt in „Vielleicht auch fällig“")
            }
        }

        XCTAssertEqual(hours, 8760)
        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count) Abweichungen in \(hours) Stunden, die ersten: \n"
                      + failures.prefix(12).joined(separator: "\n"))
    }
}
