---
entity_id: store-stations
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: feat-234-laden-stationen
tags: [feature, store, category, sorting, shopping-route, stations, picker]
---

# Laden-Stationen („Gänge“), Durchgang 1 (Issue #234)

## Approval

- [ ] Approved

Offenlegung für die Freigabe (zwei Abweichungen, beide bewusst, beide brauchen das Wort des PO):

1. **Zwischen-Menü in D1.** Damit D1 allein benutzbar ist, bekommt das ···-Menü der Ladenliste zwei
   Einträge: „Lidl-Vorlage übernehmen“ (nur Läden ohne Gänge, mit Rückfrage) und „Gänge entfernen“
   (nur Läden mit Gängen, mit Rückfrage). Das Issue sieht stattdessen „Kategorien einrichten“ vor.
   Beide Einträge entfallen in D2 und gehen in „Kategorien einrichten“ auf.
2. **Umfang.** Mehr als 4–5 Dateien (siehe Abschnitt Scope), Zeilen etwas über dem Zielkorridor
   250–350. Die Datei-Zahl ergibt sich aus der Schichtung (Logik, Modell, Sortierung, Liste, Auswahl,
   zwei Dialoge, Zeile, Texte), nicht aus Nebenarbeiten.

## Purpose

Heute gruppiert die Ladenliste nach den 35 festen Kategorien und lernt deren Reihenfolge aus dem
Abhaken. Das passt nicht zu einem echten Laden wie Lidl, dessen Gänge andere Zuschnitte haben
(„Kühltheke Fertiges“ bündelt Wurst, Tofu, Dips; „Käse“ ist keine feste Kategorie). Ein Laden kann
deshalb eine feste, geordnete Liste eigener **Gänge** (intern „Stationen“) bekommen. Die Liste folgt
dann dieser Reihenfolge, das Abhaken lernt nur noch die Reihenfolge der Artikel innerhalb eines Gangs,
und die Kategorie-Auswahl zeigt nur die Gänge dieses Ladens plus „Sonstiges“. Läden ohne Gänge
verhalten sich Bit für Bit wie bisher.

Dieser Durchgang (D1) liefert: Datenfeld, Auflösung Artikel → Gang (Regeln, kein Modell), die
Lidl-Vorlage, die Sortierung, die Anzeige in der Liste und die Auswahl. Einrichten und Ausblenden per
Oberfläche (D2) und der Abgleich geteilter Läden (D3) folgen.

Bezug zu früheren Entscheidungen: Diese Spec gilt **nur für Läden mit Gängen** und löst dort ab:
`docs/specs/models/shopping-route-order.md` (#79) AC7 („Kategorie-Modus zeigt die Abschnitte in
gelernter Ladenreihenfolge“) sowie `docs/specs/models/store-custom-categories-and-manual-order.md`
(#85/#86) AC7 („Ziehen eines Abschnitts im Modus Kategorie ändert die Abschnitts-Reihenfolge“). Für
Läden ohne Gänge bleiben beide Kriterien unverändert gültig.

Rückfrage-Alternative, die geprüft und verworfen wurde: Stationen als bloße Reihenfolge der
bestehenden eigenen Kategorien (#85) ohne Zuordnung fester Kategorien und ohne Stichwörter. Das
bräuchte pro Artikel eine handgepflegte Zuordnung und hätte „Wurst → Kühltheke“ nicht ohne Eingriff
geliefert. Ebenfalls verworfen: ein Sprachmodell für die Feinteilung (Regeln reichen, siehe
Auflösung).

## Source

- **Neu/Erweitert:** `SmartCart/Models/StoreCategories.swift` (`StationConfig`, `StoreCategories.station(...)`,
  Lidl-Vorlage), `SmartCart/Models/Store.swift` (Feld `stationConfigJSON`, Gang-API),
  `SmartCart/Models/ShoppingRoute.swift` (`SortInput.stationRank`)
- **Oberfläche:** `StoreDetailView`, `CategoryPickerView`, `ItemRow`, `AddItemView`, `EditItemView`
- **Identifier:** `StationConfig`, `StoreCategories.station(forItemNamed:category:manuallySet:remembered:config:)`,
  `StoreCategories.lidlTemplate`, `Store.hasStations`, `Store.stationName(of:)`, `Store.applyStationConfig(_:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `AssignmentService.categoryOrder` / `category(for:)` / `displayCategory` / `categoryEmoji` | service | feste Kategorien als Quelle der Zuordnung (Rohwerte), automatische Kategorie als Auflösungsstufe 4 |
| `ShoppingRoute.sortedIndices`, `itemKey`, `recordCheckOff` | module | Sortierung und Lernen; bekommt den Gang-Rang |
| `StoreCategories` (`normalizedName`, `compareKey`, `suggestedEmoji`, `CustomCategoryEntry`) | module | Namensvergleich, Emoji, eigene Kategorien (#85) |
| `Store.customCategoryEntries`, `categoryAssignments`, `categoryAssignmentDates` | model | Gang-Namen sind (außer bei Namensgleichheit mit festen Kategorien) eigene Kategorien; Merken je Artikel (#94) |
| `ShoppingItem.init` (`rememberedCategory`), `adoptCategory` | model | wenden die gemerkte Zuordnung an |
| `UITestItemEditor.open`, `UITestWait`, `UITestLaunch` | test helper | Bearbeiten-Dialog öffnen, warten, starten |
| `RestockTests/MirroredSchemaSnapshotTests`, `docs/cloudkit/private-schema-aktuell.ckdb` | test/doc | neues gespiegeltes Feld |
| `docs/context/feat-234-laden-stationen.md`, `docs/artifacts/feat-234-laden-stationen/entwurfsvorschau.html` | doc | Analyse und vom PO freigegebener Entwurf 1–3 (2026-10-30) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | `StationConfig`/`Station`, Auflösung `station(...)`, Sonstiges-Marke, Lidl-Vorlage (Daten), Namensprüfung |
| `SmartCart/Models/Store.swift` | MODIFY | Feld `stationConfigJSON`, `hasStations`, `stationConfig`, `stationName(of:)`, `applyStationConfig`, `removeStations`, `pendingItems` mit Rang, `recordCheckOff` mit Gang, `rememberCategory`/`rememberedCategory` für Gänge und Marke |
| `SmartCart/Models/ShoppingRoute.swift` | MODIFY | `SortInput.stationRank` (Standard `nil`), Vergleich Rang vor Position in den Modi Einkaufsweg und Kategorie |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | Gruppierung nach Gang (Sonstiges zuletzt), ···-Menü (zwei Einträge, „Reihenfolge anpassen“ im Kategorie-Modus ausgeblendet), Rückfragen |
| `SmartCart/Views/Store/CategoryPickerView.swift` | MODIFY | Gang-Modus: nur Gänge + „Sonstiges“, Anlegen eines Gangs, `itemName`, `onPick` |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | Zeilen-Untertitel = Gang bzw. „Sonstiges“ in Läden mit Gängen |
| `SmartCart/Views/Store/AddItemView.swift` | MODIFY | Kategorie-Zeile zeigt den Gang; Speichern: Gang bzw. Marke merken |
| `SmartCart/Views/Store/EditItemView.swift` | MODIFY | dasselbe für den Bearbeiten-Dialog |
| `SmartCart/SmartCartApp.swift` | MODIFY | nur DEBUG: `-seedStationStoreForUITests`, `-clearStationStoreForUITests` |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | neue Schlüssel (siehe Lokalisierung) |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | MODIFY | Feldliste `Store` um `stationConfigJSON` |
| `docs/cloudkit/private-schema-aktuell.ckdb` | MODIFY | `CD_stationConfigJSON STRING` in `CD_Store` |
| `RestockTests/StoreStationsTests.swift` | CREATE | Unit-Tests (neu in `project.pbxproj`, Ziel `RestockTests`) |
| `RestockTests/ShoppingRouteTests.swift` | MODIFY | Regressionstest Pfad `stationRank == nil` |
| `RestockUITests/StoreStationsUITests.swift` | CREATE | UI-Tests (neu in `project.pbxproj`, Ziel `RestockUITests`) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | beide neuen Testdateien von Hand eintragen (PBXBuildFile, PBXFileReference, Gruppe, Sources-Phase) |
| `CLAUDE.md` | MODIFY | Absatz „Laden-Stationen“ (Architekturänderung) |

Produktivdateien in App-, Widget- und Teilen-Ziel: `StoreCategories`, `Store`, `ShoppingRoute` liegen
schon in allen drei Zielen; es entsteht **keine** neue Produktivdatei und damit kein neuer Eintrag in
den Ziel-Listen. Nur zwei neue Testdateien brauchen `project.pbxproj`.

### Estimated Changes

- Files: 18 (Produktiv 11 [9 Swift, davon 1 DEBUG-Seed, plus 2 Strings-Dateien], Schema/Test 2, neue Tests 2 + Registrierung 1 + `CLAUDE.md` 1, `ShoppingRouteTests` 1)
- LoC Produktivcode: +~330/−~20 ohne DEBUG-Seed und Strings, +~400 mit beiden (StoreCategories ~+150 davon ~80 Vorlagen-Daten,
  Store ~+75, ShoppingRoute ~+15, StoreDetailView ~+45, CategoryPickerView ~+45, ItemRow/Add/Edit ~+25,
  SmartCartApp ~+40, Strings 2×~12). Tests zusätzlich ~+350. Über dem Dateilimit; Freigabe steckt im `approved`.

### Nicht in diesem Durchgang

D2 und D3 (siehe Ausblick), Änderungen an `HomeView`/`AllItemsView` (ladenübergreifend, bleiben bei festen
Kategorien), Preisschätzung (zählt weiter die automatische Kategorie), Widget/Live Activity/`CheckoffQueue`
(erben die Reihenfolge über `Store.pendingItems`, kein eigener Code), `SharedStoreService`, `SyncCoordinator`.

## Implementation Details

### Datenmodell

- `StationConfig: Codable, Equatable` (in `StoreCategories.swift`): `stations: [Station]` (Reihenfolge =
  Gang-Reihenfolge), `hidden: [String]` (Rohwerte fester Kategorien), `date: Date` (Zeitpunkt der letzten
  Änderung, in D3 für den Abgleich).
- `Station: Codable, Equatable`: `name: String`, `emoji: String`, `builtIns: [String]` (Rohwerte aus
  `AssignmentService.categoryOrder`), `keywords: [String]` (einzelne Wörter, ≥ 3 Buchstaben).
- Am `Store`: additives SwiftData-Feld `stationConfigJSON: String = ""` (skalar mit Standardwert,
  CloudKit-tauglich, kein Schema-Versionsbump). **Leer, nicht dekodierbar oder ohne Gänge = Laden ohne
  Gänge**: `hasStations == false`, jedes Verhalten exakt wie heute. `stationConfig` (get/set) kapselt
  die JSON-Umwandlung; `hasStations` prüft zuerst `stationConfigJSON.isEmpty`, damit Läden ohne Gänge
  nichts dekodieren.
- Gang-Identität ist der Name (Vergleich über `StoreCategories.normalizedName`/`compareKey`, Namen
  eindeutig, nicht leer, nicht gleich „Sonstiges“/„Other“ und nicht gleich der Sonstiges-Marke).
  - Ist der Name ein Rohwert einer festen Kategorie (z. B. „Obst & Gemüse“, „Getränke“, „Milchprodukte“),
    wird er **nicht** als eigene Kategorie angelegt; das Emoji kommt aus `station.emoji`.
  - Sonst legt `Store.applyStationConfig` ihn (falls fehlend) als eigene Kategorie an
    (`customCategoryEmojis`/`customCategoryDates`, Emoji = `station.emoji`), damit die #85-Mechanik
    (Umbenennen, Löschen, Emoji, Startseite) weiter greift. Ein schon vorhandener Eintrag bleibt
    unverändert.
- **„Sonstiges“ ist virtuell**: nie als Kategoriename gespeichert, nie in `item.category`. Anzeigename
  lokalisiert (`station.other`). Die Wahl „Sonstiges“ im Dialog wird als gemerkte Zuordnung
  `categoryAssignments[itemKey] = StoreCategories.otherStationMarker` festgehalten, damit der Artikel
  trotz Stichwort oder fester Kategorie in „Sonstiges“ bleibt. Die Marke ist ein Wert mit
  Private-Use-Zeichen am Anfang (`"\u{E000}other"`), den `normalizedName` nicht erzeugt und den die
  Namensprüfung beim Anlegen ablehnt; sie wird **nie** in `ShoppingItem.category` geschrieben und
  `rememberedCategory(forItemNamed:)` gibt sie nie zurück (der Artikel behält dann die automatische
  Kategorie, die Auflösung liest die Marke direkt aus `categoryAssignments`).

### Auflösung Artikel → Gang (Regeln, kein Modell)

Reine Funktion `StoreCategories.station(forItemNamed:category:manuallySet:remembered:config:) -> String?`
(`nil` = Sonstiges). Reihenfolge, erste zutreffende Stufe gewinnt:

1. **Gemerkt:** `remembered` (Wert von `categoryAssignments[itemKey]`) ist die Marke → `nil`; benennt er
   einen Gang der Konfiguration → dieser Gang; benennt er keinen (veraltet) → weiter.
2. **Von Hand gesetzte Kategorie** (`manuallySet == true`): ist sie ein Gang-Name → dieser Gang; ist sie
   eine feste Kategorie, die in den `builtIns` eines Gangs steht und nicht in `hidden` → dieser Gang;
   sonst weiter (insbesondere eine eigene, nicht zum Gang gehörende Kategorie wird übergangen).
3. **Stichwort:** Jedes Wort des Artikelnamens (kleingeschrieben, `compareKey`, getrennt an allem, was
   kein Buchstabe oder keine Ziffer ist) gilt als Treffer, wenn es einem Stichwort **gleicht oder darauf
   endet** (deutsches Kompositum: „Geflügelsalami“ → „salami“; „Salatgurke“ trifft „salat“ nicht, weil
   es nicht darauf endet). Das längste Stichwort gewinnt, bei Gleichstand der frühere Gang.
4. **Automatische Kategorie** (`AssignmentService.category(for:)`): steht sie in den `builtIns` eines
   Gangs (nicht in `hidden`) oder gleicht sie einem Gang-Namen → dieser Gang.
5. Sonst `nil` (Sonstiges).

Ausgeblendete feste Kategorien (`hidden`) treffen in Stufe 2 und 4 nie; ihre Artikel landen in
Sonstiges, sofern kein Stichwort oder keine Merkung greift. In D1 gibt es noch keine Oberfläche zum
Ausblenden; das Feld wird nur von der Vorlage gesetzt.

Store-Hülle: `Store.stationName(of item:) -> String?` ruft die Funktion mit `categoryAssignments[itemKey]`,
`item.category` und `item.categoryManuallySet`. `Store.stationRank(of:)` = Index des Gangs in
`config.stations`, „Sonstiges“ = `stations.count`.

### Sortierung

- `ShoppingRoute.SortInput` bekommt `var stationRank: Int? = nil`. Ist er `nil` (Läden ohne Gänge),
  läuft `sortedIndices` **unverändert** über den bisherigen Code.
- Mit Rang, Modus `.route` **und** `.category`: Dringende zuerst (wie bisher), dann Gang-Rang
  aufsteigend, dann gelernte Artikelposition (`model.itemPositions`; bekannte vor unbekannten, bei
  Gleichstand weiter), dann `addedDate`, dann Eingangsindex. Mittelwert der Kategorie als Ersatzposition
  und gelernte Abschnittsreihenfolge (`orderedCategories`) kommen für Läden mit Gängen nicht zum
  Einsatz; die gelernten Daten bleiben gespeichert (Rückweg über „Gänge entfernen“ ohne Verlust).
- Modus `.added` bleibt unverändert.
- `Store.pendingItems` setzt `stationRank` für jeden Artikel, wenn `hasStations`; sonst nichts.
- `Store.recordCheckOff` zeichnet als Kategorie den Gang-Namen auf (für „Sonstiges“ die Marke), damit das
  Lernen an die Gang-Zugehörigkeit gebunden bleibt. Die gelernten Positionen sind ohnehin über den
  ganzen Einkauf normiert; durch den Gang-Rang als erstes Kriterium entscheidet ein Haken zuerst in
  einem späteren Gang nichts über Gänge, nur über die Reihenfolge innerhalb seines Gangs.
- `Store.orderedCategories`, `applyManualCategoryOrder` und das Abschnitt-Ziehen werden für Läden mit
  Gängen nicht benutzt.

### Anzeige in der Liste (Entwurf 1 und 2, vom PO freigegeben)

- **Modus „Kategorie“:** ein Abschnitt je Gang in fester Reihenfolge, Überschrift mit dem Gang-Emoji;
  „Sonstiges“ als letzter Abschnitt, **ohne Emoji** (wie im Entwurf), nur wenn nicht leer; leere Gänge
  erscheinen nicht. Dringende bleiben im eigenen Abschnitt „Dringend“ oben. Technisch: `groupedRegularItems`
  gruppiert in Läden mit Gängen nach `stationName(of:)` (`nil` → Sonstiges-Marke) und ordnet nach
  `config.stations`, Sonstiges zuletzt; Überschrift für die Marke: `station.other`, für Gänge mit
  Namen einer festen Kategorie wie bisher der lokalisierte Anzeigename, sonst der Gang-Name.
- **Modus „Einkaufsweg“:** flache Liste ohne Überschriften in Gang-Reihenfolge; die Zeile zeigt als
  Untertitel den Gang-Namen (oder „Sonstiges“) statt der festen Kategorie (`ItemRow`).
- **„Reihenfolge anpassen“:** Im Modus „Kategorie“ eines Ladens mit Gängen wird der Menüeintrag
  ausgeblendet (die Reihenfolge ist fest; Änderung in D2). Im Modus „Einkaufsweg“ bleibt er und das
  Ziehen von Artikeln schreibt Positionen wie heute (`applyManualOrder`); weil die Sortierung zuerst
  nach Gang gruppiert, wirkt ein Ziehen nur innerhalb eines Gangs, über die Gang-Grenze springt die
  Zeile zurück (bekannte Grenze). „Gelernte Reihenfolge zurücksetzen“ bleibt unverändert.
- **···-Menü (Zwischenlösung D1):** „Lidl-Vorlage übernehmen“ nur ohne Gänge,
  „Gänge entfernen“ nur mit Gängen; beide mit `confirmationDialog`. Übernehmen setzt
  `stationConfig` auf `StoreCategories.lidlTemplate` (Zeitstempel jetzt) und legt die Gang-Namen als
  eigene Kategorien an (s. o.); es ändert keine Artikel. Entfernen leert `stationConfigJSON`, behält
  eigene Kategorien und gemerkte Zuordnungen (die Marke wirkt dann nicht mehr und wird nie angezeigt).
- Die Mechanik bleibt über Aktionen erreichbar mit stabilen Kennungen: Menüeinträge
  `store.menu.applyStationTemplate` und `store.menu.removeStations`.

### Auswahl (Entwurf 3)

`CategoryPickerView` bekommt zwei neue Eingaben: `itemName` (zum Berechnen der aktuellen Wahl) und
`onPick` (wird bei **jedem** Wählen aufgerufen, auch bei gleichem Wert; Add/Edit setzen damit
`categoryPicked`). In Läden mit Gängen zeigt sie:

- Suchfeld (filtert die Gänge, `StoreCategories.matches`), darunter Abschnitt „Gänge bei <Laden>“
  mit den Gängen in Laden-Reihenfolge (Emoji, Name, Anzahl offener Artikel), danach die Zeile
  „Sonstiges“. Kein Abschnitt „Alle Kategorien“. Die Wischaktionen Bearbeiten/Löschen entfallen in
  D1 (kommen in D2).
- Treffer-Markierung (Häkchen) auf dem Gang, den `Store.stationName(...)` für die aktuelle Wahl und den
  Artikelnamen ergibt; „Sonstiges“, wenn die Auflösung `nil` ergibt oder die Marke gewählt wurde.
- **Anlegen:** Findet die Suche keinen Gang genau, bietet die erste Zeile „„<Name>“ als Gang bei <Laden>
  anlegen“. Es wird gegen Gang-Namen aufgelöst (nicht gegen feste Kategorien): gleicht die Eingabe einem
  Gang → dieser Gang; gleicht sie „Sonstiges“ → Sonstiges; sonst entsteht ein neuer Gang (leere
  `builtIns`/`keywords`, Emoji `suggestedEmoji`) **am Ende der Gang-Liste, vor „Sonstiges“**, und wird
  gewählt. Ein eingegebener Rohname einer festen Kategorie wird ebenfalls ein Gang dieses Namens.
- Ohne Laden oder in Läden ohne Gänge unverändert (heutiges Verhalten).

Wahl und Merken in Add/Edit für Läden mit Gängen:

- **Gang gewählt:** `item.category = Gang-Name`, `categoryManuallySet = true`; beim Speichern
  `rememberCategory` – auch wenn der Gang-Name einer festen Kategorie gleicht (sonst würde ein Stichwort
  die Wahl später überstimmen).
- **Sonstiges gewählt:** `item.category = automatische Kategorie`, `categoryManuallySet = false`,
  gemerkt wird die Marke. Die Marke steht nie in `item.category`.
- Gemerkt wird, sobald `onPick` in dieser Sitzung aufgerufen wurde (Add: beim Speichern; Edit:
  zusätzlich zur bisherigen Bedingung „Kategorie geändert“). Wer den Dialog ohne Wahl speichert, ändert
  keine Merkung. Bricht man ab, wird nichts gemerkt.
- `Store.rememberCategory(_:forItemNamed:)` merkt (statt nur bei eigenen Kategorien) in Läden mit Gängen
  auch Gang-Namen und die Marke; jede andere Kategorie vergisst die Merkung wie bisher.
  `Store.rememberedCategory(forItemNamed:)` liefert eine gemerkte eigene Kategorie **oder** einen noch
  vorhandenen Gang-Namen, nie die Marke. `ShoppingItem.init` und `adoptCategory` bleiben unverändert und
  profitieren davon (neuer Artikel landet wieder im gemerkten Gang).
- Die Kategorie-Zeile der Dialoge (`categoryLabel`) zeigt in Läden mit Gängen „<Emoji> <Gang>“ bzw.
  „Sonstiges“, berechnet aus der Auflösung für den aktuellen Namen.

### Lidl-Vorlage

Statisch in `StoreCategories.lidlTemplate` (Daten, kein Netz). Reihenfolge wie im Issue. Stichwörter
folgen der Regel „gleich oder endet auf“ (Stufe 3). Überschneidungen mit der automatischen Kategorie
wurden gegen `AssignmentService.categoryMap` geprüft; ein Test (`testTemplateRoutesTypicalItems`)
hält die typischen Artikel fest.

| # | Gang | Emoji | Feste Kategorien (`builtIns`) | Stichwörter |
|---|------|-------|-------------------------------|-------------|
| 1 | Obst & Gemüse | 🥦 | Obst & Gemüse | – |
| 2 | Frische Säfte, Salate, gekühlte Getränke | 🥗 | – | saft, smoothie, eistee, salatbox, nudelsalat, kartoffelsalat, wurstsalat, fleischsalat, krautsalat, eiersalat |
| 3 | Nüsse, Süßigkeiten, Kaffee, Tee | ☕️ | Snacks | kaffee, tee, espresso, cappuccino, nüsse, mandeln, schokolade |
| 4 | Brot & Backwaren | 🥖 | Backwaren | – |
| 5 | Konserven & Gewürze | 🥫 | Konserven, Gewürze & Backen | – |
| 6 | Frisches Fleisch & Fisch | 🥩 | Fleisch & Wurst | fisch, lachs, forelle, garnelen, bratwurst, hackfleisch, hähnchen, steak, schnitzel |
| 7 | Kühltheke Fertiges | 🧊 | – | wurst, würstchen, salami, schinken, aufschnitt, leberkäse, tofu, hummus, dip, tzatziki, matjes, maultaschen |
| 8 | Käse | 🧀 | – | käse, gouda, edamer, emmentaler, mozzarella, feta, parmesan, camembert, brie, gorgonzola, halloumi |
| 9 | Milchprodukte | 🥛 | Milchprodukte | eier, margarine |
| 10 | Tiefkühl | ❄️ | Tiefkühlkost | fischstäbchen, pommes, pizza, eiscreme, speiseeis, nuggets |
| 11 | Drogerie | 🧴 | Körperpflege, Haarpflege, Zahnpflege, Kosmetik, Hygieneartikel, Reinigung, Medikamente, Babybedarf | hustensaft |
| 12 | Getränke | 🥤 | Getränke | – |

`hidden` der Vorlage (Baumarkt): Werkzeug, Eisenwaren, Garten, Pflanzen, Farbe & Lack, Sanitär,
Boden & Fliesen, Holz, Baumaterial. Alle übrigen festen Kategorien (z. B. Haushaltswaren,
Küchenausstattung, Elektronik, Textilien, Schreibwaren, Spielzeug, Dekoration, Tierbedarf) sind „offen“
und landen in Sonstiges.

Begründete Einzelentscheidungen:

- „Lebensmittel“ ist in **keinem** Gang: `AssignmentService.category(for:)` liefert diesen Wert nur als
  Rückfall für unerkannte Namen (`AssignmentService+Category.swift`, letzte Zeile von `category(for:)`).
  Stünde er in einem Gang, landete alles Unerkannte dort statt in „Sonstiges“ (Issue #234, Punkt 3).

- „bratwurst“ (9 Buchstaben) schlägt „wurst“ (5): Bratwurst bleibt beim frischen Fleisch, Leberwurst,
  Salami, Teewurst (endet auf „wurst“, nicht auf „tee“) gehen in die Kühltheke.
- „leberkäse“ steht in der Kühltheke, damit das Stichwort „käse“ (Endung) ihn nicht zum Käse zieht.
- „hustensaft“ steht bei Drogerie, damit „saft“ ihn nicht zu den frischen Säften zieht.
- „eis“ ist **kein** Stichwort (würde auf „Reis“ treffen); Eis läuft über „eiscreme“/„speiseeis“ und die
  Kategorie Tiefkühlkost.
- „salat“ allein ist **kein** Stichwort: Feldsalat, Kopfsalat, Salatgurke bleiben bei Obst & Gemüse.
- „pesto“, „fertiggericht“ sind bewusst nicht aufgenommen (Glas bzw. Tiefkühl nicht eindeutig).
- Bekannte Folge: „Apfelsaft“ landet über „saft“ bei den frischen Säften, nicht bei Getränken; wer das
  anders will, wählt Getränke, der Laden merkt es (Stufe 1).
- Gang-Namen der Vorlage sind gespeicherte Daten und deshalb deutsch, auch in der englischen Oberfläche.

### Lokalisierung (de + en, `LocalizationKeyParityTests`)

`station.other` („Sonstiges“/„Other“), `station.picker.section` („Gänge bei %@“/„Aisles at %@“),
`station.picker.create` („„%@“ als Gang bei %@ anlegen“/„Add “%@” as an aisle at %@“),
`station.menu.applyTemplate` („Lidl-Vorlage übernehmen“/„Apply Lidl template“),
`station.menu.remove` („Gänge entfernen“/„Remove aisles“),
`station.template.confirm.title` („Lidl-Vorlage übernehmen?“/„Apply Lidl template?“),
`station.template.confirm.message` („Die Liste dieses Ladens folgt dann den Gängen von Lidl. Deine
eigenen Kategorien und gemerkten Zuordnungen bleiben erhalten.“/„This store's list will then follow
Lidl's aisles. Your own categories and remembered assignments are kept.“),
`station.remove.confirm.title` („Gänge entfernen?“/„Remove aisles?“),
`station.remove.confirm.message` („Die Liste sortiert wieder nach den Standard-Kategorien. Eigene
Kategorien und gemerkte Zuordnungen bleiben erhalten.“/„The list sorts by the standard categories
again. Your own categories and remembered assignments are kept.“).
Platzhalterzahl in beiden Sprachen gleich.

### Geteilte Läden in D1

`stationConfigJSON` wird nicht in den geteilten Record geschrieben und nicht gelesen. Auf dem eigenen
Gerät hat der Laden Gänge, auf dem Gerät eines Mitglieds nicht (dort Listen wie bisher, die Gang-Namen
sind als eigene Kategorien über `categoriesJSON` sichtbar). Das ist eine bekannte Grenze bis D3.

### Deploy-Pflicht (privates CloudKit-Schema)

`Store` bekommt ein neues gespiegeltes Feld. **Vor dem nächsten TestFlight-Upload:** (1) Datei
`docs/cloudkit/private-schema-aktuell.ckdb` ergänzen (`CD_stationConfigJSON STRING`, in D1 enthalten),
(2) nach dem Zusammenführen auf `main` das Development-Schema über
`.github/workflows/cloudkit-schema.yml` (`mode=import-development`, `confirm=development`) einspielen,
(3) im CloudKit-Dashboard „Deploy Schema Changes…“ nach Production. Schritte 2 und 3 sind **nicht**
Teil der Umsetzung im PR; sie werden in Definition of Done als Pflichtpunkt vor dem Upload geführt.
Ohne sie scheitert in Production der ganze Export der Spiegelung (Ablauf `docs/testflight-setup.md`,
Spec `docs/specs/models/private-cloudkit-schema.md`).

## Test Plan

Alle Tests werden vor der Umsetzung geschrieben (TDD RED: neue Tests übersetzen/scheitern, solange API
und Seed fehlen; die Umsetzung bringt sie nach GREEN).

### Automated Tests (TDD RED)

Unit, `RestockTests/StoreStationsTests.swift` (In-Memory-Container immer `cloudKitDatabase: .none`;
`UserDefaults`-Schlüssel des Ladens in `tearDown` entfernen):

- [ ] T1: GIVEN `stationConfigJSON` leer, kaputt („{“) oder mit null Gängen WHEN `hasStations` THEN `false`, `pendingItems` identisch zum Verhalten ohne Feld (AC-1)
- [ ] T2: GIVEN Vorlage angewendet, Artikel Salami, Gouda, Apfel, Milch, Batterien WHEN `stationName(of:)` THEN Kühltheke Fertiges, Käse, Obst & Gemüse, Milchprodukte, `nil` (AC-3, AC-4)
- [ ] T3: GIVEN Vorlage WHEN Salatgurke, Bratwurst, Leberkäse, Hustensaft, Teewurst, Eistee, Hammer, „Qwertz“ THEN Obst & Gemüse, Frisches Fleisch & Fisch, Kühltheke Fertiges, Drogerie, Kühltheke Fertiges, Frische Säfte, Salate, gekühlte Getränke, `nil` (Hammer: ausgeblendet), `nil` (unerkannt → „Lebensmittel“ → Sonstiges) (AC-4, AC-5)
- [ ] T4: GIVEN Konfiguration mit Stichwort „salat“ WHEN „Geflügelsalat“ und „Salatgurke“ THEN der Erste trifft („endet auf“), der Zweite nicht (AC-4)
- [ ] T5: GIVEN zwei Stichwörter treffen („wurst“, „bratwurst“) WHEN Auflösung THEN das längere gewinnt; bei gleicher Länge der frühere Gang (AC-4)
- [ ] T6: GIVEN Merkung auf Gang X, Marke, veralteter Gang-Name, manuell gesetzte Kategorie WHEN Auflösung THEN Reihenfolge 1 > 2 > 3 > 4 > 5 wie spezifiziert (AC-6)
- [ ] T7: GIVEN ausgeblendete feste Kategorie, die auch in einem `builtIns` steht WHEN Artikel dieser Kategorie THEN Sonstiges, Stichwort/Merkung weiter wirksam (AC-5)
- [ ] T8: GIVEN Vorlage WHEN geprüft THEN genau 12 Gänge in der Reihenfolge der Tabelle, Namen eindeutig, jede `builtIns`/`hidden`-Angabe in `categoryOrder`, keine feste Kategorie in zwei Gängen, `hidden` ohne Überschneidung mit `builtIns`, Stichwörter ≥ 3 Buchstaben und ≤ 15 je Gang (AC-3)
- [ ] T9: GIVEN Store mit Gängen, Artikel in drei Gängen und Sonstiges, Modi route/category WHEN `pendingItems` THEN Dringende zuerst, dann Gang-Rang, dann Position, Sonstiges zuletzt; Modus added unverändert (AC-2, AC-7, AC-8)
- [ ] T10: GIVEN zwei Haken in der Reihenfolge Milch (Gang 9), Apfel (Gang 1), Einkauf abgeschlossen WHEN `pendingItems` THEN Apfel bleibt vor Milch; zwei Artikel desselben Gangs in umgekehrter Reihenfolge abgehakt → Reihenfolge innerhalb des Gangs lernt (AC-9)
- [ ] T11: GIVEN `recordCheckOff` WHEN Artikel aus Gang und aus Sonstiges THEN aufgezeichnete Kategorie = Gang-Name bzw. Marke (AC-9)
- [ ] T12: GIVEN `applyStationConfig(lidlTemplate)` WHEN danach THEN Gang-Namen, die keine festen Kategorien sind, stehen als eigene Kategorien; „Obst & Gemüse“, „Getränke“, „Milchprodukte“ nicht; `removeStations` leert das Feld, behält eigene Kategorien und Merkungen (AC-14)
- [ ] T13: GIVEN Laden mit Gängen WHEN `rememberCategory("Käse"/Marke/feste Kategorie)` und `rememberedCategory` THEN Gang gemerkt auch bei Namensgleichheit mit fester Kategorie, Marke gemerkt aber nie als Kategorie zurückgegeben, feste Kategorie vergisst (AC-12, AC-13)
- [ ] T14: GIVEN neuer Gang aus der Auswahl-Logik WHEN angelegt THEN steht er am Ende der Gang-Liste, Namensprüfung lehnt „Sonstiges“/„Other“ als neuen Gang ab, Eingabe eines vorhandenen Gangs wählt ihn (AC-11)
- [ ] T15: GIVEN Konfiguration WHEN JSON-Roundtrip THEN gleich; nicht dekodierbarer Text → `stationConfig == nil` (AC-1)
- [ ] T16: `MirroredSchemaSnapshotTests` (T1 und T2 dort): Feld `stationConfigJSON` in Feldliste `Store` und in `private-schema-aktuell.ckdb` (AC-16)

Unit-Regression, `RestockTests/ShoppingRouteTests.swift`:

- [ ] T17: GIVEN `SortInput` ohne `stationRank` (nil) WHEN `sortedIndices` für route, category, added mit fest vorgegebenen Eingaben THEN exakt die bisher erwarteten Reihenfolgen (festgeschriebene Listen); Bestandstests unverändert grün (AC-1)

Unit, weitere (in `StoreStationsTests.swift` bzw. Bestand):

- [ ] T18: GIVEN die kompilierten Tabellen `de.lproj`/`en.lproj` mit den neuen `station.*`-Schlüsseln WHEN `LocalizationKeyParityTests` THEN gleiche Schlüssel und gleiche Platzhalter je Schlüssel (AC-17)
- [ ] T19: GIVEN Laden mit Lidl-Vorlage, Artikel „Salami“ per Stichwort in „Kühltheke Fertiges“ und „Batterien“ in Sonstiges WHEN angelegt und Gang über `stationName(of:)` gelesen THEN `item.category` bleibt die automatische Kategorie („Fleisch & Wurst“ bzw. die von `category(for:)`), `categoryManuallySet == false`, und `PriceEstimator.resolve` liefert für den Artikel dasselbe Ergebnis wie im gleichen Laden ohne Gänge (Preisschätzung und ladenübergreifende Gruppierung nach fester Kategorie unverändert) (AC-17)

UI, `RestockUITests/StoreStationsUITests.swift` (Start über `UITestLaunch.start` mit
`-hasCompletedOnboarding YES -seedStationStoreForUITests`, `tearDown` startet einmal mit
`-clearStationStoreForUITests`; nie `-developerMode`):

- [ ] U1: GIVEN Seed WHEN Modus „Kategorie“ THEN Abschnitte in Gang-Reihenfolge: Dringend (Brot), Obst & Gemüse (Apfel), Kühltheke Fertiges (Salami), Käse (Gouda), Milchprodukte (Milch), Sonstiges (Batterien); leere Gänge ohne Überschrift (AC-2, AC-3, AC-4)
- [ ] U2: GIVEN Seed WHEN Modus „Einkaufsweg“ THEN flache Reihenfolge Brot, Apfel, Salami, Gouda, Milch, Batterien (Hinzufüge-Reihenfolge weicht ab); Untertitel „Kühltheke Fertiges“ unter Salami und „Sonstiges“ unter Batterien; keine Gang-Überschrift (AC-8, AC-10)
- [ ] U3: GIVEN Seed WHEN Auswahl in „Salami“ öffnen THEN Zeilen `categoryPicker.row.<Gang>` für alle 12 Gänge und `categoryPicker.row.other`; keine Zeile für feste Kategorien (z. B. `categoryPicker.row.Werkzeug`, `categoryPicker.row.Körperpflege`) und kein Abschnitt „Alle Kategorien“ (AC-11)
- [ ] U4: GIVEN Seed WHEN in „Batterien“ über die Suche „Backstation“ anlegen, speichern THEN im Modus „Kategorie“ ist „Backstation“ der letzte Abschnitt hinter Milchprodukte, „Sonstiges“ erscheint nicht mehr (AC-11)
- [ ] U5: GIVEN Seed WHEN „Batterien“ auf „Drogerie“ setzen, speichern, den Artikel löschen und „Batterien“ über „+“ neu hinzufügen THEN er erscheint im Abschnitt Drogerie (AC-12)
- [ ] U6: GIVEN Seed, Modus „Kategorie“ WHEN ···-Menü THEN „Reihenfolge anpassen“ fehlt; im Modus „Einkaufsweg“ ist sie da; „Gänge entfernen“ ist da, „Lidl-Vorlage übernehmen“ nicht (AC-15)
- [ ] U7: GIVEN Seed WHEN „Gänge entfernen“ bestätigen THEN Abschnitt „Fleisch & Wurst“ für Salami (klassische Kategorie), „Reihenfolge anpassen“ wieder da, Eintrag „Lidl-Vorlage übernehmen“ da; WHEN erneut übernehmen und bestätigen THEN wieder Gang-Abschnitte (AC-14)

Durchlauf (Pflicht, Simulator, Stand dieser Änderung): als Nutzer einen Laden mit „Lidl-Vorlage
übernehmen“ einrichten, Artikel hinzufügen, beide Modi und die Auswahl durchspielen, mit Bildschirmfotos
unter `docs/artifacts/feat-234-laden-stationen/`. Nichts auf Hennings Geräten ohne sein ausdrückliches
Wort.

## Acceptance Criteria

- **AC-1:** Ein Laden ohne Gänge (Feld leer, nicht dekodierbar oder ohne Gänge) verhält sich
  bitgenau wie bisher: `sortedIndices` mit `stationRank == nil` liefert in allen drei Modi dieselben
  Reihenfolgen wie vor der Änderung (festgeschriebene Regressionsfälle), `pendingItems`, Gruppierung,
  Auswahl und Menü unverändert; Bestandstests (`ShoppingRouteTests`, `ShoppingRouteManualOrderTests`,
  `StoreCategoriesTests`, `ShoppingRouteUITests`, `ShoppingRouteLearningUITests`) bleiben grün.
- **AC-2:** Mit Lidl-Vorlage zeigt der Modus „Kategorie“ je nicht leerem Gang einen Abschnitt in der
  festen Gang-Reihenfolge, mit Gang-Emoji in der Überschrift; leere Gänge erscheinen nicht; Dringende
  bleiben im Abschnitt „Dringend“ oben.
- **AC-3:** „Sonstiges“ ist der letzte Abschnitt (ohne Emoji) und erscheint nur, wenn mindestens ein
  offener Artikel dort liegt; die Vorlage hat genau die 12 Gänge der Tabelle in dieser Reihenfolge.
- **AC-4:** Stichwort-Zuordnung: Salami → Kühltheke Fertiges, Gouda → Käse, Salatgurke → Obst &
  Gemüse, Bratwurst → Frisches Fleisch & Fisch, Leberkäse → Kühltheke Fertiges, ein unerkannter Name
  (automatische Kategorie „Lebensmittel“) → Sonstiges; ein Stichwort trifft,
  wenn ein Wort des Namens ihm gleicht oder darauf endet, das längste Stichwort gewinnt, bei Gleichstand
  der frühere Gang.
- **AC-5:** Eine ausgeblendete feste Kategorie (Vorlage: Baumarkt, z. B. Werkzeug) ordnet ihre Artikel
  nie einem Gang zu; sie landen in „Sonstiges“, sofern weder Merkung noch Stichwort greifen. Feste
  Kategorien, die keinem Gang zugeordnet und nicht ausgeblendet sind (offen), landen ebenfalls in
  „Sonstiges“.
- **AC-6:** Die Auflösung folgt der Reihenfolge Merkung > von Hand gesetzte Kategorie > Stichwort >
  automatische Kategorie > Sonstiges; die Sonstiges-Marke hält einen Artikel gegen Stichwort und feste
  Kategorie in „Sonstiges“.
- **AC-7:** Im Modus „Einkaufsweg“ stehen die Artikel in Gang-Reihenfolge, innerhalb eines Gangs nach
  gelernter Artikelposition, dann nach Hinzufüge-Datum; der Modus „Kategorie“ gilt dieselbe Ordnung der
  Zeilen innerhalb der Abschnitte; „Hinzugefügt“ ist unverändert.
- **AC-8:** Dringende Artikel stehen in beiden Modi zuerst, unabhängig vom Gang.
- **AC-9:** Das Abhaken lernt nur die Reihenfolge innerhalb eines Gangs: Ein Artikel, der in einem
  späteren Gang zuerst abgehakt wurde, rückt nicht vor Artikel früherer Gänge; `recordCheckOff` zeichnet
  den Gang-Namen (Sonstiges: die Marke) als Kategorie auf.
- **AC-10:** Im Modus „Einkaufsweg“ ist die Liste flach ohne Gang-Überschriften; der Untertitel jeder
  Zeile zeigt den Gang-Namen oder „Sonstiges“ statt der festen Kategorie.
- **AC-11:** Die Kategorie-Auswahl eines Ladens mit Gängen zeigt nur dessen Gänge in Laden-Reihenfolge
  plus „Sonstiges“ (keine festen Kategorien, kein Abschnitt „Alle Kategorien“); „„<Name>“ als Gang
  anlegen“ hängt einen neuen Gang vor „Sonstiges“ an und wählt ihn; „Sonstiges“/„Other“ kann kein Gang
  werden.
- **AC-12:** Die Wahl eines Gangs (auch eines, dessen Name einer festen Kategorie gleicht) wird je
  Artikelschlüssel gemerkt; ein neu hinzugefügter Artikel gleichen Namens landet wieder im gemerkten Gang
  (`ShoppingItem.init`).
- **AC-13:** Die Wahl „Sonstiges“ wird als Marke gemerkt, steht nie in `ShoppingItem.category` und wird
  von `rememberedCategory(forItemNamed:)` nie als Kategorie zurückgegeben.
- **AC-14:** „Gänge entfernen“ (mit Rückfrage) stellt das klassische Verhalten wieder her, ohne eigene
  Kategorien oder Merkungen zu löschen; „Lidl-Vorlage übernehmen“ (mit Rückfrage, nur ohne Gänge) setzt
  die Vorlage und legt die Gang-Namen, die keine festen Kategorien sind, als eigene Kategorien an,
  ohne Artikel zu ändern.
- **AC-15:** In Läden mit Gängen fehlt „Reihenfolge anpassen“ im Modus „Kategorie“ und ist im Modus
  „Einkaufsweg“ vorhanden; in Läden ohne Gänge unverändert.
- **AC-16:** Das neue Feld `stationConfigJSON` steht in der Feldliste von `MirroredSchemaSnapshotTests`
  (Store) und als `CD_stationConfigJSON STRING` in `docs/cloudkit/private-schema-aktuell.ckdb`; der
  Deploy-Pflichtpunkt steht in der Definition of Done.
- **AC-17:** Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und gleichen
  Platzhaltern (`LocalizationKeyParityTests` grün). Die Preisschätzung, Startseite und „Alle Artikel“
  bleiben unverändert (automatische Kategorie, feste Kategorien).

## Known Limitations

- **Geteilte Läden:** Die Gang-Konfiguration bleibt lokal (D3). Mitglieder sehen den Laden ohne Gänge;
  auf dem Gerät mit Gängen erscheinen sie in der Liste, aber nicht bei den Mitgliedern.
- **Einrichten nur über die Vorlage:** Es gibt in D1 keine Oberfläche zum Anlegen, Umbenennen, Ziehen
  oder Zuordnen von Gängen und festen Kategorien und kein Ausblenden (D2). Gang-Namen aus der Auswahl
  haben keine festen Kategorien und keine Stichwörter.
- **Wischaktionen** (Bearbeiten/Löschen) in der Auswahl entfallen für Läden mit Gängen (D2).
- **Eigene Kategorien aus #85**, die nicht zu den Gängen gehören, werden in Läden mit Gängen übergangen:
  Ihre Artikel werden über Namen und automatische Kategorie neu eingeordnet (oft „Sonstiges“). Das
  Überführen kommt mit D2.
- **Stichwort-Treffer sind Wortenden:** „Apfelsaft“ → frische Säfte; zusammengesetzte Wörter, die nicht auf
  ein Stichwort enden („Käsespätzle“), und Mehrzahlformen („Bratwürste“) treffen nicht; die feste Kategorie
  fängt sie meist auf. Nur einzelne Wörter, keine Wortgruppen.
- **Gang-Namen der Vorlage sind deutsch**, auch in der englischen Oberfläche.
- **Ziehen im Modus „Einkaufsweg“** über eine Gang-Grenze hinweg hat keine Wirkung (die Zeile springt
  zurück), weil der Gang zuerst sortiert.
- **Sonstiges-Marke bei Mitgliedern:** Die Marke steht in `categoryAssignments` und reist über das
  bestehende `assignmentsJSON` zu Mitgliedern geteilter Läden; dort ist sie wirkungslos (keine Kategorie,
  `rememberedCategory` gibt sie nie zurück) und wird nie angezeigt.
- Die Stichwortlisten sind handgepflegt und an der Sicht des PO auf Lidl ausgerichtet; Abweichungen
  korrigiert der Nutzer per Auswahl, der Laden merkt sie.
- Nichts auf Hennings Geräten geprüft; kein echter Abgleich mit CloudKit.

## Ausblick (nicht in diesem Durchgang)

- **D2:** Ansicht „Kategorien einrichten“ (ersetzt die beiden Zwischen-Menüeinträge): Gänge anlegen,
  umbenennen, ziehen; feste Kategorien je Gang zuordnen mit den drei Zuständen zugeordnet / ausgeblendet /
  offen; Stichwörter je Gang; Ausblenden (Oberfläche für `hidden`); Wischaktionen in der Auswahl;
  Überführung vorhandener eigener Kategorien; Gang umbenennen zieht Merkungen und `stations[].name` mit.
- **D3:** Abgleich geteilter Läden: neues optionales Feld `stationsJSON` im `SharedStore`-Record
  (`SharedStoreSchema.optionalExtensionFields`, Drift-Test in `SharedStoreSchemaTests` erweitern),
  Ganzstand mit Zeitstempel (`StationConfig.date`, der spätere gewinnt), `SyncCoordinator.apply`,
  `SharedStoreMergeTests`, Veröffentlichen des Schemas der öffentlichen Datenbank in Production vor dem
  Upload.

## Definition of Done

- [ ] Build erfolgreich, alle Unit- und UI-Tests grün (neue Tests waren vor der Umsetzung rot)
- [ ] Echter Durchlauf im Simulator mit Belegbildern registriert
- [ ] `CLAUDE.md` um den Absatz „Laden-Stationen“ ergänzt, Issue #234 aktualisiert
- [ ] Vor dem nächsten TestFlight-Upload: Development-Schema per Workflow eingespielt und Production
  im Dashboard deployt (Deploy-Pflicht)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Erweiterung des vorhandenen Musters „reine Logik in `StoreCategories`/`ShoppingRoute`,
  dünne Hülle in `Store`, additives Feld“ (#85/#94); keine neue Abhängigkeit, kein Modell, keine neue
  Schicht. Die Wahl „Regeln statt Sprachmodell“ folgt den Projektgrundsätzen und wird hier begründet,
  nicht als ADR geführt.

## Changelog

- 2026-10-30: Initial spec created (Issue #234, Durchgang 1).
- 2026-10-30: „Lebensmittel“ aus Gang 5 entfernt (Rückfallwert für Unerkanntes → Sonstiges), Texte der
  Rückfragen festgelegt, Grenze „Marke bei Mitgliedern“ ergänzt.
- 2026-10-30: AC-17 durch T18/T19 belegt, T3 Gang-Name ausgeschrieben, U3-Kennungen voll ausgeschrieben,
  Dateizählung korrigiert.
