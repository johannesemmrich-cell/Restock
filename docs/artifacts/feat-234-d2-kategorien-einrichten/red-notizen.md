# RED-Notizen Durchgang 2a (#234), 2026-10-31

Für `/50-implement`: Was die Tests als Vertrag festlegen, wo sie von der Spec abweichen, und der Umfang.

## RED-Belege

- `test-red-unit.txt`: `StoreStationsTests` übersetzt nicht, nur wegen fehlender API (`renameStation`,
  `categoryState`, `addingStation`, …) und zwei Folgefehlern (Zeilen 670, 800: Typ unbekannt).
- `test-red-ui.txt`: `StoreStationsUITests` in einer Wegwerf-Kopie mit altem Unit-Test (das Unit-Ziel baut sonst
  mit und scheitert): 14 Tests, 9 rot (V1–V8 und U8, alle an „Kategorien einrichten fehlt im Menü“), U1–U5 grün.
  Gerät `Restock-Validate-272` (iOS 27.2).

## Vertrag aus den Tests (wo die Spec offen oder uneinheitlich ist)

- `StoreCategories.movingStations(from: IndexSet, to: Int, in: StationConfig) -> StationConfig`
  (Spec nennt einmal `movingStations(_:from:to:in:)`, einmal `movingStations(_ config, from:, to:)`; gewählt
  ist die Form mit `in:` am Ende wie bei allen anderen Funktionen).
- `addingStation(_:emoji:to:)`, `renamingStation(_:to:emoji:in:)`, `assigning(_:toStation:in:)`, `hiding(_:in:)`,
  `opening(_:in:)`, `deletingStation(_:in:)` liefern `StationConfig?` (`nil` = abgelehnt; auch unbekannter Gang
  bei Umbenennen, Zuordnen-Ziel und Löschen).
- `categoryState(_:in:)` liefert ein `Equatable`-Enum mit `.assigned(String)`, `.hidden`, `.open`.
- `Store.renameStation(_:to:emoji:) -> String?`, `Store.deleteStation(_:)`, `Store.updateStationConfig(_:)`.
- UI-Kennungen zusätzlich zur Spec: Rückfrage „Gang löschen“ = `stationSetup.confirmDelete`; die Eingabe
  „Gang hinzufügen“ ist ein Alert mit Textfeld und Knopf „Hinzufügen“; Kategorie-Zeilen im Gang-Detail tragen
  bei Zuordnung zum offenen Gang die Eigenschaft „ausgewählt“ (`.isSelected`); der Knopf `stationSetup.sort`
  schaltet den Bearbeiten-Modus ein und wieder aus (gleiche Kennung). Zuordnen-Menü: Gang-Namen als Knöpfe
  plus „Ausblenden“. Abschnittsköpfe „Gänge · 12“, „Offen · 9“, „Ausgeblendet · 9“ (Vergleich ohne
  Groß-/Kleinschreibung).

## Abweichungen von der Spec

1. **S6, „Gouda → Sonstiges“:** Gouda hat die automatische Kategorie Milchprodukte; nach dem Löschen von „Käse“
   landet er folgerichtig im Gang Milchprodukte. Der Test prüft das (und dass das Stichwort nicht mehr greift).
2. **U8** (`testChoosingOtherNeverStoresMarkerAsCategory`) nutzte den entfallenden Menüeintrag „Gänge entfernen“.
   Nur dieser eine Schritt geht jetzt über „Kategorien einrichten“ (`removeStationsViaSetup`), Absicht unverändert.
   Die Spec nennt nur U6/U7 als geändert.
3. **T18** (`testStationStringsExistInBothLanguages`) erwartete die laut Spec gestrichenen D1-Schlüssel; sie sind
   aus der Erwartung genommen. S13 prüft, dass sie fehlen.

## Umfang

Die Tests allein haben +792 Zeilen (Unit +464, UI +358 inkl. Helfer, −30). Die Spec schätzte ~220 Testzeilen und
~640 gesamt (Grenze ~700). Hochrechnung mit Produktivcode (~390) und pbxproj: **etwa 1.190 neue Zeilen**.
Vor der Umsetzung beim PO gemeldet.
