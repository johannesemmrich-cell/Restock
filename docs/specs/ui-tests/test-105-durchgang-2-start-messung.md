---
entity_id: test-105-durchgang-2-start-messung
type: bugfix
created: 2026-10-10
updated: 2026-10-10
status: draft
workflow: fix-105-leerer-start-ursache
tags: [test, ui-test, flake, launch-helper, measurement, issue-105, issue-128, issue-133]
---

# Dauerhafte Messung im Start-Helfer (Issue #105, Durchgang 2)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Durchgang 1 (PR #134) hat für gesäte UI-Tests einen Start-Helfer `UITestLaunch` eingeführt: starten,
Gegenprobe auf die Seed-Kachel, bei Fehlen genau einmal neu starten. Das ist belegt wirksame **Abhilfe**.
Warum der erste App-Start gelegentlich ohne Launch-Argumente erfolgt, ist weiter **unbekannt**.

Dieser Durchgang sollte die Ursache suchen. Der Stand der Suche (Belege in
`docs/context/fix-105-leerer-start-ursache.md` und `docs/artifacts/fix-105-leerer-start-ursache/`):

- Recherche (Internet, 2026-10-10): kein dokumentierter Fall, dass der erste `launch()` ohne die
  gesetzten `launchArguments` startet; die Ursache muss aus eigener Messung kommen.
- Messung auf `Restock-Validate` (iOS 26.5): sechs Versuche, davon **fünf gültige** (ohne Last, unter
  voller CPU-Last, mit vorher laufender Alt-App, nach Deinstallation von App und Testläufer). In allen
  fünf trug der erste App-Prozess die Seed-Argumente; „zweiter Start nötig“ trat **nie** auf.
  Der sechste Versuch war ungültig (Testläufer ließ sich unter Last nicht starten, RequestDenied).
- Hypothese 1 (erster Start trifft eine noch laufende App des vorigen Laufs): **widerlegt** (Versuch 2).
  Hypothese 2 (Sitzungsaufbau des Testläufers zu spät) und Hypothese 3 (Installation läuft parallel zum
  ersten Start): weder bestätigt noch widerlegt, der Auslöser fehlte.

Nach der Regel „Reproduktion zuerst“ wird deshalb **keine Ursache benannt und kein Fix eingereicht**.
PO-Entscheidung 2026-10-10 („Weg 1“): Der Helfer misst dauerhaft, damit der **nächste echte Fall**
(CI-Lauf oder Hennings Mac) mit Zahlen statt Vermutung auswertbar ist. Wird beim Fall „zweiter Start
nötig“ gemeldet:

- Sekunden seit Beginn des Testlaufs (Prozessstart des Testläufers) und seit dem Helferaufruf,
- Rechnerlast (`getloadavg`, 1/5/15 Minuten),
- Prozesskennung der App vor dem Neustart und nach dem Neustart (`app.processIdentifier`),
- laufende Nummer der Starts im Lauf (statischer Zähler über alle Aufrufe des Helfers).

Kein Produktcode ändert sich. Das Verhalten des Helfers (genau ein Neustart, Reihenfolge, Schweigen bei
Erfolg) bleibt unverändert.

**Offene Grenze (gilt für jede Zusage dieses Durchgangs):**

- Die **Ursache des leeren ersten Starts bleibt unbekannt**; diese Spec liefert weder Ursache noch Fix.
  Der Fehler war heute nicht reproduzierbar, die Messung belegt also nichts über ihn, solange kein
  echter Fall vorliegt.
- Die **Abhilfe aus Durchgang 1** (Neustart mit Gegenprobe) bleibt die einzige Schutzmaßnahme. Sie ist
  Abhilfe, nicht Erklärung.
- Die **übrigen sechs gesäten Klassen** (`QuickAddAssignmentUITests`, `ShoppingRouteUITests`,
  `LegacyLearnedPriceResetUITests`, `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, plus die
  Klassen mit eigener Wiederholung `ReplenishmentUITests`/`DataResetUITests`) bleiben **ungeschützt bzw.
  uneinheitlich**; ihre Umstellung ist vorerst **nicht** Teil des Vorhabens (PO). Es gibt keine Zusage
  „alle gesäten Tests starten zuverlässig“.
- Die Messung greift nur im Fall „zweiter Start nötig“ **in Klassen, die den Helfer benutzen**
  (`AddItemQuantitySuggestionUITests`, `ShoppingRouteLearningUITests`). Fehlstarts in Aufräumstarts
  (`cleaner.launch()`) und in den ungeschützten Klassen werden weder abgefangen noch gemessen.
- Folge-Issue **#133** (drei sporadische Fehler in Klassen ohne Helfer) bleibt offen.
- **#105 und #128 bleiben offen.** Geschlossen wird erst, wenn ein echter Fall mit Zahlen vorliegt und
  ausgewertet ist, oder der PO anders entscheidet.

**Ticket-Rahmen:** Durchgang 2 von #105/#128. Die in Durchgang 1 geplante Umstellung weiterer Klassen
(„Durchgang 2/3“ der Vorgänger-Spec) ist durch die PO-Entscheidung vom 2026-10-10 zurückgestellt; diese
Spec ersetzt sie für den Moment.

## Source

- **Geändert:** `RestockUITests/UITestWait.swift` — `UITestLaunch` (Meldungsformatierung als reine
  Funktion, Messwerte per Closure in `run`, Messwerte-Beschaffung in `start`) und Hilfstests in der
  vorhandenen Klasse `UITestLaunchTests` derselben Datei. **Keine neue Datei, kein Eintrag in
  `project.pbxproj`, kein Diff unter `SmartCart/`.**
- **Nicht geändert (Begründung):**
  - `AddItemQuantitySuggestionUITests`, `ShoppingRouteLearningUITests`: rufen `UITestLaunch.start`
    unverändert auf; die Signatur von `start` bleibt kompatibel.
  - Übrige gesäte Klassen: bewusst nicht umgestellt (siehe Offene Grenze).
  - `CLAUDE.md`: unverändert.
  - `SmartCart/SmartCartApp.swift`: keine DEBUG-Messzeile (Alternative C bleibt verworfen).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RestockUITests/UITestWait.swift` (#111, #105/#128 D1) | test | Ort der Änderung; `UITestLaunch.run/start/failureMessage` |
| `docs/specs/ui-tests/test-105-128-durchgang-1-start-helfer.md` | spec | Vorgänger; Verhalten von `run` und Tests T1–T4 dort bleiben gültig |
| `docs/context/fix-105-leerer-start-ursache.md`, `docs/artifacts/fix-105-leerer-start-ursache/messung-zusammenfassung.md` | doc | Recherche, Messung, Hypothesen, PO-Entscheidung |
| Simulator `Restock-Validate` | tool | Nachweisläufe; nie parallel; keine Geräte |
| Memory „UI-Test: App startet ohne Launch-Argumente“, „Leerer UI-Test-Start nur unter Last“, „Null-Test-Lauf ist kein Grün“, „LoC-Gate zählt Testcode als Produktivcode“, „Eigenes Testgerät je Projekt“ | memory | Messverfahren und Nachweisregeln |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `RestockUITests/UITestWait.swift` | MODIFY | Messzeile (`measurementLine`), Messwerte-Closures in `run`, Beschaffung in `start`, Hilfstests |

### Estimated Changes

- Files: 1 produktiv (Testcode), keine neue Datei, kein `project.pbxproj`
- LoC: ca. +40 / −5 in `RestockUITests/UITestWait.swift` (Limit ±250). Das LoC-Gate zählt Testcode
  **und** `docs/` mit (Memory „LoC-Gate zählt Testcode als Produktivcode“): diese Spec und die
  Belege unter `docs/artifacts/` zählen mit. Vor dem Abschluss `git diff --numstat` getrennt nach
  `SmartCart/`, `RestockUITests/` und `docs/` prüfen; Überschreitung → Rückmeldung mit Schätzung,
  kein `loc_limit_override`.

## Definition of Done

- [ ] Hilfstests für Messzeile und `run` mit Messwerten grün (AC-1 bis AC-4)
- [ ] Bestehendes Verhalten von `run` unverändert, bestehende Tests aus Durchgang 1 (Reihenfolge,
  Schweigen bei Erfolg, kein dritter Start) grün (AC-5)
- [ ] Gegenprobe der Messung: ein erzwungener Neustart zeigt die Meldung mit allen Feldern (AC-6)
- [ ] Gesamtlauf mindestens 1× grün, Testzahl > 0, kein Abbruch (AC-7)
- [ ] Unit-Suite grün (AC-8)
- [ ] Kein Diff unter `SmartCart/`, Umfang im Limit (AC-9)
- [ ] Offene Grenze in Ticket-Kommentaren und Berichten genannt, #105/#128/#133 bleiben offen (AC-10)

## Implementation Details

Form und Namen legt Phase 4 fest; das Verhalten ist verbindlich.

**Reine Meldungsfunktion.** Beispiel: `UITestLaunch.measurementLine(_ m: Measurement) -> String` mit

```
struct Measurement {
    var secondsSinceRunStart: Double?    // Prozessstart des Testläufers
    var secondsSinceHelperCall: Double?   // Eintritt in UITestLaunch.start
    var load: (Double, Double, Double)?  // getloadavg: 1/5/15 min
    var pidBefore: Int32                 // app.processIdentifier vor terminate()
    var pidAfter: Int32                  // nach dem zweiten launch()
    var launchOrdinal: Int               // laufende Nummer der Starts im Lauf
}
```

Die Funktion liefert einen einzeiligen Text, jedes Feld mit Namen und Einheit (z. B.
`seit Lauf 12.4 s, seit Helferaufruf 11.9 s, Last 3.1/2.4/2.0, pid 4711 → 4802, Start Nr. 1`). Ist ein Wert nicht
ermittelbar, steht an seiner Stelle sichtbar `unbekannt`, nie ein erfundener Wert.

**`run`.** Bekommt zusätzlich Closures für die Messwerte (z. B. `pid: () -> Int32` und
`snapshot: () -> Measurement-Teil`), ruft `pid` nach dem ersten `launch()` (vor `terminate()`) und nach
dem zweiten `launch()` auf und baut die Meldung nur im Fall „zweiter Start gelungen“. Die Meldung
beginnt unverändert mit `UITestLaunch: zweiter Start nötig` (Präfix, Suchbarkeit im Protokoll/xcresult),
danach der bisherige Befund des ersten Versuchs, danach die Messzeile. Reihenfolge der Aufrufe
(`launch, probe, terminate, launch, probe`), Schweigen bei Erfolg im ersten Start, Schweigen bei
Gesamtscheitern und „kein dritter Start“ bleiben unverändert.

**`start`.** Liefert die Messwerte:

- Prozessstart des Testläufers: aus der Prozessinformation des laufenden Prozesses (Beschaffung legt
  Phase 4 fest; Alternative: Zeitstempel beim ersten Zugriff auf den Helfer, dann in der Meldung als
  „seit erstem Helferaufruf“ ausgewiesen).
- Helferaufruf statt Testfallbeginn (festgelegt, keine offene Beschaffung): `start` nimmt beim Eintritt
  einen Zeitstempel (`Date()`); die Messzeile weist „seit Helferaufruf“ aus. Ein echter Testfallbeginn
  (`XCTestObservation`) ist ausdrücklich **nicht** Teil dieses Durchgangs, weil ein spät registrierter
  Beobachter den ersten Testfall verpasst — gerade den, in dem der Fehler auftritt. „Seit Lauf“ und
  „seit Helferaufruf“ zusammen zeigen, ob der Fehlstart früh im Lauf (Sitzungsaufbau) oder später auftritt.
- Last: `getloadavg`; Prozesskennung: `app.processIdentifier`; Zähler: statisch, je Aufruf von `launch`
  im Helfer erhöht.

**Beobachtung statt Eingriff:** Die Messwerte werden nur gelesen. Es gibt keine zusätzlichen Starts,
keine Pausen und keine Änderung der Fristen; grüne Läufe werden nicht langsamer.

Regelweg, kein Modell: reine Mess- und Formatierungslogik.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testinfrastruktur. Gekippte frühere Entscheidung: keine ADR; die
  Durchgang-1-Entscheidung „Helfer je Klasse, übrige Klassen umstellen“ wird **zurückgestellt**
  (nicht widerrufen), die Zusage „keine Produktänderung für Testhilfen“ (#98) bleibt gewahrt.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **1 (gewählt, PO 2026-10-10)** | Dauerhafte Messung im Helfer; Ursache offen lassen | Ehrlich zum Wissensstand (kein reproduzierter Fehler), klein (1 Datei, kein Produktcode), liefert beim nächsten echten Fall Zahlen. Schützt allerdings keine weitere Klasse |
| 2 | Die sechs übrigen gesäten Klassen auf den Helfer umstellen (Durchgang 2/3 der Vorgänger-Spec) | Schützt sicher, ist aber Abhilfe statt Ursache und verbreitert den Diff über mehrere Klassen; nicht gewählt. Würde die Zurückstellung aus dieser Spec wieder kippen; kann später ohne Rückbau folgen |
| 3 | Aufwärmstart (wegwerfbarer erster Start vor allen Klassen) | Ohne belegte Ursache nicht begründbar (Hypothese 2 und 3 offen); könnte den Fehler verdecken, statt ihn zu erklären. Kippt die Entscheidung „Gegenprobe statt Vorlauf“ aus Durchgang 1 (dort Weg B als reiner Messversuch) |
| C (aus dem Kontext) | Argumente nicht über `launchArguments`, sondern über Datei im App-Group-Container oder `launchEnvironment` übergeben | Sinnvoll nur, wenn die Ursache am Argumentweg liegt; das ist nicht belegt. Würde Produktcode ändern (DEBUG-Lesepfad in `SmartCartApp.init`) und damit die Zusage „keine Produktänderung für Testhilfen“ (#98) und die Durchgang-1-Entscheidung gegen Alternative C kippen. Wird neu bewertet, sobald die Messung einen Fall zeigt |
| Weg B (aus dem Kontext) | Simulator vor jedem Lauf neu starten/App deinstallieren (Skript) | Hennings Läufe starten aus Xcode, ein Skript greift dort nicht; Messung zeigte zudem keinen Unterschied nach Deinstallation |

## Test Plan

### Automated Tests (TDD RED)

Alle neuen Tests sind Hilfstests ohne App-Start (Closures/Fakes). RED: Vor der Umsetzung existieren
`measurementLine` und die erweiterte `run`-Signatur nicht, die Hilfstests kompilieren nicht. Die
Durchgang-1-Tests (Reihenfolge, Schweigen, kein dritter Start) werden an die neue Signatur angepasst
und laufen mit unveränderter Aussage weiter.

- [ ] T1: GIVEN eine Messung mit allen Feldern, WHEN `measurementLine` sie formatiert, THEN enthält die
  Zeile Sekunden seit Lauf und seit Helferaufruf, alle drei Lastwerte, beide Prozesskennungen und die laufende
  Nummer.
- [ ] T2: GIVEN eine Messung mit fehlenden Werten (`nil`), WHEN formatiert wird, THEN steht an jeder
  Stelle `unbekannt`, es erscheint kein erfundener Zahlenwert und es gibt keinen Absturz.
- [ ] T3: GIVEN `probe` liefert zuerst `false`, dann `true`, und `pid` liefert 100 dann 200, WHEN `run`
  läuft, THEN beginnt die Meldung mit `UITestLaunch: zweiter Start nötig`, enthält den Befund des
  ersten Versuchs, `100` und `200`; Reihenfolge `launch, probe, terminate, launch, probe`; `report`
  genau 1×.
- [ ] T4: GIVEN `probe` liefert beim ersten Mal `true`, WHEN `run` läuft, THEN keine Meldung, 1 Start,
  0× `terminate`, und die Messwerte-Closures werden nicht für eine Meldung ausgewertet.
- [ ] T5: GIVEN `probe` liefert immer `false`, WHEN `run` läuft, THEN 2 Starts, 1× `terminate`, kein
  dritter Start, Outcome „gescheitert“, `report` 0× (wie Durchgang 1).
- [ ] T6: GIVEN `failureMessage`, WHEN sie gebaut wird, THEN unverändert gegenüber Durchgang 1 (kein
  Präfix des Messdatums).
- [ ] T7 (Gegenprobe der Messung): GIVEN ein erzwungener Neustart (Hilfstest mit Fake-Closures; zusätzlich
  einmalig ein Wegwerf-Lauf mit absichtlich falscher Erwartung in einem echten Helferaufruf, nicht
  eingecheckt), WHEN die Meldung entsteht, THEN stehen im Testprotokoll alle Felder der Messzeile mit
  plausiblen Werten (pid vor ≠ pid nach).
- [ ] T8: GIVEN die Unit-Suite (`RestockTests`), WHEN sie auf `Restock-Validate` läuft, THEN grün,
  Testzahl > 0.
- [ ] T9: GIVEN der Diff gegen den Tip-Commit, WHEN `git diff --stat -- SmartCart/ Restock.xcodeproj`
  läuft, THEN leer.

## Acceptance Criteria

- **AC-1:** GIVEN eine vollständige Messung, WHEN die Messzeile gebaut wird, THEN nennt sie Sekunden seit
  Testlaufbeginn, Sekunden seit Helferaufruf, die Rechnerlast (1/5/15 min), die Prozesskennung der App
  vor und nach dem Neustart und die laufende Nummer der Starts im Lauf (Beweis: Hilfstest T1).
- **AC-2:** GIVEN nicht ermittelbare Messwerte, WHEN die Messzeile gebaut wird, THEN steht an der Stelle
  des Werts `unbekannt` und keine erfundene Zahl (Beweis: Hilfstest T2).
- **AC-3:** GIVEN der erste Start scheitert und der zweite gelingt, WHEN `run` läuft, THEN gibt es genau
  eine Meldung, die mit `UITestLaunch: zweiter Start nötig` beginnt, den Befund des ersten Versuchs und
  die Messzeile enthält, mit den Prozesskennungen vor und nach dem Neustart (Beweis: Hilfstest T3).
- **AC-4:** GIVEN die Messung, WHEN der Helfer läuft, THEN erzeugt sie keine zusätzlichen Starts, Pausen
  oder Fristen und liest nur Werte (Beweis: Hilfstests T3 und T4 prüfen die exakte Aufrufreihenfolge der
  Closures; Diff zeigt keine Änderung von `UITestWait.defaultTimeout`/`pollInterval`).
- **AC-5:** GIVEN das Verhalten aus Durchgang 1, WHEN der Durchgang umgesetzt ist, THEN gilt weiter:
  Erfolg im ersten Start → 1 Start, keine Meldung; Erfolg im zweiten → genau 1 `terminate` und eine
  Meldung; Scheitern beider → kein dritter Start, `XCTFail` mit `failureMessage` ohne Messdaten-Präfix,
  keine Meldung (Beweis: Hilfstests T4, T5, T6 grün; die Aussagen der Durchgang-1-Tests T1–T4 bleiben
  inhaltlich unverändert).
- **AC-6:** GIVEN ein erzwungener Neustart (Fake-Closures im Hilfstest; zusätzlich ein einmaliger,
  nicht eingecheckter Wegwerf-Lauf mit absichtlich falscher Erwartung auf `Restock-Validate`), WHEN die
  Meldung entsteht, THEN zeigt das Testprotokoll die Meldung mit allen Feldern der Messzeile und
  plausiblen Werten; der Wegwerf-Lauf ist als Auszug unter `docs/artifacts/fix-105-leerer-start-ursache/`
  abgelegt. **Nicht Teil dieses Nachweises:** dass die Ursache gefunden wäre; er belegt nur, dass die
  Messung im Ernstfall Zahlen liefert (Beweis: Protokollauszug mit Marker und Feldern).
- **AC-7:** GIVEN der Stand mit Änderung, WHEN der volle UI-Lauf auf `Restock-Validate` mindestens
  einmal läuft (nie parallel, ohne `-retry-tests-on-failure`/`-test-iterations`), THEN ist er grün mit
  `Executed N tests`, N > 0 und gleich der Sollzahl der Suite, ohne „Restarting after unexpected exit“;
  die Zahl der Meldungen `UITestLaunch: zweiter Start nötig` ist ausgewiesen (auch 0 ist ein Messwert;
  bei ≥ 1 Meldung wird die Messzeile als echter Fall mit Zahlen im Beleg festgehalten). Der Lauf ist
  zugleich der Durchlauf der App im Simulator mit dem Stand, den Henning bekommt. Kein Gerätetest
  (Henning-Regel: Geräte nur nach „jetzt ist ein Test möglich“).
- **AC-8:** GIVEN die Unit-Suite (`RestockTests`), WHEN sie auf `Restock-Validate` läuft, THEN grün,
  Testzahl > 0, ohne Abbruch.
- **AC-9:** GIVEN der Diff dieses Durchgangs, WHEN er gegen den Tip-Commit geprüft wird, THEN gibt es
  keine Änderung unter `SmartCart/` und keine unter `Restock.xcodeproj`, genau eine Testdatei
  (`RestockUITests/UITestWait.swift`) ist geändert (plus Spec/Belege unter `docs/`), der Umfang liegt bei
  ca. +40/−5 LoC im Testcode und innerhalb des Limits einschließlich `docs/` (Beweis: `git diff --stat`,
  `git diff --numstat` getrennt nach Verzeichnis).
- **AC-10:** GIVEN der Abschluss des Durchgangs, WHEN Ticket-Kommentare und Berichte formuliert werden,
  THEN nennen sie ausdrücklich: Die Ursache des leeren ersten Starts ist unbekannt und heute nicht
  reproduzierbar (5 gültige Versuche, nie leer; Hypothese 1 widerlegt, 2 und 3 offen); es wurde nur
  eine dauerhafte Messung ergänzt; die Abhilfe aus Durchgang 1 bleibt; sechs gesäte Klassen bleiben
  ungeschützt bzw. uneinheitlich, ihre Umstellung ist vorerst nicht geplant; Fehlstarts in Aufräumstarts
  werden nicht gemessen; es gibt keine Aussage „alle gesäten Tests starten zuverlässig“. #105, #128 und
  #133 bleiben offen. Geschlossen wird erst, wenn ein echter Fall mit Zahlen vorliegt oder der PO anders
  entscheidet.

## Risiken

- **Messung wird nie ausgelöst:** Tritt der Fehler nicht auf (heute: nie), liefert die Messung nichts.
  Das ist ein ehrliches Ergebnis; der Nutzen zeigt sich erst im nächsten echten Fall. Der Fehler kann
  außerdem in Klassen auftreten, die den Helfer nicht benutzen (bleibt unsichtbar).
- **Messwerte falsch gedeutet:** Last und Zeitabstand sind Indizien, kein Beweis. Auswertung erst bei
  mehreren Fällen; kein Schluss aus einem Einzelwert.
- **Prozessstart des Testläufers nicht ermittelbar:** Dann `unbekannt` statt
  stillschweigender Spec-Abweichung.
- **Prozesskennung vor dem Neustart:** Liest `processIdentifier` einer nicht mehr laufenden App ein
  ungültiges Ergebnis, steht `unbekannt` (Hilfstest T2 deckt das Format).
- **LoC-Gate zählt Testcode und `docs/`:** Umfang vor Abschluss prüfen; bei Blockade grünen Zwischenstand
  sichern (durch den Orchestrator), kein `loc_limit_override`.
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate`); keine zusätzlichen Build-Settings
  wie `CODE_SIGNING_ALLOWED=NO`; bei Start-Hänger der Unit-Suite Aufräum-Rezept aus #63.
- **Wegwerf-Lauf (AC-6) nicht einchecken:** Die absichtlich falsche Erwartung darf nie im Stand landen
  (Beweis: Diff vor dem Commit prüfen).

## Changelog

- 2026-10-10: Initial spec created (Durchgang 2 von #105/#128; PO-Entscheidung „Weg 1“: Messung statt
  Ursache/Fix).
