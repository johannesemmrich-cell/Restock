---
entity_id: checkoff-intent-verbergen
type: bugfix
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: fix-150-checkoff-intent-verbergen
tags: [bugfix, app-intents, siri, kurzbefehle, live-activity, issue-150]
---

# CheckOffItemIntent aus Siri und Kurzbefehlen verbergen (Issue #150)

## Approval

- [ ] Approved

## Purpose

`CheckOffItemIntent` ist der Knopf „Nächsten Artikel abhaken“ der Live Activity (Dynamic Island, Sperrbildschirm).
Weil der Befehl für das System auffindbar ist (`isDiscoverable` ist standardmäßig `true`), taucht er auch in der
Kurzbefehle-App, in Spotlight und für Siri auf. Dort meldet er Erfolg, tut aber nichts, solange für den Laden keine
Live Activity läuft (das ist gewollt, siehe Kommentar im Intent: Schutz vor einem liegengebliebenen Knopf). Ein Nutzer
kann sich so einen Kurzbefehl bauen, der Erfolg meldet und nichts abhakt. Diese Änderung verbirgt den Befehl wie
`CheckOffWidgetItemIntent`: Er bleibt aus Knöpfen der App und der Live Activity ausführbar, ist aber nicht mehr
auffindbar.

**Ursprung:** Beobachtung aus #145 Durchgang 3 (Test `testCheckOffWithClosedListChangesNothing`), Issue #150
„Siri-Abhaken meldet Erfolg, obwohl nichts abgehakt wird (Liste nicht geöffnet)“. Analyse:
`docs/context/fix-150-checkoff-intent-verbergen.md`, Beleg `docs/artifacts/fix-150-checkoff-intent-verbergen/`.

**PO-Entscheidung (2026-10-17, im Issue):** Das Issue nannte zwei Wege (ohne Activity vormerken / ehrliche Antwort
geben). Stattdessen wird der Befehl verborgen.

**Abweichung vom Ticket (offen benannt):** Die Definition of Done des Issues sah vor, den Test
`testCheckOffWithClosedListChangesNothing` an das neue Verhalten anzupassen. Das entfällt teilweise: Das Verhalten
von `perform()` ohne Activity ändert sich nicht, der Test bleibt unverändert bestehen und ist weiter grün. Er
dient als Gegenprobe, dass der Befehl über den Systemweg ausführbar bleibt (T2/T3). Neu ist nur der Metadaten-Test
(AC-1, AC-2).

**Offene Grenze (gilt für jede Zusage dieser Spec):** Dass der Befehl in der Kurzbefehle-App wirklich nicht mehr
erscheint, ist nur über die Build-Metadaten (`isDiscoverable = false`) belegt, nicht durch einen UI-Test der
Kurzbefehle-App. Der echte Tipp auf den Knopf der Live Activity ist nicht automatisierbar. Nichts wird auf
Hennings Geräten geprüft. Einzelheiten unter „Offene Grenzen“.

## Source

- **File:** `SmartCart/Intents/CheckOffItemIntent.swift`
- **Identifier:** `struct CheckOffItemIntent: LiveActivityIntent` (neue Eigenschaft `static var isDiscoverable`)
- Die Datei wird in App- **und** Widget-Ziel kompiliert (`project.yml:59`, zwei Build-Files in `project.pbxproj`);
  die Eigenschaft wirkt damit in beiden Metadaten.
- Vorbild: `SmartCartWidgets/ShoppingListWidget.swift:85-89` (`CheckOffWidgetItemIntent`, `isDiscoverable = false`).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CheckoffQueue` (`SmartCart/Models/CheckoffQueue.swift`) | module | Warteschlange, in die `perform()` die UUID legt; unverändert |
| ActivityKit (`Activity<ShoppingActivityAttributes>`) | framework | `perform()` wirkt nur bei laufender Activity des Ladens; unverändert |
| `SmartCartWidgets/ShoppingLiveActivity.swift:55`, `:133` | product | einzige Produkt-Aufrufer: `Button(intent: CheckOffItemIntent(storeName:))` in Dynamic Island und Sperrbildschirm |
| `CheckOffWidgetItemIntent` (`ShoppingListWidget.swift:85-89`) | product | Vorbild für `isDiscoverable = false` |
| `SmartCartShortcuts` (`AddItemIntent.swift:73`) | product | enthält nur `AddShoppingItemIntent`; kein Siri-Satz für das Abhaken, daher von der Änderung nicht berührt |
| `RestockUITests/AppIntentsUITests.swift` T2/T3 | test | belegen, dass der verborgene Befehl über `AppIntentsTesting` ausführbar bleibt (nur über `scripts/run-appintents-uitest.sh`, iOS 27) |
| `Metadata.appintents/extract.actionsdata` | build output | vom Build erzeugte Befehls-Metadaten; Quelle für Siri, Spotlight, Kurzbefehle; Grundlage des neuen Tests |
| `/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock` | lock | Abstimmung schwerer Läufe (Skriptlauf T3 unten) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Intents/CheckOffItemIntent.swift` | MODIFY | `static var isDiscoverable = false` plus ein Kommentarsatz (nur Knopf der Live Activity; ohne Activity tut er bewusst nichts) |
| `RestockTests/CheckOffIntentVisibilityTests.swift` | CREATE | Regressionstest auf die Build-Metadaten von App und Widget-Erweiterung |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Testdatei im Unit-Testziel registrieren (vier Stellen) |
| `RestockUITests/AppIntentsUITests.swift` | MODIFY | nur Kopfkommentar: „stiller Erfolg“ ist für Nutzer nicht mehr erreichbar (#150) |
| `CLAUDE.md` | MODIFY | Absatz AppIntentsUITests: Beobachtung „stiller Erfolg“ durch #150 verborgen |

### Estimated Changes

- Dateien: 5 (davon 2 nur Doku bzw. Kommentar; Spec und Artefakte zählen nicht). Limit 4–5: eingehalten.
- LoC: ca. +60 / −3 (Limit ±250: eingehalten). Das LoC-Gate zählt Testcode als Produktivcode; vor Abschluss
  `git diff --stat` gegen den Tip-Commit prüfen.
- Produktcode: eine Eigenschaft in einer Datei, kein Ablauf geändert.

### Side-Effects (explizit)

- Keine neuen Permissions, keine `Info.plist`-Änderung, keine `@AppStorage`- oder `UserDefaults`-Schlüssel,
  keine Audio-Dateien, keine neuen Strings, keine Dependencies, keine Scheme- oder `ci.yml`-Änderung.
- Sichtbar ändert sich nur, was das System über den Befehl weiß: `CheckOffItemIntent` verschwindet aus der Liste der
  auffindbaren Befehle (Kurzbefehle, Spotlight, Siri). Knopf der Live Activity und `AppIntentsTesting` bleiben.
- Nutzer, die sich schon einen Kurzbefehl mit diesem Befehl gebaut haben, verlieren ihn. Praktisch niemand, Release 1.0
  ist noch nicht erschienen.

### Nicht-Ziele

- Keine Änderung an `perform()` (Nichtstun ohne Activity bleibt gewollt), keine Rückmeldung per Dialog.
- Keine Änderung an `CheckOffWidgetItemIntent`, `AddShoppingItemIntent` oder `SmartCartShortcuts`.
- Keine Prüfung der Kurzbefehle-App-Oberfläche.

## Implementation Details

1. In `CheckOffItemIntent` die statische Eigenschaft `isDiscoverable = false` ergänzen, mit einem Kommentarsatz
   (Knopf-Befehl der Live Activity; nicht für Siri/Kurzbefehle gedacht, weil er ohne laufende Activity bewusst nichts
   tut). Form wie in `ShoppingListWidget.swift:85-89`.
2. Neuer Test `CheckOffIntentVisibilityTests` liest die Metadaten, die der Build erzeugt, nicht die Swift-Eigenschaft,
   weil die Metadaten das sind, was Siri, Spotlight und Kurzbefehle tatsächlich lesen.
   - **Dateiformat (am Build in `build/dd-appintents` geprüft, 2026-10-17):** `Metadata.appintents/extract.actionsdata`
     ist eine einzeilige JSON-Datei, Wurzel `{"actions": {"<IntentName>": {…, "isDiscoverable": true|false, …}}}`,
     Schlüssel ist der Swift-Typname ohne Modulpräfix (`AddShoppingItemIntent`, `CheckOffItemIntent`). Gelesen wird
     per `JSONSerialization`, ohne eigene Modelltypen. Ist der Schlüssel `isDiscoverable` in einem Eintrag nicht
     vorhanden, gilt das als Testfehler (nicht als `true` oder `false` raten).
   - **Orte:** `Bundle.main` (Test-Host ist `Restock.app`) und `Bundle.main.builtInPlugInsURL`/`SmartCartWidgets.appex`.
     Die Test-Annahme, dass der Unit-Test-Host `Restock.app` ist, wird in Phase 4 am ersten Lauf bestätigt; gelingt das
     Auffinden nicht, scheitert der Test mit klarer Meldung (Pfad, gefundene Schlüssel), nie mit stillem Überspringen.
   - **Gegenprobe im selben Test:** `AddShoppingItemIntent.isDiscoverable == true` in den App-Metadaten, damit ein
     kaputtes Lesen (leere Datei, falscher Ort, falsches Feld) den Test nicht grün macht.
3. Testdatei in `project.pbxproj` an den vier Stellen eintragen (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`,
   `PBXSourcesBuildPhase` des Unit-Testziels). Ob die Metadaten-Datei im Widget-Bündel der Test-Build-Konfiguration
   vorhanden ist, wird beim ersten Lauf geprüft (Beleg aus der Analyse: in `Debug-iphonesimulator` vorhanden).
4. Kopfkommentar in `AppIntentsUITests.swift` und Absatz in `CLAUDE.md` anpassen: Beobachtung „stiller Erfolg ohne
   Wirkung“ ist durch #150 für Nutzer nicht mehr erreichbar; der Test bleibt als Gegenprobe der Ausführbarkeit.

**Nachstellung und Beleg aus der Analyse (2026-10-17):** Heute steht `CheckOffItemIntent` in den Metadaten von App
und Widget mit `isDiscoverable = true`, `CheckOffWidgetItemIntent` mit `false`. In einer Wegwerf-Kopie mit
`isDiscoverable = false` zeigen die Metadaten `False` in App und Widget, alle anderen Befehle unverändert;
`scripts/run-appintents-uitest.sh` lief 3 von 3 grün, 0 Fehlschläge, 0 Übersprungene, 0 Wiederholungen wegen Fehler 400
(`docs/artifacts/fix-150-checkoff-intent-verbergen/repro-verborgen-appintents.log`). Das Risiko „verborgener Befehl nicht
mehr über `AppIntentsTesting` erreichbar“ ist damit widerlegt.

**Quellen (Recherche):** Apple `isDiscoverable`
(https://developer.apple.com/documentation/appintents/appintent/isdiscoverable) und Apple-Forum
(https://developer.apple.com/forums/thread/761318): verborgener Intent bleibt aus App-UI und Widget ausführbar, ist
aber nicht für Siri, Spotlight und Kurzbefehle auffindbar.

## Test Plan

### Automated Tests (TDD RED)

- [ ] T1 (RED vor Umsetzung): `CheckOffIntentVisibilityTests.testCheckOffIntentIsHiddenInAppAndWidgetMetadata` —
  GIVEN die Metadaten von `Restock.app` und `SmartCartWidgets.appex`, WHEN `CheckOffItemIntent` gelesen wird,
  THEN ist `isDiscoverable == false` in beiden. RED-Beleg: vor der Änderung schlägt der Test mit `true` fehl.
- [ ] T2: `CheckOffIntentVisibilityTests.testAddIntentStaysDiscoverable` (Gegenprobe) — GIVEN dieselben App-Metadaten,
  WHEN `AddShoppingItemIntent` gelesen wird, THEN ist `isDiscoverable == true` und der Eintrag vorhanden; GIVEN ein
  nicht vorhandener Intent-Name, THEN meldet der Hilfsleser einen Fehler statt `false` (Test gegen stilles Grün).
- [ ] T3: Skriptlauf `scripts/run-appintents-uitest.sh` (Xcode 27.1, iOS 27.0) — GIVEN freie Sperren, WHEN das Skript
  läuft, THEN 3 von 3 Tests grün, 0 Fehlschläge, 0 Übersprungene, 0 Wiederholungen wegen Fehler 400; insbesondere
  `testCheckOffIntentChecksFirstItem` (verborgener Befehl wirkt mit laufender Activity) und
  `testCheckOffWithClosedListChangesNothing` (Gegenprobe) unverändert grün.
- [ ] T4: Bestandssuite — GIVEN Simulator `Restock-Validate` (iOS 26.5), WHEN Unit- und UI-Suite laufen, THEN sind
  alle Tests grün mit bisheriger Testzahl plus 2 neuen Unit-Tests; Testzahl und Abbrüche geprüft (Null-Test-Lauf ist kein
  Grün); Unit-Suite wegen #63 bei Bedarf getrennt von der UI-Suite.
- [ ] T5: Diff gegen den Tip-Commit — nur die genannten fünf Dateien (plus Spec und Artefakte), ca. +60/−3 LoC.

### Durchlauf „App benutzt“ (Pflicht)

Im Simulator mit dem Stand, der ausgeliefert wird:

1. App mit dem Build starten, Läden gesät (Skriptlauf T3 tut das auf dem iOS-27-Wegwerf-Simulator), Liste von dm
   öffnen (startet die Live Activity), Home, `CheckOffItemIntent` über den Systemweg ausführen, App aktivieren:
   „1 von 2 erledigt“. Das ist `testCheckOffIntentChecksFirstItem` und belegt, dass der verborgene Befehl mit laufender
   Activity weiter wirkt.
2. Metadaten-Check am installierten Stand: `isDiscoverable` für `CheckOffItemIntent` in `Restock.app` und im
   `PlugIns/SmartCartWidgets.appex` gelesen aus dem installierten Bündel des Simulators (nicht nur aus dem
   Build-Ordner), Ausgabe im Artefaktordner abgelegt.
3. Registrierung als Artefakt aus dem echten Lauf (Commit-Kennung und Zeitstempel müssen zum Stand passen), nie von
   Hand gesetzt.

## Acceptance Criteria

- AC-1: GIVEN die vom Build erzeugten Metadaten der App (`Restock.app/Metadata.appintents/extract.actionsdata`),
  WHEN `CheckOffItemIntent` gelesen wird, THEN steht dort `isDiscoverable == false`. Test: T1.
- AC-2: GIVEN die Metadaten der Widget-Erweiterung (`PlugIns/SmartCartWidgets.appex/Metadata.appintents/extract.actionsdata`),
  WHEN `CheckOffItemIntent` gelesen wird, THEN steht dort `isDiscoverable == false`. Test: T1.
- AC-3: GIVEN dieselben App-Metadaten, WHEN `AddShoppingItemIntent` gelesen wird, THEN bleibt er auffindbar
  (`isDiscoverable == true`), und ein nicht vorhandener Intent-Name führt zu einem Testfehler statt zu einem
  stillen Ergebnis (Gegenprobe gegen kaputtes Lesen). Test: T2.
- AC-4: GIVEN der Skriptlauf `scripts/run-appintents-uitest.sh` auf iOS 27.0, WHEN er nach der Änderung läuft, THEN
  sind genau 3 Tests gelaufen, 0 Fehlschläge, 0 Übersprungene, 0 Wiederholungen wegen Fehler 400; `testCheckOffIntentChecksFirstItem`
  ergibt „1 von 2 erledigt“ (verborgener Befehl wirkt mit laufender Live Activity). Test: T3.
- AC-5: GIVEN `testCheckOffWithClosedListChangesNothing`, WHEN er nach der Änderung unverändert läuft, THEN ist er grün
  („0 von 2 erledigt“ bei geschlossener Liste). Der Test wird nicht geändert (Abweichung vom Ticket, oben benannt).
  Test: T3, T5 (kein Diff am Testrumpf, nur Kopfkommentar).
- AC-6: GIVEN `perform()` von `CheckOffItemIntent`, WHEN der Diff geprüft wird, THEN ist das Verhalten unverändert:
  die einzige Produktänderung in `SmartCart/` ist die Eigenschaft `isDiscoverable = false` samt Kommentar. Test: T5.
- AC-7: GIVEN die Aufrufer in `SmartCartWidgets/ShoppingLiveActivity.swift` (Zeilen 55 und 133), WHEN der Diff geprüft
  wird, THEN sind sie unverändert und rufen weiter `Button(intent: CheckOffItemIntent(storeName:))` auf. Test: T5.
- AC-8: GIVEN die Bestandssuite auf `Restock-Validate`, WHEN sie nach der Änderung läuft, THEN ist sie grün (Unit
  und UI), Testzahl entspricht der bisherigen plus den 2 neuen Unit-Tests, kein Abbruch. Test: T4.
- AC-9: GIVEN der Durchlauf im Simulator, WHEN die Metadaten des installierten Stands gelesen werden, THEN ist
  `CheckOffItemIntent` in App und Widget-Erweiterung als nicht auffindbar eingetragen, die Ausgabe liegt unter
  `docs/artifacts/fix-150-checkoff-intent-verbergen/`. Test: Durchlauf.
- AC-10: GIVEN der Diff gegen den Tip-Commit, WHEN er geprüft wird, THEN umfasst er höchstens `CheckOffItemIntent.swift`,
  `CheckOffIntentVisibilityTests.swift`, `project.pbxproj`, `AppIntentsUITests.swift` (nur Kopfkommentar) und `CLAUDE.md`
  (plus Spec und Artefakte), ca. +60/−3 LoC; keine Änderung an `ci.yml`, Scheme, `Info.plist`. Test: T5.
- AC-11: GIVEN `CLAUDE.md` und der Kopfkommentar von `AppIntentsUITests.swift`, WHEN sie geprüft werden, THEN
  beschreiben sie „stiller Erfolg ohne Wirkung“ als durch #150 für Nutzer nicht mehr erreichbar (Befehl verborgen) und
  nennen die offenen Grenzen (Kurzbefehle-App-Oberfläche und Tipp auf den Knopf nicht automatisiert geprüft). Test: T5
  (Review).
- AC-12: GIVEN der gesamte Durchgang, WHEN Schritte ausgeführt werden, THEN startet, installiert oder liest keiner ein
  Gerät des Users; Läufe nur auf Wegwerf-Simulatoren bzw. `Restock-Validate`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Eine Sichtbarkeitseigenschaft an einem bestehenden Intent, nach dem Vorbild `CheckOffWidgetItemIntent`.
  Keine neue Struktur, kein neues Muster; die PO-Entscheidung ist im Issue #150 festgehalten.

## Alternativen

Kein Modell beteiligt: deterministische Eigenschaft und Dateiprüfung.

| Option | Vorteil | Nachteil / gekippte Entscheidung |
|---|---|---|
| **Befehl verbergen (gewählt, PO 2026-10-17)** | kleinste Änderung, Befehl kann nicht mehr irreführen, Knopf bleibt, Muster wie beim Widget | in Kurzbefehlen nicht mehr nutzbar (kein bekannter Bedarf) |
| Rückmeldung ohne Activity (Dialog „Kein Einkauf aktiv“ oder Fehler) | Befehl in Kurzbefehlen ehrlich | wertet einen Knopf-Befehl zum Nutzerbefehl auf ohne Nutzen; Dialog beim liegengebliebenen Knopf störend; vom PO verworfen |
| Ohne Activity vormerken (Warteschlange auch ohne Activity) | Befehl wirkt immer | kippt den Schutz vor liegengebliebenem Knopf (Kommentar im Intent, `CheckoffQueue`), mehr Verhalten und Tests; vom PO verworfen |
| Nichts tun | kein Aufwand | Befehl ginge mit 1.0 in die Kurzbefehle-App; verworfen |

- **Gekippte frühere Entscheidung:** Die Arbeitsaussage aus #145 D3, der „stille Erfolg“ sei „Beobachtung fürs Issue“
  und ein „möglicher Nutzerfehler für Siri/Widget“, erledigt sich, weil der Befehl nicht mehr auffindbar ist.
  Eine ADR wird nicht gekippt.

## Offene Grenzen

- **Kurzbefehle-App, Spotlight und Siri** sind nicht per Test prüfbar; belegt ist nur der Metadateneintrag
  (`isDiscoverable = false`) im Build und im installierten Bündel sowie Apples Dokumentation.
- **Tipp auf den Knopf der Live Activity** (Dynamic Island, Sperrbildschirm) ist im Simulator nicht automatisierbar
  (offene Grenze seit #145 D3). Stütze: Apple-Dokumentation und das Vorbild `CheckOffWidgetItemIntent`, dessen Knopf mit
  `false` bereits funktioniert; Skriptlauf T2 belegt die Ausführbarkeit über den Systemweg.
- **Skriptlauf nur lokal**, iOS 27.0 und Xcode 27.1; in der CI und auf `Restock-Validate` ist `AppIntentsUITests`
  leer (Kompilierbedingung `APPINTENTS_UITESTS`). Der neue Metadaten-Test läuft dagegen überall mit.
- **Format der Metadaten** ist Build-Ausgabe von Xcode und nicht von Apple als Schnittstelle dokumentiert. Ändert ein
  künftiges Xcode das Format, schlägt der Test mit klarer Meldung fehl (Absicht, siehe Gegenprobe), dann ist der Leser
  anzupassen.
- Der Test-Host des Unit-Testziels ist als `Restock.app` angenommen und wird in Phase 4 am ersten Lauf bestätigt.
- **Nichts** wird auf Hennings Geräten gestartet oder geprüft (Regel „Hennings Geräte nur auf sein Wort“).

## Risiken

- **Knopf der Live Activity feuert nicht mehr:** laut Apple nein; belegt über das Vorbild und Skriptlauf T3. Echter Tipp
  nicht automatisierbar (siehe Offene Grenzen).
- **Verborgener Befehl nicht mehr per `AppIntentsTesting` auflösbar (Fehler 400):** in der Wegwerf-Kopie widerlegt
  (3/3 grün, 0 Wiederholungen); Skriptlauf T3 prüft es am echten Stand erneut.
- **Metadaten-Test grün durch falsches Lesen:** Gegenprobe `AddShoppingItemIntent == true` und Fehler bei unbekanntem
  Schlüssel (AC-3).
- **LoC-Gate zählt Testcode:** geschätzt +60/−3, weit unter dem Limit.
- **Schwere Läufe:** Skriptlauf nimmt beide Sperren; nie parallel zu anderen Simulator-Läufen.

## Changelog

- 2026-10-17: Initial spec created (Issue #150; Befehl verbergen statt Rückmeldung, PO-Entscheidung im Issue;
  Abweichung vom Ticket: `testCheckOffWithClosedListChangesNothing` bleibt als Gegenprobe unverändert)
