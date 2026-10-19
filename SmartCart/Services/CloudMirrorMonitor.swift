import CloudKit
import CoreData
import Foundation
import os

/// Issue #156, Teil A: macht den privaten iCloud-Abgleich (SwiftData über
/// `NSPersistentCloudKitContainer`) im Entwicklermodus sichtbar. Der Beobachter liest nur die
/// Ereignisse der Spiegelung und schreibt eine Zusammenfassung in `UserDefaults`; an Läden,
/// Artikeln oder der Spiegelung selbst ändert er nichts.
/// Spec: `docs/specs/services/icloud-abgleich-sichtbar.md`.
final class CloudMirrorMonitor: @unchecked Sendable {
    static let shared = CloudMirrorMonitor(statusStore: CloudMirrorStatusStore())

    let statusStore: CloudMirrorStatusStore
    private let lock = NSLock()
    private var observer: NSObjectProtocol?
    /// Zeitpunkt von `start()`; Grundlage für „erster Import seit dem Start beendet“ (Onboarding).
    private(set) var startedAt: Date?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SmartCart", category: "sync")

    init(statusStore: CloudMirrorStatusStore) {
        self.statusStore = statusStore
    }

    /// Nur im App-Prozess beobachten; Erweiterungen spiegeln nicht (siehe `SharedModelContainer`).
    static func shouldObserve(bundleURL: URL) -> Bool {
        !SharedModelContainer.isAppExtension(bundleURL: bundleURL)
    }

    /// Registriert genau einen Beobachter (`object: nil`); weitere Aufrufe sind wirkungslos.
    func start(bundleURL: URL = Bundle.main.bundleURL) {
        lock.lock()
        defer { lock.unlock() }
        guard observer == nil, Self.shouldObserve(bundleURL: bundleURL) else { return }
        startedAt = Date()
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] note in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = note.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            self?.handle(type: event.type, succeeded: event.succeeded, error: event.error, endDate: event.endDate)
        }
    }

    /// Ist seit `start()` ein Import beendet worden (erfolgreich oder nicht)?
    var firstImportFinished: Bool {
        guard let startedAt, let run = statusStore.lastRun(.import) else { return false }
        return run.date >= startedAt
    }

    /// Verarbeitet ein Ereignis; laufende Ereignisse (`endDate == nil`) und Einrichtungsläufe
    /// werden ignoriert.
    func handle(type: NSPersistentCloudKitContainer.EventType, succeeded: Bool, error: Error?, endDate: Date?) {
        guard let endDate, type == .export || type == .import else { return }
        let summary = error.map { Self.summarize(error: $0) }
        if let summary {
            Self.logger.error("mirror \(type == .export ? "export" : "import", privacy: .public) failed (\(summary.domain, privacy: .public) \(summary.code, privacy: .public)): \(summary.detail, privacy: .private)")
        }
        statusStore.record(CloudMirrorRun(date: endDate, succeeded: succeeded, summary: summary), for: type)
    }

    // MARK: - Zusammenfassung

    /// Meldet bei `partialFailure` den Eintrag, der nicht `batchRequestFailed` ist (auch unter
    /// `NSUnderlyingError`), sonst den Fehler der obersten Ebene.
    static func summarize(error: Error) -> CloudMirrorSummary {
        let top = error as NSError
        guard let entries = partialErrors(in: top) else { return summary(of: top, failed: 0, total: 0) }
        let failed = entries.filter { !isBatchFailure($0) }
        guard let single = failed.first else { return summary(of: top, failed: 0, total: entries.count) }
        return summary(of: single, failed: failed.count, total: entries.count)
    }

    private static func partialErrors(in error: NSError) -> [NSError]? {
        var current: NSError? = error
        var depth = 0
        while let candidate = current, depth < 8 {
            if let byID = candidate.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                return byID.values.map { $0 as NSError }
            }
            current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return nil
    }

    private static func isBatchFailure(_ error: NSError) -> Bool {
        error.domain == CKError.errorDomain && error.code == CKError.Code.batchRequestFailed.rawValue
    }

    private static func summary(of error: NSError, failed: Int, total: Int) -> CloudMirrorSummary {
        CloudMirrorSummary(domain: error.domain, code: error.code, detail: error.localizedDescription,
                           kind: classify(error), failedItemCount: failed, totalItemCount: total)
    }

    /// Fehlerarten wie `SyncCoordinator.classify`, ergänzt um den Text „production schema“.
    private static func classify(_ error: NSError) -> CloudMirrorSummary.Kind {
        if error.localizedDescription.lowercased().contains("production schema") { return .schemaIncomplete }
        guard error.domain == CKError.errorDomain else { return .other }
        switch CKError.Code(rawValue: error.code) {
        case .permissionFailure: return .permissionDenied
        case .notAuthenticated: return .notAuthenticated
        default: return .other
        }
    }

    // MARK: - Anzeige

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Untertitel der Dev-Zeile „iCloud-Abgleich“ in den Einstellungen.
    static func devRowSubtitle(lastExport: CloudMirrorRun?) -> (text: String, isFailure: Bool) {
        guard let run = lastExport else { return (String(localized: "noch kein Lauf"), false) }
        let time = timeFormatter.string(from: run.date)
        return run.succeeded
            ? (String(localized: "Export erfolgreich · \(time)"), false)
            : (String(localized: "Export fehlgeschlagen · \(time)"), true)
    }
}

/// Zusammenfassung eines Spiegelungsfehlers (nur Diagnose).
struct CloudMirrorSummary: Codable, Equatable {
    enum Kind: String, Codable {
        case permissionDenied, notAuthenticated, schemaIncomplete, other
    }

    var domain: String
    var code: Int
    var detail: String
    var kind: Kind
    /// Einträge ohne `batchRequestFailed`.
    var failedItemCount: Int
    /// Alle Einträge des Teilfehlers; 0 ohne Teilfehler.
    var totalItemCount: Int

    var itemCountText: String? {
        guard totalItemCount > 0 else { return nil }
        return String(localized: "\(failedItemCount) von \(totalItemCount)")
    }
}

/// Ein beendeter Export- oder Importlauf.
struct CloudMirrorRun: Codable, Equatable {
    var date: Date
    var succeeded: Bool
    var summary: CloudMirrorSummary?
}

/// Ablage des letzten Laufs je Typ und der Export-Zähler, Schlüsselpräfix `smartcart.cloudMirror.`.
final class CloudMirrorStatusStore: @unchecked Sendable {
    static let keyPrefix = "smartcart.cloudMirror."
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func runKey(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        Self.keyPrefix + (type == .export ? "lastExport" : "lastImport")
    }

    private var successKey: String { Self.keyPrefix + "exportSuccessCount" }
    private var failureKey: String { Self.keyPrefix + "exportFailureCount" }

    func lastRun(_ type: NSPersistentCloudKitContainer.EventType) -> CloudMirrorRun? {
        guard let data = defaults.data(forKey: runKey(type)) else { return nil }
        return try? PropertyListDecoder().decode(CloudMirrorRun.self, from: data)
    }

    var exportSuccessCount: Int { defaults.integer(forKey: successKey) }
    var exportFailureCount: Int { defaults.integer(forKey: failureKey) }

    func record(_ run: CloudMirrorRun, for type: NSPersistentCloudKitContainer.EventType) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? PropertyListEncoder().encode(run) else { return }
        defaults.set(data, forKey: runKey(type))
        guard type == .export else { return }
        let counter = run.succeeded ? successKey : failureKey
        defaults.set(defaults.integer(forKey: counter) + 1, forKey: counter)
    }

    /// Entfernt alle `smartcart.cloudMirror.*`-Schlüssel.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Issue #156, B2.1 (Entwurf A): Soll die Ersteinrichtung auf Läden aus iCloud warten?
enum OnboardingCloudGate {
    enum Decision: Equatable {
        case proceed, wait, skipOnboarding
    }

    /// Höchstens so lange wartet die Ersteinrichtung.
    static let maxWait: TimeInterval = 10

    static func decision(accountAvailable: Bool, firstImportFinished: Bool,
                         storeCount: Int, elapsed: TimeInterval) -> Decision {
        guard accountAvailable else { return .proceed }
        if storeCount > 0 { return .skipOnboarding }
        if firstImportFinished || elapsed >= maxWait { return .proceed }
        return .wait
    }
}
