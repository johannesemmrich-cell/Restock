---
entity_id: station-picker-adoption
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: feat-234-d2b2-picker-uebernahme
tags: [feature, store, stations, category-picker, settings-ui, adoption]
---

# Laden-Stationen: Wischen in der Kategorie-Auswahl, frühere eigene Kategorien übernehmen, Durchgang 2b-2 (Issue #234)

## Approval

- [ ] Approved

Offenlegung für die Freigabe:

1. **Zuschnitt (PO-Beschluss 2026-11-01).** Durchgang 2b ist in 2b-1 (gemergt, PR #248) und 2b-2 (diese Spec) geteilt.
   2b-2 hat rund 525 Zeilen in der Zählweise des Prüfwerkzeugs (alle neuen Zeilen inkl. Tests und Seeds; davon etwa
   250 Tests, 35 Seeds) in 11 Positionen (12 Dateien, die zwei Strings-Dateien zählen als ein Paar, dazu die
   Spec). Das liegt über dem Korridor 250–350 und über der PO-Schätzung ~480; der PO hat 2b-2 als ein Stück
   beschlossen. Meldet der Implementierer mehr als 650, hält er an, bevor er weitermacht.
2. **Entwurf (PO 2026-11-01):** Die Empfehlungen 4 (Wischen in der Auswahl) und 5 (frühere eigene Kategorien
   übernehmen) aus `docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html` sind freigegeben. Eine
   zweite Vorschau gibt es nicht. Die Alternativen des Entwurfs (Eintrag „Gänge bearbeiten …“ statt Wischen;
   Frage „Eigene Kategorien anhängen?“ beim Wählen einer Vorlage) sind verworfen.
3. **Regel R3 ist eine technische Entscheidung des Tech Leads** (Abschnitt „Welche Kategorien als ‚von früher‘
   gelten“). Sie hat eine bekannte Grenze (Offene Grenzen) und kommt ohne neues Datenfeld aus.
4. **Keine Änderung an gesperrten Specs und keine Änderung an Bestandstests.** Die 2a- und 2b-1-Specs bleiben
   unverändert. Alle Tests aus D1, 2a und 2b-1 bleiben unverändert und müssen grün bleiben. Neu sind nur die hier
   benannten Tests.

## Purpose

Heute zeigt die Kategorie-Auswahl beim Artikel in Läden mit Gängen die Gänge nur zum Antippen. Wer dort einen
Namen ändern oder einen Gang loswerden will, muss die Artikelmaske verlassen und „Kategorien einrichten“ öffnen,
während Läden ohne Gänge dieselben Wischaktionen für eigene Kategorien schon haben. Wer vor den Gängen eigene
Kategorien angelegt hat (z. B. „Asia-Regal“, #85), sieht sie in einem Laden mit Gängen nirgends mehr. Und vier
Abläufe aus 2a sind bisher nur als Logik getestet, nicht über die Oberfläche.

Diese Spec liefert (a) Wischen „Bearbeiten“ und „Löschen“ auf den Gang-Zeilen der Auswahl, mit Nachziehen der
Auswahl des offenen Dialogs, (b) den Abschnitt „Eigene Kategorien von früher“ in „Kategorien einrichten“ mit
„Übernehmen“ je Zeile und „Alle übernehmen“, und (c) die vier nachgeholten UI-Tests aus 2a.

Datenmodell (`StationConfig`, `Station`), Auflösung Artikel → Gang und Sortierung stehen in
`docs/specs/models/store-stations.md` (D1), die Einrichtungsansicht in `docs/specs/views/station-setup.md` (2a),
Vorlagen und Stichwörter in `docs/specs/views/station-templates-keywords.md` (2b-1). Das wird hier nicht
wiederholt.

## Source

- **Neu:** `SmartCart/Views/Store/StationAdoptionSection.swift` (Abschnitt „von früher“)
- **Erweitert:** `SmartCart/Models/StoreCategories.swift` (reine Funktionen: Regel R3, Auswahl nachziehen),
  `SmartCart/Models/Store.swift` (Hülle: Nutzung ermitteln, übernehmen), `SmartCart/Views/Store/CategoryPickerView.swift`
  (Wischen, Rückfrage, Editor für Gänge), `SmartCart/Views/Store/StationSetupView.swift` (Abschnitt einhängen,
  Kennungen), `AddItemView.swift` und `EditItemView.swift` (Artikelname an die Auswahl), `SmartCart/SmartCartApp.swift`
  (zwei DEBUG-Seeds)
- **Identifier:** `StoreCategories.templateStationNames`, `StoreCategories.adoptableCategories(custom:config:used:templateNames:)`,
  `StoreCategories.renamedSelection(_:from:to:)`, `StoreCategories.selectionAfterDeleting(itemName:automaticCategory:config:)`,
  `Store.adoptableCategories`, `Store.adoptCategory(_:)`, `Store.adoptAllCategories()`, `StationAdoptionSection`,
  `CategoryPickerView.itemName`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| D1 (PR #240), 2a (PR #243), 2b-1 (PR #248) | feature | gemergt; `StationConfig`, `Store.renameStation`/`deleteStation`/`removeStations`/`updateStationConfig`, `StationSetupView.delete`/`deleteDialog`, `StoreTemplates.allTemplates` |
| `StoreCategories.compareKey`, `stationNamed`, `resolveStation`, `addingStation(_:emoji:to:)`, `station(forItemNamed:category:manuallySet:remembered:config:)`, `otherStationMarker` | module | Namensvergleich, Kollisionsprüfung (lehnt „Sonstiges“, Marke und vorhandene Gänge ab, übernimmt bei festem Namen die feste Kategorie), Auflösung eines Artikels zum Gang |
| `Store.customCategoryEntries`, `categoryEmoji(_:)`, `categoryAssignments`, `items` | model | eigene Kategorien samt Emoji, Merkungen, Nutzung durch Artikel (offen und erledigt) |
| `CategoryPickerView` (Läden ohne Gänge: Wischen Z. 152–164 mit `CustomCategoryEditor` und `confirmationDialog`) | view | Muster für die Wischaktionen; `CustomCategoryEditor` ruft für Gänge falsch `updateCustomCategory` und bekommt einen Gang-Modus |
| `AddItemView`/`EditItemView` (`pickerSelection`, `applyCategory`) | view | halten die Auswahl des offenen Dialogs und schreiben sie beim Sichern; müssen nach Umbenennen/Löschen die neue Auswahl sehen |
| `LocalizationKeyParityTests`, S13 | test | gleiche Schlüssel und Platzhalter de/en |
| `UITestLaunch`, `UITestWait` (`UITestItemEditor.open`), `-clearStationStoreForUITests` | test helper | wiederverwendet |
| `docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html` | doc | freigegebener Entwurf 4 und 5 (PO 2026-11-01) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | `templateStationNames`, `adoptableCategories`, `renamedSelection`, `selectionAfterDeleting` (~+45) |
| `SmartCart/Models/Store.swift` | MODIFY | `adoptableCategories`, `adoptCategory(_:)`, `adoptAllCategories()` (~+40) |
| `SmartCart/Views/Store/CategoryPickerView.swift` | MODIFY | Wischaktionen auf Gang-Zeilen, Editor im Gang-Modus, Rückfrage, Auswahl nachziehen (~+70) |
| `SmartCart/Views/Store/AddItemView.swift`, `EditItemView.swift` | MODIFY (klein) | Artikelname an `CategoryPickerView.itemName` (~+4 je Datei) |
| `SmartCart/Views/Store/StationAdoptionSection.swift` | CREATE | Abschnitt „Eigene Kategorien von früher“ (~+70) |
| `SmartCart/Views/Store/StationSetupView.swift` | MODIFY (klein) | Abschnitt nach `hiddenSection` einhängen, Kennungen für Emoji-Raster (~+12) |
| `SmartCart/SmartCartApp.swift` | MODIFY | Seeds `-seedLegacyCustomCategoriesForUITests`, `-seedStationStoreSharedForUITests` (~+35) |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | vier neue Schlüssel je Datei (~+5 je Datei) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | `StationAdoptionSection.swift` im App-Ziel eintragen (PBXBuildFile, PBXFileReference, Gruppe, Sources-Phase; ~+4) |
| `RestockTests/StoreStationsTests.swift` | MODIFY | Unit-Tests P1–P4, A1–A9 (~+130) |
| `RestockUITests/StationSetupExtrasUITests.swift` | MODIFY | UI-Tests Y1–Y9 (~+160) |

Nicht berührt: `.github/workflows/ci.yml` (die Klasse `StationSetupExtrasUITests` steht schon in `EXTRA_CLASSES`,
CI-Teil D), `docs/cloudkit/private-schema-aktuell.ckdb`, `SharedStoreService`/`SyncCoordinator`, `ShoppingRoute.swift`,
`StoreDetailView.swift`, die gesperrten Specs. `CLAUDE.md` wird mit dem Abschluss ergänzt (Absatz
„Laden-Stationen“; Doku, keine eigene Position).

### Estimated Changes

- Files: 11 Positionen (12 Dateien)
- LoC (Gate-Zählweise: alle Additionen inkl. Tests): ca. +525 (Produktiv ~+280, Tests ~+290 abzüglich Überlappung
  mit Seeds, Seeds ~+35). Eigene Schätzung 500–600. Meldet der Implementierer mehr als 650, hält er an.
- Funktionen ≤ 50 Zeilen; `StationSetupView.swift` (762 Zeilen) wächst nur um den Einhängepunkt.

### Nicht in diesem Durchgang

Abgleich der Gänge geteilter Läden (D3), Wischaktionen für Stichwörter (Umbenennen eines Stichworts), ein
Herkunftsfeld für eigene Kategorien (Alternative C), Wischen in der Auswahl für „Sonstiges“. Kein CloudKit-Schritt.

## Implementation Details

### (a) Kategorie-Auswahl in Läden mit Gängen

Gilt nur für `stationSections` in `CategoryPickerView`; Läden ohne Gänge verhalten sich unverändert.

- Jede **Gang-Zeile** bekommt `.swipeActions(edge: .trailing)` wie die eigenen Kategorien (Muster Z. 152–164):
  „Löschen“ (destruktiv, `action.delete`, Kennung `categoryPicker.station.delete.<Name>`) und „Bearbeiten“ (indigo,
  `action.edit`, Kennung `categoryPicker.station.edit.<Name>`). **„Sonstiges“ hat keine Wischaktionen.** Die
  bestehende Zeilenkennung `categoryPicker.row.<Name>` bleibt.
- **Bearbeiten** öffnet den vorhandenen `CustomCategoryEditor` (Titel „Kategorie bearbeiten“, Name, Emoji-Raster) im
  neuen **Gang-Modus**: Speichern ruft `store.renameStation(old, to: name, emoji: emoji)` statt
  `updateCustomCategory`. Liefert es `nil` (Name schon vergeben, „Sonstiges“, leer), bleibt der Editor offen und
  zeigt die bestehende Meldung `station.setup.name.rejected`; nichts ist geändert. Merkungen, von Hand gesetzte
  Artikelkategorien, gelernter Weg und laufende Sitzung ziehen mit (Bestand von `renameStation`).
- **Löschen** zeigt dieselbe Rückfrage wie die Übersicht: `StationSetupView.deleteDialog(for:in:)` liefert Titel,
  Meldung und Knopf („Gang „X“ löschen?“, beim letzten Gang „Gänge entfernen?“), die Wirkung ist
  `StationSetupView.delete(_:in:)` (letzter Gang → `removeStations()`, sonst `deleteStation`). Abbrechen
  (außerhalb tippen) ändert nichts. Es gibt keine zweite Löschlogik.
- **Auswahl des offenen Dialogs nachziehen.** `CategoryPickerView.selection` ist hier der Gang-Name bzw. die
  Sonstiges-Marke. Nach jeder Änderung gilt:
  - Umbenennen: `selection = StoreCategories.renamedSelection(selection, from: old, to: new)`, d. h. war der
    umbenannte Gang gewählt (Vergleich über `compareKey`), wird die Auswahl der neue Name, sonst bleibt sie. Ohne
    das schriebe `EditItemView.applyCategory` den alten Namen zurück in `item.category`.
  - Löschen des gewählten Gangs, **nicht der letzte:** `selection = StoreCategories.selectionAfterDeleting(itemName:automaticCategory:config:)`
    mit der Konfiguration **nach** dem Löschen: der Gang, in den der Artikel automatisch fiele
    (`station(forItemNamed: itemName, category: automaticCategory, manuallySet: false, remembered: nil, config:)`),
    sonst die Sonstiges-Marke `otherStationMarker`. **Nicht** die rohe `automaticCategory`: Der Add-Pfad
    (`AddItemView`) setzte sonst `categoryManuallySet = true`, weil die Auswahl vom Automatikwert abwiche.
  - Löschen des **letzten** Gangs (der Laden hat danach keine Gänge): `selection = automaticCategory`. Der
    Rückfall ist damit derselbe wie bei eigenen Kategorien in Läden ohne Gänge.
  - Löschen eines nicht gewählten Gangs: Auswahl unverändert.
- `CategoryPickerView` bekommt dafür den Parameter `itemName: String` (Standardwert leer); `AddItemView` und
  `EditItemView` übergeben `trimmedName` bzw. den Artikelnamen. (Gleichwertig wäre eine Closure; der Implementierer
  nimmt, was kleiner ist, solange `selectionAfterDeleting` die Auflösung macht.)

### Reine Funktionen (`StoreCategories`)

- `templateStationNames: Set<String>`: die `compareKey`s aller Gang-Namen aus `StoreCategories.allTemplates`
  (Lidl, Discounter, Vollsortimenter, Drogerie, Baumarkt).
- `adoptableCategories(custom:config:used:templateNames:) -> [String]`: Regel R3 (nächster Abschnitt). `custom` ist
  die Liste der eigenen Kategorien in Anzeigereihenfolge (Reihenfolge bleibt), `used` die `compareKey`s der
  genutzten Namen, `templateNames` meist `templateStationNames`. Rein, ohne Zugriff auf `Store`.
- `renamedSelection(_ selection: String, from old: String, to new: String) -> String` und
  `selectionAfterDeleting(itemName:automaticCategory:config:) -> String`: wie im vorigen Abschnitt.

### Welche Kategorien als „von früher“ gelten (Regel R3)

Ob eine eigene Kategorie aus den Gängen entstanden ist (`applyStationConfig` legt jeden Gang-Namen als eigene
Kategorie an; „Vorlage ersetzen“ und „Gänge entfernen“ löschen sie nicht) oder vom Nutzer angelegt wurde, ist ohne
neues Feld nicht unterscheidbar. Deshalb gilt für eine eigene Kategorie `c`:

```
gezeigt(c)  =  c ist kein aktueller Gang
           UND  addingStation würde c annehmen (nicht „Sonstiges“, nicht die Marke, nicht leer)
           UND  ( compareKey(c) ∉ templateStationNames          // Name steht in keiner Vorlage
                  ODER compareKey(c) ∈ genutzt )                // oder sie trägt Artikel/Merkungen
```

`genutzt` sind die `compareKey`s der `category` aller Artikel des Ladens (offen und erledigt) und aller Werte in
`categoryAssignments`. Folge: „Asia-Regal“ (kein Vorlagenname) erscheint auch ohne Artikel; nach dem Wechsel Lidl →
Discounter bleiben die ungenutzten Lidl-Gang-Namen unsichtbar, genutzte erscheinen; nach „Gänge entfernen“ und neuer
Einrichtung gibt es keine Altlast aus alten Gang-Namen. Hat der Laden keine Gänge, ist die Liste leer (dort
funktionieren eigene Kategorien normal).

### (b) Abschnitt „Eigene Kategorien von früher“ (`StationAdoptionSection`)

- Eigene View-Struktur in `StationAdoptionSection.swift`, eingehängt in `StationSetupView` nach `hiddenSection`;
  **nur sichtbar, wenn `store.adoptableCategories` nicht leer ist.** Kopf „Eigene Kategorien von früher · N“
  (`station.adopt.section`, Kennung `stationSetup.adopt.section`), daneben „Alle übernehmen“
  (`station.adopt.all`, Kennung `stationSetup.adopt.all`).
- Eine Zeile je Kategorie (Emoji, Name; Kennung `stationSetup.adopt.row.<Name>`) mit „Übernehmen“
  (`station.adopt.take`, Kennung `stationSetup.adopt.take.<Name>`). Fußzeile (`station.adopt.footer`): „Übernehmen
  legt einen Gang am Ende an. Artikel, die du der Kategorie zugeordnet hattest, stehen dann darin.“
- `Store.adoptCategory(_ name: String) -> String?`: baut mit
  `StoreCategories.addingStation(name, emoji: categoryEmoji(name), to: config)` die neue Konfiguration (eigenes Emoji
  bleibt; **nicht** `addStation`, das ein Vorschlags-Emoji setzt), schreibt über `updateStationConfig` und liefert
  den Gang-Namen; `nil`, wenn der Name nicht (mehr) annehmbar ist (schon Gang, „Sonstiges“, Marke, leer), dann
  ändert sich nichts. Trägt der Name eine feste Kategorie, übernimmt der Gang sie (Bestand von `addingStation`);
  eine eigene Kategorie kann das nicht sein.
- `Store.adoptAllCategories() -> [String]`: übernimmt alle Einträge von `adoptableCategories` in dieser
  Reihenfolge am Ende, **mit genau einem** `updateStationConfig`; nicht annehmbare Namen werden übersprungen. Liefert
  die angelegten Namen.
- **Keine Datenwanderung.** Eine Merkung (`categoryAssignments`) oder eine von Hand gesetzte Artikelkategorie mit
  dem Namen trifft den neuen Gang über `stationNamed` (Vergleich `compareKey`) sofort. Dasselbe gilt für Artikel,
  die schon erledigt sind. Die eigene Kategorie bleibt bestehen (neben dem Gang), wie bei jedem Gang (`applyStationConfig`).
- Nach dem Übernehmen verschwindet die Zeile aus dem Abschnitt (kein aktueller Gang mehr = Bedingung 1); sind alle
  übernommen, verschwindet der ganze Abschnitt.

### (c) Nachgeholte UI-Tests aus 2a und Seeds

Die vier Tests (Y4 Löschen per Wischen in der Übersicht, Y5 „gehört zu Gang …“, Y6 Emoji-Auswahl, Y7 Hinweis in
geteilten Läden) laufen über sichtbare Elemente. Für Y6 bekommen die Raster-Knöpfe in `StationEmojiGrid` die Kennung
`stationSetup.emoji.<Emoji>`; für Y5 und Y4 reichen die vorhandenen Kennungen
(`stationSetup.detail.category.<Name>`, `stationSetup.row.delete.<Name>`, `stationSetup.sharedHint`).

DEBUG-Seeds (nur `#if DEBUG`, Aufräumen über das vorhandene `-clearStationStoreForUITests`, das alle Läden und
Artikel löscht; beide Seeds löschen vorher alle Läden und Artikel wie `-seedStationStoreForUITests`):

- `-seedLegacyCustomCategoriesForUITests`: Laden „Altladen“ mit **zwei** Gängen (Obst & Gemüse 🥦 mit
  `builtIns` „Obst & Gemüse“; Getränke 🥤 mit `builtIns` „Getränke“), eigenen Kategorien „Asia-Regal“ 🍜 (Artikel
  „Nudeln“ von Hand dort zugeordnet), „Wein“ 🍷 (ungenutzt, kein Vorlagenname), „Backstation“ 🥖 (Vorlagenname
  des Discounters, aber Artikel „Baguette“ von Hand dort zugeordnet = genutzt) und „Aktionsware“ 🛒 (Vorlagenname,
  ungenutzt), dazu Artikel „Apfel“ (automatisch). Erwartete Liste nach R3: Asia-Regal, Wein, Backstation, nicht
  Aktionsware. Modus Kategorie.
- `-seedStationStoreSharedForUITests`: wie `-seedStationStoreForUITests` (Laden „Stationsladen“, Lidl-Vorlage,
  sechs Artikel), zusätzlich `shareID = "UITEST-NOSHARE"` (unwahrscheinliche Kennung, nicht „444-RU8“ aus dem
  Screenshot-Seed). Begründung und Grenze: `StoreDetailView` stößt bei gesetzter `shareID` einen Abgleich an; ohne
  passenden Datensatz in CloudKit entsteht höchstens ein Fehler-Banner, geschrieben wird nichts. Der Test öffnet
  nur „Kategorien einrichten“ und löst keinen Push aus. Das ist aus dem Code begründet, nicht gemessen.

### Lokalisierung (de + en, `LocalizationKeyParityTests`)

Neue Schlüssel (de / en; Platzhalter je Schlüssel gleich): `station.adopt.section` („Eigene Kategorien von früher ·
%d“ / „Earlier custom categories · %d“, ein Platzhalter), `station.adopt.take` („Übernehmen“ / „Adopt“),
`station.adopt.all` („Alle übernehmen“ / „Adopt all“), `station.adopt.footer` („Übernehmen legt einen Gang am Ende
an. Artikel, die du der Kategorie zugeordnet hattest, stehen dann darin.“ / „Adopting adds an aisle at the end.
Items you had put in that category are then in it.“). Wiederverwendet: `action.edit`, `action.delete`,
`category.editor.title`, `station.setup.name.rejected`, `station.setup.delete.title`/`.message`,
`station.remove.confirm.*`, `station.setup.shared`, `station.setup.detail.bound`. Gang-Namen bleiben deutsch auch
in der englischen Oberfläche (bekannte Grenze seit D1).

### Kein neues Feld, kein Schema-Schritt

Alles liegt in `stationConfigJSON` (D1), `customCategoryEntries` und `categoryAssignments` (#85/#94). Keine Änderung
an `@Model`, `@AppStorage`-Schlüsseln oder `docs/cloudkit/private-schema-aktuell.ckdb`;
`MirroredSchemaSnapshotTests` bleiben unverändert. Kein CloudKit-Deploy. Seeds und Kennungen sind im Release-Build
nicht kompiliert (Nachweis per `strings` am Release-Binary wie bei den anderen DEBUG-Argumenten, Ablage in
`docs/artifacts/feat-234-d2b2-picker-uebernahme/release-strings-check.txt`).

## Test Plan

Alle Tests werden vor der Umsetzung geschrieben (TDD RED: die Unit-Tests übersetzen nicht, solange die API fehlt;
die UI-Tests scheitern, solange Wischaktionen, Abschnitt und Seeds fehlen). In-Memory-Container immer mit
`cloudKitDatabase: .none`; jeder angelegte Laden räumt seine App-Gruppen-Schlüssel in `tearDown` (`removeRouteData`).

### Automated Tests (TDD RED)

Unit, `RestockTests/StoreStationsTests.swift` (neue Abschnitte „D2b-2 Auswahl“ mit Präfix P und „D2b-2 Übernahme“
mit Präfix A):

- [ ] P1 `testRenamedSelectionFollowsRename`: GIVEN Auswahl „Käse“ WHEN `renamedSelection("Käse", from: "Käse", to: "Käsetheke")` THEN „Käsetheke“; GIVEN Auswahl „käse“ (andere Schreibweise) THEN ebenso; GIVEN Auswahl „Milch“ oder die Sonstiges-Marke THEN unverändert (AC-3)
- [ ] P2 `testSelectionAfterDeleteFallsBackToAutomaticStation`: GIVEN Lidl-Vorlage, Konfiguration nach `deletingStation("Käse")` WHEN `selectionAfterDeleting(itemName: "Gouda", automaticCategory: "Milchprodukte", config:)` THEN das Ergebnis ist der Gang, den `station(forItemNamed: "Gouda", …)` in der neuen Konfiguration liefert, sonst die Sonstiges-Marke; nie „Käse“ und nie der rohe Kategoriename „Milchprodukte“ (außer ein Gang heißt so); GIVEN Artikel „Batterien“ ohne Treffer THEN die Sonstiges-Marke (AC-4)
- [ ] P3 `testSelectionAfterDeletingLastStationIsAutomaticCategory`: GIVEN Konfiguration mit einem Gang WHEN `Store.deleteStation`/`removeStations` über `StationSetupView.delete(_:in:)` THEN `hasStations` ist falsch und die Auswahl entspricht `automaticCategory`; GIVEN `StationSetupView.deleteDialog` beim letzten Gang THEN Titel/Knopf von „Gänge entfernen“ (AC-5)
- [ ] P4 `testPickerRenameRejectedKeepsEverything`: GIVEN Lidl-Laden mit Merkung auf „Käse“ WHEN `renameStation("Käse", to: "Drogerie", emoji: "🧀")` (vergeben) und `to: "Sonstiges"` THEN je `nil`, `stationConfig` byte-gleich vorher, Merkung unverändert; WHEN gültiger Name THEN Merkung und von Hand gesetzter Artikel ziehen mit (AC-2)
- [ ] A1 `testAdoptableCategoriesRuleR3`: GIVEN Gänge Obst & Gemüse und Getränke, eigene Kategorien Asia-Regal, Wein, Backstation, Aktionsware, Getränke-Gang-Name, `used` = {backstation} WHEN `adoptableCategories(…, templateNames: templateStationNames)` THEN [Asia-Regal, Wein, Backstation] in dieser Reihenfolge; Aktionsware fehlt (Vorlagenname, ungenutzt); der aktuelle Gang fehlt (AC-6)
- [ ] A2 `testAdoptableCategoriesCompareKeyAndReserved`: GIVEN „asia-regal“ und „ASIA-REGAL“ als Gang vorhanden WHEN geprüft THEN die Kategorie „Asia-Regal“ fehlt (Gang gleichen Namens über `compareKey`); GIVEN „backstation“ klein und `used` = {compareKey("Backstation")} THEN gezeigt; GIVEN eigene Kategorie „Sonstiges“ oder leer THEN nie gezeigt (AC-6)
- [ ] A3 `testTemplateStationNamesCoverAllTemplates`: GIVEN `templateStationNames` THEN enthält die `compareKey`s aller Gang-Namen aller fünf Vorlagen (z. B. „backstation“, „kühltheke fertiges“, „werkzeug & maschinen“), sonst nichts; Größe = Zahl verschiedener `compareKey`s über alle Gänge (AC-6)
- [ ] A4 `testStoreAdoptableCategoriesReadsUsage`: GIVEN `Store` (In-Memory) mit Gängen, eigener Kategorie „Backstation“ nur über einen **erledigten** Artikel genutzt, „Vorrat“ nur über `categoryAssignments`, „Aktionsware“ ungenutzt, „Asia-Regal“ ungenutzt WHEN `store.adoptableCategories` THEN [Asia-Regal, Backstation, Vorrat] (Reihenfolge der eigenen Kategorien), Aktionsware fehlt; GIVEN Laden ohne Gänge THEN leer (AC-6)
- [ ] A5 `testAdoptCategoryAppendsKeepsEmojiAndMovesItems`: GIVEN Altladen-Stand (Seed-Äquivalent) WHEN `adoptCategory("Asia-Regal")` THEN Rückgabe „Asia-Regal“, der Gang steht als letzter, sein Emoji ist 🍜 (nicht das Vorschlags-Emoji), `station(forItemNamed: "Nudeln", category: "Asia-Regal", manuallySet: true, …)` ergibt „Asia-Regal“ ohne dass ein Artikel geändert wurde, die eigene Kategorie existiert weiter, `adoptableCategories` enthält sie nicht mehr; Zeitstempel `date` ist jetzt (AC-7)
- [ ] A6 `testAdoptAllWritesOnce`: GIVEN Altladen-Stand WHEN `adoptAllCategories()` THEN Rückgabe [Asia-Regal, Wein, Backstation], diese Gänge stehen in dieser Reihenfolge am Ende, die Weg-Version ist um genau 1 erhöht (Messweise wie K7), `adoptableCategories` ist leer; WHEN erneut THEN leere Rückgabe, `date` und Weg-Version unverändert (AC-8)
- [ ] A7 `testAdoptWithoutStationsAndCollisions`: GIVEN Laden ohne Gänge WHEN `adoptCategory("Wein")` THEN `nil`, nichts geändert; GIVEN Laden mit Gang „Wein“ WHEN `adoptCategory("Wein")` THEN `nil`; WHEN `adoptCategory("Sonstiges")` THEN `nil` (AC-7)
- [ ] A8 `testDeletingAdoptedStationRemovesCustomCategory`: GIVEN übernommener Gang „Wein“ WHEN `deleteStation("Wein")` THEN der Gang fehlt und die eigene Kategorie „Wein“ ist mit gelöscht (Bestandsverhalten, bewusst festgehalten); `adoptableCategories` zeigt „Wein“ nicht mehr (AC-7, Offene Grenzen)
- [ ] A9 `testPickerAdoptionStringsExistInBothLanguages`: GIVEN die vier neuen Schlüssel WHEN in `de.lproj` und `en.lproj` gelesen THEN alle vorhanden, nicht leer, Platzhalterzahl gleich (`station.adopt.section` 1, übrige 0); `LocalizationKeyParityTests` bleibt grün (AC-13)

UI, `RestockUITests/StationSetupExtrasUITests.swift` (Start über `UITestLaunch.start` mit `-hasCompletedOnboarding YES`
und dem Seed des Tests, `tearDown` räumt mit `-clearStationStoreForUITests`; nie `-developerMode`). Geprüft wird
der Nutzen in der Ladenliste (Modus „Kategorie“), nicht nur das Vorhandensein der Bedienelemente. Der Dialog des
Artikels wird über `UITestItemEditor.open(_:in:)` geöffnet.

- [ ] Y1 `testPickerRenameStationKeepsSelection` (AC-1, AC-2, AC-3; Seed `-seedStationStoreForUITests`): GIVEN Dialog von „Gouda“ WHEN Kategorie öffnen, „Käse“ ausdrücklich antippen, Auswahl wieder öffnen, auf „Käse“ nach links wischen → „Bearbeiten“, Namen „Käse & Co“ eingeben, speichern THEN die Zeile heißt „Käse & Co“; WHEN Name „Drogerie“ (vergeben) THEN die Meldung „Diesen Namen gibt es schon oder er ist nicht erlaubt.“ erscheint und der Name ist unverändert; WHEN zurück und Artikel sichern THEN steht „Gouda“ in der Liste im Abschnitt „Käse & Co“ (nicht in „Sonstiges“, was ohne Nachziehen der Auswahl geschähe); auf „Sonstiges“ gibt es keine Wischaktionen
- [ ] Y2 `testPickerDeleteStationAsksAndFallsBack` (AC-1, AC-4; Seed `-seedStationStoreForUITests`): GIVEN Dialog von „Gouda“ (Auswahl „Käse“) WHEN auf „Käse“ wischen → „Löschen“ THEN die Rückfrage „Gang „Käse“ löschen?“ erscheint; WHEN außerhalb tippen THEN der Gang bleibt; WHEN erneut und „Gang löschen“ THEN die Zeile verschwindet, die Auswahl zeigt den Gang bzw. „Sonstiges“, in den „Gouda“ jetzt fällt (gelesen aus `item.categoryRow`); nach Sichern steht „Gouda“ nicht mehr im Abschnitt „Käse“ und ist noch in der Liste
- [ ] Y3 `testPickerDeleteLastStationAsksRemoveStations` (AC-5; Seed `-seedLegacyCustomCategoriesForUITests`, zwei Gänge): GIVEN Dialog von „Apfel“ WHEN einen Gang löschen THEN normale Rückfrage; WHEN den letzten per Wischen löschen THEN die Rückfrage „Gänge entfernen?“ erscheint; nach Bestätigen zeigt die Auswahl keine Gänge mehr, sondern die Kategorien eines Ladens ohne Gänge (Abschnitt „Alle Kategorien“ bzw. eigene Kategorien, z. B. Zeile „Asia-Regal“), und die Ladenliste hat keine Gang-Abschnitte mehr
- [ ] Y4 `testSwipeDeleteStationInOverview` (AC-9, AC-12 Gegenprobe; Seed `-seedStationStoreForUITests`): GIVEN „Kategorien einrichten“ WHEN auf der Zeile „Drogerie“ nach links wischen und `stationSetup.row.delete.Drogerie` tippen, Rückfrage bestätigen THEN die Zeile fehlt, „Gänge · 11“; Abbrechen der Rückfrage bei einem zweiten Gang lässt ihn stehen; nach Fertig steht „Batterien“ nicht mehr unter „Drogerie“ (Abschnitt weg); zugleich fehlen `stationSetup.sharedHint` und `stationSetup.adopt.section` (ungeteilter Laden ohne frühere Kategorien)
- [ ] Y5 `testBoundCategorySubtitleShowsOwningStation` (AC-10; Seed `-seedStationStoreForUITests`): GIVEN Gang „Käse“ geöffnet WHEN die Kategorie-Zeile `stationSetup.detail.category.Getränke` gelesen wird THEN trägt sie den Untertitel „gehört zu Gang Getränke“ (Name-gebundene Kategorie des Gangs „Getränke“); die Zeile `…category.Milchprodukte` trägt ihn nicht
- [ ] Y6 `testPickGangEmojiFromGrid` (AC-11; Seed `-seedStationStoreForUITests`): GIVEN Gang „Käse“ geöffnet WHEN „Emoji“ aufgeklappt und `stationSetup.emoji.🥛` getippt THEN steht 🥛 rechts neben „Emoji“; nach Zurück und Fertig trägt der Abschnittskopf „Käse“ in der Ladenliste 🥛 statt 🧀
- [ ] Y7 `testSharedStoreShowsHint` (AC-12; Seed `-seedStationStoreSharedForUITests`): GIVEN geteilter Laden WHEN „Kategorien einrichten“ THEN `stationSetup.sharedHint` mit „Gänge bleiben bis zum Abgleich auf diesem Gerät.“ ist sichtbar; die Gang-Zeilen sind bedienbar (Gang öffnen und zurück)
- [ ] Y8 `testAdoptOneLegacyCategory` (AC-6, AC-7; Seed `-seedLegacyCustomCategoriesForUITests`): GIVEN „Kategorien einrichten“ THEN der Abschnitt „Eigene Kategorien von früher · 3“ zeigt Asia-Regal, Wein, Backstation und nicht „Aktionsware“; WHEN bei „Asia-Regal“ „Übernehmen“ THEN die Zeile verlässt den Abschnitt (Kopf „· 2“), „Gänge · 3“ mit „Asia-Regal“ 🍜 als letzter Zeile; nach Fertig steht „Nudeln“ in der Ladenliste im Abschnitt „Asia-Regal“, vorher unter „Sonstiges“
- [ ] Y9 `testAdoptAllLegacyCategories` (AC-6, AC-8; Seed `-seedLegacyCustomCategoriesForUITests`): GIVEN der Abschnitt mit 3 Zeilen WHEN „Alle übernehmen“ THEN der ganze Abschnitt verschwindet (`stationSetup.adopt.section` fehlt), „Gänge · 5“ mit Asia-Regal, Wein, Backstation in dieser Reihenfolge nach „Getränke“; nach Fertig stehen „Nudeln“ unter „Asia-Regal“ und „Baguette“ unter „Backstation“

Bestehende Tests (D1, 2a, 2b-1) laufen unverändert und müssen grün bleiben. `StationSetupExtrasUITests` bleibt
in CI-Teil D (`EXTRA_CLASSES`); sie wächst von 3 auf 12 Tests. Teil D lief mit 3 Tests rund 24 min und hat 60 min
Limit; sprengt die Klasse es im ersten CI-Lauf, schneidet der Implementierer Y3/Y4 in eine eigene Klasse und trägt
sie in `EXTRA_CLASSES` ein (eine Zeile in `ci.yml`, dann mit eigener kleiner Meldung an den PO).

| AC | Geprüft durch |
|----|---------------|
| AC-1 | Y1, Y2 |
| AC-2 | P4, Y1 |
| AC-3 | P1, Y1 |
| AC-4 | P2, Y2 |
| AC-5 | P3, Y3 |
| AC-6 | A1, A2, A3, A4, Y8, Y9 |
| AC-7 | A5, A7, A8, Y8 |
| AC-8 | A6, Y9 |
| AC-9 | Y4 |
| AC-10 | Y5 |
| AC-11 | Y6 |
| AC-12 | Y7, Y4 (Gegenprobe) |
| AC-13 | A9 |
| AC-14 | A7 (Laden ohne Gänge), Gesamtlauf der Bestandstests, Release-Strings-Nachweis |

### Durchlauf (Pflicht)

Im Simulator, auf dem Stand dieser Änderung, als Nutzer, Belegbilder als `XCTAttachment` im Testlauf (Muster
2a; Ablage unter `docs/artifacts/feat-234-d2b2-picker-uebernahme/`): (1) Laden mit Lidl-Gängen, Artikel öffnen,
Kategorie → auf einen Gang wischen (Bearbeiten, Löschen sichtbar), umbenennen, Auswahl bleibt, Artikel sichern;
(2) Gang löschen mit Rückfrage und die Rückfrage beim letzten Gang; (3) Altladen-Seed → „Kategorien einrichten“
→ Abschnitt „von früher“ mit drei Zeilen, eine übernehmen, die übrigen mit „Alle übernehmen“, in der Ladenliste
beide Sortiermodi ansehen; (4) geteilter Laden mit Hinweis. Nichts auf Hennings Geräten ohne sein ausdrückliches Wort.

## Acceptance Criteria

- **AC-1:** GIVEN die Kategorie-Auswahl eines Artikels in einem Laden mit Gängen WHEN der Nutzer eine Gang-Zeile nach links wischt THEN erscheinen „Bearbeiten“ und „Löschen“; die Zeile „Sonstiges“ zeigt keine Wischaktionen; Läden ohne Gänge verhalten sich unverändert. (Y1, Y2)
- **AC-2:** GIVEN „Bearbeiten“ auf einem Gang WHEN Name und Emoji gespeichert werden THEN läuft es über `renameStation` (Merkungen, von Hand gesetzte Artikelkategorien, gelernter Weg und Sitzung ziehen mit); WHEN der Name abgelehnt wird (schon vergeben, „Sonstiges“, leer) THEN bleibt der Editor offen mit der Meldung „Diesen Namen gibt es schon oder er ist nicht erlaubt.“ und nichts ist geändert. (P4, Y1)
- **AC-3:** GIVEN der umbenannte Gang ist in der Auswahl des offenen Dialogs gewählt WHEN er umbenannt wird THEN ist die Auswahl der neue Name, und das Sichern des Artikels legt ihn in diesen Gang (nicht zurück unter den alten Namen); eine andere Auswahl bleibt unverändert. (P1, Y1)
- **AC-4:** GIVEN „Löschen“ auf einem Gang WHEN der Nutzer es wählt THEN fragt die App vorher („Gang „X“ löschen?“, Abbrechen ändert nichts); WHEN bestätigt und der Gang war gewählt (und nicht der letzte) THEN ist die Auswahl der Gang, in den der Artikel automatisch fiele, sonst „Sonstiges“ (Marke, nie die rohe Kategorie), und der Artikel wird nicht fälschlich als von Hand kategorisiert gespeichert. (P2, Y2)
- **AC-5:** GIVEN der letzte Gang eines Ladens WHEN er in der Auswahl gelöscht wird THEN lautet die Rückfrage „Gänge entfernen?“ (dieselbe Logik wie `StationSetupView.delete`/`deleteDialog`), danach hat der Laden keine Gänge, und war er gewählt, ist die Auswahl die automatische Kategorie. (P3, Y3)
- **AC-6:** GIVEN „Kategorien einrichten“ eines Ladens mit Gängen WHEN es eigene Kategorien gibt, die kein aktueller Gang sind und (deren Name in keiner Vorlage steht ODER die von Artikeln oder Merkungen genutzt werden) THEN zeigt ein Abschnitt „Eigene Kategorien von früher · N“ genau diese (Vergleich über `compareKey`, „Sonstiges“ und leere Namen nie); gibt es keine, ist der Abschnitt nicht da; in Läden ohne Gänge gibt es ihn nie. (A1, A2, A3, A4, Y8, Y9)
- **AC-7:** GIVEN eine Zeile im Abschnitt WHEN „Übernehmen“ THEN entsteht ein neuer Gang am Ende mit dem Namen und dem eigenen Emoji der Kategorie, die Zeile verlässt den Abschnitt, und Artikel, die der Kategorie von Hand zugeordnet oder gemerkt waren (offen und erledigt), stehen sofort in diesem Gang, ohne dass Daten verschoben werden; ist der Name nicht annehmbar (schon Gang, „Sonstiges“, Laden ohne Gänge), ändert sich nichts. (A5, A7, A8, Y8)
- **AC-8:** GIVEN der Abschnitt WHEN „Alle übernehmen“ THEN werden alle gezeigten Kategorien in Listenreihenfolge am Ende angelegt, mit genau einem Schreibvorgang (ein `updateStationConfig`), der Abschnitt verschwindet; ein zweiter Aufruf ändert nichts. (A6, Y9)
- **AC-9:** GIVEN die Übersicht von „Kategorien einrichten“ WHEN ein Gang per Wischen gelöscht und bestätigt wird THEN verschwindet die Zeile und seine Artikel fallen in den Gang, der automatisch gälte, sonst „Sonstiges“; Abbrechen der Rückfrage lässt den Gang stehen. (Y4)
- **AC-10:** GIVEN das Gang-Detail WHEN eine Kategorie zu einem anderen Gang gleichen Namens gehört THEN zeigt ihre Zeile den Untertitel „gehört zu Gang <Name>“; eine nicht gebundene Kategorie zeigt ihn nicht. (Y5)
- **AC-11:** GIVEN das Gang-Detail WHEN ein Emoji im aufgeklappten Raster getippt wird THEN steht es sofort am Gang und im Abschnittskopf der Ladenliste. (Y6)
- **AC-12:** GIVEN ein Laden mit `shareID` WHEN „Kategorien einrichten“ geöffnet wird THEN steht der Hinweis „Gänge bleiben bis zum Abgleich auf diesem Gerät.“ da; in einem Laden ohne `shareID` fehlt er. (Y7, Y4)
- **AC-13:** GIVEN die vier neuen Texte WHEN die Tabellen geladen werden THEN haben sie deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern. (A9, `LocalizationKeyParityTests`)
- **AC-14:** GIVEN die Änderung insgesamt THEN gibt es kein neues `@Model`-Feld, keinen neuen `@AppStorage`-Schlüssel, keine Schemaänderung und keine `ci.yml`-Änderung; Läden ohne Gänge verhalten sich unverändert; die Seeds und Kennungen sind im Release-Build nicht kompiliert; alle Bestandstests bleiben grün. (A7, Gesamtlauf, Release-Strings-Nachweis)

## Known Limitations

- **Ungenutzte eigene Kategorie mit Vorlagen-Namen erscheint nicht (Regel R3).** Hat der Nutzer früher eine Kategorie
  „Backstation“ oder „Tiefkühl“ angelegt und nie benutzt, hält die App sie für Gang-Altlast und zeigt sie nicht. Sie
  trägt nichts; sobald ein Artikel oder eine Merkung sie nutzt, erscheint sie.
- **Löschen eines übernommenen Gangs löscht die eigene Kategorie mit** (Bestandsverhalten von `deleteStation`,
  A8). Wer sie nur als Gang loswerden will, verliert auch die Kategorie; sie taucht in „von früher“ nicht wieder auf.
- **Herkunft nicht gespeichert:** Eine Kategorie, die aus einem Gang einer früheren Vorlage entstand und
  danach durch einen Artikel genutzt wird, erscheint als „von früher“, obwohl der Nutzer sie nie selbst angelegt hat
  (R3 kann beides nicht trennen, nur ein neues Feld könnte es, Alternative C).
- **Geteilte Läden:** `categoriesJSON` trägt eigene Kategorien, nicht die Gänge. Die Liste „von früher“ kann deshalb
  je Gerät abweichen, bis die Gänge synchronisiert werden (D3).
- **Seed mit `shareID`** (`UITEST-NOSHARE`): Der Satz „kein Schreiben“ aus Abschnitt (c) stimmte nicht (Adversary
  F001): `StoreDetailView.onDisappear` hätte auf einem Simulator mit iCloud-Konto einen Record in die öffentliche
  Datenbank gepusht. Behoben, indem Y7 mit `-skipCloudKitForScreenshots` startet und der Push in `onDisappear` dieses
  DEBUG-Argument wie der Pull beachtet. Offen (F006, LOW): `SyncCoordinator.resubscribeAll` legt beim Start auch für
  den Seed eine Abfrage-Subskription an, `pushWidgetCheckoffsIfNeeded` kennt das Argument nicht; ohne iCloud-Konto
  (Restock-Validate, CI) scheitern beide nur. Nicht gemessen, nur aus dem Code begründet.
- **Emoji der übernommenen Kategorie** kann außerhalb von `emojiChoices` liegen (frei gewählt in #85); das Raster zeigt
  dann keinen markierten Eintrag, der Gang trägt das Emoji trotzdem.
- **Auswahl nach Löschen** beruht auf der Auflösung ohne Merkung und ohne Handwahl; trägt der Artikel im Add-Dialog
  schon eine eigene Merkung, wirkt sie erst nach dem Sichern.
- Kein Umbenennen/Löschen in der Auswahl für „Sonstiges“; keine Rückgängig-Funktion für Löschen.
- Die Wischaktionen und der Abschnitt sind nur im Simulator mit Standardschrift geprüft, nicht in AccessibilityXXXL.
- CI-Teil D ist mit 12 Tests nicht im echten Lauf gemessen; erst der CI-Lauf des PR zeigt die Laufzeit.
- Nichts auf Hennings Geräten geprüft; kein CloudKit-Test.

## Alternativen (verworfen oder offen)

| Punkt | Gewählt | Alternative | Folge der Alternative |
|-------|---------|-------------|-----------------------|
| Welche Kategorien „von früher“ (A) | **R3**: Name in keiner Vorlage oder genutzt | **R1** alle eigenen Kategorien, die kein Gang sind, mit Wischen-Löschen in der Liste | einfacher, aber nach jedem Vorlagenwechsel eine lange Altlastenliste; widerspricht „nur wenn es welche gibt“ (kippt nichts, nur den Filter) |
| Zuschnitt (B) | ein Durchgang 2b-2 (a+b+c) | Übernahme (b) in eigenen Durchgang 2b-3, jetzt nur (a)+(c) | spart die Regelfrage und ~170 Zeilen, kippt den PO-Zuschnitt vom 2026-11-01 |
| Herkunft der Kategorien (C) | keine; Regel statt Feld | Herkunftsfeld an `CustomCategoryEntry` (z. B. „aus Gang entstanden“) | exakt, behebt nebenbei, dass `ensureCustomCategory` eine gelöschte Gang-Kategorie beim nächsten `updateStationConfig` neu anlegt; kippt den Beschluss „kein neues Feld, kein iCloud-Schritt“ (Schema-Schritt, Production-Deploy) |
| Bedienung in der Auswahl | Wischen wie bei eigenen Kategorien | Eintrag „Gänge bearbeiten …“, der die Einrichtung öffnet (Entwurf 4, Alternative) | ein Weg weniger, aber man verlässt den Artikel; verworfen vom PO |
| Übernahme | eigener Abschnitt mit „Übernehmen“ je Zeile | Frage „Eigene Kategorien anhängen?“ beim Wählen einer Vorlage (Entwurf 5, Alternative) | nur ein Zeitpunkt, keine Auswahl einzelner Kategorien; verworfen vom PO |
| Einsortieren der Artikel | keine Datenwanderung, Auflösung über `stationNamed` | Artikel beim Übernehmen umschreiben | zerstört das Rückgängigmachen, doppelt die Logik |

Gekippt wird keine frühere Entscheidung; ADR-pflichtig ist nichts. Würde man C wählen, wäre der Beschluss
„kein neues Datenfeld, kein CloudKit-Schritt“ aus 2b gekippt.

## Definition of Done

- [ ] Build erfolgreich, alle Unit- und UI-Tests grün (neue Tests waren vor der Umsetzung rot)
- [ ] CI Teil D läuft grün (12 Tests innerhalb von 60 Minuten), A, B, C unverändert
- [ ] Echter Durchlauf im Simulator mit Belegbildern registriert
- [ ] `project.pbxproj` enthält `StationAdoptionSection.swift` im App-Ziel (Bau von Widget- und Teilen-Ziel unverändert)
- [ ] Release-Strings-Nachweis für die zwei neuen Seed-Argumente abgelegt
- [ ] `CLAUDE.md`-Absatz „Laden-Stationen“ um Durchgang 2b-2 ergänzt, Issue #234 aktualisiert
- [ ] Kein CloudKit-Schritt nötig (bestätigt: nur `stationConfigJSON`, `customCategoryEntries`, `categoryAssignments`)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Fortführung des Musters „reine Logik in `StoreCategories`, Schreiben über `Store.updateStationConfig`,
  Ansicht ruft nur die Hülle“ (#85/#94/D1/2a/2b-1). Regel R3 ist eine reine Filterfunktion über vorhandene Daten, kein
  neues Feld, keine neue Schicht, kein Modell. Wiederverwendet werden `StationSetupView.delete`/`deleteDialog` und der
  Editor der eigenen Kategorien.

## Changelog

- 2026-11-01: Initial spec created (Issue #234, Durchgang 2b-2).
- 2026-11-01 (Validierung): Abweichungen der Umsetzung von „Affected Files“: (1) `adoptableCategories`,
  `adoptCategory`, `adoptAllCategories` und `templateStationNames` stehen als `Store`-Erweiterung in
  `SmartCart/Models/StoreTemplates.swift` (+44) statt in `Store.swift`, weil `Store.swift` auch im Widget- und
  Teilen-Ziel kompiliert wird und die Vorlagen nur im App-Ziel liegen; `Store.swift` bleibt unverändert.
  (2) `StoreDetailView.swift` ist entgegen „Nicht berührt“ geändert (+5/−1, nur `#if DEBUG`): Push in `onDisappear`
  beachtet `-skipCloudKitForScreenshots` (Adversary F001). (3) `StoreCategories.followedChoice(_:next:)` (+33) für die
  Auswahl nach dem Löschen (Adversary F002). (4) `-clearStationStoreForUITests` setzt zusätzlich `shareID = nil`.
  Umfang: Produktivcode +315/−12 in 12 Dateien, Testcode +711 (Schätzung ~525; vom PO ~940 akzeptiert, Mehr aus den
  UI-Tests).
