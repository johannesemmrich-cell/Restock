import XCTest
@testable import Restock

/// Issue #184: Beitrag an Open Prices (Weg B) bis Pre-Production — Plan (P1–P5), Bereitschaft (B1),
/// Dienst mit Fake-API (S1–S5), Client-Körper (C1–C3), Filialspeicher und Nominatim (L1–L2), Texte.
/// Kein echter Netzaufruf; der Nachweis gegen Pre-Production steht in der Spec.
final class OpenPricesContributionTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 UTC
    private let rewe = OpenPricesLocation(osmID: 123_456_789, osmType: "NODE", displayName: "REWE, Hammer Straße, Münster")
    private let image = Data(repeating: 0xFF, count: 64)

    override func setUp() {
        super.setUp()
        suiteName = "UT-openprices-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func line(_ name: String, _ price: Double, quantity: Double = 1, weight: Double? = nil) -> OpenPricesContribution.Line {
        .init(name: name, price: price, quantity: quantity, weightBasis: weight)
    }

    private func service(_ api: FakeOpenPricesAPI, tokens: InMemoryTokenStore, enabled: Bool,
                         available: Bool = true) -> OpenPricesContributionService {
        defaults.set(enabled, forKey: OpenPricesContribution.enabledKey)
        return OpenPricesContributionService(api: api, tokens: tokens, defaults: defaults,
                                             locations: OpenPricesLocationStore(defaults: defaults), now: { self.fixedNow },
                                             available: available)
    }

    // MARK: - Plan

    /// P1: Zeilen mit Katalog-Kategorie werden Preise je Stück, Gewichtszeilen je Kilogramm; der Rest wird übersprungen.
    func testPlanMapsCategoriesAndPricePer() throws {
        let plan = try XCTUnwrap(OpenPricesContribution.plan(
            lines: [line("Milch", 1.19), line("Bananen", 1.38, weight: 1_150), line("Mozzarella", 2.18, quantity: 2),
                    line("Zahnbürste", 2.99), line("Qwertz", 1.00)],
            imageData: image, date: fixedNow, location: rewe))
        XCTAssertEqual(plan.prices.map(\.categoryTag), ["en:milks", "en:bananas", "en:mozzarella"])
        XCTAssertEqual(plan.prices[0].price, 1.19); XCTAssertEqual(plan.prices[0].pricePer, "UNIT")
        XCTAssertEqual(plan.prices[1].price, 1.2, accuracy: 0.0001); XCTAssertEqual(plan.prices[1].pricePer, "KILOGRAM")
        XCTAssertEqual(plan.prices[2].price, 1.09, accuracy: 0.0001); XCTAssertEqual(plan.prices[2].pricePer, "UNIT")
        XCTAssertEqual(plan.skipped, ["Zahnbürste", "Qwertz"], "Non-Food ohne Tag und Unbekanntes werden übersprungen")
        XCTAssertEqual(plan.proof.priceCount, 3)
        XCTAssertEqual(try XCTUnwrap(plan.proof.priceTotal), 1.19 + 1.38 + 2.18 + 2.99 + 1.00, accuracy: 0.0001)
        XCTAssertEqual(plan.proof.location, rewe)
        XCTAssertEqual(plan.proof.mimeType, "image/jpeg")
        XCTAssertTrue(plan.prices.allSatisfy { $0.proofID == nil && $0.currency == "EUR" && $0.location == rewe })
    }

    /// P2: Ohne beitragbare Zeile kein Plan — und damit auch kein Foto-Upload.
    func testPlanIsNilWithoutContributableLine() {
        XCTAssertNil(OpenPricesContribution.plan(lines: [line("Qwertz", 1), line("Milch", 0)], imageData: image, date: fixedNow, location: rewe))
    }

    /// P3: Datum als JJJJ-MM-TT.
    func testDateString() {
        let string = OpenPricesContribution.dateString(fixedNow)
        XCTAssertNotNil(string.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression), string)
        XCTAssertTrue(string.hasPrefix("2027-01-1"), string)
    }

    /// P4: Preis je Einheit rundet auf Cent; Menge 0 zählt als 1.
    func testPricePer() {
        XCTAssertEqual(OpenPricesContribution.pricePer(line("x", 3.33, quantity: 3))?.price, 1.11)
        XCTAssertEqual(OpenPricesContribution.pricePer(line("x", 2.00, quantity: 0))?.price, 2.00)
        XCTAssertEqual(OpenPricesContribution.pricePer(line("x", 0.69, weight: 230))?.price, 3.0)
        XCTAssertNil(OpenPricesContribution.pricePer(line("x", -1)))
    }

    /// P5: Der Preiskörper trägt die Feldnamen der API und die `proof_id` erst nach dem Setzen.
    func testPriceBodyFieldNames() {
        var price = OpenPricesPriceUpload(itemName: "Milch", categoryTag: "en:milks", price: 1.19, pricePer: "UNIT", currency: "EUR",
                                          location: rewe, date: "2027-01-15", proofID: nil)
        XCTAssertNil(price.body["proof_id"])
        price.proofID = 42
        let body = price.body
        XCTAssertEqual(body["category_tag"] as? String, "en:milks")
        XCTAssertEqual(body["price_per"] as? String, "UNIT")
        XCTAssertEqual(body["location_osm_id"] as? Int64, 123_456_789)
        XCTAssertEqual(body["location_osm_type"] as? String, "NODE")
        XCTAssertEqual(body["proof_id"] as? Int, 42)
        XCTAssertEqual(body["date"] as? String, "2027-01-15")
        XCTAssertNil(body["product_code"])
    }

    // MARK: - Bereitschaft

    /// B1: Reihenfolge der Gründe: Schalter, Anmeldung, Filiale, Foto.
    func testReadinessOrder() {
        typealias R = OpenPricesContribution
        XCTAssertEqual(R.readiness(enabled: false, loggedIn: true, location: rewe, hasImage: true), .disabled)
        XCTAssertEqual(R.readiness(enabled: true, loggedIn: false, location: rewe, hasImage: true), .notLoggedIn)
        XCTAssertEqual(R.readiness(enabled: true, loggedIn: true, location: nil, hasImage: true), .noLocation)
        XCTAssertEqual(R.readiness(enabled: true, loggedIn: true, location: rewe, hasImage: false), .noImage)
        XCTAssertEqual(R.readiness(enabled: true, loggedIn: true, location: rewe, hasImage: true), .ready)
        XCTAssertFalse(OpenPricesContribution.isEnabled(in: defaults), "Opt-in: Standard aus")
        XCTAssertEqual(OpenPricesContribution.environment, .preProduction, "bis zum Nachweis nur Pre-Production")
    }

    // MARK: - Dienst

    /// S1: Anmeldung legt Token und Nutzername ab; Abmelden entfernt beides.
    func testLoginStoresTokenAndLogoutClears() async throws {
        let api = FakeOpenPricesAPI(); let tokens = InMemoryTokenStore()
        let svc = service(api, tokens: tokens, enabled: true)
        let before = await svc.isLoggedIn
        XCTAssertFalse(before)
        try await svc.login(username: "henning", password: "geheim")
        XCTAssertEqual(tokens.token(), "token-henning")
        let name = await svc.username
        XCTAssertEqual(name, "henning")
        let after = await svc.isLoggedIn
        XCTAssertTrue(after)
        XCTAssertEqual(api.authCalls, [("henning", "geheim")].map { "\($0.0)|\($0.1)" })
        await svc.logout()
        XCTAssertNil(tokens.token())
        let cleared = await svc.username
        XCTAssertNil(cleared)
    }

    /// S2: Nachweis zuerst, dann jeder Preis mit `proof_id`; Ergebnis gespeichert.
    @MainActor
    func testContributeUploadsProofThenPrices() async throws {
        let api = FakeOpenPricesAPI(); api.proofID = 777
        let svc = service(api, tokens: InMemoryTokenStore("t"), enabled: true)
        let plan = try XCTUnwrap(OpenPricesContribution.plan(lines: [line("Milch", 1.19), line("Butter", 2.29), line("Qwertz", 1)],
                                                             imageData: image, date: fixedNow, location: rewe))
        let result = await svc.contribute(plan)
        XCTAssertEqual(api.events, ["proof", "price", "price"])
        XCTAssertEqual(api.prices.map(\.proofID), [777, 777])
        XCTAssertEqual(api.proofs.first?.priceCount, 2)
        XCTAssertEqual(api.tokensUsed, ["t", "t", "t"])
        XCTAssertEqual(result, OpenPricesLastResult(date: fixedNow, sent: 2, skipped: 1, failed: 0, proofUploaded: true, message: "ok"))
        let stored = await svc.lastResult()
        XCTAssertEqual(stored, result)
    }

    /// S3: Scheitert der Nachweis, geht kein Preis hinaus.
    func testProofFailureSendsNoPrices() async throws {
        let api = FakeOpenPricesAPI(); api.proofError = OpenPricesAPIError.badStatus(401, "Not authenticated")
        let svc = service(api, tokens: InMemoryTokenStore("t"), enabled: true)
        let plan = try XCTUnwrap(OpenPricesContribution.plan(lines: [line("Milch", 1.19)], imageData: image, date: fixedNow, location: rewe))
        let result = await svc.contribute(plan)
        XCTAssertEqual(api.events, ["proof"])
        XCTAssertEqual(result.sent, 0); XCTAssertEqual(result.failed, 1); XCTAssertFalse(result.proofUploaded)
        XCTAssertTrue(result.message.contains("401"), result.message)
    }

    /// S4: Ein abgelehnter Preis zählt als fehlgeschlagen, die anderen gehen weiter.
    func testPriceFailureIsCountedAndOthersContinue() async throws {
        let api = FakeOpenPricesAPI(); api.failPriceTags = ["en:butters"]
        let svc = service(api, tokens: InMemoryTokenStore("t"), enabled: true)
        let plan = try XCTUnwrap(OpenPricesContribution.plan(lines: [line("Milch", 1.19), line("Butter", 2.29), line("Eier", 2.99)],
                                                             imageData: image, date: fixedNow, location: rewe))
        let result = await svc.contribute(plan)
        XCTAssertEqual(result.sent, 2); XCTAssertEqual(result.failed, 1)
        XCTAssertTrue(result.message.contains("400"), result.message)
    }

    /// S5: Schalter aus oder kein Token → nichts geht hinaus (auch nicht im Hintergrundaufruf ohne Filiale).
    func testDisabledOrLoggedOutSendsNothing() async throws {
        let api = FakeOpenPricesAPI()
        let plan = try XCTUnwrap(OpenPricesContribution.plan(lines: [line("Milch", 1.19)], imageData: image, date: fixedNow, location: rewe))
        _ = await service(api, tokens: InMemoryTokenStore("t"), enabled: false).contribute(plan)
        _ = await service(api, tokens: InMemoryTokenStore(nil), enabled: true).contribute(plan)
        XCTAssertEqual(api.events, [])

        let svc = service(api, tokens: InMemoryTokenStore("t"), enabled: true)
        let storeID = UUID()
        let noLocation = await svc.readiness(for: storeID, hasImage: true)
        XCTAssertEqual(noLocation, .noLocation)
        let nothing = await svc.contribute(lines: [line("Milch", 1.19)], imageData: image, storeID: storeID, date: fixedNow)
        XCTAssertNil(nothing)
        XCTAssertEqual(api.events, [], "ohne Filiale kein Upload")
        OpenPricesLocationStore(defaults: defaults).set(rewe, for: storeID)
        let ready = await svc.readiness(for: storeID, hasImage: true)
        XCTAssertEqual(ready, .ready)
        let noImage = await svc.readiness(for: storeID, hasImage: false)
        XCTAssertEqual(noImage, .noImage)
        let sent = await svc.contribute(lines: [line("Milch", 1.19)], imageData: image, storeID: storeID, date: fixedNow)
        XCTAssertEqual(sent?.sent, 1)
        XCTAssertEqual(api.events, ["proof", "price"])
    }

    // MARK: - In 1.0 ausgeblendet (Issue #244)

    /// T1: Für 1.0 ist Open Prices nicht verfügbar.
    func testOpenPricesIsUnavailableInRelease1_0() {
        XCTAssertFalse(OpenPricesContribution.isAvailable)
    }

    /// T2: Ohne Verfügbarkeit wird nie gesendet, auch wenn Schalter, Anmeldung, Filiale und Foto bereit sind.
    func testUnavailableServiceNeverSends() async {
        let api = FakeOpenPricesAPI()
        let svc = service(api, tokens: InMemoryTokenStore("t"), enabled: true, available: false)
        let storeID = UUID()
        OpenPricesLocationStore(defaults: defaults).set(rewe, for: storeID)
        let result = await svc.contribute(lines: [line("Milch", 1.19)], imageData: image, storeID: storeID, date: fixedNow)
        XCTAssertNil(result)
        XCTAssertEqual(api.events, [], "kein Foto-Upload, kein Preis")
        XCTAssertEqual(api.authCalls, [])
        let last = await svc.lastResult()
        XCTAssertNil(last)
    }

    /// T3: Bereitschaft ist ohne Verfügbarkeit `.disabled`, mit Verfügbarkeit bei gleichen Eingaben `.ready`.
    func testReadinessIsDisabledWhenUnavailable() async {
        let storeID = UUID()
        OpenPricesLocationStore(defaults: defaults).set(rewe, for: storeID)
        let locked = service(FakeOpenPricesAPI(), tokens: InMemoryTokenStore("t"), enabled: true, available: false)
        let lockedReadiness = await locked.readiness(for: storeID, hasImage: true)
        XCTAssertEqual(lockedReadiness, .disabled)
        let open = service(FakeOpenPricesAPI(), tokens: InMemoryTokenStore("t"), enabled: true, available: true)
        let openReadiness = await open.readiness(for: storeID, hasImage: true)
        XCTAssertEqual(openReadiness, .ready)
    }

    /// T4: Der Dienst der App ist gesperrt, unabhängig vom gespeicherten Schalter.
    func testSharedServiceIsUnavailable() async {
        let readiness = await OpenPricesContributionService.shared.readiness(for: UUID(), hasImage: true)
        XCTAssertEqual(readiness, .disabled)
        let available = await OpenPricesContributionService.shared.available
        XCTAssertFalse(available)
    }

    // MARK: - Client-Körper

    /// C1: Multipart trägt Datei, Typ RECEIPT, Ort, Datum, Währung, Zahl und Summe.
    func testMultipartBody() throws {
        let proof = OpenPricesProofUpload(imageData: Data("JPEG".utf8), fileName: "r.jpg", mimeType: "image/jpeg", date: "2027-01-15",
                                          currency: "EUR", location: rewe, priceCount: 3, priceTotal: 12.5)
        let body = String(decoding: OpenPricesClient.multipartBody(proof, boundary: "B"), as: UTF8.self)
        for expected in ["--B\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\nRECEIPT\r\n",
                         "name=\"location_osm_id\"\r\n\r\n123456789\r\n", "name=\"location_osm_type\"\r\n\r\nNODE\r\n",
                         "name=\"date\"\r\n\r\n2027-01-15\r\n", "name=\"currency\"\r\n\r\nEUR\r\n",
                         "name=\"receipt_price_count\"\r\n\r\n3\r\n", "name=\"receipt_price_total\"\r\n\r\n12.50\r\n",
                         "name=\"file\"; filename=\"r.jpg\"\r\nContent-Type: image/jpeg\r\n\r\nJPEG\r\n", "--B--\r\n"] {
            XCTAssertTrue(body.contains(expected), expected)
        }
    }

    /// C2: Formular-Körper der Anmeldung ist URL-kodiert.
    func testFormBody() {
        let body = String(decoding: OpenPricesClient.formBody(["username": "a b", "password": "p&=+ß"]), as: UTF8.self)
        XCTAssertEqual(body, "password=p%26%3D%2B%C3%9F&username=a%20b")
    }

    /// C3: Jede URL trägt app_name und app_version; Pre-Production hat den eigenen Host.
    func testURLsCarryAppName() {
        let client = OpenPricesClient(environment: .preProduction)
        let url = client.url("prices").absoluteString
        XCTAssertTrue(url.hasPrefix("https://prices.openfoodfacts.net/api/v1/prices?"), url)
        XCTAssertTrue(url.contains("app_name=Restock"), url)
        XCTAssertTrue(OpenPricesClient(environment: .production).url("auth").absoluteString.hasPrefix("https://prices.openfoodfacts.org/api/v1/auth?"))
    }

    // MARK: - Filiale

    /// L1: Filiale je Laden wird gespeichert, ersetzt und entfernt.
    func testLocationStoreRoundTrip() {
        let store = OpenPricesLocationStore(defaults: defaults)
        let id = UUID()
        XCTAssertNil(store.location(for: id))
        store.set(rewe, for: id)
        XCTAssertEqual(store.location(for: id), rewe)
        store.set(nil, for: id)
        XCTAssertNil(store.location(for: id))
    }

    /// L2: Nominatim-Antwort → Orte mit großgeschriebenem OSM-Typ; kaputte Einträge fallen weg.
    func testNominatimParse() {
        let json = """
        [{"osm_type":"node","osm_id":123456789,"display_name":"REWE, Hammer Straße, Münster"},
         {"osm_type":"way","osm_id":987654321012,"display_name":"Lidl, Köln"},
         {"display_name":"ohne Typ"}]
        """
        let places = NominatimClient.parse(Data(json.utf8))
        XCTAssertEqual(places, [OpenPricesLocation(osmID: 123_456_789, osmType: "NODE", displayName: "REWE, Hammer Straße, Münster"),
                                OpenPricesLocation(osmID: 987_654_321_012, osmType: "WAY", displayName: "Lidl, Köln")])
        XCTAssertEqual(NominatimClient.parse(Data("nicht json".utf8)), [])
    }

    func testLocalizationKeysAreRegistered() {
        let keys = Set(PriceSourceDisplay.allLocalizationKeys)
        for key in OpenPricesContribution.allLocalizationKeys { XCTAssertTrue(keys.contains(key), key) }
    }

    /// Katalog: Lebensmittel tragen eine OFF-Kategorie, Non-Food nicht (Issue #184).
    func testCatalogCarriesOffCategoriesForFoodOnly() throws {
        XCTAssertEqual(try XCTUnwrap(PriceCatalog.match("Milch")).offCategory, "en:milks")
        XCTAssertEqual(try XCTUnwrap(PriceCatalog.match("Bananen")).offCategory, "en:bananas")
        XCTAssertNil(try XCTUnwrap(PriceCatalog.match("Zahnbürste")).offCategory)
        let tagged = PriceCatalog.entries.filter { $0.offCategory != nil }
        XCTAssertGreaterThanOrEqual(tagged.count, 150)
        for entry in tagged {
            XCTAssertNotNil(entry.offCategory!.range(of: #"^[a-z]{2}:[a-z0-9-]+$"#, options: .regularExpression), entry.offCategory!)
        }
    }
}

// MARK: - Fake-API

final class FakeOpenPricesAPI: OpenPricesAPI, @unchecked Sendable {
    private let lock = NSLock()
    var proofID = 1
    var proofError: Error?
    var failPriceTags: Set<String> = []
    private(set) var events: [String] = []
    private(set) var authCalls: [String] = []
    private(set) var proofs: [OpenPricesProofUpload] = []
    private(set) var prices: [OpenPricesPriceUpload] = []
    private(set) var tokensUsed: [String] = []

    func authenticate(username: String, password: String) async throws -> String {
        lock.lock(); defer { lock.unlock() }
        authCalls.append("\(username)|\(password)")
        return "token-\(username)"
    }

    func uploadProof(_ proof: OpenPricesProofUpload, token: String) async throws -> Int {
        lock.lock(); defer { lock.unlock() }
        events.append("proof"); tokensUsed.append(token)
        if let proofError { throw proofError }
        proofs.append(proof)
        return proofID
    }

    func createPrice(_ price: OpenPricesPriceUpload, token: String) async throws {
        lock.lock(); defer { lock.unlock() }
        events.append("price"); tokensUsed.append(token)
        if failPriceTags.contains(price.categoryTag) { throw OpenPricesAPIError.badStatus(400, "invalid") }
        prices.append(price)
    }
}
