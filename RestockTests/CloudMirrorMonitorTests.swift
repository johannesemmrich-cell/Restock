import XCTest
import CloudKit
import CoreData
@testable import Restock

/// Issue #156, Teil A und B2.1: Zusammenfassung von Spiegelungsfehlern, Statusablage, Prozessprüfung,
/// Warte-Entscheidung des Onboardings und Untertitel der Dev-Zeile „iCloud-Abgleich“.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md` (T1–T8; AC-1 bis AC-5, AC-13).
/// Issue #166: Einrichtungsläufe (`.setup`), Untertitel-Vorrang, Klartext 134400, Startreihenfolge.
/// Spec: `docs/specs/services/icloud-einrichtung-sichtbar.md` (T1–T6; AC-1 bis AC-5, AC-7).
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
        let failedRow = CloudMirrorMonitor.devRowSubtitle(lastSetup: nil, lastExport: failed)
        let succeededRow = CloudMirrorMonitor.devRowSubtitle(lastSetup: nil, lastExport: succeeded)
        let noRunRow = CloudMirrorMonitor.devRowSubtitle(lastSetup: nil, lastExport: nil)

        // THEN passen Text und Fehlerkennzeichen
        XCTAssertEqual(failedRow.text, "Export fehlgeschlagen · 19:02")
        XCTAssertTrue(failedRow.isFailure)
        XCTAssertEqual(succeededRow.text, "Export erfolgreich · 19:02")
        XCTAssertFalse(succeededRow.isFailure)
        XCTAssertEqual(noRunRow.text, "noch kein Lauf")
        XCTAssertFalse(noRunRow.isFailure)
    }

    // MARK: - #166 Hilfen

    private func noAccountError() -> NSError {
        NSError(domain: NSCocoaErrorDomain, code: 134_400)
    }

    // MARK: - #166 T1 (AC-1)

    func testSetupFailureIsStored() throws {
        // GIVEN eine leere Statusablage
        let store = CloudMirrorStatusStore(defaults: defaults)
        let monitor = CloudMirrorMonitor(statusStore: store)
        let failedAt = Date(timeIntervalSince1970: 1_800_000_000)

        // WHEN eine laufende Einrichtung (endDate == nil) eintrifft THEN ändert sich nichts
        monitor.handle(type: .setup, succeeded: false, error: noAccountError(), endDate: nil)
        XCTAssertEqual(mirrorKeys(), [], "Laufende Einrichtung hat geschrieben")

        // WHEN eine beendete Einrichtung mit 134400 scheitert
        monitor.handle(type: .setup, succeeded: false, error: noAccountError(), endDate: failedAt)

        // THEN steht sie als lastSetup in der Ablage, mit Domain und Code
        XCTAssertEqual(mirrorKeys(), ["smartcart.cloudMirror.lastSetup"])
        let setup = try XCTUnwrap(store.lastRun(.setup), "Einrichtung nicht gespeichert")
        XCTAssertEqual(setup.date, failedAt)
        XCTAssertFalse(setup.succeeded)
        XCTAssertEqual(setup.summary?.domain, NSCocoaErrorDomain)
        XCTAssertEqual(setup.summary?.code, 134_400)
        XCTAssertTrue(setup.summary?.detail.contains("134400") == true, "Detail: \(setup.summary?.detail ?? "nil")")
        // clear() erfasst auch den neuen Schlüssel (Grundlage von -clearCloudMirrorStatusForUITests)
        store.clear()
        XCTAssertEqual(mirrorKeys(), [])
    }

    // MARK: - #166 T2 (AC-2)

    /// `firstImportFinished` liest nur `lastRun(.import)`; bleibt der Import-Eintrag unverändert,
    /// reagiert das Onboarding nicht. `start()` wird hier bewusst nicht aufgerufen, weil der
    /// Beobachter sonst echte Ereignisse des Testprozesses in die Suite schreiben könnte.
    func testSetupLeavesCountersAndImportUntouched() throws {
        // GIVEN ein fehlgeschlagener Export und ein erfolgreicher Import
        let store = CloudMirrorStatusStore(defaults: defaults)
        let monitor = CloudMirrorMonitor(statusStore: store)
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        monitor.handle(type: .export, succeeded: false, error: itemError(.serverRejectedRequest, "x"), endDate: at)
        monitor.handle(type: .import, succeeded: true, error: nil, endDate: at)
        let exportBefore = store.lastRun(.export)
        let importBefore = store.lastRun(.import)

        // WHEN Einrichtungen scheitern und gelingen
        let later = at.addingTimeInterval(120)
        monitor.handle(type: .setup, succeeded: false, error: noAccountError(), endDate: later)
        monitor.handle(type: .setup, succeeded: true, error: nil, endDate: later.addingTimeInterval(1))

        // THEN Zähler, Export und Import unverändert, Einrichtung getrennt gespeichert
        XCTAssertEqual(store.exportFailureCount, 1)
        XCTAssertEqual(store.exportSuccessCount, 0)
        XCTAssertEqual(store.lastRun(.export), exportBefore)
        XCTAssertEqual(store.lastRun(.import), importBefore)
        XCTAssertEqual(store.lastRun(.setup)?.date, later.addingTimeInterval(1), "Einrichtung nicht gespeichert")
        XCTAssertFalse(monitor.firstImportFinished)
    }

    // MARK: - #166 T3 (AC-3)

    func testSetupSuccessReplacesFailure() throws {
        // GIVEN eine gescheiterte Einrichtung
        let store = CloudMirrorStatusStore(defaults: defaults)
        let monitor = CloudMirrorMonitor(statusStore: store)
        let failedAt = Date(timeIntervalSince1970: 1_800_000_000)
        monitor.handle(type: .setup, succeeded: false, error: noAccountError(), endDate: failedAt)
        XCTAssertEqual(store.lastRun(.setup)?.succeeded, false, "Fehler nicht gespeichert")

        // WHEN beim nächsten Start die Einrichtung gelingt
        let succeededAt = failedAt.addingTimeInterval(3600)
        monitor.handle(type: .setup, succeeded: true, error: nil, endDate: succeededAt)

        // THEN ist lastSetup erfolgreich und ohne Zusammenfassung
        let setup = try XCTUnwrap(store.lastRun(.setup))
        XCTAssertTrue(setup.succeeded)
        XCTAssertEqual(setup.date, succeededAt)
        XCTAssertNil(setup.summary)
    }

    // MARK: - #166 T4 (AC-4)

    func testSubtitlePrefersFailedSetupOverExport() throws {
        // GIVEN Einrichtung 22:54 gescheitert bzw. gelungen, Export 19:02 gescheitert bzw. gelungen
        let setupAt = try time(hour: 22, minute: 54)
        let exportAt = try time(hour: 19, minute: 2)
        let setupFailed = CloudMirrorRun(date: setupAt, succeeded: false,
                                         summary: CloudMirrorMonitor.summarize(error: noAccountError()))
        let setupOK = CloudMirrorRun(date: setupAt, succeeded: true, summary: nil)
        let exportOK = CloudMirrorRun(date: exportAt, succeeded: true, summary: nil)
        let exportFailed = CloudMirrorRun(date: exportAt, succeeded: false,
                                          summary: CloudMirrorMonitor.summarize(error: itemError(.serverRejectedRequest, "x")))

        // WHEN / THEN gescheiterte Einrichtung hat Vorrang, auch vor einem Export
        for export in [exportOK, exportFailed, nil] as [CloudMirrorRun?] {
            let row = CloudMirrorMonitor.devRowSubtitle(lastSetup: setupFailed, lastExport: export)
            XCTAssertEqual(row.text, "Einrichtung fehlgeschlagen · 22:54")
            XCTAssertTrue(row.isFailure)
        }
        // Erfolgreiche Einrichtung: bisherige Export-Logik
        let okFailed = CloudMirrorMonitor.devRowSubtitle(lastSetup: setupOK, lastExport: exportFailed)
        XCTAssertEqual(okFailed.text, "Export fehlgeschlagen · 19:02")
        XCTAssertTrue(okFailed.isFailure)
        let okOK = CloudMirrorMonitor.devRowSubtitle(lastSetup: setupOK, lastExport: exportOK)
        XCTAssertEqual(okOK.text, "Export erfolgreich · 19:02")
        XCTAssertFalse(okOK.isFailure)
        let okNone = CloudMirrorMonitor.devRowSubtitle(lastSetup: setupOK, lastExport: nil)
        XCTAssertEqual(okNone.text, "noch kein Lauf")
        XCTAssertFalse(okNone.isFailure)
    }

    // MARK: - #166 T5 (AC-5)

    func testPlainTextOnlyForKnownSetupCode() {
        // GIVEN Zusammenfassungen: 134400 aus NSCocoaErrorDomain, anderer Code, andere Domain mit 134400
        let noAccount = CloudMirrorMonitor.summarize(error: noAccountError())
        let otherCode = CloudMirrorMonitor.summarize(error: NSError(domain: NSCocoaErrorDomain, code: 134_419))
        let otherDomain = CloudMirrorMonitor.summarize(error: NSError(domain: CKError.errorDomain, code: 134_400))

        // WHEN / THEN nur der bekannte Code bekommt Klartext
        XCTAssertEqual(CloudMirrorMonitor.setupCauseText(for: noAccount), "kein iCloud-Konto")
        XCTAssertNil(CloudMirrorMonitor.setupCauseText(for: otherCode))
        XCTAssertNil(CloudMirrorMonitor.setupCauseText(for: otherDomain))
    }

    // MARK: - #166 T6 (AC-7)

    /// Der Beobachter muss in Ausführungsreihenfolge vor der Container-Erzeugung registriert sein
    /// (Apple Forum 701564). Ein Aufruf im `defer`-Block läuft erst nach `make()`, auch wenn er
    /// im Quelltext davor steht; deshalb zählt nur ein Aufruf außerhalb des `defer`-Blocks.
    func testObserverStartsBeforeContainerCreation() throws {
        // GIVEN der Quelltext von SmartCartApp.init()
        let appFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SmartCart/SmartCartApp.swift")
        let source = try String(contentsOf: appFile, encoding: .utf8)
        let initStart = try XCTUnwrap(source.range(of: "    init() {"), "init() nicht gefunden")
        let initBody = try XCTUnwrap(Self.braceBlock(in: source, openingAt: initStart.upperBound))
        let body = String(source[initBody])

        // WHEN Positionen bestimmt werden
        let make = try XCTUnwrap(body.range(of: "SharedModelContainer.make()"), "make() nicht in init()")
        let deferRange = body.range(of: "defer {").flatMap { Self.braceBlock(in: body, openingAt: $0.upperBound) }
        var starts: [Range<String.Index>] = []
        var cursor = body.startIndex
        while let found = body.range(of: "CloudMirrorMonitor.shared.start(", range: cursor..<body.endIndex) {
            starts.append(found)
            cursor = found.upperBound
        }
        let outsideDefer = starts.filter { start in deferRange.map { !$0.contains(start.lowerBound) } ?? true }

        // THEN steht ein Aufruf außerhalb des defer-Blocks vor make()
        XCTAssertFalse(outsideDefer.isEmpty, "start() wird nur im defer-Block aufgerufen, also nach make()")
        XCTAssertTrue(outsideDefer.contains { $0.lowerBound < make.lowerBound }, "start() steht nach make()")
    }

    /// Bereich ab `start` (direkt hinter einer `{`) bis vor die passende `}`.
    private static func braceBlock(in text: String, openingAt start: String.Index) -> Range<String.Index>? {
        var depth = 1
        var index = start
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return start..<index }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
