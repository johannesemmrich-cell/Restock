# Adversary Dialog — fix-166-icloud-einrichtung-sichtbar
Spec: docs/specs/services/icloud-einrichtung-sichtbar.md
Datum: 2026-10-19 09:12

## Checkliste
- [x] **Input:** Einrichtungsereignis der Spiegelung (`type == .setup`) beim App-Start, mit oder ohne Fehler.
- [x] **Output:** Dev-Zeile „iCloud-Abgleich“ zeigt bei gescheiterter Einrichtung „Einrichtung fehlgeschlagen · HH:mm“
- [x] **Side effects:** Beobachter startet früher (liest nur); ein neuer `UserDefaults`-Schlüssel
- [x] **AC-1:** [Unit] GIVEN ein beendetes `.setup`-Ereignis mit Fehler 134400 WHEN `handle` THEN steht es als `lastSetup` (nicht erfolgreich, Code 134400) in der Statusablage, ein laufendes Ereignis ändert nichts. Test: `CloudMirrorMonitorTests::testSetupFailureIsStored`
- [x] **AC-2:** [Unit] GIVEN vorhandene Export-/Import-Läufe WHEN ein `.setup`-Ereignis behandelt wird THEN bleiben Export-Zähler, `lastExport`, `lastImport` und `firstImportFinished` unverändert. Test: `CloudMirrorMonitorTests::testSetupLeavesCountersAndImportUntouched`
- [x] **AC-3:** [Unit] GIVEN eine gescheiterte Einrichtung WHEN danach eine erfolgreiche Einrichtung gemeldet wird THEN ist `lastSetup` erfolgreich und ohne Zusammenfassung. Test: `CloudMirrorMonitorTests::testSetupSuccessReplacesFailure`
- [x] **AC-4:** [Unit] GIVEN die Untertitelfunktion WHEN die Einrichtung fehlgeschlagen ist THEN lautet der Untertitel „Einrichtung fehlgeschlagen · HH:mm“ mit Fehlerkennzeichen, auch bei vorhandenem Export; bei erfolgreicher oder fehlender Einrichtung gilt die bisherige Export-Logik. Test: `CloudMirrorMonitorTests::testSubtitlePrefersFailedSetupOverExport`
- [x] **AC-5:** [Unit] GIVEN Zusammenfassungen WHEN der Klartext bestimmt wird THEN ergibt `NSCocoaErrorDomain` 134400 „kein iCloud-Konto“ und jeder andere Code oder eine andere Domain keinen Klartext. Test: `CloudMirrorMonitorTests::testPlainTextOnlyForKnownSetupCode`
- [x] **AC-6:** [UI] GIVEN gesäte gescheiterte Einrichtung und Entwicklermodus WHEN Einstellungen geöffnet THEN zeigt „iCloud-Abgleich“ „Einrichtung fehlgeschlagen“, und die Detailansicht nennt „Einrichtung (beim App-Start)“, „kein iCloud-Konto“ und „134400“. Test: `ICloudDiagnosticsUITests::testFailedSetupIsShownWithCause`
- [x] **AC-7:** [Unit] GIVEN der Quelltext von `SmartCartApp.init()` WHEN die Reihenfolge geprüft wird THEN steht `CloudMirrorMonitor.shared.start()` vor der ersten Container-Erzeugung (`SharedModelContainer.make()`); Prüfweg: Test liest die Quelldatei über `#filePath` und vergleicht die Positionen (Wettlauf geschlossen, Quelle Apple Forum 701564). Test: `CloudMirrorMonitorTests::testObserverStartsBeforeContainerCreation`
- [x] **AC-8:** [UI] GIVEN das DEBUG-Auslassen von `start()` bei Seed-Argumenten WHEN die bestehenden Diagnose-UI-Tests laufen THEN bleiben `testFailedExportIsShownWithCause`, `testDuplicatesShownAndNothingChanged` und `testRowsHiddenOutsideDeveloperMode` grün (kein Einrichtungsereignis des Simulators überschreibt den Seed). Test: Klasse `ICloudDiagnosticsUITests` im gemeinsamen Lauf
- [x] **AC-9:** [Beleg] GIVEN die App läuft auf dem Simulator `Restock-Validate` ohne iCloud-Konto, im Entwicklermodus und ohne Seed-Argumente WHEN Einstellungen → „iCloud-Abgleich“ geöffnet wird THEN zeigt die Diagnose die gescheiterte Einrichtung mit „NSCocoaErrorDomain 134400“ und „kein iCloud-Konto“ statt „noch kein Lauf“. Beleg: Bildschirmfoto und Protokollauszug aus dem echten Lauf unter `docs/artifacts/fix-166-icloud-einrichtung-sichtbar/`, als Durchlauf-Artefakt registriert (Commit-Kennung und Zeitstempel passend zum Stand).
- [x] **AC-10:** [Unit] GIVEN der Bestand WHEN die Regression läuft THEN bleiben die gesamte Unit-Suite (insbesondere `CloudMirrorMonitorTests` und die Onboarding-Warte-Tests) und die UI-Klassen `ICloudDiagnosticsUITests` und `OnboardingUITests` grün; `RestockShareExtension/` und `SmartCartWidgets/` bleiben unverändert. Test: Unit-Suite und genannte UI-Klassen
- [x] **AC-11:** [Gerät, offene Grenze, kein Gate] Auf Hennings Gerät mit TestFlight-Build erscheint ein echter Einrichtungsfehler oder -erfolg in der Diagnose. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.

## Dialog

### Runde 1
**Adversary:** Alle 14 Punkte gegen Code und Belege geprüft (Unit-Suite 578/0, ICloudDiagnosticsUITests 4/0, OnboardingUITests 1/0, `** TEST SUCCEEDED **`, 0 übersprungen; Auszug in `adversary-test-output.txt`).
- Input/AC-1: `handle` lässt `.setup` durch, `endDate == nil` bleibt verworfen; `runKey(.setup)` schreibt nur `lastSetup`; Zähler nur bei `.export` (guard in `record`). Test `testSetupFailureIsStored` bestanden, prüft laufendes Ereignis, Domain, Code, `clear()`.
Code reference: SmartCart/Services/CloudMirrorMonitor.swift:55
- AC-2/AC-3: `testSetupLeavesCountersAndImportUntouched`, `testSetupSuccessReplacesFailure` bestanden. Schwäche: `XCTAssertFalse(monitor.firstImportFinished)` in T2 ist trivial wahr, weil `start()` nie aufgerufen wird (`startedAt == nil`); die Garantie folgt allein aus dem Code (Setup schreibt nie den Import-Schlüssel), nicht aus dem Assert (F001, LOW).
- AC-4: Vorrang nur bei `!setup.succeeded`; erfolgreiche Einrichtung + Export fehlgeschlagen fällt auf die Export-Logik (im Test mit allen vier Kombinationen geprüft). Settings-Aufruf übergibt beide Läufe.
Code reference: SmartCart/Views/Settings/SettingsView.swift:287
- AC-5: `setupCauseText` prüft Domain UND Code; andere Domain mit 134400 und anderer Code liefern nil (Test belegt).
Code reference: SmartCart/Views/Settings/CloudMirrorStatusView.swift:13
- AC-7: `start()` steht in `init()` vor dem ersten `SharedModelContainer.make()` (Zeile 98) außerhalb des `defer`-Blocks; Test unterscheidet defer korrekt. Das ist der einzige Wettlaufschutz, im Test als Quelltextvergleich belegt (Grenze steht in der Spec). Klammerzählung von T6 ignoriert Klammern in Strings/Kommentaren: eine unbalancierte Klammer vor `make()` würde den Test laut scheitern lassen (XCTUnwrap), nicht still bestehen; ein Kommentar mit „CloudMirrorMonitor.shared.start(“ vor `make()` könnte dagegen fälschlich bestehen (F002, LOW).
Code reference: SmartCart/SmartCartApp.swift:61
- Release-Zweig: `#else let startMirrorMonitor = true`, kein Seed-Code kompiliert; DEBUG lässt `start()` nur bei genau den zwei Seed-Argumenten aus (`isDisjoint`). Seed-Clear-Nebenwirkung: `-seedCloudMirrorStatusForUITests` leert zuerst die gesamte `smartcart.cloudMirror.*`-Ablage, nur in DEBUG und nur mit diesem Argument; die Reihenfolge im `defer` (clear, seed status, seed setup) ist sinnvoll.
Code reference: RestockTests/CloudMirrorMonitorTests.swift:357
**Implementierer:** (Prüfung ohne Implementierer-Eingabe, nur Spec und Belege)

### Runde 2
**Adversary:** Gezielte Gegenprüfung.
- Wettlauf start() vor Container: `start()` nimmt Lock, registriert genau einen Beobachter mit `object: nil`, setzt `startedAt` vor Registrierung; `firstImportFinished` vergleicht `run.date >= startedAt`, früheres `startedAt` kann nur mehr Importe als „nach Start“ zählen, die zwischen früherem Start und altem Startpunkt lagen — das sind echte Importe dieses Prozesses, also korrekt. Share Extension / Widget unverändert (git status leer).
- Abweichung Systemtext: Spec-Prosa (Zeilen 82-85, 38) nennt „Unable to initialize … (CKAccountStatusNoAccount).“; die echte App zeigt „Der Vorgang konnte nicht abgeschlossen werden. (Cocoa-Fehler 134400.)“ (durchlauf-echte-app.txt, Bildschirmfoto durchlauf-diagnose.png). AC-6 und AC-9 fordern nur „kein iCloud-Konto“ (aus der Überschrift, nicht aus dem Systemtext) und „134400“ (Zeile „Fehler, NSCocoaErrorDomain 134400“, Systemtext enthält es ebenfalls). Keine AC verletzt. Der Seed wurde auf das echte Ereignis ohne userInfo korrigiert, damit der UI-Test den realen Fall abbildet; der Widerlegungslauf (lauf2, `localizedFailureReason`) ist dokumentiert. Das ist eine offene Grenze: Spec-Prosa und Entwurf nennen einen Text, der real nie erscheint; Spec nachziehen (F003, LOW). Kein Verdict-Grund.
- Veralteter Fehler: Bei lokalem Fallback-Container (CloudKit-Init scheitert, `make()` liefert lokalen Store) entsteht evtl. kein Einrichtungsereignis; dann bliebe ein früheres `lastSetup`-Fehlerbild mit seinem Zeitstempel stehen. Die Zeit wird mit angezeigt, Dev-only; die Spec-Annahme „jeder Start meldet eine Einrichtung“ ist für diesen Pfad unbelegt (F004, LOW, nicht reproduziert).
- AC-8/AC-10: Die drei Bestands-UI-Tests, der neue Test und `OnboardingUITests` bestanden im gemeinsamen Lauf. AC-9: Beleg echter Lauf ohne Seed (Commit d807fe1 + Patch-Hash 76b6e6ad923f im Artefakt; zeigt „Einrichtung fehlgeschlagen · 09:54“, 134400, „Ursache: kein iCloud-Konto“, nicht „noch kein Lauf“). Hinweis: Der Beleg stammt aus ungesichertem Stand; Commit-Kennung muss nach dem Sichern zum Stand passen (Registrierung als Durchlauf-Artefakt Sache des Orchestrators). AC-11 Gerät: am Gerät nicht belegt, als offene Grenze geführt.
**Implementierer:** (keine Eingabe)

### Findings
- Finding F001: ID F001, Severity LOW, Category: anti_pattern, Code reference: RestockTests/CloudMirrorMonitorTests.swift:283 — Beschreibung: `XCTAssertFalse(monitor.firstImportFinished)` ist ohne `start()` trivial; Spec-Anforderung AC-2; Remediation: Import vorher schreiben und `startedAt` über start-fähige Naht setzen oder den Assert streichen/Kommentar.
- Finding F002: ID F002, Severity LOW, Category: edge_case, Code reference: RestockTests/CloudMirrorMonitorTests.swift:372 — Textsuche kann einen Kommentar treffen; Remediation: Kommentarzeilen vor der Suche entfernen.
- Finding F003: ID F003, Severity LOW, Category: spec_violation (Prosa, keine AC), Code reference: SmartCart/Views/Settings/CloudMirrorStatusView.swift:51 — Spec-Prosa nennt englischen Systemtext, Anzeige zeigt allgemeinen Cocoa-Text; Remediation: Spec/Entwurfstext angleichen, als offene Grenze führen.
- Finding F004: ID F004, Severity LOW, Category: edge_case, Code reference: SmartCart/SmartCartApp.swift:61 — Fehlt beim lokalen Fallback ein Einrichtungsereignis, bleibt ein altes `lastSetup` stehen; Remediation: als offene Grenze in der Spec nennen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Tests: 578 passed, 0 failed, 0 übersprungen (Unit) + ICloudDiagnosticsUITests 4/0 + OnboardingUITests 1/0
Edge cases: geprüft, nur LOW-Findings F001-F004, keine bricht eine AC
Regressions: keine gefunden
Checklist: 14/14 Punkte belegt (AC-11 Gerät offene Grenze, nicht belegt am Gerät)

## Geprüfte Dateien

- sha256:e5bc6945fb87084456c511300d3474b9b8a7fb30e1e5df976be52be4737f655c  RestockTests/CloudMirrorMonitorTests.swift
- sha256:acd2327035e94c65e6af5f1addc48d716da1421e688c76e144333607f2064417  SmartCart/Services/CloudMirrorMonitor.swift
- sha256:0aa16a4b665b88de8a704ddf518c401d703318faedbba407f125ab0763795c62  SmartCart/SmartCartApp.swift
- sha256:7b54b7db8126a42c0de4073f013c5e41e8148565ae040866472ac84c7d66a0e5  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- sha256:a70b59dd340decf83f452349063cd6fab832c411802d5327dacefaddfd6a1a30  SmartCart/Views/Settings/SettingsView.swift

## Prüfbasis

- base: 39910eb03fc70e0518d5e890e114f5753a50dbe9
- blob:013fc4585e9f2643cc2f20870d7601de8f1f4e44  RestockTests/CloudMirrorMonitorTests.swift
- blob:5bc6b34907d476f71d679799c9afd07855271ad6  SmartCart/Services/CloudMirrorMonitor.swift
- blob:4a4768edfe644a9174c2306c17d2e09bc8488b74  SmartCart/SmartCartApp.swift
- blob:a531fca76aa82871e3c3efb924bac7f0c706bf89  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- blob:ce2def8f8e6ce3c03f48ab1d6d854e1a58ac6d58  SmartCart/Views/Settings/SettingsView.swift
