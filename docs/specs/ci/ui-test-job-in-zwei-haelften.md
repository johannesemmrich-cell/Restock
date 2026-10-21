---
entity_id: ui-test-job-in-zwei-haelften
type: bugfix
created: 2026-10-11
updated: 2026-10-11
status: draft
version: "1.0"
workflow: fix-136-ui-job-teilen
tags: [ci, ui-test, timeout, issue-136]
---

# UI-Test-Job der CI in zwei parallele Hälften teilen (Issue #136)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Der Job `ui-test` in `.github/workflows/ci.yml` brach bei PR #135 trotz 84 grüner Tests am
`timeout-minutes: 60` ab (Versuch 1: 61 min = 8 min Start + 44 min Tests + Abschluss; die Wiederholung war grün
in 40 min; Läufe auf `main` brauchten 46–55 min). Ursache ist die **Summe** aus Start, Bau und Testzeit, nicht
ein einzelner Test: die zwölf langsamsten Tests liegen bei 36–62 s, Mittel ca. 30 s. Die reine Testzeit
schwankt bei gleichem Code zwischen 1824 s und 2634 s (Faktor 1,44), der Simulator-Boot zwischen 1,5 und
5,4 min. Hat es bisher funktioniert? Ja, bis die Suite mit den Schnell-Eingabe-Tests auf ca. 30–44 min
Testzeit wuchs.

| Lauf | Start vor Test | Testschritt | Job gesamt | Ausgang |
|------|---------------|-------------|-----------|---------|
| PR #135, Versuch 1 | 8 min (Boot 5,4 min) | 52,5 min (Tests 2634 s) | 61 min | **Abbruch durch Limit** |
| PR #135, Versuch 2 | 3,3 min | 36,5 min (Tests 1824 s) | 40 min | grün |
| main 10.10. | 3,5 min | 42,2 min | 45,8 min | grün |
| main 9.10. | 4 min | 45 min | 49 min | grün |
| main 11.10. | 2,5 min | 48,5 min | 52 min | rot durch Testfehler (#118), nicht Limit |

Quelle und Einzelwerte: `docs/context/fix-136-ui-job-teilen.md`.

**Änderung (PO-Entscheidung 2026-10-11):** Die UI-Suite läuft in zwei parallelen Hälften. Der Job `ui-test`
wird zur Matrix mit zwei Einträgen. Hälfte A führt vier schwere Klassen aus, Hälfte B den gesamten Rest,
einschließlich künftiger Klassen. Das Limit bleibt bei 60 min je Hälfte. Erwartung aus dem grünen Lauf
hochgerechnet: A ca. 995 s, B ca. 822 s reine Testzeit (im langsamen Lauf ca. 1440 s / 1190 s), jeweils plus
ca. 5 min Bau und 3–8 min Start.

**Offene Grenze (gilt für jede positive Zusage dieser Spec):**
- Die Wirkung ist nur durch echte CI-Läufe beweisbar, nicht lokal. Die Zahlen oben sind eine Hochrechnung,
  keine Messung der Teilung.
- Die Runner-Schwankung (Start 1,5–5,4 min, Testzeit Faktor 1,44) bleibt bestehen. Die Teilung verschafft
  Abstand zum Limit, sie garantiert ihn nicht.
- Der Testfehler `testChangeStoreMovesItemAndRemembersCorrection` gehört zu #118, nicht zu #136; ein roter PR
  deswegen ist kein Zeichen, dass die Teilung versagt.
- Mehrverbrauch an Runner-Minuten: Bau und Simulator-Start laufen doppelt (je ca. 5 min Bau plus Start), die
  Warteschlange auf `macos-26` kann zwei Jobs getrennt aufhalten.

## Source

- **Geändert:**
  - `.github/workflows/ci.yml` — Job `ui-test` (ab ca. Zeile 99): `strategy` mit `fail-fast: false` und
    Matrix aus zwei Einträgen `A` und `B`; Jobname je Hälfte; `xcodebuild`-Aufruf mit Testauswahl je Hälfte;
    Artefaktname des xcresult je Hälfte; Kommentar über `timeout-minutes` angepasst.
  - `CLAUDE.md` — ein kurzer Absatz im Build-/Testabschnitt.
- **Nicht geändert:** gesamter Produktcode (`SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`),
  `RestockUITests/*`, `Restock.xcodeproj/project.pbxproj`, `.github/workflows/testflight.yml`, Job `test` in
  `ci.yml`.
- **Keine** neuen Produkt-Strings, **keine** neuen Dependencies, **keine** Änderung an `Info.plist`,
  `@AppStorage`-Schlüsseln oder Audio-Dateien.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `docs/context/fix-136-ui-job-teilen.md` | doc | verbindliche Analyse: Messung, Root Cause, Entscheidung |
| `.github/workflows/testflight.yml` | ci | enthält keinen Bezug auf `ui-test` (`needs`, `workflow_run`: keine Treffer) |
| Branch-Protection / Rulesets | ext | API liefert 404 bzw. `[]`: keine Schutzregel am Jobnamen `ui-test`, nichts zu migrieren |
| `docs/artifacts/fix-111-toast-dauer/messlauf-zusammenfassung.md` | doc | nennt den Jobnamen `ui-test` nur als Beschreibung |
| GitHub-Runner `macos-26` | ci | Nachweis ausschließlich durch echte Läufe |
| Memory „Leerer UI-Test-Start nur unter Last“ (#105) | doc | Maßstab für den Lauf unter zusätzlicher Last |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/ci.yml` | MODIFY | Job `ui-test` als Matrix mit zwei Hälften, Artefaktname, Kommentar |
| `CLAUDE.md` | MODIFY | ein Absatz: UI-Suite in zwei Hälften, neue Klassen landen in B |

### Estimated Changes

- Files: 2 (Limit 4–5)
- LoC: ca. +30 / −8 (Limit ±250). Das LoC-Gate zählt alles als Produktivcode; vor dem Abschluss mit
  `git diff --stat` gegen den Tip-Commit prüfen.
- Seiteneffekte: keine am Produkt. Jede Hälfte läuft auf eigenem Runner mit eigenem Simulator, also ohne
  gemeinsamen App-Group-Container; die Aufräum-Regel gesäter UI-Tests (`tearDown`) gilt unverändert je Hälfte.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Beide Hälften laufen im PR parallel und sind grün (AC-1)
- [ ] Die Summe der ausgeführten Tests beider Hälften ist 84, davon 1 übersprungen; kein Test doppelt, keiner fehlt (AC-2)
- [ ] Drei volle CI-Läufe liegen mit Zeiten je Schritt und Hälfte im Messbericht, jede Hälfte unter 45 min (AC-3)
- [ ] Ein Lauf unter zusätzlicher Last ist vorgelegt oder die Grenze offen benannt (AC-4)
- [ ] Der Ausfall einer Hälfte macht den PR rot (AC-5)
- [ ] Eine neue Testklasse ohne Eintrag landet in Hälfte B (AC-6)
- [ ] Die xcresult-Artefakte haben unterschiedliche Namen (AC-7)
- [ ] `ci.yml` ist gültiges YAML (AC-8)
- [ ] Die offene Grenze steht in Ticket und Bericht (AC-9)
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Job `test` und alle UI-Tests grün)

## Implementation Details

**Matrix.** Der Job `ui-test` erhält `strategy: fail-fast: false` und eine Matrix mit zwei Einträgen. Jobname je
Hälfte erkennbar: `ui-test (A)` und `ui-test (B)` (etwa über `name: ui-test (${{ matrix.half }})`). `fail-fast:
false`, damit eine rote Hälfte die andere nicht abbricht und beide Zeiten messbar bleiben. Der Rest des Jobs
(Checkout, Xcode-Wahl, `xcpretty`, Simulator-Wahl, Boot, Rechte) bleibt je Hälfte unverändert.

**Testauswahl.**
- **Hälfte A:** je Klasse `-only-testing:RestockUITests/<Klasse>` für `ReceiptReviewUITests`,
  `ShoppingRouteUITests`, `AddItemQuantitySuggestionUITests`, `ReceiptResolutionStatsUITests`.
- **Hälfte B:** `-only-testing:RestockUITests` plus `-skip-testing:RestockUITests/<Klasse>` für **dieselben**
  vier Klassen.
- **Anti-Drift:** Neue Klassen stehen in keiner Liste und laufen deshalb automatisch in B; nichts geht verloren.
  Die Klassenliste steht genau einmal in der Matrix-Definition, beide Aufrufe leiten ihre Argumente daraus ab
  (keine zweite Abschrift). Die genaue YAML-Form (z. B. eine Zeichenkette im Matrix-Eintrag, aus der ein
  kleiner Shell-Schritt die Argumente baut) legt Phase 5 fest; das Verhalten ist verbindlich.

**Artefakt.** `actions/upload-artifact@v4` darf den Namen nicht doppelt vergeben: `name: UITestResults-${{
matrix.half }}.xcresult` (oder gleichwertig). Auch `-resultBundlePath` bleibt je Runner lokal, kollidiert also
nicht.

**Limit.** `timeout-minutes: 60` bleibt je Hälfte. Der Kommentar darüber nennt die Teilung und die Zahlen
(Start 1,5–5,4 min, Testzeit Faktor 1,44) statt der alten „31 Min reine Testzeit“-Begründung.

**CLAUDE.md.** Ein kurzer Absatz im Build-/Testabschnitt: Die UI-Suite läuft in der CI in zwei Hälften
(`ui-test (A)` mit vier schweren Klassen, `ui-test (B)` mit dem Rest); neue Klassen landen automatisch in B;
die Klassenliste steht in `ci.yml`.

**Messbericht.** `docs/artifacts/fix-136-ui-job-teilen/` enthält je Lauf und Hälfte die Zeiten der Schritte
Start (Simulator-Wahl, Boot, Rechte), Bau und Test sowie die Gesamtzeit, belegt durch Run-IDs und Protokolle.

## Expected Behavior

- **Input:** PR oder Push gegen `main`.
- **Output:** Zwei Prüfungen `ui-test (A)` und `ui-test (B)` laufen parallel; beide müssen grün sein, damit
  die CI grün ist. Zusammen führen sie alle 84 Tests aus, davon 1 übersprungen.
- **Side effects:** höherer Verbrauch an Runner-Minuten (doppelter Bau und Start); bei Ausfall je Hälfte ein
  eigenes xcresult-Artefakt.

## Known Limitations

- Wirkung nur durch echte CI-Läufe beweisbar; die Teilung verschafft Abstand zum Limit, garantiert ihn nicht.
- Runner-Schwankung bleibt (Start 1,5–5,4 min, Testzeit Faktor 1,44).
- Der Schnitt ist an einem grünen Lauf gemessen; wächst eine Klasse in A oder B stark, kann eine Hälfte
  wieder an die Grenze kommen (Reserve: Alternative b).
- `testChangeStoreMovesItemAndRemembersCorrection` ist ein bekannter Fehler aus #118, nicht Teil dieses Fixes.
- Mehrverbrauch an Runner-Minuten und mögliche getrennte Wartezeiten in der Warteschlange.

## Test Plan

Für CI-Konfiguration gibt es **keine** Unit- oder UI-Tests im Repo und es werden hier keine erfunden. Die
„Tests“ dieser Änderung sind die in den Acceptance Criteria genannten Prüfungen:

- YAML-Check: `actionlint .github/workflows/ci.yml`, falls installiert, sonst
  `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` (AC-8)
- Testzählung aus den CI-Protokollen beider Hälften: Zeilen `Executed N tests` aufsummieren (AC-2)
- Zählprobe des Auswahlmusters: Testliste mit `xcodebuild test -enumerate-tests` (bzw. `-dry-run`, falls die
  Xcode-Version es unterstützt), je Hälfte mit den echten Auswahl-Argumenten; Vereinigung = Gesamtliste,
  Schnitt leer (AC-2, AC-6). Ob die Option in der lokalen Xcode-Version verfügbar ist, ist Teil des
  Prüfwegs und wird berichtet; ist sie es nicht, gilt allein der CI-Nachweis.
- Echte CI-Läufe: mindestens drei volle Läufe mit Zeiten je Schritt (AC-1, AC-3, AC-5, AC-7)
- `git diff --stat` gegen den Tip-Commit für Umfang (Scope)

## Acceptance Criteria

- **AC-1:** GIVEN ein PR mit der geänderten `ci.yml`, WHEN die CI läuft, THEN starten die Prüfungen
  `ui-test (A)` und `ui-test (B)` beide und laufen zeitlich parallel (überlappende Start- und Endzeiten in den
  Job-Protokollen); beide sind grün. Offene Grenze: nur durch echte CI-Läufe zeigbar.
- **AC-2:** GIVEN die Protokolle beider Hälften eines grünen Laufs, WHEN die Zeilen `Executed N tests`
  aufsummiert werden, THEN ist die Summe 84, davon 1 übersprungen (`ReceiptShareExtensionTests`); kein Test
  läuft doppelt, keiner fehlt (Gegenprobe über die Testlisten beider Auswahlmuster). Offene Grenze: nur durch
  echte CI-Läufe zeigbar.
- **AC-3:** GIVEN mindestens drei volle CI-Läufe mit der Teilung, WHEN die Zeiten je Schritt (Start, Bau,
  Test) und die Gesamtzeit je Hälfte ausgewertet werden, THEN liegt jede Hälfte in jedem Lauf unter 45 min
  (Abstand zum 60-min-Limit mindestens 15 min); die Zeiten stehen in einem Messbericht unter
  `docs/artifacts/fix-136-ui-job-teilen/`. Offene Grenze: Runner-Schwankung bleibt, drei Läufe beweisen den
  Abstand für diese Läufe, nicht für alle künftigen. Überschreitet eine Hälfte 45 min, wird Alternative (b)
  (drei Jobs) bewertet.
- **AC-4:** GIVEN ein CI-Lauf unter zusätzlicher Last (Maßstab Memory „Leerer UI-Test-Start nur unter Last“,
  #105), WHEN er vorgelegt wird, THEN zeigt er, ob beide Hälften auch bei langsamem Start und verlängerter
  Testzeit unter dem Limit bleiben und ob der leere erste Start (`UITestLaunch: zweiter Start nötig …`)
  auftritt. Lässt sich auf dem Runner keine Last herstellen, wird das als offene Grenze benannt, nicht
  übergangen.
- **AC-5:** GIVEN eine der beiden Hälften schlägt fehl oder läuft in das Limit, WHEN die CI abgeschlossen ist,
  THEN ist der PR rot (`fail-fast: false` bricht die andere Hälfte nicht ab, beide Ergebnisse bleiben
  sichtbar); belegt durch die Matrix-Semantik von GitHub Actions und, soweit ein roter Lauf anfällt, durch
  dessen Ergebnis. Ein absichtlich roter Lauf wird nur erzeugt, wenn er ohne Eingriff in `RestockUITests/*`
  möglich ist.
- **AC-6:** GIVEN eine neue UI-Testklasse, die in keiner Liste der Matrix steht, WHEN das Auswahlmuster
  geprüft wird (Testlisten per `xcodebuild test -enumerate-tests` bzw. `-dry-run`, falls verfügbar, sonst
  Zählung der Tests im CI-Protokoll), THEN läuft sie in Hälfte B und in keiner anderen. Dies ist ein
  Prüfweg, keine Behauptung: ist die Option nicht verfügbar, wird das berichtet.
- **AC-7:** GIVEN beide Hälften laden bei Fehlern ein xcresult hoch, WHEN der Artefaktname in `ci.yml` je
  Matrix-Eintrag aufgelöst wird, THEN sind die beiden Namen verschieden (z. B. `UITestResults-A.xcresult` und
  `UITestResults-B.xcresult`) und der Upload kollidiert nicht.
- **AC-8:** GIVEN die geänderte `ci.yml`, WHEN sie mit `actionlint` (falls installiert) bzw.
  `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` geprüft wird, THEN ist sie
  gültiges YAML ohne Fehler; `timeout-minutes: 60` steht unverändert am Job, der Kommentar darüber nennt die
  Teilung, die Klassenliste steht genau einmal in der Datei.
- **AC-9:** GIVEN der Abschluss des Fixes, WHEN Ticket und Berichte formuliert werden, THEN ist die offene
  Grenze ausdrücklich genannt: Wirkung nur durch echte CI-Läufe, Runner-Schwankung bleibt (Teilung
  verschafft Abstand, garantiert ihn nicht), `testChangeStoreMovesItemAndRemembersCorrection` gehört zu #118,
  Mehrverbrauch an Runner-Minuten; es gibt keine Aussage „zuverlässig“ oder „garantiert“. `CLAUDE.md` enthält
  den Absatz zur Teilung, der Diff umfasst genau `.github/workflows/ci.yml` und `CLAUDE.md` (ca. +30/−8 LoC),
  ohne Produktcode, `RestockUITests/*`, `project.pbxproj` oder `testflight.yml`.

## Nachtrag 2026-10-19: Wiederholung fehlgeschlagener UI-Tests im selben Lauf (Issue #173)

Befund: `ui-test (B)` war in drei von fünf Läufen am 2026-10-19 rot, jedes Mal nur durch bekannte
Sporadik ohne Code-Bezug (`StoreSetupUITests` Ziehgeste/Zeilenschalter, Toast-Dauertest aus #118);
die Ziehgeste fiel auch auf `main` (Lauf 230, Attempt 3). Jeder manuelle Rerun kostet 45 min und
blockiert Merges und TestFlight.

Maßnahme: `xcodebuild test` erhält in beiden Hälften `-retry-tests-on-failure -test-iterations 2
-test-repetition-relaunch-enabled YES`. Ein fehlgeschlagener Test läuft genau einmal erneut, die App
wird dafür neu gestartet (die Seed-/Aufräum-Startargumente der Klassen greifen also wie beim ersten
Lauf); der Lauf ist grün, wenn die Wiederholung grün ist. Kein Test wird übersprungen oder
deaktiviert, die Unit-Tests (`test`) wiederholen nichts. Ein `always()`-Schritt schreibt die
`xcresulttool`-Zusammenfassung in die Lauf-Zusammenfassung, damit Wiederholungen sichtbar bleiben;
er darf den Job nie rot machen. Strukturtest: `scripts/test_ci_ui_retry.py`.

Offene Grenzen: Die Ursachen der Sporadik sind damit nicht behoben, nur maskiert und gezählt; ein
echter, reproduzierbarer Fehler fällt weiterhin zweimal und bleibt rot. Ob die Zusammenfassung die
Wiederholungen ausweist, zeigt erst der nächste Lauf mit Sporadik (Xcode 26.6 auf dem Runner).
Laufzeit: je Wiederholung ca. 30–60 s zusätzlich, weit unter dem Limit von 60 min je Hälfte.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Matrix mit zwei Hälften; A per `-only-testing` je schwerer Klasse, B per `-only-testing:RestockUITests` plus `-skip-testing` derselben Klassen | trifft die belegte Ursache (Summe aus Start, Bau, Testzeit); eine Definition, kein Drift; Mehrverbrauch an Minuten |
| a | Nur `timeout-minutes` auf 90 anheben | verworfen: Der Abstand wird nicht größer, die Suite wächst weiter, ein hängender Lauf blockiert 90 min |
| b | Drei Jobs | Reserve: erst bauen, wenn eine Hälfte im Messlauf über ca. 45 min kommt; mehr Start-/Bauanteil, längere Warteschlange |
| c | Einmal `build-for-testing`, dann zwei Jobs mit `test-without-building` | spart ca. 5 min Doppelbau, braucht Artefaktübergabe und eine Zusatzstufe, mehr Teile können ausfallen; erst, wenn die Matrix nicht reicht |
| d | Tests kürzen (Einzeltests um 60 s) | bringt wenig: kein dominanter Einzeltest; eigenes Thema |

Kein Modell beteiligt: reine Konfiguration (Regeln vor Modell). Keine bestehende ADR wird gekippt.

**Entscheidung (PO, 2026-10-11):** Weg A.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine CI-Konfiguration, kein Eingriff in App-Architektur; keine frühere Entscheidung wird
  gekippt.

## Risiken

- **Eine Hälfte kommt trotzdem über ca. 45 min:** Schnitt ist an einem Lauf gemessen. Dann Alternative (b).
- **Doppelter Start:** zwei Boot-Phasen, jede kann einzeln bis 5,4 min brauchen; der Abstand von mindestens
  15 min je Hälfte fängt einen Einzelausreißer, garantiert aber nichts.
- **Mehrverbrauch an Runner-Minuten und Warteschlange** (Hinweis „capacity constraints, macOS arm64“ in den
  Annotations): Zwei Jobs warten ggf. getrennt.
- **Jobname ändert sich** von `ui-test` zu `ui-test (A)`/`ui-test (B)`: keine Schutzregel hängt daran
  (Branch-Protection 404, Rulesets leer); sollte künftig eine Pflichtprüfung eingerichtet werden, müssen beide
  Namen eingetragen werden.
- **Testzählung weicht ab:** Falls die Summe nicht 84 ergibt, ist der Schnitt fehlerhaft (AC-2 deckt das auf).
- **Ein Einzellauf beweist keine Stabilität:** deshalb mindestens drei volle Läufe (AC-3).

## Changelog

- 2026-10-11: Initial spec created (Issue #136; UI-Suite in zwei parallele Hälften, Entscheidung des PO
  2026-10-11, Nachweis durch YAML-Prüfung, Testzählung und echte CI-Läufe)

## Nachtrag 2026-10-20 (Issue #145, Durchgang 2)

Hälfte A wählt zusätzlich `NotificationPermissionUITests` und setzt `TEST_RUNNER_RESTOCK_NOTIF_DECISION=allow`, Hälfte B setzt `deny` (Klasse dort Teil von `RestockUITests`). `HEAVY_CLASSES` bleibt die einzige Quelle von A und ist unverändert. Strukturtest: `scripts/test_ci_notification_permission.py`.

## Nachtrag 2026-10-21 (Issue #99, Paket 3)

`DynamicTypeUITests` (zwei Tests in Schriftgröße XXXL) steht als fünfte Klasse in `HEAVY_CLASSES` und läuft in
Hälfte A. Grund: Im Lauf 39551841477 brauchte Hälfte B 53 min (Limit 60 min), Hälfte A 30 min. Die Regel
„neue Klassen landen automatisch in B“ bleibt; dies ist eine bewusste Ausnahme zur Lastverteilung. Die Liste
steht weiter genau einmal in `ci.yml`.

## Nachtrag 2026-10-21: Wiederholung, Fassung 2 (Issue #173)

Befund (PR #197, Lauf 39563379941): Die Flags `-retry-tests-on-failure -test-iterations 2
-test-repetition-relaunch-enabled YES` wiederholten nach einem einzigen Fehlschlag **die gesamte Auswahl**, nicht
den fehlgeschlagenen Test. Hälfte A: Durchlauf 1 07:48–08:15 (1 Fehler, `DynamicTypeUITests` T1), danach alle fünf
Klassen von vorn bis zum Abbruch am 60-min-Limit um 08:38; Hälfte B: Durchlauf 1 07:48–08:29 (1 Fehler,
`DataResetUITests.testAppUsableAfterEmergencyReset`, 5-s-Wartefrist auf „Nudeln“, bekannte Sporadik), danach alle
Klassen von vorn bis zum Abbruch. Beide Hälften rot durch Zeitüberschreitung, obwohl der je einzige Fehler in der
Wiederholung grün war (B) bzw. ein echter Testfehler war (A). Die erste Fassung war bis dahin nie mit einem
Fehlschlag gelaufen; ihre Laufzeitschätzung („30–60 s zusätzlich“) war falsch.

Maßnahme: Die Flags entfallen. Der Schritt ruft `xcodebuild test` einmal; ist der Lauf rot, liest
`scripts/ci_failed_ui_tests.py` die fehlgeschlagenen Testfälle aus `xcrun xcresulttool get test-results tests`
(Knoten `Test Case` mit Ergebnis `Failed`, Kennung ohne `()`), und `xcodebuild test-without-building` startet genau
diese mit `-only-testing:RestockUITests/<Klasse>/<Test>` in ein zweites Bündel `UITestRetry.xcresult`. Grün bei
grüner Wiederholung; Rot ohne fehlgeschlagenen Testfall (Bau, Simulator, Abbruch) bleibt ohne Wiederholung rot;
kein Test wird übersprungen. Die Zusammenfassung zeigt beide Bündel, das Artefakt bei Rot enthält beide.
Strukturtest `scripts/test_ci_ui_retry.py` (Aufbau und Kennungs-Parser mit Beispielbaum); der Schrittablauf ist
mit Attrappen für `xcodebuild`/`xcrun` in vier Fällen (grün, rot→grün, rot→rot, rot ohne Testfall) trocken
durchgespielt. Offene Grenze: Die JSON-Form von `xcresulttool` ist aus Xcode 16+ bekannt, auf dem Runner (Xcode 26.6)
erst mit dem nächsten Fehlschlag belegt; der Parser liefert bei fremder Form keine Kennung, dann bleibt der Lauf
ohne Wiederholung rot statt falsch grün.

Belegt im Lauf 39573224713 (PR #197, Hälfte A): erster Lauf 43 Tests, 1 Fehler (`DynamicTypeUITests` T1), danach
`Wiederholung genau einmal (Issue #173): -only-testing:RestockUITests/DynamicTypeUITests/testResolutionStats…`,
1 Test in 79 s, Job gesamt 26 min statt Abbruch bei 60 min. Die JSON-Form von `xcresulttool` auf Xcode 26.6 ist damit
belegt (Kennung korrekt gelesen). Die Wiederholung blieb rot, weil T1 ein echter Fehler war (Spaltenkopf 40 statt
100 pt), wie vorgesehen.

Dritter Befund (Läufe 39573224713, 39581094360, 39588635436): Die Wiederholung scheiterte dreimal an der
**Vorbedingung** des wiederholten Tests, nie an seiner Sache: kein Entwicklermodus („Link fehlt nach 30 Wischern“),
kein Seed („Karte „Ohne Laden“ fehlt“). Der wiederholte Test ist in `test-without-building` immer der erste Start
seiner Sitzung, und der erste Start kommt gelegentlich ohne Launch-Argumente an (Issue #105/#128, dort gemessen).
Folge: Klassen, die ihre Vorbedingung über Launch-Argumente herstellen, müssen über `UITestLaunch.start` starten
(Gegenprobe auf ein Element, das nur mit den Argumenten erscheint, genau ein zweiter Start). Umgestellt:
`DynamicTypeUITests` (DEV-Pill bzw. Kopfzeile des Prüf-Screens) und `QuickAddAssignmentUITests` (Kachel „Lidl“).
Die übrigen gesäten Klassen mit nacktem `app.launch()` stehen in einem Folge-Issue; bis dahin kann ihre
Wiederholung aus demselben Grund rot bleiben. Der erste Durchlauf von Hälfte A mit `DynamicTypeUITests` ist seit
Lauf 39588635436 grün (43 Tests, 37 min).
