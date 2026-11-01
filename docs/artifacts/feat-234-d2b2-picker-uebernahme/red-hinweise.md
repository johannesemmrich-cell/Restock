# RED-Hinweise für /50-implement (#234, Durchgang 2b-2)

Stand 2026-11-01, Phase 5.

## Festlegungen in den Tests (Spec-Widersprüche, technisch entschieden)

1. **Reihenfolge „von früher“ und „Alle übernehmen“ = alphabetisch** (`Store.customCategories`).
   Die Spec sagt „Reihenfolge der eigenen Kategorien“ (A4: Asia-Regal, Backstation, Vorrat = alphabetisch),
   zählt bei A6/Y8/Y9 aber „Asia-Regal, Wein, Backstation“ auf. Tests A6 und Y9 erwarten
   Asia-Regal, Backstation, Wein. Die reine Funktion `adoptableCategories(custom:…)` behält die
   Eingabereihenfolge (A1).
2. **`selectionAfterDeleting` bei Konfiguration ohne Gänge liefert `automaticCategory`** (P3), damit die
   Regel „letzter Gang gelöscht → automatische Kategorie“ ohne Sonderfall in der Ansicht prüfbar ist.
3. **Y5-Gegenprobe ist „Konserven“, nicht „Milchprodukte“**: Die Lidl-Vorlage hat einen Gang
   „Milchprodukte“, die Kategorie ist dort also selbst gebunden.
4. Signaturen aus den Tests: `StoreCategories.adoptableCategories(custom: [String], config: StationConfig,
   used: Set<String>, templateNames: Set<String>) -> [String]`, `templateStationNames: Set<String>`,
   `renamedSelection(_:from:to:) -> String`, `selectionAfterDeleting(itemName:automaticCategory:config:) -> String`,
   `Store.adoptableCategories: [String]`, `Store.adoptCategory(_:) -> String?` (`@discardableResult`),
   `Store.adoptAllCategories() -> [String]` (`@discardableResult`).

## UI-Kennungen, die die Tests erwarten

- Auswahl: `categoryPicker.station.edit.<Name>`, `categoryPicker.station.delete.<Name>`; Rückfrage-Knöpfe
  über ihren Text („Gang löschen“, „Gänge entfernen“), Titel als Text („Gang „Käse“ löschen?“, „Gänge entfernen?“).
- Editor im Gang-Modus: Navigationstitel „Kategorie bearbeiten“, Feld `categoryEditor.name`, Ablehnungstext
  „Diesen Namen gibt es schon oder er ist nicht erlaubt.“ als sichtbarer Text, Editor bleibt offen.
- Einrichtung: `stationSetup.adopt.section` (Label enthält „Eigene Kategorien von früher · N“),
  `stationSetup.adopt.all`, `stationSetup.adopt.row.<Name>`, `stationSetup.adopt.take.<Name>`,
  `stationSetup.emoji.<Emoji>` im `StationEmojiGrid`.
- Seeds: Laden „Altladen“ (Kachel-Label beginnt mit „Altladen,“, Artikel Apfel/Nudeln/Baguette),
  `-seedStationStoreSharedForUITests` mit Laden „Stationsladen“ (Artikel Salami).

## RED-Läufe

- Unit: `test-red-output.txt` (TEST BUILD FAILED, fehlende API).
- UI: In der Wegwerf-Kopie ohne die neuen Unit-Tests (das Schema baut das Unit-Ziel mit), iOS 27.2,
  `Restock-Validate-272`: 9 Tests, 8 rot aus dem erwarteten Grund, Y5 grün (Bestand). Y4 war ein
  Testfehler (Rollen nach dem Abbrechen öffnete einen Gang), nach Korrektur grün (`test-red-ui-y4-bestand.txt`).
- Kein Bestandstest geändert.
