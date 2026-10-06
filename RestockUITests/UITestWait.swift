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
    static let defaultTimeout: TimeInterval = 5
    static let pollInterval: TimeInterval = 0.25

    /// Liest exists → frame → isHittable; `isHittable` nur bei endlichem, nicht leerem Rahmen.
    static func readState(exists: () -> Bool, frame: () -> CGRect,
                          isHittable: () -> Bool) -> UITestElementState {
        UITestElementState(exists: false, frame: .zero, isHittable: false)
    }

    /// Wiederholt `read`, bis `done` zutrifft oder die Frist abläuft; liefert den zuletzt gelesenen Wert.
    static func poll<T>(timeout: TimeInterval, read: () -> T,
                        done: (T) -> Bool) -> (matched: Bool, last: T) {
        (false, read())
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
