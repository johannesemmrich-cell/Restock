# RED-Testvertrag D1 (#234) – Vorgaben aus den Tests für die Umsetzung

Die RED-Tests (`RestockTests/StoreStationsTests.swift`, 19 Tests; `RestockTests/ShoppingRouteTests.swift` +2 für T17;
`RestockTests/MirroredSchemaSnapshotTests.swift` T16; `RestockUITests/StoreStationsUITests.swift`, U1–U7) legen über die
Spec hinaus fest:

## API
- `Station(name:emoji:builtIns:keywords:)`, `StationConfig(stations:hidden:date:)` mit memberweisen Initialisierern; `StoreCategories.lidlTemplate: StationConfig`.
- `ShoppingRoute.SortInput.stationRank` als letztes Feld: `var stationRank: Int? = nil`.
- `Store.stationRank(of:) -> Int?`.
- `StoreCategories.StationResolution: Equatable` mit `.existing(String)`, `.other`, `.new(String)`, `.invalid`.
- `StoreCategories.resolveStation(_ input: String, config: StationConfig) -> StationResolution`: „Sonstiges“/„Other“ → `.other`; Marke oder leer → `.invalid`; Vergleich über `normalizedName`/`compareKey`.
- `Store.addStation(_ input: String) -> String?`: vorhandener Gang → dessen Name; Sonstiges → Marke; ungültig → `nil`; neuer Gang am Ende (vor Sonstiges) mit `suggestedEmoji`, leeren `builtIns`/`keywords`, zusätzlich als eigene Kategorie angelegt, außer der Name ist eine feste Kategorie.
- Gemerkte Namen werden über `compareKey` mit Gang-Namen verglichen.
- Stufe 4 der Auflösung nutzt `category(for: name)`; die gespeicherte Kategorie zählt nur bei `manuallySet == true`.
- Eingabe „Sonstiges“ in der Auswahl wählt Sonstiges (legt nie einen Gang an).

## Kennungen (UI)
- Menü: `store.menu.applyStationTemplate`, `store.menu.removeStations`; Bestätigen: `store.stations.confirmApply`, `store.stations.confirmRemove`.
- Auswahl: `categoryPicker.row.<Gang>`, `categoryPicker.row.other`; Anlegen-Zeile `categoryPicker.create`, Label enthält „Gang“.
- Kategorie-Modus: Überschrift „Sonstiges“ und Zeilen-Untertitel gleichen Texts; U1 unterscheidet über die Position.

## Seed `-seedStationStoreForUITests`
1. Alle Läden und Artikel löschen.
2. Laden „Stationsladen“, Emoji 🛒.
3. `applyStationConfig(StoreCategories.lidlTemplate)`.
4. Artikel mit `ShoppingItem(name:, category: AssignmentService.category(for:), store:)`, nicht manuell gesetzt; `addedDate` = jetzt − 3600 s + i·60 s in der Reihenfolge Batterien, Milch, Gouda, Salami, Apfel, Brot; nur Brot `isUrgent = true`.
5. `routeModel`/`currentTrip` leer, `sortMode = .route`, keine `categoryAssignments`; speichern.

`-clearStationStoreForUITests`: alle Läden und Artikel löschen (Muster wie der Aufräumer des Einkaufswegs).

## T18
`station.*`-Schlüssel (9) mit Platzhalterzahl 0/1/2 in beiden Tabellen; `station.other` = „Sonstiges“/„Other“, `station.menu.remove` = „Gänge entfernen“.
