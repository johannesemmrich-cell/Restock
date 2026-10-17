# Adversary Dialog — fix-150-checkoff-intent-verbergen
Spec: docs/specs/services/checkoff-intent-verbergen.md
Datum: 2026-10-17 08:36

## Checkliste
- [x] AC-1: GIVEN die vom Build erzeugten Metadaten der App (`Restock.app/Metadata.appintents/extract.actionsdata`), WHEN `CheckOffItemIntent` gelesen wird, THEN steht dort `isDiscoverable == false`. Test: T1.
- [x] AC-2: GIVEN die Metadaten der Widget-Erweiterung (`PlugIns/SmartCartWidgets.appex/Metadata.appintents/extract.actionsdata`), WHEN `CheckOffItemIntent` gelesen wird, THEN steht dort `isDiscoverable == false`. Test: T1.
- [x] AC-3: GIVEN dieselben App-Metadaten, WHEN `AddShoppingItemIntent` gelesen wird, THEN bleibt er auffindbar (`isDiscoverable == true`), und ein nicht vorhandener Intent-Name führt zu einem Testfehler statt zu einem stillen Ergebnis (Gegenprobe gegen kaputtes Lesen). Test: T2.
- [x] AC-4: GIVEN der Skriptlauf `scripts/run-appintents-uitest.sh` auf iOS 27.0, WHEN er nach der Änderung läuft, THEN sind genau 3 Tests gelaufen, 0 Fehlschläge, 0 Übersprungene, 0 Wiederholungen wegen Fehler 400; `testCheckOffIntentChecksFirstItem` ergibt „1 von 2 erledigt“ (verborgener Befehl wirkt mit laufender Live Activity). Test: T3.
- [x] AC-5: GIVEN `testCheckOffWithClosedListChangesNothing`, WHEN er nach der Änderung unverändert läuft, THEN ist er grün („0 von 2 erledigt“ bei geschlossener Liste). Der Test wird nicht geändert (Abweichung vom Ticket, oben benannt). Test: T3, T5 (kein Diff am Testrumpf, nur Kopfkommentar).
- [x] AC-6: GIVEN `perform()` von `CheckOffItemIntent`, WHEN der Diff geprüft wird, THEN ist das Verhalten unverändert: die einzige Produktänderung in `SmartCart/` ist die Eigenschaft `isDiscoverable = false` samt Kommentar. Test: T5.
- [x] AC-7: GIVEN die Aufrufer in `SmartCartWidgets/ShoppingLiveActivity.swift` (Zeilen 55 und 133), WHEN der Diff geprüft wird, THEN sind sie unverändert und rufen weiter `Button(intent: CheckOffItemIntent(storeName:))` auf. Test: T5.
- [x] AC-8: GIVEN die Bestandssuite auf `Restock-Validate`, WHEN sie nach der Änderung läuft, THEN ist sie grün (Unit und UI), Testzahl entspricht der bisherigen plus den 2 neuen Unit-Tests, kein Abbruch. Test: T4.
- [x] AC-9: GIVEN der Durchlauf im Simulator, WHEN die Metadaten des installierten Stands gelesen werden, THEN ist `CheckOffItemIntent` in App und Widget-Erweiterung als nicht auffindbar eingetragen, die Ausgabe liegt unter `docs/artifacts/fix-150-checkoff-intent-verbergen/`. Test: Durchlauf.
- [x] AC-10: GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens `CheckOffItemIntent.swift`, `CheckOffIntentVisibilityTests.swift`, `project.pbxproj`, `AppIntentsUITests.swift` (nur Kopfkommentar) und `CLAUDE.md` (plus Spec und Artefakte), ca. +60/−3 LoC; keine Änderung an `ci.yml`, Scheme, `Info.plist`. Test: T5.
- [x] AC-11: GIVEN `CLAUDE.md` und der Kopfkommentar von `AppIntentsUITests.swift`, WHEN sie geprüft werden, THEN beschreiben sie „stiller Erfolg ohne Wirkung“ als durch #150 für Nutzer nicht mehr erreichbar (Befehl verborgen) und nennen die offenen Grenzen (Kurzbefehle-App-Oberfläche und Tipp auf den Knopf nicht automatisiert geprüft). Test: T5 (Review).
- [x] AC-12: GIVEN der gesamte Durchgang, WHEN Schritte ausgeführt werden, THEN startet, installiert oder liest keiner ein Gerät des Users; Läufe nur auf Wegwerf-Simulatoren bzw. `Restock-Validate`.

## Dialog

### Runde 1
**Adversary:** Ich unterstelle, dass die Änderung nichts bewirkt oder der Test durch falsches Lesen grün wird. Geprüft:
- Diff gegen c901ae5 (inkl. Index): Produktänderung in SmartCart/ ist exakt eine Eigenschaft samt Kommentar, `perform()` unberührt (AC-6). `SmartCartWidgets/` ohne Diff; Aufrufer `ShoppingLiveActivity.swift:55` und `:133` rufen weiter `Button(intent: CheckOffItemIntent(storeName:))` (AC-7). Kein Diff an `.github`, Schemes, Plists (AC-10). Dateien: CheckOffItemIntent.swift (+3), CheckOffIntentVisibilityTests.swift (+66), pbxproj (+4: BuildFile, FileReference, Group, Sources; Zeilen 175/1122), AppIntentsUITests.swift (nur Kopfkommentar), CLAUDE.md (1 Zeile) = 5 Dateien (AC-10).
- Test liest echte Build-Metadaten: `Bundle.main.bundleURL` (Test-Host Restock.app) plus `PlugIns/SmartCartWidgets.appex`; fehlende Datei, fehlender Intent, fehlendes Feld sind Fehler (kein Raten); Gegenprobe Add == true und unbekannter Name wirft (AC-1..3). RED (test-red-output.txt): 2 Fehlschläge vor der Änderung; GREEN (test-green-output.txt): 2 Tests, 0 Fehler. Metadaten selbst nachgelesen (python3 -I): build/dd-red150 und build/dd-appintents zeigen CheckOffItemIntent False in App und Widget, Add/QuickAddControl True, Vorbild CheckOffWidgetItemIntent False.
- Release-Konfiguration: Die Eigenschaft steht ohne `#if`, ist also konfigurationsunabhängig; gelesen wurden nur Debug-Metadaten (geringes Rest-Risiko, kein Finding).
- AC-4/5: appintents-skriptlauf-ergebnis.txt: 3 ausgeführt, 3 bestanden, 0 Fehlschläge, 0 übersprungen, 0 Wiederholungen wegen 400, iOS 27.0, Wegwerf-Simulator gelöscht; testCheckOffIntentChecksFirstItem und testCheckOffWithClosedListChangesNothing passed; Testrumpf unverändert. Versuch 1 (Runner-Hänger unter Last) ist separat abgelegt, nicht beschönigt.
- AC-8: Unit 500 Tests, 0 Fehler (bestand-unit.txt); Vorgänger 498 (docs/artifacts/test-98-durchgang-8-siri-widget/test-green-output.txt:1533), 498 `func test` in c901ae5 gegenüber 500 jetzt: +2 stimmt. UI 108 Tests, 3 übersprungen, 0 Fehlschläge, TEST SUCCEEDED, gleiche Zahl wie früherer Lauf (108/3); die 3 Übersprungenen sind vorbestehende Gates (NotificationPermission 2, ReceiptShareExtension 1). Kein Null-Test-Lauf. Lastbedingung als Bedingung gewertet, Ergebnis grün.
- AC-9: durchlauf-installiert-metadaten.txt liest das installierte Bündel im Simulator (nicht den Build-Ordner), Commit 2251d90, Zeitstempel, md5 des Binärs: App und Widget False.
- AC-11: CLAUDE.md und Kopfkommentar nennen "seit #150 nicht mehr erreichbar" und die offenen Grenzen (Kurzbefehle-Oberfläche, Knopftipp, nichts auf Geräten).
- AC-12: Artefakte zeigen nur Wegwerf-Simulatoren und CoreSimulator-Pfade; kein devicectl oder Gerätebezug gefunden. Ein negativer Beweis ist aus Artefakten nur indirekt führbar.
Keine Einwände, die ein Finding rechtfertigen. Frühe Einigkeit ist verdächtig, daher Runde 2.
**Implementierer:** Bestätigt die Nachweise; keine Ergänzung nötig.

### Runde 2
**Adversary:** Gezielte Zweitangriffe:
- Grün trotz weiter angebotenem Befehl? Das System liest dieselbe `extract.actionsdata`; der Test prüft sie in beiden Bündeln. Nicht prüfbar bleibt die Kurzbefehle-Oberfläche (in der Spec als offene Grenze benannt, kein Finding).
- Unbekannter Name als Fehler? Ja: `guard let action = actions[intent]` wirft `missingIntent` (Test Zeile 40-49), Gegenprobe Zeile 60-65 mit XCTAssertThrowsError.
- Deckt das Vorbild den Live-Activity-Knopf? `CheckOffWidgetItemIntent` (ShoppingListWidget.swift:89) ist ebenfalls False und funktioniert als Widget-Knopf; der Live-Activity-Knopf selbst ist im Simulator nicht tippbar (offene Grenze); Skriptlauf belegt Ausführbarkeit über den Systemweg (0 Fehler 400).
- Regression: `isDiscoverable` wird in Produktcode nirgends gelesen, nur Metadaten ändern sich; keine Aufrufer betroffen.
- Rest-Risiken ohne Finding: Release-Metadaten nicht separat gelesen; Metadatenformat ist Xcode-intern (Test scheitert laut, nicht still). Metadaten im Build dd-appintents bestätigen, dass der Skriptlauf den geänderten Stand hatte.
Keine Nachforderung eines weiteren Laufs nötig.
**Implementierer:** Keine offenen Punkte; Grenzen sind in Spec, CLAUDE.md und Testkommentar benannt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Begründung: 12/12 Punkte bewiesen. Unit 500 Tests (498 + 2) grün, UI 108 Tests (3 vorbestehende Übersprünge) grün, Skriptlauf iOS 27 3/3 grün, 0 Wiederholungen. Metadaten in Build und installiertem Bündel zeigen CheckOffItemIntent als nicht auffindbar. Offene Grenzen (Kurzbefehle-Oberfläche, Knopftipp, Release-Konfiguration nicht separat gelesen) sind benannt und kein Spec-Verstoß.

## Confirmations

Confirmation:
  AC: AC-1, AC-2, AC-6
  Code reference: SmartCart/Intents/CheckOffItemIntent.swift:17
  Evidence: `static var isDiscoverable: Bool = false`; Metadaten in App und Widget False, perform() unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-1, AC-2, AC-3
  Code reference: RestockTests/CheckOffIntentVisibilityTests.swift:52
  Evidence: liest echte Metadaten beider Bündel; Gegenprobe und Fehler bei unbekanntem Intent ab Zeile 60; 2 Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-5, AC-11
  Code reference: RestockUITests/AppIntentsUITests.swift:15
  Evidence: nur Kopfkommentar geändert; Skriptlauf 3/3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCartWidgets/ShoppingLiveActivity.swift:55
  Evidence: Aufrufer unverändert (auch Zeile 133).
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:90ad0d1a15d320994f6acb2bc13ce91ced3a895485d1bf6a89e4ac6730150ea8  RestockTests/CheckOffIntentVisibilityTests.swift
- sha256:6393fd39a47d07d058754a3281f0611d36c592a27cba4fb6908cd7e41362cb32  RestockUITests/AppIntentsUITests.swift
- sha256:b0ba02be5377dd87133385d7cd8ce0ee196824d001961ad7e3c8c0b568ac194b  SmartCart/Intents/CheckOffItemIntent.swift
- sha256:45c1c94c27fe6d2603bc3a029f0aa5e6a373b4b055adcc354e3ff7e945fb9b0c  SmartCartWidgets/ShoppingLiveActivity.swift

## Prüfbasis

- base: c901ae57bcd49a6837149a31b99eec7f01c28ebc
- blob:b8a8c37728b5cc6bd97e7dfc84397f15d25d467a  RestockTests/CheckOffIntentVisibilityTests.swift
- blob:9b0e1901300d726a026acbab4aafb0791c77dd5a  RestockUITests/AppIntentsUITests.swift
- blob:223225f3d787da454e6a37077751b215be453466  SmartCart/Intents/CheckOffItemIntent.swift
- blob:2ad901648b71924c70041b9477506f2466644b0e  SmartCartWidgets/ShoppingLiveActivity.swift

## Geprüfte Dateien

- sha256:90ad0d1a15d320994f6acb2bc13ce91ced3a895485d1bf6a89e4ac6730150ea8  RestockTests/CheckOffIntentVisibilityTests.swift
- sha256:6393fd39a47d07d058754a3281f0611d36c592a27cba4fb6908cd7e41362cb32  RestockUITests/AppIntentsUITests.swift
- sha256:b0ba02be5377dd87133385d7cd8ce0ee196824d001961ad7e3c8c0b568ac194b  SmartCart/Intents/CheckOffItemIntent.swift
- sha256:45c1c94c27fe6d2603bc3a029f0aa5e6a373b4b055adcc354e3ff7e945fb9b0c  SmartCartWidgets/ShoppingLiveActivity.swift

## Prüfbasis

- base: c901ae57bcd49a6837149a31b99eec7f01c28ebc
- blob:b8a8c37728b5cc6bd97e7dfc84397f15d25d467a  RestockTests/CheckOffIntentVisibilityTests.swift
- blob:9b0e1901300d726a026acbab4aafb0791c77dd5a  RestockUITests/AppIntentsUITests.swift
- blob:223225f3d787da454e6a37077751b215be453466  SmartCart/Intents/CheckOffItemIntent.swift
- blob:2ad901648b71924c70041b9477506f2466644b0e  SmartCartWidgets/ShoppingLiveActivity.swift
