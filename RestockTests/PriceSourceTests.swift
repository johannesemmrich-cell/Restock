import XCTest
import SwiftData
@testable import Restock

/// TDD RED (Issue #151, `docs/specs/models/price-source-display.md`) — AC-1 bis AC-16.
/// Vor der Umsetzung kompiliert diese Datei erwartungsgemäß nicht (fehlende Symbole).
///
/// ## Vom Test festgelegte Nähte (genau so bauen)
///
/// Aus der Spec übernommen (dort benannt):
/// ```swift
/// // ShoppingItem.swift (neue Typen in dieser Datei, drei Ziele)
/// struct LearnedPriceResolution: Equatable {
///     enum Reason: Equatable, CaseIterable {
///         case noStore, noEntry, exceedsCap, legacyNoUnit, unitMismatch, applied, appliedRateOnly
///     }
///     let matchedKey: String?          // Ergebnis von matchingLearnedPriceKey, sonst nil
///     let entryPrice: Double?          // store.learnedPrices[matchedKey]
///     let entryUnit: String?           // store.learnedPriceUnits[matchedKey], roh (nil oder "" möglich)
///     let exceedsCap: Bool             // entryPrice × (quantityAmount > 0 ? quantityAmount : 1) > 200
///     let usage: ShoppingItem.LearnedRateUsage  // wie in init: bei noStore/noEntry/exceedsCap .reject
///     let price: Double?               // angewendeter Preis oder nil
///     let unitOverride: String?        // "g" nur bei .rateOnly
///     let reason: Reason
/// }
/// extension ShoppingItem {
///     static func resolveLearnedPrice(forLowercasedName: String, itemUnit: String, quantityAmount: Double,
///                                     quantitySource: String, in store: Store?) -> LearnedPriceResolution
///     var priceSource: String            // gespeichert, Standard ""
///     var priceSourceDate: Date?         // gespeichert, nur bei "receipt"
///     var priceOrigin: String { get }    // berechnet
/// }
/// // Store.swift
/// var learnedPriceOrigins: [String: String] = [:]
/// ```
///
/// Für die Testbarkeit hier festgelegt (Spec nennt keine exakte Signatur):
/// ```swift
/// enum PriceSourceDisplay {
///     /// „Bon · 12.10.“ / „Bon“ / „bezahlt“ / „gelernt“ / „eigener Preis“ / „Schätzung“.
///     /// Datum über DateFormatter.dateFormat(fromTemplate: "dM", …, locale: locale), Zeitzone .current.
///     static func text(origin: String, date: Date?, locale: Locale = .current) -> String
///     /// "ca. " nur bei "estimate", sonst "".
///     static func amountPrefix(origin: String) -> String
///     /// "<amountPrefix><amount>, <text>", z. B. "ca. 2,90 €, Schätzung" / "2,50 €, eigener Preis".
///     static func accessibilityLabel(amount: String, origin: String, date: Date?, locale: Locale = .current) -> String
///     /// Alle mit #151 neu eingeführten Localizable.strings-Schlüssel (Quelltexte UND Diagnosetexte,
///     /// inkl. Abschnittstitel „Preisdiagnose“).
///     static var allLocalizationKeys: [String] { get }
/// }
/// enum PriceDiagnosis {
///     /// Ruft resolveLearnedPrice mit item.name.lowercased(), item.unit, item.quantityAmount,
///     /// item.quantitySource und `store` (im Dialog: der gewählte Laden) — keine zweite Logik.
///     static func resolution(for item: ShoppingItem, in store: Store?) -> LearnedPriceResolution
///     /// Zeilen des Abschnitts „Preisdiagnose“: gefundener Eintrag (Schlüssel wörtlich, Preis,
///     /// Bezugsgröße, Datum, Herkunft), Bezugsgröße des Artikels (unitBucket(item.unit) wörtlich,
///     /// quantitySource), Obergrenze (Preis × Menge gegen „200“), Ergebnis = reasonText(reason).
///     static func lines(for item: ShoppingItem, in store: Store?) -> [String]
///     /// Lokalisierter, für jeden Grund verschiedener Text (keiner Teilstring eines anderen).
///     static func reasonText(_ reason: LearnedPriceResolution.Reason) -> String
/// }
/// extension ItemRow {
///     /// Unveränderte Regel: !isCompleted || !estimatedPriceIsAutoDerived. Gilt für Betrag UND Quelle.
///     static func showsPrice(isCompleted: Bool, estimatedPriceIsAutoDerived: Bool) -> Bool
/// }
/// extension EditItemView {
///     /// Der komplette Preisblock aus save() (Zeilen 404–419), save() ruft nur noch diese Funktion.
///     /// Feld geändert + Zahl > 0 → Preis/Menge, Bool false, priceSource "manual", Datum nil.
///     /// Feld geändert + leer → PriceEstimator.estimate(…priceCategory…), Bool true, "estimate", Datum nil.
///     /// Feld unverändert + Einheit geändert + Bool true → Schätzung neu, "estimate", Datum nil.
///     static func applyPriceEdit(priceText: String, initialPriceText: String, oldUnit: String,
///                                priceCategory: String, to item: ShoppingItem)
/// }
/// extension ActualPriceEntryView {
///     /// Bisheriges private apply(itemActualTotal:to:) als statische Funktion mit dem Laden als
///     /// Parameter; zusätzlich priceSource "paid", priceSourceDate nil, learnedPriceOrigins[key] = "paid".
///     static func apply(itemActualTotal: Double, to item: ShoppingItem, in store: Store)
/// }
/// extension ReceiptLearning {
///     /// Die Schreibzeilen aus ReceiptScannerView.save() (learnedPrices/Units/Dates) plus
///     /// learnedPriceOrigins[plan.key] = "receipt", alle mit `date`; save() ruft sie mit Date().
///     static func learn(_ plan: Plan, into store: Store, at date: Date)
/// }
/// ```
/// Annahme: Unit-Tests laufen in der Scheme-Sprache de (Test Action pinnt language="de"),
/// deshalb erwarten die Anzeigetexte Deutsch; AC-16 liest de/en direkt aus den .lproj-Bündeln.
@MainActor
final class PriceSourceTests: XCTestCase {

    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later = Date(timeIntervalSince1970: 2_000_000)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: LegacyLearnedPriceReset.flagKey)
        super.tearDown()
    }

    // MARK: - Hilfen

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeStore(_ name: String = "Lidl") -> Store {
        Store(name: name, emoji: "🛒", colorHex: "#123456")
    }

    private func makeStore(key: String, price: Double, unit: String?, date: Date? = nil, origin: String? = nil) -> Store {
        let store = makeStore()
        store.learnedPrices[key] = price
        if let unit { store.learnedPriceUnits[key] = unit }
        if let date { store.learnedPriceDates[key] = date }
        if let origin { store.learnedPriceOrigins[key] = origin }
        return store
    }

    /// Resolver mit dem aktuellen Zustand des Artikels (nur für Einträge ohne .rateOnly benutzt,
    /// weil init dort die Einheit umstellt).
    private func resolve(_ item: ShoppingItem, in store: Store?) -> LearnedPriceResolution {
        ShoppingItem.resolveLearnedPrice(
            forLowercasedName: item.name.lowercased(),
            itemUnit: item.unit,
            quantityAmount: item.quantityAmount,
            quantitySource: item.quantitySource,
            in: store)
    }

    /// 12.10.2026, 12:00 Ortszeit — mittags, damit keine Zeitzone das Datum verschiebt.
    private var october12: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 12; components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private let german = Locale(identifier: "de_DE")

    /// Parität: was `init` aus einem Resolver-Ergebnis machen muss (bitgleich zum bisherigen Verhalten).
    private func assertInitMatchesResolver(
        _ item: ShoppingItem, _ resolution: LearnedPriceResolution, itemUnit: String,
        category: String = "", _ context: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectedUnit = resolution.unitOverride ?? itemUnit
        let expectedPrice = resolution.price ?? PriceEstimator.estimate(
            for: item.name, category: category, unit: expectedUnit, quantityAmount: item.quantityAmount)
        XCTAssertEqual(item.unit, expectedUnit, "unit, \(context)", file: file, line: line)
        XCTAssertEqual(item.estimatedPrice, expectedPrice, "estimatedPrice, \(context)", file: file, line: line)
        XCTAssertEqual(item.estimatedPriceIsAutoDerived, resolution.price == nil,
                       "estimatedPriceIsAutoDerived, \(context)", file: file, line: line)
    }

    // MARK: - AC-1

    func testResolverMatchesInitForAllUsageRows() {
        let learnedUnits: [String?] = [nil, "", "stk", "g", "kg", "l"]
        let itemUnits = ["", "stk", "g", "kg", "l"]
        let sources = ["none", "user"]
        var rowsSeen = 0
        for learnedUnit in learnedUnits {
            for itemUnit in itemUnits {
                for source in sources {
                    let store = makeStore(key: "milch", price: 0.99, unit: learnedUnit)
                    let item = ShoppingItem(name: "Milch", quantityAmount: 2, unit: itemUnit,
                                            store: store, quantitySource: source)
                    let resolution = ShoppingItem.resolveLearnedPrice(
                        forLowercasedName: "milch", itemUnit: itemUnit, quantityAmount: 2,
                        quantitySource: source, in: store)
                    let context = "learnedUnit=\(learnedUnit ?? "nil") itemUnit=\(itemUnit) source=\(source)"

                    assertInitMatchesResolver(item, resolution, itemUnit: itemUnit, context)
                    XCTAssertEqual(resolution.usage,
                                   ShoppingItem.learnedRateUsage(learnedUnit: learnedUnit, itemUnit: itemUnit,
                                                                 quantitySource: source),
                                   "usage folgt der unveränderten Entscheidungstabelle, \(context)")
                    XCTAssertEqual(resolution.matchedKey, "milch", context)
                    XCTAssertEqual(item.priceSource, resolution.price == nil ? "estimate" : "learned",
                                   "ohne Origin-Eintrag: gelernt oder Schätzung, \(context)")
                    rowsSeen += 1
                }
            }
        }
        XCTAssertEqual(rowsSeen, 60)

        // Stichproben gegen die Entscheidungstabelle (nicht nur gegen sich selbst).
        let rateOnly = ShoppingItem.resolveLearnedPrice(
            forLowercasedName: "milch", itemUnit: "", quantityAmount: 1, quantitySource: "none",
            in: makeStore(key: "milch", price: 0.0125, unit: "g"))
        XCTAssertEqual(rateOnly.usage, .rateOnly)
        XCTAssertEqual(rateOnly.price, 0.0125)
        XCTAssertEqual(rateOnly.unitOverride, "g")

        let gramAsPiece = ShoppingItem.resolveLearnedPrice(
            forLowercasedName: "milch", itemUnit: "", quantityAmount: 1, quantitySource: "user",
            in: makeStore(key: "milch", price: 0.0125, unit: "g"))
        XCTAssertNil(gramAsPiece.price, "Gramm-Rate wird nie Stückpreis (#10)")
        XCTAssertNil(gramAsPiece.unitOverride)
    }

    // MARK: - AC-2

    func testResolverMatchesInitForSubstringFuzzyAndTieBreak() {
        // Teilstring
        let substringStore = makeStore(key: "hackfleisch gemischt 500g", price: 3.49, unit: "stk")
        let substringItem = ShoppingItem(name: "Hackfleisch", store: substringStore)
        let substring = resolve(substringItem, in: substringStore)
        XCTAssertEqual(substring.matchedKey, "hackfleisch gemischt 500g")
        XCTAssertEqual(substring.matchedKey,
                       ShoppingItem.matchingLearnedPriceKey(forLowercasedName: "hackfleisch", in: substringStore))
        XCTAssertEqual(substring.price, 3.49)
        assertInitMatchesResolver(substringItem, substring, itemUnit: "", "Teilstring")

        // Fuzzy (#52, Schlüssel ≥ 5 Zeichen)
        let fuzzyStore = makeStore(key: "seitan", price: 2.99, unit: "stk")
        let fuzzyItem = ShoppingItem(name: "Saitan", store: fuzzyStore)
        let fuzzy = resolve(fuzzyItem, in: fuzzyStore)
        XCTAssertEqual(fuzzy.matchedKey, "seitan")
        XCTAssertEqual(fuzzy.price, 2.99)
        assertInitMatchesResolver(fuzzyItem, fuzzy, itemUnit: "", "Fuzzy")

        // Tie-Breaker: gleiches Datum → alphabetisch kleinster Schlüssel
        let tieStore = makeStore()
        tieStore.learnedPrices["rinderhackfleisch"] = 5.99
        tieStore.learnedPrices["hackfleisch bio"] = 4.49
        tieStore.learnedPriceUnits["rinderhackfleisch"] = "stk"
        tieStore.learnedPriceUnits["hackfleisch bio"] = "stk"
        tieStore.learnedPriceDates["rinderhackfleisch"] = later
        tieStore.learnedPriceDates["hackfleisch bio"] = later
        let tieItem = ShoppingItem(name: "Hackfleisch", store: tieStore)
        let tie = resolve(tieItem, in: tieStore)
        XCTAssertEqual(tie.matchedKey, "hackfleisch bio")
        XCTAssertEqual(tie.matchedKey,
                       ShoppingItem.matchingLearnedPriceKey(forLowercasedName: "hackfleisch", in: tieStore))
        XCTAssertEqual(tie.price, 4.49)
        assertInitMatchesResolver(tieItem, tie, itemUnit: "", "Tie-Breaker")

        // Jüngeres Datum gewinnt vor dem Alphabet
        tieStore.learnedPriceDates["rinderhackfleisch"] = later.addingTimeInterval(60)
        let newerItem = ShoppingItem(name: "Hackfleisch", store: tieStore)
        let newer = resolve(newerItem, in: tieStore)
        XCTAssertEqual(newer.matchedKey, "rinderhackfleisch")
        assertInitMatchesResolver(newerItem, newer, itemUnit: "", "Datum")

        // Kein Treffer
        let noMatchItem = ShoppingItem(name: "Käse", store: substringStore)
        let noMatch = resolve(noMatchItem, in: substringStore)
        XCTAssertNil(noMatch.matchedKey)
        XCTAssertNil(noMatch.price)
        assertInitMatchesResolver(noMatchItem, noMatch, itemUnit: "", "kein Treffer")
    }

    // MARK: - AC-3

    func testResolverCapBoundaryMatchesInit() {
        let cases: [(price: Double, quantity: Double, applied: Bool, label: String)] = [
            (100.0, 2, true, "200,00 € greift"),
            (100.005, 2, false, "200,01 € wird verworfen"),
            (200.0, 0, true, "Menge 0 zählt als 1: 200,00 €"),
            (200.01, 0, false, "Menge 0 zählt als 1: 200,01 €")
        ]
        for c in cases {
            let store = makeStore(key: "steak", price: c.price, unit: "stk")
            let item = ShoppingItem(name: "Steak", quantityAmount: c.quantity, store: store)
            let resolution = resolve(item, in: store)
            assertInitMatchesResolver(item, resolution, itemUnit: "", c.label)
            if c.applied {
                XCTAssertEqual(resolution.reason, .applied, c.label)
                XCTAssertFalse(resolution.exceedsCap, c.label)
                XCTAssertEqual(item.estimatedPrice, c.price, c.label)
            } else {
                XCTAssertEqual(resolution.reason, .exceedsCap, c.label)
                XCTAssertTrue(resolution.exceedsCap, c.label)
                XCTAssertNil(resolution.price, c.label)
                XCTAssertEqual(resolution.entryPrice, c.price, "Eintrag bleibt für die Diagnose sichtbar, \(c.label)")
                XCTAssertTrue(item.estimatedPriceIsAutoDerived, "Schätzung statt Altwert, \(c.label)")
                XCTAssertEqual(item.priceSource, "estimate", c.label)
            }
        }
    }

    // MARK: - AC-4

    func testResolverReasons() {
        func reason(_ store: Store?, unit: String = "", quantity: Double = 1, source: String = "user",
                    name: String = "butter") -> LearnedPriceResolution {
            ShoppingItem.resolveLearnedPrice(forLowercasedName: name, itemUnit: unit, quantityAmount: quantity,
                                             quantitySource: source, in: store)
        }

        XCTAssertEqual(reason(nil).reason, .noStore)
        XCTAssertEqual(reason(makeStore()).reason, .noEntry)
        XCTAssertEqual(reason(makeStore(key: "butter", price: 1.99, unit: "stk"), name: "käse").reason, .noEntry)

        let capped = reason(makeStore(key: "butter", price: 150, unit: "stk"), quantity: 2)
        XCTAssertEqual(capped.reason, .exceedsCap)
        XCTAssertEqual(capped.usage, .reject, "bitgleich zu init: verworfener Eintrag ergibt .reject")

        let missingUnit = reason(makeStore(key: "butter", price: 1.99, unit: nil))
        XCTAssertEqual(missingUnit.reason, .legacyNoUnit, "Bezugsgröße fehlt")
        XCTAssertEqual(missingUnit.matchedKey, "butter")
        XCTAssertEqual(reason(makeStore(key: "butter", price: 1.99, unit: "")).reason, .legacyNoUnit, "Bezugsgröße leer")

        let mismatch = reason(makeStore(key: "butter", price: 1.99, unit: "stk"), unit: "kg")
        XCTAssertEqual(mismatch.reason, .unitMismatch)
        XCTAssertEqual(mismatch.usage, .reject)
        XCTAssertEqual(reason(makeStore(key: "butter", price: 0.01, unit: "g"), source: "user").reason, .unitMismatch,
                       "Gramm-Rate an Stückartikel mit eingetippter Menge")

        let applied = reason(makeStore(key: "butter", price: 1.99, unit: "stk"))
        XCTAssertEqual(applied.reason, .applied)
        XCTAssertEqual(applied.usage, .apply)
        XCTAssertEqual(applied.price, 1.99)
        XCTAssertNil(applied.unitOverride)

        let rateOnly = reason(makeStore(key: "butter", price: 0.01, unit: "g"), source: "none")
        XCTAssertEqual(rateOnly.reason, .appliedRateOnly)
        XCTAssertEqual(rateOnly.usage, .rateOnly)
        XCTAssertEqual(rateOnly.unitOverride, "g")

        // Vorrang: Obergrenze vor fehlender Bezugsgröße
        XCTAssertEqual(reason(makeStore(key: "butter", price: 300, unit: nil)).reason, .exceedsCap)
    }

    // MARK: - AC-5

    func testPriceOriginDerivationFromLegacyBool() {
        let item = ShoppingItem(name: "Kontrollbrot")
        let forbidden: Set<String> = ["receipt", "paid", "manual"]

        item.priceSource = ""
        item.estimatedPriceIsAutoDerived = true
        XCTAssertEqual(item.priceOrigin, "estimate")

        item.estimatedPriceIsAutoDerived = false
        XCTAssertEqual(item.priceOrigin, "learned", "Bool false kann Bon, bezahlt, manuell oder gelernt sein → neutral")
        XCTAssertFalse(forbidden.contains(item.priceOrigin))

        item.priceSource = "xyz"
        XCTAssertEqual(item.priceOrigin, "learned", "unbekannte Kennung wie Altdaten")
        item.estimatedPriceIsAutoDerived = true
        XCTAssertEqual(item.priceOrigin, "estimate")

        // Bekannte Kennungen gelten unabhängig vom Bool.
        for known in ["receipt", "paid", "learned", "manual", "estimate"] {
            item.priceSource = known
            item.estimatedPriceIsAutoDerived = true
            XCTAssertEqual(item.priceOrigin, known)
        }
    }

    // MARK: - AC-6

    func testInitSetsPriceSource() {
        let receiptDate = later
        let receiptStore = makeStore(key: "butter", price: 1.99, unit: "stk", date: receiptDate, origin: "receipt")
        let receipt = ShoppingItem(name: "Butter", store: receiptStore)
        XCTAssertEqual(receipt.priceSource, "receipt")
        XCTAssertEqual(receipt.priceSourceDate, receiptDate)
        XCTAssertEqual(receipt.priceOrigin, "receipt")

        let paid = ShoppingItem(name: "Butter", store: makeStore(key: "butter", price: 1.99, unit: "stk",
                                                             date: receiptDate, origin: "paid"))
        XCTAssertEqual(paid.priceSource, "paid")
        XCTAssertNil(paid.priceSourceDate)

        let learned = ShoppingItem(name: "Butter", store: makeStore(key: "butter", price: 1.99, unit: "stk"))
        XCTAssertEqual(learned.priceSource, "learned")
        XCTAssertNil(learned.priceSourceDate)

        // Fuzzy-Treffer: Quelle des gefundenen Eintrags
        let fuzzy = ShoppingItem(name: "Saitan", store: makeStore(key: "seitan", price: 2.99, unit: "stk",
                                                              date: receiptDate, origin: "receipt"))
        XCTAssertEqual(fuzzy.priceSource, "receipt")

        let rejected = ShoppingItem(name: "Butter", store: makeStore(key: "butter", price: 0.01, unit: "g",
                                                                 date: receiptDate, origin: "receipt"))
        XCTAssertEqual(rejected.priceSource, "estimate", "verworfener Eintrag zeigt nie „Bon“")
        XCTAssertNil(rejected.priceSourceDate)

        let none = ShoppingItem(name: "Butter", store: makeStore())
        XCTAssertEqual(none.priceSource, "estimate")
        XCTAssertNil(none.priceSourceDate)
    }

    // MARK: - AC-7

    func testReceiptLearningWritesReceiptSource() throws {
        // .apply
        let applyItem = ShoppingItem(name: "Butter")
        XCTAssertEqual(applyItem.priceSource, "estimate")
        let before = Date()
        ReceiptLearning.apply(ReceiptLearning.Plan(key: "butter", perUnitPrice: 1.99, unit: "stk"), to: applyItem)
        let after = Date()
        XCTAssertEqual(try XCTUnwrap(applyItem.estimatedPrice), 1.99, accuracy: 0.000001)
        XCTAssertEqual(applyItem.priceSource, "receipt")
        let applyDate = try XCTUnwrap(applyItem.priceSourceDate)
        XCTAssertTrue(applyDate >= before && applyDate <= after, "Datum im selben Zug wie der Preis")

        // .rateOnly
        let rateItem = ShoppingItem(name: "Hackfleisch", quantitySource: "none")
        ReceiptLearning.apply(ReceiptLearning.Plan(key: "hackfleisch", perUnitPrice: 0.0125, unit: "g"), to: rateItem)
        XCTAssertEqual(rateItem.estimatedPrice, 0.0125)
        XCTAssertEqual(rateItem.unit, "g")
        XCTAssertEqual(rateItem.priceSource, "receipt")
        XCTAssertNotNil(rateItem.priceSourceDate)

        // .reject — Preis und Quelle unverändert
        let rejectItem = ShoppingItem(name: "Hackfleisch")
        let priceBefore = rejectItem.estimatedPrice
        let sourceBefore = rejectItem.priceSource
        ReceiptLearning.apply(ReceiptLearning.Plan(key: "hackfleisch", perUnitPrice: 0.0125, unit: "g"), to: rejectItem)
        XCTAssertEqual(rejectItem.estimatedPrice, priceBefore)
        XCTAssertEqual(rejectItem.priceSource, sourceBefore)
        XCTAssertNil(rejectItem.priceSourceDate)

        // save(): Preis, Bezugsgröße, Datum und Herkunft in einem Zug
        let store = makeStore()
        let learnedAt = later
        ReceiptLearning.learn(ReceiptLearning.Plan(key: "butter", perUnitPrice: 1.89, unit: "stk"),
                              into: store, at: learnedAt)
        XCTAssertEqual(store.learnedPrices["butter"], 1.89)
        XCTAssertEqual(store.learnedPriceUnits["butter"], "stk")
        XCTAssertEqual(store.learnedPriceDates["butter"], learnedAt)
        XCTAssertEqual(store.learnedPriceOrigins["butter"], "receipt")

        // Folgewirkung: ein neuer Artikel zeigt „Bon“ mit diesem Datum.
        let next = ShoppingItem(name: "Butter", store: store)
        XCTAssertEqual(next.priceSource, "receipt")
        XCTAssertEqual(next.priceSourceDate, learnedAt)
    }

    // MARK: - AC-8

    func testActualPriceEntryWritesPaidSource() throws {
        let store = makeStore()
        store.learnedPriceOrigins["butter"] = "receipt"
        let item = ShoppingItem(name: "Butter", quantityAmount: 2, store: store)
        item.priceSourceDate = earlier

        ActualPriceEntryView.apply(itemActualTotal: 4.0, to: item, in: store)

        XCTAssertEqual(try XCTUnwrap(item.estimatedPrice), 2.0, accuracy: 0.000001)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
        XCTAssertEqual(item.priceSource, "paid")
        XCTAssertNil(item.priceSourceDate)
        XCTAssertEqual(store.learnedPrices["butter"], 2.0)
        XCTAssertEqual(store.learnedPriceUnits["butter"], "stk")
        XCTAssertEqual(store.learnedPriceOrigins["butter"], "paid", "ein bezahlter Betrag ersetzt die Bon-Herkunft")

        XCTAssertEqual(ShoppingItem(name: "Butter", store: store).priceSource, "paid",
                       "neuer Artikel übernimmt die Herkunft des Eintrags")

        // Ein Anteil ≤ 0 wird nie gelernt (bestehendes Verhalten) — auch keine Quelle.
        let zero = ShoppingItem(name: "Milch", store: store)
        let zeroSource = zero.priceSource
        ActualPriceEntryView.apply(itemActualTotal: 0, to: zero, in: store)
        XCTAssertEqual(zero.priceSource, zeroSource)
        XCTAssertNil(store.learnedPriceOrigins["milch"])
    }

    // MARK: - AC-9

    func testEditItemSaveWritesManualAndEstimate() {
        // Preis eingetragen → manual
        let manual = ShoppingItem(name: "Milch", category: "Milchprodukte", quantityAmount: 2)
        manual.priceSource = "receipt"
        manual.priceSourceDate = later
        EditItemView.applyPriceEdit(priceText: "3,00", initialPriceText: "2,40", oldUnit: "",
                                    priceCategory: "Milchprodukte", to: manual)
        XCTAssertEqual(manual.estimatedPrice, 1.5, "Feld hält die Zeilensumme, gespeichert wird je Einheit")
        XCTAssertFalse(manual.estimatedPriceIsAutoDerived)
        XCTAssertEqual(manual.priceSource, "manual")
        XCTAssertNil(manual.priceSourceDate)

        // Feld geleert → Zurücksetzen auf Schätzung
        let reset = ShoppingItem(name: "Milch", category: "Milchprodukte", quantityAmount: 2)
        reset.estimatedPrice = 1.5
        reset.estimatedPriceIsAutoDerived = false
        reset.priceSource = "manual"
        EditItemView.applyPriceEdit(priceText: "", initialPriceText: "3,00", oldUnit: "",
                                    priceCategory: "Milchprodukte", to: reset)
        XCTAssertEqual(reset.estimatedPrice,
                       PriceEstimator.estimate(for: "Milch", category: "Milchprodukte", unit: "", quantityAmount: 2))
        XCTAssertTrue(reset.estimatedPriceIsAutoDerived)
        XCTAssertEqual(reset.priceSource, "estimate")
        XCTAssertNil(reset.priceSourceDate)

        // Nur Einheit geändert, Preis war Schätzung → neu geschätzt, Quelle estimate
        let unitChange = ShoppingItem(name: "Milch", category: "Milchprodukte", quantityAmount: 500, unit: "ml")
        unitChange.estimatedPrice = 1.20 // alter Stückpreis vor der Einheitenänderung
        unitChange.priceSource = ""
        EditItemView.applyPriceEdit(priceText: "x", initialPriceText: "x", oldUnit: "",
                                    priceCategory: "Milchprodukte", to: unitChange)
        XCTAssertEqual(unitChange.estimatedPrice,
                       PriceEstimator.estimate(for: "Milch", category: "Milchprodukte", unit: "ml", quantityAmount: 500))
        XCTAssertEqual(unitChange.priceSource, "estimate")

        // Nichts geändert → eigener Preis bleibt samt Quelle
        let untouched = ShoppingItem(name: "Milch", quantityAmount: 1)
        untouched.estimatedPrice = 1.79
        untouched.estimatedPriceIsAutoDerived = false
        untouched.priceSource = "manual"
        EditItemView.applyPriceEdit(priceText: "1,79", initialPriceText: "1,79", oldUnit: "",
                                    priceCategory: "", to: untouched)
        XCTAssertEqual(untouched.estimatedPrice, 1.79)
        XCTAssertEqual(untouched.priceSource, "manual")
    }

    // MARK: - AC-10

    func testLegacyResetWritesEstimateSource() throws {
        let context = ModelContext(try makeContainer())
        let store = Store(name: "Altbon", emoji: "🥐", colorHex: "#AA5500")
        store.learnedPrices["laugenbrötchen"] = 1.56
        store.learnedPriceDates["laugenbrötchen"] = earlier
        store.learnedPriceOrigins["laugenbrötchen"] = "receipt"
        context.insert(store)
        let item = ShoppingItem(name: "Laugenbrötchen", category: "Backwaren", store: store)
        // Altzustand von Hand (init verwirft den Altwert seit #10 selbst)
        item.estimatedPrice = 1.56
        item.estimatedPriceIsAutoDerived = false
        item.priceSource = ""
        context.insert(item)
        XCTAssertEqual(item.priceOrigin, "learned", "Vorbedingung: Altdaten zeigen „gelernt“")

        LegacyLearnedPriceReset.runIfNeeded(context: context)

        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
        XCTAssertEqual(item.priceSource, "estimate")
        XCTAssertNil(item.priceSourceDate)
        XCTAssertEqual(item.priceOrigin, "estimate")
        XCTAssertEqual(store.learnedPrices, ["laugenbrötchen": 1.56])
        XCTAssertEqual(store.learnedPriceUnits, [:])
        XCTAssertEqual(store.learnedPriceDates, ["laugenbrötchen": earlier])
        XCTAssertEqual(store.learnedPriceOrigins, ["laugenbrötchen": "receipt"])
    }

    // MARK: - AC-11

    func testSyncApplyRemovesOriginForForeignPrice() {
        func localStore() -> Store {
            makeStore(key: "eier", price: 0.39, unit: "stk", date: earlier, origin: "receipt")
        }

        // Fremder, abweichender Preis (neuer, anderer Betrag) → Herkunft weg → „gelernt“
        let foreign = localStore()
        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.45], dates: ["eier": later], units: ["eier": "stk"]),
            to: foreign)
        XCTAssertEqual(foreign.learnedPrices["eier"], 0.45)
        XCTAssertNil(foreign.learnedPriceOrigins["eier"])
        XCTAssertEqual(ShoppingItem(name: "Eier", store: foreign).priceSource, "learned")

        // Gleiches Datum, gleicher Betrag → derselbe Preis, Herkunft bleibt
        let same = localStore()
        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": earlier], units: ["eier": "stk"]),
            to: same)
        XCTAssertEqual(same.learnedPriceOrigins["eier"], "receipt")

        let sameWithoutUnit = localStore()
        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.39], dates: ["eier": earlier], units: [:]),
            to: sameWithoutUnit)
        XCTAssertEqual(sameWithoutUnit.learnedPriceOrigins["eier"], "receipt")

        // Älterer Fremdpreis wird ignoriert → Herkunft bleibt
        let older = makeStore(key: "eier", price: 0.39, unit: "stk", date: later, origin: "receipt")
        LearnedPriceSync.apply(
            LearnedPriceSync.State(prices: ["eier": 0.45], dates: ["eier": earlier], units: ["eier": "stk"]),
            to: older)
        XCTAssertEqual(older.learnedPriceOrigins["eier"], "receipt")

        // Origins reisen nicht mit: State hat nur prices/dates/units, das JSON kennt keine Herkunft.
        let labels = Mirror(reflecting: LearnedPriceSync.State()).children.compactMap { $0.label }
        XCTAssertEqual(labels, ["prices", "dates", "units"])
        let json = LearnedPriceSync.encode(LearnedPriceSync.State(store: localStore()))
        XCTAssertFalse(json.contains("receipt"), json)
        XCTAssertFalse(json.lowercased().contains("origin"), json)
    }

    // MARK: - AC-12

    func testNewFieldsHaveDefaultsAndContainerLoads() throws {
        let fresh = makeStore()
        XCTAssertEqual(fresh.learnedPriceOrigins, [:])
        XCTAssertNil(ShoppingItem(name: "Seitan").priceSourceDate)

        let container = try makeContainer()
        let context = ModelContext(container)
        let store = makeStore("Rewe")
        store.learnedPriceOrigins["butter"] = "paid"
        context.insert(store)
        let item = ShoppingItem(name: "Kontrollbrot", store: store)
        item.priceSource = "receipt"
        item.priceSourceDate = later
        context.insert(item)
        try context.save()

        let reread = ModelContext(container)
        let stores = try reread.fetch(FetchDescriptor<Store>())
        let items = try reread.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(stores.first { $0.name == "Rewe" }?.learnedPriceOrigins, ["butter": "paid"])
        let rereadItem = try XCTUnwrap(items.first { $0.name == "Kontrollbrot" })
        XCTAssertEqual(rereadItem.priceSource, "receipt")
        XCTAssertEqual(rereadItem.priceSourceDate, later)
    }

    // MARK: - AC-13

    func testSourceTextsAndAccessibilityLabel() {
        XCTAssertEqual(PriceSourceDisplay.text(origin: "receipt", date: october12, locale: german), "Bon · 12.10.")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "receipt", date: nil, locale: german), "Bon")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "paid", date: nil, locale: german), "bezahlt")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "learned", date: nil, locale: german), "gelernt")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "manual", date: nil, locale: german), "eigener Preis")
        XCTAssertEqual(PriceSourceDisplay.text(origin: "estimate", date: nil, locale: german), "Schätzung")

        XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: "estimate"), "ca. ")
        for origin in ["receipt", "paid", "learned", "manual"] {
            XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: origin), "", "kein „ca.“ bei \(origin)")
        }

        XCTAssertEqual(
            PriceSourceDisplay.accessibilityLabel(amount: "2,90 €", origin: "estimate", date: nil, locale: german),
            "ca. 2,90 €, Schätzung")
        XCTAssertEqual(
            PriceSourceDisplay.accessibilityLabel(amount: "2,50 €", origin: "manual", date: nil, locale: german),
            "2,50 €, eigener Preis")
        XCTAssertEqual(
            PriceSourceDisplay.accessibilityLabel(amount: "1,99 €", origin: "receipt", date: october12, locale: german),
            "1,99 €, Bon · 12.10.")
    }

    // MARK: - AC-14

    func testCompletedItemShowsOnlyRealPriceWithSource() {
        let estimate = ShoppingItem(name: "Seitan", category: "Lebensmittel")
        XCTAssertEqual(estimate.priceOrigin, "estimate")
        XCTAssertTrue(ItemRow.showsPrice(isCompleted: false,
                                         estimatedPriceIsAutoDerived: estimate.estimatedPriceIsAutoDerived),
                      "offene Schätzung bleibt sichtbar (Budget)")
        estimate.isCompleted = true
        XCTAssertFalse(ItemRow.showsPrice(isCompleted: estimate.isCompleted,
                                          estimatedPriceIsAutoDerived: estimate.estimatedPriceIsAutoDerived),
                       "abgehakt mit Schätzung: weder Preis noch Quelle")

        let learned = ShoppingItem(name: "Butter", store: makeStore(key: "butter", price: 1.99, unit: "stk"))
        learned.isCompleted = true
        XCTAssertTrue(ItemRow.showsPrice(isCompleted: learned.isCompleted,
                                         estimatedPriceIsAutoDerived: learned.estimatedPriceIsAutoDerived),
                      "abgehakt mit echter Quelle: Preis und Quelle")
        XCTAssertEqual(PriceSourceDisplay.text(origin: learned.priceOrigin, date: learned.priceSourceDate,
                                               locale: german), "gelernt")
    }

    // MARK: - AC-15

    func testDiagnosisLinesMatchResolverResult() {
        // Treffer
        let hitStore = makeStore(key: "butter", price: 1.99, unit: "stk", date: later, origin: "receipt")
        let hitItem = ShoppingItem(name: "Butter", store: hitStore)
        // Obergrenze überschritten
        let capStore = makeStore(key: "steak", price: 150, unit: "stk")
        let capItem = ShoppingItem(name: "Steak", quantityAmount: 2, store: capStore)
        // Einheit-Konflikt
        let mismatchStore = makeStore(key: "mehl", price: 0.0011, unit: "g")
        let mismatchItem = ShoppingItem(name: "Mehl", quantityAmount: 1, unit: "kg", store: mismatchStore)

        let cases: [(item: ShoppingItem, store: Store, reason: LearnedPriceResolution.Reason,
                     key: String, entryBucket: String, itemBucket: String)] = [
            (hitItem, hitStore, .applied, "butter", "stk", "stk"),
            (capItem, capStore, .exceedsCap, "steak", "stk", "stk"),
            (mismatchItem, mismatchStore, .unitMismatch, "mehl", "g", "kg")
        ]
        for c in cases {
            let resolution = PriceDiagnosis.resolution(for: c.item, in: c.store)
            XCTAssertEqual(resolution, resolve(c.item, in: c.store), "dieselbe Kette wie init (\(c.key))")
            XCTAssertEqual(resolution.reason, c.reason, c.key)

            let text = PriceDiagnosis.lines(for: c.item, in: c.store).joined(separator: "\n")
            XCTAssertTrue(text.contains(c.key), "Schlüssel fehlt: \(text)")
            XCTAssertTrue(text.contains(c.entryBucket), "Bezugsgröße des Eintrags fehlt: \(text)")
            XCTAssertTrue(text.contains(c.itemBucket), "Bezugsgröße des Artikels fehlt: \(text)")
            XCTAssertTrue(text.contains(c.item.quantitySource), "quantitySource fehlt: \(text)")
            XCTAssertTrue(text.contains("200"), "Obergrenze fehlt: \(text)")
            XCTAssertTrue(text.contains(PriceDiagnosis.reasonText(c.reason)), "Ergebnis/Grund fehlt: \(text)")
            for other in cases where other.reason != c.reason {
                XCTAssertFalse(text.contains(PriceDiagnosis.reasonText(other.reason)),
                               "falscher Grund \(other.reason) in: \(text)")
            }
        }

        let reasonTexts = LearnedPriceResolution.Reason.allCases.map(PriceDiagnosis.reasonText)
        XCTAssertEqual(Set(reasonTexts).count, LearnedPriceResolution.Reason.allCases.count,
                       "jeder Grund hat einen eigenen Text")
        XCTAssertFalse(reasonTexts.contains(""))

        // Ohne Laden: Grund noStore, keine erfundenen Einträge
        let storeless = ShoppingItem(name: "Butter")
        XCTAssertEqual(PriceDiagnosis.resolution(for: storeless, in: nil).reason, .noStore)
        XCTAssertTrue(PriceDiagnosis.lines(for: storeless, in: nil).joined()
            .contains(PriceDiagnosis.reasonText(.noStore)))
    }

    // MARK: - AC-16

    func testAllNewStringsExistInGermanAndEnglish() throws {
        let appBundle = Bundle(for: Store.self)
        let de = try XCTUnwrap(appBundle.path(forResource: "de", ofType: "lproj").flatMap(Bundle.init(path:)),
                               "de.lproj fehlt im App-Bündel")
        let en = try XCTUnwrap(appBundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)),
                               "en.lproj fehlt im App-Bündel")
        let missing = "\u{0}MISSING"
        let keys = PriceSourceDisplay.allLocalizationKeys
        XCTAssertFalse(keys.isEmpty)
        XCTAssertEqual(Set(keys).count, keys.count, "Schlüssel doppelt")

        var germanTexts: [String] = []
        for key in keys {
            let deText = de.localizedString(forKey: key, value: missing, table: nil)
            let enText = en.localizedString(forKey: key, value: missing, table: nil)
            XCTAssertNotEqual(deText, missing, "de fehlt: \(key)")
            XCTAssertNotEqual(enText, missing, "en fehlt: \(key)")
            XCTAssertNotEqual(deText, key, "de ist der Schlüssel: \(key)")
            XCTAssertNotEqual(enText, key, "en ist der Schlüssel: \(key)")
            XCTAssertNotEqual(deText, enText, "de und en gleich: \(key)")
            germanTexts.append(deText)
        }
        // Die Liste ist echt: sie trägt die Quelltexte der Spec und den Abschnittstitel.
        for expected in ["bezahlt", "gelernt", "eigener Preis", "Schätzung", "Preisdiagnose"] {
            XCTAssertTrue(germanTexts.contains(expected), "„\(expected)“ fehlt unter den neuen Schlüsseln")
        }
        XCTAssertTrue(germanTexts.contains { $0.hasPrefix("Bon") }, "„Bon“ fehlt unter den neuen Schlüsseln")
        for reason in LearnedPriceResolution.Reason.allCases {
            XCTAssertTrue(germanTexts.contains(PriceDiagnosis.reasonText(reason)),
                          "Grundtext \(reason) gehört zu den neuen, lokalisierten Schlüsseln")
        }
    }

    // MARK: - Adversary F001: Parität gegen feste Werte der ALTEN init-Kette

    /// Unabhängig vom Resolver: Die Erwartungen sind von Hand aus der alten Kette in
    /// `git show HEAD:SmartCart/Models/ShoppingItem.swift` (Stand 9e9536a, vor #151) nachgerechnet —
    /// Schlüssel per Teilstring/Fuzzy, Obergrenze `Preis × max(Menge, 1) <= 200`, dann
    /// `learnedRateUsage`; sonst `PriceEstimator.estimate` (Stichwort „hackfleisch“ 4,00,
    /// „brötchen“ 2,50, „käse“ 3,50, Kategorie „Lebensmittel“ 2,90, „steak“ trifft das Stichwort „tea“ → 3,00).
    func testInitMatchesHandWrittenExpectationsFromPreviousChain() {
        struct Case {
            let label: String
            let key: String?, entry: Double, entryUnit: String?
            let name: String, category: String, quantity: Double, unit: String, source: String
            let price: Double?, expectedUnit: String, autoDerived: Bool
        }
        let cases: [Case] = [
            Case(label: "Stückpreis an Stück-Artikel", key: "butter", entry: 1.99, entryUnit: "stk",
                 name: "Butter", category: "", quantity: 2, unit: "", source: "user",
                 price: 1.99, expectedUnit: "", autoDerived: false),
            Case(label: "Grammrate an g-Artikel, Menge user", key: "hackfleisch", entry: 0.0125, entryUnit: "g",
                 name: "Hackfleisch", category: "", quantity: 400, unit: "g", source: "user",
                 price: 0.0125, expectedUnit: "g", autoDerived: false),
            Case(label: "Grammrate an g-Artikel, Menge history", key: "hackfleisch", entry: 0.0125, entryUnit: "g",
                 name: "Hackfleisch", category: "", quantity: 400, unit: "g", source: "history",
                 price: 0.0125, expectedUnit: "g", autoDerived: false),
            Case(label: "Grammrate an g-Artikel, Menge package", key: "hackfleisch", entry: 0.0125, entryUnit: "g",
                 name: "Hackfleisch", category: "", quantity: 400, unit: "g", source: "package",
                 price: 0.0125, expectedUnit: "g", autoDerived: false),
            Case(label: "Grammrate ohne Menge → nur Rate, Einheit g", key: "hackfleisch", entry: 0.0125, entryUnit: "g",
                 name: "Hackfleisch", category: "", quantity: 1, unit: "", source: "none",
                 price: 0.0125, expectedUnit: "g", autoDerived: false),
            Case(label: "Grammrate an Stück-Artikel (user) → verworfen", key: "hackfleisch", entry: 0.0125, entryUnit: "g",
                 name: "Hackfleisch", category: "", quantity: 1, unit: "", source: "user",
                 price: 4.00, expectedUnit: "", autoDerived: true),
            Case(label: "Altbestand ohne Bezugsgröße → verworfen", key: "laugenbrötchen", entry: 1.56, entryUnit: nil,
                 name: "Laugenbrötchen", category: "", quantity: 1, unit: "", source: "user",
                 price: 2.50, expectedUnit: "", autoDerived: true),
            Case(label: "Obergrenze knapp darunter (199,98 €)", key: "steak", entry: 99.99, entryUnit: "stk",
                 name: "Steak", category: "", quantity: 2, unit: "", source: "user",
                 price: 99.99, expectedUnit: "", autoDerived: false),
            Case(label: "Obergrenze genau (200,00 €)", key: "steak", entry: 100, entryUnit: "stk",
                 name: "Steak", category: "", quantity: 2, unit: "", source: "user",
                 price: 100, expectedUnit: "", autoDerived: false),
            // Seit #160/#162: Katalogtreffer „steak" (5,99 €) statt des früheren Teilstring-Fehltreffers
            // „tea" in „Steak" (3,00 €).
            Case(label: "Obergrenze knapp darüber (200,01 €)", key: "steak", entry: 100.005, entryUnit: "stk",
                 name: "Steak", category: "", quantity: 2, unit: "", source: "user",
                 price: 5.99, expectedUnit: "", autoDerived: true),
            Case(label: "Menge 0 zählt als 1 (200,00 €)", key: "steak", entry: 200, entryUnit: "stk",
                 name: "Steak", category: "", quantity: 0, unit: "", source: "user",
                 price: 200, expectedUnit: "", autoDerived: false),
            Case(label: "Menge 0 zählt als 1 (200,01 €)", key: "steak", entry: 200.01, entryUnit: "stk",
                 name: "Steak", category: "", quantity: 0, unit: "", source: "user",
                 price: 5.99, expectedUnit: "", autoDerived: true),
            Case(label: "Teilstring-Treffer", key: "hackfleisch gemischt 500g", entry: 3.49, entryUnit: "stk",
                 name: "Hackfleisch", category: "", quantity: 1, unit: "", source: "user",
                 price: 3.49, expectedUnit: "", autoDerived: false),
            Case(label: "Fuzzy-Treffer (Saitan ↔ seitan)", key: "seitan", entry: 2.99, entryUnit: "stk",
                 name: "Saitan", category: "", quantity: 1, unit: "", source: "user",
                 price: 2.99, expectedUnit: "", autoDerived: false),
            Case(label: "kein Treffer → Stichwort-Schätzung", key: "butter", entry: 1.99, entryUnit: "stk",
                 name: "Käse", category: "", quantity: 1, unit: "", source: "user",
                 price: 3.50, expectedUnit: "", autoDerived: true),
            // Seit #162 hat „Seitan" einen Katalogpreis (2,49 €); die Kategorie-Pauschale greift nur
            // noch für Namen ohne Katalogtreffer.
            Case(label: "Katalogtreffer ohne gelernten Eintrag", key: nil, entry: 0, entryUnit: nil,
                 name: "Seitan", category: "Lebensmittel", quantity: 1, unit: "", source: "user",
                 price: 2.49, expectedUnit: "", autoDerived: true),
            Case(label: "kein Eintrag → Kategorie-Schätzung", key: nil, entry: 0, entryUnit: nil,
                 name: "artikel ohne keyword-treffer", category: "Lebensmittel", quantity: 1, unit: "", source: "user",
                 price: 2.90, expectedUnit: "", autoDerived: true)
        ]
        for c in cases {
            let store = makeStore()
            if let key = c.key {
                store.learnedPrices[key] = c.entry
                if let entryUnit = c.entryUnit { store.learnedPriceUnits[key] = entryUnit }
            }
            let item = ShoppingItem(name: c.name, category: c.category, quantityAmount: c.quantity, unit: c.unit,
                                    store: store, quantitySource: c.source)
            XCTAssertEqual(item.estimatedPrice, c.price, "estimatedPrice, \(c.label)")
            XCTAssertEqual(item.unit, c.expectedUnit, "unit, \(c.label)")
            XCTAssertEqual(item.estimatedPriceIsAutoDerived, c.autoDerived, "estimatedPriceIsAutoDerived, \(c.label)")
        }
    }

    // MARK: - Adversary F002 (Unit-Teil): Bon lernen → neuer Artikel zeigt „Bon“ mit Datum

    func testReceiptLearnThenNewItemShowsReceiptWithDate() {
        let store = makeStore()
        let learnedAt = october12
        ReceiptLearning.learn(ReceiptLearning.Plan(key: "haferdrink", perUnitPrice: 1.49, unit: "stk"),
                              into: store, at: learnedAt)

        let item = ShoppingItem(name: "Haferdrink", store: store)

        XCTAssertEqual(item.estimatedPrice, 1.49)
        XCTAssertFalse(item.estimatedPriceIsAutoDerived)
        XCTAssertEqual(item.priceSource, "receipt")
        XCTAssertEqual(item.priceSourceDate, store.learnedPriceDates["haferdrink"])
        XCTAssertEqual(item.priceSourceDate, learnedAt)
        XCTAssertEqual(PriceSourceDisplay.text(origin: item.priceOrigin, date: item.priceSourceDate, locale: german),
                       "Bon · 12.10.")
    }
}
