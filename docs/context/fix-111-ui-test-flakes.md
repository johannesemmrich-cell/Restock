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

## Analysis

### Type
Bug (Testinfrastruktur) — App-Verhalten ist nicht betroffen.

### Root Cause (belegt, 7 von 7 roten CI-Tests ausgewertet)
Auswertung der xcresult-Bündel der Läufe 37268450172 (V1, V2), 37282304307 (V1–V3) und 37298002522
(Zeitachse aus `activities`, Video-Einzelbilder über pts zugeordnet):
- **Einzelne XCUITest-Abfragen/Bedienungshilfen-Momentaufnahmen dauern auf dem Runner sporadisch
  4,0–4,3 s** (Median 0,15–0,25 s, p90 0,5–1,2 s, je Lauf 1–8 Ausreißer > 2,5 s; in grünen Tests
  auch bis 14,3 s — die bleiben grün, weil dort 10–15 s Frist gilt). Eine solche Abfrage frisst eine
  5-s-Frist fast vollständig: 6 von 7 Fällen.
- **2 von 7 („Activation point invalid“):** Momentaufnahme kam ohne Rahmen zurück (ganzer Baum
  `{{inf, inf}, {0, 0}}`); das Prädikat `isHittable == true` scheitert dann hart statt `false` zu liefern.
- **Toast-Test:** Toast stand korrekt 6 s (Video 17,0–23,05 s). Vier nacheinander gestellte Abfragen
  (Toast, Lidl-Label, change, undo) brauchten zusammen 5,4 s; die undo-Prüfung lief 23,15–24,42 s —
  nach Ablauf. Abfragen bei sichtbarem Toast dauern in allen 6 Bündeln durchgehend 3,3–4,0 s.
- **testUnassignedCardShowsCountAndNames:** Karte zeigte den richtigen Text ruhig auf dem Video;
  zwei Abfragen (4,01 s + 2,36 s) überschritten die 5-s-Frist. Die Fehlermeldung enthält das richtige Label.
- **Nicht** die Ursache: Element verdeckt/in Bewegung (0/7, Videos ruhig, kein Banner/Scrollen/Tastatur),
  App zu langsam (App idle, „Wait for app to idle“ 0,3–0,9 s). Offen: ob die Verzögerung im
  Testrunner- oder App-Prozess (AX-Server) entsteht — für den Fix unerheblich.
Recherche: [banal PR #229](https://github.com/drawmeanelephant/banal/pull/229) (exists+hittable gemeinsam
abwarten, Koordinaten-Rückfall), [Apple-Forum 720155](https://developer.apple.com/forums/thread/720155),
[Apple-Forum 107779](https://developer.apple.com/forums/thread/107779), [Q42/Salad PR #6](https://github.com/Q42/Salad/pull/6)
(Prädikat-Warten pollt in Abständen), WWDC21 10296 (Test-Wiederholungen).

### Affected Files (with changes)
| File | Change Type | Durchgang | Description |
|------|-------------|-----------|-------------|
| `RestockUITests/UITestWait.swift` | CREATE | 1 | Gemeinsame Hilfen: `waitUntilHittable` (eigene Schleife mit Deadline: exists → Rahmen endlich und nicht leer → isHittable; kein harter Fehler bei inf-Rahmen), `waitForLabel(contains:)` (liefert zuletzt gelesenen Zustand für die Fehlermeldung, keine Extra-Abfrage), Konstante Standardfrist 20 s |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | 1 | Neue Datei registrieren (kein synchronisierter Ordner, 4 Stellen) |
| `RestockUITests/ShoppingRouteUITests.swift` | MODIFY | 1 | `openedStore()` Z. 33–35 auf `waitUntilHittable` |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift` | MODIFY | 1 | Z. 60–62 auf `waitUntilHittable`; 5-s-Wert-Prädikat nach `typeText` auf Standardfrist |
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY | 1+2 | `labelOf`/`openStore` auf gemeinsame Hilfen (D1); Toast-Tests mit Launch-Argument (D2) |
| `SmartCart/SmartCartApp.swift` bzw. `SmartCart/Views/Home/HomeView.swift` | MODIFY | 2 | DEBUG-only Launch-Argument `-quickAddToastSecondsForUITests <n>`; ohne Argument und im Release bleibt es bei 6 s |
| übrige 7 UI-Testdateien | MODIFY | 3 (nur bei Bedarf) | restliche `timeout: 5` auf Standardfrist — erst nach Messung, wenn dort Fehlschläge auftreten |

### Scope Assessment
- Durchgang 1: 5 Dateien, ca. +110/−20 LoC (behebt 6 der 7 beobachteten Fehlschläge)
- Durchgang 2: 3 Dateien, ca. +40/−10 LoC (Toast)
- Durchgang 3: offen, nur bei gemessenem Bedarf
- Risk Level: LOW für die App (DEBUG-only Argument, sonst nur Testcode); MEDIUM für die Suite (gemeinsame Hilfsdatei, pbxproj)

### Technical Approach (Empfehlung)
1. **Frist größer als die längste Einzelabfrage**, aber zustandsbasiert: grüne Läufe werden nicht
   langsamer, nur rote warten länger (max. 20 s je Stelle).
2. **isHittable nie als Prädikat direkt lesen**, sondern erst nach endlichem Rahmen — behebt den harten
   „Activation point invalid“-Fehler.
3. **Toast:** DEBUG-Launch-Argument für längere Anzeigedauer nur in den Tests, die den Toast-Inhalt lesen
   (`testToastNamesStoreAndOffersChangeAndUndo`, `testUndoRemovesToastAndItem`,
   `testChangeStoreMovesItemAndRemembersCorrection`). `testToastStaysVisibleLongerThanTwoSeconds` läuft
   bewusst OHNE Argument und prüft weiter die echte Dauer. Etabliertes Muster (Seeds in `SmartCartApp`).
4. **Nachweis (Pflicht, auf dem Runner):** Wegwerf-Zweig, `ci.yml` auf die betroffenen Klassen +
   `-test-iterations 30` (ohne Retry), Start per `gh workflow run`. Vorher-Lauf auf main-Stand zeigt die
   Fehlerquote, Nachher-Lauf mit Fix dieselbe Messung mit 0 Fehlern; dazu aus dem xcresult belegen,
   dass weiterhin Einzelabfragen > 4 s vorkommen (gleiche Runner-Lage, Tests trotzdem grün).

### Alternativen (bewertet)
- **Toast per einmaliger `snapshot()`-Abfrage** statt Launch-Argument: kein App-Eingriff, aber 6 s
  Anzeige gegen 3–4 s je Abfrage bleibt ein Wettlauf (bei 14-s-Ausreißer chancenlos). Verworfen als
  Hauptweg, ergänzend nutzbar.
- **`-retry-tests-on-failure` in der CI:** eine Zeile, kaschiert aber die Ursache, verlängert rote Läufe;
  Wiederholungen wurden früher bewusst wieder entfernt. Nicht empfohlen.
- **Direktes `tap()` ohne isHittable-Warten:** kleinster Eingriff; ob `tap()` bei inf-Rahmen nicht
  ebenfalls hart scheitert, ist unbelegt → nicht als Hauptweg.
- **Größerer/anderer Runner:** würde die Ursache treffen, kostet Geld, Wirkung unbelegt.
- **Pfadfilter für reine Doku-/CI-Änderungen:** anderes Ziel (Laufzeit, nicht Stabilität) → eigenes Issue.

### Dependencies
- Später nutzbar für #32 (Fokus-Warten), #105 (zentraler Start), #82 Teil 2 — gleiches Ziel, aber eigene
  Belege; nicht in diesen Durchgang gezogen (Scoping-Limit).

### Open Questions
- keine PO-Fragen; Umfang je Durchgang innerhalb der Limits.
