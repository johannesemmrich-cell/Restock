import Foundation

/// Bewusst OHNE hartkodierte TimeZone (z.B. `TimeZone(identifier: "Europe/Berlin")`): der
/// Produktionscode (`consumptionPattern()`, `ConsumptionPattern.daysUntilNeeded`) rechnet über
/// `Calendar.current`/`Date()`, also die System-Zeitzone des jeweiligen Rechners. Würden diese
/// Fixtures eine feste Zeitzone erzwingen, liefen sie lokal grün, aber auf einem CI-Runner mit
/// abweichender Standard-Zeitzone (GitHub Actions macOS-Runner laufen auf UTC) rot — nur weil
/// Test und Produktionscode dann nicht mehr dieselbe Zeitzone annehmen. Alle Fixtures hier sind
/// deshalb relativ zu `Date()`/`Calendar.current`, nie an ein festes Kalenderdatum gebunden.
enum DateFixtures {
    static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    static func daysFromNow(_ n: Int) -> Date {
        daysAgo(-n)
    }
}
