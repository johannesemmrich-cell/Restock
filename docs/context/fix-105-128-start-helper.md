# Context: fix-105-128-start-helper

## Request Summary
Gesäte UI-Tests sollen beim ersten Versuch grün starten. #105 (App startet gelegentlich ohne Launch-Argumente, ca. jeder 5. erste Start) und #128 (voller Lauf auf Restock-Validate scheitert 4 von 4 Mal am ersten Test) haben dieselbe Ursache und werden gemeinsam gelöst (PO-Entscheidung 2026-10-10: bündeln).

## Befund aus dem Intake (belegt, #128-Kommentar vom 2026-10-10)
- Reproduktion: voller UI-Lauf auf Restock-Validate (`-only-testing:RestockUITests`), 4 von 4 rot beim ersten Test `AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList`. Einzeltest und Einzelklasse grün, auch nach Deinstallation der App.
- Messung (temporäres `NSLog` der Startargumente in `SmartCartApp.init`, danach entfernt): Der erste App-Prozess des Laufs hatte **leere Argumente** (kein `-seed…`, kein `-AppleLanguages`, kein `-hasCompletedOnboarding`). Alle späteren Prozesse trugen sie. Zwischen diesem Prozess und dem Aufräumstart nach dem Test lag kein zweiter Prozess, der Seed-Start des Tests fehlt also.
- Bildschirmfoto im Fehlmoment: Startseite mit dm (1x/Woche) und Lidl (2x/Woche), „Alle Listen sind leer“ — der Rest des Schnell-Eingabe-Seeds aus dem vorigen Lauf. Kein Quittenhof.
- Protokollunterschied: Im ersten Test steht „Setting up automation session“ erst nach 1,05 s und „Wait for … to idle“ nach 2,52 s; im zweiten Test nach 0,22 s und 0,85 s. Die Sitzung des Testläufers ist beim ersten Start noch nicht aufgebaut, während `launch()` läuft.
- Websuche (Apple-Foren, Swift by Sundell u. a.): nichts zu diesem Fall. Bestätigt nur, dass Argumente aus `launchArguments` des Testläufers kommen. Die Ursache stützt sich daher allein auf die Messung.
- Offen: warum der erste Start im Gesamtlauf auf Validate fast immer, auf dem CI-Simulator selten ohne Argumente erfolgt.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `RestockUITests/ShoppingRouteLearningUITests.swift:37` | `openStore` hat schon die Gegenprobe: Kachel fehlt → `terminate()` + zweiter `launch()` (Kommentar verweist auf #98) |
| `RestockUITests/DataResetUITests.swift:45-49, 61-65` | zweiter `launch()` bei fehlendem Ergebnis, eigene Variante |
| `RestockUITests/ReplenishmentUITests.swift:35-38` | zweiter `launch()`, eigene Variante |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift:51-62` | `launchedApp()` + `openQuittenhofStoreDetail`: keine Gegenprobe (#128) |
| `RestockUITests/QuickAddAssignmentUITests.swift:36-43, 75` | `launchedApp(storeless:toastDuration:)`, keine Gegenprobe |
| `RestockUITests/ShoppingRouteUITests.swift:30` | Seed-Start ohne Gegenprobe |
| `RestockUITests/LegacyLearnedPriceResetUITests.swift:29` | Seed-Start ohne Gegenprobe |
| `RestockUITests/ReceiptReviewUITests.swift:110, 151, 801` | `launchedApp`, `launchedAppWithUnresolvedLine`, Screenshot-Start, keine Gegenprobe |
| `RestockUITests/ReceiptResolutionStatsUITests.swift:54-57` | Seed optional (`seed:`), keine Gegenprobe |
| `RestockUITests/RestockUITests.swift` | Starts ohne Seed (nur Onboarding-Flag) |
| `RestockUITests/UITestWait.swift` | bestehende Warte-Hilfen (#111); Ort für einen Start-Helfer möglich |
| `SmartCart/SmartCartApp.swift:22-48` | `init()`: alle DEBUG-Seeds/Clear-Argumente laufen im `defer` |
| `Restock.xcodeproj/project.pbxproj` | neue Datei in vier Stellen eintragen (CLAUDE.md), auch im Ziel `RestockUITests` |

Von den elf Testdateien starten neun die App gesät, drei haben bereits eine eigene Wiederholung (ShoppingRouteLearning, DataReset, Replenishment), sechs nicht.

## Existing Patterns
- Einzelne Klassen wiederholen den Start selbst, jede auf eigene Weise (Erwartung je Klasse: andere Kachel).
- Jede gesäte Klasse räumt im `tearDown()` per eigenem Clear-Argument auf (CLAUDE.md), und dieser Aufräumstart ist selbst ein App-Start mit Argumenten.
- Wartehilfen: `UITestWait.defaultTimeout` (20 s), `waitUntilHittable()`, `waitForLabel(contains:)`.

## Dependencies
- Upstream: `XCUIApplication.launch()/terminate()`, Seed-Argumente in `SmartCartApp`.
- Downstream: alle UI-Klassen, die den Helfer bekommen; die CI-UI-Suite (~40 min).

## Existing Specs
- `docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md` — Wartehilfen
- `docs/specs/ui-tests/test-98-*` — Seeds, Aufräumregeln
- Memory: ui-test-app-startet-ohne-launch-argumente, ui-test-cold-start-timeouts, ui-test-seeds-muessen-aufraeumen, eigenes-testgeraet-je-projekt, null-test-lauf-ist-kein-gruen

## Risks & Considerations
- **Gegenprobe braucht ein Erwartungs-Element je Klasse** (die Kachel, die der Seed erzeugt). Ein klassenunabhängiger Beweis, dass Argumente angekommen sind, ginge nur über Produktcode (z. B. DEBUG-Marker) — Alternative für die Analyse.
- **Umfang:** Helfer + bis zu sechs Klassen + `project.pbxproj` überschreiten die Grenzen (4–5 Dateien, ±250 Zeilen) wahrscheinlich; Durchgänge nach der Vorgabe zu #98 (Limits je Durchgang) einplanen, Reihenfolge: Helfer + AddItemQuantity (belegter Fall #128), dann QuickAdd, dann Rest.
- **Wiederholung kann die Ursache nur überdecken:** Der zweite Start ist die Abhilfe, nicht die Erklärung. Die Analyse muss prüfen, ob sich der erste Start sauber abwarten lässt (z. B. Sitzung des Testläufers vor dem ersten `launch()` aufbauen).
- **Nachweis:** voller Lauf auf Restock-Validate vorher rot (4/4 belegt), nachher mehrfach grün; keine Null-Test-Läufe als Grün zählen; Simulator nie parallel nutzen.
- **Aufräumstarts** (`cleaner.launch()`) können dieselbe Lücke haben und würden dann den Rest des Seeds stehen lassen.
