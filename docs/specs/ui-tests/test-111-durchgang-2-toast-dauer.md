---
entity_id: test-111-durchgang-2-toast-dauer
type: bugfix
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: fix-111-toast-dauer
tags: [test, ui-test, flake, toast, quick-add, debug-launch-argument, ci, issue-111]
---

# Anzeigedauer des Schnell-Hinzufügen-Toasts nur in UI-Tests verlängerbar (Issue #111, Durchgang 2)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Der 7. in #111 beobachtete Fehlschlag, `QuickAddAssignmentUITests.testToastNamesStoreAndOffersChangeAndUndo`,
blieb in Durchgang 1 offen: Der Toast steht nach dem Hinzufügen fest 6 s (`HomeView.swift:1483`), einzelne
UI-Abfragen brauchen auf dem Runner 3–4 s (Messung Durchgang 1), mehrere nacheinander gestellte Prüfungen
überschreiten die 6 s, und der Toast ist beim Lesen schon weg. Eine längere Frist im Test hilft nicht, weil
die Anzeigedauer der App die Grenze setzt (Analyse in `docs/context/fix-111-toast-dauer.md`,
Abschnitt „Analysis“; Hintergrund und Messwerte in `docs/context/fix-111-ui-test-flakes.md`).

Der Toast hat **drei** Fristen (nicht nur die 6 s): nach dem Hinzufügen 6 s (`HomeView.swift:1483`),
Neustart nach dem Schließen des Laden-Dialogs 3 s (`HomeView.swift:229`) und der Toast „verschoben nach …“
nach einem Laden-Wechsel 3 s (`HomeView.swift:1561`). `testChangeStoreMovesItemAndRemembersCorrection`
liest die Meldung gegen die 3-s-Frist von Zeile 1561; ein Argument, das nur die 6 s ändert, ließe diesen Test
offen.

Dieser Durchgang führt ein **nur im DEBUG-Build wirksames** Launch-Argument
`-quickAddToastDurationForUITests <Sekunden>` ein. Es ersetzt in `showQuickAddToast` den übergebenen Wert
`duration` und gilt damit für alle drei Aufrufe. Drei Toast-Tests starten mit 60 s; der Dauertest
`testToastStaysVisibleLongerThanTwoSeconds` startet **ohne** Argument und schützt die echte Frist. Im
Release-Build wird der Zweig nicht kompiliert, die Frist bleibt 6 s bzw. 3 s.

**Ticket-Rahmen:** #111 ist ein Ticket mit mehreren Durchgängen (Memory „#98 ein Ticket, mehrere
Durchgänge“); die Scoping-Limits gelten je Durchgang. Übernahme von Durchgang 1 und 2 erst nach dem
#115-Fix und grüner CI (PO-Entscheidung 2026-10-06, Memory „#111 Ausnahme wegen #115“).

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Nach Durchgang 2 ist #111 **nicht** erledigt. Es
bleiben (a) XCTests eigene Abfrage-Zeitgrenze („Failed to get matching snapshots: Timed out while evaluating
UI query“, Einzelabfrage 31 s), gegen die weder eine längere Testfrist noch eine längere Toast-Dauer hilft,
(b) der Wettlauf zwischen den getrennten Abfragen `frame` → `isHittable` → `tap()`, und (c) Durchgang 3
(übrige UI-Testdateien, nur bei gemessenem Bedarf). Es gibt keine Zusage „alle Flakes behoben“.

## Source

- **Geändert:** `SmartCart/Views/Home/HomeView.swift` — `showQuickAddToast` (Zeile 1495) bestimmt unter
  `#if DEBUG` die Dauer aus `UserDefaults.standard.double(forKey: "quickAddToastDurationForUITests")`;
  ein Wert > 0 ersetzt `duration`. `UserDefaults` liest Launch-Argumente der Form `-key value` ohne
  eigenes Parsen (Argument-Domain). Die drei Aufrufstellen (Zeilen 229, 1479–1483, 1561) bleiben
  unverändert. Zeilennummern sind Stand 2026-10-07.
- **Geändert:** `RestockUITests/QuickAddAssignmentUITests.swift` — `launchedApp(storeless:)` (Zeile 33)
  bekommt den Parameter `toastDuration: Int? = nil`, der bei gesetztem Wert
  `-quickAddToastDurationForUITests <n>` an `app.launchArguments` hängt. Die Tests
  `testToastNamesStoreAndOffersChangeAndUndo` (139), `testUndoRemovesToastAndItem` (153) und
  `testChangeStoreMovesItemAndRemembersCorrection` (275) starten mit `toastDuration: 60`.
  `testToastStaysVisibleLongerThanTwoSeconds` (170) bleibt ohne Argument. Die Tests, die nur kurz auf die
  Existenz des Toasts warten (Zeilen ca. 260, 340), brauchen es nicht.
- **Nicht geändert:** `RestockUITests/UITestWait.swift`, `SmartCartApp.swift`, `project.pbxproj` (keine
  neue Datei), `.github/workflows/ci.yml` auf `main`, das Scheme, alle übrigen UI-Testdateien.
- **Keine** neuen Produkt-Strings, **keine** neuen Dependencies, **keine** Änderung an `Info.plist`,
  `@AppStorage`-Schlüsseln oder Audio-Dateien. Das Argument wird nur gelesen, nie geschrieben.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `UserDefaults.standard` (Argument-Domain) | framework | liest `-quickAddToastDurationForUITests <n>` ohne eigenes Parsen |
| `DispatchQueue.main.asyncAfter` | framework | Ausblend-Timer in `showQuickAddToast` (unverändert) |
| `docs/context/fix-111-toast-dauer.md` | doc | verbindliche Analyse dieses Durchgangs |
| `docs/context/fix-111-ui-test-flakes.md` | doc | Plan, Messwerte, Alternativen für #111 |
| `docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md` | spec | Durchgang 1; Messverfahren, Nachweis auf dem Runner |
| `SmartCart/SmartCartApp.swift` (Zeilen 70, 190, 289) | code | Muster für DEBUG-Launch-Argumente (nur Vorbild, nicht geändert) |
| Simulator `Restock-Validate` | tool | lokaler Lauf und Durchlauf; nie parallel (Memory „Eigenes Testgerät je Projekt“) |
| GitHub-Runner `macos-26` | ci | Nachweis mit `-test-iterations 30` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Home/HomeView.swift` | MODIFY | `showQuickAddToast`: unter `#if DEBUG` ersetzt das Launch-Argument `-quickAddToastDurationForUITests` die Dauer (alle drei Aufrufe); Release unverändert |
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY | `launchedApp(toastDuration:)`; drei Toast-Tests mit 60 s; Dauertest ohne Argument; RED-Test T1 |

### Estimated Changes

- Files: 2 (Limit 4–5)
- LoC: ca. +25 / −5 (Limit ±250). Das LoC-Gate zählt Testcode als Produktivcode (Memory „LoC-Gate zählt
  Testcode als Produktivcode“); Umfang vor dem Abschluss mit `git diff --stat` gegen den Tip-Commit prüfen.
  Bei Überschreitung zuerst Rückmeldung mit Schätzung, nicht das Limit anheben.
- Seiteneffekte: keine im Release; im DEBUG-Build nur, wenn das Argument gesetzt ist.

## Definition of Done

- [ ] RED-Test T1 schlägt vor der Umsetzung fehl und ist danach grün (AC-1, AC-2)
- [ ] Dauertest `testToastStaysVisibleLongerThanTwoSeconds` ohne Argument grün (AC-3)
- [ ] Die drei Toast-Tests starten mit `toastDuration: 60` und prüfen inhaltlich dasselbe wie vorher (AC-7)
- [ ] Alle drei Fristen vom Argument gesteuert, ohne Argument unverändert (AC-4, AC-5)
- [ ] Release-Build kompiliert, Zweig nicht enthalten (AC-6)
- [ ] Gesamte UI- und Unit-Suite lokal auf `Restock-Validate` grün, Testzahl > 0, kein Abbruch (AC-8)
- [ ] Runner-Nachweis vorher/nachher mit `-test-iterations 30` dokumentiert (AC-9, AC-10)
- [ ] Durchlauf der App im Simulator mit echtem Verhalten (AC-11)
- [ ] Offene Grenzen in Ticket und Bericht benannt, #111 bleibt offen (AC-12)
- [ ] Diff gegen Tip-Commit: genau `HomeView.swift` und `QuickAddAssignmentUITests.swift`, ca. +25/−5 LoC, keine neuen Produkt-Strings, Dependencies, `Info.plist`- oder `@AppStorage`-Änderung, `UITestWait.swift` unberührt (AC-13)

## Implementation Details

**App (`HomeView.swift`).** Am Anfang von `showQuickAddToast(_:item:duration:)` wird die wirksame Dauer
bestimmt. Skizze (Form legt Phase 5 fest, Verhalten ist verbindlich):

```swift
var effectiveDuration = duration
#if DEBUG
let override = UserDefaults.standard.double(forKey: "quickAddToastDurationForUITests")
if override > 0 { effectiveDuration = override }
#endif
```

`asyncAfter(deadline: .now() + effectiveDuration)` nutzt den wirksamen Wert. Token gegen ältere Timer und
Bleiben solange `showStoreCorrection` offen ist, bleiben unverändert. Fehlt das Argument oder ist es `0`,
negativ oder nicht numerisch, gilt `duration` wie bisher.

**Tests (`QuickAddAssignmentUITests.swift`).** `launchedApp(storeless:toastDuration:)` hängt
`["-quickAddToastDurationForUITests", "\(n)"]` an die Launch-Argumente, wenn `toastDuration` gesetzt ist.
Die drei Toast-Tests (139, 153, 275) übergeben 60. Der Dauertest (170) ruft `launchedApp()` weiter ohne
Argument auf. `testUndoRemovesToastAndItem` wartet nur auf das Verschwinden **durch Undo**, nicht durch den
Timer; die 60 s sind dort unkritisch. Seed-Aufräumen in `tearDown()` bleibt wie bisher (das Argument
erzeugt keinen Zustand im App-Group-Container).

**RED-Test (T1).** Neuer Test in `QuickAddAssignmentUITests`: Start mit `toastDuration: 60`, Artikel
hinzufügen, **mindestens 8 s** abwarten (länger als die 6 s Standardfrist, ohne Abfragen im Fenster), dann
prüfen, dass der Toast noch sichtbar ist. Vor der Umsetzung ist der Toast nach 8 s weg (RED: Argument
unbekannt, 6 s gelten), danach grün. Eine Gegenprobe ohne Argument gibt es bereits implizit: der
Dauertest prüft die echte Frist.

**Nachweis auf dem Runner (Pflicht, Wegwerf-Zweig).** Messverfahren wie Durchgang 1 (Memory „UI-Test liest
Feld nach typeText zu früh“): Wegwerf-Zweig mit auf `QuickAddAssignmentUITests` eingeschränkter `ci.yml`,
`-test-iterations 30`, **ohne** Retry (`-retry-tests-on-failure` bleibt aus), Start per `gh workflow run`.

- **Vorher-Lauf** (Stand `main`, ohne Fix): Fehlerquote der Toast-Tests wird gemessen. Zeigt der Lauf
  0 Fehler, wird das offen benannt (Flake ist sporadisch), ein weiterer Vorher-Lauf wird versucht, bevor
  abgeschlossen wird.
- **Nachher-Lauf** (mit Fix): dieselbe Messung, erwartet 0 Fehler bei den drei Toast-Tests.
- **Gleiche Runner-Lage:** Aus dem `UITestResults.xcresult` wird belegt, dass weiterhin Einzelabfragen
  > 4 s vorkommen, sonst beweist „grün“ nur einen ruhigen Runner.
- `ci.yml` auf `main` bleibt unverändert; der Wegwerf-Zweig wird danach gelöscht.

**Durchlauf (Pflicht, „Die App wird benutzt, nicht nur gebaut“).** Nach grüner Suite wird die App im
Simulator **ohne** Argument wie ein Nutzer gestartet: Artikel per Schnell-Hinzufügen anlegen, Toast steht
etwa 6 s und verschwindet dann von selbst; „Laden ändern“ öffnet den Dialog, nach dem Schließen läuft der
Toast neu etwa 3 s. Der Durchlauf wird als Artefakt registriert (echter Lauf, Commit-Kennung und
Zeitstempel passend, nie von Hand gesetzt). Ergänzend ein Start mit dem Argument (60 s), der zeigt, dass es
nur im DEBUG-Build wirkt.

**Lokal:** Gesamte UI-Suite auf `Restock-Validate` im gemeinsamen Lauf, ohne zusätzliche Build-Settings
(Memory „CODE_SIGNING_ALLOWED=NO bricht die App-Gruppe“); Testzahl > 0 und Abbrüche prüfen (Memory
„Null-Test-Lauf ist kein Grün“).

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED): GIVEN App-Start mit `-quickAddToastDurationForUITests 60`, WHEN ein Artikel per
  Schnell-Hinzufügen angelegt und mindestens 8 s gewartet wird, THEN ist der Toast noch sichtbar.
  Vor der Umsetzung schlägt der Test fehl (Toast nach 6 s weg).
- [ ] T2: GIVEN App-Start ohne Argument, WHEN ein Artikel hinzugefügt wird, THEN steht der Toast länger
  als 2 s (bestehender `testToastStaysVisibleLongerThanTwoSeconds`, bleibt grün und unverändert).
- [ ] T3: GIVEN `testToastNamesStoreAndOffersChangeAndUndo`, `testUndoRemovesToastAndItem` und
  `testChangeStoreMovesItemAndRemembersCorrection` mit 60 s, WHEN sie im gemeinsamen Lauf auf
  `Restock-Validate` laufen, THEN sind sie grün mit unveränderten Prüfungen.
- [ ] T4: GIVEN die gesamte UI- und Unit-Suite, WHEN sie lokal im gemeinsamen Lauf läuft, THEN sind alle
  Tests grün und die Testzahl ist > 0.
- [ ] T5: GIVEN der Release-Build (`-configuration Release`, Simulator), WHEN er kompiliert, THEN gelingt
  der Build, und der DEBUG-Zweig ist nicht enthalten.
- [ ] T6: GIVEN der Wegwerf-Zweig mit `-test-iterations 30` ohne Retry, WHEN Vorher- und Nachher-Lauf auf
  dem Runner laufen, THEN zeigt der Nachher-Lauf 0 Fehler bei den Toast-Tests, und das xcresult belegt
  Einzelabfragen > 4 s.
- [ ] T7: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat` läuft, THEN sind es 2 Dateien und
  ca. +25/−5 LoC.

Der Dauertest (T2) deckt die Frist von 6 s nur nach unten (> 2 s) ab; der Durchlauf (AC-11) belegt das
echte 6-s-Verhalten ohne Argument.

## Acceptance Criteria

- **AC-1:** GIVEN der Start mit `-quickAddToastDurationForUITests 60` (DEBUG), WHEN ein Artikel per
  Schnell-Hinzufügen angelegt wird, THEN ist der Toast nach mindestens 8 s noch sichtbar.
- **AC-2:** GIVEN derselbe Test vor der Umsetzung (Stand `main`), WHEN er läuft, THEN schlägt er fehl,
  weil der Toast nach 6 s verschwunden ist (RED belegt, Schalter Fehler da → Fix → Fehler weg).
- **AC-3:** GIVEN der Start ohne Argument, WHEN `testToastStaysVisibleLongerThanTwoSeconds` läuft, THEN
  ist er unverändert grün; er startet über `launchedApp()` ohne `toastDuration`.
- **AC-4:** GIVEN gesetztes Argument mit Wert > 0, WHEN `showQuickAddToast` aus einer der drei
  Aufrufstellen läuft (nach Hinzufügen 6 s, Neustart nach Laden-Dialog 3 s, „verschoben nach“ 3 s), THEN
  ersetzt der Argumentwert die jeweilige `duration`; die Aufrufstellen selbst sind unverändert.
- **AC-5:** GIVEN kein Argument oder ein Wert ≤ 0 bzw. nicht numerisch, WHEN `showQuickAddToast` läuft,
  THEN gelten unverändert 6 s bzw. 3 s.
- **AC-6:** GIVEN der Release-Build, WHEN er kompiliert, THEN ist der Zweig `#if DEBUG` nicht enthalten, der
  Build läuft ohne Fehler, und die Fristen sind unverändert 6 s bzw. 3 s.
- **AC-7:** GIVEN die Tests `testToastNamesStoreAndOffersChangeAndUndo`, `testUndoRemovesToastAndItem` und
  `testChangeStoreMovesItemAndRemembersCorrection`, WHEN der Durchgang umgesetzt ist, THEN starten sie mit
  `toastDuration: 60` und prüfen inhaltlich dasselbe wie vorher (Toast nennt Laden, bietet „Laden ändern“
  und „Rückgängig“, Undo entfernt Toast und Artikel, Laden-Wechsel verschiebt den Artikel und merkt die
  Korrektur); geändert ist nur der Start.
- **AC-8:** GIVEN die gesamte UI- und Unit-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf
  läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- **AC-9:** GIVEN der Wegwerf-Zweig mit auf `QuickAddAssignmentUITests` eingeschränkter `ci.yml` und
  `-test-iterations 30` ohne Retry, WHEN der Vorher-Lauf (Stand `main`) läuft, THEN ist die Fehlerquote
  der drei Toast-Tests dokumentiert; ist sie 0, wird das offen benannt und der Nachweis entsprechend
  eingeschränkt.
- **AC-10:** GIVEN derselbe Wegwerf-Zweig mit dem Fix, WHEN der Nachher-Lauf läuft, THEN sind es 0 Fehler
  bei den drei Toast-Tests, das xcresult belegt weiterhin Einzelabfragen > 4 s (gleiche Runner-Lage), und
  `ci.yml` auf `main` ist unverändert.
- **AC-11:** GIVEN die App im Simulator ohne Argument, WHEN sie als Nutzer durchgespielt wird
  (Schnell-Hinzufügen, Toast, „Laden ändern“, Dialog schließen), THEN verschwindet der Toast nach etwa 6 s
  bzw. nach dem Dialog nach etwa 3 s von selbst; der Durchlauf ist als Artefakt registriert (echter Lauf,
  Commit-Kennung und Zeitstempel passend).
- **AC-12:** GIVEN der Abschluss des Durchgangs, WHEN Ticket und Berichte formuliert werden, THEN sind
  ausdrücklich als offen genannt: XCTests eigene Abfrage-Zeitgrenze („Timed out while evaluating UI
  query“, 31 s), der Wettlauf `frame` → `isHittable` → `tap()` und Durchgang 3; es gibt keine Aussage „alle
  Flakes behoben“, und #111 bleibt offen.
- **AC-13:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `SmartCart/Views/Home/HomeView.swift` und `RestockUITests/QuickAddAssignmentUITests.swift` (ca. +25/−5
  LoC), ohne neue Produkt-Strings, Dependencies, `Info.plist`- oder `@AppStorage`-Änderung;
  `UITestWait.swift` ist unberührt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testbarkeit über ein DEBUG-only Launch-Argument nach bestehendem Muster
  (`SmartCartApp.swift`). Kein Eingriff in App-Architektur oder bestehende ADRs; kein früherer Beschluss
  wird gekippt.

## Folge-Durchgänge im selben Ticket

- **Durchgang 3 (nur bei gemessenem Bedarf):** die übrigen UI-Testdateien mit kurzen Fristen (restliche
  `timeout: 5` auf die Standardfrist). Erst nach Messung, wenn dort Fehlschläge auftreten; Umfang offen.
  Nicht Teil dieser Spec.
- Überschneidung, gleiches Ziel, eigene Belege, nicht hier gezogen: #32 (Fokus-Warten), #82 Teil 2
  (Tipp aufs Häkchen), #105 (zentraler Start mit Gegenprobe).
- #111 bleibt nach diesem Durchgang offen (AC-12).

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | DEBUG-only Launch-Argument setzt die Anzeigedauer (60 s) in drei Tests, gilt für alle drei Fristen in `showQuickAddToast` | trifft die belegte Ursache (Anzeigedauer kürzer als die Summe der Abfragen); Release unverändert; Dauertest schützt die echte Frist; eine Stelle für alle drei Fristen |
| B | Launch-Argument schaltet das Ausblenden in Tests ganz ab | robuster gegen Timing, aber ein Fehler im Ausblenden fiele nur im Dauertest auf, und die Frist-Logik wäre in den drei Tests nicht mehr beteiligt; verworfen |
| C | Alle Prüfungen in einem Zug vor Ablauf lesen (Test umbauen) | kein App-Eingriff, aber die Einzelabfrage bis 31 s (XCTest-Grenze) bleibt unlösbar, die Frist bleibt Glückssache; verworfen |

Kein Modell beteiligt: deterministische Testlogik. Gekippte frühere Entscheidung: keine ADR. Ausdrücklich
nicht gekippt: die Annahme „Toast steht 6 s“ gilt im Produkt weiter; nur der Test darf sie im DEBUG-Build
verlängern.

**Entscheidung:** Weg A.

## Risiken

- **Argument wirkt im Release:** Ausgeschlossen durch `#if DEBUG`; Absicherung durch Release-Build
  (AC-6) und Durchlauf ohne Argument (AC-11).
- **Dauertest verliert Aussagekraft:** Er prüft nur „länger als 2 s“, nicht exakt 6 s; deshalb der
  Durchlauf (AC-11). Ändert sich die echte Frist unbemerkt, fängt der Dauertest nur eine Verkürzung unter 2 s.
- **Zeilennummern verschieben sich:** Die genannten Zeilen (229, 1479–1483, 1495, 1561) stammen vom
  2026-10-07; maßgeblich sind die Funktionen, nicht die Zeilen.
- **Vorher-Lauf zeigt 0 Fehler:** Flake ist sporadisch; dann wird offen benannt, ein zweiter Vorher-Lauf
  versucht, und der Nachweis gilt eingeschränkt (Nachher 0 Fehler plus > 4-s-Abfragen im xcresult).
- **Teilerfolg:** Die XCTest-Abfragegrenze (31 s) und der Wettlauf `frame` → `isHittable` → `tap()` bleiben;
  wer „grün beim ersten Versuch“ erwartet, irrt (AC-12).
- **LoC-Gate zählt Testcode als Produktivcode:** ca. +25/−5 weit unter dem Limit; trotzdem vor dem Abschluss
  prüfen.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); „Executed 0 tests“ ist kein Grün.

## Changelog

- 2026-10-07: Initial spec created (Durchgang 2 von #111; Toast-Dauer per DEBUG-only Launch-Argument für
  alle drei Fristen, Nachweis auf dem Runner und Durchlauf im Simulator)
