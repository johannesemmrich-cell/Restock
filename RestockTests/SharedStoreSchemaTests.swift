import XCTest
import SwiftData
import CloudKit
@testable import Restock

/// Geteilte Läden bei unvollständigem CloudKit-Produktions-Schema (Issue #121).
/// Spec: `docs/specs/services/shared-store-schema-fallback.md`, Testplan T1–T8, T13–T15.
///
/// Die Tests laufen ohne CloudKit: `FakeSharedStoreDatabase` stellt die Produktion nach. Sie lehnt
/// Records mit Feldern außerhalb ihres Schemas mit `CKError.serverRejectedRequest` und
/// `ServerErrorDescription` „Cannot create or modify field 'categoriesJSON' in record 'SharedStore'
/// in production schema“ ab und zählt die Speicherversuche.
///
/// Festgelegte Bausteine (baut Phase 6, die Tests nutzen sie):
/// - `protocol SharedStoreDatabase { record(for:) async throws -> CKRecord; save(_:) async throws -> CKRecord }`,
///   `extension CKDatabase: SharedStoreDatabase {}`.
/// - `SharedStoreService(database: SharedStoreDatabase)`; `SharedStoreService.shared` bleibt und hält
///   `container.publicCloudDatabase` in der intern lesbaren Eigenschaft `database`.
/// - Der Fake erreicht `syncToCloud` über den vorhandenen Push-Pfad `push(store:)`. Dessen Ergebnis-Tupel
///   bekommt das zusätzliche, benannte Element `usedSchemaFallback: Bool` (Aufrufer lesen das Tupel nur
///   über Namen, `SyncCoordinator.swift:88-91`; die Signatur bleibt sonst gleich).
/// - `SyncCoordinator.shared.sharedStoreService: SharedStoreService` (setzbar, Vorgabe `.shared`), damit
///   `SyncCoordinator.push`/`pull` im Test den Fake benutzen.
/// - `SyncCoordinator.lastFailureKind` wird optional (`SyncFailureKind?`, `nil` = kein Fehler); nur so
///   ist „zurückgesetzt“ (AC-10) beobachtbar und passt zu `SyncBanner.decision(kind:)`.
/// - `SyncCoordinator.SyncFailureKind.schemaIncomplete`, `SyncCoordinator.lastFailureDetail: String`.
/// - `SharedStoreSchema.optionalExtensionFields`, `SharedStoreSchema.isProductionSchemaRejection(_:)`.
/// - `SyncBanner.decision(syncFailed:kind:developerMode:detail:) -> SyncBanner.Decision`
///   (`isVisible`, `text`, `detailLine: String?`).
/// - `SyncLog.message(for:) -> String`.
///
/// Abweichung von der Spec-Skizze des Fakes: `CKRecord.modificationDate` ist nur vom Server setzbar,
/// der Fake gibt daher keine eigene `modificationDate` zurück. `syncToCloud` setzt den Wasserstand dann
/// auf `Date()` (`saved.modificationDate ?? Date()`); geprüft wird nur „vorgerückt“ bzw. „unverändert“.
///
/// Der Fake prüft vorhandene UND geänderte Felder (`allKeys()` ∪ `changedKeys()`) gegen sein Schema.
/// Grund (lokal geprüft): Nach `record[field] = nil` fehlt das Feld in `allKeys()`, steht aber weiter
/// in `changedKeys()`; beim Speichern ginge damit eine Feld-Änderung an den Server, die die echte
/// Produktion ablehnen könnte (nicht belegt). Der Fallback-Record darf die Erweiterungsfelder daher
/// in keiner der beiden Mengen tragen (T1, T2). AC-3 legt nur das Ergebnis fest, nicht den
/// Mechanismus; ein `record[field] = nil` auf demselben Record genügt dafür nicht.
///
/// T4b (AC-5, zweiter Teil): Fallback und Wiederholung bei `serverRecordChanged` lösen sich nicht
/// endlos aus — höchstens drei Speicherversuche (Erstversuch, ein Fallback, eine Wiederholung).
///
/// OFFENE GRENZE: Echtes Speichern gegen die CloudKit-Produktion ist nicht automatisiert prüfbar; der
/// Fake ist die Ersatzprüfung.
@MainActor
final class SharedStoreSchemaTests: XCTestCase {

    static let coreFields: Set<String> = [
        "storeName", "storeEmoji", "storeColorHex", "ownerDevice",
        "itemsJSON", "membersJSON", "deletedJSON", "pricesJSON",
    ]
    static let extensionFields: Set<String> = ["categoriesJSON", "assignmentsJSON"]
    static let schemaRejectionText =
        "Cannot create or modify field 'categoriesJSON' in record 'SharedStore' in production schema"
    static let schemaIncompleteText =
        "Server-Einrichtung unvollständig — Kategorien und gemerkte Zuordnungen werden noch nicht geteilt; Artikel gleichen ab"
    static let otherFailureText =
        "Sync fehlgeschlagen — Änderungen werden möglicherweise nicht mit anderen geteilt"

    private var container: ModelContainer!
    private var context: ModelContext!
    private var shareIDs: [String] = []
    private var storeIDs: [UUID] = []
    private var originalContext: ModelContext?
    private var originalService: SharedStoreService?

    override func setUpWithError() throws {
        let leftovers = Self.utSyncKeys()
        XCTAssertEqual(leftovers, [], "Sync-Schlüssel eines früheren Tests wurden nicht aufgeräumt")
        leftovers.forEach(UserDefaults.standard.removeObject(forKey:))
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        originalContext = SyncCoordinator.shared.modelContext
        SyncCoordinator.shared.modelContext = context
        originalService = SyncCoordinator.shared.sharedStoreService
    }

    override func tearDown() {
        if let originalService { SyncCoordinator.shared.sharedStoreService = originalService }
        SyncCoordinator.shared.modelContext = originalContext
        removeSyncKeys()
        XCTAssertEqual(Self.utSyncKeys(), [], "tearDown hat Sync-Schlüssel stehen lassen")
        container = nil
        context = nil
    }

    // MARK: - T1 (RED): Push gegen die Produktion ohne die zwei Erweiterungsfelder

    /// Ist-Zustand der PO-Meldung: Mit dem Code vor dem Fallback wirft der Push „production schema“
    /// (der Fake protokolliert die Ablehnung). Nach der Umsetzung gelingt er.
    func testT1_pushAgainstProductionSchemaWithoutExtensionFieldsSucceeds() async throws {
        let fake = FakeSharedStoreDatabase(allowedFields: Self.coreFields)
        let service = SharedStoreService(database: fake)
        let store = makeSharedStore()

        do {
            _ = try await service.push(store: store)
        } catch {
            XCTFail("Push scheitert an der Produktion: \(SyncLog.message(for: error))")
        }
        XCTAssertTrue(fake.rejections.contains { SharedStoreSchema.isProductionSchemaRejection($0) },
                      "Der Fake hat den ersten Speicherversuch wegen Produktions-Schema abgelehnt")
        assertNoExtensionFields(in: try XCTUnwrap(fake.lastSaved, "kein Record gespeichert"))
    }

    // MARK: - T2: Fallback speichert einmal ohne Erweiterungsfelder

    func testT2_fallbackSavesOnceMoreWithCoreFieldsOnly() async throws {
        let fake = FakeSharedStoreDatabase(allowedFields: Self.coreFields)
        let service = SharedStoreService(database: fake)
        let store = makeSharedStore()
        let item = makeItem(in: store, name: "Milch")
        store.learnedPrices = ["milch": 1.29]
        store.learnedPriceDates = ["milch": Date(timeIntervalSince1970: 2_000_000)]
        store.learnedPriceUnits = ["milch": "stk"]
        store.customCategoryEntries = ["Kühltheke": CustomCategoryEntry(emoji: "🧊", date: Date())]

        let result = try await service.push(store: store)

        XCTAssertEqual(result?.usedSchemaFallback, true, "syncToCloud meldet, dass das Fallback griff")
        XCTAssertEqual(fake.saveAttempts, 2, "genau ein zusätzlicher Speicherversuch")
        let saved = try XCTUnwrap(fake.lastSaved)
        XCTAssertEqual(Set(saved.allKeys()), Self.coreFields, "alle Kernfelder, keine Erweiterungsfelder")
        assertNoExtensionFields(in: saved)
        let items = await service.decodeItems(saved["itemsJSON"] as? String ?? "[]")
        XCTAssertEqual(items.map(\.id), [item.id], "Artikel gleichen ab")
        XCTAssertEqual(LearnedPriceSync.decode(saved["pricesJSON"] as? String ?? "{}").prices, ["milch": 1.29])
        let members = await service.decodeMembers(saved["membersJSON"] as? String ?? "[]")
        XCTAssertTrue(members.contains(UserIdentity.displayName) || UserIdentity.displayName.isEmpty)
        XCTAssertEqual(result?.categories["Kühltheke"]?.emoji, "🧊", "lokale Kategorien bleiben im Ergebnis")
        let lastSync = await service.lastSyncDate(shareID: try XCTUnwrap(store.shareID))
        XCTAssertNotEqual(lastSync, .distantPast, "Wasserstand rückt nach erfolgreichem Speichern vor")
    }

    // MARK: - T3: andere Fehler lösen kein Fallback aus

    func testT3_otherErrorsDoNotTriggerFallback() async throws {
        let cases: [(CKError.Code, SyncCoordinator.SyncFailureKind)] = [
            (.networkUnavailable, .other),
            (.permissionFailure, .permissionDenied),
            (.notAuthenticated, .notAuthenticated),
        ]
        for (code, expectedKind) in cases {
            let fake = FakeSharedStoreDatabase(allowedFields: nil)
            fake.saveError = CKError(code)
            let service = SharedStoreService(database: fake)
            let store = makeSharedStore()

            do {
                _ = try await service.push(store: store)
                XCTFail("\(code): Push hätte werfen müssen")
            } catch let error as CKError {
                XCTAssertEqual(error.code, code, "\(code): der ursprüngliche Fehler wird geworfen")
            }
            XCTAssertEqual(fake.saveAttempts, 1, "\(code): kein Fallback, genau ein Speicherversuch")

            let coordinatorFake = FakeSharedStoreDatabase(allowedFields: nil)
            coordinatorFake.saveError = CKError(code)
            SyncCoordinator.shared.sharedStoreService = SharedStoreService(database: coordinatorFake)
            let ok = await SyncCoordinator.shared.push(store: makeSharedStore())
            XCTAssertFalse(ok)
            XCTAssertEqual(SyncCoordinator.shared.lastFailureKind, expectedKind, "\(code): Klassifizierung wie bisher")
            XCTAssertEqual(coordinatorFake.saveAttempts, 1)
        }
    }

    // MARK: - T4: auch der zweite Versuch scheitert

    func testT4_fallbackFailingThrowsAfterTwoAttemptsAndKeepsWatermark() async throws {
        let fake = FakeSharedStoreDatabase(allowedFields: Self.coreFields)
        fake.rejectEverySave = true
        let service = SharedStoreService(database: fake)
        let store = makeSharedStore()
        let shareID = try XCTUnwrap(store.shareID)

        do {
            _ = try await service.push(store: store)
            XCTFail("Push hätte werfen müssen")
        } catch {
            XCTAssertTrue(SharedStoreSchema.isProductionSchemaRejection(error), "Fehler des zweiten Versuchs")
        }
        XCTAssertEqual(fake.saveAttempts, 2, "genau zwei Versuche, kein dritter")
        let lastSync = await service.lastSyncDate(shareID: shareID)
        XCTAssertEqual(lastSync, .distantPast, "Wasserstand bleibt bei fehlgeschlagenem Speichern")
    }

    // MARK: - T4b: Fallback und serverRecordChanged begrenzen sich gegenseitig (AC-5)

    /// Zwei Drehbücher: (A) Schema-Ablehnung zuerst, danach abwechselnd; (B) `serverRecordChanged`
    /// zuerst, danach abwechselnd. In beiden Fällen höchstens drei Speicherversuche, dann wird ein
    /// CloudKit-Fehler geworfen — nie die Obergrenze des Fakes (= Endlosschleife).
    func testT4b_fallbackAndServerRecordChangedRetryStayBounded() async throws {
        for schemaFirst in [true, false] {
            let label = schemaFirst ? "(A) Schema zuerst" : "(B) serverRecordChanged zuerst"
            let fake = FakeSharedStoreDatabase(allowedFields: Self.coreFields)
            fake.scriptedError = { attempt, record in
                let schemaTurn = (attempt % 2 == 1) == schemaFirst
                if schemaTurn { return FakeSharedStoreDatabase.schemaRejection() }
                let server = CKRecord(recordType: "SharedStore", recordID: record.recordID)
                server["storeName"] = "Server" as CKRecordValue
                return FakeSharedStoreDatabase.serverRecordChanged(serverRecord: server)
            }
            let service = SharedStoreService(database: fake)
            let store = makeSharedStore()
            let shareID = try XCTUnwrap(store.shareID)

            do {
                _ = try await service.push(store: store)
                XCTFail("\(label): Push hätte werfen müssen")
            } catch let error as CKError {
                XCTAssertTrue(error.code == .serverRecordChanged || SharedStoreSchema.isProductionSchemaRejection(error),
                              "\(label): Fehler des letzten Versuchs wird geworfen, nicht \(error)")
            } catch {
                XCTFail("\(label): Obergrenze des Fakes erreicht oder fremder Fehler: \(error)")
            }
            XCTAssertLessThanOrEqual(fake.saveAttempts, 3,
                                     "\(label): höchstens Erstversuch + ein Fallback + eine Wiederholung")
            XCTAssertLessThan(fake.saveAttempts, FakeSharedStoreDatabase.attemptCeiling)
            let lastSync = await service.lastSyncDate(shareID: shareID)
            XCTAssertEqual(lastSync, .distantPast, "\(label): Wasserstand bleibt")
        }
    }

    // MARK: - T5: vollständiges Produktions-Schema

    func testT5_fullSchemaSavesOnceWithExtensionFields() async throws {
        let fake = FakeSharedStoreDatabase(allowedFields: Self.coreFields.union(Self.extensionFields))
        let service = SharedStoreService(database: fake)
        let store = makeSharedStore()

        let result = try await service.push(store: store)

        XCTAssertEqual(result?.usedSchemaFallback, false)
        XCTAssertEqual(fake.saveAttempts, 1)
        let saved = try XCTUnwrap(fake.lastSaved)
        XCTAssertTrue(Self.extensionFields.isSubset(of: Set(saved.allKeys())),
                      "categoriesJSON und assignmentsJSON werden geschrieben")
        XCTAssertTrue(fake.rejections.isEmpty)
    }

    // MARK: - T6: Erkennung der Ablehnung (Textregel)

    func testT6_productionSchemaRejectionDetection() {
        XCTAssertEqual(SharedStoreSchema.optionalExtensionFields, ["categoriesJSON", "assignmentsJSON"])

        let otherCase = CKError(.serverRejectedRequest, userInfo: [
            "ServerErrorDescription": "Cannot create or modify field 'assignmentsJSON' in record 'SharedStore' in Production SCHEMA",
        ])
        XCTAssertTrue(SharedStoreSchema.isProductionSchemaRejection(otherCase), "Groß/Klein egal")

        let viaLocalized = CKError(.invalidArguments, userInfo: [
            NSLocalizedDescriptionKey: "Cannot create or modify field 'categoriesJSON' in record 'SharedStore' in production schema",
        ])
        XCTAssertTrue(viaLocalized.localizedDescription.contains("production schema"), "Vorbedingung des Tests")
        XCTAssertTrue(SharedStoreSchema.isProductionSchemaRejection(viaLocalized),
                      "ohne ServerErrorDescription zählt localizedDescription")

        let network = CKError(.networkUnavailable, userInfo: ["ServerErrorDescription": "Network unavailable"])
        XCTAssertFalse(SharedStoreSchema.isProductionSchemaRejection(network))

        let recordID = CKRecord.ID(recordName: "UT-PARTIAL")
        let partialSchema = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [recordID: FakeSharedStoreDatabase.schemaRejection()],
        ])
        XCTAssertTrue(SharedStoreSchema.isProductionSchemaRejection(partialSchema), "Teilfehler zählen")
        let partialNetwork = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: network]])
        XCTAssertFalse(SharedStoreSchema.isProductionSchemaRejection(partialNetwork))
    }

    // MARK: - T7: Zustand im SyncCoordinator

    func testT7_coordinatorStateSetAndReset() async throws {
        let store = makeSharedStore()

        let production = FakeSharedStoreDatabase(allowedFields: Self.coreFields)
        SyncCoordinator.shared.sharedStoreService = SharedStoreService(database: production)
        let fallbackOK = await SyncCoordinator.shared.push(store: store)
        XCTAssertTrue(fallbackOK, "Kern abgeglichen, Push liefert true")
        XCTAssertEqual(SyncCoordinator.shared.lastFailureKind, .schemaIncomplete)
        XCTAssertTrue(SyncCoordinator.shared.lastFailureDetail.lowercased().contains("production schema"),
                      "Detail benennt die Ablehnungsursache: \(SyncCoordinator.shared.lastFailureDetail)")

        let full = FakeSharedStoreDatabase(allowedFields: nil)
        SyncCoordinator.shared.sharedStoreService = SharedStoreService(database: full)
        let fullOK = await SyncCoordinator.shared.push(store: store)
        XCTAssertTrue(fullOK)
        XCTAssertNil(SyncCoordinator.shared.lastFailureKind, "vollständiger Push setzt den Zustand zurück")

        full.saveError = CKError(.networkUnavailable)
        let failed = await SyncCoordinator.shared.push(store: store)
        XCTAssertFalse(failed)
        XCTAssertEqual(SyncCoordinator.shared.lastFailureKind, .other)
        XCTAssertFalse(SyncCoordinator.shared.lastFailureDetail.isEmpty, "Detail nach Fehler gesetzt")

        let pulled = await SyncCoordinator.shared.pull(store: store)
        XCTAssertTrue(pulled)
        XCTAssertNil(SyncCoordinator.shared.lastFailureKind, "nach erfolgreichem Pull kein alter Fehler")
    }

    // MARK: - T8: Drift-Test der Feldliste

    func testT8_sharedStoreFieldListMatchesPublishedSchema() async throws {
        let store = makeSharedStore()
        let code = try XCTUnwrap(store.shareID)
        let record = CKRecord(recordType: "SharedStore", recordID: CKRecord.ID(recordName: code))

        _ = await SharedStoreService.shared.mergeIntoRecord(record, store: store, code: code, isNewRecord: true)

        XCTAssertEqual(
            Set(record.allKeys()), Self.coreFields.union(Self.extensionFields),
            "Felder von SharedStore geändert: CloudKit-Schema vor dem TestFlight-Upload veröffentlichen (docs/testflight-setup.md)"
        )
    }

    // MARK: - T13: Banner-Entscheidung

    func testT13_bannerDecision() {
        let detail = "CKErrorDomain 15: Cannot create or modify field 'categoriesJSON' in record 'SharedStore' in production schema"

        let a = SyncBanner.decision(syncFailed: false, kind: .schemaIncomplete, developerMode: false, detail: detail)
        XCTAssertTrue(a.isVisible, "(a) sichtbar, obwohl der Push als Erfolg zählte")
        XCTAssertEqual(a.text, Self.schemaIncompleteText)
        XCTAssertNil(a.detailLine, "(a) ohne Entwicklermodus keine Detailzeile")

        let b = SyncBanner.decision(syncFailed: true, kind: .other, developerMode: false, detail: detail)
        XCTAssertTrue(b.isVisible)
        XCTAssertEqual(b.text, Self.otherFailureText, "(b) bisheriger Text wörtlich")
        XCTAssertNil(b.detailLine)

        let c = SyncBanner.decision(syncFailed: false, kind: nil, developerMode: true, detail: "")
        XCTAssertFalse(c.isVisible, "(c) kein Fehler, kein Banner")

        let d = SyncBanner.decision(syncFailed: false, kind: .schemaIncomplete, developerMode: true, detail: detail)
        XCTAssertTrue(d.isVisible)
        XCTAssertEqual(d.text, Self.schemaIncompleteText)
        XCTAssertEqual(d.detailLine, detail, "(d) Entwicklermodus zeigt die Detailzeile")

        let permission = SyncBanner.decision(syncFailed: true, kind: .permissionDenied, developerMode: true, detail: detail)
        XCTAssertEqual(permission.text,
                       "Keine Schreibberechtigung für diese geteilte Liste — deine Änderungen erreichen die anderen Mitglieder nicht")
        XCTAssertEqual(permission.detailLine, detail, "Detailzeile auch bei Syncfehlern im Entwicklermodus")

        let login = SyncBanner.decision(syncFailed: true, kind: .notAuthenticated, developerMode: false, detail: detail)
        XCTAssertEqual(login.text,
                       "Nicht bei iCloud angemeldet — Änderungen werden nicht geteilt (Einstellungen → beim iPhone anmelden)")
    }

    // MARK: - T14: Log-Meldung ohne Personendaten

    func testT14_logMessageHasDomainCodeTextAndNoPersonalData() {
        let shareCode = "UTGEHEIM42"
        let serverRecord = CKRecord(recordType: "SharedStore", recordID: CKRecord.ID(recordName: shareCode))
        serverRecord["storeName"] = "Geheimladen" as CKRecordValue
        serverRecord["ownerDevice"] = "Anna Geheimname" as CKRecordValue
        serverRecord["itemsJSON"] = "[{\"name\":\"Geheimartikel\"}]" as CKRecordValue
        let error = CKError(.serverRejectedRequest, userInfo: [
            "ServerErrorDescription": Self.schemaRejectionText,
            CKRecordChangedErrorServerRecordKey: serverRecord,
        ])

        let message = SyncLog.message(for: error)

        XCTAssertTrue(message.contains(CKErrorDomain), "Domain: \(message)")
        XCTAssertTrue(message.contains("\(CKError.Code.serverRejectedRequest.rawValue)"), "Code: \(message)")
        XCTAssertTrue(message.contains(Self.schemaRejectionText), "Fehlertext: \(message)")
        for secret in ["Geheimladen", "Anna Geheimname", "Geheimartikel", shareCode] {
            XCTAssertFalse(message.contains(secret), "Personendaten im Log: \(secret)")
        }
    }

    // MARK: - T15: Produktivdatenbank bleibt die öffentliche

    func testT15_defaultDatabaseIsPublicCloudDatabase() async throws {
        let database = await SharedStoreService.shared.database
        let ckDatabase = try XCTUnwrap(database as? CKDatabase, "Produktivinstanz ist eine CKDatabase")
        XCTAssertEqual(ckDatabase.databaseScope, .public)
        // Übersetzbarkeit: CKDatabase erfüllt das Protokoll.
        let conforming: SharedStoreDatabase = ckDatabase
        XCTAssertNotNil(conforming)
    }

    // MARK: - Helpers

    /// Fallback-Record: Erweiterungsfelder weder vorhanden noch als geändert markiert.
    private func assertNoExtensionFields(in record: CKRecord, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(Self.extensionFields.isDisjoint(with: record.allKeys()),
                      "Erweiterungsfelder in allKeys(): \(record.allKeys())", file: file, line: line)
        XCTAssertTrue(Self.extensionFields.isDisjoint(with: record.changedKeys()),
                      "Erweiterungsfelder in changedKeys(): \(record.changedKeys())", file: file, line: line)
    }

    private func makeSharedStore() -> Store {
        let store = Store(name: "Testladen", emoji: "🛒", colorHex: "#4A90D9")
        context.insert(store)
        storeIDs.append(store.id)
        let shareID = "UT-\(UUID().uuidString)"
        store.shareID = shareID
        shareIDs.append(shareID)
        return store
    }

    private func makeItem(in store: Store, name: String) -> ShoppingItem {
        let item = ShoppingItem(name: name, store: store)
        context.insert(item)
        return item
    }

    private func removeSyncKeys() {
        let defaults = UserDefaults.standard
        for id in shareIDs {
            defaults.removeObject(forKey: "lastSync_\(id)")
            defaults.removeObject(forKey: "deletedTombstones_\(id)")
        }
        for id in storeIDs {
            for prefix in ["shareID_", "members_", "isSharedByMe_"] {
                defaults.removeObject(forKey: "\(prefix)\(id.uuidString)")
            }
        }
        shareIDs = []
        storeIDs = []
    }

    private static func utSyncKeys() -> [String] {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("lastSync_UT-") || $0.hasPrefix("deletedTombstones_UT-") }
            .sorted()
    }
}

/// Fake der CloudKit-Produktion: kennt nur `allowedFields` (`nil` = jedes Feld erlaubt) und lehnt
/// Records mit anderen Feldern wie die Produktion ab. Zählt Speicherversuche.
final class FakeSharedStoreDatabase: SharedStoreDatabase, @unchecked Sendable {
    private let lock = NSLock()
    private let allowedFields: Set<String>?
    private var stored: [CKRecord.ID: CKRecord] = [:]
    private var _saveAttempts = 0
    private var _rejections: [Error] = []
    private var _lastSaved: CKRecord?
    private var _saveError: Error?
    private var _rejectEverySave = false
    private var _scriptedError: ((Int, CKRecord) -> Error?)?

    init(allowedFields: Set<String>?) {
        self.allowedFields = allowedFields
    }

    var saveAttempts: Int { lock.withLock { _saveAttempts } }
    var rejections: [Error] { lock.withLock { _rejections } }
    var lastSaved: CKRecord? { lock.withLock { _lastSaved } }
    /// Jeder Speicherversuch wirft diesen Fehler (Netz, Berechtigung, Anmeldung).
    var saveError: Error? {
        get { lock.withLock { _saveError } }
        set { lock.withLock { _saveError = newValue } }
    }
    /// Jeder Speicherversuch wird wegen Produktions-Schema abgelehnt (auch das Fallback).
    var rejectEverySave: Bool {
        get { lock.withLock { _rejectEverySave } }
        set { lock.withLock { _rejectEverySave = newValue } }
    }

    /// Fehler je Speicherversuch (1-basiert) nach Drehbuch; `nil` = normale Schema-Prüfung.
    var scriptedError: ((Int, CKRecord) -> Error?)? {
        get { lock.withLock { _scriptedError } }
        set { lock.withLock { _scriptedError = newValue } }
    }

    /// Obergrenze gegen Endlosschleifen: ab dem 11. Versuch wirft der Fake `ceilingReached`.
    /// Ein Test, der diesen Fehler sieht, hat eine fehlende Begrenzung gefunden.
    static let attemptCeiling = 10
    static let ceilingReached = NSError(domain: "FakeSharedStoreDatabase.ceiling", code: 999, userInfo: [
        NSLocalizedDescriptionKey: "Obergrenze von \(attemptCeiling) Speicherversuchen erreicht — Endlosschleife",
    ])

    static func serverRecordChanged(serverRecord: CKRecord) -> CKError {
        CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord])
    }

    static func schemaRejection(field: String = "categoriesJSON") -> CKError {
        CKError(.serverRejectedRequest, userInfo: [
            "ServerErrorDescription": "Cannot create or modify field '\(field)' in record 'SharedStore' in production schema",
        ])
    }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        try lock.withLock {
            guard let record = stored[recordID] else { throw CKError(.unknownItem) }
            return record
        }
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        try lock.withLock {
            _saveAttempts += 1
            if _saveAttempts > Self.attemptCeiling { throw Self.ceilingReached }
            if let error = _saveError { throw error }
            if let script = _scriptedError, let error = script(_saveAttempts, record) { throw error }
            // Geprüft werden vorhandene UND geänderte Felder: `record[field] = nil` entfernt das
            // Feld aus `allKeys()`, lässt es aber in `changedKeys()` — beim Speichern ginge eine
            // Feld-Änderung an den Server, die die Produktion ablehnen könnte.
            let touched = Set(record.allKeys()).union(record.changedKeys())
            let unknown = allowedFields.map { touched.subtracting($0).sorted() } ?? []
            if _rejectEverySave || !unknown.isEmpty {
                let error = Self.schemaRejection(field: unknown.first ?? "categoriesJSON")
                _rejections.append(error)
                throw error
            }
            stored[record.recordID] = record
            _lastSaved = record
            return record
        }
    }
}
