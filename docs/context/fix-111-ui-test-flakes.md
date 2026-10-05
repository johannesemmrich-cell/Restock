# Context: fix-111-ui-test-flakes

## Request Summary
Die UI-Suite in der CI (Job `ui-test`, ~38 Min reine Testzeit, 71 Tests) fällt bei unverändertem App-Code
sporadisch durch — am 2026-10-05 sechs verschiedene Tests in sechs roten Läufen, jeweils 70/71 grün.
Ziel (Issue #111): **UI-Tests beim ersten Versuch grün**, unabhängig vom Tempo des Rechners, ohne das
sichtbare Verhalten der App zu ändern.

## Beobachtete Fehlschläge (aus Issue #111 + Kommentaren)
| Test | Meldung | Klasse |
|------|---------|--------|
| `QuickAddAssignmentUITests.testToastNamesStoreAndOffersChangeAndUndo` | „Rückgängig“ fehlt | Toast (6 s) weg, bevor alle Prüfungen durch sind |
| `ShoppingRouteUITests.testSwitchingSortModesReordersList` | 5 s auf `isHittable == 1` überschritten | Kachel nach Start nicht antippbar |
| `ShoppingRouteUITests.testSortModeIsRememberedPerStore` | 5 s `isHittable` | dito |
| `QuickAddAssignmentUITests.testUnassignedCardShowsCountAndNames` | „Name fehlt — bekommen: 2 Artikel ohne Laden, Testartikel Zwei, **Testartikel Eins**, …“ | Prädikat-Warten (5 s) läuft ab, obwohl der Text zum Fehlerzeitpunkt stimmt → Abfrage selbst langsam? |
| `…testCreatingCustomCategoryFromItemDialog` | 5 s `isHittable` | Kachel/Element nicht antippbar |
| `AddItemQuantitySuggestionUITests.testStaleSuggestionIsDroppedWhenNameIsTypedFurther` | (a) „Activation point invalid“ an Quittenhof-Kachel, (b) 5 s auf Einheit `value == "l"` | (a) Element in Bewegung/außerhalb, (b) Tasten kommen verspätet an |

Messung im Issue: Runner-Image grün/rot identisch (`macos-26-arm64` 20260907.0351.1), Testzeit gleich
(2206 s grün, 2104–2306 s rot) → „langsamerer Runner“ **nicht** belegt. Tageszeit-Muster nur Hinweis.
CI-Bilanz letzte 100 Läufe `ci.yml`: 65 success, 22 failure, 13 cancelled.
Rote Läufe mit evtl. noch vorhandenem `UITestResults.xcresult` (7 Tage Aufbewahrung): 37298002522,
37282304307, 37268450172, 37213446221, 37139777182 u. a.

## Related Files
| File | Relevance |
|------|-----------|
| `RestockUITests/QuickAddAssignmentUITests.swift` | Toast-Tests; eigene `labelOf` (XCTNSPredicateExpectation, 5 s), `openStore` (isHittable 10 s) |
| `RestockUITests/ShoppingRouteUITests.swift` | `openedStore()` wartet 5 s auf `isHittable` der Kachel; `waitForOrder` mit 5-s-Schleife |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift` | `openQuittenhofStoreDetail` 5 s `isHittable`; Wert-Prädikat 5 s nach `typeText` |
| `RestockUITests/ReceiptReviewUITests.swift` | Bereits robuste Hilfen: `waitUntilSettled` (30 s), `waitUntilLabel` (meldet erreichten Zustand), `tapScrollingIntoView`, `clear()` mit Wiederholung (#82 Teil 1) |
| `RestockUITests/ShoppingRouteLearningUITests.swift` | hat bereits die Start-Gegenprobe aus #105 |
| übrige UI-Testdateien (10 insgesamt, 3212 Zeilen) | 128× `timeout: 5`, 9× `3`, 1× `2`; alle Hilfen sind `private` je Datei kopiert — **keine gemeinsame Hilfsdatei** |
| `SmartCart/Views/Home/HomeView.swift:1479–1508` | `showQuickAddToast(..., duration: 6)`; Abräumen per `asyncAfter`, bleibt stehen solange `showStoreCorrection` |
| `SmartCart/Views/Home/QuickAddTargetViews.swift:139–156` | Toast-Kennungen `quickAdd.toast[.message/.change/.undo]` |
| `.github/workflows/ci.yml` (Job `ui-test`) | ein `xcodebuild test -only-testing:RestockUITests`, kein Retry, kein Pfadfilter, 60 Min Timeout, neueste Xcode-/iOS-Version |
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` | Test-Action (Sprache de/DE); Ort für Testwiederholungs-Optionen |

## Existing Patterns
- Warten per `waitForExistence(timeout:)` + `expectation(for:evaluatedWith:)`/`XCTNSPredicateExpectation`.
- Seed-Start über Launch-Argumente (`-seed…ForUITests`), Aufräumen per `-clear…` in `tearDown`.
- DEBUG-Launch-Argumente steuern bereits Testzustände in der App (Seeds) — ein `-quickAddToastDuration`
  o. ä. wäre dasselbe Muster.
- Bewährte Robustheits-Lösungen aus Vorgängern: Fokus abwarten vor `typeText` (#32), Feld erneut lesen
  statt einmal (#82 Teil 1, 8/30 → 0/30 auf dem Runner), Start-Gegenprobe (#105), 30-s-Kaltstart
  (Memory „UI-Test-Wartezeiten bei kaltem Start“).

## Dependencies
- Upstream: XCTest/XCUITest-Abfragen (Accessibility-Snapshot), Simulator auf GitHub-Runner `macos-26`.
- Downstream: Jede Zusammenführung hängt am grünen `ui-test`-Job; Regel „Merge bei rotem UI-Flake
  erlaubt“ (nur Doku/CI-Dateien) ist ein Notbehelf, solange #111 offen ist.

## Überschneidende offene Tickets (Bündel-Kandidaten, gleiches Ziel)
- **#32** Tippen ohne Fokus-Warten (RestockUITests.swift Z. 73/111)
- **#82 Teil 2** Tipp aufs Häkchen ohne Wirkung (nicht nachgestellt, 0/30 auf Runner)
- **#105** App startet ohne Launch-Argumente → zentraler Start-Helper mit Gegenprobe
- #17/#18 (Zustand zurücksetzen / Kennungen statt Texte) — anderes Ziel, nicht bündeln

## Existing Specs
- `docs/specs/testing/ui-test-language.md` — Sprache der UI-Tests (Scheme)
- `docs/specs/ui-tests/*` — Specs einzelner UI-Testklassen (Replenishment, ShoppingRouteLearning, #98)

## Risks & Considerations
- **Ursache unbelegt.** Drei Fehlerbilder (Zeit abgelaufen, Activation point invalid, Text beim
  Fehler schon richtig) deuten eher auf langsame/blockierte Accessibility-Abfragen bzw. Bewegung der
  Startseite (Banner, Animation) als auf zu kurze App-Reaktion. Muss in der Analyse mit den xcresult-
  Aufzeichnungen geprüft werden, bevor Wartezeiten angefasst werden.
- Reproduktion: lokal bisher kaum (#82: 90 Läufe 0 Fehler); auf dem Runner Wiederholungsläufe nötig
  (Messverfahren aus #82: Einzeltest N-mal auf dem Runner).
- Umfang: 10 Dateien → sprengt 4–5-Dateien-Limit; mehrere Durchgänge unter einem Ticket (wie #98).
- LoC-Gate zählt Testcode als Produktivcode (Memory).
- Pauschales Hochsetzen aller Timeouts verlängert rote Läufe (Suite schon ~38 Min) und verdeckt echte
  Regressionen.
- Alternativen zum Testcode: Testwiederholung bei Fehlschlag (`-retry-tests-on-failure`,
  bewusst zuvor verworfen? — #172 in globaler Regel nennt „CI-Wiederholung entfernen“), Pfadfilter für
  reine Doku-/CI-Änderungen, Aufteilen der Suite.
- Simulator nie parallel nutzen; eigenes Testgerät `Restock-Validate`.
