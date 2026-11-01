import CloudKit
import Foundation
import os

/// Promo-Codes für kostenlose Pro-Freischaltung (Freunde, Familie, Live-Tester). 1:1 aus
/// Dresslyst übernommen (dort `PromoCodeService`), nur an Restock angepasst: Freischaltung läuft
/// über `PremiumService` statt `PurchaseManager`, und wie bei `CommunityPriceService`/
/// `SharedStoreService` liegt ein Protokoll (`PromoCodeDatabase`) vor der öffentlichen CloudKit-
/// Datenbank, damit `PromoCodeServiceTests` ohne Netz mit einem Fake laufen.
///
/// Wie in Dresslyst bewusst über die **öffentliche** CloudKit-Datenbank (nicht die private
/// Spiegel-DB, die bleibt unberührt): eine Entzieh-Funktion braucht zwingend eine Instanz, die
/// alle Installationen gemeinsam sehen — rein lokal/offline ist das nicht abbildbar.
///
/// Design-Entscheidung (aus Dresslyst): der Code-String selbst ist die `recordName`. Einlösen ist
/// dadurch ein direkter Record-Fetch per ID statt einer `CKQuery` — kein „Queryable"-Index nötig.
/// Nur die Admin-Liste (`fetchAllCodes()`) braucht eine Query.
@MainActor
final class PromoCodeService: ObservableObject {
    static let shared = PromoCodeService(
        database: PromoCodeService.defaultDatabase(arguments: ProcessInfo.processInfo.arguments),
        defaults: .standard,
        onUnlockChange: { PremiumService.shared.setHasValidPromoCode($0) })

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SmartCart",
                                       category: "promoCode")

    /// Dieselbe Installation-UUID-Idee wie `CommunityPriceService.clientID` — rein zur Zuordnung
    /// „wer hat diesen Code eingelöst", kein Konto-/Gerätebezug.
    static let installationIDKey = "promoCode.installationUUID"
    static let redeemedCodeKey = "promoCode.redeemedCode"

    @Published private(set) var isRedeeming = false
    @Published private(set) var redeemErrorMessage: String?
    /// Admin-Liste, siehe `fetchAllCodes()` — nur für die Dev-Mode-Verwaltung.
    @Published private(set) var allCodes: [PromoCodeRecord] = []
    @Published private(set) var isLoadingList = false
    @Published private(set) var listErrorMessage: String?
    /// Diagnose, nur Dev-Mode: zeigt den letzten echten Speicherfehler beim Erzeugen, damit ein
    /// Totalausfall nicht wie „0 angefragt" aussieht (aus Dresslyst übernommen).
    @Published private(set) var lastGenerateErrorMessage: String?

    private let database: PromoCodeDatabase
    private let defaults: UserDefaults
    private let onUnlockChange: (Bool) -> Void
    private let now: () -> Date

    init(database: PromoCodeDatabase, defaults: UserDefaults,
         onUnlockChange: @escaping (Bool) -> Void, now: @escaping () -> Date = Date.init) {
        self.database = database
        self.defaults = defaults
        self.onUnlockChange = onUnlockChange
        self.now = now
    }

    /// Standard: öffentliche CloudKit-Datenbank. Muster `CommunityPriceService.defaultDatabase` —
    /// es gibt bewusst keinen UI-Test-Ersatz, Promo-Codes haben keinen UI-Test.
    static func defaultDatabase(arguments: [String]) -> PromoCodeDatabase {
        CKContainer(identifier: SharedModelContainer.cloudKitContainerID).publicCloudDatabase
    }

    private var installationID: String {
        if let existing = defaults.string(forKey: Self.installationIDKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.installationIDKey)
        return id
    }

    // MARK: - Redemption

    enum RedeemError: LocalizedError {
        case notFound
        case revoked
        case redeemedByAnother

        var errorDescription: String? {
            switch self {
            case .notFound: return String(localized: "promoCode.error.notFound")
            case .revoked: return String(localized: "promoCode.error.revoked")
            case .redeemedByAnother: return String(localized: "promoCode.error.redeemedByAnother")
            }
        }
    }

    /// Nutzer gibt einen Code ein. Bei Erfolg: Record als von dieser Installation eingelöst
    /// markiert, lokale Freischaltung sofort aktiv.
    @discardableResult
    func redeem(_ rawCode: String) async -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return false }
        isRedeeming = true
        redeemErrorMessage = nil
        defer { isRedeeming = false }

        do {
            let record = try await database.record(for: code)
            guard (record[PromoCodeSchema.isRevoked] as? Int64 ?? 0) == 0 else {
                redeemErrorMessage = RedeemError.revoked.localizedDescription
                return false
            }
            let existingRedeemer = record[PromoCodeSchema.redeemedBy] as? String
            guard existingRedeemer == nil || existingRedeemer == installationID else {
                redeemErrorMessage = RedeemError.redeemedByAnother.localizedDescription
                return false
            }
            record[PromoCodeSchema.redeemedBy] = installationID as CKRecordValue
            record[PromoCodeSchema.redeemedAt] = now() as CKRecordValue
            // .changedKeys (letzter Schreiber gewinnt) wie in Dresslyst: dieser Save ändert nur
            // zwei Felder; ein „client oplock error" bei einer stinknormalen Einlösung wäre
            // schlimmer als ein toleriertes Wettrennen zweier Einlöseversuche desselben Codes.
            try await database.modifyChangedKeys(record)

            defaults.set(code, forKey: Self.redeemedCodeKey)
            onUnlockChange(true)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            redeemErrorMessage = RedeemError.notFound.localizedDescription
            return false
        } catch {
            redeemErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Best-effort, bei jedem App-Start aufgerufen, damit ein Entzug zeitnah ankommt. Prüft NUR den
    /// einen Record, den diese Installation eingelöst hat (direkter ID-Fetch, keine Query).
    func revalidateLocalRedemption() async {
        guard let code = defaults.string(forKey: Self.redeemedCodeKey) else { return }
        do {
            let record = try await database.record(for: code)
            let isRevoked = (record[PromoCodeSchema.isRevoked] as? Int64 ?? 0) != 0
            let redeemedByMe = (record[PromoCodeSchema.redeemedBy] as? String) == installationID
            onUnlockChange(!isRevoked && redeemedByMe)
        } catch let error as CKError where error.code == .unknownItem {
            // Record gelöscht (nicht nur entzogen) — als entzogen behandeln.
            onUnlockChange(false)
        } catch {
            // Netzwerkfehler o.ä. — lokalen Stand NICHT anfassen, sonst entzöge jeder Flugmodus-
            // Start die Freischaltung kurzzeitig. Nächster Start versucht es erneut.
        }
    }

    // MARK: - Admin (Dev-Mode)

    struct PromoCodeRecord: Identifiable {
        let id: String   // == code
        let label: String
        let isRevoked: Bool
        let redeemedByInstallationID: String?
        let redeemedAt: Date?
        let createdAt: Date?

        var code: String { id }
        var status: Status {
            if isRevoked { return .revoked }
            if redeemedByInstallationID != nil { return .redeemed }
            return .open
        }
        enum Status { case open, redeemed, revoked }
    }

    /// Erzeugt `count` neue, eindeutige Codes (Format `XXXX-XXXX`, Zeichensatz ohne 0/O/1/I) und
    /// legt sie in der öffentlichen Datenbank an. `fetchAllCodes()` braucht einen „Queryable"-Index
    /// auf `isRevoked` im CloudKit Dashboard.
    @discardableResult
    func generateCodes(count: Int, label: String) async -> [String] {
        var created: [String] = []
        lastGenerateErrorMessage = nil
        for _ in 0..<count {
            let code = Self.randomCode()
            let record = CKRecord(recordType: PromoCodeSchema.recordType,
                                  recordID: CKRecord.ID(recordName: code))
            record[PromoCodeSchema.isRevoked] = Int64(0) as CKRecordValue
            record[PromoCodeSchema.label] = label as CKRecordValue
            record[PromoCodeSchema.createdAt] = now() as CKRecordValue
            do {
                try await database.create(record)
                created.append(code)
            } catch {
                lastGenerateErrorMessage = error.localizedDescription
                continue
            }
        }
        await fetchAllCodes()
        return created
    }

    func setRevoked(_ revoked: Bool, code: String) async {
        do {
            let record = try await database.record(for: code)
            record[PromoCodeSchema.isRevoked] = Int64(revoked ? 1 : 0) as CKRecordValue
            try await database.modifyChangedKeys(record)
            await fetchAllCodes()
        } catch {
            listErrorMessage = error.localizedDescription
        }
    }

    func fetchAllCodes() async {
        isLoadingList = true
        defer { isLoadingList = false }
        do {
            let records = try await database.allCodeRecords()
            allCodes = records.map { record in
                PromoCodeRecord(
                    id: record.recordID.recordName,
                    label: record[PromoCodeSchema.label] as? String ?? "",
                    isRevoked: (record[PromoCodeSchema.isRevoked] as? Int64 ?? 0) != 0,
                    redeemedByInstallationID: record[PromoCodeSchema.redeemedBy] as? String,
                    redeemedAt: record[PromoCodeSchema.redeemedAt] as? Date,
                    createdAt: record[PromoCodeSchema.createdAt] as? Date)
            }
            listErrorMessage = nil
        } catch {
            listErrorMessage = error.localizedDescription
        }
    }

    static func randomCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func group() -> String { String((0..<4).map { _ in alphabet.randomElement()! }) }
        return "\(group())-\(group())"
    }
}

// MARK: - CloudKit-Naht

/// Protokoll vor der öffentlichen CloudKit-Datenbank, damit `PromoCodeServiceTests` mit einem Fake
/// laufen (Muster `CommunityPriceDatabase`/`SharedStoreDatabase`).
protocol PromoCodeDatabase: Sendable {
    /// Direkter Fetch per Record-Name (== Code). Wirft `CKError.unknownItem`, wenn es ihn nicht gibt.
    func record(for recordName: String) async throws -> CKRecord
    /// Neuen Code anlegen (Standard-Save-Policy).
    func create(_ record: CKRecord) async throws
    /// Bestehenden Record mit `.changedKeys` speichern (letzter Schreiber gewinnt).
    func modifyChangedKeys(_ record: CKRecord) async throws
    /// Alle Codes, jüngste zuerst — nur für die Admin-Liste.
    func allCodeRecords() async throws -> [CKRecord]
}

extension CKDatabase: PromoCodeDatabase {
    func record(for recordName: String) async throws -> CKRecord {
        try await record(for: CKRecord.ID(recordName: recordName))
    }

    func create(_ record: CKRecord) async throws {
        _ = try await save(record)
    }

    func modifyChangedKeys(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            add(operation)
        }
    }

    func allCodeRecords() async throws -> [CKRecord] {
        // Wie Dresslyst: CloudKit braucht ein „Queryable"-Feld je Query, `recordName` ist das nicht.
        let query = CKQuery(recordType: PromoCodeSchema.recordType,
                            predicate: NSPredicate(format: "%K >= 0", PromoCodeSchema.isRevoked))
        query.sortDescriptors = [NSSortDescriptor(key: PromoCodeSchema.createdAt, ascending: false)]
        var results: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await records(continuingMatchFrom: cursor)
            } else {
                page = try await records(matching: query, resultsLimit: 100)
            }
            results.append(contentsOf: page.matchResults.compactMap { try? $0.1.get() })
            cursor = page.queryCursor
        } while cursor != nil
        return results
    }
}

// MARK: - Schema

/// Record-Typ `PromoCode` in der **öffentlichen** Datenbank. Record-Name == Code.
///
/// **Schema-/Rollen-Schritt im CloudKit-Dashboard — zwingend, sonst schlägt JEDE fremde Einlösung
/// fehl:** `redeem` ist ein *Fremdschreiben* — ein ganz normaler Nutzer (Freund/Tester) ändert
/// `redeemedBy`/`redeemedAt` an einem Record, den der Entwickler erzeugt hat. Die Standard-
/// Sicherheitsrolle der öffentlichen DB gibt `_icloud` (angemeldet) nur CREATE + READ, **kein
/// WRITE** auf fremde Records; ohne Zusatzrolle wirft das Speichern `CKError.permissionFailure`.
/// Das Muster ist also **`SharedStore`/`SharedItemPhoto`** (die einzigen Typen mit Fremdschreiben,
/// die im Dashboard `GRANT CREATE, WRITE TO "_icloud"` tragen), **nicht** `CommunityPrice` (dort
/// schreibt jeder nur eigene Records, creator == self, daher reicht die Default-Rolle).
/// Zu tun, bevor Codes für andere funktionieren: Record-Typ `PromoCode` in Development UND
/// Production anlegen und der Rolle `_icloud` **WRITE** auf den Typ gewähren (`docs/testflight-
/// setup.md`). In Development legt CloudKit den Typ beim ersten Erzeugen selbst an (mit Default-
/// Rolle, also noch ohne das nötige WRITE), in Production gar nicht. Einzeltest auf einem Gerät
/// mit dem eigenen Entwickler-Account verdeckt den Fehler (creator == self hat WRITE).
enum PromoCodeSchema {
    static let recordType = "PromoCode"
    static let isRevoked = "isRevoked"
    static let redeemedBy = "redeemedByInstallationID"
    static let redeemedAt = "redeemedAt"
    static let label = "label"
    static let createdAt = "createdAt"
}
