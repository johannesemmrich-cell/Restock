# Adversary-Dialog: test-98-durchgang-4-sync (Issue #98, Durchgang 4)

### Runde 1

Eigener Lauf: `-only-testing:RestockTests/SharedStoreMergeTests` auf Restock-Validate: 15 Tests, 0 Fehler, TEST SUCCEEDED.
Diff gegen Basis 3dc7844 (= origin/main): Produktcode nur `SharedStoreService.swift`, 2 Zeilen `private` entfernt (Zeilen 83, 134); `SyncCoordinator.swift`, `SmartCartApp.swift` unveraendert.

Finding:
  id: F001
  severity: MEDIUM
  category: spec_violation
  description: Umfang weit ueber Zusage. Numstat gegen 3dc7844: Testdatei +423, QuickAddAssignmentUITests +17/-11, pbxproj +4, SharedStoreService +2/-2 = ca. +446/-13 (ca. 460 LoC). Spec/Briefing nannten ca. +230 (Merge-Tests ~170), Limit +-250. Briefing sagt "bei Zeilenueberschreitung Rueckmeldung"; kein Beleg einer solchen Rueckmeldung. Dateizahl 4 Code-Dateien (nicht 6), das ist unkritisch.
  evidence: git diff --numstat 3dc7844c591eab0e4d12c5902750586dfe836c85 (RestockTests/SharedStoreMergeTests.swift 423 0); docs/briefings/test-98-durchgang-4-sync.md:26
  remediation: Ueberschreitung (ca. 2x) im PO-Briefing/Abschluss ausdruecklich offenlegen; AC-18 mit Ist-Zahlen belegen.
Code reference: RestockTests/SharedStoreMergeTests.swift:1

Finding:
  id: F002
  severity: MEDIUM
  category: edge_case
  description: AC-14/T22 verlangt drei Wiederholungen der geaenderten UI-Tests. nachschaerfen-1-2.md nennt fuer testChangeStoreMovesItemAndRemembersCorrection "im Klassenlauf gruen, im Einzellauf 1 von 3" (mehrdeutig: 1 gruen von 3 oder 3 gruen?). Nur fuer testQuantityAndUnitShownInList sind 3 von 3 Laeufen belegt. Der Seed-Flake beim ersten App-Start ist ehrlich dokumentiert (Gegenprobe mit unveraendertem Bestandstest: Lauf 1 rot, 2 und 3 gruen; geprueft in gegenprobe-bestandstest-1..3.txt), erklaert aber nicht, ob die Wiederholungen des geaenderten Tests gruen waren.
  evidence: docs/artifacts/test-98-durchgang-4-sync/nachschaerfen-1-2.md (Abschnitt Nachschaerfen 1); gemeinsamer-lauf.md ("Je Klasse ein Lauf")
  remediation: Drei Laeufe von testChangeStoreMovesItemAndRemembersCorrection mit Ergebniszeilen vorlegen (Flake-Faelle als solche mit Verweis auf #111 kennzeichnen) oder die Formulierung praezisieren.
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:283

Finding:
  id: F003
  severity: LOW
  category: anti_pattern
  description: Zwei Aufraeum-Tests sind schwach. (1) testTearDownLeavesNoSyncKeys ruft `removeSyncKeys()` selbst auf und prueft damit den Helfer, nicht das tatsaechliche `tearDown()`; entfiele der Aufruf in tearDown, bliebe der Test gruen. (2) testApplyWithoutShareIDWritesNoWatermark filtert Schluessel auf `lastSync_` UND `store.id.uuidString`; `lastSync_`-Schluessel enthalten aber die shareID, nie die store.id; die Assertion ist damit leer (immer wahr), auch bei einer Mutation, die ohne shareID schreibt. Der Fall "Laden ohne shareID" (AC-6) ist also nicht wirksam belegt; er ist auch durch keine Mutationsprobe gedeckt.
  evidence: RestockTests/SharedStoreMergeTests.swift:196 (Filter), :335 (Selbstaufruf)
  remediation: (2) Schluesselmenge vor/nach `apply` vergleichen (Snapshot aller `lastSync_*`-Keys) oder Mutationsprobe zeigen; (1) Nachweis ueber zweiten Testlauf, der prueft, dass nach dem Lauf der Klasse keine `UT-`-Schluessel in UserDefaults stehen, oder Eingestaendnis, dass es nur den Helfer prueft.
Code reference: RestockTests/SharedStoreMergeTests.swift:196
Code reference: RestockTests/SharedStoreMergeTests.swift:335

Finding:
  id: F004
  severity: LOW
  category: edge_case
  description: P6 prueft Kategorien/Zuordnungen/Preise nur mit disjunkten Schluesseln (Vereinigung), nicht "neuerer Stand gewinnt je Schluessel" im Push-Merge, und bei Preisen nur `prices`, nicht Datum/Einheit. Eine Mutation, die `StoreCategories.merge` im Push durch eine reine Vereinigung ersetzt, bliebe gruen. AC-10 verlangt nur "zusammengefuehrt und zurueckgeschrieben", die Regeln selbst stehen in StoreCategoriesTests/LearnedPriceSyncTests; deshalb nur LOW. S2-S4 (apply) pruefen beide Richtungen korrekt (A: Remote neuer gewinnt, B: lokal neuer bleibt; milch/brot analog).
  evidence: RestockTests/SharedStoreMergeTests.swift:281-301; SmartCart/Services/SharedStoreService.swift:92
  remediation: Ein gemeinsamer Schluessel mit unterschiedlichen Datumsangaben in P6 ergaenzen (je Richtung) oder die Grenze im Kommentar benennen.
Code reference: SmartCart/Services/SharedStoreService.swift:92
Code reference: RestockTests/SharedStoreMergeTests.swift:281

Finding:
  id: F005
  severity: LOW
  category: spec_violation
  description: Abweichung 15 statt 14 Tests (Spec-Tabelle T1-T14; zusaetzlich testApplyWithoutShareIDWritesNoWatermark) ist in Spec/Artefakten nicht als Abweichung festgehalten, nur beilaeufig als "15 Tests" in mutationsproben.md. Der Zusatztest ist zudem der leere aus F003.
  evidence: docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md:255-268; docs/artifacts/test-98-durchgang-4-sync/mutationsproben.md:5
  remediation: Abweichung im Abschluss/PO-Bericht benennen oder Spec-Tabelle nachziehen (alle Stellen per grep).
Code reference: RestockTests/SharedStoreMergeTests.swift:192

Finding:
  id: F006
  severity: LOW
  category: edge_case
  description: S9 belegt nur die Reihenfolge "Wasserstand erst nach Beginn des Speicherns" (willSave-Beobachter), nicht das Verhalten bei fehlschlagendem Save. Das ist in mutationsproben.md ehrlich benannt, auch dass Probe (c1) mit der ersten Testfassung NICHT gefangen wurde und erst (c2) rot wurde. Mutation (c2) schob markSynced hinter den `guard`, nicht unmittelbar vor `try context.save()`; die willSave-Pruefung faengt aber beides, solange der Aufruf vor dem Speichern steht. Akzeptabel; Grenze muss in jede Zusage.
  evidence: docs/artifacts/test-98-durchgang-4-sync/mutationsproben.md (Zeilen (c1)/(c2), Abschnitt "Grenze"); SmartCart/Services/SyncCoordinator.swift:300-309
  remediation: Grenze in PO-Bericht uebernehmen.
Code reference: SmartCart/Services/SyncCoordinator.swift:300
Code reference: RestockTests/SharedStoreMergeTests.swift:171

### Pruefung je AC (Runde 1)

Code reference: SmartCart/Services/SharedStoreService.swift:83
Code reference: RestockTests/SharedStoreMergeTests.swift:47
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:283

- AC-1 AKZEPTIERT: S1 prueft Duplikat und leeren Namen (:47-52).
- AC-2 AKZEPTIERT: beide Richtungen fuer Kategorien, Zuordnungen, Preise (:54-92); Einschraenkung F004 betrifft nur Push (AC-10).
- AC-3 AKZEPTIERT: Mutation (b) rot (nur testApplyDeletesOnlyTombstonedItems); Abwesenheit loescht nicht belegt (:94-101).
- AC-4 AKZEPTIERT: aelter aendert nichts, neuer ueberschreibt alle 12 Felder; Mutation (a) rot (12 Fehler).
- AC-5 AKZEPTIERT: lokal gemerkte Kategorie "Kuehltheke" vs Absender "Milchprodukte" (:132-151).
- AC-6 NACHFRAGE: S8-nil-Fall und Reihenfolge belegt, Orphan-Fall belegt; "Laden ohne shareID" nur durch leere Assertion (F003). Beweisforderung: Test, der bei Schreiben ohne shareID rot wird (Mutation zeigen).
- AC-7 AKZEPTIERT: P1 beide Einseitenfaelle, P2 beide Richtungen; Mutation (d) rot.
- AC-8 AKZEPTIERT: Vereinigung exakt geprueft, beide Kreuzfaelle (lokal vermerkt/remote steht, remote vermerkt/lokal steht), geschriebener JSON-Stand geprueft (:234-248).
- AC-9 AKZEPTIERT: Remote + lokal + eigener Name, leer gefiltert, sortiert, im Record geschrieben (:250-262).
- AC-10 AKZEPTIERT mit Vorbehalt F004: Besitzer neu/bestehend belegt; Metadaten belegt; Merge-Regeln im Push nur als Vereinigung.
- AC-11 AKZEPTIERT: Kommentar :306-309 benennt `>` vs `>=` und Nicht-Beschluss; beide Richtungen im Test (:310-323).
- AC-12 AKZEPTIERT: a, b, c (nach Nachschaerfen), d mit Testnamen und Zeilen belegt, Rueckdrehen per Diff bestaetigt (SyncCoordinator unveraendert). Ehrlich: c1 nicht gefangen.
- AC-13 NACHFRAGE: eigene shareID je Test und tearDown vorhanden, Lauf in Reihenfolge grün; aber Nachweis "nach dem Lauf keine Schluessel" ist schwach (F003). Beweisforderung: Pruefung nach Klassenlauf (UserDefaults auf `UT-`-Schluessel) und Lauf in umgekehrter/zufaelliger Reihenfolge (z. B. -test-iterations/-parallel-testing off mit Randomisierung).
- AC-14 NACHFRAGE: Code stimmt (Probe und Gegenprobe ueber dieselbe Sammlung `dialogButtons`, CONTAINS mit Kachel-Ausschluss; Kachel-Label beginnt laut `tile()` mit "Name," also gueltig; RED belegt in nachschaerfen-1-2.md). Offen: drei gruene Laeufe (F002).
- AC-15 AKZEPTIERT: RED ueber Fehllenkung belegt, 3 von 3 gruen; Suche an `listRow("Hackfleisch")` gebunden (:341-346).
- AC-16 AKZEPTIERT: roter Lauf mit Absturzbericht und Meldungszeile (SmartCartApp.swift:182), Rueckdrehen per leerem Diff gegen origin/main, gruener Lauf danach; `git diff origin/main -- SmartCart` zeigt nur SharedStoreService.
- AC-17 AKZEPTIERT: eigener Diff: genau 2 Zeilen `private` entfernt (Zeilen 83, 134), sonst nichts im Produktcode.
- AC-18 NACHFRAGE: Ist ca. +446/-13 statt ca. +230 (F001); Beweisforderung: Offenlegung im PO-Bericht mit Ist-Zahlen, inkl. Abweichung 15 statt 14 Tests (F005). Dateizahl ist 4 Code-Dateien, nicht 6 (SmartCartApp/DataResetUITests im Endstand nicht angefasst).
- AC-19 NACHFRAGE: Spec und Testdatei-Kommentar (:11-14) nennen die Grenze vollstaendig; Ticketkommentar in #98 liegt noch nicht vor. Beweisforderung: Kommentar in #98 (Link), der die Grenze samt Begruendung enthaelt.

Zwischenverdikt Runde 1: AMBIGUOUS (kein CRITICAL/HIGH; AC-6, AC-13, AC-14, AC-18, AC-19 mit offener Beweisforderung; 14 von 19 ACs akzeptiert (AC-10 mit Vorbehalt F004)).

### Runde 2

Eigene Nachprüfung: Klassenlauf SharedStoreMergeTests dreimal nacheinander. Lauf 1: TEST FAILED (Ursache nicht im Detail ausgewertet, nur die Zusammenfassung wurde gelesen; wahrscheinlichster Grund: Rest-Schluessel `lastSync_UT-NOSHARE` aus der Mutationsprobe des Entwicklers im Simulator, den `setUp` per Absicht meldet und dann entfernt, siehe setup-faengt-mutationsreste.txt; nicht belegt). Lauf 2 und 3: 15 Tests, 0 Fehler, TEST SUCCEEDED. Produktcode-Diff gegen HEAD: nur SharedStoreService.swift (2 Zeilen). Numstat gegen 3dc7844: Testdatei +479, QuickAdd UITests +17/-11, SharedStoreService +2/-2.

Code reference: SmartCart/Services/SharedStoreService.swift:83
Code reference: RestockTests/SharedStoreMergeTests.swift:200
Code reference: RestockTests/SharedStoreMergeTests.swift:32
Code reference: RestockTests/SharedStoreMergeTests.swift:291
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:283

- F003a / AC-6 AKZEPTIERT: Vorher/nachher-Vergleich aller `lastSync_*` (:200-211); Mutation `shareID ?? "UT-NOSHARE"` macht den Test rot (mutation-f003a-red.txt, Zeile 210 mit Schluessel `lastSync_UT-NOSHARE`).
- F003b / AC-13 AKZEPTIERT: `setUp` und `tearDown` pruefen echte Reste (:32, :46); Mutation (tearDown-Aufraeumen entfernt) rot mit 10 `error:`-Zeilen in mutation-f003b-red.txt (Koordinator nennt 6 Fehler; Zaehlung abweichend, weil Folgetests durch Reste auch rot werden, Wirkung unstrittig). Zufallsreihenfolge (seed 4242, seed 7 doppelt) gruen belegt.
- F004 / AC-10 AKZEPTIERT: P6 prueft gemeinsame Schluessel mit lokal-neuer und server-neuer Seite fuer Kategorien, Zuordnungen und Preise samt Datum und Einheit (:291-343). Gelesen, Erwartungen konsistent mit der Merge-Regel.
- F006 AKZEPTIERT: Grenze benannt (Reihenfolge, kein echtes Fehlschlagen von save).
- F002 / AC-14 AKZEPTIERT mit Vorbehalt: Ehrliche Zaehlung 2 von 3 je Test; die roten Laeufe scheitern vor den geaenderten Zeilen (Tastaturfokus im unveraenderten Helfer bzw. Seed-Flake, dieselbe Flake beim unveraenderten Bestandstest). Einordnung #111. Der Vorbehalt: der Flake macht die Suite nicht stabiler, gehoert in den PO-Bericht und darf nicht als "3 von 3 gruen" zugesagt werden.
- F001 / AC-18 AKZEPTIERT unter Bedingung: Ist rund +500 Zeilen (Testdatei +479) gegen Zusage ca. 230 und Limit +-250. Die Zusage ist verfehlt; der PO-Bericht muss das mit den Ist-Zahlen zur Entscheidung vorlegen (zugesagt vom Koordinator). 15 statt 14 Tests (F005) ebenfalls dort offenlegen; Zusatztest ist jetzt wirksam.
- AC-19 AKZEPTIERT mit Vorbehalt: Testdatei-Kommentar (:11-14) und Spec nennen die Grenze; der Ticketkommentar in #98 steht noch aus (laut Koordinator in /70-deploy nach dem Merge). Muss dort erfolgen, vorher nicht abgeschlossen.
- Neuer Produktbefund (CloudPreferencesSync spiegelt shareID_* in den iCloud-Schluesselspeicher, aufgehobene Teilung koennte wiederkommen): nicht in #98 behoben, Folge-Ticket ist angemessen; nicht von mir geprueft.
- Rest-Hinweis zur Testhygiene: Lauf 1 meiner Wiederholung schlug einmal fehl. Ob ein Rest-Schluessel aus der Mutationsprobe die Ursache war, ist nicht bewiesen. Vor dem Abschluss einen sauberen Lauf (nach Neustart bzw. Aufraeumen des Simulators) in den Nachweis legen.

Endverdikt Runde 2: AMBIGUOUS. Begruendung: Alle inhaltlichen Findings sind behoben und durch Mutationsproben belegt, der Produktcode-Diff ist 2 Zeilen. Offen sind nur Dinge, die ein Mensch bzw. spaetere Phase entscheiden muss: (1) PO-Freigabe der Umfangsueberschreitung (~+500 statt ~+230), (2) Ticketkommentar #98, (3) UI-Flake-Einordnung #111 im PO-Bericht, (4) ein ungeklaerter einzelner Rotlauf der Unit-Klasse in meiner Nachpruefung. Kein Punkt zeigt einen Fehler im Produkt oder in den Tests.

Nachtrag Runde 2 (Koordinator, zu Rest-Hinweis/Punkt 4): Klassenlauf SharedStoreMergeTests vier Mal nacheinander auf dem aufgeräumten Simulator Restock-Validate (klassenlauf-runde2-1..4.txt): jeweils Executed 15 tests, 0 failures, TEST SUCCEEDED. Der einzelne Rotlauf der Adversary-Nachprüfung ist damit nicht reproduziert; wahrscheinlichste Ursache bleibt der von setUp absichtlich gemeldete Rest-Schlüssel aus der Mutationsprobe, nicht bewiesen. Als ungeklärt festgehalten.

### Abschlussliste Runde 2

Übertragung der Runde-2-Entscheidungen des Adversary in Checklistenform (Koordinator, keine neue Bewertung). Vorbehalte stehen an der jeweiligen Zeile.

- [x] AC-1 bis AC-5 (apply: Mitglieder, Kategorien/Zuordnungen/Preise, Löschvermerke, Last-write-wins, Neuanlage) akzeptiert
- [x] AC-6 akzeptiert nach Nachbesserung F003a (wirksamer Test, Mutation rot); Grenze: Reihenfolge belegt, kein echtes Fehlschlagen von save (F006)
- [x] AC-7 bis AC-9 (Push-Merge: Pull-vor-Push, Tombstones, Mitglieder) akzeptiert
- [x] AC-10 akzeptiert nach Nachbesserung F004 (gemeinsame Schlüssel, beide Richtungen)
- [x] AC-11 (Gleichstand als Ist-Verhalten) akzeptiert
- [x] AC-12 (Mutationsproben a, b, c, d, jeweils zurückgedreht) akzeptiert
- [x] AC-13 akzeptiert nach Nachbesserung F003b (setUp/tearDown prüfen echte Reste, Zufallsreihenfolgen grün); Vorbehalt: ein Rotlauf der Adversary-Nachprüfung nicht reproduziert, vier saubere Läufe grün
- [x] AC-14 akzeptiert mit Vorbehalt: ehrliche Zählung 2 von 3 je Test, rote Läufe scheitern vor den geänderten Zeilen, Flake auch beim unveränderten Bestandstest (#111)
- [x] AC-15 und AC-16 akzeptiert
- [x] AC-17 akzeptiert (Produktcode-Diff genau zwei Zeilen)
- [x] AC-18 nur unter Bedingung: Ist-Umfang rund +500 Zeilen statt ca. 230 (Limit ±250), 15 statt 14 Tests; Entscheidung liegt beim PO
- [x] AC-19 nur mit Vorbehalt: Testdatei-Kommentar und Spec nennen die offene Grenze; Ticketkommentar in #98 steht noch aus

## Verdict: AMBIGUOUS

## Geprüfte Dateien

- sha256:f4a62023a3f0b58e8076ddcd0d924688ace655a30c78dcbcc89c471b61ecc68f  RestockTests/SharedStoreMergeTests.swift
- sha256:fbf9d65c35be07e180ee2e5a5ddc200cc8cd0c6bd53337f34c65865a700744e4  RestockUITests/QuickAddAssignmentUITests.swift
- sha256:e91284248cb82ac88a899dd0dc3eda3c119f235445fa532b6f0a9286c90c651f  SmartCart/Services/SharedStoreService.swift
- sha256:edb9c408f27c78cccd5f64fe413ee9d4e4ec947f00ffddc24722a38ac72eb9c4  SmartCart/Services/SyncCoordinator.swift
