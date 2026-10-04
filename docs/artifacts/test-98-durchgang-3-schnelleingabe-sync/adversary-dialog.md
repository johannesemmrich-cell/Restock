# Adversary-Dialog: Issue #98 Durchgang 3

Workflow: test-98-durchgang-3-schnelleingabe-sync
Beweise: test-green-output.txt (14 Tests, 0 Failures; nur DataResetUITests und QuickAddAssignmentUITests), test-red-output.txt (2 Failures vor DEBUG-Zweig), release-build-check.txt.

### Runde 1

Code reference: SmartCart/SmartCartApp.swift:69
AC-10: Testzweig nur in `#if DEBUG`, Release hat nur `let forceContainerFailure = false`. release-build-check.txt: 0 Treffer auf die drei neuen Namen, Kontrolle `smartcart.dataResetOccurred` 2 Treffer. AKZEPTIERT.

Code reference: SmartCart/SmartCartApp.swift:85
Marker wird vor deleteStoreFiles (Z. 88) angelegt (Z. 85) und danach per precondition geprueft (Z. 90), nur mit Argument. AKZEPTIERT, Einschraenkung F003.

Code reference: SmartCart/SmartCartApp.swift:33
clearDataResetForUITestsIfNeeded steht im defer von init() und greift auch bei erfolgreichem make(). AKZEPTIERT.

Code reference: SmartCart/SmartCartApp.swift:138
deleteStoreFiles unveraendert und private; make() und Services im Diff-Stat unveraendert. AKZEPTIERT.

Code reference: RestockUITests/QuickAddAssignmentUITests.swift:97
AC-1: Assertion auf Listenzelle nach Oeffnen des Ladens, nicht auf den Toast; Gegenprobe dm. green-output Z. 470 passed. AKZEPTIERT.

Code reference: RestockUITests/QuickAddAssignmentUITests.swift:116
AC-2: Dialog-Knopf dm, danach Liste dm positiv und Lidl negativ. AKZEPTIERT, F002.

Code reference: RestockUITests/QuickAddAssignmentUITests.swift:153
AC-3: erneutes Eintippen: target nennt dm, reason "frueher in diesen Laden verschoben", Gegenprobe Joghurt nach Lidl. AKZEPTIERT.

Code reference: RestockUITests/QuickAddAssignmentUITests.swift:170
AC-4: Zelle Hackfleisch, Text "500 gramm" (ItemRow Z. 99), "ca. "-Variante und Rohtext negativ. AKZEPTIERT, F004.

Code reference: RestockUITests/DataResetUITests.swift:79
AC-5/6/7: Vorlauf-Kacheln muessen stehen, Alert, OK, Feld, beide Kacheln weg, dritter Start ohne Alert. RED/GREEN-Paar: red-output Z. 259 und 429 (2 Failures), green 14 Tests ohne Failure. Kein Leerlauf: ohne echtes Loeschen blieben die Laeden. AKZEPTIERT.

Code reference: RestockUITests/DataResetUITests.swift:26
AC-9: beide tearDown starten Clear-Argumente; 12 QuickAdd-Tests gruen nach D1/D2. Luecke F001.

Code reference: RestockUITests/DataResetUITests.swift:11
AC-12: "OFFENE GRENZE" im Klassenkommentar und in der Spec. Ticketkommentar liegt nicht im Repo. AKZEPTIERT.

### Runde 2

Code reference: RestockUITests/DataResetUITests.swift:59
#105: ohne Argument kein Alert, 20 s Wartezeit, ein Neustart; idempotent. Im Lauf nicht ausgeloest, logisch korrekt. AKZEPTIERT.

Code reference: SmartCart/SmartCartApp.swift:166
Datenverlust: nur DEBUG und nur mit Argument; auf echtem Geraet mit Argument wuerde geloescht (F005). Kein Release-Risiko.

Code reference: SmartCart/SmartCartApp.swift:30
Wechselwirkung mit Seeds: Seeds laufen im defer auf frischem Container, Clear entfernt nur den Schluessel. Kein Konflikt.

Code reference: RestockUITests/QuickAddAssignmentUITests.swift:49
Toast-Race: openStore schliesst Tastatur und prueft isHittable; nur Q2 liest die Toast-Meldung knapp nach Korrektur (3 s). F002.

Code reference: Restock.xcodeproj/project.pbxproj:1078
pbxproj: vier Registrierungsstellen vorhanden, Test kompilierte und lief. AKZEPTIERT.

AC-Tabelle:
- AC-1 AKZEPTIERT (QuickAddAssignmentUITests.swift:97)
- AC-2 AKZEPTIERT (QuickAddAssignmentUITests.swift:116)
- AC-3 AKZEPTIERT (QuickAddAssignmentUITests.swift:153)
- AC-4 AKZEPTIERT (QuickAddAssignmentUITests.swift:170)
- AC-5 AKZEPTIERT (DataResetUITests.swift:92)
- AC-6 AKZEPTIERT (DataResetUITests.swift:101)
- AC-7 AKZEPTIERT mit F003 (SmartCartApp.swift:177)
- AC-8 AKZEPTIERT: nur Launch-Argumente und Seed, kein Handsetzen (DataResetUITests.swift:45)
- AC-9 NACHFRAGE (F001)
- AC-10 AKZEPTIERT (SmartCartApp.swift:69)
- AC-11 NACHFRAGE (F006): 4 Dateien ok, Regeldienste und Texte unveraendert, aber ca. 313 Zeilen (129+136+43+4) ueber Limit 250.
- AC-12 AKZEPTIERT (DataResetUITests.swift:11)

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/DataResetUITests.swift:26
  Description: Nachweislauf nur mit -only-testing auf DataResetUITests und QuickAddAssignmentUITests (14 Tests). ReplenishmentUITests, uebrige Suiten, Unit-Tests und Wiederholung (T8) fehlen.
  Spec requirement: AC-9 - Bestandssuiten im gemeinsamen Lauf gruen.
  Conflict: Wechselwirkung mit anderen Seeds und Stabilitaet nicht bewiesen.
  Remediation: Gesamtlauf aller Suiten und zwei Wiederholungen als Artefakt.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/QuickAddAssignmentUITests.swift:136
  Description: Negativprobe "Lidl nicht im Dialog" sucht nur in app.sheets und kann vakuum wahr sein; Toast-Text nur 3 s pruefbar.
  Spec requirement: AC-2 - Dialog zeigt nur den anderen Laden.
  Conflict: Negativteil kann leer laufen.
  Remediation: Auch gegen app.buttons pruefen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/SmartCartApp.swift:177
  Description: Marker ist .txt; die Pruefung schlaegt nur bei kuenftig verbreitertem Filter an, Wirksamkeit nie gezeigt.
  Spec requirement: AC-7 - keine Fremddateien betroffen.
  Conflict: Regressionsschutz statt Wirksamkeitsnachweis.
  Remediation: Wirksamkeit einmalig mit verbreitertem Filter belegen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/QuickAddAssignmentUITests.swift:181
  Description: staticTexts["500 gramm"] nicht auf die Zeile von Hackfleisch eingegrenzt.
  Spec requirement: AC-4 - Mengenzeile in der Liste.
  Conflict: Fremder Treffer wuerde genuegen; aktuell keiner.
  Remediation: listRow("Hackfleisch").staticTexts["500 gramm"].

Finding:
  ID: F005
  Severity: LOW
  Category: security
  Code reference: SmartCart/SmartCartApp.swift:166
  Description: Debug-Build mit dem Argument loescht echte Store-Dateien.
  Spec requirement: AC-10 - nur DEBUG und nur mit Argument.
  Conflict: Kein Konflikt, Hinweis; Release geprueft sauber.
  Remediation: Warnung im CLAUDE.md-Eintrag.

Finding:
  ID: F006
  Severity: MEDIUM
  Category: spec_violation
  Code reference: RestockUITests/DataResetUITests.swift:15
  Description: Umfang ca. 313 hinzugefuegte Zeilen gegen ca. +200 in der Spec und Limit 250, ohne dokumentierte Rueckmeldung.
  Spec requirement: AC-11 - Umfang ca. +200 LoC; bei mehr Rueckmeldung mit Schaetzung.
  Conflict: Limit ueberschritten ohne Freigabe.
  Remediation: Ueberschreitung dokumentieren und entscheiden lassen (Q3 als Verschiebekandidat) oder kuerzen.

Zaehlung: CRITICAL 0, HIGH 0, MEDIUM 2, LOW 4.

VERDICT: AMBIGUOUS - Verhaltens-ACs belegt (RED/GREEN, Release sauber), aber AC-9 (kein Gesamtlauf mit ReplenishmentUITests und Wiederholungen; ein Lauf waere unverzichtbar, nicht gestartet) und AC-11 (ca. 313 LoC ueber Limit) brauchen menschliche Entscheidung.

### Runde 3

Selbst geprueft: test-gesamtlauf-output.txt per grep. Unit: "Executed 434 tests, with 0 failures" (Z. 1199). UI: "Executed 71 tests, with 1 test skipped and 0 failures" (Z. 6080), `** TEST SUCCEEDED **` (Z. 6090), kein Treffer auf Restarting oder failed. Suites DataResetUITests (Z. 1749, 2 Tests), QuickAddAssignmentUITests (Z. 2618, 12 Tests), ReplenishmentUITests (Z. 4902, 10 Tests) passed. Commit 45873db enthaelt die unveraenderte SmartCartApp-Aenderung (44 Zeilen). Restvorbehalt: die drei Stabilitaetswiederholungen (T8) stehen noch aus und gehoeren zu /60-validate, kein Blocker.
AC-11: Freigabe durch PO laut Koordinator (312 Zeilen, Grenze 250, Antwort "Umfang so lassen"); dokumentiert in der Memory-Datei issue-98-durchgang-3-umfang-akzeptiert.md, F006 damit aufgeloest.

Code reference: SmartCart/SmartCartApp.swift:69
Code reference: RestockUITests/QuickAddAssignmentUITests.swift:97
Code reference: RestockUITests/DataResetUITests.swift:79

Status: CONFIRMED
AC: AC-1
Evidence: Runde 1, QuickAddAssignmentUITests.swift:97; im Gesamtlauf Suite QuickAddAssignmentUITests passed (Z. 2618).

Status: CONFIRMED
AC: AC-2
Evidence: Runde 1, QuickAddAssignmentUITests.swift:116; Suite im Gesamtlauf passed (12 Tests, 0 Failures).

Status: CONFIRMED
AC: AC-3
Evidence: Runde 1, QuickAddAssignmentUITests.swift:153; Suite im Gesamtlauf passed.

Status: CONFIRMED
AC: AC-4
Evidence: Runde 1, QuickAddAssignmentUITests.swift:170; Suite im Gesamtlauf passed.

Status: CONFIRMED
AC: AC-5
Evidence: Runde 1, DataResetUITests.swift:92 mit RED/GREEN-Paar; DataResetUITests im Gesamtlauf passed (Z. 1749).

Status: CONFIRMED
AC: AC-6
Evidence: Runde 1/2, DataResetUITests.swift:101; DataResetUITests im Gesamtlauf passed.

Status: CONFIRMED
AC: AC-7
Evidence: Runde 1, SmartCartApp.swift:85 und :90 (Marker vor und precondition nach deleteStoreFiles); Notfalltests im Gesamtlauf passed, Wirksamkeitsgrenze als F003 (LOW) bekannt.

Status: CONFIRMED
AC: AC-8
Evidence: Runde 2, Tests nutzen nur Launch-Argumente und Seed-Rohdaten, nichts von Hand gesetzt (DataResetUITests.swift:45).

Status: CONFIRMED
AC: AC-9
Evidence: Frischer Gesamtlauf ohne -only-testing: 434 Unit- und 71 UI-Tests mit 0 Failures, ReplenishmentUITests passed (Z. 4902), keine Restarts, TEST SUCCEEDED (Z. 6090); T8-Wiederholungen als Restvorbehalt fuer /60-validate.

Status: CONFIRMED
AC: AC-10
Evidence: Runde 1, SmartCartApp.swift:69 nur unter #if DEBUG, release-build-check.txt 0 Treffer; make() und deleteStoreFiles unveraendert.

Status: CONFIRMED
AC: AC-11
Evidence: 4 Code-Dateien, Regeldienste, Texte, Layout unveraendert; ca. 312 Zeilen ueber Limit 250 mit dokumentierter PO-Freigabe ("Umfang so lassen", Memory-Datei issue-98-durchgang-3-umfang-akzeptiert.md).

Status: CONFIRMED
AC: AC-12
Evidence: Runde 1, "OFFENE GRENZE" in DataResetUITests.swift:11 und in der Spec.

Bestehende LOW-Findings F002 bis F005 bleiben als bekannt und nicht blockierend bestehen; F001 und F006 sind durch Gesamtlauf bzw. PO-Freigabe aufgeloest. Zaehlung final: CRITICAL 0, HIGH 0, MEDIUM 0 offen, LOW 4.

VERDICT: VERIFIED - alle 12 ACs bestaetigt, Gesamtlauf (434 Unit, 71 UI, 0 Failures, keine Restarts) liegt vor, Umfang vom PO freigegeben, kein CRITICAL/HIGH; Restvorbehalt T8-Wiederholungen in /60-validate.

## Geprüfte Dateien

- sha256:fd9a9732fd018cd112459f0fb1bdf9a657866ced086e3303dd3ea49a4b8f7783  Restock.xcodeproj/project.pbxproj
- sha256:3a16d0fcf6a70b01fd11fa59045570ce57fdc06ba248a68e2c9966a824134f6a  RestockUITests/DataResetUITests.swift
- sha256:fc35450a2ca3f26760454abd3fc4b8de9f21a7ad94d2a60eeea0d1479d2af7f5  RestockUITests/QuickAddAssignmentUITests.swift
- sha256:2381ddbd5885b3bd43c6511f4302c036d9405a13eff0a9e0d03fae02b30ede78  SmartCart/SmartCartApp.swift
