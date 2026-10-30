import XCTest

// Gemeinsame Warte-Hilfen der UI-Tests (Issue #111).
// Auf dem CI-Runner dauern einzelne XCUITest-Abfragen sporadisch 4–14 s, und eine Momentaufnahme
// kommt gelegentlich mit Rahmen {{inf, inf}, {0, 0}} zurück — `isHittable` scheitert dann hart.
// Die Hilfen warten zustandsbasiert (Ende beim ersten Treffer) und melden den zuletzt gelesenen
// Zustand, ohne nach Fristablauf eine weitere Abfrage zu stellen.

/// Zustand eines Elements aus einer Warte-Runde.
struct UITestElementState: CustomStringConvertible {
    var exists: Bool
    var frame: CGRect
    var isHittable: Bool

    var description: String { "exists=\(exists) frame=\(frame) hittable=\(isHittable)" }
}

enum UITestWait {
    /// Länger als die längste belegte Einzelabfrage (14,3 s) plus Reserve.
    static let defaultTimeout: TimeInterval = 20
    static let pollInterval: TimeInterval = 0.25

    /// Liest exists → frame → isHittable; `isHittable` nur bei endlichem, nicht leerem Rahmen.
    static func readState(exists: () -> Bool, frame: () -> CGRect,
                          isHittable: () -> Bool) -> UITestElementState {
        guard exists() else { return UITestElementState(exists: false, frame: .zero, isHittable: false) }
        let rect = frame()
        let finite = [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy { $0.isFinite }
        guard finite, !rect.isEmpty else { return UITestElementState(exists: true, frame: rect, isHittable: false) }
        return UITestElementState(exists: true, frame: rect, isHittable: isHittable())
    }

    /// Wiederholt `read`, bis `done` zutrifft oder die Frist abläuft; liefert den zuletzt gelesenen Wert.
    static func poll<T>(timeout: TimeInterval, read: () -> T,
                        done: (T) -> Bool) -> (matched: Bool, last: T) {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let value = read()
            if done(value) { return (true, value) }
            if Date() >= deadline { return (false, value) }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }
}

extension XCUIElement {
    func waitUntilHittable(timeout: TimeInterval = UITestWait.defaultTimeout)
        -> (matched: Bool, last: UITestElementState) {
        UITestWait.poll(timeout: timeout,
                        read: { UITestWait.readState(exists: { self.exists }, frame: { self.frame },
                                                     isHittable: { self.isHittable }) },
                        done: { $0.isHittable })
    }

    func waitForLabel(contains text: String, timeout: TimeInterval = UITestWait.defaultTimeout)
        -> (matched: Bool, lastLabel: String) {
        let result = UITestWait.poll(timeout: timeout, read: { self.exists ? self.label : "" },
                                     done: { $0.contains(text) })
        return (result.matched, result.last)
    }
}

// Bearbeiten-Dialog eines Artikels in der Ladenliste öffnen. Ein Tipp auf die Zeile hakt ab
// (Abhaken beim Einkaufen); bearbeitet wird über Lang drücken → „Bearbeiten“.
enum UITestItemEditor {
    static func open(_ name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let text = app.staticTexts[name].firstMatch
        let ready = text.waitUntilHittable()
        XCTAssertTrue(ready.matched, "Zeile „\(name)“ nicht antippbar — zuletzt: \(ready.last)", file: file, line: line)
        text.press(forDuration: 1.0)
        let edit = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "item.action.edit", "Bearbeiten")).firstMatch
        let editReady = edit.waitUntilHittable()
        XCTAssertTrue(editReady.matched, "„Bearbeiten“ im Menü von „\(name)“ fehlt — zuletzt: \(editReady.last)",
                      file: file, line: line)
        edit.tap()
    }
}

// Start-Helfer für gesäte UI-Tests (Issue #105 / #128, Durchgang 1).
// Gemessen (#98, #128, App-Protokoll): Der Testläufer startet die App gelegentlich, im vollen Lauf
// auf Restock-Validate beim ersten Start fast immer, ganz ohne Launch-Argumente; ohne Seed fehlt die
// erwartete Kachel. Ursache unbekannt — der zweite Start ist Abhilfe, nicht Erklärung. Deshalb:
// starten, Gegenprobe auf das Seed-Element, bei Fehlen genau einmal neu starten und das Messdatum
// `UITestLaunch: zweiter Start nötig` ausgeben, sonst mit klarer Meldung scheitern.
enum UITestLaunch {
    struct Outcome {
        enum Kind { case firstLaunch, secondLaunch, failed }
        let kind: Kind
        let launches: Int
        let detail: String
    }

    static let secondLaunchMarker = "UITestLaunch: zweiter Start nötig"

    /// Messwerte für die Meldung „zweiter Start nötig“ (Issue #105, Durchgang 2); `nil` = nicht ermittelbar.
    struct Measurement {
        var secondsSinceRunStart: Double?    // Prozessstart des Testläufers
        var secondsSinceHelperCall: Double?  // Eintritt in UITestLaunch.start
        var load: (Double, Double, Double)?  // getloadavg: 1/5/15 min
        var pidBefore: Int32?                // App-Prozesskennung (nicht öffentliche processID, siehe appProcessID) vor terminate()
        var pidAfter: Int32?                 // nach dem zweiten launch()
        var launchOrdinal: Int               // laufende Nummer der Starts im Lauf
    }

    /// Laufende Nummer der Starts über alle Aufrufe des Helfers im Lauf.
    static var launchCount = 0

    /// Einzeilige Messzeile; nicht ermittelbare Werte stehen als „unbekannt“, nie als erfundene Zahl.
    static func measurementLine(_ m: Measurement) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        func num(_ v: Double) -> String { String(format: "%.1f", locale: posix, v) }
        func secs(_ v: Double?) -> String { v.map { "\(num($0)) s" } ?? "unbekannt" }
        let load = m.load.map { "\(num($0.0))/\(num($0.1))/\(num($0.2))" } ?? "unbekannt"
        let pid = (m.pidBefore == nil && m.pidAfter == nil) ? "unbekannt"
            : "\(m.pidBefore.map(String.init) ?? "unbekannt") → \(m.pidAfter.map(String.init) ?? "unbekannt")"
        return "seit Lauf \(secs(m.secondsSinceRunStart)), seit Helferaufruf \(secs(m.secondsSinceHelperCall)), "
            + "Last \(load), pid \(pid), Start Nr. \(m.launchOrdinal)"
    }

    /// Reine Entscheidungslogik: launch, probe; bei Fehlschlag genau einmal terminate, launch, probe.
    /// Messwerte (`pid`, `snapshot`) werden nur gelesen, und nur nach dem ersten Fehlschlag.
    static func run(launch: () -> Void, terminate: () -> Void,
                    probe: () -> (matched: Bool, detail: String),
                    pid: () -> Int32?, snapshot: () -> Measurement,
                    report: (String) -> Void) -> Outcome {
        launch()
        let first = probe()
        if first.matched { return Outcome(kind: .firstLaunch, launches: 1, detail: first.detail) }
        let pidBefore = pid()
        terminate()
        launch()
        let pidAfter = pid()
        let second = probe()
        guard second.matched else { return Outcome(kind: .failed, launches: 2, detail: second.detail) }
        var measurement = snapshot()
        measurement.pidBefore = pidBefore
        measurement.pidAfter = pidAfter
        report("\(secondLaunchMarker) — erster Versuch: \(first.detail) — \(measurementLine(measurement))")
        return Outcome(kind: .secondLaunch, launches: 2, detail: second.detail)
    }

    /// Prozessstart des Testläufers (sysctl KERN_PROC_PID, p_starttime); `nil`, wenn nicht ermittelbar.
    static func runnerStartDate() -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        guard start.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
    }

    /// Prozesskennung der App. `XCUIApplication` hat unter iOS keine öffentliche Eigenschaft dafür;
    /// gelesen wird die nicht öffentliche `processID` nur, wenn vorhanden. Fehlt sie oder ist sie ≤ 0: `nil`.
    static func appProcessID(_ app: XCUIApplication) -> Int32? {
        guard app.responds(to: NSSelectorFromString("processID")),
              let pid = (app.value(forKey: "processID") as? NSNumber)?.int32Value, pid > 0 else { return nil }
        return pid
    }

    static func loadAverage() -> (Double, Double, Double)? {
        var values = [Double](repeating: 0, count: 3)
        guard getloadavg(&values, 3) == 3 else { return nil }
        return (values[0], values[1], values[2])
    }

    static func failureMessage(launches: Int, expected: String, detail: String) -> String {
        "App-Start gescheitert nach \(launches) Starts: \(expected) nicht antippbar, zuletzt: \(detail). "
            + "Launch-Argumente des Tests nicht angekommen oder Seed fehlgeschlagen."
    }

    /// Startet `app` und prüft, ob `element` (vom Seed erzeugt) antippbar wird; siehe `run`.
    @discardableResult
    static func start(_ app: XCUIApplication, expecting element: XCUIElement, description: String? = nil,
                      file: StaticString = #filePath, fileID: String = #fileID,
                      function: String = #function, line: UInt = #line) -> Outcome {
        let helperCall = Date()
        let expected = description ?? "erwartetes Element"
        let outcome = run(
            launch: { launchCount += 1; app.launch() },
            terminate: { app.terminate() },
            probe: {
                let result = element.waitUntilHittable()
                return (result.matched, result.last.description)
            },
            pid: { appProcessID(app) },
            snapshot: {
                Measurement(secondsSinceRunStart: runnerStartDate().map { Date().timeIntervalSince($0) },
                            secondsSinceHelperCall: Date().timeIntervalSince(helperCall),
                            load: loadAverage(), pidBefore: nil, pidAfter: nil, launchOrdinal: launchCount)
            },
            report: { NSLog("%@ [%@ %@, %@]", $0, fileID, function, expected) })
        if outcome.kind == .failed {
            XCTFail(failureMessage(launches: outcome.launches, expected: expected, detail: outcome.detail),
                    file: file, line: line)
        }
        return outcome
    }
}

// Wiederholung für AppIntentsTesting (Issue #145, Durchgang 3). Belegt im Probelauf: Unter Rechnerlast scheitert
// `run()` mit AppIntentsServicesMetadataErrorDomain 400 „… is not present“, ohne Last nicht. Ursache unbekannt —
// wiederholt wird nur genau dieser Fehler, mit Messzeile; jeder andere Fehler geht sofort durch. Ohne Import des
// Frameworks, damit die Logik auch unter Xcode 26 gebaut und geprüft wird.
enum AppIntentRetry {
    static let maxDuration: TimeInterval = 10
    static let interval: TimeInterval = 0.5
    static let marker = "AppIntents: Wiederholung"

    static func isNotPresent(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "AppIntentsServicesMetadataErrorDomain" && nsError.code == 400
            && nsError.localizedDescription.contains("is not present")
    }

    /// Ruft `call` auf; liefert die Anzahl der Versuche. Nach Fristablauf wird der letzte 400-Fehler geworfen.
    @discardableResult
    static func runIntentRetrying(_ name: String, maxDuration: TimeInterval = maxDuration,
                                  interval: TimeInterval = interval, now: () -> Date = Date.init,
                                  sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
                                  report: (String) -> Void = { NSLog("%@", $0) },
                                  _ call: () async throws -> Void) async throws -> Int {
        let start = now()
        var attempt = 1
        while true {
            do {
                try await call()
                if attempt > 1 {
                    // Erfolgszeile bewusst ohne `marker`, damit die Zählung der Wiederholungen stimmt.
                    NSLog("AppIntents: Erfolg nach %d Versuchen, %.1f s, bei %@", attempt,
                          now().timeIntervalSince(start), name)
                }
                return attempt
            } catch {
                let elapsed = now().timeIntervalSince(start)
                guard isNotPresent(error), elapsed + interval <= maxDuration else { throw error }
                let load = UITestLaunch.loadAverage().map { String(format: "%.2f", $0.0) } ?? "unbekannt"
                report("\(marker) \(attempt) nach \(String(format: "%.1f", elapsed)) s wegen 400 bei \(name), Last \(load)")
                try await sleep(interval)
                attempt += 1
            }
        }
    }
}

// MARK: - Prüfung der Hilfen ohne App (T1–T4)

final class UITestWaitTests: XCTestCase {
    private let infFrame = CGRect(x: CGFloat.infinity, y: CGFloat.infinity, width: 0, height: 0)
    private let tileFrame = CGRect(x: 20, y: 200, width: 160, height: 90)

    // T1 / AC-1: Bei inf- oder leerem Rahmen wird isHittable gar nicht erst gelesen.
    func testInfiniteOrEmptyFrameIsNotReadyAndSkipsHittable() {
        for frame in [infFrame, CGRect(x: 10, y: 10, width: 0, height: 0)] {
            let state = UITestWait.readState(exists: { true }, frame: { frame }, isHittable: {
                XCTFail("isHittable darf bei Rahmen \(frame) nicht gelesen werden"); return true
            })
            XCTAssertTrue(state.exists, "exists muss gelesen sein")
            XCTAssertFalse(state.isHittable, "Rahmen \(frame) gilt als noch nicht bereit")
        }
        let ready = UITestWait.readState(exists: { true }, frame: { tileFrame }, isHittable: { true })
        XCTAssertTrue(ready.isHittable, "Endlicher Rahmen + hittable muss bereit sein")
        XCTAssertEqual(ready.frame, tileFrame)
    }

    // T1 / AC-1: Nach zwei inf-Runden wird weiter gewartet statt hart zu scheitern.
    func testPollKeepsWaitingThroughInfiniteFrames() {
        var frames = [infFrame, infFrame, tileFrame]
        var reads = 0
        let result = UITestWait.poll(timeout: 5, read: { () -> UITestElementState in
            reads += 1
            let frame = frames.count > 1 ? frames.removeFirst() : frames[0]
            return UITestWait.readState(exists: { true }, frame: { frame }, isHittable: { true })
        }, done: { $0.isHittable })
        XCTAssertTrue(result.matched, "Muss nach endlichem Rahmen Erfolg melden, zuletzt: \(result.last)")
        XCTAssertEqual(reads, 3, "Genau drei Runden erwartet")
    }

    // T2 / AC-2: Sofort bereit → erste Runde, keine feste Wartezeit.
    func testPollReturnsInFirstRoundWhenReady() {
        var reads = 0
        let start = Date()
        let result = UITestWait.poll(timeout: 20, read: { () -> Bool in reads += 1; return true }, done: { $0 })
        XCTAssertTrue(result.matched)
        XCTAssertEqual(reads, 1, "Nur eine Runde erwartet")
        XCTAssertLessThan(Date().timeIntervalSince(start), 1, "Darf nicht auf die Frist warten")
    }

    // T3 / AC-3: Fristablauf liefert den zuletzt gesehenen Zustand, ohne weitere Abfrage.
    func testTimeoutReportsLastSeenStateWithoutExtraRead() {
        var reads = 0
        let start = Date()
        let result = UITestWait.poll(timeout: 0.8, read: { () -> UITestElementState in
            reads += 1
            return UITestElementState(exists: true, frame: self.tileFrame, isHittable: false)
        }, done: { $0.isHittable })
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertFalse(result.matched)
        XCTAssertGreaterThan(reads, 1, "Muss bis zur Frist wiederholt lesen")
        XCTAssertGreaterThanOrEqual(elapsed, 0.8, "Muss die Frist ausschöpfen")
        XCTAssertLessThan(elapsed, 2, "Frist darf nicht weit überschritten werden")
        XCTAssertEqual(result.last.description, "exists=true frame=\(tileFrame) hittable=false")
    }

    // T4 / AC-4: Label-Warten liefert den zuletzt gelesenen Text.
    func testLabelTimeoutReturnsLastReadLabel() {
        let label = "2 Artikel ohne Laden, Testartikel Zwei"
        var reads = 0
        let result = UITestWait.poll(timeout: 0.6, read: { () -> String in reads += 1; return label },
                                     done: { $0.contains("Testartikel Eins") })
        XCTAssertFalse(result.matched)
        XCTAssertEqual(result.last, label)
        XCTAssertGreaterThan(reads, 1, "Muss bis zur Frist wiederholt lesen")
    }

    // AC-5: Standardfrist an einer Stelle, 20 s.
    func testDefaultTimeoutIsTwentySeconds() {
        XCTAssertEqual(UITestWait.defaultTimeout, 20)
    }
}

// MARK: - Prüfung des Start-Helfers ohne App (Issue #105 / #128, Durchgang 1: T1–T4)

final class UITestLaunchTests: XCTestCase {
    private let marker = "UITestLaunch: zweiter Start nötig"

    private let fullMeasurement = UITestLaunch.Measurement(
        secondsSinceRunStart: 12.4, secondsSinceHelperCall: 11.9, load: (3.1, 2.4, 2.0),
        pidBefore: nil, pidAfter: nil, launchOrdinal: 1)

    /// Zeichnet die Aufrufe der injizierten Closures in Reihenfolge auf.
    private func run(probes: [(matched: Bool, detail: String)], pids: [Int32?] = [100, 200])
        -> (outcome: UITestLaunch.Outcome, calls: [String], reports: [String], measureCalls: Int) {
        var calls: [String] = []
        var reports: [String] = []
        var remaining = probes
        var remainingPids = pids
        var measureCalls = 0
        let outcome = UITestLaunch.run(
            launch: { calls.append("launch") },
            terminate: { calls.append("terminate") },
            probe: {
                calls.append("probe")
                return remaining.isEmpty ? (false, "keine weitere Antwort") : remaining.removeFirst()
            },
            pid: { measureCalls += 1; return remainingPids.isEmpty ? nil : remainingPids.removeFirst() },
            snapshot: { measureCalls += 1; return self.fullMeasurement },
            report: { reports.append($0) })
        return (outcome, calls, reports, measureCalls)
    }

    // T1 / AC-1: Die Messzeile nennt alle Felder mit Namen und Einheit.
    func testMeasurementLineNamesAllFields() {
        var m = fullMeasurement
        m.pidBefore = 4711
        m.pidAfter = 4802
        let line = UITestLaunch.measurementLine(m)
        XCTAssertFalse(line.contains("\n"), "Einzeilig erwartet: \(line)")
        for part in ["seit Lauf 12.4 s", "seit Helferaufruf 11.9 s", "Last 3.1/2.4/2.0",
                     "pid 4711 → 4802", "Start Nr. 1"] {
            XCTAssertTrue(line.contains(part), "„\(part)“ fehlt in: \(line)")
        }
    }

    // T2 / AC-2: Fehlende Werte erscheinen als „unbekannt“, nie als erfundene Zahl.
    func testMeasurementLineShowsUnknownForMissingValues() {
        let m = UITestLaunch.Measurement(secondsSinceRunStart: nil, secondsSinceHelperCall: nil, load: nil,
                                         pidBefore: nil, pidAfter: nil, launchOrdinal: 2)
        let line = UITestLaunch.measurementLine(m)
        XCTAssertEqual(line.components(separatedBy: "unbekannt").count - 1, 4,
                       "Lauf, Helferaufruf, Last und pid je einmal „unbekannt“: \(line)")
        XCTAssertTrue(line.contains("Start Nr. 2"), line)
        XCTAssertFalse(line.contains("0.0"), "Keine erfundene Zahl: \(line)")
    }

    // T1 / AC-1: Gegenprobe beim ersten Start gelungen → ein Start, kein Neustart, keine Meldung.
    func testFirstLaunchMatchedDoesNotRestartOrReport() {
        let result = run(probes: [(true, "exists=true hittable=true")])
        XCTAssertEqual(result.calls, ["launch", "probe"])
        XCTAssertTrue(result.reports.isEmpty, "Keine Messmeldung beim ersten Treffer")
        XCTAssertEqual(result.outcome.kind, .firstLaunch)
        XCTAssertEqual(result.outcome.launches, 1)
        // T4 / AC-4: Bei Erfolg im ersten Start wird nichts gemessen oder gemeldet.
        XCTAssertEqual(result.measureCalls, 0, "Messwerte dürfen ohne Meldung nicht ausgewertet werden")
    }

    // T2 / AC-2: Erst der zweite Start trägt die Argumente → genau ein Neustart, genau eine Meldung.
    func testSecondLaunchRecoversAndReportsOnce() {
        let result = run(probes: [(false, "exists=false"), (true, "exists=true hittable=true")])
        XCTAssertEqual(result.calls, ["launch", "probe", "terminate", "launch", "probe"])
        XCTAssertEqual(result.outcome.kind, .secondLaunch)
        XCTAssertEqual(result.outcome.launches, 2)
        XCTAssertEqual(result.reports.count, 1, "Genau eine Messmeldung")
        XCTAssertTrue(result.reports[0].hasPrefix(marker), "Präfix fehlt: \(result.reports[0])")
        XCTAssertTrue(result.reports[0].contains("exists=false"), "Befund des ersten Versuchs fehlt")
        // T3 / AC-3: Messzeile mit beiden Prozesskennungen hängt an derselben Meldung.
        XCTAssertTrue(result.reports[0].contains("pid 100 → 200"), "Messzeile fehlt: \(result.reports[0])")
        XCTAssertTrue(result.reports[0].contains("seit Lauf 12.4 s"), "Messzeile fehlt: \(result.reports[0])")
    }

    // T3 / AC-3: Auch der zweite Start ohne Treffer → kein dritter Start, Befund des letzten Versuchs.
    func testBothLaunchesFailedStopsAfterTwoStarts() {
        let result = run(probes: [(false, "exists=false"), (false, "exists=true hittable=false")])
        XCTAssertEqual(result.calls, ["launch", "probe", "terminate", "launch", "probe"])
        XCTAssertEqual(result.outcome.kind, .failed)
        XCTAssertEqual(result.outcome.launches, 2)
        XCTAssertEqual(result.outcome.detail, "exists=true hittable=false")
        XCTAssertTrue(result.reports.isEmpty, "Das Messdatum gibt es nur bei Erfolg im zweiten Start")
        // T5 / AC-5: Gesamtscheitern bleibt ohne Meldung und ohne dritten Start (Kennung vor terminate
        // wird gelesen, bevor man weiß, wie der zweite Versuch ausgeht).
        XCTAssertEqual(result.calls.filter { $0 == "launch" }.count, 2, "Kein dritter Start")
    }

    // T4 / AC-3: Die Fehlermeldung nennt Anzahl Starts, erwartetes Element und Befund.
    func testFailureMessageNamesLaunchesElementAndState() {
        let message = UITestLaunch.failureMessage(launches: 2, expected: "Kachel „Quittenhof“",
                                                  detail: "exists=false")
        XCTAssertTrue(message.contains("2"), message)
        XCTAssertTrue(message.contains("Kachel „Quittenhof“"), message)
        XCTAssertTrue(message.contains("exists=false"), message)
        XCTAssertFalse(message.contains(marker), "Meldung darf nicht den Messdaten-Präfix tragen")
    }
}

// MARK: - Prüfung der Intent-Wiederholung ohne App (Issue #145, Durchgang 3: T8)

final class AppIntentRetryTests: XCTestCase {
    private let notPresent = NSError(domain: "AppIntentsServicesMetadataErrorDomain", code: 400,
                                     userInfo: [NSLocalizedDescriptionKey: "com.johannesemmrich.Restock is not present"])

    /// Fährt den Helfer mit Scheinuhr: `sleep` rückt die Uhr vor, `failures` kommen der Reihe nach vor dem Erfolg.
    private func run(failures: [Error]) async -> (attempts: Int?, calls: Int, reports: [String], error: Error?) {
        var clock = Date(timeIntervalSince1970: 0)
        var remaining = failures
        var calls = 0
        var reports: [String] = []
        do {
            let attempts = try await AppIntentRetry.runIntentRetrying(
                "Probe", now: { clock }, sleep: { clock += $0 }, report: { reports.append($0) }) {
                calls += 1
                if !remaining.isEmpty { throw remaining.removeFirst() }
            }
            return (attempts, calls, reports, nil)
        } catch {
            return (nil, calls, reports, error)
        }
    }

    func testOnlyMetadata400NotPresentCountsAsRetryable() {
        XCTAssertTrue(AppIntentRetry.isNotPresent(notPresent))
        XCTAssertFalse(AppIntentRetry.isNotPresent(NSError(domain: notPresent.domain, code: 400)), "Text fehlt")
        XCTAssertFalse(AppIntentRetry.isNotPresent(NSError(domain: "AppIntentsServicesSecurityErrorDomain", code: 800,
                                                           userInfo: notPresent.userInfo)), "Andere Domain")
    }

    func testRetriesNotPresentAndReportsEachRetry() async {
        let result = await run(failures: [notPresent, notPresent])
        XCTAssertNil(result.error)
        XCTAssertEqual(result.attempts, 3)
        XCTAssertEqual(result.reports.count, 2, "Je Wiederholung eine Messzeile: \(result.reports)")
        XCTAssertTrue(result.reports.allSatisfy { $0.hasPrefix(AppIntentRetry.marker) }, "\(result.reports)")
    }

    func testOtherErrorIsThrownAtOnce() async {
        let other = NSError(domain: "AppIntentsServicesSecurityErrorDomain", code: 800)
        let result = await run(failures: [other, notPresent])
        XCTAssertEqual(result.calls, 1, "Keine Wiederholung bei anderem Fehler")
        XCTAssertEqual((result.error as NSError?)?.code, 800)
        XCTAssertTrue(result.reports.isEmpty)
    }

    func testGivesUpAfterMaxDurationWithLast400() async {
        let result = await run(failures: Array(repeating: notPresent, count: 1000))
        XCTAssertEqual((result.error as NSError?)?.code, 400, "Nach Fristablauf muss der 400-Fehler kommen")
        XCTAssertGreaterThan(result.calls, 1)
        XCTAssertLessThanOrEqual(Double(result.calls - 1) * AppIntentRetry.interval, AppIntentRetry.maxDuration + 0.001)
    }
}
