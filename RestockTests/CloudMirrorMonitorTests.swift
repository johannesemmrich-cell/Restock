import XCTest
import CloudKit
import CoreData
@testable import Restock

/// Issue #156, Teil A und B2.1: Zusammenfassung von Spiegelungsfehlern, Statusablage, Prozessprüfung,
/// Warte-Entscheidung des Onboardings und Untertitel der Dev-Zeile „iCloud-Abgleich“.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md` (T1–T8; AC-1 bis AC-5, AC-13).
///
/// Offene Grenze (Spec): Der Live-Weg eines echten Export-Ereignisses aus Production ist hier nicht
/// geprüft; die Fehler sind nachgebaut. Jeder Test der Statusablage nutzt eine eigene
/// `UserDefaults`-Suite und entfernt sie im `tearDown()`.
final class CloudMirrorMonitorTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "CloudMirrorMonitorTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Hilfen

    private static let schemaText =
        "Cannot create or modify field 'CD_photoData_ckAsset' in record 'CD_ShoppingItem' in production schema"

    private func batchFailed() -> NSError {
        CKError(.batchRequestFailed) as NSError
    }

    private func itemError(_ code: CKError.Code, _ text: String) -> NSError {
        CKError(code, userInfo: [NSLocalizedDescriptionKey: text]) as NSError
    }

    private func partialFailure(_ entries: [NSError]) -> CKError {
        var byID: [CKRecord.ID: NSError] = [:]
        for (index, entry) in entries.enumerated() {
            byID[CKRecord.ID(recordName: "UT-record-\(index)")] = entry
        }
        return CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: byID])
    }

    private func mirrorKeys() -> [String] {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("smartcart.cloudMirror.") }.sorted()
    }

    private func time(hour: Int, minute: Int) throws -> Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        parts.hour = hour
        parts.minute = minute
        return try XCTUnwrap(Calendar.current.date(from: parts))
    }

    // MARK: - T1 (AC-1)

    func testPartialFailureReportsNonBatchError() {
        // GIVEN ein partialFailure mit zwei batchRequestFailed und einem CD_ShoppingItem-Fehler
        let single = itemError(.serverRejectedRequest, "Record type CD_ShoppingItem rejected by server")
        let error = partialFailure([batchFailed(), single, batchFailed()])

        // WHEN summarize
        let summary = CloudMirrorMonitor.summarize(error: error)

        // THEN wird nur der Einzelfehler gemeldet, samt „1 von 3“
        XCTAssertEqual(summary.domain, CKError.errorDomain)
        XCTAssertEqual(summary.code, CKError.Code.serverRejectedRequest.rawValue)
        XCTAssertTrue(summary.detail.contains("CD_ShoppingItem"), "Detail: \(summary.detail)")
        XCTAssertEqual(summary.failedItemCount, 1)
        XCTAssertEqual(summary.totalItemCount, 3)
        XCTAssertEqual(summary.itemCountText, "1 von 3")
    }

    // MARK: - T2 + T3 (AC-2)

    func testFallbackAndUnderlyingError() {
        // GIVEN partialFailure nur mit batchRequestFailed
        let onlyBatch = partialFailure([batchFailed(), batchFailed()])
        // WHEN summarize THEN wird der Fehler der obersten Ebene gemeldet
        let batchSummary = CloudMirrorMonitor.summarize(error: onlyBatch)
        XCTAssertEqual(batchSummary.domain, CKError.errorDomain)
        XCTAssertEqual(batchSummary.code, CKError.Code.partialFailure.rawValue)

        // GIVEN ein Fehler ohne Teilfehler WHEN summarize THEN oberster Fehler
        let plain = itemError(.networkUnavailable, "Network unavailable")
        let plainSummary = CloudMirrorMonitor.summarize(error: plain)
        XCTAssertEqual(plainSummary.code, CKError.Code.networkUnavailable.rawValue)
        XCTAssertNil(plainSummary.itemCountText)

        // GIVEN der Einzelfehler liegt im partialFailure unter NSUnderlyingError eines Core-Data-Fehlers (T3)
        let single = itemError(.serverRejectedRequest, "Record type CD_ShoppingItem rejected by server")
        let nested = partialFailure([batchFailed(), single])
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_419,
                              userInfo: [NSUnderlyingErrorKey: nested])
        // WHEN summarize THEN wird der verschachtelte Einzelfehler gefunden
        let nestedSummary = CloudMirrorMonitor.summarize(error: wrapped)
        XCTAssertEqual(nestedSummary.domain, CKError.errorDomain)
        XCTAssertEqual(nestedSummary.code, CKError.Code.serverRejectedRequest.rawValue)
        XCTAssertTrue(nestedSummary.detail.contains("CD_ShoppingItem"), "Detail: \(nestedSummary.detail)")
        XCTAssertEqual(nestedSummary.itemCountText, "1 von 2")
    }

    // MARK: - T4 (AC-3)

    func testProductionSchemaTextIsClassified() {
        // GIVEN Fehlertext „… in production schema“, einmal direkt, einmal als Einzelfehler im partialFailure
        let direct = itemError(.serverRejectedRequest, Self.schemaText)
        let partial = partialFailure([batchFailed(), itemError(.invalidArguments, Self.schemaText)])

        // WHEN summarize
        let directSummary = CloudMirrorMonitor.summarize(error: direct)
        let partialSummary = CloudMirrorMonitor.summarize(error: partial)

        // THEN Art schemaIncomplete
        XCTAssertEqual(directSummary.kind, .schemaIncomplete)
        XCTAssertEqual(partialSummary.kind, .schemaIncomplete)
        // Gegenprobe: ein anderer Fehler ist nicht schemaIncomplete
        XCTAssertNotEqual(CloudMirrorMonitor.summarize(error: itemError(.networkFailure, "offline")).kind,
                          .schemaIncomplete)
    }

    // MARK: - T5 (AC-4)

    func testHandlePersistsOnlyFinishedEvents() throws {
        // GIVEN eine leere Statusablage auf eigener Suite
        let store = CloudMirrorStatusStore(defaults: defaults)
        let monitor = CloudMirrorMonitor(statusStore: store)
        XCTAssertNil(store.lastRun(.export))
        let failedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let succeededAt = failedAt.addingTimeInterval(60)

        // WHEN ein laufendes Ereignis (endDate == nil) eintrifft THEN ändert sich nichts
        monitor.handle(type: .export, succeeded: false, error: itemError(.serverRejectedRequest, "x"), endDate: nil)
        XCTAssertEqual(mirrorKeys(), [], "Laufendes Ereignis hat geschrieben")

        // WHEN ein beendeter Export scheitert THEN Zeit, Zusammenfassung und Zähler
        let error = partialFailure([batchFailed(), itemError(.serverRejectedRequest, Self.schemaText)])
        monitor.handle(type: .export, succeeded: false, error: error, endDate: failedAt)
        let failed = try XCTUnwrap(store.lastRun(.export))
        XCTAssertEqual(failed.date, failedAt)
        XCTAssertFalse(failed.succeeded)
        XCTAssertTrue(failed.summary?.detail.contains("CD_ShoppingItem") == true, "Zusammenfassung fehlt")
        XCTAssertEqual(store.exportFailureCount, 1)
        XCTAssertEqual(store.exportSuccessCount, 0)

        // WHEN danach ein Export gelingt und ein Import endet THEN Erfolg, Zähler, Import getrennt
        monitor.handle(type: .export, succeeded: true, error: nil, endDate: succeededAt)
        monitor.handle(type: .import, succeeded: true, error: nil, endDate: succeededAt)
        XCTAssertEqual(store.lastRun(.export)?.succeeded, true)
        XCTAssertEqual(store.lastRun(.export)?.date, succeededAt)
        XCTAssertEqual(store.lastRun(.import)?.succeeded, true)
        XCTAssertEqual(store.exportFailureCount, 1)
        XCTAssertEqual(store.exportSuccessCount, 1)

        // Alle Schlüssel tragen das Präfix, clear() entfernt sie (Grundlage von -clearCloudMirrorStatusForUITests)
        XCTAssertFalse(mirrorKeys().isEmpty)
        store.clear()
        XCTAssertEqual(mirrorKeys(), [])
        XCTAssertNil(store.lastRun(.export))
    }

    // MARK: - T6 (AC-5)

    func testObserveOnlyInAppProcess() {
        // GIVEN Bundle-URLs von App und Teilen-Erweiterung
        let app = URL(fileURLWithPath: "/private/var/containers/Bundle/Application/X/Restock.app")
        let appex = app.appendingPathComponent("PlugIns/RestockShareExtension.appex")

        // WHEN shouldObserve THEN nur im App-Prozess
        XCTAssertTrue(CloudMirrorMonitor.shouldObserve(bundleURL: app))
        XCTAssertFalse(CloudMirrorMonitor.shouldObserve(bundleURL: appex))
    }

    // MARK: - T7 (AC-13)

    func testOnboardingGateDecisions() {
        typealias Gate = OnboardingCloudGate
        // GIVEN kein Konto WHEN decision THEN .proceed (kein Warten)
        XCTAssertEqual(Gate.decision(accountAvailable: false, firstImportFinished: false, storeCount: 0, elapsed: 0), .proceed)
        // GIVEN Konto, Import läuft, 3 s WHEN decision THEN .wait
        XCTAssertEqual(Gate.decision(accountAvailable: true, firstImportFinished: false, storeCount: 0, elapsed: 3), .wait)
        // GIVEN Konto, Import läuft, 10 s WHEN decision THEN .proceed (Frist abgelaufen)
        XCTAssertEqual(Gate.decision(accountAvailable: true, firstImportFinished: false, storeCount: 0, elapsed: 10), .proceed)
        // GIVEN Import fertig ohne Läden WHEN decision THEN .proceed
        XCTAssertEqual(Gate.decision(accountAvailable: true, firstImportFinished: true, storeCount: 0, elapsed: 1), .proceed)
        // GIVEN Läden sind angekommen WHEN decision THEN .skipOnboarding
        XCTAssertEqual(Gate.decision(accountAvailable: true, firstImportFinished: false, storeCount: 2, elapsed: 2), .skipOnboarding)
        XCTAssertEqual(Gate.decision(accountAvailable: true, firstImportFinished: true, storeCount: 2, elapsed: 5), .skipOnboarding)
    }

    // MARK: - T8 (Dev-Zeile „iCloud-Abgleich“, Grundlage AC-6)

    func testDevRowSubtitleForFailedSucceededAndNoRun() throws {
        // GIVEN letzter Export um 19:02 fehlgeschlagen bzw. erfolgreich, oder noch kein Lauf
        let at = try time(hour: 19, minute: 2)
        let summary = CloudMirrorMonitor.summarize(error: itemError(.serverRejectedRequest, Self.schemaText))
        let failed = CloudMirrorRun(date: at, succeeded: false, summary: summary)
        let succeeded = CloudMirrorRun(date: at, succeeded: true, summary: nil)

        // WHEN die Untertitelfunktion läuft
        let failedRow = CloudMirrorMonitor.devRowSubtitle(lastExport: failed)
        let succeededRow = CloudMirrorMonitor.devRowSubtitle(lastExport: succeeded)
        let noRunRow = CloudMirrorMonitor.devRowSubtitle(lastExport: nil)

        // THEN passen Text und Fehlerkennzeichen
        XCTAssertEqual(failedRow.text, "Export fehlgeschlagen · 19:02")
        XCTAssertTrue(failedRow.isFailure)
        XCTAssertEqual(succeededRow.text, "Export erfolgreich · 19:02")
        XCTAssertFalse(succeededRow.isFailure)
        XCTAssertEqual(noRunRow.text, "noch kein Lauf")
        XCTAssertFalse(noRunRow.isFailure)
    }
}
