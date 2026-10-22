import XCTest
import SwiftData
@testable import Restock

/// Issue #164: KI-Preisschätzung als Stufe vor der Pauschale — Regeln (R1–R6), Zwischenspeicher (C1–C3),
/// Dienst mit Schein-Modell (S1–S6), Anzeige und „Stimmt so“ (D1–D3). Das echte Modell misst
/// `AIPriceEvaluationTests` (nur AI_EVAL, `scripts/run-ai-price-eval.sh`).
final class AIPriceEstimationTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var cache: AIPriceCache!
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "UT-aiprice-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        cache = AIPriceCache(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func request(_ name: String, amount: Double = 1, unit: String = "", category: String = "Lebensmittel") -> AIPriceRequest {
        AIPriceRequest(itemName: name, quantityAmount: amount, unit: unit, category: category)
    }

    private func guess(_ amount: Double, _ unit: String, _ low: Double, _ typical: Double, _ high: Double) -> AIPriceGuess {
        AIPriceGuess(packageAmount: amount, packageUnit: unit, low: low, typical: typical, high: high)
    }

    // MARK: - Regeln

    /// R1: Stückartikel, Spanne plausibel → Packungspreis als Rate je Stück.
    func testValidPieceGuessGivesPackagePrice() throws {
        let r = try XCTUnwrap(AIPriceEstimation.validate(guess(1, "stk", 1.99, 2.49, 3.49), for: request("Burrata")))
        XCTAssertEqual(r.perUnitPrice, 2.49, accuracy: 0.0001)
        XCTAssertEqual(r.guess.packageUnit, "stk")
    }

    /// R2: Gewichtsartikel mit Gewichtspackung → Rate je Gramm (Entscheidungstabelle wie Katalog).
    func testWeightGuessScalesToItemUnit() throws {
        let r = try XCTUnwrap(AIPriceEstimation.validate(guess(250, "g", 2.49, 2.99, 3.99), for: request("Mandelmus", amount: 500, unit: "g")))
        XCTAssertEqual(r.perUnitPrice, 2.99 / 250, accuracy: 0.000001)
        let kg = try XCTUnwrap(AIPriceEstimation.validate(guess(1, "kg", 4, 5, 6), for: request("Harissa", amount: 200, unit: "g")))
        XCTAssertEqual(kg.guess.packageAmount, 1000)
        XCTAssertEqual(kg.guess.packageUnit, "g")
        XCTAssertEqual(kg.perUnitPrice, 5.0 / 1000, accuracy: 0.000001)
    }

    /// R3: Spanne oben/unten über Faktor 3 → verworfen (Entscheidung 2).
    func testRangeWiderThanFactorThreeIsRejected() {
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "stk", 1.00, 2.00, 3.01), for: request("Trüffelöl")))
        XCTAssertNotNil(AIPriceEstimation.validate(guess(1, "stk", 1.00, 2.00, 3.00), for: request("Trüffelöl")))
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "stk", 0, 2, 3), for: request("x")), "low 0")
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "stk", 2, 1, 3), for: request("x")), "nicht aufsteigend")
    }

    /// R4: Gewichtsartikel mit Stückpackung → verworfen (sonst Rate je kg als Stückpreis).
    func testPieceGuessForWeightItemIsRejected() {
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "stk", 1, 2, 3), for: request("Mandelmus", amount: 500, unit: "g")))
        XCTAssertNotNil(AIPriceEstimation.validate(guess(250, "g", 1, 2, 3), for: request("Mandelmus", amount: 1, unit: "")))
    }

    /// R5: Gesamtpreis der Zeile über `maxPlausibleLineTotal` → verworfen; unbekannte Einheit → verworfen.
    func testCapAndUnknownUnit() {
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "stk", 20, 25, 30), for: request("Wein", amount: 2, unit: "")))
        XCTAssertNotNil(AIPriceEstimation.validate(guess(1, "stk", 20, 25, 30), for: request("Wein", amount: 1, unit: "")))
        XCTAssertNil(AIPriceEstimation.validate(guess(1, "dutzend", 1, 2, 3), for: request("Eier")))
        XCTAssertNil(AIPriceEstimation.validate(guess(0, "g", 1, 2, 3), for: request("x")))
    }

    /// R6: Einheiten des Modells werden normalisiert.
    func testUnitNormalization() {
        XCTAssertEqual(AIPriceEstimation.normalizedPackageUnit(" Gramm "), "g")
        XCTAssertEqual(AIPriceEstimation.normalizedPackageUnit("Stück"), "stk")
        XCTAssertEqual(AIPriceEstimation.normalizedPackageUnit("ML"), "ml")
        XCTAssertEqual(AIPriceEstimation.normalizedPackageUnit("Liter"), "l")
        XCTAssertNil(AIPriceEstimation.normalizedPackageUnit("Karton"))
    }

    // MARK: - Zwischenspeicher

    /// C1: Schlüssel trennt Bezugsgrößen; C2: Treffer und Fehlversuch werden gespeichert; C3: Sperre läuft ab.
    func testCacheKeyStoreAndRetry() {
        XCTAssertEqual(request("Mehl").cacheKey, "mehl|stk")
        XCTAssertEqual(request("Mehl ", amount: 500, unit: "g").cacheKey, "mehl|g")
        cache.store(guess(1, "stk", 1, 2, 3), for: "a|stk", at: fixedNow)
        cache.store(nil, for: "b|stk", at: fixedNow)
        XCTAssertEqual(cache.entry(for: "a|stk")?.guess?.typical, 2)
        XCTAssertNil(cache.entry(for: "b|stk")?.guess)
        XCTAssertFalse(AIPriceCache.isRetryDue(cache.entry(for: "b|stk")!, now: fixedNow.addingTimeInterval(29 * 86_400)))
        XCTAssertTrue(AIPriceCache.isRetryDue(cache.entry(for: "b|stk")!, now: fixedNow.addingTimeInterval(31 * 86_400)))
        XCTAssertFalse(AIPriceCache.isRetryDue(cache.entry(for: "a|stk")!, now: fixedNow.addingTimeInterval(400 * 86_400)), "Treffer werden nicht erneut erfragt")
        cache.remove("a|stk")
        XCTAssertNil(cache.entry(for: "a|stk"))
    }

    // MARK: - Dienst

    private func makeStore() throws -> (ModelContainer, Store) {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let store = Store(name: "Rewe City", emoji: "🛒", colorHex: "#123456")
        container.mainContext.insert(store)
        return (container, store)
    }

    /// Legt einen Artikel im Laden an und sichert, damit `store.pendingItems` ihn über die Beziehung sieht.
    @MainActor
    @discardableResult
    private func addItem(_ name: String, to store: Store, in container: ModelContainer) throws -> ShoppingItem {
        let item = ShoppingItem(name: name, store: store)
        container.mainContext.insert(item)
        try container.mainContext.save()
        return item
    }

    private func service(_ fake: FakePriceLanguageModel, enabled: Bool) -> AIPriceEstimationService {
        defaults.set(enabled, forKey: AIPriceEstimation.isEnabledKey)
        return AIPriceEstimationService(model: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
    }

    /// S1: Standard aus — ohne Schlüssel kein Modellaufruf, Pauschale bleibt.
    @MainActor
    func testDisabledByDefaultMakesNoModelCall() async throws {
        let (container, store) = try makeStore()
        let item = try addItem("Burrata", to: store, in: container)
        XCTAssertEqual(item.priceOrigin, "category", "Burrata hat keinen Katalogeintrag — Voraussetzung des Tests")
        XCTAssertEqual(store.pendingItems.count, 1, "Beziehung sichtbar — Voraussetzung des Tests")
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1.99, 2.49, 3.49))
        XCTAssertFalse(AIPriceEstimation.isEnabled(in: defaults))
        let svc = AIPriceEstimationService(model: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
        let calls = await svc.fill(store: store)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(fake.requests.count, 0)
        XCTAssertEqual(item.priceOrigin, "category")
    }

    /// S2: Eingeschaltet — Pauschal-Artikel bekommt den geprüften KI-Preis, Katalog-/eigene Artikel nicht.
    @MainActor
    func testEnabledFillsOnlyCategoryItems() async throws {
        let (container, store) = try makeStore()
        let burrata = try addItem("Burrata", to: store, in: container)
        let mozzarella = try addItem("Mozzarella", to: store, in: container)
        let manual = try addItem("Harissa", to: store, in: container)
        manual.estimatedPrice = 3.0; manual.estimatedPriceIsAutoDerived = false; manual.priceSource = "manual"
        try container.mainContext.save()
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1.99, 2.49, 3.49))
        let svc = service(fake, enabled: true)
        let calls = await svc.fill(store: store)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(fake.requests.map(\.itemName), ["Burrata"])
        XCTAssertEqual(burrata.priceSource, "ai")
        XCTAssertEqual(burrata.priceOrigin, "ai")
        XCTAssertEqual(burrata.estimatedPrice, 2.49)
        XCTAssertTrue(burrata.estimatedPriceIsAutoDerived)
        XCTAssertEqual(burrata.priceSourceDate, fixedNow)
        XCTAssertEqual(mozzarella.priceOrigin, "estimate")
        XCTAssertEqual(manual.priceSource, "manual")
        XCTAssertEqual(cache.entry(for: "burrata|stk")?.guess?.typical, 2.49)
    }

    /// S3: Zweite Liste mit demselben Namen — Zwischenspeicher, kein zweiter Modellaufruf.
    @MainActor
    func testCacheAvoidsSecondModelCall() async throws {
        let (container, store) = try makeStore()
        try addItem("Burrata", to: store, in: container)
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1.99, 2.49, 3.49))
        let svc = service(fake, enabled: true)
        _ = await svc.fill(store: store)
        let second = try addItem("burrata", to: store, in: container)
        let calls = await svc.fill(store: store)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(fake.requests.count, 1)
        XCTAssertEqual(second.priceSource, "ai")
        XCTAssertEqual(second.estimatedPrice, 2.49)
    }

    /// S4: Verworfene Antwort → Pauschale bleibt, Fehlversuch gesperrt, kein erneuter Aufruf innerhalb 30 Tagen.
    @MainActor
    func testRejectedAnswerKeepsCategoryAndBlocksRetry() async throws {
        let (container, store) = try makeStore()
        let item = try addItem("Burrata", to: store, in: container)
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1.00, 5.00, 9.00))
        let svc = service(fake, enabled: true)
        _ = await svc.fill(store: store)
        XCTAssertEqual(item.priceOrigin, "category")
        XCTAssertNotNil(cache.entry(for: "burrata|stk"))
        XCTAssertNil(cache.entry(for: "burrata|stk")?.guess)
        let calls = await svc.fill(store: store)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(fake.requests.count, 1)
    }

    /// S5: Modell nicht verfügbar (iOS < 26 oder Apple Intelligence aus) → kein Aufruf, auch mit Schalter.
    @MainActor
    func testUnavailableModelIsNeverAsked() async throws {
        let (container, store) = try makeStore()
        try addItem("Burrata", to: store, in: container)
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1, 2, 3), available: false)
        let calls = await service(fake, enabled: true).fill(store: store)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(fake.requests.count, 0)
    }

    /// S6: Höchstens `maximumCallsPerFill` Aufrufe je Öffnung; gleiche Namen nur einmal.
    @MainActor
    func testCallsPerFillAreBounded() async throws {
        let (container, store) = try makeStore()
        for i in 0..<(AIPriceEstimation.maximumCallsPerFill + 3) { try addItem("Spezialartikel \(i)", to: store, in: container) }
        try addItem("Spezialartikel 0", to: store, in: container)
        let fake = FakePriceLanguageModel(answer: nil)
        let calls = await service(fake, enabled: true).fill(store: store)
        XCTAssertEqual(calls, AIPriceEstimation.maximumCallsPerFill)
        XCTAssertEqual(Set(fake.requests.map(\.cacheKey)).count, fake.requests.count, "kein Name doppelt")
    }

    /// Community vor KI: ein Artikel mit Community-Preis ist kein Kandidat.
    @MainActor
    func testCommunityPriceIsNotOverridden() async throws {
        let (container, store) = try makeStore()
        let item = try addItem("Burrata", to: store, in: container)
        item.estimatedPrice = 2.0; item.priceSource = "community:Rewe"; item.estimatedPriceIsAutoDerived = true
        try container.mainContext.save()
        XCTAssertFalse(AIPriceEstimationService.isCandidate(item))
        let fake = FakePriceLanguageModel(answer: guess(1, "stk", 1, 2, 3))
        _ = await service(fake, enabled: true).fill(store: store)
        XCTAssertEqual(item.priceSource, "community:Rewe")
        XCTAssertEqual(fake.requests.count, 0)
    }

    // MARK: - Anzeige und Bestätigung

    /// D1: Zeile zeigt „ca. … · KI-Schätzung“ in der Warnfarbe-Logik (Präfix) und ohne „Preis?“.
    func testDisplayForAISource() {
        XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: "ai"), "ca. ")
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: "ai", hasPrice: true, isAutoDerived: true))
        let text = PriceSourceDisplay.text(origin: "ai", date: nil, locale: Locale(identifier: "de_DE"))
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "price.source.ai")
        XCTAssertTrue(ShoppingItem.knownPriceSources.contains("ai"))
        let keys = Set(PriceSourceDisplay.allLocalizationKeys)
        for key in ["price.source.ai", "item.price.ai.section", "item.price.ai.range", "item.price.ai.confirm",
                    "settings.dev.aiPrice", "settings.dev.aiPrice.footer"] {
            XCTAssertTrue(keys.contains(key), key)
        }
    }

    /// D2: „Stimmt so“ macht den KI-Preis zum eigenen Preis; auf andere Quellen ohne Wirkung.
    @MainActor
    func testConfirmTurnsAIPriceIntoManual() throws {
        let (container, store) = try makeStore()
        _ = container
        let item = ShoppingItem(name: "Burrata", store: store)
        item.estimatedPrice = 2.49; item.priceSource = "ai"; item.estimatedPriceIsAutoDerived = true; item.priceSourceDate = fixedNow
        AIPriceEstimationService.confirm(item)
        XCTAssertEqual(item.priceSource, "manual")
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
        XCTAssertEqual(item.estimatedPrice, 2.49)
        XCTAssertNil(item.priceSourceDate)
        XCTAssertFalse(AIPriceEstimationService.isCandidate(item))

        let other = ShoppingItem(name: "Mozzarella", store: store)
        let before = other.priceSource
        AIPriceEstimationService.confirm(other)
        XCTAssertEqual(other.priceSource, before)
    }

    /// D3: Spanne und Packung im Bearbeiten-Sheet aus dem Zwischenspeicher.
    @MainActor
    func testEditSheetRangeTextComesFromCache() throws {
        let (container, store) = try makeStore()
        _ = container
        let item = ShoppingItem(name: "Burrata", store: store)
        XCTAssertNil(EditItemView.aiRangeText(for: item, cache: cache, locale: Locale(identifier: "de_DE")))
        cache.store(guess(150, "g", 1.99, 2.49, 3.49), for: "burrata|stk", at: fixedNow)
        let text = try XCTUnwrap(EditItemView.aiRangeText(for: item, cache: cache, locale: Locale(identifier: "de_DE")))
        XCTAssertTrue(text.contains("150 g"), text)
        XCTAssertTrue(text.contains("1,99"), text)
        XCTAssertTrue(text.contains("3,49"), text)
        XCTAssertFalse(text.contains("item.price.ai"), text)
    }

    func testPromptCarriesOnlyHarmlessFields() {
        let prompt = SystemPriceLanguageModel.prompt(for: request("Burrata", amount: 2, unit: "stk", category: "Milchprodukte"))
        XCTAssertTrue(prompt.contains("Burrata"))
        XCTAssertTrue(prompt.contains("Milchprodukte"))
        XCTAssertTrue(prompt.contains("Deutschland"))
        XCTAssertFalse(prompt.lowercased().contains("rewe"))
    }
}

// MARK: - Schein-Modell

final class FakePriceLanguageModel: PriceLanguageModel, @unchecked Sendable {
    private let lock = NSLock()
    let answer: AIPriceGuess?
    let available: Bool
    private(set) var requests: [AIPriceRequest] = []

    init(answer: AIPriceGuess?, available: Bool = true) {
        self.answer = answer
        self.available = available
    }

    var isAvailable: Bool { available }

    func estimate(_ request: AIPriceRequest) async -> AIPriceGuess? {
        lock.lock(); defer { lock.unlock() }
        requests.append(request)
        return answer
    }
}
