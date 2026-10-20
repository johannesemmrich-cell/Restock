import CloudKit
import CryptoKit
import Foundation
import os

/// Lesen und Schreiben des Community-Preispools (Issue #163, Weg A) — als Protokoll vor der
/// öffentlichen CloudKit-Datenbank, damit `CommunityPriceTests` mit einem Fake laufen (Muster
/// `SharedStoreDatabase`).
protocol CommunityPriceDatabase {
    func save(_ record: CKRecord) async throws -> CKRecord
    /// Alle Beobachtungen einer Kette zu den Artikelschlüsseln (`itemKey IN …`).
    func fetchCommunityRecords(chain: String, itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord]
}

extension CKDatabase: CommunityPriceDatabase {
    func fetchCommunityRecords(chain: String, itemKeys: [String], resultsLimit: Int) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@ AND %K IN %@",
                                    CommunityPriceSchema.chain, chain, CommunityPriceSchema.itemKey, itemKeys)
        let query = CKQuery(recordType: CommunityPriceSchema.recordType, predicate: predicate)
        let (matchResults, _) = try await records(matching: query, resultsLimit: resultsLimit)
        return matchResults.compactMap { try? $0.1.get() }
    }
}

/// Record-Typ `CommunityPrice` in der öffentlichen Datenbank. **Vor dem TestFlight-Upload in
/// Production veröffentlichen** (`docs/testflight-setup.md`); Drift-Test `CommunityPriceTests`
/// gegen `docs/cloudkit/private-schema-aktuell.ckdb`.
enum CommunityPriceSchema {
    static let recordType = "CommunityPrice"
    static let itemKey = "itemKey"
    static let chain = "chain"
    static let price = "price"
    static let unit = "unit"
    static let observedAt = "observedAt"
    static let clientID = "clientID"
    static let fields: Set<String> = [itemKey, chain, price, unit, observedAt, clientID]

    /// Ein Nutzer hält je Kette und Artikel genau einen aktuellen Eintrag (Upsert über den
    /// Record-Namen), statt den Pool mit jedem Bon weiter zu füllen. Der Hash verrät weder
    /// Kennung noch Artikel.
    static func recordName(clientID: String, chain: String, itemKey: String) -> String {
        let digest = SHA256.hash(data: Data("\(clientID)|\(chain)|\(itemKey)".utf8))
        return "cp-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func fill(_ record: CKRecord, itemKey: String, chain: String, price: Double, unit: String,
                     observedAt: Date, clientID: String) {
        record[Self.itemKey] = itemKey as CKRecordValue
        record[Self.chain] = chain as CKRecordValue
        record[Self.price] = price as CKRecordValue
        record[Self.unit] = unit as CKRecordValue
        record[Self.observedAt] = observedAt as CKRecordValue
        record[Self.clientID] = clientID as CKRecordValue
    }

    static func observation(from record: CKRecord) -> CommunityPrice.Observation? {
        guard let price = record[Self.price] as? Double,
              let unit = record[Self.unit] as? String,
              let observedAt = record[Self.observedAt] as? Date else { return nil }
        return CommunityPrice.Observation(price: price, unit: unit, observedAt: observedAt)
    }
}

/// Schreibt Beobachtungen (nur mit eingeschaltetem Schalter) und holt Aggregate in den
/// Zwischenspeicher. Fehler werden protokolliert, nie dem Nutzer gezeigt: Ohne Schema in der
/// Produktion scheitert das Speichern still, die App bleibt benutzbar.
actor CommunityPriceService {
    static let containerID = "iCloud.com.johannesemmrich.SmartCart"
    /// `UserDefaults.standard`, wie `@AppStorage` in `SettingsView`. Standard: an (Opt-out, PO
    /// 2026-10-20); nur ein ausdrücklich gespeichertes `false` schaltet das Teilen ab.
    static let sharingEnabledKey = "communityPricesSharingEnabled"
    static let sharingEnabledDefault = true
    /// Pseudonyme Kennung je Installation in der App-Gruppe; keine Verbindung zur Apple-ID.
    static let clientIDKey = "communityPriceClientID"
    static let fetchLimit = 400
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SmartCart", category: "community")

    static let shared = CommunityPriceService(
        database: CKContainer(identifier: containerID).publicCloudDatabase,
        defaults: .standard, cache: .shared)

    let database: CommunityPriceDatabase
    let defaults: UserDefaults
    let cache: CommunityPriceCache
    let now: () -> Date

    init(database: CommunityPriceDatabase, defaults: UserDefaults, cache: CommunityPriceCache,
         now: @escaping () -> Date = Date.init) {
        self.database = database
        self.defaults = defaults
        self.cache = cache
        self.now = now
    }

    var isSharingEnabled: Bool { Self.isSharingEnabled(in: defaults) }

    /// Fehlt der Schlüssel (frische Installation oder nie angefasst), gilt der Standard.
    static func isSharingEnabled(in defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: sharingEnabledKey) as? Bool) ?? sharingEnabledDefault
    }

    func clientID() -> String {
        if let existing = cache.defaults.string(forKey: Self.clientIDKey), !existing.isEmpty { return existing }
        let id = UUID().uuidString
        cache.defaults.set(id, forKey: Self.clientIDKey)
        return id
    }

    /// Was beim Bon-Scan oder „Preis eintragen" geteilt wird: Artikelname, Laden (nur die Kette
    /// reist), Preis je Bezugsgröße, Bezugsgröße. Kein Name, kein Foto, keine Filiale.
    struct Contribution: Equatable {
        let itemName: String
        let storeName: String
        let perUnitPrice: Double
        let unit: String
    }

    /// Speichert eine Beobachtung als Upsert. `false`, wenn der Schalter aus ist, die Eingabe
    /// unbrauchbar ist oder CloudKit ablehnt.
    @discardableResult
    func contribute(_ contribution: Contribution) async -> Bool {
        guard isSharingEnabled, contribution.perUnitPrice > 0 else { return false }
        let chain = CommunityPrice.chain(fromStoreName: contribution.storeName)
        let itemKey = CommunityPrice.itemKey(contribution.itemName)
        let unit = contribution.unit.trimmingCharacters(in: .whitespaces).lowercased()
        guard !chain.isEmpty, !itemKey.isEmpty, !unit.isEmpty else { return false }
        let id = clientID()
        let recordID = CKRecord.ID(recordName: CommunityPriceSchema.recordName(clientID: id, chain: chain, itemKey: itemKey))
        let record = CKRecord(recordType: CommunityPriceSchema.recordType, recordID: recordID)
        CommunityPriceSchema.fill(record, itemKey: itemKey, chain: chain, price: contribution.perUnitPrice,
                                  unit: unit, observedAt: now(), clientID: id)
        do {
            _ = try await database.save(record)
            return true
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Eigener Eintrag existiert schon: den Server-Record aktualisieren (Upsert).
            guard let server = error.serverRecord else { return false }
            CommunityPriceSchema.fill(server, itemKey: itemKey, chain: chain, price: contribution.perUnitPrice,
                                      unit: unit, observedAt: now(), clientID: id)
            do {
                _ = try await database.save(server)
                return true
            } catch {
                Self.logger.error("Community-Preis nicht aktualisiert: \(SharedStoreSchema.errorText(error), privacy: .private)")
                return false
            }
        } catch {
            Self.logger.error("Community-Preis nicht gespeichert: \(SharedStoreSchema.errorText(error), privacy: .private)")
            return false
        }
    }

    nonisolated func contributeInBackground(_ contribution: Contribution) {
        Task { await contribute(contribution) }
    }

    /// Holt die Beobachtungen der Kette zu den Artikelnamen und schreibt Aggregate in den
    /// Zwischenspeicher. Liefert die Zahl der Artikel mit Aggregat; `nil` bei Netz-/Serverfehler
    /// (der Zwischenspeicher bleibt dann unverändert).
    func refresh(storeName: String, itemNames: [String]) async -> Int? {
        let chain = CommunityPrice.chain(fromStoreName: storeName)
        let keys = Array(Set(itemNames.map(CommunityPrice.itemKey).filter { !$0.isEmpty })).sorted()
        guard !chain.isEmpty, !keys.isEmpty else { return 0 }
        let records: [CKRecord]
        do {
            records = try await database.fetchCommunityRecords(chain: chain, itemKeys: keys, resultsLimit: Self.fetchLimit)
        } catch {
            Self.logger.error("Community-Preise nicht geladen: \(SharedStoreSchema.errorText(error), privacy: .private)")
            return nil
        }
        var grouped: [String: [CommunityPrice.Observation]] = [:]
        for record in records {
            guard let key = record[CommunityPriceSchema.itemKey] as? String,
                  let observation = CommunityPriceSchema.observation(from: record) else { continue }
            grouped[key, default: []].append(observation)
        }
        var aggregates: [String: CommunityPrice.Aggregate] = [:]
        let reference = now()
        for key in keys {
            if let aggregate = CommunityPrice.aggregate(grouped[key] ?? [], now: reference) { aggregates[key] = aggregate }
        }
        cache.update(chain: chain, queriedKeys: keys, aggregates: aggregates)
        return aggregates.count
    }

    /// Wendet den Zwischenspeicher auf offene Artikel an, deren Preis automatisch hergeleitet
    /// ist (Schätzung, Pauschale oder älterer Community-Wert). Echte Preise bleiben unberührt.
    /// Verliert ein Artikel sein Aggregat, fällt er auf Katalog/Pauschale zurück.
    @MainActor
    static func apply(cache: CommunityPriceCache, to items: [ShoppingItem], storeName: String) -> Int {
        var changed = 0
        for item in items where item.estimatedPriceIsAutoDerived && !item.isCompleted {
            let resolution = CommunityPrice.resolve(
                forLowercasedName: item.name.lowercased(), storeName: storeName, itemUnit: item.unit,
                quantityAmount: item.quantityAmount, quantitySource: item.quantitySource, cache: cache)
            if let resolution {
                let source = CommunityPrice.sourcePrefix + resolution.chainDisplayName
                if item.priceSource == source, item.estimatedPrice == resolution.price { continue }
                if let unitOverride = resolution.unitOverride { item.unit = unitOverride }
                item.estimatedPrice = resolution.price
                item.priceSource = source
                item.priceSourceDate = resolution.latest
                changed += 1
            } else if item.priceOrigin == "community" {
                let fallback = PriceEstimator.resolve(for: item.name, category: item.category, unit: item.unit,
                                                      quantityAmount: item.quantityAmount)
                item.estimatedPrice = fallback?.price
                item.priceSource = fallback?.source ?? "estimate"
                item.priceSourceDate = nil
                changed += 1
            }
        }
        return changed
    }

    /// Aus `StoreDetailView.task`: holen, dann auf der Hauptschleife auf die offene Liste anwenden.
    func refreshAndApply(store: Store) async {
        let (name, names) = await MainActor.run {
            (store.name, store.pendingItems.filter { $0.estimatedPriceIsAutoDerived }.map(\.name))
        }
        guard !names.isEmpty, await refresh(storeName: name, itemNames: names) != nil else { return }
        let cache = self.cache
        await MainActor.run { _ = Self.apply(cache: cache, to: store.pendingItems, storeName: name) }
    }
}
