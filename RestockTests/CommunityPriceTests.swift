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
        for key in ["price.source.community", "price.source.community.undated", "settings.community.share", "settings.community.footer"] {
            XCTAssertTrue(keys.contains(key), key)
        }
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
}
