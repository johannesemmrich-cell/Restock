# Adversary Dialog — test-145-d3-app-intents-testing
Spec: docs/specs/ui-tests/test-145-durchgang-3-app-intents.md
Datum: 2026-10-16 20:57

## Checkliste
- [x] **AC-1:** GIVEN gesäte Läden Lidl und dm, WHEN `testAddIntentPutsItemIntoDm` den `AddShoppingItemIntent` über `AppIntentsTesting` ausführt, THEN erscheint der Artikel in der dm-Kachel und in der dm-Liste und **nicht** in Lidl (Kachel und Liste). Test: T1.
- [x] **AC-2:** GIVEN die dm-Liste mit zwei Artikeln war geöffnet und die App liegt im Hintergrund (Home), WHEN `testCheckOffIntentChecksFirstItem` den `CheckOffItemIntent` für dm ausführt und die App wieder aktiviert wird, THEN ist der erste Artikel erledigt („1 von 2 erledigt“), der zweite offen. Test: T2.
- [x] **AC-3:** GIVEN die Liste ist geschlossen, WHEN `testCheckOffWithClosedListChangesNothing` den Intent ausführt (auch wenn `run()` Erfolg meldet), THEN ist nach dem Öffnen der Liste kein Artikel erledigt („0 von 2 erledigt“). Test: T3.
- [x] **AC-4:** GIVEN die Tests T1 bis T3, WHEN sie ihre Aussage prüfen, THEN lesen sie ausschließlich den Zustand der App-Oberfläche und werten das Ergebnis von `run()` nie aus (kein `XCTAssert` auf dem Rückgabewert). Test: T9 (`grep` bzw. Review der Klasse).
- [x] **AC-5:** GIVEN `runIntentRetrying`, WHEN ein Aufruf mit `AppIntentsServicesMetadataErrorDomain` Code 400 und Text „is not present“ scheitert, THEN wird innerhalb einer festen Frist wiederholt und je Wiederholung eine Messzeile ins Testprotokoll geschrieben; WHEN ein anderer Fehler auftritt, THEN wird er sofort ohne Wiederholung weitergereicht; nach Fristablauf wird der letzte 400-Fehler geworfen. Test: T8, T7.
- [x] **AC-6:** GIVEN Xcode 26.6 (CI) oder Xcode 27.1 mit einem iOS-26-Simulator, WHEN das UI-Testziel ohne `APPINTENTS_UITESTS` gebaut und die Suite gefahren wird, THEN steht die gesamte Datei `AppIntentsUITests.swift` hinter `#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS`, der Helfer importiert das Framework nicht, jeder Test beginnt mit `#available(iOS 27.0, *)` und springt sonst per `XCTSkip` mit Grund, das Paket lädt und der Build bleibt grün. Test: T4.
- [x] **AC-7:** GIVEN die Launch-Argumente der Klasse, WHEN sie geprüft werden, THEN sind es nur `-hasCompletedOnboarding YES` und der Seed `-seedQuickAddAssignmentForUITests` (plus die von `UITestLaunch` gesetzten); `-developerMode` und `-notificationsEnabled` kommen nicht vor (Argument-Domain-Falle). Test: T9 (`grep`).
- [x] **AC-8:** GIVEN jeder Testlauf (auch bei Fehlschlag), WHEN `tearDown()` läuft, THEN startet es die App mit `-clearQuickAddAssignmentSeedForUITests` und beendet sie; es bleibt kein Seed im App-Gruppen-Container. Test: T5, T7 (zweiter Lauf startet auf sauberem Simulator ohnehin; Prüfung im Bestandslauf T4 und per Review).
- [x] **AC-9:** GIVEN das Skript, WHEN es startet, THEN nimmt es `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` in dieser Reihenfolge per `mkdir` samt `owner`-Datei, bricht bei belegter Sperre mit Meldung ab, ohne die fremde Sperre anzutasten, und gibt bei jedem Ende nur selbst angelegte Sperren frei. Test: T5, T6.
- [x] **AC-10:** GIVEN das Skript, WHEN es läuft, THEN baut es genau einmal (`build-for-testing`, einzige zusätzliche Einstellung `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APPINTENTS_UITESTS'`) und führt auf einem Wegwerf-Simulator mit Runtime iOS 27.0 `simctl install` und `xcodebuild test-without-building -only-testing:RestockUITests/AppIntentsUITests` aus. Test: T5.
- [x] **AC-11:** GIVEN die Auswertung, WHEN sie läuft, THEN zählt der Lauf nur bei genau 3 gelaufenen Tests, 0 Fehlschlägen, 0 Übersprungenen und ohne Abbruch als grün; „Executed 0 tests“, Runner-Neustart oder Übersprünge sind Rot (Null-Test-Lauf ist kein Grün). Test: T5.
- [x] **AC-12:** GIVEN der Skriptlauf, WHEN er endet (grün oder rot), THEN ist der Wegwerf-Simulator gelöscht (`trap`), `simctl list devices` enthält keinen Namen `Restock-AppIntents-<zeit>` und `Restock-Validate` ist unverändert. Test: T5.
- [x] **AC-13:** GIVEN der Nachweis, WHEN drei Skriptläufe hintereinander erfolgt sind, THEN sind alle drei grün, davon mindestens einer unter Rechnerlast; die Protokolle samt Messzeilen und Ergebnisblock (Commit-Kennung, Zeitstempel, Testzahl, Last) liegen unter `docs/artifacts/test-145-d3-app-intents-testing/`. Test: T7.
- [x] **AC-14:** GIVEN die Bestandssuite auf `Restock-Validate` (iOS 26.5), WHEN sie nach der Änderung läuft, THEN lädt das Paket, sie bleibt grün mit der bisherigen Testzahl plus den 4 `AppIntentRetryTests` (die Klasse `AppIntentsUITests` ist dort leer); kein Abbruch, kein „Failed to load the test bundle“. Test: T4.
- [x] **AC-15:** GIVEN der Abschluss, WHEN die Doku geprüft wird, THEN beschreibt `CLAUDE.md` Klasse, Skript, Sperren, Wegwerf-Simulator iOS 27, Retry-Helfer, die Kompilierbedingung `APPINTENTS_UITESTS` samt Grund (Ladefehler auf iOS 26), die leere Klasse in CI und Bestandssuite und die offenen Grenzen. Test: T9.
- [x] **AC-16:** GIVEN Spec, Kopfkommentar der Klasse, `CLAUDE.md`, Ticketkommentar und Bericht, WHEN sie formuliert werden, THEN sind ausdrücklich als offen genannt: echter Siri-Ruf per Stimme, nicht prüfbarer Dialogtext, Tipp auf Widget/Live Activity/Control, CI-Anschluss (xcode-27-Runner Preview, Signierungsfehler 800 unbelegt), Fehler 400 unter Last nur abgefangen und nicht erklärt, „stiller Erfolg ohne Wirkung“ von `CheckOffItemIntent` ohne Activity (Beobachtung fürs Issue), nichts auf Hennings Geräten; #145 bleibt offen (Durchgang 4). Keine Zusage lautet „Siri geprüft“ ohne diese Einschränkungen.
- [x] **AC-17:** GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens `AppIntentsUITests.swift`, `UITestWait.swift`, `run-appintents-uitest.sh`, `project.pbxproj` sowie die Doku (`CLAUDE.md`, Spec, Artefakte), ca. +330 LoC (vom PO freigegeben); Produktcode (`SmartCart/`, `RestockShareExtension/`, `SmartCartWidgets/`), `ci.yml` und Scheme sind unverändert. Test: T9.
- [x] **AC-18:** GIVEN der gesamte Durchgang, WHEN Schritte ausgeführt werden, THEN startet, installiert oder liest keiner ein Gerät des Users; alle Läufe nur auf Wegwerf-Simulatoren bzw. `Restock-Validate`. Test: Review des Skripts (`simctl`-Ziele nur selbst angelegte UDIDs).

## Dialog

### Runde 1
**Adversary:** Beweise jeden der 18 Punkte selbst. Annahme: Der Durchgang ist kaputt, bis das Gegenteil belegt ist. Konkret gefordert: (a) Bestandssuite auf Restock-Validate komplett, nicht nur drei Klassen; (b) der Sperren-Abbruch wirklich ausgelöst, nicht nur im Skript gelesen; (c) `$(inherited)` behält DEBUG (sonst wären die DEBUG-Seeds tot); (d) T3 beweist „keine Wirkung" und nicht „noch nicht angewendet"; (e) Wegwerf-Simulator und Sperren bei Abbruch (SIGTERM) in der Testphase freigegeben; (f) T1 bis T3 werten `run()` nie aus; (g) Diff-Umfang und Produktcode unverändert; (h) kein Gerät des Users berührt.
**Implementierer:** Belege, alle selbst gefahren oder gelesen, nicht aus Vorarbeit übernommen:
- (a) AC-14: Vollständiger `xcodebuild test`, Schema Restock, keine Zusatz-Settings, Restock-Validate (iOS 26.5), beide Sperren 20:59:45 bis Ende. Ergebnis `** TEST SUCCEEDED **`: Unit 498 Tests, 0 Fehlschläge; UI 108 Tests, 3 übersprungen, 0 Fehlschläge; 603 bestanden. Die 3 Übersprünge sind vorgesehene Gates (2x `NotificationPermissionUITests` ohne `RESTOCK_NOTIF_DECISION`, 1x `ReceiptShareExtensionTests` ohne Skript), kein Nullbasis-Lauf. `AppIntentRetryTests` 4 bestanden, `AppIntentsUITests` trägt 0 Tests bei. Kein „Failed to load the test bundle", kein „Executed 0 tests", kein „Restarting after unexpected exit". Auszug: `docs/artifacts/test-145-d3-app-intents-testing/adversary-test-output.txt`.
Code reference: RestockUITests/AppIntentsUITests.swift:1
- (b) AC-9: `/tmp/heavy-build.lock` mit fremder `owner`-Datei belegt, Skript gestartet: sofort `ABBRUCH — Sperre /tmp/heavy-build.lock belegt, Inhaber: fremder-inhaber adversary-probe`, Exit 2, `owner` unverändert, keine loose-ends-Sperre angelegt, 0 Simulatoren vorher und nachher. Dasselbe mit `/tmp/loose-ends-testlauf.lock` belegt: Abbruch Exit 2, die vom Skript zuvor genommene heavy-Sperre ist danach frei (gibt nur eigene frei), fremde Sperre samt `owner` unangetastet. Meine Prüfsperren danach entfernt.
Code reference: scripts/run-appintents-uitest.sh:18
- (c) `xcodebuild -showBuildSettings` mit genau dem Skript-Argument liefert für Ziel Restock und SmartCartWidgets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG APPINTENTS_UITESTS`: `$(inherited)` greift, DEBUG bleibt. Zusätzlich beweisen die drei grünen Skriptläufe (Seed `-seedQuickAddAssignmentForUITests` ist DEBUG-only) das indirekt.
Code reference: scripts/run-appintents-uitest.sh:28
- (d) T3: `CheckOffItemIntent.perform()` legt nur dann etwas in `CheckoffQueue` (synchron), wenn eine Live Activity mit pendingItemIDs existiert; ohne Activity bleibt der Zweig ausdrücklich leer („passiert bewusst NICHTS"). Die Liste lädt `applyPendingCheckoffs()` beim Erscheinen. Es gibt also nichts, was später „nachgezogen" werden könnte; „Erledigt" fehlt nach dem Öffnen, „0 von 2 erledigt" steht. Mechanismus und UI-Beobachtung stimmen überein, kein bloßes Zeitfenster.
Code reference: SmartCart/Intents/CheckOffItemIntent.swift:29
- (e) AC-12: Skript in der Testphase (Zeile „Test auf …" gesehen, `xcodebuild test-without-building` läuft) per SIGTERM beendet: nach 10 s Skript weg, `Restock-AppIntents-…`-Simulator gelöscht, beide Sperren frei, keine xcodebuild-Waise. Ein erster Versuch traf nur die Boot-Phase (`bootstatus -b` ist Vordergrundkind, Trap wartet), auch dort nach dem Boot sauber aufgeräumt. Siehe `adversary-test-output.txt`.
Code reference: scripts/run-appintents-uitest.sh:17
- (f) AC-4: Suche nach `run()`: nur zwei Stellen, beide `_ = try await … .run()`, Ergebnis verworfen; kein `XCTAssert` auf Rückgabe. Alle Assertions lesen `app.staticTexts`/Kachel-Labels.
Code reference: RestockUITests/AppIntentsUITests.swift:63
- AC-7: Launch-Argumente sind nur `-hasCompletedOnboarding YES`, `-seedQuickAddAssignmentForUITests`, im Aufräumer `-clearQuickAddAssignmentSeedForUITests`; `-developerMode`/`-notificationsEnabled` kommen nicht vor (grep ohne Treffer).
Code reference: RestockUITests/AppIntentsUITests.swift:44
- AC-5: `isNotPresent` verlangt Domain `AppIntentsServicesMetadataErrorDomain`, Code 400 und „is not present"; jeder andere Fehler wird durch `guard isNotPresent(error), elapsed + interval <= maxDuration else { throw error }` sofort geworfen; Frist 10 s, Intervall 0,5 s, je Wiederholung `report(...)` mit Marker. 4 `AppIntentRetryTests` im Vollauf grün (T7/T8).
Code reference: RestockUITests/UITestWait.swift:220
- AC-6: Datei beginnt mit `#if canImport(AppIntentsTesting) && APPINTENTS_UITESTS`, jeder Test beginnt mit `guard #available(iOS 27.0, *) else { throw XCTSkip(...) }`; `UITestWait.swift` importiert das Framework nicht; Vollauf auf iOS 26.5 baut und lädt (AC-14). Registrierung im Projekt: je eine Zeile in PBXBuildFile, PBXFileReference, Gruppe, Sources.
Code reference: Restock.xcodeproj/project.pbxproj:1149
- AC-8: `tearDown()` startet mit `-clearQuickAddAssignmentSeedForUITests` und beendet die App; läuft auch nach Fehlschlag.
Code reference: RestockUITests/AppIntentsUITests.swift:28
- AC-10/AC-11: Ein `build-for-testing` mit der einen Zusatzeinstellung, Wegwerf-Simulator mit Runtime 27.0, `simctl install`, `test-without-building -only-testing:RestockUITests/AppIntentsUITests`; grün nur bei `EXECUTED == 3`, 0 Fehlschlägen, 0 Übersprungenen und ohne die vier Abbruchmarker.
Code reference: scripts/run-appintents-uitest.sh:52
- AC-13: drei Skriptläufe grün (3/3 Tests, Lauf 2 unter 8x CPU-Last), Protokolle `appintents-20261016-204057/204437/204744.log` mit je `Executed 3 tests, with 0 failures`; Zusammenfassung `test-green-output.txt`.
Code reference: scripts/run-appintents-uitest.sh:67
- AC-15/AC-16: `CLAUDE.md` Absatz `AppIntentsUITests` (Zeile 44) nennt Klasse, Skript, Sperren, iOS-27-Wegwerf-Simulator, Retry-Helfer, `APPINTENTS_UITESTS` samt Ladefehler-Grund, leere Klasse in CI/Bestandssuite und alle offenen Grenzen inkl. „#145 bleibt offen (Durchgang 4)".
Code reference: CLAUDE.md:44
- AC-17/AC-18: Diff gegen HEAD~1 ohne Doku: nur `CLAUDE.md`, `project.pbxproj`, `AppIntentsUITests.swift`, `UITestWait.swift` plus untracked Skript (69 Zeilen); Produktcode, `ci.yml`, Scheme unverändert. Code-LoC: 144 + 100 + 4 + 69 = 317, im freigegebenen Rahmen (ca. +330). Skript berührt per `simctl` nur die selbst angelegte `$SIM`.
Code reference: RestockUITests/UITestWait.swift:189

### Runde 2
**Adversary:** Runde 1 war schnell grün. Gegenfragen: (1) Kann ein Fehlschlag grün werden: wertet das Skript Null-Läufe, Übersprünge und Hänger richtig? (2) Ist der Nachweis AC-13 maschinell entstanden oder von Hand zusammengefasst? (3) Wurde der Wiederholungsweg (400) je in einem echten Lauf durchlaufen? (4) Kippt ein Fehlschlag in T2 den nachfolgenden T3? (5) Fängt der Hänger-Schutz einen Hänger vor dem ersten Testergebnis? (6) Ist die Negativprüfung in T1 für Lidl nicht leer?
**Implementierer:** Antworten mit Befund:
- (1) Ja: `PASSED/FAILED/SKIPPED` werden einzeln aus `Test Case`-Zeilen gezählt, `EXECUTED` muss genau 3 sein, ein `STATUS` ungleich 0, die vier Marker „Executed 0 tests", „Restarting after unexpected exit", „TEST EXECUTE FAILED", „HÄNGER-SCHUTZ" und ein übriger Simulator machen Rot. `bash -n` fehlerfrei, Datei ausführbar.
Code reference: scripts/run-appintents-uitest.sh:54
- (2) Teilweise von Hand: Die Protokolle `appintents-*.log` enthalten nur die xcodebuild-Ausgabe; der Ergebnisblock des Skripts (Commit, Zeit, Last) geht auf stdout und steht in `test-green-output.txt` redaktionell zusammengefasst. Inhalt stimmt mit den Protokollen überein (`Executed 3 tests, with 0 failures`, 3 Test-Case-Zeilen je Protokoll), ist aber nicht maschinell persistiert. F001 (LOW).
- (3) Nein: in allen drei Läufen 0 Wiederholungen (`test-green-output.txt`). Der Wiederholungsweg ist nur über `AppIntentRetryTests` mit Scheinuhr belegt; in CLAUDE.md als „unter Last nur abgefangen, nicht erklärt" offen genannt. F002 (LOW, Beobachtung).
- (4) Möglich: scheitert T2 vor dem abschließenden Zurück-Tipp, bleibt die Live Activity für dm bestehen und T3 (Gegenprobe) könnte folgefehlschlagen. Das erzeugt keinen falschen Pass, nur einen Folgefehler. F003 (LOW).
- (5) Nein: Der Wächter greift erst, wenn schon ein „Test Case … passed/failed/skipped" im Protokoll steht. Ein Hänger im ersten Test bliebe unbegrenzt. F004 (LOW).
- (6) T1 prüft vor der Lidl-Negativprüfung `waitForExistence` auf den Titel „Lidl"; die Positivprüfung der dm-Liste davor schließt „Artikel kam nirgends an" aus. Schwach, aber nicht leer.
- Zusatz: Der Kopfkommentar der Klasse nennt alle offenen Grenzen außer „#145 bleibt offen (Durchgang 4)"; der Satz steht in CLAUDE.md und der Spec. Ticketkommentar und Bericht existieren zum Prüfzeitpunkt noch nicht und waren nicht prüfbar. F005 (LOW).

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/run-appintents-uitest.sh:58
  Description: Der Ergebnisblock (Commit, Zeit, Last, Testzahl) wird nur auf stdout ausgegeben, nicht ins Protokoll geschrieben; test-green-output.txt ist eine von Hand erstellte Zusammenfassung.
  Spec requirement: AC-13 — Protokolle samt Messzeilen und Ergebnisblock unter docs/artifacts
  Conflict: Der Beleg ist nicht maschinell entstanden; der Inhalt stimmt aber mit den Rohprotokollen überein.
  Remediation: Ergebnisblock per tee -a "$LOG" mitschreiben.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/UITestWait.swift:202
  Description: Der Wiederholungsweg für Fehler 400 lief in keinem der drei echten Skriptläufe (0 Wiederholungen, auch unter Last); nur Scheinuhr-Tests belegen ihn.
  Spec requirement: AC-5 — Wiederholung mit Messzeile
  Conflict: Kein Verstoß, die Spec verlangt T7/T8 mit Scheinuhr; die Wirkung gegen das echte Framework bleibt unbelegt (in CLAUDE.md offen genannt).
  Remediation: Keine; bei Auftreten im nächsten Lauf die Messzeile auswerten.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/AppIntentsUITests.swift:126
  Description: Schließt T2 die Liste nicht (Fehlschlag vorher), bleibt die Live Activity bestehen; tearDown() terminiert nur die App.
  Spec requirement: AC-8 — kein Seed bleibt im Container
  Conflict: Folgefehler in T3 möglich, kein falsches Grün; der Seed wird geräumt.
  Remediation: Im tearDown() zusätzlich Aktivitäten beenden.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: scripts/run-appintents-uitest.sh:42
  Description: Der Hänger-Schutz wirkt erst nach dem ersten abgeschlossenen Test (grep auf eine Test-Case-Ergebniszeile).
  Spec requirement: AC-11 — Abbruch/Hänger ist Rot
  Conflict: Ein Hänger vor dem ersten Ergebnis wird nicht beendet; der Lauf hielte beide Sperren unbegrenzt.
  Remediation: Zeitmarke ab Teststart statt Bedingung auf ein erstes Ergebnis.

Finding:
  ID: F005
  Severity: LOW
  Category: spec_violation
  Code reference: RestockUITests/AppIntentsUITests.swift:12
  Description: Der Kopfkommentar nennt die offenen Grenzen, aber nicht "#145 bleibt offen (Durchgang 4)".
  Spec requirement: AC-16 — alle genannten Orte nennen die offenen Punkte
  Conflict: Geringe Unvollständigkeit; Ticketkommentar und Bericht fehlen noch und sind beim Abschluss gegen die Liste zu prüfen.
  Remediation: Satz ergänzen.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: RestockUITests/AppIntentsUITests.swift:86
  Evidence: T1 prüft dm-Kachel, dm-Liste und Abwesenheit in Lidl; grün in 3 Skriptläufen (Protokolle 204057/204437/204744).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: RestockUITests/AppIntentsUITests.swift:107
  Evidence: T2 "1 von 2 erledigt", Reihenfolge Zahnpasta erledigt, Duschgel offen; grün in 3 Läufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Intents/CheckOffItemIntent.swift:29
  Evidence: Ohne Live Activity wird nichts gequeut; T3 (Zeile 132) sieht kein "Erledigt"; grün in 3 Läufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: RestockUITests/AppIntentsUITests.swift:63
  Evidence: run() nur als "_ = try await ...run()"; keine Assertion auf dem Ergebnis.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockUITests/UITestWait.swift:194
  Evidence: isNotPresent prüft Domain, Code 400 und Text; Vollauf: 4 AppIntentRetryTests bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: RestockUITests/AppIntentsUITests.swift:1
  Evidence: Bedingung canImport und APPINTENTS_UITESTS; Vollauf Restock-Validate: 606 Tests, Bündel lädt, AppIntentsUITests 0 Tests.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: RestockUITests/AppIntentsUITests.swift:44
  Evidence: Nur -hasCompletedOnboarding YES und -seedQuickAddAssignmentForUITests; kein -developerMode, kein -notificationsEnabled.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: RestockUITests/AppIntentsUITests.swift:25
  Evidence: tearDown() startet mit -clearQuickAddAssignmentSeedForUITests und beendet die App.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/run-appintents-uitest.sh:22
  Evidence: Eigener Versuch: fremde heavy- bzw. loose-Sperre belegt, Abbruch Exit 2, fremde Sperre samt owner unverändert, eigene Sperre freigegeben, kein Simulator.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/run-appintents-uitest.sh:28
  Evidence: Ein build-for-testing mit der einen Zusatzeinstellung; showBuildSettings zeigt DEBUG APPINTENTS_UITESTS; test-without-building mit -only-testing auf AppIntentsUITests.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/run-appintents-uitest.sh:52
  Evidence: Grün nur bei 3 ausgeführten, 0 Fehlschlägen, 0 Übersprüngen, ohne Abbruchmarker (Hänger-Schutz nur eingeschränkt, F004).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/run-appintents-uitest.sh:12
  Evidence: SIGTERM in der Testphase: Simulator gelöscht, Sperren frei, keine Waise; regulär: Schlussprüfung Zeile 56, Restock-Validate Shutdown.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/run-appintents-uitest.sh:58
  Evidence: Drei grüne Läufe, einer unter Last, Protokolle und Zusammenfassung unter docs/artifacts (Einschränkung F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: Restock.xcodeproj/project.pbxproj:762
  Evidence: Vollauf Restock-Validate iOS 26.5: 498 Unit + 108 UI, 0 Fehlschläge, 3 vorgesehene Übersprünge, TEST SUCCEEDED; adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: CLAUDE.md:44
  Evidence: Absatz nennt Klasse, Skript, Sperren, Wegwerf-Simulator iOS 27, Retry-Helfer, APPINTENTS_UITESTS samt Grund, leere Klasse in CI und Bestandssuite.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: CLAUDE.md:44
  Evidence: Alle offenen Grenzen in CLAUDE.md und Kopfkommentar genannt; "#145 bleibt offen" in CLAUDE.md. Lücken siehe F005; Ticketkommentar und Bericht noch nicht prüfbar.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: RestockUITests/UITestWait.swift:189
  Evidence: Nur vier Code-Dateien plus Skript geändert (317 Zeilen), Produktcode, ci.yml und Scheme unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: scripts/run-appintents-uitest.sh:33
  Evidence: simctl-Ziele nur die selbst angelegte UDID; Läufe nur auf Wegwerf-Simulatoren und Restock-Validate.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED — Bestandssuite 603 bestanden, 0 fehlgeschlagen, 3 vorgesehene Übersprünge; alle 18 Punkte belegt; nur 5 LOW-Befunde (F001 bis F005), kein Block. Vorbehalt: Ticketkommentar und Bericht (AC-16) existieren noch nicht.

## Geprüfte Dateien

- sha256:d40511cde0baf2f68e102091c5f2a8560d88341e10382e08113c1ee2e667c21a  CLAUDE.md
- sha256:7867424f2fa57d477f4cedc9726d4b23daf4d6cc294fb94df973a8bd366f5f4b  Restock.xcodeproj/project.pbxproj
- sha256:2180839adf83416b2a1f987e846797fdf7ddf2ea9373086919ce2354aedfb433  RestockUITests/AppIntentsUITests.swift
- sha256:495e33b8669f7ea52fc55b83b86cdd7a67d379151bef93ff7b4020e5cb0e94aa  RestockUITests/UITestWait.swift
- sha256:29567b3388c681089ba9248edd6719678b33a8a34d11e27008d002d44ed0eb8f  SmartCart/Intents/CheckOffItemIntent.swift
- sha256:f65138529d20b3cb3194a57e2b169a41eff9fa12f08d32c2463439b82a82f399  scripts/run-appintents-uitest.sh

## Prüfbasis

- base: 84216469dbd4b4bc5fbb66941a0fc30994a999ee
- blob:fe32c94833a2159e46f3a678d936af42591e00e3  CLAUDE.md
- blob:e5e15d6e398e561d61401a87ae7a579fab2482cc  Restock.xcodeproj/project.pbxproj
- blob:660107931c401e6c5f888c07ff0a79e8d9bfa3ee  RestockUITests/AppIntentsUITests.swift
- blob:f61f8acabf9e926fff42c25ed58e7c9a06f4fc54  RestockUITests/UITestWait.swift
- blob:86fd5502c82c6badeccec4876f9e206a0d3416fe  SmartCart/Intents/CheckOffItemIntent.swift
- blob:49ac1afd8fc72f6e48584d029b2a0e4e35b42043  scripts/run-appintents-uitest.sh
