---
entity_id: test-111-durchgang-1-ui-test-wait
type: bugfix
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: fix-111-ui-test-flakes
tags: [test, ui-test, flake, wait-helper, ci, issue-111]
---

# UI-Test-Flakes durch langsame Einzelabfragen beheben (Issue #111, Durchgang 1)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Die UI-Suite in der CI fällt bei unverändertem App-Code sporadisch durch (am 2026-10-05 sechs
verschiedene Tests in sechs roten Läufen, jeweils 70 von 71 grün). Belegte Ursache (Auswertung der
xcresult-Bündel, Analyse in `docs/context/fix-111-ui-test-flakes.md`): Einzelne XCUITest-Abfragen
dauern auf dem Runner sporadisch 4,0–4,3 s (in grünen Tests bis 14,3 s) und fressen eine
5-s-Frist fast vollständig; in zwei Fällen kam die Momentaufnahme ohne Rahmen
(`{{inf, inf}, {0, 0}}`) zurück, und das Prädikat `isHittable == true` scheitert dann hart
(„Activation point invalid“) statt `false` zu liefern. Nicht die Ursache: verdeckte oder bewegte
Elemente (0 von 7), eine zu langsame App.

Dieser Durchgang baut gemeinsame, **zustandsbasierte** Warte-Hilfen (grüne Läufe werden nicht
langsamer, nur ein ohnehin roter Lauf wartet bis zu 20 s je Stelle) und stellt die Stellen darauf
um, an denen 6 der 7 beobachteten Fehlschläge auftraten. Kein App-Code ändert sich.

**Ticket-Rahmen:** #111 ist ein Ticket mit mehreren Durchgängen (wie #98, Memory „#98 ein Ticket,
mehrere Durchgänge“); die Scoping-Limits gelten je Durchgang.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Der 7. beobachtete Fehlschlag,
`QuickAddAssignmentUITests.testToastNamesStoreAndOffersChangeAndUndo` (Toast steht 6 s, vier
nacheinander gestellte Abfragen brauchen zusammen länger), wird in Durchgang 1 **nicht** behoben.
Eine längere Frist hilft dort nicht, weil die Anzeigedauer der App die Grenze setzt. Nach Durchgang 1
ist #111 **nicht** erledigt; es gibt keine Zusage „alle Flakes behoben“. Ebenso ungeprüft bleiben die
übrigen 7 UI-Testdateien (128 Stellen mit `timeout: 5`), solange dort kein Fehlschlag gemessen ist.

## Source

- **Neu:** `RestockUITests/UITestWait.swift` — gemeinsame Hilfen (~70 LoC).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — neue Datei im Target `RestockUITests`
  registrieren: `PBXBuildFile`, `PBXFileReference`, `PBXGroup` (Gruppe `RestockUITests`),
  `PBXSourcesBuildPhase` (UI-Test-Target). Xcode entdeckt Dateien nicht selbst (CLAUDE.md,
  „Adding new Swift files“).
- **Geändert:** `RestockUITests/ShoppingRouteUITests.swift` — `openedStore()` (Zeilen 32–36:
  `waitForExistence` plus Erwartung `isHittable == true` mit 5 s) auf `waitUntilHittable`; in
  `testSortModeIsRememberedPerStore` tippt der Neustart-Zweig (Zeilen 114–116) die Kachel ohne jedes
  Hittable-Warten, dort kommt derselbe Aufruf davor.
- **Geändert:** `RestockUITests/AddItemQuantitySuggestionUITests.swift` — `openQuittenhofStoreDetail`
  (Zeilen 59–62) auf `waitUntilHittable`; die Erwartung `value == "l"` nach `typeText` in
  `testStaleSuggestionIsDroppedWhenNameIsTypedFurther` (Zeilen 204–205, 5 s) auf die Standardfrist.
- **Geändert:** `RestockUITests/QuickAddAssignmentUITests.swift` — `labelOf` (Zeilen 58–62, 5 s,
  `XCTNSPredicateExpectation`) und `openStore` (Zeilen 69–76, `isHittable` mit 10 s) auf die
  gemeinsamen Hilfen. Betrifft `testUnassignedCardShowsCountAndNames` (Zeilen 206–207, die
  Fehlermeldungen lesen heute `card.label` mit einer **weiteren** Abfrage) und alle Tests, die
  `openStore` nutzen.
- **Hinweis zur Zuordnung:** `testCreatingCustomCategoryFromItemDialog` liegt in
  `ShoppingRouteUITests` (Zeile 123) und läuft über `openedStore()`; es wird also über die Änderung
  an dieser Datei abgedeckt, nicht über `QuickAddAssignmentUITests`.
- **Nicht geändert:** alles unter `SmartCart/`, `.github/workflows/ci.yml` auf `main`, das Scheme,
  die übrigen UI-Testdateien. `ReceiptReviewUITests` behält seine eigenen `private`-Hilfen
  (`waitUntilSettled`, `waitUntilLabel`, `labelOf`); sie waren Vorbild (Fehlermeldung nennt den
  erreichten Zustand) und werden hier nicht umgezogen.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCTest / XCUITest (`XCUIElement`, `XCTestCase`) | framework | Abfragen, Rahmen, `isHittable`, Fehlerausgabe |
| `docs/context/fix-111-ui-test-flakes.md` | doc | Analyse, Messwerte, Alternativen |
| `RestockUITests/ReceiptReviewUITests.swift` | test | Vorbild für zustandsmeldende Wartehilfen (`waitUntilLabel`) |
| `.github/workflows/ci.yml` | ci | Vorlage für den Wegwerf-Zweig des Nachweises (nur dort verändert, nie auf `main`) |
| Simulator `Restock-Validate` | tool | lokaler Gesamtlauf; nie parallel (Memory „Eigenes Testgerät je Projekt“) |
| GitHub-Runner `macos-26` | ci | Nachweis mit `-test-iterations 30` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/UITestWait.swift` | CREATE | `waitUntilHittable(timeout:)`, `waitForLabel(contains:timeout:)`, Konstante Standardfrist 20 s |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Neue Datei in vier Abschnitten registrieren |
| `RestockUITests/ShoppingRouteUITests.swift` | MODIFY | `openedStore()` und Neustart-Zweig in `testSortModeIsRememberedPerStore` auf `waitUntilHittable` |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift` | MODIFY | `openQuittenhofStoreDetail` auf `waitUntilHittable`; Wert-Erwartung nach `typeText` auf Standardfrist |
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY | `labelOf` und `openStore` auf die gemeinsamen Hilfen |

### Estimated Changes

- Files: 5 (Obergrenze des Limits 4–5; nichts darüber hinaus)
- LoC: ca. +110 / −20 (Limit ±250). Hinweis: Das LoC-Gate zählt Testcode als Produktivcode (Memory
  „LoC-Gate zählt Testcode als Produktiv“); Umfang ist deshalb vor dem Abschluss mit `git diff
  --stat` gegen den Tip-Commit zu prüfen. Wird das Limit überschritten, zuerst Rückmeldung mit
  Schätzung, nicht das Limit anheben.

## Definition of Done

- [ ] UI-Test-Target baut, neue Datei an allen vier Stellen in `project.pbxproj` registriert (AC-12)
- [ ] Hilfstests T1–T4 grün (AC-1 bis AC-5)
- [ ] Gesamte UI- und Unit-Suite lokal auf `Restock-Validate` grün, Testzahl > 0, kein Abbruch (AC-7)
- [ ] Runner-Nachweis vorher/nachher mit `-test-iterations 30` dokumentiert, nachher 0 Fehler (AC-8, AC-9)
- [ ] Kein Diff unter `SmartCart/`, `ci.yml` auf `main` unverändert, Umfang im Limit (AC-9, AC-10)
- [ ] Toast-Fehlschlag in Ticket und Bericht als offen benannt, #111 bleibt offen (AC-11)

## Implementation Details

**Hilfen (`UITestWait.swift`).** Wo sie liegen (Extension auf `XCUIElement` bzw. freie Funktion mit
`XCTestCase`-Bezug) legt Phase 4 fest; Signaturen und Verhalten sind verbindlich:

- `UITestWait.defaultTimeout`: Konstante `20` Sekunden. Begründung: länger als die längste belegte
  Einzelabfrage in roten Tests (≈ 4,3 s) und in grünen (14,3 s), dazu Reserve für eine zweite Abfrage.
- `XCUIElement.waitUntilHittable(timeout:)` — eigene Polling-Schleife mit Deadline, kein
  `XCTNSPredicateExpectation` (dessen Auswertung ist an `isHittable` bei fehlendem Rahmen gescheitert).
  Je Runde, in dieser Reihenfolge: (1) `exists`; (2) `frame` lesen: endlich (`isFinite` in allen
  vier Komponenten, also kein `inf`/`nan`) **und** nicht leer (`!isEmpty`); (3) erst dann
  `isHittable`. Ein `inf`-Rahmen oder ein leerer Rahmen zählt als „noch nicht bereit“ und führt zu
  einer weiteren Runde, nie zu einem harten Fehler. Kurze Pause zwischen den Runden (Größenordnung
  0,25 s, über `RunLoop`/`Thread.sleep`, damit die Schleife die Abfragen nicht in dichter Folge
  stellt). Bei Erfolg kehrt sie sofort zurück. Rückgabe: `Bool`; zusätzlich liefert eine
  Variante/ein Ergebnis den **zuletzt gesehenen Zustand** (exists, frame, isHittable), den die
  Aufrufer in die Fehlermeldung übernehmen (`XCTAssertTrue(…, "… — zuletzt: \(state)")`). Der Zustand
  stammt aus der letzten Runde der Schleife, es gibt keine Extra-Abfrage nach Fristablauf.
- `waitForLabel(contains:timeout:)` auf einem Element: Schleife mit Deadline, liest das Label **einmal
  je Runde** und prüft den Text; gibt `(matched: Bool, lastLabel: String)` zurück. Die
  Fehlermeldung nennt `lastLabel`, ohne `element.label` ein weiteres Mal abzufragen — die zusätzliche
  Abfrage nach dem Fristablauf war in `testUnassignedCardShowsCountAndNames` selbst eine der langen
  Abfragen.
- Zustandsbasiert: Beide Hilfen enden beim ersten Treffer. Grüne Läufe werden nicht langsamer.

**Umstellungen.**

1. `ShoppingRouteUITests.openedStore()` und der Neustart-Zweig von `testSortModeIsRememberedPerStore`:
   `waitForExistence(timeout: 15)` bleibt (Kaltstart), danach `waitUntilHittable` statt
   `expectation(for: isHittable…)` mit `waitForExpectations(timeout: 5)`; Prüfungen und Ablauf
   danach unverändert.
2. `AddItemQuantitySuggestionUITests.openQuittenhofStoreDetail`: gleiche Umstellung. Die Erwartung
   `value == "l"` bekommt `UITestWait.defaultTimeout` statt 5 s (Tasten kommen auf dem Runner bis 3 s
   verspätet an, Memory „UI-Test liest Feld nach typeText zu früh“); die Prüfung bleibt `value == "l"`.
3. `QuickAddAssignmentUITests`: `labelOf` ruft `waitForLabel` auf (Signatur bleibt für die Aufrufer
   kompatibel, Standardfrist statt 5 s); `testUnassignedCardShowsCountAndNames` nutzt den
   zurückgegebenen `lastLabel` statt `card.label` in der Meldung; `openStore` nutzt `waitUntilHittable`
   statt `isHittable` mit 10 s. Die Toast-Tests werden **nicht** angefasst (Durchgang 2).

**Nachweis auf dem Runner (Pflicht, Wegwerf-Zweig).** Messverfahren aus #82 (Memory „UI-Test liest
Feld nach typeText zu früh“): Wegwerf-Zweig mit `ci.yml`, eingeschränkt auf die betroffenen Klassen
(`ShoppingRouteUITests`, `AddItemQuantitySuggestionUITests`, `QuickAddAssignmentUITests` ohne die
Toast-Tests) mit `-test-iterations 30` und **ohne** Retry (`-retry-tests-on-failure` bleibt aus),
Start per `gh workflow run`.

- **Vorher-Lauf** (Stand `main`, ohne Fix): Fehlerquote wird gemessen. Zeigt der Lauf 0 Fehler,
  wird das **offen benannt** (die Flakes sind sporadisch; dann ist der Nachweis „vorher rot“ nicht
  erbracht, und der Nachher-Lauf beweist weniger) und ein weiterer Vorher-Lauf versucht, bevor
  abgeschlossen wird.
- **Nachher-Lauf** (mit Fix): dieselbe Messung, erwartet 0 Fehler.
- **Gleiche Runner-Lage:** Aus dem `UITestResults.xcresult` des Nachher-Laufs wird belegt, dass
  weiterhin Einzelabfragen > 4 s vorkommen (Auswertung der `activities`-Zeitachse wie in der
  Analyse). Nur dann ist „Tests grün“ ein Beleg für den Fix und nicht für einen ruhigen Runner.
- `ci.yml` auf `main` bleibt unverändert; der Wegwerf-Zweig wird danach gelöscht.

**Lokal:** Gesamte UI-Suite auf `Restock-Validate` im gemeinsamen Lauf, ohne zusätzliche
Build-Settings (Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“); Testzahl > 0 und Abbrüche
prüfen (Memory „Null-Test-Lauf ist kein Grün“).

## Test Plan

### Automated Tests (TDD RED)

Die Änderung betrifft Testcode; RED entsteht über eine gezielte Probe der Hilfen, nicht über die
Produkt-Tests (die laufen heute grün, weil das Problem sporadisch ist).

- [ ] T1: GIVEN ein Element, dessen Rahmen zunächst `{{inf, inf}, {0, 0}}` meldet und nach 2 Runden
  endlich ist, WHEN `waitUntilHittable` läuft, THEN wartet sie weiter und liefert `true`, statt hart zu
  scheitern. Prüfung als kleiner Hilfstest an einer Prüfstelle der Hilfsfunktion (der Rahmenlesepfad
  ist so getrennt, dass die Entscheidungsregel „endlich, nicht leer“ ohne App prüfbar ist), RED:
  vorher existiert die Hilfe nicht.
- [ ] T2: GIVEN ein Element, das hittable ist, WHEN `waitUntilHittable(timeout: 20)` läuft, THEN kehrt
  sie nach der ersten Runde zurück (deutlich unter der Frist).
- [ ] T3: GIVEN ein Element, das nie hittable wird, WHEN die Frist abläuft, THEN nennt die Meldung den
  zuletzt gesehenen Zustand (exists, frame, hittable).
- [ ] T4: GIVEN eine Karte mit Label „2 Artikel ohne Laden, Testartikel Zwei“, WHEN `waitForLabel(contains:
  "Testartikel Eins")` abläuft, THEN ist `matched == false` und `lastLabel` enthält den gelesenen Text.
- [ ] T5: GIVEN die fünf umgestellten Tests (`testSwitchingSortModesReordersList`,
  `testSortModeIsRememberedPerStore`, `testUnassignedCardShowsCountAndNames`,
  `testCreatingCustomCategoryFromItemDialog`, `testStaleSuggestionIsDroppedWhenNameIsTypedFurther`),
  WHEN sie im gemeinsamen Lauf auf `Restock-Validate` laufen, THEN sind sie grün mit unveränderten
  Prüfungen.
- [ ] T6: GIVEN die gesamte UI-Suite, WHEN sie lokal im gemeinsamen Lauf läuft, THEN sind alle Tests grün
  und die Testzahl ist > 0.
- [ ] T7: GIVEN der Wegwerf-Zweig mit `-test-iterations 30` ohne Retry, WHEN Vorher- und Nachher-Lauf auf
  dem Runner laufen, THEN zeigt der Nachher-Lauf 0 Fehler, und das xcresult belegt Einzelabfragen > 4 s.
- [ ] T8: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat -- SmartCart/` läuft, THEN ist die
  Ausgabe leer.

Die Form von T1–T4 (eigene Hilfstests in `RestockUITests` oder Prüfung der Entscheidungsregel als
reine Funktion ohne App) legt Phase 4 fest; Verbindlich ist, dass die inf-Rahmen-Regel und die
Zustandsmeldung vor der Umstellung der Tests nachgewiesen sind. Hilfstests ohne Eigenzustand kosten
keine App-Starts. Der Umfang einschließlich dieser Tests muss in die ca. +110 LoC passen; passt er
nicht, hat der Nachweis der Regel Vorrang vor einer breiteren Zustandsausgabe.

## Acceptance Criteria

- **AC-1:** GIVEN ein Element, dessen Rahmen `inf` oder leer meldet, WHEN `waitUntilHittable` läuft,
  THEN wartet sie bis zur Frist weiter und scheitert nicht hart; erst ein endlicher, nicht leerer
  Rahmen mit `isHittable == true` beendet sie mit Erfolg.
- **AC-2:** GIVEN ein Element, das sofort hittable ist, WHEN `waitUntilHittable` läuft, THEN kehrt sie in
  der ersten Runde zurück (zustandsbasiert, keine feste Wartezeit).
- **AC-3:** GIVEN ein Element, das bis zum Fristende nicht hittable wird, WHEN die Frist abläuft, THEN
  nennt die Fehlermeldung den zuletzt gesehenen Zustand (exists, frame, hittable) ohne zusätzliche
  Abfrage nach Fristablauf.
- **AC-4:** GIVEN ein Label, das den erwarteten Text nicht enthält, WHEN `waitForLabel(contains:)`
  abläuft, THEN liefert sie den zuletzt gelesenen Label-Text zurück, und die Fehlermeldung nennt ihn.
- **AC-5:** GIVEN die Standardfrist, WHEN sie benutzt wird, THEN beträgt sie 20 s und ist an einer Stelle
  (`UITestWait.defaultTimeout`) definiert.
- **AC-6:** GIVEN die Tests `ShoppingRouteUITests.testSwitchingSortModesReordersList`,
  `testSortModeIsRememberedPerStore`, `testCreatingCustomCategoryFromItemDialog`,
  `QuickAddAssignmentUITests.testUnassignedCardShowsCountAndNames` und
  `AddItemQuantitySuggestionUITests.testStaleSuggestionIsDroppedWhenNameIsTypedFurther`, WHEN der
  Durchgang umgesetzt ist, THEN prüfen sie inhaltlich dasselbe wie vorher (gleiche Assertions auf
  Sortierreihenfolge, Kategorie, Zähler-/Namenstext, Einheit „l“); geändert ist nur das Warten.
- **AC-7:** GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft,
  THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- **AC-8:** GIVEN der Wegwerf-Zweig mit auf die betroffenen Klassen eingeschränkter `ci.yml` und
  `-test-iterations 30` ohne Retry, WHEN der Vorher-Lauf (Stand `main`) läuft, THEN ist die Fehlerquote
  dokumentiert; ist sie 0, wird das offen benannt und der Nachweis entsprechend eingeschränkt.
- **AC-9:** GIVEN derselbe Wegwerf-Zweig mit dem Fix, WHEN der Nachher-Lauf läuft, THEN sind es 0 Fehler,
  und das xcresult belegt, dass weiterhin Einzelabfragen > 4 s vorkommen (gleiche Runner-Lage, Tests
  trotzdem grün). `ci.yml` auf `main` ist unverändert.
- **AC-10:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN gibt es
  keine Änderung unter `SmartCart/` (App-Verhalten unverändert), und der Umfang liegt bei 5 Dateien
  und ca. +110/−20 LoC.
- **AC-11:** GIVEN der Abschluss des Durchgangs, WHEN Ticket und Berichte formuliert werden, THEN ist
  der Fehlschlag `testToastNamesStoreAndOffersChangeAndUndo` ausdrücklich als offen genannt
  (Durchgang 2); es gibt keine Aussage „alle Flakes behoben“, und #111 bleibt offen.
- **AC-12:** GIVEN die neue Datei, WHEN `xcodebuild` das UI-Test-Target baut, THEN ist sie in
  `project.pbxproj` an allen vier Stellen registriert, und der Build läuft ohne Fehler.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testinfrastruktur, kein Eingriff in App-Architektur oder bestehende ADRs. Die
  gemeinsame Hilfsdatei folgt dem Muster „zustandsbasiert statt fester Fristen“ aus den Memory-Einträgen
  zu Kaltstart- und Abfragezeiten.

## Folge-Durchgänge im selben Ticket

- **Durchgang 2 (offen, nicht Teil dieser Spec):** Toast-Test
  `testToastNamesStoreAndOffersChangeAndUndo`. Geplant: DEBUG-only Launch-Argument
  `-quickAddToastSecondsForUITests <n>` in der App; ohne Argument und im Release bleibt es bei 6 s.
  Gilt für die Tests, die den Toast-Inhalt lesen (`testToastNamesStoreAndOffersChangeAndUndo`,
  `testUndoRemovesToastAndItem`, `testChangeStoreMovesItemAndRemembersCorrection`);
  `testToastStaysVisibleLongerThanTwoSeconds` läuft weiter **ohne** Argument und prüft die echte
  Dauer. Geschätzt 3 Dateien, ca. +40/−10 LoC. Dieser 7. beobachtete Fehlschlag bleibt bis dahin offen.
- **Durchgang 3 (nur bei gemessenem Bedarf):** die übrigen 7 UI-Testdateien (restliche
  `timeout: 5` auf die Standardfrist). Erst nach Messung, wenn dort Fehlschläge auftreten;
  Umfang offen.
- Überschneidung, gleiches Ziel, eigene Belege, nicht hier gezogen: #32 (Fokus-Warten),
  #82 Teil 2 (Tipp aufs Häkchen), #105 (zentraler Start mit Gegenprobe).

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Gemeinsame zustandsbasierte Hilfen mit Frist 20 s; `isHittable` erst nach endlichem Rahmen | trifft die belegte Ursache (lange Einzelabfrage, `inf`-Rahmen); grüne Läufe nicht langsamer; wiederverwendbar für Durchgang 2/3 und #32/#105 |
| B | `-retry-tests-on-failure` in der CI | eine Zeile, kaschiert die Ursache, verlängert rote Läufe (Suite ≈ 38 Min); Wiederholungen wurden früher bewusst entfernt; verworfen |
| C | Direktes `tap()` ohne `isHittable`-Warten | kleinster Eingriff, aber unbelegt, ob `tap()` bei `inf`-Rahmen nicht ebenfalls hart scheitert; verworfen als Hauptweg |
| D | Größerer oder anderer Runner | würde die Ursache treffen, kostet Geld, Wirkung unbelegt; verworfen |
| E | Pauschal alle `timeout: 5` auf 20 s hochsetzen (alle 10 Dateien) | sprengt die Limits, verlängert rote Läufe, verdeckt echte Regressionen; nur bei gemessenem Bedarf in Durchgang 3 |
| F | Toast per einmaliger `snapshot()`-Abfrage lesen | kein App-Eingriff, bleibt aber ein Wettlauf gegen 6 s Anzeigedauer bei 3–4 s je Abfrage (bei 14-s-Ausreißer chancenlos); Hauptweg verworfen, ergänzend nutzbar (Durchgang 2) |
| G | Pfadfilter für reine Doku-/CI-Änderungen | anderes Ziel (Laufzeit statt Stabilität), eigenes Issue |

Kein Modell beteiligt: alles deterministische Wartelogik. Gekippte frühere Entscheidung: keine ADR;
nur die Arbeitsannahme „5 s genügen für eine Abfrage“ (Memory „CI-UI-Abfragen dauern 4 s“).

**Entscheidung:** Weg A in Durchgang 1; Toast in Durchgang 2.

## Risiken

- **pbxproj:** Neue Datei muss an vier Stellen mit eindeutiger 24-stelliger Hex-UUID stehen;
  Tippfehler führen zu „No such file“ oder zur Datei außerhalb des Targets (Tests kompilieren, die
  Hilfen fehlen). Schutz: Build des UI-Test-Targets und Gegenprobe per `grep` der UUIDs (AC-12);
  Eintrag über den `general-purpose`-Agenten, wie in CLAUDE.md vorgesehen.
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +110/−20 liegt im Limit, wird aber mit den
  Hilfstests (T1–T4) knapp; Umfang vor dem Abschluss prüfen, bei Überschreitung Rückfrage mit
  Schätzung, nicht das Limit anheben (Memory „LoC-Gate zählt Testcode als Produktivcode“).
- **Vorher-Lauf zeigt 0 Fehler:** Die Flakes sind sporadisch (#82: lokal 90 Läufe 0 Fehler). Dann ist
  „vorher rot“ nicht erbracht; das wird offen benannt, ein zweiter Vorher-Lauf versucht, und der
  Nachweis gilt eingeschränkt (Nachher 0 Fehler plus > 4-s-Abfragen im xcresult).
- **Längere rote Läufe:** Ein echter Fehler wartet jetzt bis 20 s je Stelle statt 5 s. Akzeptiert, weil
  grüne Läufe unverändert schnell bleiben und die Meldung den erreichten Zustand nennt.
- **Teilerfolg:** Der Toast-Test bleibt rot-anfällig; wer nach Durchgang 1 „grün beim ersten Versuch“
  erwartet, irrt. Deshalb Offene Grenze in jeder Zusage (AC-11).
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün;
  bei Start-Hänger der Unit-Suite Aufräum-Rezept aus #63, nicht den Test ändern.
- **Runner-Zeit:** 30 Iterationen der betroffenen Klassen laufen deutlich unter der 60-Min-Grenze nur,
  wenn die Klassen klein genug sind; Reihenfolge und Iterationszahl werden bei Bedarf gekürzt, nie
  ohne Vermerk.

## Changelog

- 2026-10-06: Initial spec created (Durchgang 1 von #111; Durchgang 2 und 3 als Folge-Durchgänge
  dokumentiert)
