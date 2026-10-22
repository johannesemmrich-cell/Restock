import XCTest
import CloudKit
@testable import Restock

/// Issue #163, Weg A: Community-Preispool in der öffentlichen CloudKit-Datenbank, Opt-in.
/// Netzfrei über `FakeCommunityPriceDatabase`; der Zwischenspeicher benutzt je Test eine eigene
/// `UserDefaults`-Suite, nur die Stufen-Tests an `ShoppingItem.init` gehen über `.shared` und
/// räumen ihn in `setUp`/`tearDown` wieder ab.
@MainActor
final class CommunityPriceTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var cache: CommunityPriceCache!
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15

    override func setUp() {
        super.setUp()
        suiteName = "UT-community-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        cache = CommunityPriceCache(defaults: defaults)
        CommunityPriceCache.shared.clear()
        UserDefaults.standard.removeObject(forKey: CommunityPriceService.sharingEnabledKey)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        CommunityPriceCache.shared.clear()
        UserDefaults.standard.removeObject(forKey: CommunityPriceService.sharingEnabledKey)
        super.tearDown()
    }

    private func makeService(_ fake: FakeCommunityPriceDatabase, sharing: Bool) -> CommunityPriceService {
        defaults.set(sharing, forKey: CommunityPriceService.sharingEnabledKey)
        return CommunityPriceService(database: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
    }

    private func daysAgo(_ days: Double) -> Date { fixedNow.addingTimeInterval(-days * 86_400) }

    private func observation(_ price: Double, unit: String = "stk", daysAgo days: Double = 1) -> CommunityPrice.Observation {
        CommunityPrice.Observation(price: price, unit: unit, observedAt: daysAgo(days))
    }

    // MARK: - Kette und Schlüssel

    func testChainIsFirstWordLowercasedAlphanumeric() {
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "Rewe City"), "rewe")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "REWE"), "rewe")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "dm-drogerie markt"), "dm")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "Aldi Süd"), "aldi")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "Netto Marken-Discount"), "netto")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "  Edeka Müller "), "edeka")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "Müller"), "müller")
        XCTAssertEqual(CommunityPrice.chain(fromStoreName: "---"), "")
        XCTAssertEqual(CommunityPrice.chainDisplayName(fromStoreName: "Rewe City"), "Rewe")
        XCTAssertEqual(CommunityPrice.chainDisplayName(fromStoreName: "dm-drogerie markt"), "dm")
        XCTAssertEqual(CommunityPrice.itemKey("  Mozzarella "), "mozzarella")
    }

    // MARK: - Aggregat

    func testAggregateNeedsThreeRecentObservationsAndUsesMedian() {
        XCTAssertNil(CommunityPrice.aggregate([observation(1.0), observation(1.2)], now: fixedNow), "zwei reichen nicht")
        let odd = CommunityPrice.aggregate([observation(1.0), observation(5.0), observation(1.2)], now: fixedNow)
        XCTAssertEqual(odd?.price, 1.2, "Median, nicht Mittelwert")
        XCTAssertEqual(odd?.count, 3)
        let even = CommunityPrice.aggregate([observation(1.0), observation(1.2), observation(1.4), observation(2.0)], now: fixedNow)
        XCTAssertEqual(try XCTUnwrap(even?.price), 1.3, accuracy: 0.0001)
        // Älter als 180 Tage zählt nicht.
        XCTAssertNil(CommunityPrice.aggregate(
            [observation(1.0, daysAgo: 181), observation(1.0, daysAgo: 200), observation(1.0, daysAgo: 1)], now: fixedNow))
        // Jüngste 20 gewinnen: 25 alte teure, 20 jüngere günstige → Median der 20.
        var many = (0..<25).map { observation(9.0, daysAgo: 100 + Double($0)) }
        many += (0..<20).map { observation(1.0, daysAgo: Double($0) + 1) }
        let capped = CommunityPrice.aggregate(many, now: fixedNow)
        XCTAssertEqual(capped?.price, 1.0)
        XCTAssertEqual(capped?.count, 20)
        XCTAssertEqual(capped?.latest, daysAgo(1), "jüngste Beobachtung")
    }

    func testAggregateUsesMajorityUnitOnly() {
        let mixed = [observation(0.01, unit: "g"), observation(0.012, unit: "g"), observation(0.011, unit: "g"),
                     observation(1.99, unit: "stk"), observation(2.49, unit: "stk")]
        let aggregate = CommunityPrice.aggregate(mixed, now: fixedNow)
        XCTAssertEqual(aggregate?.unit, "g")
        XCTAssertEqual(try XCTUnwrap(aggregate?.price), 0.011, accuracy: 0.000001)
        XCTAssertEqual(aggregate?.count, 3)
        // Gleichstand: alphabetisch kleinere Bezugsgröße, dann zu wenige → nil.
        let tie = [observation(0.01, unit: "g"), observation(0.012, unit: "g"), observation(1.99, unit: "stk"), observation(2.49, unit: "stk")]
        XCTAssertNil(CommunityPrice.aggregate(tie, now: fixedNow))
        XCTAssertNil(CommunityPrice.aggregate([observation(0, unit: "stk"), observation(0, unit: "stk"), observation(0, unit: "stk")], now: fixedNow),
                     "Nullpreise zählen nicht")
    }

    // MARK: - Zwischenspeicher

    func testCacheUpdateKeepsOtherChainsAndRemovesQueriedKeysWithoutAggregate() {
        let a = CommunityPrice.Aggregate(price: 1.09, unit: "stk", count: 3, latest: fixedNow)
        cache.update(chain: "rewe", queriedKeys: ["mozzarella", "butter"], aggregates: ["mozzarella": a])
        cache.update(chain: "lidl", queriedKeys: ["butter"], aggregates: ["butter": a])
        XCTAssertEqual(cache.aggregate(chain: "rewe", itemKey: "mozzarella"), a)
        XCTAssertNil(cache.aggregate(chain: "rewe", itemKey: "butter"))
        XCTAssertEqual(cache.aggregate(chain: "lidl", itemKey: "butter"), a)
        // Erneute Abfrage ohne Aggregat entfernt den Eintrag, andere Kette bleibt.
        cache.update(chain: "rewe", queriedKeys: ["mozzarella"], aggregates: [:])
        XCTAssertNil(cache.aggregate(chain: "rewe", itemKey: "mozzarella"))
        XCTAssertEqual(cache.aggregate(chain: "lidl", itemKey: "butter"), a)
        cache.clear()
        XCTAssertTrue(cache.entries().isEmpty)
    }

    // MARK: - Schreiben (Opt-in, Upsert)

    func testSharingIsOnByDefaultWhenKeyIsAbsent() async throws {
        // PO 2026-10-20: Standard an (Opt-out). Frische Installation = Schlüssel fehlt.
        XCTAssertNil(defaults.object(forKey: CommunityPriceService.sharingEnabledKey))
        XCTAssertTrue(CommunityPriceService.sharingEnabledDefault)
        XCTAssertTrue(CommunityPriceService.isSharingEnabled(in: defaults))
        let fake = FakeCommunityPriceDatabase()
        let service = CommunityPriceService(database: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
        let ok = await service.contribute(.init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: "stk"))
        XCTAssertTrue(ok)
        XCTAssertEqual(fake.saved.count, 1, "ohne gespeicherte Entscheidung gilt der Standard: teilen")
        // Ein nicht-boolescher Fremdwert am Schlüssel fällt auf den Standard zurück.
        defaults.set("nein", forKey: CommunityPriceService.sharingEnabledKey)
        XCTAssertTrue(CommunityPriceService.isSharingEnabled(in: defaults))
    }

    func testContributeDoesNothingWhileSharingIsOff() async {
        let fake = FakeCommunityPriceDatabase()
        let service = makeService(fake, sharing: false)
        let ok = await service.contribute(.init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: "stk"))
        XCTAssertFalse(ok)
        XCTAssertTrue(fake.saved.isEmpty, "ohne Schalter verlässt nichts das Gerät")
    }

    func testContributeWritesAnonymousRecordWithDeterministicName() async throws {
        let fake = FakeCommunityPriceDatabase()
        let service = makeService(fake, sharing: true)
        let ok = await service.contribute(.init(itemName: " Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: "STK"))
        XCTAssertTrue(ok)
        let record = try XCTUnwrap(fake.saved.last)
        XCTAssertEqual(record.recordType, "CommunityPrice")
        XCTAssertEqual(record["itemKey"] as? String, "mozzarella")
        XCTAssertEqual(record["chain"] as? String, "rewe")
        XCTAssertEqual(record["price"] as? Double, 1.09)
        XCTAssertEqual(record["unit"] as? String, "stk")
        XCTAssertEqual(record["observedAt"] as? Date, fixedNow)
        let clientID = try XCTUnwrap(record["clientID"] as? String)
        let expectedClientID = await service.clientID()
        XCTAssertEqual(clientID, expectedClientID, "Kennung je Installation, bleibt gleich")
        XCTAssertEqual(Set(record.allKeys()), CommunityPriceSchema.fields, "nur die Schema-Felder, nichts Persönliches")
        XCTAssertEqual(record.recordID.recordName, CommunityPriceSchema.recordName(clientID: clientID, chain: "rewe", itemKey: "mozzarella"))
        XCTAssertFalse(record.recordID.recordName.contains("mozzarella"))
        XCTAssertFalse(record.recordID.recordName.contains(clientID))

        // Zweiter Preis für denselben Artikel: gleicher Record-Name (Upsert), kein zweiter Eintrag.
        _ = await service.contribute(.init(itemName: "Mozzarella", storeName: "REWE", perUnitPrice: 1.19, unit: "stk"))
        XCTAssertEqual(fake.saved.count, 2)
        XCTAssertEqual(fake.saved[0].recordID, fake.saved[1].recordID)
        XCTAssertEqual(fake.stored.count, 1)

        // Unbrauchbare Eingaben werden verworfen.
        let zero = await service.contribute(.init(itemName: "Butter", storeName: "Rewe", perUnitPrice: 0, unit: "stk"))
        XCTAssertFalse(zero)
        let noUnit = await service.contribute(.init(itemName: "Butter", storeName: "Rewe", perUnitPrice: 1, unit: ""))
        XCTAssertFalse(noUnit)
        XCTAssertEqual(fake.saved.count, 2)
    }

    func testContributeUpdatesServerRecordAfterServerRecordChanged() async throws {
        let fake = FakeCommunityPriceDatabase()
        let service = makeService(fake, sharing: true)
        let clientID = await service.clientID()
        let name = CommunityPriceSchema.recordName(clientID: clientID, chain: "rewe", itemKey: "mozzarella")
        let server = CKRecord(recordType: "CommunityPrice", recordID: CKRecord.ID(recordName: name))
        CommunityPriceSchema.fill(server, itemKey: "mozzarella", chain: "rewe", price: 0.99, unit: "stk", observedAt: daysAgo(30), clientID: clientID)
        fake.stored[server.recordID] = server
        fake.failFirstSaveWithServerRecordChanged = true

        let ok = await service.contribute(.init(itemName: "Mozzarella", storeName: "Rewe", perUnitPrice: 1.29, unit: "stk"))
        XCTAssertTrue(ok)
        XCTAssertEqual(fake.saveAttempts, 2, "einmal abgelehnt, dann der Server-Record")
        let stored = try XCTUnwrap(fake.stored[server.recordID])
        XCTAssertEqual(stored["price"] as? Double, 1.29)
        XCTAssertEqual(stored["observedAt"] as? Date, fixedNow)

        fake.saveError = CKError(.networkUnavailable)
        let failed = await service.contribute(.init(itemName: "Butter", storeName: "Rewe", perUnitPrice: 2.19, unit: "stk"))
        XCTAssertFalse(failed, "Netzfehler: still, kein Absturz")
    }

    // MARK: - Lesen

    func testRefreshFillsCacheAndRemovesKeysWithoutEnoughData() async throws {
        let fake = FakeCommunityPriceDatabase()
        for (index, price) in [1.09, 0.99, 1.19, 0.89].enumerated() {
            fake.add(itemKey: "mozzarella", chain: "rewe", price: price, unit: "stk", observedAt: daysAgo(Double(index + 1)), client: "c\(index)")
        }
        fake.add(itemKey: "butter", chain: "rewe", price: 2.19, unit: "stk", observedAt: daysAgo(1), client: "c0")
        fake.add(itemKey: "mozzarella", chain: "lidl", price: 0.79, unit: "stk", observedAt: daysAgo(1), client: "c0")
        cache.update(chain: "rewe", queriedKeys: [], aggregates: ["butter": .init(price: 9, unit: "stk", count: 3, latest: fixedNow)])
        let service = makeService(fake, sharing: false)

        let count = await service.refresh(storeName: "Rewe City", itemNames: ["Mozzarella", "Butter", "Butter", ""])
        XCTAssertEqual(count, 1)
        XCTAssertEqual(fake.lastQuery?.chain, "rewe")
        XCTAssertEqual(fake.lastQuery?.itemKeys, ["butter", "mozzarella"], "Schlüssel eindeutig und sortiert")
        let aggregate = try XCTUnwrap(cache.aggregate(chain: "rewe", itemKey: "mozzarella"))
        XCTAssertEqual(aggregate.price, 1.04, accuracy: 0.0001, "Median von 0,89 0,99 1,09 1,19")
        XCTAssertEqual(aggregate.count, 4)
        XCTAssertEqual(aggregate.latest, daysAgo(1))
        XCTAssertNil(cache.aggregate(chain: "rewe", itemKey: "butter"), "nur eine Beobachtung → alter Eintrag entfernt")

        fake.fetchError = CKError(.networkUnavailable)
        let failed = await service.refresh(storeName: "Rewe", itemNames: ["Mozzarella"])
        XCTAssertNil(failed)
        XCTAssertNotNil(cache.aggregate(chain: "rewe", itemKey: "mozzarella"), "bei Fehler bleibt der Zwischenspeicher")

        let empty = await service.refresh(storeName: "Rewe", itemNames: [])
        XCTAssertEqual(empty, 0)
    }

    // MARK: - Stufe in ShoppingItem.init

    private func seedShared(chain: String, itemKey: String, price: Double, unit: String = "stk") {
        CommunityPriceCache.shared.update(chain: chain, queriedKeys: [],
                                          aggregates: [itemKey: .init(price: price, unit: unit, count: 3, latest: fixedNow)])
    }

    func testCommunityStageSitsBetweenOwnPricesAndCatalog() throws {
        seedShared(chain: "rewe", itemKey: "mozzarella", price: 0.95)
        let rewe = Store(name: "Rewe City", emoji: "🛒", colorHex: "#123456")

        let community = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        XCTAssertEqual(try XCTUnwrap(community.estimatedPrice), 0.95, accuracy: 0.0001)
        XCTAssertTrue(community.estimatedPriceIsAutoDerived, "fremde Beobachtung, kein eigener Preis")
        XCTAssertEqual(community.priceSource, "community:Rewe")
        XCTAssertEqual(community.priceOrigin, "community")
        XCTAssertEqual(community.priceSourceDetail, "Rewe")
        XCTAssertEqual(community.priceSourceDate, fixedNow)
        XCTAssertEqual(PriceSourceDisplay.amountPrefix(origin: "community"), "")
        XCTAssertFalse(PriceSourceDisplay.showsPrompt(origin: "community", hasPrice: true, isAutoDerived: true))
        let text = PriceSourceDisplay.text(origin: "community", date: fixedNow, detail: "Rewe", locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(text.hasPrefix("Community · Rewe · "), text)
        XCTAssertEqual(PriceSourceDisplay.text(origin: "community", date: nil, detail: "Rewe", locale: Locale(identifier: "de_DE")),
                       "Community · Rewe")

        // Eigener Preis in diesem Laden gewinnt.
        rewe.learnedPrices["mozzarella"] = 1.29
        rewe.learnedPriceUnits["mozzarella"] = "stk"
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", store: rewe).priceSource, "learned")

        // Eigener Preis aus einem anderen Laden gewinnt ebenfalls.
        let other = Store(name: "Edeka", emoji: "🛒", colorHex: "#123456")
        let lidl = Store(name: "Lidl", emoji: "🛒", colorHex: "#123456")
        lidl.learnedPrices["mozzarella"] = 0.99
        lidl.learnedPriceUnits["mozzarella"] = "stk"
        seedShared(chain: "edeka", itemKey: "mozzarella", price: 1.05)
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", store: other, otherStores: [lidl]).priceSource, "otherStore:Lidl")

        // Andere Kette, kein Eintrag → Katalog.
        let aldi = Store(name: "Aldi", emoji: "🛒", colorHex: "#123456")
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: aldi).priceSource, "estimate")
        // Ohne Laden → Katalog.
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", category: "Milchprodukte").priceSource, "estimate")
    }

    func testCommunityStageObeysUnitTableAndCap() throws {
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#123456")
        // Gramm-Rate an Stückartikel mit eingetippter Menge: verworfen → Katalog.
        seedShared(chain: "rewe", itemKey: "mozzarella", price: 0.008, unit: "g")
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe).priceSource, "estimate")
        // Ohne belegte Menge: Rate mit Einheit g, wie bei gelernten Preisen.
        let rate = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe, quantitySource: "none")
        XCTAssertEqual(rate.priceSource, "community:Rewe")
        XCTAssertEqual(rate.unit, "g")
        // Obergrenze 200 €.
        seedShared(chain: "rewe", itemKey: "mozzarella", price: 150)
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", category: "Milchprodukte", quantityAmount: 2, store: rewe).priceSource, "estimate")
    }

    // MARK: - Anwenden auf bestehende Artikel

    func testApplyTouchesOnlyAutoDerivedPendingItems() throws {
        let a = CommunityPrice.Aggregate(price: 0.95, unit: "stk", count: 3, latest: fixedNow)
        cache.update(chain: "rewe", queriedKeys: [], aggregates: ["mozzarella": a])
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#123456")
        let estimate = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        let manual = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        manual.estimatedPrice = 1.49
        manual.estimatedPriceIsAutoDerived = false
        manual.priceSource = "manual"
        let completed = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        completed.isCompleted = true
        let unrelated = ShoppingItem(name: "Butter", store: rewe)

        let changed = CommunityPriceService.apply(cache: cache, to: [estimate, manual, completed, unrelated], storeName: "Rewe")
        XCTAssertEqual(changed, 1)
        XCTAssertEqual(try XCTUnwrap(estimate.estimatedPrice), 0.95, accuracy: 0.0001)
        XCTAssertEqual(estimate.priceSource, "community:Rewe")
        XCTAssertEqual(manual.estimatedPrice, 1.49)
        XCTAssertEqual(manual.priceSource, "manual")
        XCTAssertEqual(completed.priceSource, "estimate")
        XCTAssertEqual(unrelated.priceSource, "estimate")

        // Unverändert: zweiter Lauf ändert nichts.
        XCTAssertEqual(CommunityPriceService.apply(cache: cache, to: [estimate], storeName: "Rewe"), 0)
        // Aggregat weg → zurück auf den Katalog.
        cache.update(chain: "rewe", queriedKeys: ["mozzarella"], aggregates: [:])
        XCTAssertEqual(CommunityPriceService.apply(cache: cache, to: [estimate], storeName: "Rewe"), 1)
        XCTAssertEqual(estimate.priceSource, "estimate")
        XCTAssertEqual(try XCTUnwrap(estimate.estimatedPrice), 1.09, accuracy: 0.0001)
    }

    func testCatalogRefreshLeavesCommunityPricesAlone() {
        XCTAssertNil(CatalogEstimateRefresh.refreshed(isAutoDerived: true, priceSource: "community:Rewe", name: "Mozzarella",
                                                      priceCategory: "Milchprodukte", unit: "", quantityAmount: 1))
        XCTAssertNotNil(CatalogEstimateRefresh.refreshed(isAutoDerived: true, priceSource: "estimate", name: "Mozzarella",
                                                         priceCategory: "Milchprodukte", unit: "", quantityAmount: 1))
    }

    // MARK: - Kettenübergreifend (PO 2026-10-22)

    func testRefreshFallsBackToAllChainsWhenOwnChainHasTooFewObservations() async throws {
        let fake = FakeCommunityPriceDatabase()
        // Rewe: 2 Beobachtungen (zu wenig), Lidl 2, Aldi 1 → zusammen 5.
        fake.add(itemKey: "mozzarella", chain: "rewe", price: 1.19, unit: "stk", observedAt: daysAgo(1), client: "c1")
        fake.add(itemKey: "mozzarella", chain: "rewe", price: 1.09, unit: "stk", observedAt: daysAgo(2), client: "c2")
        fake.add(itemKey: "mozzarella", chain: "lidl", price: 0.79, unit: "stk", observedAt: daysAgo(3), client: "c3")
        fake.add(itemKey: "mozzarella", chain: "lidl", price: 0.89, unit: "stk", observedAt: daysAgo(4), client: "c4")
        fake.add(itemKey: "mozzarella", chain: "aldi", price: 0.99, unit: "stk", observedAt: daysAgo(5), client: "c5")
        // Butter: insgesamt nur 2 → auch kettenübergreifend nichts.
        fake.add(itemKey: "butter", chain: "rewe", price: 2.19, unit: "stk", observedAt: daysAgo(1), client: "c1")
        fake.add(itemKey: "butter", chain: "lidl", price: 1.99, unit: "stk", observedAt: daysAgo(1), client: "c3")
        let service = makeService(fake, sharing: false)

        let count = await service.refresh(storeName: "Rewe City", itemNames: ["Mozzarella", "Butter"])
        XCTAssertEqual(count, 1, "nur Mozzarella hat ein Aggregat (über alle Ketten)")
        XCTAssertEqual(fake.lastQuery?.chain, "rewe", "zuerst die eigene Kette")
        XCTAssertEqual(fake.allChainsQueries, [["butter", "mozzarella"]], "dann alle Ketten, nur für Schlüssel ohne eigenes Aggregat")
        XCTAssertNil(cache.aggregate(chain: "rewe", itemKey: "mozzarella"))
        let all = try XCTUnwrap(cache.aggregate(chain: CommunityPrice.allChainsMarker, itemKey: "mozzarella"))
        XCTAssertEqual(all.price, 0.99, accuracy: 0.0001, "Median von 0,79 0,89 0,99 1,09 1,19")
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(all.latest, daysAgo(1))
        XCTAssertNil(cache.aggregate(chain: CommunityPrice.allChainsMarker, itemKey: "butter"), "zusammen < 3 → nichts")

        // Lesen am Artikel: Quelle „community:*", Anzeige „andere Läden".
        let resolution = try XCTUnwrap(CommunityPrice.resolve(
            forLowercasedName: "mozzarella", storeName: "Rewe City", itemUnit: "", quantityAmount: 1,
            quantitySource: "user", cache: cache))
        XCTAssertTrue(resolution.isAllChains)
        XCTAssertEqual(resolution.source, "community:*")
        XCTAssertNil(CommunityPrice.resolve(forLowercasedName: "butter", storeName: "Rewe City", itemUnit: "",
                                            quantityAmount: 1, quantitySource: "user", cache: cache))
    }

    func testOwnChainWithEnoughObservationsHasPriorityOverAllChains() async throws {
        let fake = FakeCommunityPriceDatabase()
        for (index, price) in [1.09, 1.19, 1.29].enumerated() {
            fake.add(itemKey: "mozzarella", chain: "rewe", price: price, unit: "stk", observedAt: daysAgo(Double(index + 1)), client: "r\(index)")
        }
        for index in 0..<5 {
            fake.add(itemKey: "mozzarella", chain: "lidl", price: 0.79, unit: "stk", observedAt: daysAgo(Double(index + 1)), client: "l\(index)")
        }
        let service = makeService(fake, sharing: false)
        let count = await service.refresh(storeName: "Rewe", itemNames: ["Mozzarella"])
        XCTAssertEqual(count, 1)
        XCTAssertTrue(fake.allChainsQueries.isEmpty, "eigene Kette reicht, keine zweite Abfrage")
        XCTAssertEqual(try XCTUnwrap(cache.aggregate(chain: "rewe", itemKey: "mozzarella")).price, 1.19, accuracy: 0.0001)

        // Liegt zusätzlich ein (älteres) Aggregat aller Ketten im Zwischenspeicher, gewinnt trotzdem die eigene Kette.
        cache.update(chain: CommunityPrice.allChainsMarker, queriedKeys: [],
                     aggregates: ["mozzarella": .init(price: 0.79, unit: "stk", count: 8, latest: fixedNow)])
        let resolution = try XCTUnwrap(CommunityPrice.resolve(
            forLowercasedName: "mozzarella", storeName: "Rewe", itemUnit: "", quantityAmount: 1,
            quantitySource: "user", cache: cache))
        XCTAssertFalse(resolution.isAllChains)
        XCTAssertEqual(resolution.source, "community:Rewe")
        XCTAssertEqual(resolution.price, 1.19, accuracy: 0.0001)
    }

    func testAllChainsQueryFailureKeepsOwnChainResults() async throws {
        let fake = FakeCommunityPriceDatabase()
        for (index, price) in [1.09, 1.19, 1.29].enumerated() {
            fake.add(itemKey: "mozzarella", chain: "rewe", price: price, unit: "stk", observedAt: daysAgo(Double(index + 1)), client: "r\(index)")
        }
        fake.add(itemKey: "butter", chain: "lidl", price: 1.99, unit: "stk", observedAt: daysAgo(1), client: "l0")
        cache.update(chain: CommunityPrice.allChainsMarker, queriedKeys: [],
                     aggregates: ["butter": .init(price: 2.09, unit: "stk", count: 4, latest: fixedNow)])
        fake.allChainsFetchError = CKError(.networkUnavailable)
        let service = makeService(fake, sharing: false)

        let count = await service.refresh(storeName: "Rewe", itemNames: ["Mozzarella", "Butter"])
        XCTAssertEqual(count, 1, "die eigene Kette zählt, die zweite Abfrage ist still gescheitert")
        XCTAssertNotNil(cache.aggregate(chain: "rewe", itemKey: "mozzarella"))
        XCTAssertEqual(cache.aggregate(chain: CommunityPrice.allChainsMarker, itemKey: "butter")?.price, 2.09,
                       "bei Fehler bleibt das alte Aggregat aller Ketten")
    }

    func testShoppingItemShowsAllChainsSource() throws {
        CommunityPriceCache.shared.update(chain: CommunityPrice.allChainsMarker, queriedKeys: [],
                                          aggregates: ["mozzarella": .init(price: 0.99, unit: "stk", count: 5, latest: fixedNow)])
        let rewe = Store(name: "Rewe City", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        XCTAssertEqual(try XCTUnwrap(item.estimatedPrice), 0.99, accuracy: 0.0001)
        XCTAssertTrue(item.estimatedPriceIsAutoDerived)
        XCTAssertEqual(item.priceSource, "community:*")
        XCTAssertEqual(item.priceOrigin, "community")
        XCTAssertEqual(item.priceSourceDetail, CommunityPrice.allChainsMarker)
        XCTAssertEqual(item.priceSourceDate, fixedNow)

        let german = Locale(identifier: "de_DE")
        let dated = PriceSourceDisplay.text(origin: "community", date: fixedNow, detail: item.priceSourceDetail, locale: german)
        XCTAssertTrue(dated.hasPrefix("Community · andere Läden · "), dated)
        XCTAssertEqual(PriceSourceDisplay.text(origin: "community", date: nil, detail: "*", locale: german),
                       "Community · andere Läden")
        // Eigene Kette weiter mit Namen.
        XCTAssertEqual(PriceSourceDisplay.text(origin: "community", date: nil, detail: "Rewe", locale: german), "Community · Rewe")

        // Ohne Laden gibt es keine Kette und damit auch keinen Wert aller Ketten (Siri, Widget).
        XCTAssertEqual(ShoppingItem(name: "Mozzarella", category: "Milchprodukte").priceSource, "estimate")
        // Ein Katalog-Neuberechnen fasst den Community-Wert nicht an.
        XCTAssertNil(CatalogEstimateRefresh.refreshed(isAutoDerived: true, priceSource: "community:*", name: "Mozzarella",
                                                      priceCategory: "Milchprodukte", unit: "", quantityAmount: 1))
    }

    func testApplyUsesAllChainsAggregate() throws {
        cache.update(chain: CommunityPrice.allChainsMarker, queriedKeys: [],
                     aggregates: ["mozzarella": .init(price: 0.99, unit: "stk", count: 5, latest: fixedNow)])
        let rewe = Store(name: "Rewe", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "Mozzarella", category: "Milchprodukte", store: rewe)
        XCTAssertEqual(item.priceSource, "estimate", "geteilter Zwischenspeicher ist leer, nur `cache` ist gefüllt")
        XCTAssertEqual(CommunityPriceService.apply(cache: cache, to: [item], storeName: "Rewe"), 1)
        XCTAssertEqual(item.priceSource, "community:*")
        XCTAssertEqual(try XCTUnwrap(item.estimatedPrice), 0.99, accuracy: 0.0001)
        // Eigene Kette kommt dazu → wechselt auf die eigene Kette.
        cache.update(chain: "rewe", queriedKeys: [],
                     aggregates: ["mozzarella": .init(price: 1.15, unit: "stk", count: 3, latest: fixedNow)])
        XCTAssertEqual(CommunityPriceService.apply(cache: cache, to: [item], storeName: "Rewe"), 1)
        XCTAssertEqual(item.priceSource, "community:Rewe")
    }

    // MARK: - Schema und Texte

    func testSchemaFieldsMatchPublishedExport() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/cloudkit/private-schema-aktuell.ckdb")
        let ckdb = try String(contentsOf: url, encoding: .utf8)
        guard let start = ckdb.range(of: "RECORD TYPE CommunityPrice (") else {
            return XCTFail("RECORD TYPE CommunityPrice fehlt in private-schema-aktuell.ckdb: Schema anlegen und vor dem TestFlight-Upload nach Production deployen (docs/testflight-setup.md)")
        }
        let rest = ckdb[start.upperBound...]
        let block = String(rest[..<(rest.range(of: ");")?.lowerBound ?? rest.endIndex)])
        for field in CommunityPriceSchema.fields {
            XCTAssertNotNil(block.range(of: "(?<![A-Za-z0-9_])\(field)(?![A-Za-z0-9_])", options: .regularExpression),
                            "Feld \(field) fehlt im veröffentlichten Schema")
        }
    }

    func testLocalizationKeysAreRegistered() {
        let keys = Set(PriceSourceDisplay.allLocalizationKeys)
        for key in ["price.source.community", "price.source.community.undated", "settings.community.share", "settings.community.footer",
                    "price.source.community.allchains", "price.source.community.allchains.undated",
                    "settings.community.notice.title", "settings.community.notice.message",
                    "settings.community.notice.share", "settings.community.notice.decline"] {
            XCTAssertTrue(keys.contains(key), key)
        }
    }

    // MARK: - Erst-Hinweis vor dem ersten Beitrag (Issue #186)

    private let shareable = CommunityPriceService.Contribution(itemName: "Mozzarella", storeName: "Rewe City",
                                                                perUnitPrice: 1.09, unit: "stk")

    /// U1, AC-1: Schalter an (Schlüssel fehlt = Standard an), Merker fehlt, ein teilbarer Beitrag → Hinweis fällig.
    func testNoticeDueWhenSwitchOnNoMarkerAndShareableContribution() {
        XCTAssertNil(defaults.object(forKey: CommunityPriceService.noticeShownKey))
        XCTAssertTrue(CommunityPriceService.noticeDue([shareable], in: defaults), "Standard an, Merker fehlt")
        defaults.set(true, forKey: CommunityPriceService.sharingEnabledKey)
        XCTAssertTrue(CommunityPriceService.noticeDue([shareable], in: defaults), "Schalter ausdrücklich an")
    }

    /// U2, AC-9: Schalter aus → kein Hinweis.
    func testNoticeNotDueWhenSwitchOff() {
        defaults.set(false, forKey: CommunityPriceService.sharingEnabledKey)
        XCTAssertFalse(CommunityPriceService.noticeDue([shareable], in: defaults))
    }

    /// U3, AC-5: nach einer Entscheidung (Merker gesetzt) kein zweiter Hinweis.
    func testNoticeNotDueWhenMarkerSet() {
        CommunityPriceService.recordNoticeDecision(share: true, in: defaults)
        XCTAssertFalse(CommunityPriceService.noticeDue([shareable], in: defaults))
    }

    /// U4, AC-10: Bon ohne teilbare Zeile → kein Hinweis.
    func testNoticeNotDueWithoutShareableContribution() {
        let unusable: [CommunityPriceService.Contribution] = [
            .init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 0, unit: "stk"),
            .init(itemName: "Mozzarella", storeName: "", perUnitPrice: 1.09, unit: "stk"),
            .init(itemName: "", storeName: "Rewe City", perUnitPrice: 1.09, unit: "stk"),
            .init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: "  "),
        ]
        XCTAssertFalse(CommunityPriceService.noticeDue(unusable, in: defaults))
        XCTAssertFalse(CommunityPriceService.noticeDue([], in: defaults))
        XCTAssertTrue(CommunityPriceService.noticeDue(unusable + [shareable], in: defaults),
                      "ein teilbarer Beitrag genügt")
    }

    /// U5, AC-10/AC-12: `isShareable` entscheidet wie die Guards von `contribute`.
    func testIsShareableMatchesContributeGuards() async {
        let cases: [CommunityPriceService.Contribution] = [
            shareable,
            .init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 0, unit: "stk"),
            .init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: -1, unit: "stk"),
            .init(itemName: "Mozzarella", storeName: "", perUnitPrice: 1.09, unit: "stk"),
            .init(itemName: "", storeName: "Rewe City", perUnitPrice: 1.09, unit: "stk"),
            .init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: " "),
            .init(itemName: "Hackfleisch", storeName: "Lidl", perUnitPrice: 0.012, unit: "g"),
        ]
        for contribution in cases {
            let fake = FakeCommunityPriceDatabase()
            let service = makeService(fake, sharing: true)
            let sent = await service.contribute(contribution)
            XCTAssertEqual(contribution.isShareable, sent, "\(contribution)")
        }
        // Zweite Sicherung bleibt: mit Schalter aus sendet `contribute` auch Teilbares nicht.
        let fake = FakeCommunityPriceDatabase()
        let off = makeService(fake, sharing: false)
        let sent = await off.contribute(shareable)
        XCTAssertFalse(sent)
        XCTAssertTrue(fake.saved.isEmpty)
    }

    /// U6, AC-2: „Weiter teilen“ setzt den Merker und lässt den Schalter-Schlüssel unberührt.
    func testRecordDecisionShareKeepsSwitchAndSetsMarker() {
        CommunityPriceService.recordNoticeDecision(share: true, in: defaults)
        XCTAssertEqual(defaults.object(forKey: CommunityPriceService.noticeShownKey) as? Bool, true)
        XCTAssertNil(defaults.object(forKey: CommunityPriceService.sharingEnabledKey), "Schalter-Schlüssel unberührt")
        XCTAssertTrue(CommunityPriceService.isSharingEnabled(in: defaults))
    }

    /// U7, AC-3: „Nicht teilen“ setzt den Merker und schreibt den Schalter ausdrücklich auf aus.
    func testRecordDecisionDeclineTurnsSwitchOffAndSetsMarker() {
        CommunityPriceService.recordNoticeDecision(share: false, in: defaults)
        XCTAssertEqual(defaults.object(forKey: CommunityPriceService.noticeShownKey) as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: CommunityPriceService.sharingEnabledKey) as? Bool, false,
                       "ausdrücklich false, damit @AppStorage in den Einstellungen sofort aus zeigt")
        XCTAssertFalse(CommunityPriceService.isSharingEnabled(in: defaults))
    }

    /// U8, AC-3: Nach „Nicht teilen“ verlässt kein gesammelter Beitrag das Gerät, auch nicht der auslösende.
    func testDeclinedContributionsAreNotSentToDatabase() async {
        let fake = FakeCommunityPriceDatabase()
        let service = CommunityPriceService(database: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
        let pending = [shareable, .init(itemName: "Butter", storeName: "Rewe City", perUnitPrice: 1.99, unit: "stk")]
        XCTAssertTrue(CommunityPriceService.noticeDue(pending, in: defaults))

        CommunityPriceService.recordNoticeDecision(share: false, in: defaults)
        let sent = await service.contribute(pending)

        XCTAssertEqual(sent, 0)
        XCTAssertTrue(fake.saved.isEmpty, "nach „Nicht teilen“ bleibt die Datenbank leer")
        XCTAssertEqual(fake.saveAttempts, 0)
    }

    /// U9, AC-2/AC-7: Nach „Weiter teilen“ geht jeder teilbare Beitrag genau einmal raus, Unbrauchbares nie.
    func testAcceptedContributionsAreSentAfterDecision() async {
        let fake = FakeCommunityPriceDatabase()
        let service = CommunityPriceService(database: fake, defaults: defaults, cache: cache, now: { self.fixedNow })
        let pending: [CommunityPriceService.Contribution] = [
            shareable,
            .init(itemName: "Butter", storeName: "Rewe City", perUnitPrice: 1.99, unit: "stk"),
            .init(itemName: "Pfand", storeName: "Rewe City", perUnitPrice: 0, unit: "stk"),
        ]
        XCTAssertTrue(CommunityPriceService.noticeDue(pending, in: defaults))

        CommunityPriceService.recordNoticeDecision(share: true, in: defaults)
        let sent = await service.contribute(pending)

        XCTAssertEqual(sent, 2)
        XCTAssertEqual(fake.saveAttempts, 2, "jeder teilbare Beitrag genau einmal")
        XCTAssertEqual(Set(fake.saved.compactMap { $0[CommunityPriceSchema.itemKey] as? String }), ["mozzarella", "butter"])
        XCTAssertFalse(CommunityPriceService.noticeDue(pending, in: defaults), "kein zweiter Hinweis")
    }

    /// U10, AC-9: Bei ausgeschaltetem Schalter bleibt der Merker unberührt (späteres Einschalten fragt noch).
    func testSwitchOffLeavesMarkerUntouched() {
        defaults.set(false, forKey: CommunityPriceService.sharingEnabledKey)
        XCTAssertFalse(CommunityPriceService.noticeDue([shareable], in: defaults))
        XCTAssertNil(defaults.object(forKey: CommunityPriceService.noticeShownKey))
        defaults.set(true, forKey: CommunityPriceService.sharingEnabledKey)
        XCTAssertTrue(CommunityPriceService.noticeDue([shareable], in: defaults))
    }

    /// U11, AC-8/AC-11: „Preis eintragen“ liefert den Beitrag, statt ihn zu senden; dieselbe Regel wie beim Bon.
    func testActualPriceEntryCollectsContributionInsteadOfSending() throws {
        let store = Store(name: "Rewe City", emoji: "🛒", colorHex: "#123456")
        let item = ShoppingItem(name: "Mozzarella", store: store)
        ActualPriceEntryView.apply(itemActualTotal: 1.09, to: item, in: store)

        let contribution = try XCTUnwrap(ActualPriceEntryView.contribution(for: item, in: store))
        XCTAssertEqual(contribution.itemName, "Mozzarella")
        XCTAssertEqual(contribution.storeName, "Rewe City")
        XCTAssertEqual(contribution.perUnitPrice, try XCTUnwrap(item.estimatedPrice), accuracy: 0.000001)
        XCTAssertEqual(contribution.unit, ShoppingItem.unitBucket(item.unit))
        XCTAssertTrue(CommunityPriceService.noticeDue([contribution], in: defaults))

        let unpriced = ShoppingItem(name: "Butter", store: store)
        unpriced.estimatedPrice = 0
        XCTAssertNil(ActualPriceEntryView.contribution(for: unpriced, in: store), "Preis 0 ist kein Beitrag")
    }

    // MARK: - Nacharbeiten (Issue #208)

    private func footerTexts() throws -> [String: String] {
        var result: [String: String] = [:]
        for loc in ["de", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                                    subdirectory: nil, localization: loc))
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            result[loc] = try XCTUnwrap(table["settings.community.footer"], "Schlüssel fehlt in \(loc)")
        }
        return result
    }

    /// U1, AC-1: Die Fußnote beginnt nicht mehr mit dem Satz „Voreingestellt an.“ und nennt „Community“.
    func testFooterDoesNotStartWithDefaultOnSentence() throws {
        let texts = try footerTexts()
        XCTAssertFalse(texts["de"]!.hasPrefix("Voreingestellt an."))
        XCTAssertFalse(texts["en"]!.hasPrefix("On by default."))
        XCTAssertTrue(texts["de"]!.contains("Community"))
        XCTAssertTrue(texts["en"]!.contains("Community"))
    }

    /// U2, AC-2: Es gibt nur diesen einen Fußnoten-Schlüssel, keinen zweiten je Schalterstand.
    func testFooterIsSameTextRegardlessOfSwitch() throws {
        for loc in ["de", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                                    subdirectory: nil, localization: loc))
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
            let footerKeys = table.keys.filter { $0.hasPrefix("settings.community.footer") }
            XCTAssertEqual(footerKeys, ["settings.community.footer"], "\(loc): genau ein Fußnoten-Schlüssel")
        }
    }

    /// U3, AC-4: Mit dem Argument wählt die Auswahl die Ersatz-Datenbank.
    func testDefaultDatabaseWithDiscardArgumentIsDiscarding() {
        let db = CommunityPriceService.defaultDatabase(arguments: ["Restock", "-discardCommunityPricesForUITests"])
        XCTAssertTrue(db is DiscardingCommunityPriceDatabase)
    }

    /// U4, AC-4: Ohne oder mit unbekanntem Argument bleibt es die Produktionsdatenbank.
    func testDefaultDatabaseWithoutOrUnknownArgumentIsCloudKit() {
        XCTAssertFalse(CommunityPriceService.defaultDatabase(arguments: ["Restock"]) is DiscardingCommunityPriceDatabase)
        XCTAssertFalse(CommunityPriceService.defaultDatabase(arguments: ["Restock", "-discardSomethingElse"]) is DiscardingCommunityPriceDatabase)
    }

    private func clearDiscardCount() {
        UserDefaults.standard.removeObject(forKey: DiscardingCommunityPriceDatabase.countKey)
    }

    /// U5, AC-5: Die Ersatz-Datenbank verwirft, gibt den Record zurück und zählt.
    func testDiscardingDatabaseCountsAndDiscards() async throws {
        clearDiscardCount()
        defer { clearDiscardCount() }
        let db = DiscardingCommunityPriceDatabase()
        let record = CKRecord(recordType: "CommunityPrice", recordID: CKRecord.ID(recordName: "UT-208"))
        let first = try await db.save(record)
        let second = try await db.save(record)
        XCTAssertEqual(first.recordID, record.recordID)
        XCTAssertEqual(second.recordID, record.recordID)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: DiscardingCommunityPriceDatabase.countKey), 2)
        let own = try await db.fetchCommunityRecords(chain: "rewe", itemKeys: ["mozzarella"], resultsLimit: 10)
        let all = try await db.fetchCommunityRecordsAllChains(itemKeys: ["mozzarella"], resultsLimit: 10)
        XCTAssertTrue(own.isEmpty)
        XCTAssertTrue(all.isEmpty)
    }

    /// U6, AC-6: Ein Beitrag über den Dienst mit Ersatz-Datenbank zählt und erreicht keine Fake-Produktion.
    func testContributionThroughDiscardingServiceNeverReachesFakeAndCounts() async {
        clearDiscardCount()
        defer { clearDiscardCount() }
        let fake = FakeCommunityPriceDatabase()
        defaults.set(true, forKey: CommunityPriceService.sharingEnabledKey)
        let service = CommunityPriceService(database: DiscardingCommunityPriceDatabase(), defaults: defaults,
                                            cache: cache, now: { self.fixedNow })
        let ok = await service.contribute(.init(itemName: "Mozzarella", storeName: "Rewe City", perUnitPrice: 1.09, unit: "stk"))
        XCTAssertTrue(ok)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: DiscardingCommunityPriceDatabase.countKey), 1)
        XCTAssertTrue(fake.saved.isEmpty)
    }
}

// MARK: - Fake

final class FakeCommunityPriceDatabase: CommunityPriceDatabase, @unchecked Sendable {
    private let lock = NSLock()
    var stored: [CKRecord.ID: CKRecord] = [:]
    var saved: [CKRecord] = []
    var saveAttempts = 0
    var saveError: Error?
    var fetchError: Error?
    var failFirstSaveWithServerRecordChanged = false
    var lastQuery: (chain: String, itemKeys: [String])?
    /// Artikelschlüssel jeder kettenübergreifenden Abfrage (PO 2026-10-22), in Aufrufreihenfolge.
    var allChainsQueries: [[String]] = []
    var allChainsFetchError: Error?

    func add(itemKey: String, chain: String, price: Double, unit: String, observedAt: Date, client: String) {
        let record = CKRecord(recordType: CommunityPriceSchema.recordType,
                              recordID: CKRecord.ID(recordName: CommunityPriceSchema.recordName(clientID: client, chain: chain, itemKey: itemKey)))
        CommunityPriceSchema.fill(record, itemKey: itemKey, chain: chain, price: price, unit: unit, observedAt: observedAt, clientID: client)
        stored[record.recordID] = record
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        lock.lock(); defer { lock.unlock() }
        saveAttempts += 1
        if let saveError { throw saveError }
        if failFirstSaveWithServerRecordChanged, let server = stored[record.recordID] {
            failFirstSaveWithServerRecordChanged = false
            throw CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
        }
        saved.append(record)
        stored[record.recordID] = record
        return record
    }

    func fetchCommunityRecords(chain: String, itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord] {
        lock.lock(); defer { lock.unlock() }
        lastQuery = (chain, itemKeys)
        if let fetchError { throw fetchError }
        return stored.values.filter {
            ($0[CommunityPriceSchema.chain] as? String) == chain
                && itemKeys.contains(($0[CommunityPriceSchema.itemKey] as? String) ?? "")
        }
    }

    func fetchCommunityRecordsAllChains(itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord] {
        lock.lock(); defer { lock.unlock() }
        allChainsQueries.append(itemKeys)
        if let allChainsFetchError { throw allChainsFetchError }
        let matching = stored.values
            .filter { itemKeys.contains(($0[CommunityPriceSchema.itemKey] as? String) ?? "") }
            .sorted { (($0[CommunityPriceSchema.observedAt] as? Date) ?? .distantPast) > (($1[CommunityPriceSchema.observedAt] as? Date) ?? .distantPast) }
        return Array(matching.prefix(resultsLimit))
    }
}
