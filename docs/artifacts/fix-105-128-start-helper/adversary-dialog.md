# Adversary Dialog — fix-105-128-start-helper
Spec: docs/specs/ui-tests/test-105-128-durchgang-1-start-helfer.md
Datum: 2026-10-10 17:48

## Checkliste
- [x] **AC-1:** GIVEN die Gegenprobe gelingt beim ersten Start, WHEN der Helfer läuft, THEN startet er die App genau einmal, beendet sie nicht, gibt keine Messmeldung aus und kehrt ohne feste Wartezeit zurück (Beweis: Hilfstest T1 mit Zählern für `launch`, `terminate`, `report`).
- [x] **AC-2:** GIVEN die Gegenprobe scheitert beim ersten und gelingt beim zweiten Start, WHEN der Helfer läuft, THEN erfolgt genau ein `terminate()` und ein zweites `launch()`, der Test läuft weiter, und der Helfer gibt genau eine Meldung mit dem festen Präfix `UITestLaunch: zweiter Start nötig` samt Befund des ersten Versuchs aus (Beweis: Hilfstest T2 mit Aufrufreihenfolge und Meldungstext).
- [x] **AC-3:** GIVEN die Gegenprobe scheitert auch beim zweiten Start, WHEN der Helfer läuft, THEN gibt es keinen dritten Start und der Test schlägt mit klarer Meldung fehl, die Anzahl Starts, erwartetes Element und zuletzt gesehenen Zustand nennt (Beweis: Hilfstests T3 und T4).
- [x] **AC-4:** GIVEN die Entscheidungslogik, WHEN sie geprüft wird, THEN liegt sie in einer reinen Funktion mit injizierbarem `launch`, `terminate`, `probe` und `report`, sodass T1–T4 ohne echten Simulatorstart laufen; die Hilfstests liegen in `RestockUITests/UITestWait.swift`, es gibt **keine neue Datei** und **keinen** Eintrag in `project.pbxproj` (Beweis: `git diff --stat` zeigt genau die drei Dateien aus Scope; `git diff -- Restock.xcodeproj` leer).
- [x] **AC-5:** GIVEN `AddItemQuantitySuggestionUITests`, WHEN der Durchgang umgesetzt ist, THEN startet `launchedApp()` über den Helfer mit der Kachel „Quittenhof“ als erwartetem Element, und alle Tests der Klasse prüfen inhaltlich dasselbe wie vorher (Beweis: Diff der Klasse zeigt nur Start/Kachelsuche; T5 grün).
- [x] **AC-6:** GIVEN `ShoppingRouteLearningUITests.openStore`, WHEN der Durchgang umgesetzt ist, THEN ersetzt der Helfer die eigene Wiederholung (kein `terminate()`/zweites `launch()` mehr im Testcode der Klasse außerhalb des Helfers und der unveränderten Aufräum-/Neustart-Stellen `tearDown()`/`relaunchAfterQuietPeriod`), Kachel „Wegeladen“ bleibt das erwartete Element, und die Tests prüfen inhaltlich dasselbe wie vorher (Beweis: Diff der Klasse; T5 grün).
- [x] **AC-7:** GIVEN der Stand `main` vor der Änderung, WHEN der volle UI-Lauf auf `Restock-Validate` (`-only-testing:RestockUITests`, ohne `-retry-tests-on-failure`/`-test-iterations`) läuft, THEN ist der erste Test rot (Kachel „Quittenhof“ fehlt), und das Protokoll belegt Testzahl, Fehlerzeile und Startargumente bzw. den Zustand der Startseite; Beleg unter `docs/artifacts/fix-105-128-start-helper/` (Reproduktion zuerst; die Zusage „4 von 4“ aus #128 wird erneut gezeigt, nicht nur zitiert). Zeigt der Lauf wider Erwarten grün, wird das offen benannt, die Reproduktion wiederholt und nicht abgeschlossen, bevor der Fehlfall gezeigt ist.
- [ ] **AC-8:** GIVEN der Stand mit Änderung, WHEN der volle UI-Lauf auf `Restock-Validate` dreimal nacheinander (nie parallel) läuft, THEN sind alle drei Läufe grün; je Lauf belegt: `Executed N tests` mit N > 0 und gleich der Sollzahl der Suite, 0× „Restarting after unexpected exit“, kein `-retry-tests-on-failure`/`-test-iterations` im Aufruf (Memory „Null-Test-Lauf ist kein Grün“), und die Zahl der Meldungen `UITestLaunch: zweiter Start nötig` je Lauf ist ausgewiesen (auch 0 ist ein Messwert). Belege unter `docs/artifacts/fix-105-128-start-helper/`. Der Gesamtlauf ist zugleich der Durchlauf der App im Simulator mit dem Stand, den Henning bekommt.
- [x] **AC-9:** GIVEN die Unit-Suite (`RestockTests`), WHEN sie auf `Restock-Validate` läuft, THEN ist sie grün mit Testzahl > 0 und ohne Abbruch.
- [x] **AC-10:** GIVEN der Diff dieses Durchgangs, WHEN er gegen den Tip-Commit geprüft wird, THEN gibt es keine Änderung unter `SmartCart/` (App-Verhalten unverändert), der Umfang liegt bei 3 Testdateien (plus Spec und Belege unter `docs/`) und ca. +90/−20 LoC, `CLAUDE.md` ist unverändert, die `cleaner.launch()`-Aufräumstarts sind unverändert.
- [ ] **AC-11:** GIVEN der Abschluss des Durchgangs, WHEN Ticket-Kommentare und Berichte formuliert werden, THEN nennen sie ausdrücklich: Die Ursache des leeren ersten Starts ist unbekannt, die Wiederholung ist Abhilfe, nicht Erklärung; sechs weitere gesäte Klassen sind erst in Durchgang 2/3 geschützt; ein Fehlstart in Aufräumstarts wird nicht abgefangen; es gibt keine Aussage „alle gesäten Tests starten zuverlässig“. #105 und #128 bleiben bis Durchgang 3 offen. Der Kommentar enthält die Messzahlen zum zweiten Start aus AC-8.

## Dialog

### Runde 1
**Adversary:** Spiegeln T1-T4 nur die Implementierung? Mutationsgedanke: Meldung schon beim ersten Treffer (T1 faengt: reports leer), Meldung doppelt (T2: count==1), dritter Start (T3: calls exakt), terminate im Erfolgsfall (T1: calls == [launch, probe]). Fall "Probe liefert nur beim zweiten Mal true" ist T2 selbst. Luecke: `UITestLaunch.start` (XCTFail, NSLog, Closures) hat keinen eigenen Test, nur `run`/`failureMessage`. Zusatzwartezeit im Erfolgsfall? `start` ruft nach `run` nichts weiter; Probe nutzt waitUntilHittable ohne feste Wartezeit bei Erfolg. Worst Case (beide Starts leer) ca. 2x20 s plus Starts, vertretbar.
Code reference: RestockUITests/UITestWait.swift:69
**Implementierer:** `run` ist rein; T1-T4 pruefen die Aufrufreihenfolge der Closures. Eigener Wiederholungslauf der Hilfstests: UITestLaunchTests (4) und UITestWaitTests (6) = 10 Tests, 0 Fehler, TEST SUCCEEDED (adversary-test-output.txt). Die `start`-Huelle wird in den Vollaeufen real durchlaufen (Meldung dort ausgegeben).

**Adversary:** AC-5/AC-6 Diff: AddItemQuantitySuggestionUITests startet `launchedApp()` ueber den Helfer, Kachelsuche in `quittenhofTile` ausgelagert und in `openQuittenhofStoreDetail` wiederverwendet, Assertions unveraendert. ShoppingRouteLearningUITests.openStore: eigene Wiederholung ersetzt, danach bleiben waitForExistence 15 und isHittable-Pruefung unveraendert. Verbleibende terminate/launch: nur cleaner (Zeile 33/34) und `app.terminate()` Zeile 60 (relaunchAfterQuietPeriod, laut Spec erlaubt). AddItem: nur cleaner (Zeile 44/45). Kein Test prueft weniger.
Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:54
Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:40
**Implementierer:** Bestaetigt; keine weiteren Aufrufe ausserhalb Helfer und Aufraeumstellen.

### Runde 2
**Adversary:** AC-7: Lauf 1+2 gruen (78 Tests), Lauf 3 unter kuenstlicher CPU-Last rot mit der Meldung aus #128 (Quittenhof-Kachel), zweiter Fehler testAppLaunchesToHomeScreen ausserhalb Scope, offen benannt. Der Fehler tritt also nicht von selbst auf, Startargumente wurden nicht gemessen, Ursache unbewiesen; die Spec-Klausel (offen benennen) ist erfuellt, "erster Test rot" nur unter Last.
Code reference: RestockUITests/UITestWait.swift:98
**Implementierer:** Ehrlich dokumentiert (reproduktion-zusammenfassung.md); der Nachher-Lauf zeigt das Messdatum "erster Versuch: exists=false frame=(0,0,0,0)" in 3 von 4 Laeufen.

**Adversary:** AC-8 ist woertlich NICHT erfuellt. Lauf 2 rot: ReplenishmentUITests.testAlsoDuePlusAddsItem Zeile 212, `.exists` ohne Wartezeit; Helfermeldung 0x, also kein Helferneustart beteiligt; Klasse nicht umgestellt. Unter-Last-Lauf rot: QuickAddAssignmentUITests.tearDown Zeile 28, `cleaner.terminate()` "Failed to terminate"; Klasse nutzt den Helfer nicht, die einzige Helfermeldung dieses Laufs stammt aus einem frueheren Test einer anderen Klasse. Dass der Helfer (zusaetzlicher Neustart) das Terminate-Verhalten spaeter beeinflusst, ist nicht belegt und nicht ausgeschlossen; vor der Aenderung trat "Failed to terminate" in keinem Vorher-Log auf (0 Treffer), allerdings lief dort auch nur ein Lauf unter Last. Nachkauf-Tests sind laut Memory (#111/#115) ein bekannter Zeitflake. Nicht erfuellt ist ausserdem "dreimal nacheinander gruen": gruen, rot, gruen.
Code reference: RestockUITests/ReplenishmentUITests.swift:212
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:28
**Implementierer:** Beide Fehler in nicht umgestellten Klassen, kein Fehlstart, 0x "Restarting after unexpected exit", 82 Tests je Lauf, kein Retry-Flag; der Helfer fing in 3 Laeufen den leeren ersten Start auf, der vorher den ersten Test rot gemacht haette. Wortlaut AC-8 verfehlt, ehrlich ausgewiesen.

**Adversary:** AC-9: unit-suite-output.txt "Executed 478 tests, with 0 failures", TEST SUCCEEDED. AC-10: 3 Testdateien (+66/-10), keine Aenderung unter SmartCart/, CLAUDE.md oder pbxproj (git status), Cleaner-Starts unveraendert. AC-11: Abschluss, offen, kein Defekt.
Code reference: RestockUITests/UITestWait.swift:199
**Implementierer:** Bestaetigt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

AMBIGUOUS

Findings:
- F001 (MEDIUM, spec_violation): AC-8 "dreimal nacheinander gruen" nicht erfuellt (gruen, rot durch ReplenishmentUITests.testAlsoDuePlusAddsItem, gruen; Unter-Last-Lauf rot durch QuickAddAssignmentUITests tearDown). Code reference: RestockUITests/ReplenishmentUITests.swift:212. Einordnung (nicht umgestellte Klassen, Helfer nicht beteiligt) plausibel, aber nicht bewiesen; PO muss die Abweichung akzeptieren.
- F002 (LOW, edge_case): Fehlschlag von cleaner.terminate() kann in den umgestellten Klassen identisch auftreten und wird nicht abgefangen; muss in AC-11 als offene Grenze stehen. Code reference: RestockUITests/QuickAddAssignmentUITests.swift:28.
- F003 (LOW, edge_case): `UITestLaunch.start` (XCTFail, Meldungsweg) ohne eigenen Test. Code reference: RestockUITests/UITestWait.swift:98.
- F004 (LOW, spec_violation): AC-7 zeigt den Fehlfall nur unter kuenstlicher Last. Code reference: RestockUITests/ShoppingRouteLearningUITests.swift:40.
- AC-11 offen (Abschluss), kein Defekt.

## Geprüfte Dateien

- sha256:3600b9811e257f5fe11ced7895f0c25a3c693fcf0c4a2544621b4211e38faaa0  RestockUITests/AddItemQuantitySuggestionUITests.swift
- sha256:343c4a8a9f670f9e52755dc7af20e8e46a61949c9078dc6f891e9fe7afcfd86b  RestockUITests/QuickAddAssignmentUITests.swift
- sha256:be7b704eba5f5ee272c226250ee5c569b0344f22fffa51eb01e34051ebccb6c7  RestockUITests/ReplenishmentUITests.swift
- sha256:b0ac3fd504f4074cde736306df2889db9ee359e9ef4f64429a1b8633fd2b8d5f  RestockUITests/ShoppingRouteLearningUITests.swift
- sha256:d172605dbc6452da9897359908d2b2e55fb6b54d48db1aba8a79e5bd904a0bf2  RestockUITests/UITestWait.swift

## Prüfbasis

- base: c3329ab9cb484cc95a3d35b225c96bb76dfebcb6
- blob:dcfc3fe3149e6af1bda73efb8519f8cf047a78f6  RestockUITests/AddItemQuantitySuggestionUITests.swift
- blob:ddd685912a2574f4b83e94b6634e168594adf973  RestockUITests/QuickAddAssignmentUITests.swift
- blob:026cd235b178bd9a67ed824bc58d5dcbbc041452  RestockUITests/ReplenishmentUITests.swift
- blob:67a965c9847df4d4cb6a90f04188f87fcdd733be  RestockUITests/ShoppingRouteLearningUITests.swift
- blob:9c45abb8230f0aa10d3210cba41cf66e94571d04  RestockUITests/UITestWait.swift
