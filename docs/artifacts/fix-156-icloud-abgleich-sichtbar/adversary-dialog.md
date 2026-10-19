# Adversary Dialog — fix-156-icloud-abgleich-sichtbar
Spec: docs/specs/services/icloud-abgleich-sichtbar.md
Datum: 2026-10-18 20:31

## Checkliste
- [x] **Input:** Export-/Import-Ereignisse der Spiegelung, Zustand der Läden, Start der Ersteinrichtung, Beitritt zu
- [x] **Output:** Diagnosezeilen im Entwicklermodus; Ersteinrichtung wartet höchstens 10 s auf Läden aus iCloud;
- [x] **Side effects:** Zusätzlicher Beobachter im App-Prozess; neue `UserDefaults`-Schlüssel
- [x] AC-1 [Unit]: GIVEN ein `partialFailure` mit `batchRequestFailed`-Einträgen und einem Einzelfehler WHEN `summarize` THEN wird nur der Einzelfehler samt Zahl der Einträge gemeldet. Test: `CloudMirrorMonitorTests::testPartialFailureReportsNonBatchError`
- [x] AC-2 [Unit]: GIVEN nur `batchRequestFailed` oder ein Fehler ohne Teilfehler, auch in `NSUnderlyingError` WHEN `summarize` THEN wird der oberste Fehler bzw. der verschachtelte Einzelfehler gemeldet. Test: `CloudMirrorMonitorTests::testFallbackAndUnderlyingError`
- [x] AC-3 [Unit]: GIVEN „… in production schema“ WHEN `summarize` THEN Art `schemaIncomplete`. Test: `CloudMirrorMonitorTests::testProductionSchemaTextIsClassified`
- [x] AC-4 [Unit]: GIVEN beendete Export-/Import-Ereignisse WHEN `handle` THEN speichert die Statusablage Zeit, Zusammenfassung und Zähler; laufende Ereignisse ändern nichts. Test: `CloudMirrorMonitorTests::testHandlePersistsOnlyFinishedEvents`
- [x] AC-5 [Unit]: GIVEN eine App-Erweiterung bzw. die App WHEN `shouldObserve` THEN false bzw. true. Test: `CloudMirrorMonitorTests::testObserveOnlyInAppProcess`
- [x] AC-6 [UI]: GIVEN ein gesäter fehlgeschlagener Export und Entwicklermodus WHEN Einstellungen geöffnet THEN zeigt „iCloud-Abgleich“ „Export fehlgeschlagen“ und die Detailansicht nennt die Ursache „CD_ShoppingItem“. Test: `ICloudDiagnosticsUITests::testFailedExportIsShownWithCause`
- [x] AC-7 [UI]: GIVEN `-developerMode NO` WHEN Einstellungen geöffnet THEN erscheinen weder „iCloud-Abgleich“ noch „Doppelte Läden“. Test: `ICloudDiagnosticsUITests::testRowsHiddenOutsideDeveloperMode`
- [x] AC-8 [Unit]: GIVEN gleiche `shareID`, Preset-Namen mit Groß/Klein-, Leerzeichen- oder Diakritikunterschied und gleichnamige eigene Läden WHEN `groups` THEN entstehen Gruppen der Klassen 1, 2 und 3 (Klasse 3 nur melden). Test: `StoreDuplicateFinderTests::testClassesOneToThree`
- [x] AC-9 [Unit]: GIVEN gleicher Name in anderem Land, geteilter Laden neben Preset und die 17 DE-Presets WHEN `groups` THEN keine Gruppe. Test: `StoreDuplicateFinderTests::testNoFalsePositives`
- [x] AC-10 [Unit]: GIVEN eine Gruppe in beliebiger Reihenfolge WHEN `winner` THEN immer die kleinste UUID. Test: `StoreDuplicateFinderTests::testWinnerIsSmallestUUIDRegardlessOfOrder`
- [x] AC-11 [UI]: GIVEN ein gesätes Preset-Doppel WHEN „Doppelte Läden“ geöffnet THEN zeigt die Ansicht eine Doppelgruppe mit „bliebe“, und die Ladenanzahl bleibt unverändert (nichts gelöscht, nichts zusammengeführt). Test: `ICloudDiagnosticsUITests::testDuplicatesShownAndNothingChanged`
- [x] AC-12 [Unit]: GIVEN die neuen Dateien WHEN nach `delete(` gesucht wird THEN kein Treffer. Test: `StoreDuplicateFinderTests::testNewFilesNeverDelete`
- [x] AC-13 [Unit]: GIVEN kein Konto / Konto ohne Import nach 3 s / nach 10 s / Import fertig ohne Läden / Läden vorhanden WHEN `OnboardingCloudGate.decision` THEN `.proceed` / `.wait` / `.proceed` / `.proceed` / `.skipOnboarding`. Test: `CloudMirrorMonitorTests::testOnboardingGateDecisions`
- [x] AC-14 [UI]: GIVEN simulierten Import (4 s) WHEN die App neu startet THEN ist der Hinweis „Deine Läden werden aus iCloud geladen …“ sichtbar, „Loslegen“ gesperrt und spätestens nach 10 s aktiv. Test: `OnboardingCloudWaitUITests::testHintAndLockedButtonUntilImportDone`
- [x] AC-15 [UI]: GIVEN simuliert eintreffende Läden WHEN die App neu startet THEN entfällt die Einrichtung, die Startseite zeigt die Läden genau einmal und bleibt nach Neustart ohne Argument. Test: `OnboardingCloudWaitUITests::testArrivingStoresSkipOnboarding`
- [x] AC-16 [UI]: GIVEN Simulator ohne iCloud-Konto WHEN das Onboarding startet THEN gibt es kein Warten (der bestehende Durchlauf bleibt unverändert grün). Test: `OnboardingUITests::testOnboardingWalkthroughCreatesChosenStoresAndName` (unverändert)
- [x] AC-17 [Unit]: GIVEN vorhandene Läden WHEN die Einfügelogik von `finishOnboarding` und `seedStores` läuft THEN werden nur fehlende Presets eingefügt, vorhandene bleiben unverändert (17 bleiben 17; bei 10 vorhandenen genau 7 neu). Test: `StoreDuplicateFinderTests::testOnboardingInsertsOnlyMissingPresets` und `::testSeedStoresInsertsOnlyMissingPresets`
- [x] AC-18 [Unit]: GIVEN ein Laden mit `shareID` X WHEN Beitritt zu X THEN wird derselbe Laden wiederverwendet. Test: `StoreDuplicateFinderTests::testJoinReusesStoreWithSameShareID`
- [x] AC-19 [Beleg]: `docs/cloudkit/private-schema-aktuell.ckdb` enthält `"CD_photoData_ckAsset" ASSET` in `CD_ShoppingItem`; `diff` zwischen Export vor und nach dem Import zeigt nur dieses Feld, `validate-schema` ohne Fehler, Dashboard-Diff vor dem Deploy zeigt nur dieses Feld, Production-Export enthält es, Management-Token entfernt (`remove-token --type management`, kein Tokenwert im Repo). Test (automatisch): `MirroredSchemaSnapshotTests::testPhotoDataAssetFieldIsListed` (rot vor dem Import, grün danach)
- [x] AC-20 [Gerät, offene Grenze, kein Gate]: Mit TestFlight-Build auf Hennings Gerät erscheint der Exportstatus, und eine Neuinstallation erzeugt keine Doppel. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.
- [x] AC-21 [Unit]: GIVEN der Bestand WHEN die Regression läuft THEN bleiben `MirroredSchemaSnapshotTests` T1–T3, `SchemaCloudKitCompatibilityTests`, `ExistingDataSurvivesCloudEnableTests`, `SharedModelContainerExtensionDetectionTests` und die UI-Klassen `OnboardingUITests`, `StoreSetupUITests`, `DeveloperModeUnlockUITests` grün; `RestockShareExtension/` und `SmartCartWidgets/` unverändert. Test: gesamte Unit-Suite und genannte UI-Klassen

## Testläufe (Belege im selben Ordner)
- Unit (adversary-unit-output.txt): Lauf 1: 536 Tests, 1 Failure (T19, damals erwartet); Lauf 2 nach Schema-Import: 536 Tests, 0 Failures, TEST SUCCEEDED, 0 Neustarts, 0 übersprungen. StoreDuplicateFinderTests 7/7 grün, CloudMirrorMonitorTests grün.
- UI (adversary-ui-output.txt): 16 Tests, 0 Failures, TEST SUCCEEDED (OnboardingUITests 1, StoreSetupUITests 8, DeveloperModeUnlockUITests 2, ICloudDiagnosticsUITests 3, OnboardingCloudWaitUITests 2).
- Release-Build (adversary-release-build.txt): BUILD SUCCEEDED, keine Fehler.
- RestockShareExtension/ und SmartCartWidgets/ stehen nicht in der Änderungsliste gegen den RED-Stand: unverändert. Neue Dateien nur in der Sources-Phase des App-Ziels (pbxproj, dieselbe Phase wie RecipeRecognitionService).

## Dialog

### Runde 1
**Adversary:** Jeder Punkt wird gegen Code und Testausgabe geprüft, nicht gegen die Behauptung.

Confirmation:
  AC: AC-1, AC-2, AC-3
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:67
  Evidence: summarize filtert batchRequestFailed heraus, meldet failed.first plus failed/total, fällt auf den obersten Fehler zurück, sucht Teilfehler über die NSUnderlyingError-Kette (Tiefe 8); classify erkennt "production schema". Die drei Tests sind grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, Side effects (Schlüssel smartcart.cloudMirror.*, Thread-Sicherheit, Logger)
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:54
  Evidence: handle verwirft endDate == nil und andere Typen als export/import (Zeile 55); Fehlertext im Logger privacy .private, Domain/Code .public (Zeile 58); record (Zeile 179) und clear (Zeile 190) unter NSLock. testHandlePersistsOnlyFinishedEvents grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5 (nur App-Prozess, nur einmal registriert)
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:32
  Evidence: start() hält den Lock, prüft observer == nil und shouldObserve; ein zweiter Aufruf ist wirkungslos. testObserveOnlyInAppProcess grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5 Einbindung, DEBUG-Argumente nur unter #if DEBUG, Seed/Aufräumer-Paare
  Code reference: SmartCart/SmartCartApp.swift:30
  Evidence: CloudMirrorMonitor.shared.start() steht im defer außerhalb von #if DEBUG. Seed-/Clear-/Simulate-Funktionen (Zeilen 531, 546, 587) liegen im #if DEBUG-Block (175 bis 829). Paare: seedCloudMirrorStatus/clearCloudMirrorStatus, seedDuplicateStores/clearDuplicateStores; simulateCloudImport und simulateCloudStoresArrive räumt -clearOnboardingForUITests auf (tearDown beider UI-Klassen). Release-Build kompiliert.
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-7
  Code reference: SmartCart/Views/Settings/SettingsView.swift:284
  Evidence: Beide NavigationLinks liegen im if developerMode-Zweig (Zeile 258); Untertitel aus devRowSubtitle. testFailedExportIsShownWithCause und testRowsHiddenOutsideDeveloperMode grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6 Detailansicht
  Code reference: SmartCart/Views/Settings/CloudMirrorStatusView.swift:7
  Evidence: Ursache-Abschnitt zeigt summary.detail (enthält CD_ShoppingItem), .devFeedback gesetzt, keine Behauptung "alles in Ordnung".
  Status: CONFIRMED

Confirmation:
  AC: AC-8, AC-9, AC-10, AC-12
  Code reference: SmartCart/Services/StoreDuplicateService.swift:72
  Evidence: groups bildet Klasse 1 (shareID), 2 (nicht eigen, Land, normalisierter Name; geteilte Läden per presetKey ausgeschlossen), 3 (eigene, nur melden); winner (Zeile 89) = kleinste UUID, reihenfolgeunabhängig; kein delete( in den vier neuen Dateien (grep leer). Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11 (nichts gelöscht, nichts zusammengeführt)
  Code reference: SmartCart/Views/Settings/StoreDuplicatesView.swift:10
  Evidence: View liest per @Query und bildet Snapshots, keine Schreib- oder Löschaufrufe. testDuplicatesShownAndNothingChanged grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:208
  Evidence: decision: kein Konto -> proceed; storeCount > 0 -> skipOnboarding; Import fertig oder elapsed >= 10 -> proceed; sonst wait. Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-15, AC-16 (Warten, Polling, skipOnboarding setzt nur hasCompletedOnboarding)
  Code reference: SmartCart/Views/Settings/OnboardingView.swift:159
  Evidence: runCloudGate pollt alle 250 ms und endet bei Schritt != 0, hasCompletedOnboarding oder nach 10 s; skipOnboarding setzt ausschließlich hasCompletedOnboarding = true (Land und Name unberührt); die Argumentreihenfolge (firstImportFinished vor fetchCount) verhindert "Import fertig, Läden noch nicht gesehen". OnboardingCloudWaitUITests (2) grün, OnboardingUITests unverändert grün (kein Warten ohne Konto).
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Views/Settings/OnboardingView.swift:368
  Evidence: finishOnboarding ruft StoreSeeding.insertMissingPresets; seedStores ebenso (SettingsView.swift:425). presetStores ist @State (Zeile 13), die vorherige isActive-Zuweisung wirkt auf dieselben Instanzen. Beide Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-17 Kern (nur fehlende Presets, Bestand unverändert)
  Code reference: SmartCart/Services/StoreDuplicateService.swift:107
  Evidence: insertMissingPresets fügt nur Kennungen aus missingPresets (Zeile 94) ein; bestehende Läden werden nicht angefasst.
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: SmartCart/Views/Store/StoreShareSheet.swift:386
  Evidence: existingStore(shareID:) wird vor dem Pull gesucht; bei Treffer wird der Laden aktualisiert statt ein zweiter angelegt. testJoinReusesStoreWithSameShareID grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: Restock.xcodeproj/project.pbxproj:1045
  Evidence: neue Dateien nur in der App-Sources-Phase; Unit 535 von 536 grün (einziger Fehler T19), UI 16 von 16 grün, ShareExtension/Widgets unverändert.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Settings/OnboardingView.swift:141
  Description: cloudDecision startet bei .proceed, accountAvailable bei false (Zeile 19); die Kontoabfrage läuft in eigenem Task parallel zum Gate-Task (Zeilen 141 und 142). Bis accountStatus() antwortet, ist "Loslegen" aktiv.
  Spec requirement: AC-13 / B2.1 — mit Konto warten; Startwert "kein Konto bis Antwort" ist so vorgesehen
  Conflict: Ein schneller Tipp in diesem Fenster umgeht das Warten und erzeugt die Doppel, die B2 verhindern soll. Spec-konform, aber Restlücke.
  Remediation: Optional Startwert .wait bis zur Kontoantwort (Frist 10 s bleibt).

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:47
  Description: firstImportFinished wird auch durch einen fehlgeschlagenen Import wahr, weil handle jeden beendeten Import speichert.
  Spec requirement: AC-13 — "Import fertig ohne Läden -> proceed" (Spec: Ereignis "Import beendet")
  Conflict: Offline oder bei Importfehler geht die Einrichtung sofort weiter, Presets entstehen, später eintreffende iCloud-Läden werden Doppel. Spec-konform, Doppel möglich.
  Remediation: Nur erfolgreiche Importe als "fertig" zählen, 10 s bleibt Obergrenze.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:67
  Description: summarize wählt bei mehreren Nicht-batchRequestFailed-Teilfehlern failed.first aus byID.values (Dictionary-Reihenfolge, nicht deterministisch).
  Spec requirement: AC-1 — gemeldet wird der Eintrag, der nicht batchRequestFailed ist
  Conflict: Bei verschiedenen Ursachen kann die angezeigte Ursache zwischen Läufen wechseln (die Zahl failedItemCount bleibt richtig).
  Remediation: Nach Domain/Code sortieren oder häufigste Ursache wählen.

### Runde 2
**Adversary:** Zweiter Durchgang gezielt auf Randfälle statt auf die gemeldeten Tests.

Probe 1, Beobachter/Thread: start() ist per Lock gegen Doppelregistrierung geschützt; handle schreibt nur über record (Lock) in UserDefaults.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/Services/CloudMirrorMonitor.swift:18
  Description: startedAt ist private(set) var, wird in firstImportFinished (Zeile 47) ohne Lock gelesen und in start() unter Lock geschrieben.
  Spec requirement: Thread-Sicherheit
  Conflict: Theoretisch ungeschützter Lesezugriff; durch Startreihenfolge (start vor UI) praktisch entschärft.
  Remediation: Lesen unter Lock.

Probe 2, Beitritt: Zwischen existing (Zeile 386) und der Nutzung nach dem Netzaufruf kann der Laden gelöscht worden sein.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Store/StoreShareSheet.swift:386
  Description: Das Store-Objekt wird vor dem Netzaufruf geholt und danach unverändert benutzt (Name, apply, addMember). Ein zwischenzeitlich gelöschter Laden würde weiter beschrieben. Die Meldung "bereits beigetreten" entfällt; der Schlüssel share.join.alreadyjoined.format steht ungenutzt in beiden Localizable.strings.
  Spec requirement: AC-18 — wiederverwenden statt zweiten anlegen
  Conflict: Randfall, spec-konform; toter Textschlüssel.
  Remediation: existing nach dem await erneut auflösen; toten Schlüssel entfernen.

Probe 3, Fehlerpfad der Einrichtung.

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Settings/OnboardingView.swift:368
  Description: try? schluckt einen Fehler von insertMissingPresets (fetch oder save); danach wird hasCompletedOnboarding = true gesetzt. Schlägt der fetch fehl, entstehen keine Läden bei abgeschlossener Einrichtung.
  Spec requirement: AC-17 — fehlende Presets einfügen
  Conflict: Sehr unwahrscheinlich; vorher war save() mit try? ebenso stumm.
  Remediation: Fehler protokollieren; Flag nur bei Erfolg setzen.

Probe 4, Löschen/Zusammenführen: grep nach delete( in den neuen Dateien leer; das einzige context.delete im Diff ist removeDuplicateSeed (DEBUG, nur feste Seed-Kennungen).
Code reference: SmartCart/Services/StoreDuplicateService.swift:121

Probe 5, Release-Build ohne DEBUG-Teile: OnboardingCloudSimulation.current ist ohne DEBUG nil; BUILD SUCCEEDED.
Code reference: SmartCart/Views/Settings/StoreDuplicatesView.swift:46

**Implementierer:** Keine Antwort (isolierter Prüfer). F001 bis F006 sind LOW, keiner blockiert ein AC.

### Runde 3
**Adversary:** AC-19 gegen neue Belege geprüft.

Confirmation:
  AC: AC-19
  Code reference: docs/cloudkit/private-schema-aktuell.ckdb:62
  Evidence-Fortsetzung: Entwicklungsprotokoll mit 1 Zeile Unterschied und gültigem Schema, danach genau dieses Feld neu. Produktionsprotokoll: Export enthält das Feld in Zeile 62, Entwicklung und Produktion gleich.
  Evidence: Zeile 62 im Record-Typ CD_Shopping-Item lautet CD_photoData_ckAsset ASSET; die Datei unterscheidet sich vom Vorstand nur in dieser Zeile.
  Weitere Belege: Dashboard-Freigabe durch den PO bestätigt, Inhaltsbeleg ist der Produktionsexport. Unit-Lauf neu: 536 Tests, 0 Failures, TEST SUCCEEDED (T19 grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-19 Token-Hygiene und Abweichung
  Code reference: docs/testflight-setup.md:33
  Evidence: Suche nach Zeichenfolgen mit 32 oder mehr Base64/Hex-Zeichen in docs/cloudkit, docs/testflight-setup.md und beiden cktool-Protokollen ergibt nur Pfade und Prosa, keinen Tokenwert; die Protokolle nennen den Wert ausdrücklich nicht. Abweichung: remove-token entfällt auf ausdrückliche PO-Anweisung vom 2026-10-18 (Token dauerhaft im Schlüsselbund). Das ist eine PO-Entscheidung, kein Defekt; testflight-setup.md ist entsprechend geändert.
  Status: CONFIRMED

AC-20 bleibt offene Grenze (am Gerät nicht belegt).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (precondition_origins.default_lang). Keine Tabelle angehängt; manuell: smartcart.cloudMirror.* wird nur in CloudMirrorStatusStore.record geschrieben (Bedingung davor: beendetes Export-/Import-Ereignis, endDate != nil; Test für diesen Weg: CloudMirrorMonitorTests::testHandlePersistsOnlyFinishedEvents). hasCompletedOnboarding wird bei skipOnboarding nur gesetzt, wenn Konto vorhanden und storeCount > 0 (Test für diesen Weg: OnboardingCloudWaitUITests::testArrivingStoresSkipOnboarding).

## Verdict

AC-19 bewiesen (Schema in Entwicklung und Produktion, T19 grün, Token-Abweichung = PO-Entscheidung). AC-20 offene Grenze, am Gerät nicht belegt. Alle anderen Punkte bewiesen; F001 bis F006 sind LOW.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:412601e090e0d02cf9402c939d62bbc4c9265325e5422322a1c8d7c3b74f7900  Restock.xcodeproj/project.pbxproj
- sha256:2f8ae1c307eb3bcb7ebb66dc34b64553b95d8ea840cf2cc63a3ef12efcd6c23c  SmartCart/Services/CloudMirrorMonitor.swift
- sha256:f3cc71e991778ec8f58275a13d6a7339deac445bf864b7ca36351233cf386759  SmartCart/Services/StoreDuplicateService.swift
- sha256:fad6e5bcdedc7bdf8d2079f7d09465667b84837608be097b3c2955ea6bc12e52  SmartCart/SmartCartApp.swift
- sha256:07b20c399a9ffc092a9d3a5c3a1ef718e746397bbb852a7636159a289973270d  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- sha256:ca3db2cd19c2fb7fb560fc0e817d8307ae591b6ebb2fb7fe44429afa1eac04b1  SmartCart/Views/Settings/OnboardingView.swift
- sha256:d215ed9fb36147e92d24124a460bb8a05209091c4a02cbac9824a4e38f1aaf5f  SmartCart/Views/Settings/SettingsView.swift
- sha256:b97ae3d8ef5b4cde51f65f7ff709a86609699631433dbc15420fa5d8cdaf08c7  SmartCart/Views/Settings/StoreDuplicatesView.swift
- sha256:797aad32d0584083abf1fbc9b157bedbdfc2da96ea05238beb0de87dc372be50  SmartCart/Views/Store/StoreShareSheet.swift

## Prüfbasis

- base: 58d95df450dcb2ea35c997d571bb0c4252c7a708
- blob:ca439ac8848a7f020b99dfb0c87b7dab6ed976a1  Restock.xcodeproj/project.pbxproj
- blob:c341f27963287250dbed97cb7deed30b1866ac08  SmartCart/Services/CloudMirrorMonitor.swift
- blob:43cd165c75522af84b8090542cedef5147075219  SmartCart/Services/StoreDuplicateService.swift
- blob:fe9417f7ec8268fb5493854132ecfacb7bbcf773  SmartCart/SmartCartApp.swift
- blob:04e56ba253679a47c58529e752f7cae81fd96a44  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- blob:5883fa29e10c0f4781073553e7e2a28cbecd410c  SmartCart/Views/Settings/OnboardingView.swift
- blob:7485b709a64bc7be63f86982d34a0f9b6795722d  SmartCart/Views/Settings/SettingsView.swift
- blob:83e0b91028e43cbbd0d5f7890593fbb31bb3d961  SmartCart/Views/Settings/StoreDuplicatesView.swift
- blob:061235aec2a1386806f205ed924c9db97173f883  SmartCart/Views/Store/StoreShareSheet.swift

## Geprüfte Dateien

- sha256:412601e090e0d02cf9402c939d62bbc4c9265325e5422322a1c8d7c3b74f7900  Restock.xcodeproj/project.pbxproj
- sha256:2f8ae1c307eb3bcb7ebb66dc34b64553b95d8ea840cf2cc63a3ef12efcd6c23c  SmartCart/Services/CloudMirrorMonitor.swift
- sha256:f3cc71e991778ec8f58275a13d6a7339deac445bf864b7ca36351233cf386759  SmartCart/Services/StoreDuplicateService.swift
- sha256:fad6e5bcdedc7bdf8d2079f7d09465667b84837608be097b3c2955ea6bc12e52  SmartCart/SmartCartApp.swift
- sha256:07b20c399a9ffc092a9d3a5c3a1ef718e746397bbb852a7636159a289973270d  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- sha256:ca3db2cd19c2fb7fb560fc0e817d8307ae591b6ebb2fb7fe44429afa1eac04b1  SmartCart/Views/Settings/OnboardingView.swift
- sha256:d215ed9fb36147e92d24124a460bb8a05209091c4a02cbac9824a4e38f1aaf5f  SmartCart/Views/Settings/SettingsView.swift
- sha256:b97ae3d8ef5b4cde51f65f7ff709a86609699631433dbc15420fa5d8cdaf08c7  SmartCart/Views/Settings/StoreDuplicatesView.swift
- sha256:797aad32d0584083abf1fbc9b157bedbdfc2da96ea05238beb0de87dc372be50  SmartCart/Views/Store/StoreShareSheet.swift

## Prüfbasis

- base: 58d95df450dcb2ea35c997d571bb0c4252c7a708
- blob:ca439ac8848a7f020b99dfb0c87b7dab6ed976a1  Restock.xcodeproj/project.pbxproj
- blob:c341f27963287250dbed97cb7deed30b1866ac08  SmartCart/Services/CloudMirrorMonitor.swift
- blob:43cd165c75522af84b8090542cedef5147075219  SmartCart/Services/StoreDuplicateService.swift
- blob:fe9417f7ec8268fb5493854132ecfacb7bbcf773  SmartCart/SmartCartApp.swift
- blob:04e56ba253679a47c58529e752f7cae81fd96a44  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- blob:5883fa29e10c0f4781073553e7e2a28cbecd410c  SmartCart/Views/Settings/OnboardingView.swift
- blob:7485b709a64bc7be63f86982d34a0f9b6795722d  SmartCart/Views/Settings/SettingsView.swift
- blob:83e0b91028e43cbbd0d5f7890593fbb31bb3d961  SmartCart/Views/Settings/StoreDuplicatesView.swift
- blob:061235aec2a1386806f205ed924c9db97173f883  SmartCart/Views/Store/StoreShareSheet.swift

## Geprüfte Dateien

- sha256:412601e090e0d02cf9402c939d62bbc4c9265325e5422322a1c8d7c3b74f7900  Restock.xcodeproj/project.pbxproj
- sha256:2f8ae1c307eb3bcb7ebb66dc34b64553b95d8ea840cf2cc63a3ef12efcd6c23c  SmartCart/Services/CloudMirrorMonitor.swift
- sha256:f3cc71e991778ec8f58275a13d6a7339deac445bf864b7ca36351233cf386759  SmartCart/Services/StoreDuplicateService.swift
- sha256:fad6e5bcdedc7bdf8d2079f7d09465667b84837608be097b3c2955ea6bc12e52  SmartCart/SmartCartApp.swift
- sha256:07b20c399a9ffc092a9d3a5c3a1ef718e746397bbb852a7636159a289973270d  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- sha256:ca3db2cd19c2fb7fb560fc0e817d8307ae591b6ebb2fb7fe44429afa1eac04b1  SmartCart/Views/Settings/OnboardingView.swift
- sha256:d215ed9fb36147e92d24124a460bb8a05209091c4a02cbac9824a4e38f1aaf5f  SmartCart/Views/Settings/SettingsView.swift
- sha256:b97ae3d8ef5b4cde51f65f7ff709a86609699631433dbc15420fa5d8cdaf08c7  SmartCart/Views/Settings/StoreDuplicatesView.swift
- sha256:797aad32d0584083abf1fbc9b157bedbdfc2da96ea05238beb0de87dc372be50  SmartCart/Views/Store/StoreShareSheet.swift
- sha256:4ae78de7fd33819ad6bd6c7d02aabf2b224c8bf25d0a33b3509f4ae98ce88760  docs/cloudkit/private-schema-aktuell.ckdb
- sha256:05bb69eeb114c5b0e71baa4b7b1cab283095e1504d9ef8c3407b7327f843194e  docs/testflight-setup.md

## Prüfbasis

- base: 58d95df450dcb2ea35c997d571bb0c4252c7a708
- blob:ca439ac8848a7f020b99dfb0c87b7dab6ed976a1  Restock.xcodeproj/project.pbxproj
- blob:c341f27963287250dbed97cb7deed30b1866ac08  SmartCart/Services/CloudMirrorMonitor.swift
- blob:43cd165c75522af84b8090542cedef5147075219  SmartCart/Services/StoreDuplicateService.swift
- blob:fe9417f7ec8268fb5493854132ecfacb7bbcf773  SmartCart/SmartCartApp.swift
- blob:04e56ba253679a47c58529e752f7cae81fd96a44  SmartCart/Views/Settings/CloudMirrorStatusView.swift
- blob:5883fa29e10c0f4781073553e7e2a28cbecd410c  SmartCart/Views/Settings/OnboardingView.swift
- blob:7485b709a64bc7be63f86982d34a0f9b6795722d  SmartCart/Views/Settings/SettingsView.swift
- blob:83e0b91028e43cbbd0d5f7890593fbb31bb3d961  SmartCart/Views/Settings/StoreDuplicatesView.swift
- blob:061235aec2a1386806f205ed924c9db97173f883  SmartCart/Views/Store/StoreShareSheet.swift
- blob:7688a33a190c2681a928e6e8174eaafbb1236326  docs/cloudkit/private-schema-aktuell.ckdb
- blob:88fe8a4807bdc97d2610dd3d63dfd095ea64664f  docs/testflight-setup.md
