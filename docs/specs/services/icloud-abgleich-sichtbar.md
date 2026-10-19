---
entity_id: icloud-abgleich-sichtbar
type: bugfix
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: fix-156-icloud-abgleich-sichtbar
tags: [bugfix, cloudkit, swiftdata, sync, onboarding, duplikate, schema, diagnose, issue-156]
---

# iCloud-Abgleich sichtbar, Doppel-Läden verhindern, Foto-Asset-Feld im Schema (Issue #156)

## Approval

- [ ] Approved

Die Entscheidungen des PO vom 2026-10-18 sind in diese Spec übernommen und werden nicht neu verhandelt
(Quelle: `docs/context/fix-156-icloud-abgleich-sichtbar.md`, „Open Questions“): Doppel **verhindern und
anzeigen**, nichts löschen, nichts zusammenführen; Onboarding **Entwurf A** (Warten bis höchstens 10 s);
Entwickler **zwei Zeilen**; Exportfehler **nur im Entwicklermodus**; `_ckAsset` **nur Foto**; alles in
**einem Durchgang**.

**Umfang offen genannt:** Der PO hat vorab ca. 400–500 Zeilen in einem Durchgang akzeptiert. Die Schätzung
dieser Spec liegt bei **ca. 670 Zeilen inklusive Tests** (Produkt ca. 320, Unit-Tests ca. 270, UI-Tests ca. 80)
und bei rund 10 Produkt-/Dokudateien plus 5 Testdateien. Das überschreitet sowohl die akzeptierte Zeilenzahl
als auch die Dateigrenze der Scoping-Limits; die Überschreitung wird hier nicht stillschweigend übergangen,
sondern mit der Freigabe dieser Spec bestätigt (siehe „Scope“, „Alternativen“ für Streichkandidaten).

## Purpose

Seit Build 32 und dem Production-Deploy (Issue #155) läuft der private iCloud-Abgleich der eigenen Läden und
Listen erstmals in TestFlight. Drei Lücken bleiben: (A) Ein gescheiterter Export ist in der App unsichtbar,
(B) Läden können doppelt entstehen, schon bei einer einfachen Neuinstallation, weil die Ersteinrichtung alle
17 Standardläden neu anlegt, bevor die Läden aus iCloud eingetroffen sind, und (C) das Überlauffeld
`CD_photoData_ckAsset` fehlt im Schema, sodass ein Foto über 1 MB den ganzen Export scheitern ließe.
Diese Spec macht den Abgleich im Entwicklermodus sichtbar, verhindert die Doppel an ihren Quellen, zeigt
vorhandene Doppel an und ergänzt das Foto-Feld im Schema.

Es liegt keine Verschlechterung vor: Der private Abgleich lief in TestFlight bis 2026-10-18 nie
(Production-Schema fehlte, siehe `docs/specs/models/private-cloudkit-schema.md`).

## Source

Recherche mit Quellen: `docs/artifacts/fix-156-icloud-abgleich-sichtbar/recherche-2026-10-18.md`. Kern:
SwiftData spiegelt über `NSPersistentCloudKitContainer`, dessen `eventChangedNotification` (`object: nil`)
Typ, Erfolg, Fehler und Endzeit je Lauf liefert; bei `partialFailure` trägt nur ein Eintrag die Ursache, die
übrigen melden `batchRequestFailed`; Apple DTS empfiehlt als Gewinner bei Duplikaten die **kleinste UUID**;
`CD_<attr>_ckAsset` (ASSET) ist der Überlauf ab 1 MB Record-Größe. Freigegebener Entwurf:
`docs/artifacts/fix-156-icloud-abgleich-sichtbar/entwurf.html`.

- **Neu:** `SmartCart/Services/CloudMirrorMonitor.swift` (`CloudMirrorMonitor`, `CloudMirrorSummary`,
  `CloudMirrorStatusStore`, `OnboardingCloudGate`)
- **Neu:** `SmartCart/Services/StoreDuplicateService.swift` (`StoreSnapshot`, `StoreDuplicateFinder`,
  `StoreDuplicateGroup`)
- **Neu:** `SmartCart/Views/Settings/CloudMirrorStatusView.swift`, `SmartCart/Views/Settings/StoreDuplicatesView.swift`
- **Geändert:** `SmartCart/SmartCartApp.swift`, `SmartCart/Views/Settings/SettingsView.swift`,
  `SmartCart/Views/Settings/OnboardingView.swift`, `SmartCart/Views/Store/StoreShareSheet.swift`
- **Schema:** `docs/cloudkit/private-schema-aktuell.ckdb` (Feld `CD_photoData_ckAsset`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NSPersistentCloudKitContainer.eventChangedNotification` / `.Event` (CoreData) | system | Quelle der Export-/Import-Ereignisse; nur im App-Prozess, `object: nil` |
| `CKError`, `CKContainer.accountStatus()` (CloudKit) | system | Fehlerklassifikation; Kontostatus für „ohne iCloud-Konto kein Warten“ |
| `SyncCoordinator.classify`, `SyncLog`, `Logger(category: "sync")` | module | Muster und Wiederverwendung für Fehlerarten und Protokoll (Fehlertext `.private`) |
| `SharedModelContainer.isAppExtension(bundleURL:)` | module | Beobachter nur im App-Prozess starten |
| `CloudPreferencesSync` (KV-Store, `hasCompletedOnboarding`) | module | Weg, auf dem „Einrichtung erledigt“ ohnehin ankommt; Onboarding darf ihn nicht aushebeln |
| `Store`, `ShoppingItem`, `Store.presets(for:)` (`SmartCart/Models/`) | models | Duplikatkriterium (`shareID`, `isCustom`, `countryCode`, Name), Presets für B2 |
| `SettingsView` Dev-Sektion, `ReceiptResolutionStatsView` | views | Einhängepunkt und Muster für die Detailansichten |
| `SyncBanner.decision` (`StoreDetailView.swift`) | module | Muster für reine Anzeigefunktionen |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | test | Snapshot-Test, um `_ckAsset`-Prüfung erweitert |
| `cktool` (Xcode), CloudKit-Dashboard „Deploy Schema Changes…“ | tool | Schema Development; Production nur per Dashboard |
| Management-Token | credential | Für `cktool`; danach `remove-token --type management`, Wert nie anzeigen |
| `UITestWait` / `UITestLaunch` (`RestockUITests/UITestWait.swift`) | test helper | Wartehilfen und Startablauf der UI-Tests |
| Hennings Geräte | external | Nur für die offene Grenze AC-20, nur nach seinem wörtlichen „jetzt ist ein Test möglich“ |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/CloudMirrorMonitor.swift` | CREATE | Beobachter, reine Zusammenfassung `summarize`, Statusablage in `UserDefaults`, Warte-Entscheidung `OnboardingCloudGate` |
| `SmartCart/Services/StoreDuplicateService.swift` | CREATE | Reine Duplikaterkennung Klassen 1–3, Gewinnerregel kleinste UUID, „fehlende Presets“ für B2 |
| `SmartCart/Views/Settings/CloudMirrorStatusView.swift` | CREATE | Detailansicht „iCloud-Abgleich“ |
| `SmartCart/Views/Settings/StoreDuplicatesView.swift` | CREATE | Detailansicht „Doppelte Läden“, nur Anzeige |
| `SmartCart/SmartCartApp.swift` | MODIFY | Monitor im `init()`-`defer` starten; DEBUG-Seed-/Aufräumargumente |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Zwei Dev-Zeilen; `seedStores(for:)` fügt nur fehlende Presets ein |
| `SmartCart/Views/Settings/OnboardingView.swift` | MODIFY | Hinweis, gesperrtes „Loslegen“, Entfall der Einrichtung, `finishOnboarding` fügt nur fehlende Presets ein |
| `SmartCart/Views/Store/StoreShareSheet.swift` | MODIFY | Beitritt verwendet vorhandenen Laden gleicher `shareID` wieder |
| `docs/cloudkit/private-schema-aktuell.ckdb` | MODIFY | Feld `CD_photoData_ckAsset ASSET` in `CD_ShoppingItem` |
| `docs/testflight-setup.md` | MODIFY | Vermerk „offen für #156“ ersetzen; Deploy-Schritt für `_ckAsset` |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | MODIFY | Neuer strenger Test auf `CD_photoData_ckAsset` |
| `RestockTests/CloudMirrorMonitorTests.swift` | CREATE | Zusammenfassung, Statusablage, Warte-Entscheidung |
| `RestockTests/StoreDuplicateFinderTests.swift` | CREATE | Duplikatklassen, Gewinner, B2-Einfügelogik mit In-Memory-Container |
| `RestockUITests/ICloudDiagnosticsUITests.swift` | CREATE | Dev-Zeilen und Detailansichten mit Seed |
| `RestockUITests/OnboardingCloudWaitUITests.swift` | CREATE | Warten, gesperrter Knopf, Entfall der Einrichtung |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Fünf neue Swift-Dateien in den vier Abschnitten registrieren |

Nicht angefasst: `RestockShareExtension/`, `SmartCartWidgets/` (kein Beobachter dort, siehe Risiken), das
Modell `Store`, `SharedModelContainer.swift`.

### Estimated Changes

- Dateien: 10 Produkt/Doku (4 neu, 6 geändert inklusive .ckdb und Doku) + 5 Test (2 geändert/neu Unit, 2 neu UI, 1 geändert Snapshot) + pbxproj
- LoC: ca. +670/−20 (Produkt ca. +320, Unit ca. +270, UI ca. +80)
- Bestätigung durch den PO mit dieser Freigabe nötig, weil über den vorab akzeptierten Wert hinaus.

## Implementation Details

Reihenfolge der Umsetzung: C (Schema, Dashboard-Deploy braucht Vorlauf) → A → B1 → B2.

**C, Schema.** Ablauf wie in `docs/testflight-setup.md`: `cktool export-schema` (Development), in der
Arbeitsdatei in `CD_ShoppingItem` die Zeile `"CD_photoData_ckAsset" ASSET` ergänzen (Schreibweise exakt wie die
vorhandenen `CD_`-Felder), `validate-schema`, `import-schema` (ersetzt das ganze Development-Schema, deshalb
vorher exportieren), erneut exportieren und mit `diff` prüfen, dass nur dieses Feld dazukam. Export wird zu
`private-schema-aktuell.ckdb`. Production: Dashboard „Deploy Schema Changes…“, Container-ID prüfen, Diff darf
nur dieses Feld zeigen. Management-Token danach entfernen. Der Deploy ist ein Schritt außerhalb des Codes (Henning
über Claude Desktop/Browser-Steuerung). Andere `_ckAsset`-Felder (z. B. für lange Strings) sind bewusst nicht
Teil dieses Durchgangs (PO-Entscheidung: nur Foto); `PhotoCompressor` begrenzt Fotos auf höchstens 500 KB.

**A, Beobachter.** `CloudMirrorMonitor.start()` registriert genau einen Beobachter auf
`NSPersistentCloudKitContainer.eventChangedNotification` mit `object: nil`; wiederholter Aufruf ist wirkungslos.
Start ursprünglich im `defer`-Block von `SmartCartApp.init()`, seit #166 vor der Container-Erzeugung. Nur im App-Prozess: `shouldObserve(bundleURL:)` ist eine reine
Funktion auf Basis von `SharedModelContainer.isAppExtension`. Der Handler liest `type`, `succeeded`, `error`,
`endDate` aus dem Event und ruft die testbare Funktion `handle(type:succeeded:error:endDate:)`; Ereignisse mit
`endDate == nil` (laufend) werden ignoriert. Die Ereignisse treffen auf beliebiger Queue ein, geschrieben wird
nur in `UserDefaults` (thread-sicher), UI-Zustand wird auf dem Main-Actor gelesen.
Einrichtungsläufe (`.setup`) wurden hier ursprünglich ignoriert; seit Issue #166 werden sie als `lastSetup`
gespeichert, siehe `docs/specs/services/icloud-einrichtung-sichtbar.md`.
Die reine Funktion `summarize(error:) -> CloudMirrorSummary` liefert Domain, Code, Fehlerart und Detail:
bei `CKError.partialFailure` wird `partialErrorsByItemID` durchsucht und der Eintrag gemeldet, der **nicht**
`batchRequestFailed` ist (Fundort in `NSUnderlyingError` mitgeprüft), plus die Zahl der betroffenen Einträge;
fehlt ein solcher Eintrag, wird der Fehler der obersten Ebene gemeldet. Fehlerarten nutzen
`SyncCoordinator.classify` (u. a. „production schema“ → Schema unvollständig). `os.Logger`, Kategorie `sync`:
Domain und Code `.public`, Fehlertext `.private`. Die Statusablage `CloudMirrorStatusStore` (injizierbare
`UserDefaults`, Standard `.standard`, Schlüsselpräfix `smartcart.cloudMirror.`) hält je Typ (Export/Import) den
letzten Lauf (Zeit, Erfolg, Zusammenfassung) und Zähler „Exporte ok/fehlgeschlagen“. `quotaExceeded` kann in
Live-Ereignissen fehlen (FB13773922); die Ansicht behauptet daher nie „alles in Ordnung“, sondern nur „letzter
Export am …, erfolgreich“.
Anzeige nur bei `developerMode`: Zeile „iCloud-Abgleich“ in der Dev-Sektion von `SettingsView` (Untertitel
„Export fehlgeschlagen · 19:02“ in `Color.destructive`, sonst „Export erfolgreich · 19:02“ bzw. „noch kein Lauf“)
und `CloudMirrorStatusView` (Abschnitte: Letzter Export, Ursache, Letzter Import, Seit Installation) mit
`.devFeedback(context: "iCloud-Abgleich")`, Muster `ReceiptResolutionStatsView`.

**B1, Doppel messen und anzeigen.** `StoreDuplicateFinder.groups(_ stores: [StoreSnapshot])` bildet Gruppen
nach dem Kriterium aus der Analyse: Klasse 1: gleiche, nicht leere `shareID`. Klasse 2: `isCustom == false`,
gleicher `countryCode`, Name normalisiert (trim, Groß/Klein, diakritikfrei). Klasse 3: `isCustom == true`,
gleicher normalisierter Name, nur gemeldet. Nicht gruppiert: gleicher Name in verschiedenen Ländern, geteilter
Laden gegen gleichnamiges Preset. `winner(of:)` liefert die kleinste UUID und ist von der Eingabereihenfolge
unabhängig. **Es wird nichts gelöscht, umgehängt oder zusammengeführt.** `StoreDuplicatesView` zeigt Zähler
(Läden gesamt, davon aktiv, Doppelgruppen) und je Gruppe die Läden mit Aktiv-Status, Artikelzahl und gekürzter
Kennung; „bliebe“ markiert den Gewinner nur als Information. Dev-Zeile „Doppelte Läden“ mit Untertitel „keine“
bzw. „N Gruppen“, `.devFeedback(context: "Doppelte Läden")`.

**B2, Doppel verhindern.**
1. Onboarding Entwurf A: Die reine Funktion `OnboardingCloudGate.decision(accountAvailable:firstImportFinished:storeCount:elapsed:)`
   liefert `.proceed` (kein Konto, Import fertig ohne Läden, 10 s vergangen), `.wait` oder `.skipOnboarding`
   (Läden sind angekommen). `OnboardingView` startet beim Erscheinen von Schritt 0 die Kontoabfrage
   (`CKContainer.accountStatus()`, bei Fehler gilt „kein Konto“) und eine Frist von 10 s. Während `.wait`:
   Hinweiszeile „Deine Läden werden aus iCloud geladen …“ mit Fortschrittsanzeige, „Loslegen“ gesperrt. Bei
   `.skipOnboarding` wird `hasCompletedOnboarding = true` gesetzt (kein Einfügen von Läden), die Startseite
   erscheint. Ohne iCloud-Konto kein Warten. Der erste Import gilt als fertig, sobald das Monitor-Ereignis
   „Import beendet“ eintraf. Land und Anzeigename werden dabei nicht verändert.
2. `finishOnboarding()` und `seedStores(for:)` fügen nur Presets ein, für die nicht schon ein Laden gleichen
   Landes und normalisierten Namens existiert (`StoreDuplicateFinder.missingPresets(_:existing:)`; abgeleitet aus
   Klasse 2). Vorhandene Läden werden nicht verändert, auch nicht deren `isActive`.
3. `StoreShareSheet`-Beitritt: Existiert schon ein `Store` mit derselben `shareID`, wird er aktualisiert und
   wiederverwendet, statt einen zweiten anzulegen (`StoreShareJoin.existingStore(shareID:in:)`).

**Seed-/Aufräumargumente (DEBUG, in `SmartCartApp.init()`).** Jedes Argument mit Aufräumgegenstück, das in
`tearDown()` benutzt wird (CLAUDE.md-Regel):
- `-seedCloudMirrorStatusForUITests` (schreibt einen fehlgeschlagenen Export mit Ursache `CD_ShoppingItem` und
  einen erfolgreichen Import in die Statusablage) / `-clearCloudMirrorStatusForUITests` (entfernt alle
  `smartcart.cloudMirror.*`-Schlüssel).
- `-seedDuplicateStoresForUITests` (legt „Lidl“ und „Lidl“ DE als Preset-Doppel mit je fester UUID an, über den
  echten Datenweg) / `-clearDuplicateStoresForUITests` (entfernt genau diese Läden).
- `-simulateCloudImportForUITests <Sekunden>` (Onboarding behandelt ein Konto als vorhanden und den ersten Import
  erst nach der Zeit als fertig) und `-simulateCloudStoresArriveForUITests <Sekunden>` (fügt nach der Zeit zwei
  Läden über den echten Datenweg ein). Beide erzeugen Läden nur im zweiten Fall; Aufräumen übernimmt das
  vorhandene `-clearOnboardingForUITests` (Läden, `hasCompletedOnboarding`, `selectedCountry`, Anzeigename).
Die Dev-Zeilen-Tests benutzen `-developerMode YES` nur lesend und schreiben den Schlüssel nie (Argument-Domain-
Falle, CLAUDE.md); die Onboarding-Tests starten nie mit `-hasCompletedOnboarding`.

**Lokalisierung/Konventionen.** Neue sichtbare Texte über `String(localized:)` mit Schlüsseln in der
bestehenden Stringtabelle unter `Resources/`; Farben über Tokens aus `DesignSystem.swift`; Haptik nicht nötig.
Neue Swift-Dateien werden im `project.pbxproj` an allen vier Stellen registriert.

## Expected Behavior

- **Input:** Export-/Import-Ereignisse der Spiegelung, Zustand der Läden, Start der Ersteinrichtung, Beitritt zu
  einem geteilten Laden.
- **Output:** Diagnosezeilen im Entwicklermodus; Ersteinrichtung wartet höchstens 10 s auf Läden aus iCloud;
  keine neuen Doppel durch Einrichtung, Länderwechsel oder Beitritt.
- **Side effects:** Zusätzlicher Beobachter im App-Prozess; neue `UserDefaults`-Schlüssel
  `smartcart.cloudMirror.*`; keine Änderung an gespeicherten Läden, Artikeln oder deren Schlüsseln; keine neuen
  Berechtigungen; keine Änderung der AppStorage-Schlüssel; Schema-Feld additiv.

## Alternativen

- **B3, automatisch zusammenführen (nicht gewählt):** Würde auch Altlasten beseitigen. Risiko hoch: Artikel
  hängen per cascade am Laden, per-Gerät-Schlüssel `<key>_<store.id>` (shareID, Mitglieder, Reihenfolge) müssten
  übertragen werden, zwei Geräte könnten gleichzeitig dieselben Läden löschen. Geschätzt +350 Zeilen. Gekippt
  würde die PO-Entscheidung „nichts löschen“; die Gewinnerregel liegt als reine Funktion bereit, damit B3 nach
  einer Messung am Gerät ein eigener, kleiner Schritt wird.
- **Onboarding Alternative B (nicht gewählt):** Einrichtung läuft wie heute, gewartet wird erst bei „Los geht's!“.
  Kein Warten am Anfang, aber wer schon Läden in iCloud hat, wählt umsonst aus. Entwurf A (PO-freigegeben) kippt
  dieses Verhalten.
- **Nur gewählte Presets anlegen (nicht gewählt):** Würde das Schadensbild kleiner machen, ändert aber die
  Laden-Einrichtung (inaktive Presets fehlen dort). Nebenwirkung, deshalb verworfen.
- **Eine kombinierte Dev-Zeile (nicht gewählt):** kürzer, mischt aber Uploadfehler und Ladenzustand; PO wählte zwei
  Zeilen.
- **Keine Modell-Spalte `deviceOrigin`/eindeutiges Feld (nicht gewählt):** `@Attribute(.unique)` ist mit CloudKit
  nicht erlaubt (Forum 656380); ein neues Modellfeld wäre zudem eine Schemaänderung in Production.
- **Streichkandidaten bei Umfangsproblemen:** `StoreDuplicatesView` samt UI-Test (ca. 90 Zeilen) könnte nach
  B2 entfallen; Dev-Zeile mit Zähler genügte. Nicht entschieden, nur genannt.
- **Frühere Entscheidung, die berührt wird:** Die Aussage in `private-cloudkit-schema.md`, Beobachter und Doppel
  seien „nicht Teil dieses Ziels“, wird hiermit eingelöst; ein ADR ist dafür nicht nötig.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests (`xcodebuild test`, `Restock-Validate`, Sperren aus `CLAUDE.md`):

- [ ] `CloudMirrorMonitorTests`
  - T1: GIVEN ein `partialFailure` mit zwei `batchRequestFailed` und einem `CD_ShoppingItem`-Fehler WHEN `summarize` THEN meldet es den Einzelfehler und „1 von 3“.
  - T2: GIVEN `partialFailure` nur mit `batchRequestFailed` oder ein Fehler ohne Teilfehler WHEN `summarize` THEN wird der Fehler der obersten Ebene gemeldet.
  - T3: GIVEN der Einzelfehler liegt in `NSUnderlyingError` WHEN `summarize` THEN wird er gefunden.
  - T4: GIVEN Fehlertext „… in production schema“ WHEN `summarize` THEN Art `schemaIncomplete`.
  - T5: GIVEN ein beendetes Export-Ereignis (Fehler, dann Erfolg) WHEN `handle` THEN speichert die Statusablage Zeit, Zusammenfassung und Zähler; ein laufendes Ereignis (`endDate == nil`) ändert nichts (eigene `UserDefaults`-Suite je Test).
  - T6: GIVEN Bundle-URL `.appex` bzw. `.app` WHEN `shouldObserve` THEN false bzw. true.
  - T7: GIVEN die Warte-Entscheidung WHEN kein Konto / Konto ohne Import nach 3 s / nach 10 s / Import fertig ohne Läden / Läden vorhanden THEN `.proceed` / `.wait` / `.proceed` / `.proceed` / `.skipOnboarding`.
  - T8: GIVEN die Untertitelfunktion der Dev-Zeile WHEN letzter Export fehlgeschlagen / erfolgreich / kein Lauf THEN Text und Fehlerkennzeichen passen.
- [ ] `StoreDuplicateFinderTests`
  - T9: GIVEN zwei Läden mit gleicher `shareID` WHEN `groups` THEN eine Gruppe (Klasse 1).
  - T10: GIVEN „Lidl“ und „lidl “ (Preset, DE) bzw. „Bäckerei“/„Backerei“ WHEN `groups` THEN je eine Gruppe (Klasse 2).
  - T11: GIVEN gleicher Name in DE und AT, geteilter „Lidl“ neben Preset „Lidl“ WHEN `groups` THEN keine Gruppe.
  - T12: GIVEN zwei eigene Läden gleichen Namens WHEN `groups` THEN Gruppe der Klasse 3, markiert „nur melden“.
  - T13: GIVEN die 17 DE-Presets WHEN `groups` THEN keine Gruppe (Nachweis, dass 19 Läden in Production kein Doppel sind).
  - T14: GIVEN eine Gruppe in drei Reihenfolgen WHEN `winner` THEN immer die kleinste UUID.
  - T15: GIVEN In-Memory-Container (`ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`) mit 17 vorhandenen Läden WHEN die Einfügelogik von `finishOnboarding` läuft THEN bleiben es 17 Läden, vorhandene `isActive` unverändert.
  - T16: GIVEN 10 vorhandene und 7 fehlende Presets WHEN `seedStores` bzw. `missingPresets` THEN werden genau 7 eingefügt.
  - T17: GIVEN ein Laden mit `shareID` X WHEN Beitritt zu X THEN wird derselbe Laden wiederverwendet, Zahl der Läden unverändert.
  - T18: GIVEN alle neuen Dateien WHEN nach `delete(` gesucht wird THEN kein Treffer (Test liest die Quelldateien über `#filePath`).
- [ ] `MirroredSchemaSnapshotTests` (bestehend, erweitert)
  - T19: GIVEN `private-schema-aktuell.ckdb` WHEN streng nach `"CD_photoData_ckAsset" ASSET` in `CD_ShoppingItem` gesucht wird THEN vorhanden. RED zuerst (Feld fehlt), GREEN nach dem Schema-Import. Der bestehende Regex mit `(_ckAsset)?` bleibt unverändert, damit T1–T3 grün bleiben.

UI-Tests (deutsche Labeltexte, Wartehilfen aus `UITestWait.swift`):

- [ ] `ICloudDiagnosticsUITests` (Start mit `-developerMode YES -seedCloudMirrorStatusForUITests -seedDuplicateStoresForUITests -hasCompletedOnboarding YES`; `tearDown` mit `-clearCloudMirrorStatusForUITests -clearDuplicateStoresForUITests`)
  - T20: GIVEN gesäter fehlgeschlagener Export WHEN Einstellungen geöffnet THEN Zeile „iCloud-Abgleich“ zeigt „Export fehlgeschlagen“; Tipp öffnet die Ansicht mit „CD_ShoppingItem“.
  - T21: GIVEN gesätes Preset-Doppel WHEN Zeile „Doppelte Läden“ geöffnet THEN „Doppelgruppen“ = 1 und „bliebe“ sichtbar; Laden-Anzahl auf der Startseite vor und nach dem Öffnen gleich.
  - T22: GIVEN `-developerMode NO` WHEN Einstellungen geöffnet THEN keine der beiden Zeilen.
- [ ] `OnboardingCloudWaitUITests` (Start mit `-clearOnboardingForUITests`; `tearDown` mit `-hasCompletedOnboarding YES -clearOnboardingForUITests`, wie `OnboardingUITests`)
  - T23: GIVEN `-simulateCloudImportForUITests 4` WHEN App startet THEN „Deine Läden werden aus iCloud geladen …“ sichtbar, „Loslegen“ gesperrt; spätestens nach 10 s ist „Loslegen“ aktiv.
  - T24: GIVEN `-simulateCloudStoresArriveForUITests 3` WHEN App startet THEN entfällt die Einrichtung, die Startseite zeigt die zwei Läden genau einmal, nach Neustart ohne Argument bleibt sie.
  - Regression: bestehendes `OnboardingUITests` (ohne Konto im Simulator, kein Warten) bleibt grün.

RED-Phase: Alle Tests werden vor der Implementierung geschrieben und müssen mit Compilerfehlern bzw. Assertions
fehlschlagen; T19 scheitert, weil das Feld fehlt.

## Known Limitations (offene Grenzen)

- Ein Exportfehler aus Production lässt sich im Simulator nicht erzeugen (kein iCloud-Konto, Production-Ablehnung
  nicht nachstellbar). Geprüft wird die Zusammenfassung mit nachgebauten Fehlern und die Anzeige mit gesätem
  Status, nicht der Live-Weg des Ereignisses.
- Das Warten im Onboarding wird im Simulator nur mit simuliertem Import geprüft; der echte iCloud-Import mit
  eingehenden Läden ist nur am Gerät belegbar (AC-20).
- Altlasten-Doppel bleiben bestehen und werden nur angezeigt; Gleichzeitigkeit auf zwei Geräten bei Offline
  bleibt möglich (B2 verhindert die häufigen Quellen, nicht alle).
- Ist die Spiegelung lokal zurückgefallen (kein Cloud-Container), kommt nie ein Import; das Onboarding wartet dann
  bis zur Frist von 10 s.
- `quotaExceeded` erreicht Live-Ereignisse nicht zuverlässig (FB13773922); „letzter Export erfolgreich“ ist keine
  Aussage über vollständigen Abgleich.
- Der Production-Deploy von `CD_photoData_ckAsset` läuft über das Dashboard, ist nicht automatisierbar, und der
  Snapshot-Test erkennt einen vergessenen Deploy nicht. Alle übrigen `_ckAsset`-Felder (andere String-/Data-Attribute)
  fehlen weiter im Schema; erreichbar ist praktisch nur `photoData`.
- Nichts auf Hennings Geräten geprüft.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test oder ein Werkzeug-Artefakt belegt; AC-20 (Gerät) ist ausdrücklich als offene Grenze genannt
- [ ] Im Entwicklermodus zeigen Einstellungen die Zeilen „iCloud-Abgleich“ und „Doppelte Läden“ mit Detailansichten, und das Onboarding wartet im Simulator-Test sichtbar auf iCloud
- [ ] Die App ist im Simulator gestartet und der geänderte Ablauf durchgespielt (registrierter Durchlauf)
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün)

## Acceptance Criteria

Belegart: **[Unit]**, **[UI]**, **[Beleg]** (Werkzeug-Artefakt), **[Gerät]** (offene Grenze, kein Gate).

- AC-1 [Unit]: GIVEN ein `partialFailure` mit `batchRequestFailed`-Einträgen und einem Einzelfehler WHEN `summarize` THEN wird nur der Einzelfehler samt Zahl der Einträge gemeldet. Test: `CloudMirrorMonitorTests::testPartialFailureReportsNonBatchError`
- AC-2 [Unit]: GIVEN nur `batchRequestFailed` oder ein Fehler ohne Teilfehler, auch in `NSUnderlyingError` WHEN `summarize` THEN wird der oberste Fehler bzw. der verschachtelte Einzelfehler gemeldet. Test: `CloudMirrorMonitorTests::testFallbackAndUnderlyingError`
- AC-3 [Unit]: GIVEN „… in production schema“ WHEN `summarize` THEN Art `schemaIncomplete`. Test: `CloudMirrorMonitorTests::testProductionSchemaTextIsClassified`
- AC-4 [Unit]: GIVEN beendete Export-/Import-Ereignisse WHEN `handle` THEN speichert die Statusablage Zeit, Zusammenfassung und Zähler; laufende Ereignisse ändern nichts. Test: `CloudMirrorMonitorTests::testHandlePersistsOnlyFinishedEvents`
- AC-5 [Unit]: GIVEN eine App-Erweiterung bzw. die App WHEN `shouldObserve` THEN false bzw. true. Test: `CloudMirrorMonitorTests::testObserveOnlyInAppProcess`
- AC-6 [UI]: GIVEN ein gesäter fehlgeschlagener Export und Entwicklermodus WHEN Einstellungen geöffnet THEN zeigt „iCloud-Abgleich“ „Export fehlgeschlagen“ und die Detailansicht nennt die Ursache „CD_ShoppingItem“. Test: `ICloudDiagnosticsUITests::testFailedExportIsShownWithCause`
- AC-7 [UI]: GIVEN `-developerMode NO` WHEN Einstellungen geöffnet THEN erscheinen weder „iCloud-Abgleich“ noch „Doppelte Läden“. Test: `ICloudDiagnosticsUITests::testRowsHiddenOutsideDeveloperMode`
- AC-8 [Unit]: GIVEN gleiche `shareID`, Preset-Namen mit Groß/Klein-, Leerzeichen- oder Diakritikunterschied und gleichnamige eigene Läden WHEN `groups` THEN entstehen Gruppen der Klassen 1, 2 und 3 (Klasse 3 nur melden). Test: `StoreDuplicateFinderTests::testClassesOneToThree`
- AC-9 [Unit]: GIVEN gleicher Name in anderem Land, geteilter Laden neben Preset und die 17 DE-Presets WHEN `groups` THEN keine Gruppe. Test: `StoreDuplicateFinderTests::testNoFalsePositives`
- AC-10 [Unit]: GIVEN eine Gruppe in beliebiger Reihenfolge WHEN `winner` THEN immer die kleinste UUID. Test: `StoreDuplicateFinderTests::testWinnerIsSmallestUUIDRegardlessOfOrder`
- AC-11 [UI]: GIVEN ein gesätes Preset-Doppel WHEN „Doppelte Läden“ geöffnet THEN zeigt die Ansicht eine Doppelgruppe mit „bliebe“, und die Ladenanzahl bleibt unverändert (nichts gelöscht, nichts zusammengeführt). Test: `ICloudDiagnosticsUITests::testDuplicatesShownAndNothingChanged`
- AC-12 [Unit]: GIVEN die neuen Dateien WHEN nach `delete(` gesucht wird THEN kein Treffer. Test: `StoreDuplicateFinderTests::testNewFilesNeverDelete`
- AC-13 [Unit]: GIVEN kein Konto / Konto ohne Import nach 3 s / nach 10 s / Import fertig ohne Läden / Läden vorhanden WHEN `OnboardingCloudGate.decision` THEN `.proceed` / `.wait` / `.proceed` / `.proceed` / `.skipOnboarding`. Test: `CloudMirrorMonitorTests::testOnboardingGateDecisions`
- AC-14 [UI]: GIVEN simulierten Import (4 s) WHEN die App neu startet THEN ist der Hinweis „Deine Läden werden aus iCloud geladen …“ sichtbar, „Loslegen“ gesperrt und spätestens nach 10 s aktiv. Test: `OnboardingCloudWaitUITests::testHintAndLockedButtonUntilImportDone`
- AC-15 [UI]: GIVEN simuliert eintreffende Läden WHEN die App neu startet THEN entfällt die Einrichtung, die Startseite zeigt die Läden genau einmal und bleibt nach Neustart ohne Argument. Test: `OnboardingCloudWaitUITests::testArrivingStoresSkipOnboarding`
- AC-16 [UI]: GIVEN Simulator ohne iCloud-Konto WHEN das Onboarding startet THEN gibt es kein Warten (der bestehende Durchlauf bleibt unverändert grün). Test: `OnboardingUITests::testOnboardingWalkthroughCreatesChosenStoresAndName` (unverändert)
- AC-17 [Unit]: GIVEN vorhandene Läden WHEN die Einfügelogik von `finishOnboarding` und `seedStores` läuft THEN werden nur fehlende Presets eingefügt, vorhandene bleiben unverändert (17 bleiben 17; bei 10 vorhandenen genau 7 neu). Test: `StoreDuplicateFinderTests::testOnboardingInsertsOnlyMissingPresets` und `::testSeedStoresInsertsOnlyMissingPresets`
- AC-18 [Unit]: GIVEN ein Laden mit `shareID` X WHEN Beitritt zu X THEN wird derselbe Laden wiederverwendet. Test: `StoreDuplicateFinderTests::testJoinReusesStoreWithSameShareID`
- AC-19 [Beleg]: `docs/cloudkit/private-schema-aktuell.ckdb` enthält `"CD_photoData_ckAsset" ASSET` in `CD_ShoppingItem`; `diff` zwischen Export vor und nach dem Import zeigt nur dieses Feld, `validate-schema` ohne Fehler, Dashboard-Diff vor dem Deploy zeigt nur dieses Feld, Production-Export enthält es, Management-Token entfernt (`remove-token --type management`, kein Tokenwert im Repo). Test (automatisch): `MirroredSchemaSnapshotTests::testPhotoDataAssetFieldIsListed` (rot vor dem Import, grün danach)
- AC-20 [Gerät, offene Grenze, kein Gate]: Mit TestFlight-Build auf Hennings Gerät erscheint der Exportstatus, und eine Neuinstallation erzeugt keine Doppel. Nur nach seinem wörtlichen „jetzt ist ein Test möglich“; bis dahin in jedem Bericht „am Gerät nicht belegt“.
- AC-21 [Unit]: GIVEN der Bestand WHEN die Regression läuft THEN bleiben `MirroredSchemaSnapshotTests` T1–T3, `SchemaCloudKitCompatibilityTests`, `ExistingDataSurvivesCloudEnableTests`, `SharedModelContainerExtensionDetectionTests` und die UI-Klassen `OnboardingUITests`, `StoreSetupUITests`, `DeveloperModeUnlockUITests` grün; `RestockShareExtension/` und `SmartCartWidgets/` unverändert. Test: gesamte Unit-Suite und genannte UI-Klassen

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es ändert sich weder die Store-Adressierung noch das Prinzip „ein Schema, ein Store für alle
  Prozesse“. Der Beobachter ist rein lesend, die Doppelvermeidung nutzt vorhandene Daten. Die Gewinnerregel
  (kleinste UUID) ist nur vorbereitet, nicht angewendet; würde B3 später umgesetzt, bekäme das Zusammenführen
  einen eigenen ADR.

## Changelog

- 2026-10-18: Initial spec created
- 2026-10-18: Abweichung von AC-19 auf Anweisung des PO: Der Management-Token wird **nicht** entfernt, er bleibt dauerhaft im Schlüsselbund (kein `remove-token`), damit künftige Schema-Arbeit ohne neuen Dashboard-Schritt läuft. Der AC-Text ist durch den Spec-Freeze gesperrt; diese Zeile hat Vorrang.
- 2026-10-19: Issue #166: Einrichtungsläufe werden nicht mehr ignoriert, sondern als `lastSetup` gespeichert und angezeigt; der Beobachter startet vor der Container-Erzeugung. Siehe `docs/specs/services/icloud-einrichtung-sichtbar.md`.
