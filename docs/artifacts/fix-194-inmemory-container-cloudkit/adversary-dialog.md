# Adversary Dialog — fix-194-inmemory-container-cloudkit
Spec: docs/specs/testing/inmemory-container-ohne-cloudkit.md
Datum: 2026-10-21 09:56

## Checkliste
- [x] **Input:** Unit-Tests unter iOS 27.0 im Simulator ohne iCloud-Konto.
- [x] **Output:** Die fünf Testklassen legen ihren In-Memory-Speicher ohne CloudKit-Aufbau an; kein
- [x] **Side effects:** keine; das Verhalten der App ändert sich nicht.
- [x] **AC-1:** GIVEN der Strukturtest `scripts/test_inmemory_containers_no_cloudkit.py`, WHEN er gegen den Stand vor dem Fix läuft, THEN liegt ein RED-Protokoll mit genau 5 Treffern vor, und WHEN er nach dem Fix läuft, THEN ist er grün (0 Verstöße, Exit 0).
- [x] **AC-2:** GIVEN die fünf Dateien `NotificationDigestChainTests`, `ReceiptAIResolutionChainTests`, `ReceiptKnownItemNamesTests`, `ReceiptParserSuggestionTests`, `ReceiptResolutionStatsTests`, WHEN der Diff gelesen wird, THEN enthält der In-Memory-Aufruf jeweils `cloudKitDatabase: .none` und der Diff je Datei umfasst genau eine geänderte Zeile.
- [x] **AC-3:** GIVEN `NotificationDigestChainTests` auf iOS 27.0 im Simulator, WHEN die Klasse nach dem Fix läuft, THEN sind 8 von 8 Tests grün ohne „Restarting after unexpected exit", und ein RED-Protokoll (Host-Absturz auf dem Stand davor) liegt vor.
- [x] **AC-4:** GIVEN die gesamte Unit-Suite (`-only-testing:RestockTests`) auf iOS 27.0, WHEN sie nach dem Fix läuft, THEN gibt es 0 Host-Neustarts, 0 Absturzberichte während des Laufs, die Zahl der ausgeführten Tests ist ≥ 600, und die einzigen roten Tests sind die aus #195 (`ReceiptTextRecognizerTests` T1, 3 Assertions). Offene Grenze: #195 bleibt rot.
- [x] **AC-5:** GIVEN der Gesamtdiff gegen den Tip-Commit, WHEN die Pfade geprüft werden, THEN sind `SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`, `RestockUITests/` und `Restock.xcodeproj/project.pbxproj` unverändert; geändert sind nur die fünf Testdateien, der Strukturtest und `CLAUDE.md`.
- [x] **AC-6:** GIVEN der Stand nach dem Fix, WHEN ein Durchlauf im Simulator (iOS 27.0) gemacht wird, THEN startet die Test-Host-App, die Startseite ist sichtbar, und ein Bildschirmfoto liegt unter `docs/artifacts/fix-194-inmemory-container-cloudkit/`.

## Dialog

### Runde 1
**Adversary:**
Selbst belegt (Rohdaten: docs/artifacts/fix-194-inmemory-container-cloudkit/adversary-test-output.txt, adversary-sim-run.txt):
- AC-1: Strukturtest heute: 2 Tests OK, Exit 0. RED-Protokoll test-red-structure.txt: genau 5 Treffer (Digest:203, AIResolution:56, KnownItemNames:11, ParserSuggestion:14, Stats:33), Exit 1. Mehrzeilen-Selbsttest laeuft und ist gruen. Probe: `isStoredInMemoryOnly:true` ohne Leerzeichen und `isStoredInMemoryOnly: m` werden nicht erkannt (F002, LOW). 17 Fundstellen im Verzeichnis, alle 17 mit Literal `: true`.
- AC-2: Diff-Stat: je Swift-Datei 1 insertion/1 deletion, Diff-Zeile enthaelt `cloudKitDatabase: .none`. Belegt.
- AC-3: GREEN selbst gefahren (iOS 27.0, nur die Klasse): 8 Tests, 0 Failures, 0 Restarts, Absturzberichte weiter 24. RED-Protokoll liegt vor, ist aber ein uebernommener Lauf einer Wegwerf-Kopie (README), nicht auf diesem Baum (F001, LOW).
- AC-4: Volllog: 0x "Restarting after unexpected exit"; "Executed 612 tests, with 3 failures (0 unexpected)"; einziges `Test Case ... failed (` ist ReceiptTextRecognizerTests T1, 3 XCTAssert-Fehler (ReceiptTextRecognizerTests.swift:52,54,56) = #195. 611 passed + 1 failed = 612, >= 600. crash-reports-count.txt: 24/24/24/24, aktuell 24.
- AC-5: Status: geaendert nur CLAUDE.md und 5 Testdateien; kein SmartCart/, Widgets, ShareExtension, RestockUITests, pbxproj. Das Skript ist bereits im Tip-Commit 0e6f24f (RED) und daher nicht im Arbeitsbaum-Diff; Implementierer soll Diff gegen den Basis-Commit zeigen.
- AC-6: simulator-durchlauf.png (222847 Byte) vorhanden; Bild geprueft: Startseite Restock sichtbar (Kopfkarte, Schnell hinzufuegen, Meine Laeden), Uhr 09:16.
Offen fuer Runde 2: Bild ansehen; F001 und F002 einordnen; Diff gegen Basis-Commit zeigen.
Finding F001: Severity LOW, Category spec_violation, Code reference: docs/artifacts/fix-194-inmemory-container-cloudkit/README.md:5. Description: RED-Lauf stammt aus Fremdkopie (e9a6b79). Spec requirement: AC-3 RED-Protokoll auf dem Stand davor. Conflict: nur formal, nicht auf diesem Baum gefahren. Remediation: Offenlegung im Bericht, kein weiterer Lauf.
Finding F002: Severity LOW, Category edge_case, Code reference: scripts/test_inmemory_containers_no_cloudkit.py:48. Description: MARKER ist exakt "isStoredInMemoryOnly: true"; Schreibweise ohne Leerzeichen oder mit Variable wird uebersehen. Spec requirement: Expected Behavior (kuenftige Verstoesse rot). Conflict: Luecke, Known Limitations nennt sie nur teilweise. Remediation: Regex `isStoredInMemoryOnly\s*:`.
Code reference: RestockTests/NotificationDigestChainTests.swift:203
Code reference: RestockTests/ReceiptAIResolutionChainTests.swift:56
Code reference: RestockTests/ReceiptKnownItemNamesTests.swift:11
Code reference: RestockTests/ReceiptParserSuggestionTests.swift:14
Code reference: RestockTests/ReceiptResolutionStatsTests.swift:33
Code reference: scripts/test_inmemory_containers_no_cloudkit.py:15
Code reference: CLAUDE.md:26
**Implementierer:**
- F002 (behoben): `MARKER` ist jetzt die Regex `isStoredInMemoryOnly\s*:(?!\s*false\b)` — jeder Wert außer dem Literal `false` zählt (`true`, `:true` ohne Leerzeichen, Variablen). Neuer Selbsttest `test_detector_sees_spelling_variants_and_ignores_false`: meldet `isStoredInMemoryOnly: true`, `isStoredInMemoryOnly:true`, `isStoredInMemoryOnly: inMemory` (Zeilen 1–3), meldet `false` und `:true, cloudKitDatabase: .none` nicht. Neuer Lauf (test-green-structure.txt): 3 Tests OK, Exit 0. RED bleibt gültig: die erweiterte Erkennung gegen die exportierten `RestockTests/` von 0e6f24f liefert genau dieselben 5 Treffer (Digest:203, AIResolution:56, KnownItemNames:11, ParserSuggestion:14, Stats:33) — alle fünf sind Literale `: true`, die alte Erkennung traf sie schon; Beleg in adversary-test-output.txt („F002 Implementierer").
- AC-5: Diff gegen Basis 0e6f24f (adversary-test-output.txt, „AC-5 Implementierer"): 7 Dateien, +20/−7 — die fünf Testdateien (je 1/1), CLAUDE.md (+2), scripts/test_inmemory_containers_no_cloudkit.py (+13/−2, F002). 0 Pfade unter SmartCart/, SmartCartWidgets/, RestockShareExtension/, RestockUITests/, project.pbxproj.
- F001 (offengelegt, kein neuer Lauf): Das RED-Protokoll für AC-3 (test-red-notificationdigest*.txt/.log) stammt aus der Gegenprobe vom 2026-10-21 08:21 auf dem unveränderten Stand (Wegwerf-Kopie von e9a6b79, deren fünf Testdateien identisch zu main/0e6f24f sind): 8× „Restarting after unexpected exit", `No eligible connection available`. Die 24 Absturzberichte `~/Library/Logs/DiagnosticReports/Restock-2026-10-21-*` belegen dasselbe. Kein erneuter RED-Lauf, weil jeder weitere Lauf auf dem alten Stand acht neue Absturzmeldungen beim PO erzeugt hätte, ohne neue Information zu liefern. Nach dem Fix blieb die Zahl über B, C und D bei 24 (crash-reports-count.txt).
- Input: Simulator ohne iCloud-Konto — test-green-output-full.log:9 `NSCocoaErrorDomain Code=134400 "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."` (vom eigenen Produktions-Container der App beim Start des Test-Hosts, abgefangen als `[sync] mirror setup failed`).
- Output: die fünf Klassen legen ihren Speicher mit `cloudKitDatabase: .none` an — Diff je Datei genau diese eine Zeile; Lauf C: 612 Tests, 0 „Restarting after unexpected exit", nur #195 rot; Lauf B: Digest 8/8.
- Side effects: keine — `diff --name-only 0e6f24f` enthält nur Testdateien, Strukturtest und CLAUDE.md, keinen Produktcode; die App startet im Simulator wie zuvor (simulator-durchlauf.png).

### Runde 2
**Adversary:**
- Strukturtest erneut selbst: 3 Tests OK, Exit 0 (MARKER jetzt Regex, Zeile 15).
- F002 nachgebohrt: Beispieldatei mit `isStoredInMemoryOnly:true`, `isStoredInMemoryOnly: inMemory`, `: false` und einem korrekten Aufruf; gemeldet werden genau Zeile 1 und 2. F002 BEHOBEN.
- F001: als formal offengelegt akzeptiert (RED-Lauf aus Fremdkopie, README und Bericht). Offene Grenze, kein Blocker.
- AC-5: Namensliste gegen 0e6f24f selbst gefahren: 7 Dateien, genau die erlaubten; kein Produktcode, UITests, pbxproj. BELEGT.
- Input/Output/Side effects: Volllog 0 Restarts, 612 Tests, Crashberichte konstant 24, Diff nur Tests und Doku. BELEGT.
Restrisiko: Strukturtest prueft Text; Container ausserhalb von isStoredInMemoryOnly nicht erfasst (Known Limitations).
Code reference: RestockTests/NotificationDigestChainTests.swift:203
Code reference: RestockTests/ReceiptAIResolutionChainTests.swift:56
Code reference: RestockTests/ReceiptKnownItemNamesTests.swift:11
Code reference: RestockTests/ReceiptParserSuggestionTests.swift:14
Code reference: RestockTests/ReceiptResolutionStatsTests.swift:33
Code reference: scripts/test_inmemory_containers_no_cloudkit.py:15
Code reference: CLAUDE.md:26
**Implementierer:** keine weiteren Forderungen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 611 bestanden, 1 rot (#195, ausserhalb des Auftrags), 0 uebersprungen; Strukturtest 3/3; Klasse 8/8 auf iOS 27.0
Edge cases: F002 behoben und geprueft; F001 LOW, offengelegt
Regressions: keine; 0 Host-Neustarts, Absturzberichte konstant 24
Checklist: 9/9 points proven
Offene Grenze: CI (iOS 26) kann den Fix nicht bestaetigen; #195 bleibt rot.

## Geprüfte Dateien

- sha256:c75af2680d96720b67ce281ff4c24fc1c574b6243109ba5316fc2cec261bdf2e  CLAUDE.md
- sha256:9cd84a1dc9861b42da32aebc42ae4d0254447f882b47777f77d1ec6bbbddce0e  RestockTests/NotificationDigestChainTests.swift
- sha256:b2fc66e12eb65114fd5a50451986256c27c3f8f4bd8127cf8c7c7c88e5520e86  RestockTests/ReceiptAIResolutionChainTests.swift
- sha256:2d9496a8f2d2a19c4866d8e9b3dac580e29e2e41781d1f44af041f7fbc8c5395  RestockTests/ReceiptKnownItemNamesTests.swift
- sha256:56fdfcbbf48eb9010b9ec26bdfd593298f7d22e9f61b05155490da8bfd2f43e6  RestockTests/ReceiptParserSuggestionTests.swift
- sha256:f79aac43e2b99b0d6779c71e78ef4553a61958343e01e9855c8d1254c3ae4c6c  RestockTests/ReceiptResolutionStatsTests.swift
- sha256:e838d99fafb939ca28a01e64653184442aeb26f939b6ffec14c830895a5afaa4  scripts/test_inmemory_containers_no_cloudkit.py

## Prüfbasis

- base: 13f8e14e93f681a1b3b0da87856e1e56ac90cef3
- blob:61399204050da8804cfc021e5edb041bdd9d9e48  CLAUDE.md
- blob:260dd3d3fa9cdb02aa9bde9113d3dde92c9671fe  RestockTests/NotificationDigestChainTests.swift
- blob:5691068a48bb48f30f57a6207f466e6fa94ffcd1  RestockTests/ReceiptAIResolutionChainTests.swift
- blob:27459fca458a53d2b17eea5be07306f6ee9e5925  RestockTests/ReceiptKnownItemNamesTests.swift
- blob:ad83d0c54623d17c54583116b0cfc46929ec6474  RestockTests/ReceiptParserSuggestionTests.swift
- blob:0667f7e2096d30cb677c87abbf18d874ebb8ad44  RestockTests/ReceiptResolutionStatsTests.swift
- blob:6dc44c2acff07b3f9959484aaa6c9f21fda03abe  scripts/test_inmemory_containers_no_cloudkit.py

## Geprüfte Dateien

- sha256:c75af2680d96720b67ce281ff4c24fc1c574b6243109ba5316fc2cec261bdf2e  CLAUDE.md
- sha256:9cd84a1dc9861b42da32aebc42ae4d0254447f882b47777f77d1ec6bbbddce0e  RestockTests/NotificationDigestChainTests.swift
- sha256:b2fc66e12eb65114fd5a50451986256c27c3f8f4bd8127cf8c7c7c88e5520e86  RestockTests/ReceiptAIResolutionChainTests.swift
- sha256:2d9496a8f2d2a19c4866d8e9b3dac580e29e2e41781d1f44af041f7fbc8c5395  RestockTests/ReceiptKnownItemNamesTests.swift
- sha256:56fdfcbbf48eb9010b9ec26bdfd593298f7d22e9f61b05155490da8bfd2f43e6  RestockTests/ReceiptParserSuggestionTests.swift
- sha256:f79aac43e2b99b0d6779c71e78ef4553a61958343e01e9855c8d1254c3ae4c6c  RestockTests/ReceiptResolutionStatsTests.swift
- sha256:e838d99fafb939ca28a01e64653184442aeb26f939b6ffec14c830895a5afaa4  scripts/test_inmemory_containers_no_cloudkit.py

## Prüfbasis

- base: 13f8e14e93f681a1b3b0da87856e1e56ac90cef3
- blob:61399204050da8804cfc021e5edb041bdd9d9e48  CLAUDE.md
- blob:260dd3d3fa9cdb02aa9bde9113d3dde92c9671fe  RestockTests/NotificationDigestChainTests.swift
- blob:5691068a48bb48f30f57a6207f466e6fa94ffcd1  RestockTests/ReceiptAIResolutionChainTests.swift
- blob:27459fca458a53d2b17eea5be07306f6ee9e5925  RestockTests/ReceiptKnownItemNamesTests.swift
- blob:ad83d0c54623d17c54583116b0cfc46929ec6474  RestockTests/ReceiptParserSuggestionTests.swift
- blob:0667f7e2096d30cb677c87abbf18d874ebb8ad44  RestockTests/ReceiptResolutionStatsTests.swift
- blob:6dc44c2acff07b3f9959484aaa6c9f21fda03abe  scripts/test_inmemory_containers_no_cloudkit.py
