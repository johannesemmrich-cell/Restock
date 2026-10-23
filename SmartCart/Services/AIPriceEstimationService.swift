import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

// Issue #164: KI-Preisschätzung als Stufe VOR der Kategorie-Pauschale — nur für Artikel, für die
// eigene Preise, Community (#163) und Katalog (#162) nichts liefern (`priceSource == "category"`).
// Reihenfolge und Rahmen vom PO (2026-10-18): Daten und Regeln zuerst, KI für den Rest; Gerätemodell
// (`FoundationModels`, iOS 26+) zuerst, Cloud-Modell nur nach Nachweis in einem eigenen Issue.
// Die Stufe ist AUS, bis der Nachweis (Prüfsatz, ≥ 70 % innerhalb ±30 %, `AIPriceEvaluationTests`,
// `scripts/run-ai-price-eval.sh`) bestanden ist: `AIPriceEstimation.isEnabled(in:)` liest den
// Schlüssel `aiPriceEstimationEnabled` (Standard aus; Schalter im Entwicklermodus).
//
// Was das Gerät verlässt: nichts — das Modell läuft auf dem Gerät. Eingabe sind Artikelname,
// Menge/Einheit, Kategorie und Land/Währung; kein Laden, kein Nutzername, keine Historie.

/// Eingabe für das Modell: harmlos, ohne Laden und Historie.
struct AIPriceRequest: Equatable, Sendable {
    let itemName: String
    let quantityAmount: Double
    let unit: String
    let category: String
    var country: String = "Deutschland"
    var currency: String = "EUR"

    /// Schlüssel im Zwischenspeicher: Artikelschlüssel plus Bezugsgröße der Einheit, damit „Mehl“
    /// (Stück) und „Mehl 500 g“ (Gewicht) getrennt liegen.
    var cacheKey: String { "\(CommunityPrice.itemKey(itemName))|\(ShoppingItem.unitBucket(unit))" }
}

/// Strukturierte Antwort des Modells: typische Packung und Spanne je Packung in Euro. Nie Freitext.
struct AIPriceGuess: Equatable, Codable, Sendable {
    let packageAmount: Double
    let packageUnit: String
    let low: Double
    let typical: Double
    let high: Double
}

/// Naht vor dem Modell, damit `AIPriceEstimationTests` mit einem Schein-Modell laufen.
protocol PriceLanguageModel: Sendable {
    var isAvailable: Bool { get }
    /// `nil` bei nicht verfügbarem Modell, Zeitüberschreitung oder unbrauchbarer Antwort.
    func estimate(_ request: AIPriceRequest) async -> AIPriceGuess?
}

#if canImport(FoundationModels)
/// Schema für die geführte Generierung: dieselben Felder wie `AIPriceGuess`.
@available(iOS 26, *)
@Generable
struct AIPriceGuessGenerable {
    @Guide(description: "Typische Packungsgröße als Zahl, z. B. 125 für 125 g oder 1 für ein Stück")
    var packageAmount: Double
    @Guide(description: "Einheit der Packung: genau eines von g, ml oder stk")
    var packageUnit: String
    @Guide(description: "Niedriger Regalpreis je Packung in Euro (Eigenmarke, Discounter)")
    var low: Double
    @Guide(description: "Typischer Regalpreis je Packung in Euro")
    var typical: Double
    @Guide(description: "Hoher Regalpreis je Packung in Euro (Marke)")
    var high: Double
}
#endif

/// Apples Gerätemodell (FoundationModels, iOS 26+ mit eingeschalteter Apple Intelligence).
struct SystemPriceLanguageModel: PriceLanguageModel {
    /// Zeitgrenze wie `RecipeRecognitionService` (echte Grenze über `withRealTimeout`).
    static let timeoutSeconds = 20.0

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    static func prompt(for request: AIPriceRequest) -> String {
        let quantity: String
        if request.quantityAmount > 0, !request.unit.trimmingCharacters(in: .whitespaces).isEmpty {
            quantity = "Menge auf der Liste: \(request.quantityAmount.formatted(.number.locale(Locale(identifier: "de_DE")))) \(request.unit). "
        } else {
            quantity = ""
        }
        let category = request.category.isEmpty ? "" : "Kategorie: \(request.category). "
        return """
        Du schätzt Regalpreise im Lebensmittel- und Drogeriehandel in \(request.country) \
        (Supermarkt, Discounter, Drogeriemarkt), Währung \(request.currency), Stand 2026. \
        Artikel: „\(request.itemName)“. \(category)\(quantity)\
        Nenne die typische Packungsgröße (Zahl und Einheit g, ml oder stk) und die Preisspanne je Packung: \
        niedrig (Eigenmarke/Discounter), typisch, hoch (Marke). Nur die Felder, keine Erklärung.
        """
    }

    func estimate(_ request: AIPriceRequest) async -> AIPriceGuess? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let prompt = Self.prompt(for: request)
        return await withRealTimeout(seconds: Self.timeoutSeconds, operation: {
            // Greedy wie bei der Bon-Namensauflösung (#159): reproduzierbare Messläufe.
            let options = GenerationOptions(sampling: .greedy)
            guard let response = try? await LanguageModelSession().respond(
                to: prompt, generating: AIPriceGuessGenerable.self, options: options) else { return nil }
            let content = response.content
            return AIPriceGuess(packageAmount: content.packageAmount, packageUnit: content.packageUnit,
                                low: content.low, typical: content.typical, high: content.high)
        }, onTimeout: { nil })
        #else
        return nil
        #endif
    }
}

/// Regeln bleiben Code (PO): Plausibilität, Packung gegen Bezugsgröße, Obergrenze; Ergebnis je
/// Namensschlüssel zwischengespeichert, damit derselbe Name deterministisch denselben Preis bekommt.
enum AIPriceEstimation {
    static let isEnabledKey = "aiPriceEstimationEnabled"
    /// Aus, bis der Nachweis bestanden ist (Entscheidung 4 in #164).
    static let isEnabledDefault = false
    static let source = "ai"
    /// Entscheidung 2: Spanne oben/unten höchstens Faktor 3, sonst Pauschale.
    static let maximumRangeFactor = 3.0
    /// Ein verworfener oder ausgebliebener Versuch wird so lange nicht wiederholt (Tage).
    static let retryAfterDays = 30
    /// Höchstens so viele Modellaufrufe je Listenöffnung, damit das Öffnen nicht minutenlang rechnet.
    static let maximumCallsPerFill = 8

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: isEnabledKey) as? Bool) ?? isEnabledDefault
    }

    /// Ergebnis der Prüfung: Rate je Einheit des Artikels (wie `estimatedPrice`), dazu die Packung
    /// und Spanne für das Bearbeiten-Sheet.
    struct Resolution: Equatable {
        let perUnitPrice: Double
        let guess: AIPriceGuess
    }

    /// Normalisiert die Einheit des Modells („Gramm“, „Stück“, „ML“ → `g`/`stk`/`ml`), sonst `nil`.
    static func normalizedPackageUnit(_ raw: String) -> String? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gramm", "gram", "grams": return "g"
        case "kg", "kilogramm", "kilo": return "kg"
        case "ml", "milliliter", "millilitre": return "ml"
        case "l", "liter", "litre": return "l"
        case "stk", "stück", "stueck", "st", "stk.", "stück.", "piece", "pieces", "pack", "packung", "pcs": return "stk"
        default: return nil
        }
    }

    /// Prüft die Antwort und rechnet sie auf die Einheit des Artikels um; `nil` = verworfen (→ Pauschale).
    /// - Spanne: 0 < low ≤ typical ≤ high, high/low ≤ `maximumRangeFactor`.
    /// - Packung: Einheit g/ml/stk (kg/l werden umgerechnet), Menge > 0; ein Gewichts-/Volumenartikel
    ///   (`unitBucket == "g"`) braucht eine Gewichts-/Volumenpackung, sonst wäre der Stückpreis eine
    ///   Rate je kg/l und die Zeile zeigte Unsinn (Regel aus `learnedRateUsage`, Issue #10).
    /// - Gesamtpreis der Zeile ≤ `PriceEstimator.maxPlausibleLineTotal`.
    static func validate(_ guess: AIPriceGuess, for request: AIPriceRequest) -> Resolution? {
        guard guess.low > 0, guess.low <= guess.typical, guess.typical <= guess.high,
              guess.high / guess.low <= maximumRangeFactor,
              guess.packageAmount > 0, guess.packageAmount.isFinite, guess.typical.isFinite else { return nil }
        guard var unit = normalizedPackageUnit(guess.packageUnit) else { return nil }
        var amount = guess.packageAmount
        if unit == "kg" { unit = "g"; amount *= 1000 }
        if unit == "l" { unit = "ml"; amount *= 1000 }
        let itemBucket = ShoppingItem.unitBucket(request.unit)
        if itemBucket == "g", unit == "stk" { return nil }
        let normalized = AIPriceGuess(packageAmount: amount, packageUnit: unit, low: guess.low, typical: guess.typical, high: guess.high)
        let entry = PriceCatalogEntry(names: [request.cacheKey], packageAmount: amount, packageUnit: unit,
                                      low: guess.low, typical: guess.typical, high: guess.high, source: source)
        let perUnit = PriceCatalog.perUnitPrice(for: entry, itemUnit: request.unit)
        let quantity = request.quantityAmount > 0 ? request.quantityAmount : 1
        guard perUnit > 0, perUnit * quantity <= PriceEstimator.maxPlausibleLineTotal else { return nil }
        return Resolution(perUnitPrice: perUnit, guess: normalized)
    }
}

/// Zwischenspeicher je Namensschlüssel in der App-Gruppe (`aiPrices.v1`): angenommene Antworten
/// mit Packung und Spanne, dazu verworfene/ausgebliebene Versuche als Sperre bis `retryAfterDays`.
struct AIPriceCache {
    static let storageKey = "aiPrices.v1"
    static let shared = AIPriceCache(defaults: UserDefaults(suiteName: "group.com.johannesemmrich.SmartCart") ?? .standard)

    struct Entry: Codable, Equatable {
        /// `nil` = Versuch ohne brauchbares Ergebnis (verworfen oder keine Antwort).
        let guess: AIPriceGuess?
        let date: Date
    }

    let defaults: UserDefaults

    func entries() -> [String: Entry] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return decoded
    }

    func entry(for key: String) -> Entry? { entries()[key] }

    func store(_ guess: AIPriceGuess?, for key: String, at date: Date = Date()) {
        var all = entries()
        all[key] = Entry(guess: guess, date: date)
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: Self.storageKey) }
    }

    func remove(_ key: String) {
        var all = entries()
        all.removeValue(forKey: key)
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: Self.storageKey) }
    }

    func clear() { defaults.removeObject(forKey: Self.storageKey) }

    /// Ein Fehlversuch sperrt den Schlüssel bis `retryAfterDays`; danach darf das Modell erneut gefragt werden.
    static func isRetryDue(_ entry: Entry, now: Date) -> Bool {
        entry.guess == nil && now.timeIntervalSince(entry.date) > Double(AIPriceEstimation.retryAfterDays) * 86_400
    }
}

/// Fragt das Modell für Artikel ohne datenbasierten Preis, prüft, speichert und schreibt die Rate an
/// den Artikel (`priceSource = "ai"`, weiter automatisch hergeleitet). Aufruf aus
/// `StoreDetailView.task` NACH `CommunityPriceService.refreshAndApply`, damit Community vorgeht.
actor AIPriceEstimationService {
    static let shared = AIPriceEstimationService(model: SystemPriceLanguageModel(), defaults: .standard, cache: .shared)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SmartCart", category: "aiprice")

    let model: PriceLanguageModel
    let defaults: UserDefaults
    let cache: AIPriceCache
    let now: () -> Date

    init(model: PriceLanguageModel, defaults: UserDefaults, cache: AIPriceCache, now: @escaping () -> Date = Date.init) {
        self.model = model
        self.defaults = defaults
        self.cache = cache
        self.now = now
    }

    var isEnabled: Bool { AIPriceEstimation.isEnabled(in: defaults) }

    /// Artikel, für die die KI-Stufe zuständig ist: offen, automatisch hergeleitet, nur Pauschale oder
    /// gar kein Preis — oder schon KI (damit ein geänderter Zwischenspeicher nachzieht).
    static func isCandidate(_ item: ShoppingItem) -> Bool {
        guard !item.isCompleted, item.estimatedPriceIsAutoDerived else { return false }
        return item.priceOrigin == "category" || item.priceOrigin == AIPriceEstimation.source || item.estimatedPrice == nil
    }

    static func request(for item: ShoppingItem) -> AIPriceRequest {
        AIPriceRequest(itemName: item.name, quantityAmount: item.quantityAmount, unit: item.unit, category: item.category)
    }

    /// Schreibt eine geprüfte Antwort an den Artikel. `false`, wenn nichts zu ändern war.
    @MainActor
    @discardableResult
    static func apply(_ resolution: AIPriceEstimation.Resolution, date: Date, to item: ShoppingItem) -> Bool {
        if item.priceSource == AIPriceEstimation.source, item.estimatedPrice == resolution.perUnitPrice { return false }
        item.estimatedPrice = resolution.perUnitPrice
        item.estimatedPriceIsAutoDerived = true
        item.priceSource = AIPriceEstimation.source
        item.priceSourceDate = date
        return true
    }

    /// Zwischenspeicher ohne Modell auf die Kandidaten anwenden (synchron, auch bei ausgeschalteter
    /// Stufe: ein früher angenommener Wert bleibt sichtbar, bis Daten ihn ersetzen).
    @MainActor
    static func applyCache(_ cache: AIPriceCache, to items: [ShoppingItem]) -> Int {
        var changed = 0
        for item in items where isCandidate(item) {
            let request = request(for: item)
            guard let guess = cache.entry(for: request.cacheKey)?.guess,
                  let resolution = AIPriceEstimation.validate(guess, for: request),
                  let date = cache.entry(for: request.cacheKey)?.date else { continue }
            if apply(resolution, date: date, to: item) { changed += 1 }
        }
        return changed
    }

    /// Aus `StoreDetailView.task`: erst den Zwischenspeicher anwenden, dann (nur mit Schalter und
    /// verfügbarem Modell) höchstens `maximumCallsPerFill` fehlende Artikel beim Modell erfragen.
    /// Liefert die Zahl der Modellaufrufe.
    @discardableResult
    func fill(store: Store) async -> Int {
        let pending = await MainActor.run { store.pendingItems }
        _ = await MainActor.run { Self.applyCache(cache, to: pending) }
        guard isEnabled, model.isAvailable else { return 0 }
        let candidates = await MainActor.run {
            pending.filter { Self.isCandidate($0) && $0.priceOrigin != AIPriceEstimation.source }.map { ($0, Self.request(for: $0)) }
        }
        var calls = 0
        var asked: Set<String> = []
        for (item, request) in candidates {
            guard calls < AIPriceEstimation.maximumCallsPerFill, !asked.contains(request.cacheKey) else { continue }
            if let entry = cache.entry(for: request.cacheKey), !AIPriceCache.isRetryDue(entry, now: now()) { continue }
            asked.insert(request.cacheKey)
            calls += 1
            let guess = await model.estimate(request)
            let resolution = guess.flatMap { AIPriceEstimation.validate($0, for: request) }
            cache.store(resolution?.guess, for: request.cacheKey, at: now())
            if let resolution {
                let date = now()
                _ = await MainActor.run { Self.apply(resolution, date: date, to: item) }
            } else {
                Self.logger.info("KI-Preis verworfen oder ausgeblieben für \(request.cacheKey, privacy: .private)")
            }
        }
        return calls
    }

    /// „Stimmt so“ im Bearbeiten-Sheet (Entscheidung 3): der KI-Preis wird zum eigenen Preis, ohne Netz.
    @MainActor
    static func confirm(_ item: ShoppingItem) {
        guard item.priceOrigin == AIPriceEstimation.source, item.estimatedPrice != nil else { return }
        item.estimatedPriceIsAutoDerived = false
        item.priceSource = "manual"
        item.priceSourceDate = nil
        item.lastModified = Date()
    }
}
