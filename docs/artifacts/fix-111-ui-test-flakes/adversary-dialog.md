# Adversary Dialog — fix-111-ui-test-flakes
Spec: docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
Datum: 2026-10-06 08:30

## Checkliste
- [x] **AC-1:** GIVEN ein Element, dessen Rahmen `inf` oder leer meldet, WHEN `waitUntilHittable` läuft, THEN wartet sie bis zur Frist weiter und scheitert nicht hart; erst ein endlicher, nicht leerer Rahmen mit `isHittable == true` beendet sie mit Erfolg.
- [x] **AC-2:** GIVEN ein Element, das sofort hittable ist, WHEN `waitUntilHittable` läuft, THEN kehrt sie in der ersten Runde zurück (zustandsbasiert, keine feste Wartezeit).
- [x] **AC-3:** GIVEN ein Element, das bis zum Fristende nicht hittable wird, WHEN die Frist abläuft, THEN nennt die Fehlermeldung den zuletzt gesehenen Zustand (exists, frame, hittable) ohne zusätzliche Abfrage nach Fristablauf.
- [x] **AC-4:** GIVEN ein Label, das den erwarteten Text nicht enthält, WHEN `waitForLabel(contains:)` abläuft, THEN liefert sie den zuletzt gelesenen Label-Text zurück, und die Fehlermeldung nennt ihn.
- [x] **AC-5:** GIVEN die Standardfrist, WHEN sie benutzt wird, THEN beträgt sie 20 s und ist an einer Stelle (`UITestWait.defaultTimeout`) definiert.
- [x] **AC-6:** GIVEN die Tests `ShoppingRouteUITests.testSwitchingSortModesReordersList`, `testSortModeIsRememberedPerStore`, `testCreatingCustomCategoryFromItemDialog`, `QuickAddAssignmentUITests.testUnassignedCardShowsCountAndNames` und `AddItemQuantitySuggestionUITests.testStaleSuggestionIsDroppedWhenNameIsTypedFurther`, WHEN der Durchgang umgesetzt ist, THEN prüfen sie inhaltlich dasselbe wie vorher (gleiche Assertions auf Sortierreihenfolge, Kategorie, Zähler-/Namenstext, Einheit „l“); geändert ist nur das Warten.
- [x] **AC-7:** (PO-Ausnahme, im Werkzeug erfasst: adversary_ambiguous_override; #115, #105) GIVEN die gesamte UI-Suite, WHEN sie lokal auf `Restock-Validate` im gemeinsamen Lauf läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag.
- [x] **AC-8:** GIVEN der Wegwerf-Zweig mit auf die betroffenen Klassen eingeschränkter `ci.yml` und `-test-iterations 30` ohne Retry, WHEN der Vorher-Lauf (Stand `main`) läuft, THEN ist die Fehlerquote dokumentiert; ist sie 0, wird das offen benannt und der Nachweis entsprechend eingeschränkt.
- [x] **AC-9:** GIVEN derselbe Wegwerf-Zweig mit dem Fix, WHEN der Nachher-Lauf läuft, THEN sind es 0 Fehler, und das xcresult belegt, dass weiterhin Einzelabfragen > 4 s vorkommen (gleiche Runner-Lage, Tests trotzdem grün). `ci.yml` auf `main` ist unverändert.
- [x] **AC-10:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN gibt es keine Änderung unter `SmartCart/` (App-Verhalten unverändert), und der Umfang liegt bei 5 Dateien und ca. +110/−20 LoC.
- [x] **AC-11:** GIVEN der Abschluss des Durchgangs, WHEN Ticket und Berichte formuliert werden, THEN ist der Fehlschlag `testToastNamesStoreAndOffersChangeAndUndo` ausdrücklich als offen genannt (Durchgang 2), ebenso XCTests eigene Abfrage-Zeitgrenze („Timed out while evaluating UI query“), gegen die keine Frist im Test hilft, und der Wettlauf zwischen den getrennten Abfragen `frame` → `isHittable` → `tap()`: meldet der Runner den `inf`-Rahmen erst beim Lesen von `isHittable` oder beim Tippen, scheitert der Test weiterhin hart (in den Messläufen nicht beobachtet); es gibt keine Aussage „alle Flakes behoben“, und #111 bleibt offen.
- [x] **AC-12:** GIVEN die neue Datei, WHEN `xcodebuild` das UI-Test-Target baut, THEN ist sie in `project.pbxproj` an allen vier Stellen registriert, und der Build läuft ohne Fehler.
- [x] **AC-13:** GIVEN die fünf Tests aus AC-6 samt der privaten Hilfen, die sie aufrufen, WHEN eine Stelle positiv wartet (Element erscheint, Wert stellt sich ein, Element verschwindet) und dafür eine Frist unter der Standardfrist hat, THEN nutzt sie `UITestWait.defaultTimeout`. Negative Prüfungen, Ausweich-Abfragen und die Toast-Tests (Durchgang 2) bleiben unverändert; Kaltstart-Fristen ≥ 15 s ebenfalls. Die Prüfungen selbst bleiben wie in AC-6.

## Dialog

### Runde 1
**Adversary:**
Behauptung: Die Hilfen warten zustandsbasiert, überstehen `inf`-/leere Rahmen, melden den letzten Zustand ohne Zusatzabfrage; die fünf Tests prüfen dasselbe wie vorher; Runner-Messung vorher 5/300, nachher 0/450. Ich glaube nichts davon ungesehen und prüfe Code, Diff gegen Basis `acd3be4`, Testausgaben und Messartefakte selbst.

Eigener Testlauf (Restock-Validate, vorher `ps` ohne laufende xcodebuild/xctest): `UITestWaitTests` (6) plus die fünf AC-6-Tests plus Toast-Test `testToastNamesStoreAndOffersChangeAndUndo` → `Executed 12 tests, with 0 failures`, `** TEST SUCCEEDED **`, 0 übersprungen (`docs/artifacts/fix-111-ui-test-flakes/adversary-test-output.txt`).

Grenzfälle der Hilfen, am Code gelesen:
- Element existiert nicht: `readState` liefert `exists=false, frame=.zero, hittable=false`, liest weder `frame` noch `isHittable`.
Code reference: RestockUITests/UITestWait.swift:26
- Rahmen `inf` / `nan` / leer: `isFinite` über alle vier Komponenten plus `!rect.isEmpty`; `CGRect.null` (Ursprung inf) fällt ebenfalls durch; `isHittable` wird dann nicht gelesen.
Code reference: RestockUITests/UITestWait.swift:28
- Frist 0 oder negativ: `poll` liest genau einmal, prüft danach die Deadline und kehrt mit dem gelesenen Wert zurück; kein Absturz, kein Hängen.
Code reference: RestockUITests/UITestWait.swift:36
- Frist läuft während einer langen Abfrage ab: Deadline-Prüfung erst nach `read()`; zurück kommt der Wert dieser Runde, keine Extra-Abfrage. Überziehung um bis zu eine Runde (bei 3 Abfragen à 4 s also bis ca. 32 s statt 20 s) — kein harter Fehler.
Code reference: RestockUITests/UITestWait.swift:40
- Standardfrist an genau einer Stelle, 20 s.
Code reference: RestockUITests/UITestWait.swift:20

Fragen an den Implementierer: (1) Wird `labelOf` noch von den Toast-Tests benutzt? (2) Belegen die Hilfstests den echten `XCUIElement`-Pfad oder nur die Regel? (3) Stammt der Gesamtlauf (AC-7) vom jetzigen Stand? (4) Ist der gemessene Nachher-3-Stand identisch mit dem Arbeitsstand?

**Implementierer:**
(Antworten aus den vorgelegten Artefakten, vom Adversary nachgeprüft.)
(2) T1–T4 prüfen `readState`/`poll` mit eingespeisten Closures (Spec erlaubt das ausdrücklich, Test Plan „Prüfung der Entscheidungsregel als reine Funktion ohne App“). Der echte Pfad läuft in den UI-Tests: `waitUntilHittable` in `openedStore`, Neustart-Zweig, `openQuittenhofStoreDetail`, `openStore`; `waitForLabel` in `testUnassignedCardShowsCountAndNames`.
Code reference: RestockUITests/UITestWait.swift:47
Code reference: RestockUITests/ShoppingRouteUITests.swift:34
Code reference: RestockUITests/ShoppingRouteUITests.swift:116
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:61
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:72
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:205
(4) Diff-Statistik Arbeitsstand gegen den Wegwerf-Stand von Nachher 3 (cf89d2b) für RestockUITests, Restock.xcodeproj und SmartCart ist leer → Nachher 3 lief exakt auf dem jetzigen Testcode. Diff gegen die Basis acd3be4 für SmartCart und .github ist leer → kein App-Code, ci.yml unverändert.
(3) Der Gesamtlauf `test-full-suite-ui-77-green-unit-hung.txt` stammt von 09:00; `ShoppingRouteUITests.swift`/`AddItemQuantitySuggestionUITests.swift` wurden um 13:58/13:59 (AC-13) zuletzt geändert. Auf dem jetzigen Stand liegt `test-green-output-2.txt` vor (Start 13:59:26): alle vier geänderten Klassen vollständig (30 Tests, 0 Fehler, inkl. Toast-Tests).
(1) Ja — siehe Runde 2.

Zwischenstand Runde 1: AC-2, AC-3, AC-5, AC-12 belegt; AC-1/AC-4 auf Regel-Ebene belegt; AC-7, AC-13 offen.

Confirmation:
  AC: AC-2
  Code reference: RestockUITests/UITestWait.swift:39
  Evidence: `done(value)` wird vor jeder Pause geprüft; T2 `testPollReturnsInFirstRoundWhenReady` (reads == 1, < 1 s) grün in adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: RestockUITests/UITestWait.swift:40
  Evidence: Bei Fristablauf wird der Wert der letzten Runde zurückgegeben, kein weiterer `read()`; Beschreibung `exists=… frame=… hittable=…` (UITestWait.swift:15); Aufrufer übernehmen `ready.last` in die Meldung (ShoppingRouteUITests.swift:35, AddItemQuantitySuggestionUITests.swift:62, QuickAddAssignmentUITests.swift:73). T3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockUITests/UITestWait.swift:20
  Evidence: `static let defaultTimeout: TimeInterval = 20`, einzige Definition; alle Aufrufer referenzieren `UITestWait.defaultTimeout`. Test `testDefaultTimeoutIsTwentySeconds` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Restock.xcodeproj/project.pbxproj:174
  Evidence: PBXBuildFile (174), PBXFileReference (373), PBXGroup RestockUITests (708), PBXSourcesBuildPhase UI-Test-Target (1078); UUID …E01 2×, …E02 3× — keine Kollision. Build + Lauf grün (adversary-test-output.txt).
  Status: CONFIRMED

### Runde 2
**Adversary:**
Tiefer gebohrt: Toast-Tests, Hittable-Wettlauf, Messmethodik, Assertions, Umfang, AC-7, AC-11.

1. **Toast-Tests indirekt verändert.** `labelOf` wurde umgebaut (Standardfrist 20 s statt 5 s, `exists` + `label` je Runde statt `XCTNSPredicateExpectation`). `testUnassignedCardShowsCountAndNames` ruft `labelOf` gar nicht mehr auf (nutzt `waitForLabel` direkt, Z. 205/207). Die Änderung wirkt also ausschließlich auf andere Tests — darunter die Toast-Tests `testToastNamesStoreAndOffersChangeAndUndo` (Z. 146) und `testChangeStoreMovesItemAndRemembersCorrection` (Z. 303). AC-13: „die Toast-Tests (Durchgang 2) bleiben unverändert“. Der Quelltext der Toast-Tests ist unverändert, ihr Warteverhalten nicht: erste Runde jetzt 2 Abfragen statt 1 — genau im 6-s-Fenster, in dem der 7. Flake bereits an der Summe der Abfragen scheitert. Der Runner-Messlauf schließt Toast-Tests aus (ci-messlauf.yml, `-only-testing` nur die fünf AC-6-Tests) — Wirkung ungemessen. Die Spec widerspricht sich (Implementation Details 3: „`labelOf` ruft `waitForLabel` auf … Standardfrist statt 5 s“ vs. AC-13).
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:60
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:146
Code reference: RestockUITests/UITestWait.swift:57
Zusätzlich: Verschwindet das Element zwischen `exists` und `label` (Toast nach 6 s), scheitert der `label`-Zugriff hart statt `matched=false` zu liefern.

2. **Wettlauf frame → isHittable → tap.** `readState` liest `frame` und `isHittable` in zwei getrennten Abfragen; `tap()` löst das Element danach ein drittes Mal auf. Liefert die `isHittable`- oder `tap`-Momentaufnahme `inf`, scheitert es weiterhin hart („Activation point invalid“). Der Schutz greift nur, wenn `inf` schon bei der Rahmen-Abfrage auftritt. In keinem der Messläufe kam ein `inf`-Rahmen vor (Suche nach „Activation point“/„inf, inf“ in messlauf-* → 0 Treffer) — der `inf`-Schutz ist auf dem Runner nie ausgelöst, nur auf Regel-Ebene bewiesen.
Code reference: RestockUITests/UITestWait.swift:30
Code reference: RestockUITests/ShoppingRouteUITests.swift:36

3. **Messmethodik.** `slow_queries.py` misst Abstand Start-Aktivität → Start nächste Aktivität. Innerhalb eines `waitForExistence` schließt das XCTests Warten mit ein (Nachher 3, Iteration 18: 19,23 s + 15,89 s an einer einzigen 20-s-Wartestelle). „Einzelabfragen > 4 s“ ist damit ein Näherungswert (Abfrage oder spätes Erscheinen). Für die Kernaussage „mit 5-s-Frist wäre diese Stelle gescheitert, mit 20 s grün“ trägt es trotzdem. Vorher 2 (2/150) liegt nur als Zeile der Zusammenfassung vor, ohne Log-Auszug/Fundstellen-Datei. Die AC-13-Fassung hat nur 150 Läufe (bei der Vorher-2-Rate 2/150 wären 0/150 mit ca. 13 % auch ohne Wirkung zu erwarten); stärkerer Beleg sind die 8 Wartestellen > 5 s in Nachher 3, die grün blieben.
Code reference: docs/artifacts/fix-111-ui-test-flakes/slow_queries.py:44
Nachher 3 zeigt außerdem die Ausweich-Abfrage in `choose` (5 s) mit 18,14 s → Ausweichpfad über `descendants(label == mode)` genommen. Spec-konform (Ausweich-Abfragen bleiben), Kandidat für Durchgang 3.
Code reference: RestockUITests/ShoppingRouteUITests.swift:59

4. **Assertions (AC-6).** Diff Zeile für Zeile: nur Fristen von 5/10 s auf `UITestWait.defaultTimeout`, `expectation(isHittable)` → `waitUntilHittable` + `XCTAssertTrue(ready.matched)`, `labelOf` → `waitForLabel` mit gleichem Text. Sortier-Erwartungen, „🥛 Milchprodukte“, „Kühltheke hinten“/„🧊“, „2 Artikel ohne Laden“/„Testartikel Eins“, `value == "l"`, die negativen `XCTAssertFalse(...exists)` (ca. 2 l / 2 l) — unverändert. Kaltstart `waitForExistence(timeout: 15)` unverändert, Ausweich `button.waitForExistence(timeout: 5)` unverändert.
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:204
Code reference: RestockUITests/ShoppingRouteUITests.swift:101

5. **Umfang (AC-10).** Diff-Statistik gegen die Basis acd3be4: 5 Dateien, +176/−32 (208). Spec: „ca. +110/−20“ plus AC-13 „ca. ±25“. Hartes Limit ±250 eingehalten; Schätzung um ~60 % überschritten (UITestWait.swift 137 Zeilen statt ~70, Hilfstests ~75 Zeilen in derselben Datei).

6. **AC-7.** Formaler Gesamtlauf entstand vor AC-13 und endete insgesamt mit `** TEST FAILED **` (Unit-Runner hing, #63); der UI-Teil war 77 Tests / 0 Fehler / 1 übersprungen. Für den jetzigen Stand fehlt ein Lauf der gesamten UI-Suite.

7. **AC-11.** Spec (AC-11, Changelog, Purpose) und messlauf-zusammenfassung.md nennen Toast-Test und „Timed out while evaluating UI query“ als offen; das Briefing ebenfalls, enthält aber den überholten Satz „Messung der erweiterten Fassung steht noch aus“. Ticket-/Berichtsformulierung erst in Phase 8 prüfbar.

**Implementierer:**
(Zu 1) Die Spec schreibt die `labelOf`-Umstellung in Implementation Details 3 ausdrücklich vor; der Toast-Quelltext ist unangetastet. Lokal laufen alle 12 `QuickAddAssignmentUITests` inkl. Toast-Tests grün (test-green-output-2.txt; Adversary-Eigenlauf: Toast-Test grün). Eine Runner-Messung der Toast-Tests mit neuem `labelOf` gibt es nicht. → Widerspruch in der Spec bleibt offen; Entscheidung nötig.
(Zu 2) Die Spec gibt die Reihenfolge exists → frame → isHittable vor; Alternative C (direktes `tap()`) war bewusst verworfen. Der Wettlauf ist nicht als offene Grenze benannt.
(Zu 3–7) Belege wie oben; kein Gegenargument.

Ergebnis Runde 2: AC-1, AC-4, AC-6, AC-8, AC-9, AC-10 bestätigt (mit Einschränkungen in den Findings); AC-7 und AC-13 AMBIGUOUS; AC-11 erst in Phase 8 abschließend nachweisbar.

Confirmation:
  AC: AC-1
  Code reference: RestockUITests/UITestWait.swift:29
  Evidence: Bei nicht endlichem oder leerem Rahmen wird `isHittable` nicht gelesen, Zustand „nicht bereit“, `poll` läuft weiter; T1 (`testInfiniteOrEmptyFrameIsNotReadyAndSkipsHittable`, `testPollKeepsWaitingThroughInfiniteFrames`: 3 Runden → Erfolg) grün. Einschränkung F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockUITests/QuickAddAssignmentUITests.swift:206
  Evidence: `waitForLabel` liefert `lastLabel` aus der letzten Runde (UITestWait.swift:59); Meldungen „Anzahl fehlt — bekommen: \(count.lastLabel)“ / „Name fehlt — bekommen: \(name.lastLabel)“ ohne zweite `card.label`-Abfrage. T4 grün (prüft `poll`, nicht die Extension selbst).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/ShoppingRouteUITests.swift:117
  Evidence: Diff gegen acd3be4 ändert in den fünf Tests ausschließlich Fristen und die Hittable-Warteform; alle inhaltlichen Assertions wortgleich. Eigenlauf: alle fünf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/fix-111-ui-test-flakes/ci-messlauf.yml:76
  Evidence: `-test-iterations 30`, kein `-retry-tests-on-failure`, nur die fünf Tests; Vorher-1-Log: `Executed 150 tests, with 3 failures` (2× isHittable-5-s, 1× „Timed out while evaluating UI query“). Vorher 2 (2/150) nur in der Zusammenfassung belegt (F005).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/fix-111-ui-test-flakes/messlauf-nachher3-langsame-abfragen.txt:1
  Evidence: Nachher 3 (cf89d2b, Testcode identisch mit Arbeitsstand): `Executed 150 tests, with 0 failures`; 21 Aktivitäten > 4 s, davon 8 > 5 s in 20-s-Wartestellen; Nachher 1/2 je 0/150 (erste Fassung). ci.yml gegenüber der Basis unverändert. Einschränkung F005.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Restock.xcodeproj/project.pbxproj:1078
  Evidence: Diff gegen die Basis unter `SmartCart/` leer; 5 Dateien. Umfang über der Schätzung, unter dem Limit (F004).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md:241
  Evidence: Spec und messlauf-zusammenfassung.md nennen Toast-Test und XCTest-Abfragegrenze als offen, keine Aussage „alle Flakes behoben“. Ticket-/Berichtstext erst beim Abschluss (Phase 8) nachweisbar; Briefing-Satz veraltet (F007).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/QuickAddAssignmentUITests.swift:60
  Description: `labelOf` nutzt jetzt `waitForLabel` (20 s, je Runde `exists` + `label`). Die AC-6-Tests rufen `labelOf` nicht mehr auf; betroffen sind nur andere Tests, darunter die Toast-Tests (Z. 146, Z. 303). Deren Quelltext ist unverändert, ihr Warteverhalten nicht (eine zusätzliche Abfrage in der ersten Runde, 20 s statt 5 s im Fehlerfall; harter Fehler, falls der Toast zwischen `exists` und `label` verschwindet, UITestWait.swift:57). Auf dem Runner ungemessen (Messlauf schließt Toast-Tests aus).
  Spec requirement: AC-13 — „die Toast-Tests (Durchgang 2) bleiben unverändert“; gleichzeitig Implementation Details 3 „`labelOf` ruft `waitForLabel` auf“.
  Conflict: Die Spec widerspricht sich; die Umsetzung folgt Punkt 3 und verändert damit das Verhalten genau des Tests, dessen Flake (Summe der Abfragen > 6 s Anzeigedauer) offen ist — möglicherweise zum Schlechteren.
  Remediation: `labelOf` auf den alten Stand (XCTNSPredicateExpectation, 5 s) zurücksetzen — `testUnassignedCardShowsCountAndNames` nutzt `waitForLabel` bereits direkt — oder den Widerspruch in der Spec auflösen und die Toast-Tests in einem Runner-Messlauf gegenmessen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: RestockUITests/UITestWait.swift:30
  Description: `frame` und `isHittable` werden in getrennten Abfragen gelesen, danach löst `tap()` (ShoppingRouteUITests.swift:36) das Element erneut auf. Kommt die `inf`-Momentaufnahme erst bei `isHittable` oder `tap`, scheitert es weiterhin hart. In den Messläufen trat kein `inf`-Rahmen auf; der Schutz ist auf dem Runner unbewiesen.
  Spec requirement: AC-1 — `waitUntilHittable` scheitert bei `inf`-Rahmen nicht hart.
  Conflict: Kein Verstoß gegen den Wortlaut (der GIVEN-Fall ist abgedeckt), aber eine nicht benannte Restlücke für 2 der 7 analysierten Fehlschläge.
  Remediation: Als offene Grenze in Spec/Ticket aufnehmen; in einem Folge-Durchgang ggf. Tipp über die gelesene Koordinate prüfen.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/ShoppingRouteUITests.swift:52
  Description: Der einzige Lauf der gesamten UI-Suite (test-full-suite-ui-77-green-unit-hung.txt, 09:00) stammt vor AC-13 (ShoppingRouteUITests/AddItemQuantitySuggestionUITests zuletzt 13:58/13:59 geändert) und endete insgesamt mit `** TEST FAILED **` (Unit-Runner-Hänger #63). Auf dem jetzigen Stand gibt es nur Teilläufe (test-green-output-2.txt: 4 geänderte Klassen, 30/0; adversary-test-output.txt: 12/0).
  Spec requirement: AC-7 — gesamte UI-Suite im gemeinsamen Lauf grün, Testzahl > 0, kein Abbruch.
  Conflict: Für den jetzigen Stand nicht belegt.
  Remediation: Orchestrator: gesamte UI-Suite (`-only-testing:RestockUITests`) auf Restock-Validate auf dem jetzigen Stand laufen lassen; 77 Tests, 0 Fehler, 1 übersprungen (ReceiptShareExtensionTests) erwartet.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: RestockUITests/UITestWait.swift:65
  Description: Umfang +176/−32 (5 Dateien) statt „ca. +110/−20“ (+ ca. ±25 für AC-13); Hilfstests (~75 Zeilen) in derselben Datei.
  Spec requirement: AC-10 — Umfang ca. +110/−20 LoC.
  Conflict: Schätzung deutlich überschritten, hartes Limit ±250 eingehalten.
  Remediation: Im Abschlussbericht offen nennen; keine Codeänderung nötig.

Finding:
  ID: F005
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/artifacts/fix-111-ui-test-flakes/slow_queries.py:44
  Description: Dauer = Abstand zur nächsten Aktivität; schließt XCTests eigenes Warten in `waitForExistence` ein (Iteration 18: 19,23 s + 15,89 s an einer Stelle). Vorher 2 ohne eigene Log-/Fundstellen-Datei; AC-13-Fassung nur 150 Läufe.
  Spec requirement: AC-9 — xcresult belegt Einzelabfragen > 4 s.
  Conflict: Messgröße ist Näherung (Abfrage oder spätes Erscheinen); Kernaussage „mit 5 s rot, mit 20 s grün“ trägt dennoch.
  Remediation: In der Zusammenfassung „Abfrage- bzw. Wartedauer > 4 s“ formulieren; Vorher-2-Log-Auszug ablegen.

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/ShoppingRouteUITests.swift:59
  Description: Ausweich-Abfrage `button.waitForExistence(timeout: 5)` in `choose` lief in Nachher 3 18,14 s → Ausweichpfad genommen. Spec-konform unverändert, aber unter Runner-Last greift der Ausweich regelmäßig.
  Spec requirement: AC-13 — Ausweich-Abfragen bleiben unverändert.
  Conflict: Kein Verstoß; Hinweis für Durchgang 3.
  Remediation: Im Ticket für Durchgang 3 vermerken.

Finding:
  ID: F007
  Severity: LOW
  Category: spec_violation
  Code reference: docs/briefings/fix-111-ui-test-flakes.md:27
  Description: Briefing sagt „Die 0 Fehler stammen aus der Fassung vor der Erweiterung; Messung der erweiterten Fassung steht noch aus“ — überholt (Nachher 3, 0/150 auf AC-13-Stand). F002 fehlt als offene Grenze.
  Spec requirement: AC-11 — offene Grenzen korrekt in Berichten.
  Conflict: Bericht nicht aktuell; Ticket-Text erst in Phase 8 prüfbar.
  Remediation: Briefing/Abschlussbericht aktualisieren.

### Runde 3
**Adversary:**
Nachprüfung der Reaktion auf Runde 2 auf dem jetzigen Arbeitsstand (Basis `acd3be4`). Eigener Lauf (Restock-Validate, vorher `ps` ohne xcodebuild/xctest): `QuickAddAssignmentUITests` (12, inkl. aller vier Toast-Tests) + `UITestWaitTests` (6) → `Executed 18 tests, with 0 failures`, `** TEST SUCCEEDED **`, 0 übersprungen (`adversary-test-output.txt`).

1. **F001 (labelOf).** `git diff acd3be4 -- RestockUITests/QuickAddAssignmentUITests.swift` = +6/−4, nur `openStore` (Z. 73–74) und `testUnassignedCardShowsCountAndNames` (Z. 206–209). `labelOf` ist wortgleich der Ausgangsstand (`XCTNSPredicateExpectation`, 5 s). Spec Umstellung 3, Source und Affected-Files-Tabelle sagen jetzt dasselbe; der Widerspruch zu AC-13 ist aufgelöst. Toast-Tests im Eigenlauf grün. → F001 erledigt.
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:58
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:73

2. **labelOf von den AC-6-Tests aufgerufen?** `grep labelOf`: Aufrufe nur in Z. 112–337 außerhalb von `testUnassignedCardShowsCountAndNames` (Z. 201–210 nutzt nur `waitForLabel`); `ShoppingRouteUITests` und `AddItemQuantitySuggestionUITests` kennen `labelOf` nicht. Der Runner-Messlauf (`ci-messlauf.yml`) lief nur über die fünf AC-6-Tests → Nachher 3 bleibt für AC-9/AC-13 gültig, obwohl er vor dem Zurücksetzen lief.
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:206

3. **AC-13 Restkontrolle.** Alle Fristen in den fünf Tests und ihren Hilfen: positive Wartestellen < 20 s sind auf `UITestWait.defaultTimeout` (ShoppingRouteUITests Z. 37, 51, 55, 61, 66, 94, 101, 119, 130–152; AddItemQuantitySuggestionUITests Z. 186, 198, 203, 205, 210, 213). Verblieben: Kaltstart 15 s (Z. 33, 115; AddItem Z. 60; QuickAdd Z. 204), Ausweich-Abfrage `choose` Z. 58 (5 s) — beides laut AC-13 ausgenommen. Die übrigen `timeout: 5` (ShoppingRoute Z. 159–180, AddItem Z. 126–247) gehören zu Tests außerhalb von AC-6. Assertions unverändert (AC-6).
Code reference: RestockUITests/ShoppingRouteUITests.swift:58
Code reference: RestockUITests/ShoppingRouteUITests.swift:101
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:205

4. **F002 / F005 / F007.** AC-11 der Spec nennt den Wettlauf `frame` → `isHittable` → `tap()` jetzt als offene Grenze (spec Z. 246–248). `messlauf-vorher2-log-auszug.txt` liegt vor: `Executed 150 tests, with 2 failures`, 2× `testSwitchingSortModesReordersList` „Exceeded timeout of 5 seconds … exists == 0“ — deckt sich mit der Zusammenfassung. Briefing neu (spec_sha256 = aktueller Hash `c4975e92…`), der überholte Satz ist weg. Aber: Das Briefing nennt den Wettlauf aus AC-11 nicht unter „Kritische Anmerkungen“ und verspricht in der DoD „die gesamte Testsuite lokal grün“ — das ist auf diesem Stand wegen #115 nicht erreichbar (F008, LOW).
Code reference: RestockUITests/UITestWait.swift:30
Code reference: docs/briefings/fix-111-ui-test-flakes.md:18

5. **AC-7 (Gesamtlauf).** Selbst geprüft:
   - Beide Gesamtläufe (`-only-testing:RestockUITests`, UDID Restock-Validate, ohne Extra-Build-Settings) starteten 17:44:10 bzw. 18:10:50, nach der letzten Änderung an `QuickAddAssignmentUITests.swift` (17:43:50) → jetziger Stand. 77 Tests, 1 übersprungen (ReceiptShareExtensionTests, bekannt), kein Abbruch, kein Retry.
   - Die fünf AC-6-Tests und die Toast-Tests sind in beiden Läufen grün.
   - Lauf 1, `testAssumedQuantityIsMarkedAsAssumptionInList`: erster Test des Laufs (Kaltstart), scheitert in der **unveränderten** Zeile 60 (`waitForExistence(timeout: 15)`, „Quittenhof-Kachel nicht gefunden“), also vor jeder geänderten Zeile. In Lauf 2 grün. Die Behauptung „Hierarchie zeigt ‚Noch keine Läden‘“ ist im Text-Log nicht enthalten (`grep` 0 Treffer) — nur im xcresult, nicht im Artefakt. Einordnung als #105/Kaltstart plausibel, Produktbezug zu #111 ausgeschlossen.
   - `ReplenishmentUITests` Z. 117/183: in beiden Gesamtläufen und allein (10 Tests, 2 Fehler) rot. Gegenprobe-Lauf 37497249016: Commit `e3b4871` ist laut GitHub-Compare gegenüber `acd3be4` genau 1 Commit voraus und ändert **nur** `.github/workflows/ci.yml` → Stand `main` mit gleichem App- und Testcode; dort dieselben zwei ✗ mit wortgleichen Meldungen. `git diff acd3be4 -- SmartCart RestockUITests/ReplenishmentUITests.swift .github` ist leer. Issue #115 offen, mit Belegen und Ursachenvermutung (datumsabhängiger Seed).
   - Unit-Suite getrennt: `Executed 449 tests, with 0 failures`, `** TEST SUCCEEDED **`.
   Bewertung: Dass dieser Durchgang keinen Test bricht, ist **belegt**: alle Fehlschläge liegen in Dateien bzw. Zeilen, die er nicht anfasst, und zwei davon treten auf `main` identisch auf. AC-7 verlangt im Wortlaut aber „alle Tests grün“ — das ist auf diesem Stand **nicht erfüllt**, und ich darf eine Ausnahme nicht selbst genehmigen. Die Spec kennt keine Ausnahmeregel. Dazu kommt: #115 macht den CI-Job `ui-test` auf jedem Stand rot, auch auf dem PR dieses Durchgangs. Die Regel „Mergen sobald CI grün“ greift also nicht; die Merge-Ausnahme aus dem Memory gilt nur für reine Doku-/CI-Änderungen. → AC-7 bleibt AMBIGUOUS mit benannter, nachgewiesen unabhängiger Ausnahme. Auflösung: entweder PO-Override mit Verweis auf #115 (und auf den Kaltstart-Flake #105 in Lauf 1) oder erst #115 beheben und den Gesamtlauf wiederholen.
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:60
Code reference: Restock.xcodeproj/project.pbxproj:1078

6. **Umfang (F004).** Jetzt +173/−28 in 5 Dateien (pbxproj 4/0, AddItem 8/8, QuickAdd 6/4, ShoppingRoute 18/16, UITestWait 137/0). Unter ±250, Spec-Schätzung „ca. +110/−20“ (AC-10, Estimated Changes) weiter nicht angepasst. Bleibt LOW.
Code reference: RestockUITests/UITestWait.swift:65

**Implementierer:**
(Antworten aus der Rückmeldung des Orchestrators, vom Adversary nachgeprüft, siehe oben.) F001 zurückgesetzt; F002 in AC-11; F005 Log abgelegt; F007 Briefing neu; AC-7 zwei Gesamtläufe + Einzellauf + CI-Gegenprobe auf `main` + Issue #115; Unit-Suite getrennt grün. Zu F008 und F004 liegt keine Antwort vor.

Ergebnis Runde 3: F001, F002, F005, F007 erledigt. AC-13 bestätigt. AC-7 weiter AMBIGUOUS (Wortlaut nicht erfüllt, Unabhängigkeit belegt). Neu F008 (LOW). F004, F006 bleiben LOW.

Confirmation:
  AC: AC-13
  Code reference: RestockUITests/ShoppingRouteUITests.swift:66
  Evidence: Alle positiven Wartestellen < 20 s in den fünf AC-6-Tests und ihren Hilfen (`openedStore`, `choose`, `waitForOrder`, `openAddItemFromQuittenhof`, `openQuittenhofStoreDetail`) nutzen `UITestWait.defaultTimeout`; ausgenommen bleiben nur Kaltstart 15 s und die Ausweich-Abfrage Z. 58. `labelOf` (Toast-Tests) ist wieder im Ausgangsstand. Nachher 3: 0/150 mit Wartestellen > 5 s; Gesamtläufe 1/2 und Eigenlauf: Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md:246
  Evidence: Spec nennt Toast-Test, XCTest-Abfragegrenze und den Wettlauf frame → isHittable → tap() als offen, keine Aussage „alle Flakes behoben“. Ticket-/Abschlusstext erst in Phase 8 prüfbar; Briefing ohne Wettlauf (F008).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/QuickAddAssignmentUITests.swift:207
  Evidence: Eigenlauf Runde 3: `testUnassignedCardShowsCountAndNames` grün; Zählertext und Name wortgleich wie im Ausgangsstand.
  Status: CONFIRMED

Finding:
  ID: F003
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:60
  Description: Gesamtläufe der UI-Suite auf dem jetzigen Stand: 77 Tests, 1 übersprungen, 3 bzw. 2 Fehlschläge. `ReplenishmentUITests` Z. 117/183 scheitern immer, auch auf `main` im CI (Lauf 37497249016, Stand acd3be4 + nur ci.yml), Issue #115. In Lauf 1 scheitert zusätzlich der Kaltstart-Test in der unveränderten Z. 60 (in Lauf 2 grün).
  Spec requirement: AC-7 — gesamte UI-Suite grün, Testzahl > 0, kein Abbruch, kein Retry.
  Conflict: Wortlaut nicht erfüllt. Belegt ist aber, dass die Ursache außerhalb dieses Durchgangs liegt (kein Diff in SmartCart/ und ReplenishmentUITests.swift). Eine Ausnahme sieht die Spec nicht vor.
  Remediation: PO-Override mit Verweis auf #115/#105, oder #115 zuerst beheben und den Gesamtlauf wiederholen. Für den PR beachten: Der CI-Job `ui-test` wird wegen #115 rot sein.

Finding:
  ID: F008
  Severity: LOW
  Category: spec_violation
  Code reference: docs/briefings/fix-111-ui-test-flakes.md:18
  Description: Das Briefing verspricht in der DoD „die gesamte Testsuite lokal grün“ und nennt unter „Kritische Anmerkungen“ weder den Wettlauf frame → isHittable → tap() (AC-11) noch #115.
  Spec requirement: AC-11 — offene Grenzen in Ticket und Berichten benannt (Memory „Offene Grenze in allen Zusagen“ schließt das PO-Briefing ein).
  Conflict: Der PO bekommt eine Zusage, die auf diesem Stand nicht hält, und eine offene Grenze fehlt.
  Remediation: Briefing um beide Punkte ergänzen und neu registrieren; im Abschlussbericht/Ticket ebenso nennen.

### Runde 4
**Adversary:**
Der Orchestrator meldet: Der PO habe am 2026-10-06 per getippter Nachricht „ok-ausnahme“ die Ausnahme für AC-7 genehmigt. Die zwei `ReplenishmentUITests`-Fehlschläge (#115) und der Kaltstart-Fehlschlag (#105) sollen nicht gegen diesen Durchgang zählen. Übernahme ins Produkt erst, wenn #115 behoben und die CI grün ist.

Bewertung:
- Fachlich trage ich die Ausnahme mit. Belegt (Runde 3): Die zwei Nachkauf-Fehlschläge treten auf `main` identisch auf (CI-Lauf 37497249016, Stand `acd3be4` + nur `ci.yml`). Der Diff unter `SmartCart/`, in `ReplenishmentUITests.swift` und unter `.github` ist leer. Der Kaltstart-Fehlschlag liegt in einer unveränderten Zeile und ist in Gesamtlauf 2 grün. Alle Tests, die dieser Durchgang berührt, sind in beiden Gesamtläufen und im Eigenlauf grün.
- Die Genehmigung selbst kann ich nicht prüfen. Sie erreicht mich nur als Nachricht des Orchestrators. Im Arbeitsverzeichnis gibt es dazu keinen Eintrag: Eine Suche nach „ok-ausnahme“ in `.claude/` und `docs/` findet nichts, und das Gate-Ereignisprotokoll enthält keinen Override. Eine weitergereichte Nachricht ist kein Nachweis der PO-Zustimmung. Deshalb hake ich AC-7 **nicht** selbst ab. Ich vermerke die gemeldete Ausnahme am Checklistenpunkt. Verbindlich wird sie, wenn der PO-Override im Werkzeug erfasst ist (`workflow.py override-ambiguous` mit dieser Begründung). Das Verdict AMBIGUOUS erzwingt diesen Schritt ohnehin.
- Bedingung für die Übernahme ins Produkt: #115 behoben, CI-Job `ui-test` grün.
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:60
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:206

**Implementierer:**
(Über den Orchestrator) PO-Entscheidung „ok-ausnahme“ vom 2026-10-06 für #115/#105. F008 (Briefing) zieht der Orchestrator nach. Keine Codeänderung seit Runde 3: Die Hashes von `ShoppingRouteUITests.swift`, `AddItemQuantitySuggestionUITests.swift`, `UITestWait.swift` und `project.pbxproj` sind im neuen Stempel unverändert.
Code reference: RestockUITests/ShoppingRouteUITests.swift:101
Code reference: RestockUITests/UITestWait.swift:30
Code reference: Restock.xcodeproj/project.pbxproj:1078

Ergebnis Runde 4: Fachlich spricht nichts gegen die Ausnahme. AC-7 bleibt bis zum erfassten PO-Override offen; der Vermerk steht am Checklistenpunkt.

### Runde 5
**Adversary:**
Selbst geprüft:
1. **Override.** Der Workflow-Zustand von fix-111-ui-test-flakes (Zustandsdatei, gelesen mit dem Read-Werkzeug) enthält das Feld `adversary_ambiguous_override`. Es ist am 2026-10-06T19:24:37 gesetzt. Die Begründung lautet: „PO-Entscheidung Henning 2026-10-06 ('ok-ausnahme'): AC-7 Ausnahme — #115 ReplenishmentUITests auf main identisch rot (CI 37497249016), kein Diff in SmartCart/ oder ReplenishmentUITests.swift; Kaltstart-Flake #105. Übernahme erst nach Behebung von #115 und grüner CI.“ Inhaltlich deckt sich das genau mit den Belegen aus Runde 3. Wer den Befehl ausgelöst hat, zeigt das Feld nicht. Es ist aber der vorgesehene Weg im Werkzeug für eine PO-Ausnahme. Damit hake ich AC-7 als „belegt mit erfasster PO-Ausnahme“ ab. Das Verdict bleibt AMBIGUOUS, denn eine Ausnahme ist kein vollständiges Grün.
2. **Briefing (F008).** Das Briefing ist neu. `spec_sha256` stimmt mit der aktuellen Spec überein, die Registrierung in `po_briefing` hat den Zeitstempel 19:25:16. Die DoD verspricht kein „gesamte Testsuite grün“ mehr. Unter „Kritische Anmerkungen“ stehen jetzt #115, der Toast-Test, der Wettlauf beim Antippen und „Ziel ‚beim ersten Versuch grün‘ nicht erreicht“. → F008 erledigt. Restpunkt (LOW, kein neues Finding): Z. 27 ordnet den Wettlauf beim Antippen der „Behebung erst Durchgang 2“ zu. Laut Spec gehört zu Durchgang 2 nur der Toast-Test. Der Wettlauf ist eine offene Grenze ohne eingeplanten Durchgang (AC-11). Im Abschlussbericht/Ticket richtig formulieren.
3. **Code unverändert seit Runde 3.** Die Hashes im neuen Stempel sind für alle fünf Code-Dateien gleich.
Code reference: docs/briefings/fix-111-ui-test-flakes.md:27
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:60
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:206
Code reference: RestockUITests/ShoppingRouteUITests.swift:101
Code reference: RestockUITests/UITestWait.swift:30
Code reference: Restock.xcodeproj/project.pbxproj:1078

**Implementierer:**
(Über den Orchestrator) Override erfasst, Briefing neu erzeugt und registriert. Keine Codeänderung.

Ergebnis Runde 5: AC-7 abgehakt (PO-Ausnahme erfasst). F001, F002, F005, F007, F008 erledigt. Es bleiben F003 (durch die PO-Ausnahme gedeckt), F004 und F006 (LOW).

Confirmation:
  AC: AC-7
  Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:60
  Evidence: Gesamtläufe 1/2 auf jetzigem Stand, 77 Tests, 1 übersprungen, kein Abbruch, kein Retry. Alle Tests, die der Durchgang berührt, sind grün. Die Fehlschläge (#115 Replenishment Z. 117/183, #105 Kaltstart Z. 60 unverändert) sind nachgewiesen unabhängig und durch `adversary_ambiguous_override` (2026-10-06T19:24:37) als PO-Ausnahme erfasst.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F003: AC-7 — die gesamte UI-Suite ist auf dem jetzigen Stand nicht grün (2 Läufe: 3 bzw. 2 Fehlschläge). Nachgewiesen unabhängig von diesem Durchgang: `ReplenishmentUITests` Z. 117/183 scheitern identisch auf `main` im CI (Lauf 37497249016), Issue #115; der Kaltstart-Fehlschlag in Lauf 1 liegt in einer unveränderten Zeile und ist in Lauf 2 grün. Die Spec sieht keine Ausnahme vor; über die Ausnahme muss der PO entscheiden (Override mit Verweis auf #115), oder #115 wird zuerst behoben.

Offene LOW-Findings: F004 (Umfang +173/−28 statt ca. +110/−20, unter dem Limit), F006 (Ausweich-Abfrage `choose`, Durchgang 3), F008 (Briefing ohne Wettlauf und ohne #115-Vorbehalt).
Erledigt seit Runde 2: F001, F002, F005, F007.

Proven points: 12/13 (AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-8, AC-9, AC-10, AC-11 [Phase-8-Vorbehalt], AC-12, AC-13); AMBIGUOUS: AC-7
Tests: 18 passed, 0 failed, 0 übersprungen (adversary-test-output.txt, Runde 3); Gesamtläufe UI 77 Tests / 1 übersprungen / 3 bzw. 2 Fehlschläge (unabhängig, #115/#105); Unit 449 / 0 Fehler
Recommendation: AC-7 per `override-ambiguous` mit Begründung „#115: ReplenishmentUITests auf main identisch rot, kein Diff in SmartCart/ oder ReplenishmentUITests.swift“ freigeben oder #115 vorziehen; F008 im Briefing nachziehen. Der PR wird im CI-Job `ui-test` wegen #115 rot sein.

Runde 4: Laut Orchestrator hat der PO am 2026-10-06 die Ausnahme für #115/#105 genehmigt („ok-ausnahme“). Fachlich trägt der Adversary sie mit (Unabhängigkeit belegt). Das Verdict bleibt AMBIGUOUS, weil AC-7 eine Ausnahme ist und kein vollständiges Grün, und weil die Genehmigung nur weitergereicht und nicht im Werkzeug erfasst ist. Abschluss über `override-ambiguous` mit dieser Begründung. Übernahme ins Produkt erst nach Behebung von #115 und grüner CI.

Runde 5: Der PO-Override ist im Werkzeug erfasst (`adversary_ambiguous_override`, 2026-10-06T19:24:37). AC-7 ist mit der PO-Ausnahme #115/#105 abgehakt, F008 ist erledigt. Proven points damit 13/13, eines davon (AC-7) über eine Ausnahme. Das Verdict bleibt AMBIGUOUS, weil die UI-Suite nicht vollständig grün ist. Übernahme ins Produkt erst nach Behebung von #115 und grüner CI. Rest LOW: F004, F006, Briefing Z. 27 (Wettlauf fälschlich Durchgang 2 zugeordnet).

## Geprüfte Dateien

- sha256:242298918596e040739db594a66dd7332e02acf06e87b374193e7b93fc0842b3  Restock.xcodeproj/project.pbxproj
- sha256:2d63afb053c3b3edeb885e28f725f96c1befd2fb509e918ec68f00bfc413e6d8  RestockUITests/AddItemQuantitySuggestionUITests.swift
- sha256:b361f1f8cf26de782a745baf68777843131e22afb9ba675aada9016edaf9f978  RestockUITests/QuickAddAssignmentUITests.swift
- sha256:8949041e7baf9138c063665f17f822c9f9f97cce90f4a91320af6f135ebb5aaf  RestockUITests/ShoppingRouteUITests.swift
- sha256:f210642ba0c852350fe7b4b12dd2cd3033bc3e3889a335005271a134a8b9125e  RestockUITests/UITestWait.swift
- sha256:17028ee437ba6384c07ced3b828f7ccf2b8ee36a3b58433cd1fc0a8aa9ae9d3e  docs/artifacts/fix-111-ui-test-flakes/ci-messlauf.yml
- sha256:18f283f8c12124fe3bff2ad6117c1c38d8f26ea656d2ea059fac9aa2bcfffdb0  docs/artifacts/fix-111-ui-test-flakes/messlauf-nachher3-langsame-abfragen.txt
- sha256:43fb215252f5703fad195bf4f65e812348ae39fbd86e65b29d652876278678fd  docs/artifacts/fix-111-ui-test-flakes/slow_queries.py
- sha256:464cd4bf3e664c49e7434dd77f46c69e0246ebf43e403a5fb00506c8d2e9b75f  docs/briefings/fix-111-ui-test-flakes.md
- sha256:c4975e928e8e460e2cb540aeec86048b909dc546bc126ffb860fc187f0f632ca  docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md

## Prüfbasis

- base: acd3be468aa585da955cecd04e360bcd1b3fbeca
- blob:e203313d14c48232d728903f22eb4ea411b8fae8  Restock.xcodeproj/project.pbxproj
- blob:b727a5b4d23ec8b764f4bbb29645b1627a31a9ad  RestockUITests/AddItemQuantitySuggestionUITests.swift
- blob:aee299e2672b4d329478c3ec1f7db1d9c5efbe5f  RestockUITests/QuickAddAssignmentUITests.swift
- blob:50d35d917e6712aca56409fbccf22f3b096aa33d  RestockUITests/ShoppingRouteUITests.swift
- blob:e354d823c4c328291d2d8178ed20c482d52498c5  RestockUITests/UITestWait.swift
- blob:6e45e585f77b39cf71c7108ac9e848494c435dda  docs/artifacts/fix-111-ui-test-flakes/ci-messlauf.yml
- blob:6ab982a64542705d153f3f19d74977bf1f69bb3e  docs/artifacts/fix-111-ui-test-flakes/messlauf-nachher3-langsame-abfragen.txt
- blob:0cbb901121b140fa74a52db029bc5a32e63713ab  docs/artifacts/fix-111-ui-test-flakes/slow_queries.py
- blob:cbd038f1cf5ca5f2f692870efaea4211277a1094  docs/briefings/fix-111-ui-test-flakes.md
- blob:0c824abe3280e43bac7cafd698d7043e8dc901ca  docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
