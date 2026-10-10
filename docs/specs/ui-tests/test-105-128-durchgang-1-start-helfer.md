---
entity_id: test-105-128-durchgang-1-start-helfer
type: bugfix
created: 2026-10-10
updated: 2026-10-10
status: draft
workflow: fix-105-128-start-helper
tags: [test, ui-test, flake, launch-helper, seed, issue-105, issue-128]
---

# Start-Helfer für gesäte UI-Tests (Issue #105 + #128, Durchgang 1)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Gesäte UI-Tests sollen beim ersten Versuch grün starten. Heute startet der Testläufer die App
gelegentlich (#105: ca. jeder 5. erste Start) oder im vollen Lauf auf `Restock-Validate` fast immer
(#128: 4 von 4) **ohne** die Launch-Argumente des Tests. Der Seed greift dann nicht, die Startseite
zeigt den Rest des vorigen Laufs, und der erste Test des Gesamtlaufs
(`AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList`) scheitert an der
fehlenden Kachel „Quittenhof“.

Belegt (Analyse und Messung in `docs/context/fix-105-128-start-helper.md`):

- Reproduktion: voller UI-Lauf auf `Restock-Validate` (`-only-testing:RestockUITests`), 4 von 4 rot
  am ersten Test; Einzeltest und Einzelklasse grün, auch nach Deinstallation der App.
- Messung (temporäres `NSLog` der Startargumente in `SmartCartApp.init`, danach entfernt): Der erste
  App-Prozess des Laufs trug **leere** Argumente, alle späteren trugen sie. Ein zweiter Prozess
  zwischen diesem und dem Aufräumstart nach dem Test existierte nicht.
- Protokollunterschied: Im ersten Test steht „Setting up automation session“ erst nach 1,05 s (zweiter
  Test: 0,22 s) und „Wait for … to idle“ nach 2,52 s (zweiter Test: 0,85 s). Die Sitzung des
  Testläufers ist beim ersten Start noch nicht aufgebaut, während `launch()` bereits läuft.
- Websuche (Apple-Foren, Swift by Sundell u. a.): kein dokumentierter Fall; bestätigt nur, dass die
  Argumente aus `launchArguments` des Testläufers kommen.

Dieser Durchgang führt einen **zentralen Start-Helfer mit Gegenprobe** ein: starten, prüfen, ob das
vom Seed erzeugte Element da ist, wenn nicht genau einmal neu starten, danach mit klarer Meldung
scheitern. Er wird auf den belegten Fall (#128) und auf die Klasse angewendet, die eine eigene
Wiederholung hat. Kein Produktcode ändert sich.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):** Die **Ursache** des leeren ersten Starts
bleibt unbekannt. Gesichert ist nur der späte Sitzungsaufbau des Testläufers (1,05 s statt 0,22 s);
dass er den leeren Start verursacht, ist nicht bewiesen. Die Wiederholung ist **Abhilfe, nicht
Erklärung**. Offen bleibt ebenso, warum der erste Start im Gesamtlauf auf `Restock-Validate` fast
immer, auf dem CI-Simulator selten ohne Argumente erfolgt. Der Helfer meldet jeden Fall, in dem der
zweite Start nötig war, damit die Ursache später mit Zahlen statt Vermutung eingegrenzt werden kann.
Nach Durchgang 1 sind die übrigen gesäten Klassen (Ausblick unten) weiter ungeschützt; es gibt keine
Zusage „alle gesäten Tests starten zuverlässig“. Ein Fehlstart **in einem Aufräumstart**
(`cleaner.launch()`) wird nicht abgefangen (siehe Source), ebenso kein leerer Start, dessen Seed-Element
zufällig trotzdem sichtbar ist (Rest eines früheren Laufs mit gleicher Kachel).

**Ticket-Rahmen:** #105 und #128 sind gebündelt (PO-Entscheidung 2026-10-10) und laufen in **drei
Durchgängen** (PO-Entscheidung 2026-10-10, wie bei #98; Limits gelten je Durchgang). Diese Spec ist
Durchgang 1. Beide Tickets bleiben bis Durchgang 3 offen.

## Source

- **Geändert:** `RestockUITests/UITestWait.swift` — neuer Helfer `UITestLaunch` samt Entscheidungslogik
  als reine, injizierbare Funktion und Hilfstests dafür. Die Datei enthält bereits die Hilfstests
  `UITestWaitTests` zu den Warte-Hilfen aus #111 (Prüfung ohne App, ohne App-Start); die neuen
  Hilfstests kommen dort hinein oder in eine zweite Testklasse **derselben Datei**. Damit entsteht
  **keine neue Datei und kein Eintrag in `project.pbxproj`**.
- **Geändert:** `RestockUITests/AddItemQuantitySuggestionUITests.swift` — `launchedApp()` (heute
  `launch()` ohne Gegenprobe) startet über den Helfer; erwartetes Element ist die Kachel „Quittenhof“
  (`label BEGINSWITH "Quittenhof,"`). Die Kachelsuche aus `openQuittenhofStoreDetail` wird in eine
  kleine private Funktion gezogen, die beide benutzen. Gilt für alle 7 Aufrufer von `launchedApp()`;
  der belegte Fehlfall ist `testAssumedQuantityIsMarkedAsAssumptionInList`.
- **Geändert:** `RestockUITests/ShoppingRouteLearningUITests.swift` — `openStore` ersetzt seine eigene
  Wiederholung (`if !tile.waitForExistence … terminate … launch`, Verweis #98) durch den Helfer;
  erwartetes Element bleibt die Kachel „Wegeladen“. Danach laufen `expectation(for: isHittable…)` mit
  5 s und `tile.tap()` unverändert weiter, soweit der Helfer sie nicht schon abdeckt.
- **Nicht geändert (Begründung):**
  - Alles unter `SmartCart/` — kein DEBUG-Marker (Alternative C).
  - Aufräumstarts `cleaner.launch()` in `tearDown()`: Sie bleiben unverändert, weil jeder Seed zuerst
    alle Läden löscht (`SmartCartApp.seed…`); ein leerer Aufräumstart hinterlässt den Rest des Seeds
    stehen, der nächste Seed räumt ihn ohnehin weg. Folge: Gegenprobe dort wäre Aufwand ohne Nutzen für
    die Testergebnisse. Grenze: Ein Test, der ohne eigenen Seed auf leerem Zustand aufbaut
    (`RestockUITests.testAppLaunchesToHomeScreen`), bleibt auf einen sauberen Aufräumstart angewiesen
    (gleiche Annahme wie heute, CLAUDE.md-Regel zu Seeds).
  - `CLAUDE.md` bleibt in Durchgang 1 unverändert; der Absatz zum Start-Helfer kommt mit Durchgang 3,
    wenn feststeht, welche Klassen ihn benutzen.
  - Die übrigen gesäten Klassen (siehe Ausblick) und `RestockUITests.swift` (Start ohne Seed).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RestockUITests/UITestWait.swift` (#111) | test | Ort des Helfers; `defaultTimeout` (20 s), `waitUntilHittable()` für die Gegenprobe |
| `RestockUITests/ShoppingRouteLearningUITests.swift` | test | Vorbild und Vorgänger der Wiederholung (Verweis #98) |
| `SmartCart/SmartCartApp.swift` (`init()`, DEBUG-Seeds) | app | liefert die Seed-Argumente; bleibt unverändert |
| `docs/context/fix-105-128-start-helper.md` | doc | Befund, Messung, Alternativen, Umfang |
| Simulator `Restock-Validate` | tool | Gesamtlauf vorher/nachher; nie parallel (Memory „Eigenes Testgerät je Projekt“) |
| Memory „UI-Test: App startet ohne Launch-Argumente“, „Null-Test-Lauf ist kein Grün“, „UI-Test-Seeds müssen aufräumen“, „LoC-Gate zählt Testcode als Produktivcode“ | memory | Messverfahren, Nachweisregeln |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/UITestWait.swift` | MODIFY | `UITestLaunch.start(_:expecting:)` + reine Entscheidungsfunktion + Hilfstests (keine neue Datei) |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift` | MODIFY | `launchedApp()` über den Helfer (Kachel „Quittenhof“) |
| `RestockUITests/ShoppingRouteLearningUITests.swift` | MODIFY | eigene Wiederholung in `openStore` durch den Helfer ersetzt |

### Estimated Changes

- Files: 3 (Limit 4–5); kein `project.pbxproj`, keine neue Datei
- LoC: ca. +90 / −20 (Limit ±250). Das LoC-Gate zählt Testcode **und** `docs/` als Produktivcode
  (Memory „LoC-Gate zählt Testcode als Produktivcode“): diese Spec zählt mit. Vor dem Abschluss
  `git diff --numstat` getrennt nach `SmartCart/`, `RestockUITests/` und `docs/` prüfen; Überschreitung
  → Rückmeldung mit Schätzung, Limit nicht anheben, kein `loc_limit_override`.

## Definition of Done

- [ ] Reproduktion zuerst: voller UI-Lauf auf `Restock-Validate` **vor** der Änderung rot am ersten Test,
  Beleg abgelegt (AC-7)
- [ ] Hilfstests für die Entscheidungslogik grün (AC-1 bis AC-4)
- [ ] `AddItemQuantitySuggestionUITests` und `ShoppingRouteLearningUITests` nutzen den Helfer (AC-5, AC-6)
- [ ] Mindestens 3 grüne Gesamtläufe hintereinander, Testzahl > 0, kein Abbruch, kein Retry-Flag (AC-8)
- [ ] Unit-Suite grün (AC-9)
- [ ] Kein Diff unter `SmartCart/`, Umfang im Limit (AC-10)
- [ ] Offene Grenze in Ticket-Kommentaren und Berichten genannt, #105/#128 bleiben offen (AC-11)

## Implementation Details

**Helfer.** Form (Name, Rückgabetyp, ob freie Funktion oder `enum`-Namensraum) legt Phase 4 fest; das
Verhalten ist verbindlich. Vorschlag: `UITestLaunch.start(_ app: XCUIApplication, expecting element:
XCUIElement)`, daneben eine **reine** Funktion, die Start, Neustart, Gegenprobe und Meldung als
Closures bekommt:

```
UITestLaunch.run(launch: () -> Void, terminate: () -> Void,
                 probe: () -> (matched: Bool, detail: String),
                 report: (String) -> Void) -> UITestLaunch.Outcome
```

`Outcome` unterscheidet drei Fälle: Gegenprobe beim ersten Start gelungen (`launches == 1`),
Gegenprobe erst nach dem zweiten Start gelungen (`launches == 2`), endgültig gescheitert
(`launches == 2`, `detail` des letzten Versuchs).

Ablauf von `start`:

1. `app.launch()`.
2. Gegenprobe: `element.waitUntilHittable()` (Frist `UITestWait.defaultTimeout`, 20 s). Treffer → fertig,
   keine Meldung.
3. Kein Treffer → genau **einmal** `app.terminate()`, `app.launch()`, Gegenprobe erneut mit derselben
   Frist. Treffer → fertig und **Messdatum ausgeben** mit festem Präfix
   `UITestLaunch: zweiter Start nötig` (per `NSLog`, damit es im Testprotokoll und im xcresult
   auffindbar ist), samt Klassen-/Testname und dem Befund des ersten Versuchs (`detail`:
   `exists`/`frame`/`hittable` aus `waitUntilHittable`).
4. Auch der zweite Versuch ohne Treffer → `XCTFail` mit klarer Meldung: Anzahl Starts (2), Beschreibung
   des erwarteten Elements, zuletzt gesehener Zustand (`exists`/`frame`/`hittable`), Hinweis „Launch-
   Argumente des Tests nicht angekommen oder Seed fehlgeschlagen“. Es gibt **keinen** dritten Start.

Eigenschaften: zustandsbasiert (grüne Läufe sofort fertig, kein zusätzlicher Start, keine feste Pause);
die Gegenprobe ist die Kachel selbst, es wird keine Extra-Abfrage nach Fristablauf gestellt (Zustand
stammt aus der letzten Runde, wie bei `waitUntilHittable`). Kosten des Fehlfalls: bis zu 20 s Wartezeit
vor dem Neustart; bei einem echten Seed-Fehler insgesamt bis zu 40 s bis zum `XCTFail`. Das ist
akzeptiert, weil grüne Läufe nicht langsamer werden und der Fehlstart sonst den ganzen Test kostet.

**Umstellungen.**

1. `AddItemQuantitySuggestionUITests.launchedApp()`: Argumente setzen wie bisher; statt `app.launch()`
   `UITestLaunch.start(app, expecting: quittenhofTile(app))`. `openQuittenhofStoreDetail` benutzt
   dieselbe `quittenhofTile`-Funktion und behält `waitForExistence`/`waitUntilHittable`/`tap()`.
   Prüfungen der Tests bleiben wie sie sind.
2. `ShoppingRouteLearningUITests.openStore`: `app.launch()` und die `if !tile.waitForExistence … {
   terminate; launch }`-Wiederholung entfallen zugunsten von `UITestLaunch.start(app, expecting:
   tile)`; der Kommentar zur Messung (#98) wandert in den Helfer, mit Verweis auf #105/#128. Die
   Zeilen danach (`XCTAssertTrue(tile.waitForExistence…)`, Hittable-Erwartung, `tap()`,
   Prüfung „Gouda“) bleiben, soweit sie nicht doppelt sind.
3. Aufräumstarts, `tearDown()` und alle Seed-Argumente bleiben unverändert.

Regelweg, kein Modell: reine Start-/Wartelogik. Geprüfte Alternativen: siehe Abschnitt „Alternativen“.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testinfrastruktur. Gekippte frühere Entscheidung: keine ADR. Die Alternative C
  (DEBUG-Marker) würde die Zusage „keine Produktänderung für Testhilfen“ aus #98 aufweichen und ist
  deshalb nicht gewählt.

## Folge-Durchgänge im selben Ticket

- **Durchgang 2:** `QuickAddAssignmentUITests` (`launchedApp(storeless:toastDuration:)`),
  `ShoppingRouteUITests`, `LegacyLearnedPriceResetUITests`.
- **Durchgang 3:** `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `ReplenishmentUITests` und
  `DataResetUITests` (beide ersetzen ihre eigenen Wiederholungen), danach der `CLAUDE.md`-Absatz zum
  Start-Helfer. Mit Durchgang 3 werden #128 und #105 geschlossen, jeweils mit Kommentar und den
  Messzahlen zum zweiten Start (Anzahl Meldungen `UITestLaunch: zweiter Start nötig` je Durchgang
  und Gesamtlauf).

## Test Plan

### Automated Tests (TDD RED)

Die Entscheidungslogik hängt nicht an einem echten Simulatorstart und wird deshalb mit Closures geprüft
(Hilfstests ohne App-Start, kosten keine Starts). RED: vor der Umsetzung existiert `UITestLaunch` nicht,
die Hilfstests kompilieren nicht.

- [ ] T1: GIVEN `probe` liefert beim ersten Mal `matched == true`, WHEN `run` läuft, THEN `launch` wurde
  genau 1× aufgerufen, `terminate` 0×, `report` 0×, Outcome „erster Start“.
- [ ] T2: GIVEN `probe` liefert zuerst `false`, dann `true`, WHEN `run` läuft, THEN Reihenfolge
  `launch, probe, terminate, launch, probe`, Outcome „zweiter Start“, `report` genau 1× mit dem Präfix
  `UITestLaunch: zweiter Start nötig` und dem `detail` des ersten Versuchs.
- [ ] T3: GIVEN `probe` liefert immer `false`, WHEN `run` läuft, THEN genau 2 Starts, 1× `terminate`,
  kein dritter Start, Outcome „gescheitert“ mit `detail` des zweiten Versuchs.
- [ ] T4: GIVEN die Meldung für „gescheitert“, WHEN sie gebaut wird, THEN nennt sie Anzahl Starts (2),
  das erwartete Element und den Befund (`exists`/`frame`/`hittable`), enthält aber **nicht** den
  Präfix des Messdatums (der wird nur bei Erfolg im zweiten Start ausgegeben).
- [ ] T5: GIVEN beide umgestellten Klassen, WHEN der Gesamtlauf auf `Restock-Validate` läuft, THEN sind
  `testAssumedQuantityIsMarkedAsAssumptionInList` und alle Tests beider Klassen grün, mit
  unveränderten Prüfungen.
- [ ] T6: GIVEN der Zustand vor der Änderung (Stand `main`), WHEN der Gesamtlauf ohne Einschränkung
  außer `-only-testing:RestockUITests` auf `Restock-Validate` läuft, THEN scheitert der erste Test
  (Reproduktion #128, Beleg erneut).
- [ ] T7: GIVEN der Stand mit Änderung, WHEN derselbe Gesamtlauf dreimal nacheinander läuft, THEN dreimal
  alle Tests grün.
- [ ] T8: GIVEN die Unit-Suite (`RestockTests`), WHEN sie läuft, THEN grün, Testzahl > 0.
- [ ] T9: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat -- SmartCart/` läuft, THEN leer.

## Acceptance Criteria

- **AC-1:** GIVEN die Gegenprobe gelingt beim ersten Start, WHEN der Helfer läuft, THEN startet er die
  App genau einmal, beendet sie nicht, gibt keine Messmeldung aus und kehrt ohne feste Wartezeit zurück
  (Beweis: Hilfstest T1 mit Zählern für `launch`, `terminate`, `report`).
- **AC-2:** GIVEN die Gegenprobe scheitert beim ersten und gelingt beim zweiten Start, WHEN der Helfer
  läuft, THEN erfolgt genau ein `terminate()` und ein zweites `launch()`, der Test läuft weiter, und der
  Helfer gibt genau eine Meldung mit dem festen Präfix `UITestLaunch: zweiter Start nötig` samt Befund
  des ersten Versuchs aus (Beweis: Hilfstest T2 mit Aufrufreihenfolge und Meldungstext).
- **AC-3:** GIVEN die Gegenprobe scheitert auch beim zweiten Start, WHEN der Helfer läuft, THEN gibt es
  keinen dritten Start und der Test schlägt mit klarer Meldung fehl, die Anzahl Starts, erwartetes
  Element und zuletzt gesehenen Zustand nennt (Beweis: Hilfstests T3 und T4).
- **AC-4:** GIVEN die Entscheidungslogik, WHEN sie geprüft wird, THEN liegt sie in einer reinen Funktion
  mit injizierbarem `launch`, `terminate`, `probe` und `report`, sodass T1–T4 ohne echten
  Simulatorstart laufen; die Hilfstests liegen in `RestockUITests/UITestWait.swift`, es gibt **keine
  neue Datei** und **keinen** Eintrag in `project.pbxproj` (Beweis: `git diff --stat` zeigt genau die
  drei Dateien aus Scope; `git diff -- Restock.xcodeproj` leer).
- **AC-5:** GIVEN `AddItemQuantitySuggestionUITests`, WHEN der Durchgang umgesetzt ist, THEN startet
  `launchedApp()` über den Helfer mit der Kachel „Quittenhof“ als erwartetem Element, und alle Tests der
  Klasse prüfen inhaltlich dasselbe wie vorher (Beweis: Diff der Klasse zeigt nur Start/Kachelsuche;
  T5 grün).
- **AC-6:** GIVEN `ShoppingRouteLearningUITests.openStore`, WHEN der Durchgang umgesetzt ist, THEN ersetzt
  der Helfer die eigene Wiederholung (kein `terminate()`/zweites `launch()` mehr im Testcode der Klasse
  außerhalb des Helfers und der unveränderten Aufräum-/Neustart-Stellen
  `tearDown()`/`relaunchAfterQuietPeriod`), Kachel „Wegeladen“ bleibt das erwartete Element, und die
  Tests prüfen inhaltlich dasselbe wie vorher (Beweis: Diff der Klasse; T5 grün).
- **AC-7:** GIVEN der Stand `main` vor der Änderung, WHEN der volle UI-Lauf auf `Restock-Validate`
  (`-only-testing:RestockUITests`, ohne `-retry-tests-on-failure`/`-test-iterations`) läuft, THEN ist der
  erste Test rot (Kachel „Quittenhof“ fehlt), und das Protokoll belegt Testzahl, Fehlerzeile und
  Startargumente bzw. den Zustand der Startseite; Beleg unter
  `docs/artifacts/fix-105-128-start-helper/` (Reproduktion zuerst; die Zusage „4 von 4“ aus #128 wird
  erneut gezeigt, nicht nur zitiert). Zeigt der Lauf wider Erwarten grün, wird das offen benannt, die
  Reproduktion wiederholt und nicht abgeschlossen, bevor der Fehlfall gezeigt ist.
- **AC-8:** GIVEN der Stand mit Änderung, WHEN der volle UI-Lauf auf `Restock-Validate` dreimal
  nacheinander (nie parallel) läuft, THEN sind alle drei Läufe grün; je Lauf belegt: `Executed N tests`
  mit N > 0 und gleich der Sollzahl der Suite, 0× „Restarting after unexpected exit“, kein
  `-retry-tests-on-failure`/`-test-iterations` im Aufruf (Memory „Null-Test-Lauf ist kein Grün“), und
  die Zahl der Meldungen `UITestLaunch: zweiter Start nötig` je Lauf ist ausgewiesen (auch 0 ist ein
  Messwert). Belege unter `docs/artifacts/fix-105-128-start-helper/`. Der Gesamtlauf ist zugleich der
  Durchlauf der App im Simulator mit dem Stand, den Henning bekommt.
- **AC-9:** GIVEN die Unit-Suite (`RestockTests`), WHEN sie auf `Restock-Validate` läuft, THEN ist sie
  grün mit Testzahl > 0 und ohne Abbruch.
- **AC-10:** GIVEN der Diff dieses Durchgangs, WHEN er gegen den Tip-Commit geprüft wird, THEN gibt es
  keine Änderung unter `SmartCart/` (App-Verhalten unverändert), der Umfang liegt bei 3 Testdateien
  (plus Spec und Belege unter `docs/`) und ca. +90/−20 LoC, `CLAUDE.md` ist unverändert, die
  `cleaner.launch()`-Aufräumstarts sind unverändert.
- **AC-11:** GIVEN der Abschluss des Durchgangs, WHEN Ticket-Kommentare und Berichte formuliert werden,
  THEN nennen sie ausdrücklich: Die Ursache des leeren ersten Starts ist unbekannt, die Wiederholung ist
  Abhilfe, nicht Erklärung; sechs weitere gesäte Klassen sind erst in Durchgang 2/3 geschützt; ein
  Fehlstart in Aufräumstarts wird nicht abgefangen; es gibt keine Aussage „alle gesäten Tests starten
  zuverlässig“. #105 und #128 bleiben bis Durchgang 3 offen. Der Kommentar enthält die Messzahlen zum
  zweiten Start aus AC-8.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Zentraler Start-Helfer `UITestLaunch.start(_:expecting:)` mit klassenspezifischer Gegenprobe: launch, „Seed-Kachel antippbar“, bei Fehlen genau einmal terminate + launch | löst das belegte Symptom (#128, 4 von 4) an der Stelle, an der es auftritt; ersetzt die drei uneinheitlichen Wiederholungen; liefert Messzahlen zum zweiten Start; reiner Regelweg ohne Produktcode |
| B | Aufwärm-Start im `setUp` (launch + terminate), damit die Sitzung des Testläufers steht | würde die Gegenprobe überflüssig machen, ist aber unbewiesen (Ursache nicht belegt) und kostet je Klasse einen Start; nur optionaler Messversuch in einem Wegwerf-Lauf, nicht Teil der ACs und nicht des Diffs |
| C | DEBUG-Marker in `SmartCartApp` („Argumente angekommen“) als klassenunabhängiger Beweis | Eingriff in Produktcode und ein weiterer Pfad im langen `init()`; weicht die Zusage „keine Produktänderung für Testhilfen“ (#98) auf; verworfen, Option falls die Gegenprobe bei vielen Klassen unhandlich wird |
| D | CI-Wiederholung (`-retry-tests-on-failure`) | durch #172 bewusst entfernt; keine Option |

Kein Modell beteiligt: reine Start-/Wartelogik.

**Entscheidung:** Weg A in Durchgang 1 (Helfer plus zwei Klassen); Durchgang 2 und 3 stellen die übrigen
Klassen um. Weg B bleibt ein reiner Messversuch.

## Risiken

- **Wiederholung überdeckt die Ursache:** Der zweite Start macht den Lauf grün, erklärt aber nichts. Das
  Messdatum (`UITestLaunch: zweiter Start nötig`) ist der Gegenmaßnahme-Teil: Häufung nach Test,
  Klasse und Lauf zeigt, ob der Fehlstart an der ersten Sitzung hängt oder zufällig ist. Alternative B
  (Aufwärm-Start) kann als Messversuch folgen.
- **Gegenprobe mit falscher Erwartung macht Tests rot:** Die Kachel muss zum Seed passen („Quittenhof,“
  bzw. „Wegeladen,“); die Label-Präfixe werden aus den bestehenden Tests übernommen, nicht neu
  erfunden. Emoji-Text im Label bricht `BEGINSWITH`-Prüfungen (Memory „Emoji-Text bricht
  Accessibility-Label“): unverändertes Muster der heutigen Tests.
- **Falsch-negativ der Gegenprobe:** Ist die Kachel eines früheren Laufs noch da (gleicher Name), besteht
  die Gegenprobe auch ohne angekommene Argumente. Für „Quittenhof“ und „Wegeladen“ löscht jeder Seed
  zuerst alle Läden, und die Aufräumstarts entfernen sie; das Restrisiko ist benannt (offene Grenze).
- **Längerer roter Lauf:** Ein echter Seed-Fehler wartet jetzt bis zu 40 s bis zur Meldung. Akzeptiert.
- **LoC-Gate zählt Testcode und `docs/`:** Umfang vor Abschluss prüfen; bei Blockade grünen Zwischenstand
  sichern (durch den Orchestrator), kein `loc_limit_override`.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); keine zusätzlichen Build-Settings
  wie `CODE_SIGNING_ALLOWED=NO` (bricht die App-Gruppe); bei Start-Hänger der Unit-Suite Aufräum-Rezept
  aus #63, nicht den Test ändern.
- **Gesamtlauf-Dauer:** Ein voller UI-Lauf dauert lokal lang; vier Läufe (vorher + 3 nachher) werden
  nacheinander gefahren, nie überlappend.

## Changelog

- 2026-10-10: Initial spec created (Durchgang 1 von #105 + #128; Durchgang 2 und 3 als Ausblick).
