# Adversary Runde 6, Vergleichsmessung Schliessen-Tipp (F005), #145 Durchgang 4

Frage: Ist der einmalige Fehlschlag des Schliessen-Tipps in Runde 5 (Lauf 1) eine Folge der Chip-Aenderung
(`.fixedSize(horizontal: true, vertical: false)` in `ToolbarChipModifier`) oder der bekannte UI-Aussetzer (#111/#118)?

## Aufbau

- Stand A = `origin/main` (506eb4b, gleich dem Merge-Base des Zweigs), per `git archive` in eine Wegwerf-Kopie.
- Stand B = aktueller Worktree-Stand inkl. uncommittete Aenderungen (rsync von SmartCart, Widgets, ShareExtension, Tests, UITests, Projekt). B enthaelt damit alle vier geaenderten Code-Dateien (Chip, PaywallView, PremiumService, FakePurchaseStore).
- Messsonde `AdversaryR6CloseProbeUITests` (Quelltext unten), identisch an `RestockUITests/PaywallUITests.swift` jeder Kopie angehaengt (keine pbxproj-Aenderung noetig); im Worktree selbst nie vorhanden.
- Ablauf je Tipp: Start mit `-hasCompletedOnboarding YES -developerMode NO`, `chart.bar` antippen (wie `testExpensesAnalysisLockedOpensPaywall`), auf Paywall-Kopf warten, `waitUntilHittable()` auf "Schliessen", Chip-Rahmen lesen, tippen, bis 5 s lang auf Verschwinden der Paywall pruefen. Kein XCTAssert je Tipp; Fehlschlag = Messzeile mit Zeit, Chip-Rahmen, Last, Screenshot als Anhang, danach zweiter Tipp bzw. App-Neustart.
- Wegwerf-Simulator `Restock-R6-Wegwerf`: iPhone 17 Pro, iOS 26.5 (Typ und Runtime von Restock-Validate), frisch angelegt, beide Staende nacheinander auf demselben Geraet. Restock-Validate wurde fuer die Messung nicht benutzt.
- Blockfolge abwechselnd: A1, B1, A2, B2, A3, B3, A4, B4 (je 75 Tipps), 10:05 bis 10:37.
- Last: 5 Prozesse `yes > /dev/null` (Rechner hat 10 Kerne) fuer alle Bloecke gleich, dazu fremde Last anderer Sitzungen (Lastmittel 1 min zu Beginn 153,75, in den spaeteren Bloecken 13 bis 45; je Block in den Rohprotokollen). Lastprozesse am Ende beendet (Pruefung: keiner uebrig).
- Rohprotokolle: `adversary-r6-vergleich-main.txt` (A), `adversary-r6-vergleich-branch.txt` (B).

## Ergebnis

| Block | Stand A (origin/main) Tipps / Fehlschlaege / Oeffnen-Fehler | Dauer A | Stand B (Zweig) Tipps / Fehlschlaege / Oeffnen-Fehler | Dauer B |
|---|---|---|---|---|
| 1 | 75 / 0 / 0 | 276 s | 75 / 0 / 0 | 216 s |
| 2 | 75 / 0 / 0 | 217 s | 75 / 0 / 0 | 216 s |
| 3 | 75 / 0 / 0 | 214 s | 75 / 0 / 0 | 217 s |
| 4 | 75 / 0 / 0 | 209 s | 75 / 0 / 0 | 208 s |
| Summe | 300 / 0 / 0 | | 300 / 0 / 0 | |

Entscheidungsregel (vorher festgelegt): B signifikant schlechter als A (B mindestens 3 Fehlschlaege mehr und Rate mindestens doppelt so hoch) = F005 bestaetigt. Beide gleich (auch beide 0) = bekannter Aussetzer.
Befund: B 0/300, A 0/300. Gleich. B ist nicht schlechter. F005 als Regression nicht bestaetigt.

Grenze der Aussage: Der Aussetzer aus Runde 5 (1 von rund 57 Schliessen-Tipps, im Gesamtlauf) trat in keinem der 600 Tipps der Sonde auf, auch nicht auf A. Die Messung kann ihn daher weder dem Zweig noch main zuordnen; sie zeigt nur, dass unter Last bei 300 Tipps je Stand kein Unterschied zu sehen ist. Bei einer Grundrate von 1/57 haetten rund 5 Fehlschlaege je Stand erwartet werden koennen; die Grundrate im Gesamtlauf (nach vielen vorherigen Tests im selben Simulator-Zustand) gilt also fuer die isolierte Sonde nicht. Ein Unterschied in der Trefferflaeche wurde in Runde 5 ebenfalls ausgeschlossen (15/15 an Mitte und Raendern des 99-pt-Chips).

## Sondenquelltext (in beiden Kopien identisch)

```swift

// Adversary Runde 6 (nur in Wegwerf-Kopien): Messsonde fuer Schliessen-Tipps der Paywall.
final class AdversaryR6CloseProbeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-developerMode", "NO"]
        UITestLaunch.start(app, expecting: app.buttons["chart.bar"], description: "chart.bar")
        return app
    }

    func testCloseTaps() {
        var app = launch()
        let n = Int(ProcessInfo.processInfo.environment["R6_TAPS"] ?? "") ?? 50
        var ok = 0, fail = 0, openFail = 0
        var msgs = ""
        let t0 = Date()
        var i = 0
        while i < n {
            i += 1
            let chart = app.buttons["chart.bar"]
            let r1 = chart.waitUntilHittable()
            if !r1.matched {
                openFail += 1
                app.terminate()
                app = launch()
                continue
            }
            chart.tap()
            let head = app.staticTexts["Restock Pro"]
            if !head.waitForExistence(timeout: UITestWait.defaultTimeout) {
                openFail += 1
                msgs += "R6MESS OPEN_FAIL i=" + String(i) + "\n"
                continue
            }
            let close = app.buttons["Schließen"]
            let r2 = close.waitUntilHittable()
            let frame = close.frame
            if !r2.matched {
                openFail += 1
                app.terminate()
                app = launch()
                continue
            }
            close.tap()
            let end = Date().addingTimeInterval(5)
            var gone = false
            while Date() < end {
                if !head.exists {
                    gone = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            if gone {
                ok += 1
            } else {
                fail += 1
                let load = UITestLaunch.loadAverage()?.0 ?? -1
                let secs = Int(Date().timeIntervalSince(t0))
                msgs += "R6MESS FEHLSCHLAG i=" + String(i) + " t=" + String(secs) + "s"
                msgs += " chipRahmen=" + frame.debugDescription + " last1=" + String(load) + "\n"
                let att = XCTAttachment(screenshot: app.screenshot())
                att.lifetime = .keepAlways
                att.name = "r6-fail-" + String(i)
                add(att)
                close.tap()
                let end2 = Date().addingTimeInterval(5)
                var gone2 = false
                while Date() < end2 {
                    if !head.exists {
                        gone2 = true
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                if !gone2 {
                    app.terminate()
                    app = launch()
                }
            }
        }
        let total = Int(Date().timeIntervalSince(t0))
        msgs += "R6RESULT taps=" + String(n) + " ok=" + String(ok) + " fehlschlag=" + String(fail)
        msgs += " oeffnen_fehlgeschlagen=" + String(openFail) + " dauer=" + String(total) + "s\n"
        print(msgs)
    }
}
```

## Weiterer Gesamtlauf (AC-19)

Siehe `adversary-test-output.txt` (Runde 6; der Lauf aus Runde 5 liegt als `adversary-test-output-runde5-lauf2.txt` und `adversary-test-output-runde5-lauf1.txt`): Unit 610/610, UI 130 ausgefuehrt, 127 bestanden, 0 fehlgeschlagen, 3 uebersprungen, EXIT 0, Dauer UI 1979 s.

## Aufraeumen

Wegwerf-Simulator EFA13D44-78C9-4C9A-AB67-34D6C7D8E5E3 geloescht, Lastprozesse beendet, Sperren freigegeben.
