# Context: fix-105-leerer-start-ursache

## Request Summary
Durchgang 2 von #105/#128 (PO-Wahl 2026-10-10): Ursache des leeren ersten App-Starts im gemeinsamen UI-Lauf suchen, statt die sechs übrigen gesäten Klassen einzeln auf den Start-Helfer umzustellen. Ziel: eine zentrale Lösung, die alle gesäten Klassen schützt, oder ein belegtes „nicht behebbar“.

## Stand (aus Durchgang 1, PR #134, gemergt)
- `UITestLaunch.start(_:expecting:description:)` in `RestockUITests/UITestWait.swift`: launch, Gegenprobe auf Seed-Kachel, sonst einmal terminate + launch; meldet „UITestLaunch: zweiter Start nötig“. Angewendet auf `AddItemQuantitySuggestionUITests` und `ShoppingRouteLearningUITests`.
- Nachweis: `docs/artifacts/fix-105-128-start-helper/` (vorher: 2 Läufe ohne Last grün, 1 Lauf unter Last rot; nachher: „zweiter Start nötig“ in 3 von 4 Läufen genau 1×, immer im ersten Test, auch ohne Last).
- Offen: #133 (drei sporadische Fehler in Klassen ohne Helfer), Ursache des leeren Starts unbekannt.

## Recherche (Internet, 2026-10-10)
Suchen: „launchArguments ignored first launch Xcode 26“, „launch twice / under load“, „Failed to terminate / relaunched / first test“. Ergebnis: **kein dokumentierter Fall**, dass der erste `launch()` ohne die gesetzten Argumente startet. Bestätigt nur: Argumente werden vor `launch()` gesetzt und beim Prozessstart übergeben (Apple-Forum 25355, 759226; Swift by Sundell). Zu „Failed to terminate“ (Teil von #133): bekannter, nicht abfangbarer Apple-Fehler (Foren 13234, 94054, 18931; iOS 17: terminate() suspendiert statt zu beenden). Die Ursache muss daher aus eigener Messung kommen.

## Befund aus den vorhandenen Protokollen (nachher-lauf1-ohne-last.txt, Zeilen 49–141)
- Erster Test des Laufs: `Launch` bei t=0.05 s, „Setting up automation session“ erst bei t=1.13 s (spätere Tests ca. 0,2 s). Danach 23 s Warten auf die Kachel (Seed fehlt), `Terminate …:97400`, zweiter `Launch`, Kachel da.
- Der Testläufer-Prozess (RestockUITests-Runner) startet die App im allerersten Testfall, während Xcode noch aufbaut/installiert (Zeilen davor: Prune…Modules, IDELaunchParametersSnapshot). Hypothesen, noch ungeprüft:
  1. Der erste `launch()` trifft eine noch laufende/übernommene App-Instanz des vorigen Laufs (Terminate gilt PID 97400, nicht dem eigenen Start) – Argumente werden dann nie übergeben.
  2. Sitzungsaufbau des Testläufers zu spät; Start läuft ohne Argumente an.
  3. Installation der App durch xcodebuild läuft parallel zum ersten Start.
- Auch ohne Last tritt es bei Validate auf; auf dem CI-Simulator selten (#105).

## Related Files
| Datei | Relevanz |
|-------|----------|
| `RestockUITests/UITestWait.swift` | `UITestLaunch.start`, Ort für eine zentrale Lösung |
| `RestockUITests/*UITests.swift` (acht gesäte Klassen) | Startpunkte, `tearDown` mit `cleaner.launch()` |
| `SmartCart/SmartCartApp.swift:22-48` | `init()` mit DEBUG-Seeds (Ort für eine Messzeile der Startargumente und der Prozesskennung) |
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` | Test Action (Sprache/Region, Testplan, Reihenfolge) |
| `docs/artifacts/fix-105-128-start-helper/*` | Vorher-/Nachher-Läufe |

## Existing Patterns
- Klassenlokale Wiederholungen (DataReset, Replenishment) und der zentrale Helfer (Durchgang 1).
- Memory: ui-test-app-startet-ohne-launch-argumente, ui-test-leerer-start-nur-unter-last, ui-test-cold-start-timeouts, eigenes-testgeraet-je-projekt, null-test-lauf-ist-kein-gruen.

## Dependencies
- Upstream: XCTest/`XCUIApplication` (Xcode 26, iOS 26.5 Simulator), Restock-Validate.
- Downstream: alle gesäten UI-Klassen, CI-UI-Suite (~40 min).

## Existing Specs
- `docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md`, `docs/specs/ui-tests/test-98-*`, Spec Durchgang 1 Start-Helfer.

## Alternativen zum bisherigen Weg (Pflicht laut Henning)
- A. Aufwärmstart: ein erster, wegwerfbarer Test/Start vor allen Klassen (Klasse mit Namen vor allen anderen oder `+load`-artiger Einstieg), danach sind die Starts stabil. Kippt: Entscheidung „Helfer je Klasse“ (Durchgang 1).
- B. Vor jedem Lauf Simulator neu starten/App deinstallieren (Skript statt Testcode). Kippt: Annahme, dass Läufe aus Xcode starten; Henning startet aber auch aus Xcode.
- C. Argumente nicht über `launchArguments`, sondern über eine Datei im App-Group-Container oder die Umgebung (`launchEnvironment`) übergeben, die auch ein „leerer“ Start liest. Nur sinnvoll, wenn die Ursache am Argumentweg liegt.

## Risks & Considerations
- Ohne belegte Ursache bleibt jede Lösung Abhilfe. Messung zuerst: Startargumente **und** Prozesskennung der App im ersten Start protokollieren (temporäre DEBUG-Zeile, danach entfernen) und mit der PID im `Terminate`-Protokoll vergleichen.
- Nachstellen nur auf Restock-Validate, nie parallel, Last wie in Durchgang 1 (Rechenprozess je Kern). Keine Geräte (Henning-Regel).
- Umfang bleibt klein: Messung + zentrale Lösung in `UITestWait.swift`; Umstellung der Klassen entfällt, falls A/B/C trägt.

## Analysis

### Type
Bugfix (Testinfrastruktur). Ursache nicht belegt, Fehler heute nicht reproduzierbar.

### Messung (Belege: `docs/artifacts/fix-105-leerer-start-ursache/`)
Sechs Versuche auf Restock-Validate (`messung-zusammenfassung.md`): ohne Last, unter voller CPU-Last, mit laufender Alt-App, nach Deinstallation von App und Testläufer. In allen fünf gültigen Versuchen trug der erste App-Prozess die Seed-Argumente, nie „zweiter Start nötig“. Hypothese 1 (laufende Alt-App) ist widerlegt. Hypothese 2 (späte Sitzung) und 3 (parallele Installation) sind weder bestätigt noch widerlegt, der Auslöser fehlte heute.
Nebenbeobachtung: Unter Last startete der Testläufer einmal selbst nicht („failed to launch …xctrunner“, RequestDenied), ein eigener Lastfehler der Testumgebung.
Vermutung, nicht Messung: Die Fehlstarts der früheren Tage traten auf, während der Mac parallel arbeitete (andere Sitzungen, Bauvorgänge).

### Konsequenz (Regel „Reproduktion zuerst")
Ohne reproduzierten Fehler wird keine Ursache benannt und kein Fix eingereicht. Der Start-Helfer aus Durchgang 1 bleibt die belegt wirksame Abhilfe. Die Messzeile ist wieder entfernt, der Arbeitsbaum enthält keine Codeänderung.

### Wege
1. Dauerhafte Messung im Helfer (Empfehlung): Bei jedem zweiten Start protokolliert `UITestLaunch.start` zusätzlich Zeit seit Testbeginn, Rechnerlast und Prozesskennung der App. Der nächste echte Fall (CI oder Hennings Mac) belegt dann die Ursache. 1 Datei, kein Produktcode.
2. Die sechs übrigen Klassen auf den Helfer umstellen (Durchgang 2/3 wie geplant): Abhilfe statt Ursache, schützt aber sicher.
3. Aufwärmstart vor dem Lauf: ohne belegte Ursache nicht begründbar, nicht empfohlen.

### Entscheidung PO (2026-10-10)
Weg 1: Messung im Helfer einbauen. Umstellung der übrigen Klassen vorerst nicht.

### Technical Approach
`UITestLaunch.start` (`RestockUITests/UITestWait.swift`) ergänzt die Meldung „zweiter Start nötig“ um: Sekunden seit Start des Testfalls bzw. des Testlaufs, Rechnerlast (`getloadavg`), Prozesskennung der App vor dem Neustart (`app.processIdentifier`) und danach, Anzahl bisheriger Starts im Lauf. Reine Test-Hilfe; Unit-Test der Meldungsformatierung als Funktion. Dateien: `UITestWait.swift`, ggf. eine Testdatei. Risiko: niedrig. Geschätzt +40/−5 Zeilen.

### Open Questions
- [ ] Wie belegt man die Wirksamkeit, wenn der Fehler nicht auftritt? Vorschlag für die Spec: Nachweis = Meldung erscheint mit allen Feldern, sobald ein Neustart erzwungen wird (Gegenprobe mit absichtlich falscher Erwartung).
