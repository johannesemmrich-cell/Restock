# Adversary-Dialog: fix-105-leerer-start-ursache (Durchgang 2 von #105/#128)

Spec: docs/specs/ui-tests/test-105-durchgang-2-start-messung.md
Prüfstand: RestockUITests/UITestWait.swift (+66/−2), Hilfstests 12/12 grün (eigener Lauf des Prüfers), Wegwerf-Lauf AC-6 im Auszug belegt.

### Runde 1

- [x] AC-1: measurementLine liefert alle Felder mit Namen und Einheit; testMeasurementLineNamesAllFields grün.
- [x] AC-2: nicht ermittelbare Werte erscheinen als „unbekannt“, kein „0.0“; testMeasurementLineShowsUnknownForMissingValues grün.
- [x] AC-3: run meldet nur bei „zweiter Start gelungen“, mit Präfix, Befund und Messzeile (pid 100 → 200); testSecondLaunchRecoversAndReportsOnce grün.
- [x] AC-4: defaultTimeout/pollInterval unverändert; keine neuen Starts oder Pausen; measureCalls == 0 bei Erfolg im ersten Start.
- [x] AC-5: Verhalten aus Durchgang 1 unverändert (kein dritter Start, failureMessage unverändert, keine Meldung bei Gesamtscheitern).
- [x] AC-6: Wegwerf-Lauf im echten Helfer: „seit Lauf 9.9 s, seit Helferaufruf 8.9 s, Last 4.3/4.3/3.9, pid 8108 → 8132, Start Nr. 2“; kein Wegwerf-Code im Repo.
- [x] AC-9: kein Diff unter SmartCart/ und Restock.xcodeproj; genau eine Testdatei geändert.
- [x] AC-7: voller UI-Lauf auf Restock-Validate (ui-lauf-voll.txt): Executed 84 tests, 1 skipped (bekannt), 0 failures, TEST SUCCEEDED, kein Restart; Meldungen „zweiter Start nötig“: 0 (Messwert, kein Beweis der Stabilität).
- [x] AC-8: Unit-Suite (unit-lauf.txt): Executed 478 tests, 0 failures, TEST SUCCEEDED.
- [x] AC-10: Text für Ticket-Kommentare und PR liegt vor (abschlussbericht.md) und nennt alle geforderten Aussagen; Einstellen in Tickets erfolgt beim Abschluss.

Code reference: RestockUITests/UITestWait.swift:79
Code reference: RestockUITests/UITestWait.swift:93
Code reference: RestockUITests/UITestWait.swift:106
Code reference: RestockUITests/UITestWait.swift:127
Code reference: RestockUITests/UITestWait.swift:139
Code reference: RestockUITests/UITestWait.swift:158
Code reference: RestockUITests/UITestWait.swift:263

### Runde 2

(a) pid wird nach dem ersten Fehlschlag vor terminate gelesen (Spec-konform), rein lesend; bei Erfolg im ersten Start wird nichts gelesen.
(b) Nur eine fehlende pid ergibt „4711 → unbekannt“; NaN/negative Werte würden als Zahl formatiert (praktisch unerreichbar, F002).
(c) KVC auf processID ist durch responds(to:) abgesichert; Werte ≤ 0 oder fehlend ergeben „unbekannt“ (Restrisiko Xcode-Update, F003).
(d) sysctl-Struktur und Zeitbezug plausibel; Fehlschlag ergibt nil.
(e) launchCount zählt nur Helferstarts über alle Aufrufe; Aufräumstarts nicht gezählt (in der Spec als Grenze genannt).
(f) Kommentar zu app.processIdentifier war irreführend (F001) und ist korrigiert.
(g) Umfang +66/−2 statt ca. +40/−5, im Limit; LoC-Gate vor Abschluss prüfen, kein loc_limit_override.
(h) Kein Throwaway105 im Repo-Code.

Findings:

- F001 | LOW | anti_pattern | Kommentar nannte app.processIdentifier, das es unter iOS nicht gibt | Evidence: RestockUITests/UITestWait.swift:84 | Remediation: Kommentar angepasst (erledigt).
- F002 | LOW | edge_case | NaN/negative Werte werden nicht als „unbekannt“ formatiert, Test für nur eine fehlende pid fehlt | Evidence: RestockUITests/UITestWait.swift:95 | Remediation: bewusst nicht umgesetzt, praktisch unerreichbar; Scope.
- F003 | LOW | edge_case | pid über nicht öffentliche Eigenschaft, kann mit künftigem Xcode still zu „unbekannt“ werden | Evidence: RestockUITests/UITestWait.swift:139 | Remediation: als Grenze im Abschlussbericht nennen.
- F004 | LOW | spec_violation | Umfang über der Schätzung; launchCount ohne eigenen Test (nur durch Wegwerf-Lauf belegt) | Evidence: RestockUITests/UITestWait.swift:164 | Remediation: im Abschlussbericht benennen.

Code reference: RestockUITests/UITestWait.swift:84

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:62a169769f99de18a3ab5fa99e3ed5dc8caea685bc5fe2f8a0d9feca03309315  RestockUITests/UITestWait.swift

## Prüfbasis

- base: 865c5135e6e1a2597ba9893cd1135d5103556dc9
- blob:b77ae748afb9a9129b3f7e1bae4a33f1f45671e5  RestockUITests/UITestWait.swift
