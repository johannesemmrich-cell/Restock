---
entity_id: shared-store-stations-sync
type: feature
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: feat-234-d3-gaenge-teilen
tags: [feature, store, stations, shared-store, cloudkit, sync, schema]
---

# Laden-Stationen: Gänge geteilter Läden über den SharedStore-Record abgleichen, Durchgang 3 (Issue #234)

## Approval

- [ ] Approved

Offenlegung für die Freigabe:

1. **Festlegung aus D1 bleibt:** „Ganzstand mit Zeitstempel, der spätere gewinnt“
   (`docs/specs/models/store-stations.md`, Ausblick → D3). Kein Abgleich je Gang. Die Alternativen stehen im
   Abschnitt „Alternativen“.
2. **Schema-Schritt ist Pflicht und gehört zu dieser Spec.** Ein neues Feld im Typ `SharedStore` der öffentlichen
   Datenbank muss vor dem nächsten TestFlight-Upload in Development und Production stehen (Abschnitt „Schema-Schritt“).
   Ohne ihn fällt der Schema-Fallback (#121) für den ganzen Laden zurück, auch für Kategorien und Merkungen.
3. **PO-Entscheidung 2026-11-02:** Der Hinweis in „Kategorien einrichten“ bei geteilten Läden lautet künftig
   „Änderungen an den Gängen gelten für alle Mitglieder dieses Ladens.“ (de) bzw. „Changes to the aisles apply to
   all members of this store.“ (en).
4. **Keine Änderung an gesperrten Specs.** D1, 2a, 2b-1, 2b-2 und #121 bleiben unverändert. Dass `removeStations()`
   künftig einen Löschvermerk statt `""` schreibt, ändert eine D1-Zusage („Laden ohne Gänge“), nicht deren Wirkung:
   alle Leser gehen über `hasStations`.
5. **Bestandstests:** Geändert werden nur vier Stellen vorhandener Tests (je eine Zeile), die den alten Hinweistext oder die alte
   Feldliste wörtlich prüfen (T5, T6 in `SharedStoreSchemaTests`, Schlüsseltext in `StoreStationsTests`) sowie Y7. Alle
   anderen bleiben unverändert und müssen grün bleiben.

## Purpose

Wer einen Laden teilt und dort Gänge einrichtet (Reihenfolge, Stichwörter, ausgeblendete Kategorien), sieht sie heute
nur auf den eigenen Geräten. Mitglieder des geteilten Ladens sehen ihn ohne Gänge, und der Hinweis in „Kategorien
einrichten“ sagt ausdrücklich „Gänge bleiben bis zum Abgleich auf diesem Gerät.“. Nach dieser Spec reisen die Gänge
im `SharedStore`-Record mit: Wer sie einrichtet, ändert oder entfernt, ändert sie für alle Mitglieder, der spätere
Stand gewinnt.

Datenmodell, Zuordnung Artikel → Gang und Sortierung stehen in `docs/specs/models/store-stations.md` (D1), die
Oberfläche in 2a, 2b-1 und 2b-2. Das wird hier nicht wiederholt.

## Source

- **Erweitert:** `SmartCart/Models/StoreCategories.swift` (reine Funktion, Kodieren/Dekodieren),
  `SmartCart/Models/Store.swift` (`removeStations()`, neue `adoptRemoteStationConfig(_:)`),
  `SmartCart/Services/SharedStoreService.swift` (Feld `stationsJSON`, `mergeIntoRecord`, `push`, `pull`,
  `SharedStoreSchema.optionalExtensionFields`), `SmartCart/Services/SyncCoordinator.swift` (`apply(…, stations:)`,
  beide Aufrufer), `SmartCart/Resources/{de,en}.lproj/Localizable.strings` (Hinweistext)
- **Identifier:** `StoreCategories.mergeStationConfig(local:remote:)`, `StoreCategories.encodeStationConfig(_:)`,
  `StoreCategories.decodeStationConfig(_:)`, `Store.adoptRemoteStationConfig(_:)`, `Store.removeStations()`,
  `SharedStoreService.mergeIntoRecord(_:store:code:isNewRecord:includeExtensionFields:)`,
  `SharedStoreService.MergedState`, `SharedStoreService.push(store:)`, `SharedStoreService.pull(shareID:)`,
  `SyncCoordinator.apply(items:members:…stations:modifiedAt:to:)`, `SharedStoreSchema.optionalExtensionFields`,
  Localizable-Schlüssel `station.setup.shared`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| D1 (PR #240) bis 2b-2 (PR #250) | feature | gemergt; `Station`, `StationConfig { stations, hidden, date }` (`StoreCategories.swift` Z. 179–192, `date` ausdrücklich „für den Abgleich in D3“), `Store.stationConfig`/`hasStations`/`applyStationConfig`/`updateStationConfig`/`removeStations` |
| `StoreCategories.merge`, `mergeAssignments` | module | Muster „später gewinnt“; werden nicht verändert |
| `Store.ensureCustomCategory(_:emoji:)`, `Store.bumpRouteRevision()` (private static, nur innerhalb `Store` aufrufbar) | model | beim Übernehmen: Gang-Name als eigene Kategorie anlegen (vorhandene bleiben unverändert), Liste neu sortieren |
| `SharedStoreService` (#121), `SharedStoreSchema.coreFields`/`optionalExtensionFields`, `SharedStoreDatabase` | module | Push-Merge, Pull, alles-oder-nichts-Fallback; bleibt unverändert, `stationsJSON` kommt in die optionale Menge |
| `SyncCoordinator.apply`/`pull`/`push` | module | Merge gegen den lokalen Stand zum Anwendungszeitpunkt, Fortschrittsmarke nur nach erfolgreichem Speichern |
| CloudKit-Typ `SharedStore` (öffentliche DB) | schema | neues Feld `stationsJSON`; Datei `docs/cloudkit/private-schema-aktuell.ckdb`, Ablauf `.github/workflows/cloudkit-schema.yml`, Production per Dashboard |
| `RestockTests/SharedStoreSchemaTests` (Fake-Produktion, T8 Drift-Test), `SharedStoreMergeTests`, `StoreStationsTests` | test | werden erweitert |
| `-skipCloudKitForScreenshots`, Seed `-seedStationStoreSharedForUITests` (`shareID` „UITEST-NOSHARE“) | test helper | UI-Tests schicken nichts an CloudKit |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | `mergeStationConfig(local:remote:)`, `encodeStationConfig`, `decodeStationConfig` (~+25) |
| `SmartCart/Models/Store.swift` | MODIFY | `removeStations()` schreibt Löschvermerk; neue `adoptRemoteStationConfig(_:)` (~+25) |
| `SmartCart/Services/SharedStoreService.swift` | MODIFY | Feld `stationsJSON` in `mergeIntoRecord`, `MergedState`, `push`, `pull`; `optionalExtensionFields` (~+25) |
| `SmartCart/Services/SyncCoordinator.swift` | MODIFY | `apply(…, stations:)` + beide Aufrufer (~+15) |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | Text von `station.setup.shared` (je 1 Zeile geändert) |
| `docs/cloudkit/private-schema-aktuell.ckdb` | MODIFY | `stationsJSON STRING QUERYABLE SEARCHABLE SORTABLE` im Typ `SharedStore` (+1) |
| `RestockTests/StoreStationsTests.swift` | MODIFY | G1–G9; Schlüsseltext-Prüfung (Z. 1061) auf neuen Text (~+110) |
| `RestockTests/SharedStoreMergeTests.swift` | MODIFY | M1–M7 (~+110) |
| `RestockTests/SharedStoreSchemaTests.swift` | MODIFY | T5/T6 (Feldliste, Fake-Produktion `extensionFields`), neuer T17 (~+35) |
| `RestockUITests/StationSetupExtrasUITests.swift` | MODIFY | Y7: erwarteter Hinweistext (1 Zeile) |
| `docs/specs/views/station-picker-adoption.md` | MODIFY | nur Changelog: AC-12/Y7 durch diese Spec abgelöst (gesperrte Spec) |

Nicht berührt: `StationSetupView.swift` (Hinweis kommt aus dem Schlüssel), `StoreTemplates.swift`, `ShoppingRoute.swift`,
`.github/workflows/ci.yml`, `project.pbxproj` (keine neue Datei), die gesperrten Specs. `CLAUDE.md` wird mit dem
Abschluss ergänzt (Absatz „Laden-Stationen“; Doku, keine eigene Position).

### Estimated Changes

- Files: 10 Positionen (4 Produktiv-Swift, Strings-Paar, Schema, 4 Testdateien); Strings-Paar zählt als eins
- LoC: Produktiv ca. +100 bis +120, Unit-Tests ca. +220 bis +300, UI ca. +1/-1; das liegt im Rahmen der
  Scoping-Limits für Produktivcode, die Gesamtzahl mit Tests über 250. Meldet der Implementierer mehr als 450
  Zeilen insgesamt, hält er an.
- Funktionen ≤ 50 Zeilen.

## Implementation Details

### (a) Neues Record-Feld `stationsJSON`

Optionales Feld im Typ `SharedStore`, Inhalt: die mit dem vorhandenen `JSONEncoder` kodierte `StationConfig` (gleiche
Kodierung wie `Store.stationConfigJSON`, damit Zeichenketten gleicher Konfigurationen gleich sind). Das Feld steht in
`SharedStoreSchema.optionalExtensionFields` (jetzt `categoriesJSON`, `assignmentsJSON`, `stationsJSON`), nicht in
`coreFields`. Der Schema-Fallback (#121) bleibt **alles-oder-nichts**: lehnt Production ein Feld ab, wird genau einmal
ohne alle drei Felder gespeichert, `includeExtensionFields == false` lässt `stationsJSON` weg.

### (b) Reine Merge-Funktion

`StoreCategories.mergeStationConfig(local: StationConfig?, remote: StationConfig?) -> StationConfig?`:

- Das spätere `date` gewinnt. **Gleichstand: lokal.**
- `nil` zählt als `Date.distantPast`. Hat nur eine Seite eine Konfiguration, gewinnt sie. Haben beide `nil`, ist das
  Ergebnis `nil`.
- `decodeStationConfig(_ json: String?) -> StationConfig?` liefert `nil` für `nil`, leeren String und kaputtes JSON.
  Ein kaputter oder fehlender Remote-Stand überschreibt deshalb nie einen gültigen lokalen Stand.
- Ganzstand: es wird nie zwischen Gängen gemischt, das Ergebnis ist genau `local` oder genau `remote`.

### (c) Push: `mergeIntoRecord`

Im Block `if includeExtensionFields` liest die Funktion `record["stationsJSON"]`, dekodiert, mergt mit
`store.stationConfig` und schreibt das Ergebnis zurück, **nur wenn es nicht `nil` ist** (sonst bleibt das Feld
unangetastet, der Record behält unbekannte und leere Felder). Der gemergte Stand wird als neues Element `stations:
StationConfig?` in `MergedState` und im Rückgabetupel von `push(store:)` zurückgegeben, damit der Aufrufer ihn lokal
anwenden kann. Der Merge arbeitet auf dem Server-Record (`currentRecord`), nicht auf einer Kopie; nach
`serverRecordChanged` wird gegen den Gewinner neu gemergt (Bestand).

### (d) Pull und Anwenden

`pull(shareID:)` liefert den **Rohwert** `stations: StationConfig?` (nur dekodiert, kein Merge, wie bei Preisen).
`SyncCoordinator.apply(…, stations: StationConfig? = nil, …)` mergt zum Anwendungszeitpunkt gegen den lokalen Stand:

1. `merged = mergeStationConfig(local: store.stationConfig, remote: stations)`
2. nur wenn `merged != store.stationConfig`: `store.adoptRemoteStationConfig(merged)`.

Beide Aufrufer (`pull` Z. 105, `push` Z. 128) reichen `stations` durch; der Push reicht den gemergten Stand aus dem
Ergebnis durch. Die Reihenfolge in `apply` ist: Mitglieder, Kategorien, Zuordnungen, **Gänge**, Preise, Artikel.
Dadurch liegen die eigenen Kategorien der Gang-Namen (reisen über `categoriesJSON`) und die Merkungen schon vor.

### (e) Löschvermerk statt leerem Feld

`Store.removeStations()` schreibt `StationConfig(stations: [], hidden: [], date: Date())` statt `""` und ruft
weiter `Store.bumpRouteRevision()`. Begründung (Risiko 1 der Analyse): Ein leerer lokaler Stand kann im Vergleich
„später gewinnt“ nicht gewinnen, beim nächsten Pull kämen die Gänge des Partners zurück. Der Vermerk trägt das Datum,
gewinnt gegen ältere Stände und reist als Ganzstand.

Wie Leser mit der leeren Konfiguration umgehen (geprüft im Code):

- `Store.hasStations` / `activeStationConfig` (Store.swift Z. 335–340) verlangen `!stations.isEmpty`. Eine leere
  Konfiguration gilt dort als „keine Gänge“; damit verhalten sich Sortierung, Anzeige, Auswahl und Abhaken wie im
  Laden ohne Gänge (D1-Zusage).
- `StationSetupView.config` (Z. 25) ist `store.hasStations ? store.stationConfig : nil`, also `nil` beim Vermerk; die
  Übersicht zeigt wie bisher die Vorlagen-Auswahl.
- `StationSetupView.addStation()` (Z. 230) nimmt `store.stationConfig ?? StationConfig(stations: [], hidden: [], date: Date())`
  als Basis. Beim Vermerk ist das der Vermerk mit `hidden: []`; deshalb schreibt `removeStations()` ausdrücklich
  `hidden: []` und übernimmt nie das alte `hidden`. Ein neuer Gang nach dem Entfernen startet also ohne
  ausgeblendete Kategorien, wie vorher mit `""`.
- `StationSetupView.delete(_:in:)` (Z. 246) und `deleteDialog` zählen `store.stationConfig?.stations.count ?? 0`;
  beim Vermerk 0, derselbe Zweig wie bei `nil`. Die Löschwege (`renameStation` Z. 425, `deleteStation` Z. 465)
  suchen den Gang per `stationNamed` in der Konfiguration und finden im Vermerk nichts, ändern also nichts.
- Der Seed-Aufräumer und das Anlegen über Vorlagen gehen über `applyStationConfig`/`updateStationConfig` und
  ersetzen den Vermerk durch die neue Konfiguration mit neuem Datum.

### (f) `Store.adoptRemoteStationConfig(_:)`

Übernimmt eine fremde Konfiguration **ohne neuen Zeitstempel**:

- setzt `stationConfig = config` mit dem mitgelieferten `date` (kein `Date()`),
- legt für jeden Gang `ensureCustomCategory(name, emoji:)` an (vorhandene bleiben unverändert),
- ruft `Store.bumpRouteRevision()` **nur, wenn sich `stationConfigJSON` tatsächlich geändert hat**.

`applyStationConfig` darf dafür nie benutzt werden: es stempelt `date = Date()` neu, der übernommene Stand würde dann
beim nächsten Push als „neuer“ zurückgeschrieben und bei den anderen Mitgliedern wieder übernommen (Ping-Pong).
`removeStations()` und alle Schreibwege der Oberfläche bleiben die einzigen Orte, die ein neues Datum vergeben.

### (g) Hinweistext

`station.setup.shared`: de „Änderungen an den Gängen gelten für alle Mitglieder dieses Ladens.“, en „Changes to the
aisles apply to all members of this store.“. Platzhalterzahl unverändert 0; Schlüssel- und Platzhaltergleichheit
prüft `LocalizationKeyParityTests`. `StationSetupView.sharedHint` erscheint weiter nur bei `store.shareID != nil`.

### Schema-Schritt

Der Schema-Schritt gehört zur Umsetzung und wird vom Tech Lead selbst erledigt (kein Auftrag an Henning, Memory
`schema-schritt-nicht-erfragen`), **vor dem nächsten TestFlight-Upload**:

1. `docs/cloudkit/private-schema-aktuell.ckdb`: im Typ `SharedStore` die Zeile
   `stationsJSON    STRING QUERYABLE SEARCHABLE SORTABLE,` alphabetisch nach `ownerDevice`/`pricesJSON` einordnen
   (cktool sortiert Felder alphabetisch; Typ wie `categoriesJSON`). Der Drift-Test T8 hält Feldliste und Datei gleich.
2. Development: Ablauf `cloudkit-schema.yml` mit `mode=import-development` (nur von `main`, Pflichtfeld
   `confirm` = `development`).
3. Production: im CloudKit-Dashboard „Deploy Schema Changes…“. Production ist nur additiv; der Deploy-Dialog zeigt
   teils fälschlich „0 Änderungen“.
4. Danach `mode=export` ausführen und Development gegen Production vergleichen; die Repo-Datei muss byteidentisch mit
   dem Development-Export sein.

Ohne Schritt 3 lehnt Production das Feld ab, der Fallback speichert ohne alle Erweiterungsfelder, und `lastFailureKind`
steht auf `.schemaIncomplete` (Bestand, #121); Kategorien und Merkungen reisten dann ebenfalls nicht.

## Alternativen

- **(a) Abgleich je Gang** (wie Kategorien je Name): verliert bei gleichzeitigen Änderungen weniger. Aber Reihenfolge,
  `hidden` und Umbenennen (als Löschen plus Anlegen) bräuchten eigene Zeitstempel und Löschvermerke je Gang, etwa der
  3- bis 4-fache Umfang. Es kippte die D1-Festlegung „Ganzstand mit Zeitstempel“. Nicht jetzt: erst bauen, wenn
  gleichzeitige Änderungen in der Praxis auftreten.
- **(b) Nur der Besitzer schreibt Gänge:** kein Merge nötig. Aber Mitglieder könnten nichts mehr einrichten, und
  `ownerDevice` ist ein Anzeigename, keine Identität; der Besitzer ist technisch nicht prüfbar. Trägt nicht.
- **(c) Gestaffelter Schema-Fallback** (erst nur `stationsJSON` weglassen, dann alle): schützt Kategorien bei
  vergessenem Deploy, kostet einen dritten Speicherversuch und mehr Zustände in `syncToCloud`. Durch den Pflicht-Deploy
  mit Export-Vergleich überflüssig. Es kippte die #121-Festlegung „genau ein Wiederholungsversuch, alles oder nichts“.
- **(d) Kein Abgleich, nur Hinweis** (Zustand vor D3): kostet nichts, aber Mitglieder sehen den Laden ohne Gänge; das
  ist der Grund für den Durchgang.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests (`RestockTests`), In-Memory-Container immer mit `cloudKitDatabase: .none`, eindeutige `shareID` je Test,
Aufräumprüfung der `lastSync_UT-*`/`deletedTombstones_UT-*`-Schlüssel wie in `SharedStoreMergeTests`.

`StoreStationsTests.swift` (reine Funktion und Modell):

- [ ] G1: GIVEN lokal Datum T und remote Datum T+1 WHEN `mergeStationConfig` THEN Ergebnis ist genau der Remote-Stand
  (Ganzstand, keine Mischung); umgekehrt (remote T-1) gewinnt lokal.
- [ ] G2: GIVEN beide Konfigurationen mit gleichem `date` und verschiedenem Inhalt WHEN `mergeStationConfig` THEN gewinnt
  lokal.
- [ ] G3: GIVEN lokal `nil` und remote gültig WHEN `mergeStationConfig` THEN remote; GIVEN lokal gültig und remote `nil`
  THEN lokal; GIVEN beide `nil` THEN `nil`.
- [ ] G4: GIVEN `decodeStationConfig` mit `nil`, `""`, `"{"` und `"[]"` WHEN dekodiert THEN jeweils `nil`; GIVEN lokal gültig
  und Remote-Zeichenkette kaputt WHEN dekodiert und gemergt THEN bleibt der lokale Stand; Kodieren und Dekodieren einer
  Konfiguration ist verlustfrei (gleiches `date`).
- [ ] G5: GIVEN Laden mit Gängen und `hidden` WHEN `removeStations()` THEN `stationConfig` hat `stations == []`,
  `hidden == []`, `date` ≥ Zeitpunkt vor dem Aufruf; `hasStations == false`; `stationName(of:)` und `stationRank(of:)`
  sind `nil`; der Zähler unter `Store.routeRevisionKey` (App-Gruppe, `shoppingRouteRevision`) ist gestiegen.
- [ ] G6: GIVEN Laden ohne Gänge WHEN `adoptRemoteStationConfig(c)` THEN `stationConfig == c` einschließlich des
  mitgelieferten `date` (nicht neu gestempelt), jeder Gang-Name ist eigene Kategorie mit seinem Emoji, `hasStations`
  gilt.
- [ ] G7: GIVEN `adoptRemoteStationConfig(c)` WHEN erneut mit demselben `c` THEN ändert sich `stationConfigJSON` nicht
  und `bumpRouteRevision` wird nicht ein zweites Mal ausgelöst; WHEN danach `mergeStationConfig(local: store.stationConfig,
  remote: c)` THEN gleicher Stand (kein Ping-Pong: übernommener Stand ist weder neuer noch anders als der Absender).
- [ ] G8: GIVEN Mitglied mit Laden ohne lokale Gänge (`stationConfigJSON == ""`) und fremdem Löschvermerk WHEN
  `merge` und `adoptRemoteStationConfig` THEN `stationConfig` ist der Vermerk, `hasStations == false`, die Übersicht
  würde die Vorlagen-Auswahl zeigen (`hasStations`-Bedingung), und ein folgendes `addStation`-Basis hat `hidden == []`.
- [ ] G9: GIVEN Datei `Localizable.strings` de und en WHEN Schlüssel `station.setup.shared` gelesen THEN de „Änderungen
  an den Gängen gelten für alle Mitglieder dieses Ladens.“ und en „Changes to the aisles apply to all members of this
  store.“. Kein zusätzlicher Test: G9 ist die bestehende Prüfung in Z. 1061, deren erwarteter Text auf den neuen
  geändert wird (zählt im Umfang als Änderung, nicht als neuer Test).

`SharedStoreMergeTests.swift` (ohne CloudKit, `CKRecord` nie hochgeladen):

- [ ] M1: GIVEN Server-Record mit `stationsJSON` Datum T+1 und lokaler Stand Datum T WHEN `mergeIntoRecord(…,
  includeExtensionFields: true)` THEN bleibt das Feld im Record unverändert und `MergedState.stations` ist der Remote-Stand.
- [ ] M2: GIVEN Server-Record Datum T und lokaler Stand Datum T+1 WHEN `mergeIntoRecord` THEN trägt der Record den
  lokalen Stand (dekodiert gleich) und `MergedState.stations` ist der lokale.
- [ ] M3: GIVEN Server-Record ohne `stationsJSON` und lokal keine Gänge WHEN `mergeIntoRecord` THEN fehlt das Feld
  weiterhin im Record (nicht auf `""` oder `{}` gesetzt) und `MergedState.stations == nil`; GIVEN `includeExtensionFields:
  false` WHEN `mergeIntoRecord` THEN bleibt `stationsJSON` im Record unberührt, auch mit lokalen Gängen.
- [ ] M4: GIVEN lokal Stand Datum T und `apply(…, stations: remote)` mit Datum T+1 WHEN angewendet THEN `store.stationConfig`
  ist der Remote-Stand mit unverändertem Datum, und es gibt keinen Stempel von „jetzt“.
- [ ] M5: GIVEN lokal Stand T+1 und `apply(…, stations: remote)` mit Datum T WHEN angewendet THEN bleibt der lokale
  Stand; bei `stations: nil` ebenso (Pull ohne Feld, ältere App-Version schrieb den Record).
- [ ] M6: GIVEN lokaler Löschvermerk Datum T+1 und Remote-Stand mit Gängen Datum T WHEN `apply` und `mergeIntoRecord`
  THEN gewinnt der Vermerk in beide Richtungen (die Gänge des Partners kommen nicht zurück), im Record steht der Vermerk.
- [ ] M7: GIVEN `apply` zweimal mit demselben Remote-Stand WHEN der zweite Aufruf THEN schreibt `store.stationConfigJSON`
  nicht neu (`merged == lokal`), der Zähler unter `Store.routeRevisionKey` steigt nicht; `store.stationConfig.date` bleibt das des Absenders.

`SharedStoreSchemaTests.swift` (Fake-Produktion):

- [ ] T5 (angepasst): GIVEN volles Schema WHEN Push THEN ein Speicherversuch, Felder `categoriesJSON`, `assignmentsJSON`
  und `stationsJSON` werden geschrieben, `allowedFields` der Fake-Produktion enthalten `stationsJSON`.
- [ ] T6 (angepasst): `SharedStoreSchema.optionalExtensionFields == ["categoriesJSON", "assignmentsJSON", "stationsJSON"]`.
- [ ] T17 (neu): GIVEN Fake-Produktion ohne `stationsJSON` (lehnt das Feld ab) und lokale Gänge WHEN Push THEN greift
  genau einmal der Fallback, der gespeicherte Record enthält **keines** der drei Erweiterungsfelder, Artikel und Mitglieder
  stehen im Record, `schemaRejection != nil`, höchstens drei Speicherversuche (Grenze aus #121 unverändert).
- [ ] T8 (unverändert; rot, sobald `stationsJSON` im Code steht und die `.ckdb`-Zeile fehlt, grün mit ihr): Feldliste des Codes gleich Feldliste des Typs `SharedStore` in der
  Schemadatei; schlägt ohne die neue Zeile in der `.ckdb` fehl.

UI-Test (`RestockUITests`):

- [ ] Y7 (angepasst): GIVEN Seed mit `shareID` (`-seedStationStoreSharedForUITests`, `-skipCloudKitForScreenshots`) WHEN
  „Kategorien einrichten“ THEN steht der neue Hinweis „Änderungen an den Gängen gelten für alle Mitglieder dieses
  Ladens.“ da; die Gang-Zeilen lassen sich öffnen. Der Test schickt nichts an CloudKit.

Echter Abgleich mit zweitem Konto ist nicht automatisierbar (Offene Grenzen).

### Durchlauf (Pflicht)

Im Simulator, auf dem Stand dieser Änderung, als Nutzer, Belegbilder als `XCTAttachment` im Testlauf (Muster 2a;
Ablage unter `docs/artifacts/feat-234-d3-gaenge-teilen/`): (1) Seed mit `shareID` (`-seedStationStoreSharedForUITests`,
`-skipCloudKitForScreenshots`) → ··· → „Kategorien einrichten“ → neuer Hinweis sichtbar; (2) dort „Gänge entfernen“
bestätigen, Ladenliste zeigt den Laden ohne Gänge, erneut „Kategorien einrichten“ zeigt die Vorlagen-Auswahl; eine
Vorlage wählen, Gänge erscheinen wieder (Löschvermerk wird ersetzt, altes `hidden` nicht übernommen); (3) Laden ohne
`shareID`: Hinweis fehlt, Gänge wie bisher. Der Abgleich zwischen zwei Geräten selbst ist im Durchlauf nicht
erreichbar (zweites Konto), er ist über M1–M7 und T17 geprüft. Nichts auf Hennings Geräten ohne sein ausdrückliches Wort.

## Acceptance Criteria

- AC-1: Der Typ `SharedStore` hat ein optionales Feld `stationsJSON`, es steht in
  `SharedStoreSchema.optionalExtensionFields` und in `docs/cloudkit/private-schema-aktuell.ckdb`. Tests: T6, T8, T5.
- AC-2: `StoreCategories.mergeStationConfig` wählt den Stand mit dem späteren `date` als Ganzes, bei Gleichstand den
  lokalen; `nil` gilt als `distantPast`. Tests: G1, G2, G3.
- AC-3: Ein fehlendes oder kaputtes Remote-Feld überschreibt nie einen gültigen lokalen Stand. Tests: G4, M5.
- AC-4: Der Push mergt die lokalen Gänge gegen den Server-Record im `includeExtensionFields`-Block, schreibt nur ein
  nicht leeres Ergebnis und liefert den gemergten Stand zurück. Tests: M1, M2, M3.
- AC-5: Der Pull liefert den Rohwert; `SyncCoordinator.apply` mergt gegen den lokalen Stand zum Anwendungszeitpunkt
  und schreibt nur bei Änderung; Übernahme behält das Datum des Absenders. Tests: M4, M5, M7.
- AC-6: „Gänge entfernen“ schreibt einen Löschvermerk (`stations: []`, `hidden: []`, `date` jetzt); der Laden gilt als
  ohne Gänge, und der Vermerk gewinnt gegen ältere Remote-Stände. Tests: G5, M6, G8.
- AC-7: `Store.adoptRemoteStationConfig` setzt kein neues Datum, legt die Gang-Namen als eigene Kategorien an und löst
  die Weg-Version nur bei tatsächlicher Änderung aus; ein übernommener Stand führt zu keinem Rückschreiben (kein
  Ping-Pong). Tests: G6, G7, M7.
- AC-8: Ein Mitglied ohne lokale Gänge erhält beim Pull bzw. Beitritt die Gänge des Ladens. Tests: G3, G6, M4.
- AC-9: Der Schema-Fallback (#121) bleibt alles-oder-nichts: ohne Erweiterungsfelder wird `stationsJSON` weder
  geschrieben noch verändert. Tests: T17, M3.
- AC-10: Der Hinweis `station.setup.shared` lautet de und en wie in „Implementation Details (g)“; de/en-Schlüssel und
  Platzhalter bleiben gleich. Tests: G9, Y7, `LocalizationKeyParityTests`.
- AC-11: Schema-Schritt vor dem nächsten TestFlight-Upload erledigt: `.ckdb` ergänzt, Development importiert,
  Production deployt, Export-Vergleich Development ↔ Production ohne Unterschied, Repo-Datei byteidentisch mit dem
  Development-Export. Nicht automatisch testbar, Nachweis ist ein Protokoll: Protokoll des Ablaufs `cloudkit-schema.yml` (`mode=export`) im Abschlussbericht;
  Test T8 prüft die Repo-Datei.
- AC-12: Laden ohne `shareID` und alle bisherigen Gang-Tests (D1 bis 2b-2) verhalten sich unverändert; UI-Seed
  `UITEST-NOSHARE` schickt nichts an CloudKit. Tests: Bestandssuite, Y7.

## Definition of Done

- [ ] Build erfolgreich, alle Unit- und UI-Tests grün (neue Tests G1–G8, M1–M7, T17 waren vor der Umsetzung rot)
- [ ] CI alle Teile grün (A, B, C, D unverändert in der Klassenaufteilung)
- [ ] Echter Durchlauf im Simulator mit Belegbildern registriert (Abschnitt „Durchlauf (Pflicht)“)
- [ ] Schema-Schritt erledigt (AC-11): `.ckdb` ergänzt, Development importiert, Production deployt, Export-Vergleich
  Development ↔ Production ohne Unterschied, Protokoll unter `docs/artifacts/feat-234-d3-gaenge-teilen/`
- [ ] `docs/specs/views/station-picker-adoption.md`: Changelog-Eintrag, dass AC-12/Y7 (Hinweistext) durch diese Spec
  abgelöst sind (die Spec ist gesperrt, daher nur Changelog)
- [ ] `CLAUDE.md`-Absatz „Laden-Stationen“ um Durchgang 3 ergänzt (Grenze „Gänge bleiben lokal“ entfernt, Feld
  `stationsJSON` und Schema-Pflicht genannt), Issue #234 aktualisiert

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** additives, optionales Feld nach dem Muster von `categoriesJSON`/`assignmentsJSON` (#85/#94) und
  `schemaIncomplete` (#121). Die Wahl „Ganzstand mit Zeitstempel“ ist in D1 getroffen und hier nur umgesetzt; es gibt
  keine neue Architektur, daher keine ADR.

## Offene Grenzen

- **Gerätezeit statt Serverzeit:** Der Vergleich nutzt `StationConfig.date` der Absender-Geräte. Geht eine Uhr falsch,
  gewinnt der falsche Stand (wie bei Kategorien akzeptiert).
- **Gleichzeitige Bearbeitung:** Ändern zwei Mitglieder die Gänge zwischen zwei Abgleichen, geht die ältere Änderung
  ganz verloren (Ganzstand). Abhilfe wäre Alternative (a), erst bei beobachteten Konflikten.
- **Gelernter Weg reist nicht:** Der je Gerät gelernte Weg (`ShoppingRoute`) hängt am Gang-Namen; wird ein Gang bei
  einem anderen Mitglied umbenannt, fehlt dem Empfänger der gelernte Weg unter dem alten Namen. Konfiguration,
  Merkungen (`assignmentsJSON`) und Artikelkategorien (`itemsJSON`) reisen.
- **Ältere App-Versionen:** Sie kennen `stationsJSON` nicht und zeigen den Laden ohne Gänge. Dass sie das Feld beim
  eigenen Push nicht löschen, ist nur durch Recherche belegt, nicht durch Apple-Dokumentation: CloudKit speichert nur
  ausdrücklich gesetzte Felder, und `mergeIntoRecord` arbeitet auf dem geladenen Server-Record (Christian Selig,
  „CKSyncEngine questions and answers“, https://christianselig.com/2026/01/cksyncengine/; Apple-Forum
  https://developer.apple.com/forums/thread/763641). Beim Produktions-Schema gilt: nur additiv, der Deploy-Dialog
  zeigt teils fälschlich „0 Änderungen“, daher der Export-Vergleich (https://developer.apple.com/forums/thread/749729,
  https://developer.apple.com/forums/thread/748719).
- **Kein echter Zwei-Konten-Abgleich automatisiert:** Teilen mit zweitem iCloud-Konto, Einladung, Push und
  Serverrechte sind wie in #98 Durchgang 4 nicht automatisierbar; geprüft wird die Logik mit Schein-Antworten und
  einem Fake für die Datenbank.
- **UI-Seed:** `UITEST-NOSHARE` mit `-skipCloudKitForScreenshots` schickt nichts; ob ein echter UI-Lauf nichts sendet,
  ist durch Konstruktion begründet, nicht gemessen.
- **F006 (LOW) aus 2b-2 bleibt offen:** `SyncCoordinator.resubscribeAll` legt beim Start auch für den Seed mit
  `shareID` eine Abfrage-Subskription an, `pushWidgetCheckoffsIfNeeded` kennt `-skipCloudKitForScreenshots` nicht.
- **Löschvermerk bleibt stehen:** Eine leere Konfiguration mit Datum bleibt im Record und im Laden gespeichert; sie
  ist klein und gilt überall als „keine Gänge“. Ein neuer Gang oder eine Vorlage ersetzt sie.
- **Schema-Fallback kostet Kategorien:** Steht das Feld nicht in Production, verzichtet der Fallback auf alle drei
  Erweiterungsfelder. Der Pflicht-Deploy (AC-11) ist die Absicherung, nicht der Code.
- Nichts auf Hennings Geräten geprüft; kein Test gegen echtes CloudKit.

## Changelog

- 2026-11-02: Initial spec created (Issue #234, Durchgang 3)
