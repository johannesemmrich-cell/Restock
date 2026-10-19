import Foundation

/// Community-Preise (Issue #163, Weg A): ein anonymer Pool in der öffentlichen CloudKit-Datenbank,
/// gefüllt von Nutzern, die den Schalter „Preise anonym mit anderen teilen" eingeschaltet haben.
/// Diese Datei enthält nur reine Logik ohne CloudKit (Kette, Artikelschlüssel, Aggregat, Zwischen-
/// speicher in der App-Gruppe), damit `ShoppingItem.init` synchron lesen kann und Widget sowie
/// Teilen-Erweiterung mitkompilieren. Netzzugriff: `CommunityPriceService` (nur App-Ziel).
enum CommunityPrice {
    /// Quelle am Artikel: `"community:<Anzeigename der Kette>"`, `priceOrigin` = `"community"`.
    static let sourcePrefix = "community:"
    /// Ein Community-Preis gilt erst ab so vielen Beobachtungen derselben Kette …
    static let minimumObservations = 3
    /// … innerhalb dieser Frist …
    static let maximumAgeDays = 180
    /// … als Median der jüngsten so vielen Beobachtungen.
    static let maximumObservationsPerAggregate = 20

    /// Kette aus dem Ladennamen: erstes Wort, kleingeschrieben, nur Buchstaben und Ziffern
    /// („Rewe City" → „rewe", „dm-drogerie markt" → „dm", „Aldi Süd" → „aldi").
    static func chain(fromStoreName name: String) -> String {
        var word = ""
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                word.unicodeScalars.append(scalar)
            } else if !word.isEmpty {
                break
            }
        }
        return word
    }

    /// Anzeigename der Kette: erstes Wort des Ladennamens, wie der Nutzer es schreibt.
    static func chainDisplayName(fromStoreName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let first = trimmed.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "/" }).first
        return first.map(String.init) ?? trimmed
    }

    /// Artikelschlüssel wie `Store.learnedPrices`: kleingeschrieben, ohne Rand-Leerzeichen.
    static func itemKey(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Eine Beobachtung aus dem Pool: Preis je Bezugsgröße (`"stk"`/`"g"`, wie `learnedPriceUnits`).
    struct Observation: Equatable {
        let price: Double
        let unit: String
        let observedAt: Date
    }

    /// Verdichteter Wert je Kette und Artikel, so im Zwischenspeicher abgelegt.
    struct Aggregate: Equatable, Codable {
        let price: Double
        let unit: String
        let count: Int
        let latest: Date
    }

    /// Median der jüngsten `maximumObservationsPerAggregate` Beobachtungen innerhalb von
    /// `maximumAgeDays`, nur bei mindestens `minimumObservations`. Bei gemischten Bezugsgrößen
    /// zählt die häufigste (Gleichstand: alphabetisch kleinere), die anderen werden ignoriert —
    /// eine Gramm-Rate und ein Stückpreis dürfen nie in einen Median fließen.
    static func aggregate(_ observations: [Observation], now: Date = Date()) -> Aggregate? {
        let cutoff = now.addingTimeInterval(-Double(maximumAgeDays) * 86_400)
        let recent = observations
            .filter { $0.observedAt >= cutoff && $0.price > 0 && !$0.unit.isEmpty }
            .sorted { $0.observedAt > $1.observedAt }
        guard !recent.isEmpty else { return nil }
        var unitCounts: [String: Int] = [:]
        for observation in recent { unitCounts[observation.unit, default: 0] += 1 }
        let unit = unitCounts.sorted { a, b in a.value != b.value ? a.value > b.value : a.key < b.key }[0].key
        let sameUnit = Array(recent.filter { $0.unit == unit }.prefix(maximumObservationsPerAggregate))
        guard sameUnit.count >= minimumObservations else { return nil }
        let prices = sameUnit.map(\.price).sorted()
        let middle = prices.count / 2
        let median = prices.count % 2 == 0 ? (prices[middle - 1] + prices[middle]) / 2 : prices[middle]
        return Aggregate(price: median, unit: unit, count: sameUnit.count, latest: sameUnit[0].observedAt)
    }

    /// Ergebnis der Stufe „Community" für `ShoppingItem.init`.
    struct Resolution: Equatable {
        let price: Double
        let unit: String
        let chainDisplayName: String
        let count: Int
        let latest: Date
        /// `"g"` nur bei `.rateOnly` (Gramm-Rate ohne belegte Menge), wie bei gelernten Preisen.
        let unitOverride: String?
    }

    /// Dieselbe Entscheidungstabelle und Obergrenze wie bei gelernten Preisen (Issue #10, #151):
    /// Bezugsgröße muss zur Einheit des Artikels passen, der Gesamtpreis bleibt unter
    /// `PriceEstimator.maxPlausibleLearnedLineTotal`. Exakter Schlüssel, kein Fuzzy.
    static func resolve(
        forLowercasedName itemLower: String, storeName: String?, itemUnit: String,
        quantityAmount: Double, quantitySource: String, cache: CommunityPriceCache = .shared
    ) -> Resolution? {
        guard let storeName else { return nil }
        let chain = chain(fromStoreName: storeName)
        let key = itemKey(itemLower)
        guard !chain.isEmpty, !key.isEmpty,
              let aggregate = cache.aggregate(chain: chain, itemKey: key) else { return nil }
        let plausibleQuantity = quantityAmount > 0 ? quantityAmount : 1
        guard aggregate.price * plausibleQuantity <= PriceEstimator.maxPlausibleLearnedLineTotal else { return nil }
        switch ShoppingItem.learnedRateUsage(learnedUnit: aggregate.unit, itemUnit: itemUnit, quantitySource: quantitySource) {
        case .reject:
            return nil
        case .apply:
            return Resolution(price: aggregate.price, unit: aggregate.unit, chainDisplayName: chainDisplayName(fromStoreName: storeName),
                              count: aggregate.count, latest: aggregate.latest, unitOverride: nil)
        case .rateOnly:
            return Resolution(price: aggregate.price, unit: aggregate.unit, chainDisplayName: chainDisplayName(fromStoreName: storeName),
                              count: aggregate.count, latest: aggregate.latest, unitOverride: "g")
        }
    }
}

/// Zwischenspeicher der Aggregate je „Kette|Artikelschlüssel" in der App-Gruppe. Gefüllt von
/// `CommunityPriceService.refresh`, gelesen von `ShoppingItem.init` (synchron, ohne Netz).
struct CommunityPriceCache {
    static let storageKey = "communityPrices.v1"
    static let shared = CommunityPriceCache(
        defaults: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart") ?? .standard)

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    static func key(chain: String, itemKey: String) -> String { "\(chain)|\(itemKey)" }

    func entries() -> [String: CommunityPrice.Aggregate] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: CommunityPrice.Aggregate].self, from: data)
        else { return [:] }
        return decoded
    }

    func aggregate(chain: String, itemKey: String) -> CommunityPrice.Aggregate? {
        entries()[Self.key(chain: chain, itemKey: itemKey)]
    }

    /// Übernimmt die Aggregate einer Abfrage: abgefragte Schlüssel ohne Aggregat werden entfernt
    /// (der Pool hat dafür keine ausreichenden Daten mehr), andere Ketten bleiben unberührt.
    func update(chain: String, queriedKeys: [String], aggregates: [String: CommunityPrice.Aggregate]) {
        var all = entries()
        for key in queriedKeys { all.removeValue(forKey: Self.key(chain: chain, itemKey: key)) }
        for (itemKey, aggregate) in aggregates { all[Self.key(chain: chain, itemKey: itemKey)] = aggregate }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: Self.storageKey) }
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
