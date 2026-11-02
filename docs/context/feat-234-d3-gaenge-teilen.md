# Context: feat-234-d3-gaenge-teilen (Issue #234, Durchgang 3)

## Request Summary
Gänge („Stationen“) eines geteilten Ladens sollen bei allen Mitgliedern ankommen. Heute bleibt
`Store.stationConfigJSON` lokal (über die private iCloud-Spiegelung nur auf den eigenen Geräten); Mitglieder
sehen den Laden ohne Gänge. Punkt 7 des Issues: neues optionales Feld im `SharedStore`-Record wie
`categoriesJSON`, in `SharedStoreSchema.optionalExtensionFields`, Production-Schema der öffentlichen DB vor
TestFlight deployen.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/SharedStoreService.swift` | `mergeIntoRecord` (Push-Merge, schreibt `categoriesJSON`/`assignmentsJSON` nur bei `includeExtensionFields`), `pull` (liest Felder, Merge erst im Coordinator), `push`/`MergedState`-Tupel, `SharedStoreSchema.coreFields`/`optionalExtensionFields` (Z. 459ff.) |
| `SmartCart/Services/SyncCoordinator.swift` | `apply(…categories:assignments:…)` Z. 272ff.: mergt gegen lokalen Stand, schreibt nur bei Änderung; Aufrufer Z. 105 (Pull) und Z. 128 (Push-Ergebnis) |
| `SmartCart/Models/StoreCategories.swift` | `Station`, `StationConfig { stations, hidden, date }` (Z. 179–192; `date` ausdrücklich „für den Abgleich in D3“), `merge`/`mergeAssignments` als Muster (später gewinnt, mit Löschvermerk) |
| `SmartCart/Models/Store.swift` | `stationConfig` (get/set JSON), `activeStationConfig`/`hasStations`, Schreibstellen `applyStationConfig` (setzt `date = Date()`, legt Gang-Namen als eigene Kategorien an, `bumpRouteRevision`), `addStation` (setzt `date`), `updateStationConfig`, `renameStation`, `deleteStation`, **`removeStations()` setzt `stationConfigJSON = ""`** |
| `SmartCart/Models/StoreTemplates.swift` | `adoptCategory`/`adoptAllCategories` → `updateStationConfig` |
| `SmartCart/Views/Store/StationSetupView.swift` | alle UI-Schreibwege laufen über `updateStationConfig`/`applyStationConfig`/`removeStations` |
| `docs/cloudkit/private-schema-aktuell.ckdb` | enthält `RECORD TYPE SharedStore` (öffentliche DB) mit `categoriesJSON`/`assignmentsJSON`; neues Feld hier ergänzen, Development per `cloudkit-schema.yml` `import-development`, Production im Dashboard |
| `RestockTests/SharedStoreSchemaTests.swift` | Fake-Produktion (`allowedFields`), T6 prüft `optionalExtensionFields` wörtlich, T8 Drift-Test Feldliste ↔ Schemadatei |
| `RestockTests/SharedStoreMergeTests.swift` | `SyncCoordinator.apply` und `mergeIntoRecord` ohne CloudKit, eindeutige `shareID` je Test, UserDefaults-Aufräumprüfung |
| `RestockTests/StoreStationsTests.swift` | Gang-Logik-Tests (T/S/K/P/A-Reihen) |

## Existing Patterns
- **Ganzstand mit Zeitstempel**: Spec D1 legt fest „Sync als Ganzstand mit Zeitstempel (`StationConfig.date`, der spätere gewinnt)“ — kein Merge je Gang. Anders als Kategorien/Merkungen (je Schlüssel).
- **Push-Merge vs. Pull-Apply**: Push mergt in `mergeIntoRecord` gegen den Server-Record und schreibt zurück; Pull liefert Rohwerte, `SyncCoordinator.apply` mergt gegen den lokalen Stand zum Anwendungszeitpunkt und schreibt nur bei Änderung.
- **Schema-Fallback (#121)**: lehnt Production ein Feld ab, wird genau einmal ohne ALLE `optionalExtensionFields` gespeichert.
- **Kodierung**: JSON-String-Felder (`STRING QUERYABLE SEARCHABLE SORTABLE` im Schema).

## Dependencies
- Upstream: `StationConfig` (Codable), `Store.applyStationConfig` (legt eigene Kategorien an — die reisen bereits über `categoriesJSON`), CloudKit-Record `SharedStore`.
- Downstream: Sortierung/Anzeige (`stationRank`, `stationName`), Auswahl, „Kategorien einrichten“ — alle lesen nur `stationConfig`; Merkungen inkl. `otherStationMarker` reisen schon über `assignmentsJSON`.

## Existing Specs
- `docs/specs/models/store-stations.md` (D1, Abschnitt „Ausblick → D3“, Grenze Z. 314ff./439)
- `docs/specs/views/station-setup.md` (D2a), `station-templates-keywords.md` (D2b-1), `station-picker-adoption.md` (D2b-2)
- `docs/specs/services/shared-store-schema-fallback.md` (#121), `docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md`

## Risks & Considerations
1. **Löschen geht verloren**: `removeStations()` leert das Feld samt `date`. Ein leerer lokaler Stand kann im „später gewinnt“-Vergleich nicht gewinnen → beim nächsten Pull kämen die Gänge des Partners zurück. Braucht einen Löschvermerk (z. B. Konfiguration ohne Gänge mit Datum; `hasStations` verlangt ohnehin ≥ 1 Gang).
2. **Schema-Fallback alles-oder-nichts**: Steht das neue Feld noch nicht in Production, verwirft der Fallback auch `categoriesJSON`/`assignmentsJSON` → Kategorien-Abgleich fiele bis zum Deploy zurück. Abhilfe: Deploy vor Upload (Pflicht) oder gestaffelter Fallback (erst nur neues Feld weglassen) — Analysefrage.
3. **Alte App-Versionen** ignorieren das Feld (lesen es nicht, schreiben es aber auch nicht weg: CKRecord behält unbekannte Felder beim Merge auf demselben Record — zu prüfen, ob `mergeIntoRecord` auf dem Server-Record arbeitet: ja, `currentRecord` lädt ihn).
4. **Uhrzeit-Vergleich** zwischen Geräten (Gerätezeit, nicht Serverzeit) — wie bei Kategorien akzeptiert.
5. **Nebenwirkungen beim Übernehmen**: Remote-Konfiguration darf nicht per `applyStationConfig` gesetzt werden (das stempelt `date = Date()` neu → Ping-Pong). Eigene Kategorien der Gang-Namen kommen über `categoriesJSON`; trotzdem prüfen, ob `ensureCustomCategory` beim Empfänger nötig ist. `bumpRouteRevision` nach Übernahme nötig, damit die Liste neu sortiert.
6. **Seed-Laden `UITEST-NOSHARE`** (D2b-2) hat `shareID`; F006 (Subskription) offen — UI-Tests dürfen nichts an CloudKit schicken (`-skipCloudKitForScreenshots`).
7. **Schema-Schritt**: `.ckdb` ergänzen, Development importieren, Production deployen vor nächstem TestFlight (Henning: Schema-Schritt aus freigegebener Spec selbst erledigen, Memory `schema-schritt-nicht-erfragen`).
8. Echter CloudKit-Abgleich mit zweitem Konto nicht automatisierbar (bekannte Grenze #98 D4).

## Analysis

### Type
Feature (Durchgang 3 von #234: Gänge in geteilten Läden abgleichen)

### Recherche (2026-11-02)
- CloudKit speichert nur ausdrücklich gesetzte Felder; ältere App-Versionen, die den Server-Record laden und mergen, lassen ein ihnen unbekanntes Feld unangetastet (Christian Selig, „CKSyncEngine questions and answers“, https://christianselig.com/2026/01/cksyncengine/; Apple-Forum https://developer.apple.com/forums/thread/763641). Keine Apple-Doku sagt das wörtlich → Grenze in der Spec.
- Fehlt ein neues Feld im Production-Schema: „Cannot create or modify field … in production schema“; Production ist nur additiv, Deploy-Dialog zeigt teils fälschlich „0 Änderungen“ → nach dem Deploy per `cloudkit-schema.yml` (`export`) Dev ↔ Prod vergleichen (https://developer.apple.com/forums/thread/749729, https://developer.apple.com/forums/thread/748719).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Models/StoreCategories.swift | MODIFY | reine Funktion `mergeStationConfig(local:remote:)` (später `date` gewinnt, Gleichstand lokal, nil/kaputt = distantPast), Kodieren/Dekodieren |
| SmartCart/Models/Store.swift | MODIFY | `removeStations()` schreibt Löschvermerk `StationConfig(stations: [], hidden: [], date: now)` statt `""`; neue `adoptRemoteStationConfig(_:)` ohne neuen Stempel (`ensureCustomCategory` je Gang, `bumpRouteRevision` nur bei Änderung) |
| SmartCart/Services/SharedStoreService.swift | MODIFY | Feld `stationsJSON`: Merge in `mergeIntoRecord` (im `includeExtensionFields`-Block), Rückgabe in `MergedState`/`push`/`pull`, `optionalExtensionFields` += `stationsJSON` |
| SmartCart/Services/SyncCoordinator.swift | MODIFY | `apply(…, stations:)` + beide Aufrufer |
| SmartCart/Views/Store/StationSetupView.swift + de/en Localizable.strings | MODIFY | Hinweis `station.setup.shared` neu formulieren (PO-Frage) |
| docs/cloudkit/private-schema-aktuell.ckdb | MODIFY | `stationsJSON STRING` im Typ `SharedStore` (Drift-Test T8) |
| RestockTests/SharedStoreSchemaTests.swift, SharedStoreMergeTests.swift, StoreStationsTests.swift | MODIFY | Feldliste T6, Push-Merge, Apply, Löschvermerk, kein Ping-Pong, Gleichstand, kaputtes JSON, Beitritt |
| RestockUITests/StationSetupExtrasUITests.swift | MODIFY | Y7 (Hinweis im geteilten Laden) auf neuen Text |

### Scope Assessment
- Files: 4 Produktiv + Strings/Schema + 4 Testdateien
- Estimated LoC: Produktiv ~+100–120, Tests ~+220–300 (Unit), UI ~10 (Y7 anpassen)
- Risk Level: MEDIUM (zentraler Abgleichspfad, aber additives Feld nach bewährtem Muster #85/#94)

### Technical Approach (Empfehlung)
Ganzstand mit Zeitstempel wie in Spec D1 festgelegt: neues optionales Record-Feld `stationsJSON` (kodierte `StationConfig`). Push mergt lokal gegen Server-Record, Pull-Apply mergt gegen lokalen Stand, Übernahme setzt kein neues Datum (sonst Ping-Pong). „Gänge entfernen“ wird zum Löschvermerk (leere Konfiguration mit Datum, `hidden: []`, weil `StationSetupView.swift:230` sonst altes `hidden` übernähme); alle Leser gehen über `hasStations`/`activeStationConfig` (≥ 1 Gang), leere Konfiguration = „keine Gänge“. Schema-Fallback bleibt alles-oder-nichts (Feld in `optionalExtensionFields`); dafür Schema-Schritt Pflicht: `.ckdb` ergänzen → Development importieren → Production deployen → Export-Vergleich, vor dem nächsten TestFlight-Upload (selbst erledigen, Memory `schema-schritt-nicht-erfragen`).

### Alternativen (geprüft, nicht empfohlen)
- (a) Merge je Gang (wie Kategorien je Name): verliert bei gleichzeitigen Änderungen weniger, aber Reihenfolge/`hidden`/Umbenennen als Löschen+Anlegen ≈ 3–4× Umfang; kippt D1-Festlegung „Ganzstand“. Erst wenn Konflikte in der Praxis auftreten.
- (b) Nur der Besitzer schreibt Gänge: kein Merge, aber Mitglieder könnten nichts mehr einrichten, und `ownerDevice` ist nur ein Anzeigename, keine Identität → trägt nicht.
- (c) Gestaffelter Schema-Fallback (erst nur `stationsJSON` weglassen): schützt Kategorien bei vergessenem Deploy, kostet einen dritten Speicherversuch und mehr Zustände; durch Pflicht-Deploy + Export-Vergleich überflüssig.

### Risiken / Grenzen
- Gerätezeit statt Serverzeit (wie Kategorien); gleichzeitige Bearbeitung: ältere Änderung geht ganz verloren.
- Umbenennen beim Empfänger: Konfiguration, Merkungen (assignmentsJSON), Artikel-Kategorien (itemsJSON) reisen; gelernter Weg unter altem Gang-Namen nicht (Weg ist ohnehin je Gerät).
- Ältere App-Versionen sehen keine Gänge (lassen das Feld aber stehen, nur per Recherche belegt).
- Echter Zwei-Konten-Abgleich nicht automatisierbar (#98 D4); UI-Seed `UITEST-NOSHARE` schickt nichts (`-skipCloudKitForScreenshots`).

### Dependencies
`StationConfig` (Codable), `customCategoryEntries` (Gang-Namen reisen schon über `categoriesJSON`), `categoryAssignmentEntries`, CloudKit-Record `SharedStore` (öffentliche DB).

### Open Questions
- [x] PO 2026-11-02: Hinweis in „Kategorien einrichten“ bei geteilten Läden lautet neu „Änderungen an den Gängen gelten für alle Mitglieder dieses Ladens.“ (statt „Gänge bleiben bis zum Abgleich auf diesem Gerät.“); englisch sinngemäß „Changes to the aisles apply to all members of this store.“
