import Foundation
import Security
import os

// Issue #184 (Weg B aus #163): Preise, die Restock beim Bon-Scan ohnehin erkennt, zusätzlich an
// Open Prices (Open Food Facts, prices.openfoodfacts.org) beitragen — damit sie allen helfen, nicht nur
// Restock-Nutzern. Open Prices verlangt (Projekt-Doku, Stand 2026-10-20): ein Open-Food-Facts-Konto
// (Bearer-Token), einen Nachweis (hier das Bonfoto, Typ RECEIPT, Lizenz CC BY-SA, also öffentlich),
// eine Filiale als OpenStreetMap-Ort und je Preis Barcode ODER OFF-Kategorie (dann `price_per`).
// Deshalb: eigener Opt-in-Schalter (Standard aus, Hinweis beim Einschalten), Anmeldung in den
// Einstellungen (Token im Schlüsselbund), Filiale je Laden aus einer Nominatim-Suche, und je Bonzeile
// die OFF-Kategorie aus dem Katalog (`PriceCatalogEntry.offCategory`); Zeilen ohne Kategorie werden
// übersprungen. Reihenfolge (Issue): erst gegen die Pre-Production-Umgebung, dann Production.
//
// Die API-Form (Pfade, Felder) stammt aus dem Repo `openfoodfacts/open-prices`; sie ist gegen die
// Pre-Production-Umgebung zu belegen, bevor `environment` auf `.production` wechselt — die Aufrufe
// dafür stehen in `docs/specs/services/open-prices-contribution.md`.

enum OpenPricesEnvironment: String, Sendable {
    case preProduction
    case production

    var baseURL: URL {
        switch self {
        case .preProduction: return URL(string: "https://prices.openfoodfacts.net/api/v1")!
        case .production: return URL(string: "https://prices.openfoodfacts.org/api/v1")!
        }
    }

    var displayName: String {
        self == .preProduction ? "Pre-Production (Test)" : "Production"
    }
}

/// Filiale als OpenStreetMap-Ort, wie Open Prices sie verlangt (`location_osm_id`/`location_osm_type`).
struct OpenPricesLocation: Codable, Equatable, Sendable, Identifiable {
    let osmID: Int64
    /// `NODE`, `WAY` oder `RELATION` (Großschreibung wie die Open-Prices-API).
    let osmType: String
    let displayName: String

    var id: String { "\(osmType)/\(osmID)" }
}

/// Nachweis-Upload: das Bonfoto mit Ort, Datum und Währung.
struct OpenPricesProofUpload: Equatable, Sendable {
    let imageData: Data
    let fileName: String
    let mimeType: String
    /// `JJJJ-MM-TT`
    let date: String
    let currency: String
    let location: OpenPricesLocation
    let priceCount: Int
    let priceTotal: Double?
}

/// Ein Preis je Bonzeile ohne Barcode: OFF-Kategorie plus Preis je Stück oder je Kilogramm.
struct OpenPricesPriceUpload: Equatable, Sendable {
    let itemName: String
    let categoryTag: String
    let price: Double
    /// `UNIT` oder `KILOGRAM`
    let pricePer: String
    let currency: String
    let location: OpenPricesLocation
    let date: String
    var proofID: Int?

    /// JSON für `POST /prices` (Feldnamen der Open-Prices-API).
    var body: [String: Any] {
        var dict: [String: Any] = [
            "category_tag": categoryTag,
            "price": price,
            "price_per": pricePer,
            "currency": currency,
            "location_osm_id": location.osmID,
            "location_osm_type": location.osmType,
            "date": date,
        ]
        if let proofID { dict["proof_id"] = proofID }
        return dict
    }
}

/// Naht vor dem Netz, damit `OpenPricesContributionTests` mit einem Fake laufen.
protocol OpenPricesAPI: Sendable {
    func authenticate(username: String, password: String) async throws -> String
    /// Liefert die `id` des angelegten Nachweises.
    func uploadProof(_ proof: OpenPricesProofUpload, token: String) async throws -> Int
    func createPrice(_ price: OpenPricesPriceUpload, token: String) async throws
}

enum OpenPricesAPIError: Error, Equatable {
    case badStatus(Int, String)
    case malformedResponse
}

/// Echter Client (URLSession). Alle Aufrufe tragen `app_name`/`app_version` als Abfrageparameter,
/// wie Open Prices es für Beiträge aus Apps wünscht.
struct OpenPricesClient: OpenPricesAPI {
    let environment: OpenPricesEnvironment
    let session: URLSession

    init(environment: OpenPricesEnvironment, session: URLSession = .shared) {
        self.environment = environment
        self.session = session
    }

    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }

    func url(_ path: String) -> URL {
        var components = URLComponents(url: environment.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "app_name", value: OpenPricesContribution.appName),
                                 URLQueryItem(name: "app_version", value: Self.appVersion)]
        return components.url!
    }

    func authenticate(username: String, password: String) async throws -> String {
        var request = URLRequest(url: url("auth"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(["username": username, "password": password])
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String, !token.isEmpty else { throw OpenPricesAPIError.malformedResponse }
        return token
    }

    func uploadProof(_ proof: OpenPricesProofUpload, token: String) async throws -> Int {
        var request = URLRequest(url: url("proofs/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let boundary = "RestockBoundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(proof, boundary: boundary)
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else { throw OpenPricesAPIError.malformedResponse }
        return id
    }

    func createPrice(_ price: OpenPricesPriceUpload, token: String) async throws {
        var request = URLRequest(url: url("prices"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: price.body)
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
    }

    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw OpenPricesAPIError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenPricesAPIError.badStatus(http.statusCode, String(data: data.prefix(300), encoding: .utf8) ?? "")
        }
    }

    static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return fields.keys.sorted().map { key in
            "\(key)=\(fields[key]!.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").data(using: .utf8)!
    }

    /// Multipart-Körper für `POST /proofs/upload`: Datei plus Textfelder (`type`, Ort, Datum, Währung,
    /// Zahl und Summe der Preise des Bons).
    static func multipartBody(_ proof: OpenPricesProofUpload, boundary: String) -> Data {
        var fields: [(String, String)] = [
            ("type", "RECEIPT"),
            ("location_osm_id", String(proof.location.osmID)),
            ("location_osm_type", proof.location.osmType),
            ("date", proof.date),
            ("currency", proof.currency),
            ("receipt_price_count", String(proof.priceCount)),
        ]
        if let total = proof.priceTotal { fields.append(("receipt_price_total", String(format: "%.2f", total))) }
        var body = Data()
        func append(_ text: String) { body.append(text.data(using: .utf8)!) }
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(proof.fileName)\"\r\nContent-Type: \(proof.mimeType)\r\n\r\n")
        body.append(proof.imageData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Token im Schlüsselbund

protocol OpenPricesTokenStore: Sendable {
    func token() -> String?
    func set(_ token: String?)
}

/// Bearer-Token im Schlüsselbund (nur dieses Gerät, nicht in iCloud-Backups synchronisiert).
struct KeychainTokenStore: OpenPricesTokenStore {
    static let service = "com.johannesemmrich.Restock.openprices"
    static let account = "bearer-token"
    static let shared = KeychainTokenStore()

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.service,
         kSecAttrAccount as String: Self.account]
    }

    func token() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ token: String?) {
        SecItemDelete(query as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

/// Für Tests und Vorschauen.
final class InMemoryTokenStore: OpenPricesTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    init(_ value: String? = nil) { self.value = value }
    func token() -> String? { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ token: String?) { lock.lock(); defer { lock.unlock() }; value = token }
}

// MARK: - Filiale je Laden

/// Gemerkte OSM-Filiale je Laden (`UserDefaults`, nicht am gespiegelten `Store`-Modell: kein neues
/// CloudKit-Feld, die Filiale ist ohnehin gerätenah).
struct OpenPricesLocationStore {
    static let storageKey = "openPricesLocations.v1"
    static let shared = OpenPricesLocationStore(defaults: .standard)
    let defaults: UserDefaults

    func all() -> [String: OpenPricesLocation] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: OpenPricesLocation].self, from: data) else { return [:] }
        return decoded
    }

    func location(for storeID: UUID) -> OpenPricesLocation? { all()[storeID.uuidString] }

    func set(_ location: OpenPricesLocation?, for storeID: UUID) {
        var map = all()
        map[storeID.uuidString] = location
        if let data = try? JSONEncoder().encode(map) { defaults.set(data, forKey: Self.storageKey) }
    }
}

/// Ortssuche (Nominatim), Naht für Tests.
protocol PlaceSearchAPI: Sendable {
    func search(_ query: String) async throws -> [OpenPricesLocation]
}

/// OpenStreetMap Nominatim: `search?q=…&format=jsonv2`; Nutzungsbedingungen verlangen eine
/// aussagekräftige `User-Agent`-Kennung und höchstens eine Anfrage je Sekunde (hier nur auf Tipp).
struct NominatimClient: PlaceSearchAPI {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func search(_ query: String) async throws -> [OpenPricesLocation] {
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "format", value: "jsonv2"),
                                 URLQueryItem(name: "limit", value: "10"), URLQueryItem(name: "addressdetails", value: "0")]
        var request = URLRequest(url: components.url!)
        request.setValue("Restock iOS \(OpenPricesClient.appVersion) (support@emmrich-business.com)", forHTTPHeaderField: "User-Agent")
        request.setValue(Locale.current.language.languageCode?.identifier ?? "de", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        try OpenPricesClient.check(response, data)
        return Self.parse(data)
    }

    /// `osm_type` kommt klein (`node`/`way`/`relation`), Open Prices will es groß.
    static func parse(_ data: Data) -> [OpenPricesLocation] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let type = item["osm_type"] as? String, let name = item["display_name"] as? String else { return nil }
            let id: Int64
            if let n = item["osm_id"] as? Int64 { id = n } else if let n = item["osm_id"] as? Int { id = Int64(n) }
            else if let n = item["osm_id"] as? Double { id = Int64(n) } else { return nil }
            return OpenPricesLocation(osmID: id, osmType: type.uppercased(), displayName: name)
        }
    }
}

// MARK: - Plan eines Beitrags (reine Logik)

enum OpenPricesContribution {
    static let enabledKey = "openPricesContributionEnabled"
    /// Opt-in, Standard aus (Bonfoto wird öffentlich).
    static let enabledDefault = false
    static let usernameKey = "openPricesUsername"
    static let lastResultKey = "openPricesLastResult"
    static let appName = "Restock"
    /// Bis der Nachweis gegen Pre-Production vorliegt, geht nichts nach Production.
    static let environment: OpenPricesEnvironment = .preProduction
    /// Issue #244: in 1.0 ausgeblendet (App Review 2.1/1.2). Sperrt Einstieg und Sendeweg,
    /// auch bei früher eingeschaltetem Schalter.
    static let isAvailable = false
    static let currency = "EUR"

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: enabledKey) as? Bool) ?? enabledDefault
    }

    /// Eine Bonzeile, wie `ReceiptScannerView.save()` sie kennt.
    struct Line: Equatable, Sendable {
        let name: String
        /// Zeilen-Gesamtpreis
        let price: Double
        let quantity: Double
        /// Gewicht in Gramm bei Gewichtszeilen
        let weightBasis: Double?
    }

    struct Plan: Equatable, Sendable {
        let proof: OpenPricesProofUpload
        let prices: [OpenPricesPriceUpload]
        /// Namen der übersprungenen Zeilen (keine OFF-Kategorie oder unbrauchbarer Preis).
        let skipped: [String]
    }

    /// Bereitschaft, als reine Funktion für Einstellungen und `save()`.
    enum Readiness: Equatable {
        case ready, disabled, notLoggedIn, noLocation, noImage
    }

    static func readiness(enabled: Bool, loggedIn: Bool, location: OpenPricesLocation?, hasImage: Bool) -> Readiness {
        guard enabled else { return .disabled }
        guard loggedIn else { return .notLoggedIn }
        guard location != nil else { return .noLocation }
        guard hasImage else { return .noImage }
        return .ready
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Preis je Stück (`UNIT`) oder je Kilogramm (`KILOGRAM`) aus Zeilensumme, Stückzahl und Gewicht.
    static func pricePer(_ line: Line) -> (price: Double, per: String)? {
        guard line.price > 0 else { return nil }
        if let grams = line.weightBasis, grams > 0 {
            return ((line.price / grams * 1000 * 100).rounded() / 100, "KILOGRAM")
        }
        let quantity = line.quantity > 0 ? line.quantity : 1
        return ((line.price / quantity * 100).rounded() / 100, "UNIT")
    }

    /// Baut Nachweis und Preise; `nil`, wenn keine Zeile beitragbar ist (dann auch kein Foto-Upload).
    static func plan(lines: [Line], imageData: Data, date: Date, location: OpenPricesLocation,
                     categoryTag: (String) -> String? = { PriceCatalog.match($0)?.offCategory }) -> Plan? {
        let day = dateString(date)
        var prices: [OpenPricesPriceUpload] = []
        var skipped: [String] = []
        for line in lines {
            guard let tag = categoryTag(line.name), let per = pricePer(line) else { skipped.append(line.name); continue }
            prices.append(OpenPricesPriceUpload(itemName: line.name, categoryTag: tag, price: per.price, pricePer: per.per,
                                                currency: currency, location: location, date: day, proofID: nil))
        }
        guard !prices.isEmpty else { return nil }
        let total = lines.reduce(0.0) { $0 + max($1.price, 0) }
        let proof = OpenPricesProofUpload(imageData: imageData, fileName: "restock-receipt.jpg", mimeType: "image/jpeg",
                                          date: day, currency: currency, location: location,
                                          priceCount: prices.count, priceTotal: total > 0 ? total : nil)
        return Plan(proof: proof, prices: prices, skipped: skipped)
    }

    static var allLocalizationKeys: [String] {
        ["settings.openprices.title", "settings.openprices.toggle", "settings.openprices.footer",
         "settings.openprices.confirm.title", "settings.openprices.confirm.message", "settings.openprices.confirm.ok",
         "settings.openprices.account", "settings.openprices.username", "settings.openprices.password",
         "settings.openprices.login", "settings.openprices.logout", "settings.openprices.loggedin",
         "settings.openprices.login.failed", "settings.openprices.locations", "settings.openprices.locations.footer",
         "settings.openprices.location.choose", "settings.openprices.location.search", "settings.openprices.location.none",
         "settings.openprices.last", "settings.openprices.last.none", "settings.openprices.environment"]
    }
}

/// Ergebnis des letzten Beitrags für die Einstellungen (nur Zähler und Datum, keine Artikelnamen).
struct OpenPricesLastResult: Codable, Equatable {
    let date: Date
    let sent: Int
    let skipped: Int
    let failed: Int
    let proofUploaded: Bool
    let message: String
}

// MARK: - Dienst

actor OpenPricesContributionService {
    static let shared = OpenPricesContributionService(
        api: OpenPricesClient(environment: OpenPricesContribution.environment),
        tokens: KeychainTokenStore.shared, defaults: .standard, locations: .shared)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SmartCart", category: "openprices")

    let api: OpenPricesAPI
    let tokens: OpenPricesTokenStore
    let defaults: UserDefaults
    let locations: OpenPricesLocationStore
    let now: () -> Date
    let available: Bool

    init(api: OpenPricesAPI, tokens: OpenPricesTokenStore, defaults: UserDefaults, locations: OpenPricesLocationStore,
         now: @escaping () -> Date = Date.init, available: Bool = OpenPricesContribution.isAvailable) {
        self.api = api
        self.tokens = tokens
        self.defaults = defaults
        self.locations = locations
        self.now = now
        self.available = available
    }

    var isEnabled: Bool { OpenPricesContribution.isEnabled(in: defaults) }
    var isLoggedIn: Bool { tokens.token() != nil }
    var username: String? { defaults.string(forKey: OpenPricesContribution.usernameKey) }

    func readiness(for storeID: UUID, hasImage: Bool) -> OpenPricesContribution.Readiness {
        OpenPricesContribution.readiness(enabled: available && isEnabled, loggedIn: isLoggedIn,
                                         location: locations.location(for: storeID), hasImage: hasImage)
    }

    func login(username: String, password: String) async throws {
        let token = try await api.authenticate(username: username, password: password)
        tokens.set(token)
        defaults.set(username, forKey: OpenPricesContribution.usernameKey)
    }

    func logout() {
        tokens.set(nil)
        defaults.removeObject(forKey: OpenPricesContribution.usernameKey)
    }

    func lastResult() -> OpenPricesLastResult? {
        guard let data = defaults.data(forKey: OpenPricesContribution.lastResultKey) else { return nil }
        return try? JSONDecoder().decode(OpenPricesLastResult.self, from: data)
    }

    private func store(_ result: OpenPricesLastResult) {
        if let data = try? JSONEncoder().encode(result) { defaults.set(data, forKey: OpenPricesContribution.lastResultKey) }
    }

    /// Nachweis zuerst, dann jeder Preis mit `proof_id`; scheitert der Nachweis, geht kein Preis hinaus.
    /// Fehler werden protokolliert und als Zähler gespeichert, nie dem Nutzer als Dialog gezeigt.
    @discardableResult
    func contribute(_ plan: OpenPricesContribution.Plan) async -> OpenPricesLastResult {
        guard isEnabled, let token = tokens.token() else {
            let result = OpenPricesLastResult(date: now(), sent: 0, skipped: plan.skipped.count, failed: plan.prices.count,
                                              proofUploaded: false, message: "nicht bereit")
            return result
        }
        let proofID: Int
        do {
            proofID = try await api.uploadProof(plan.proof, token: token)
        } catch {
            Self.logger.error("Open Prices: Nachweis nicht hochgeladen: \(String(describing: error), privacy: .private)")
            let result = OpenPricesLastResult(date: now(), sent: 0, skipped: plan.skipped.count, failed: plan.prices.count,
                                              proofUploaded: false, message: Self.message(for: error))
            store(result)
            return result
        }
        var sent = 0
        var failed = 0
        var lastError: Error?
        for var price in plan.prices {
            price.proofID = proofID
            do {
                try await api.createPrice(price, token: token)
                sent += 1
            } catch {
                failed += 1
                lastError = error
                Self.logger.error("Open Prices: Preis nicht gespeichert: \(String(describing: error), privacy: .private)")
            }
        }
        let result = OpenPricesLastResult(date: now(), sent: sent, skipped: plan.skipped.count, failed: failed,
                                          proofUploaded: true, message: lastError.map(Self.message(for:)) ?? "ok")
        store(result)
        return result
    }

    static func message(for error: Error) -> String {
        if case let OpenPricesAPIError.badStatus(code, text) = error { return "HTTP \(code) \(text.prefix(80))" }
        return (error as NSError).localizedDescription
    }

    /// Bereitschaft prüfen, planen, senden; `nil`, wenn nichts gesendet wurde.
    @discardableResult
    func contribute(lines: [OpenPricesContribution.Line], imageData: Data?, storeID: UUID, date: Date) async -> OpenPricesLastResult? {
        guard readiness(for: storeID, hasImage: imageData != nil) == .ready,
              let imageData, let location = locations.location(for: storeID),
              let plan = OpenPricesContribution.plan(lines: lines, imageData: imageData, date: date, location: location) else { return nil }
        return await contribute(plan)
    }

    /// Aus `ReceiptScannerView.save()`: alles im Hintergrund, der Screen wartet nicht.
    nonisolated func contributeInBackground(lines: [OpenPricesContribution.Line], imageData: Data?, storeID: UUID, date: Date) {
        Task { await contribute(lines: lines, imageData: imageData, storeID: storeID, date: date) }
    }
}
