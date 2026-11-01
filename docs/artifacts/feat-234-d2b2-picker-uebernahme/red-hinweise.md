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

## Festlegungen in Phase 6

1. **Abschnitt „Eigene Kategorien von früher“ steht direkt unter „Gänge“, vor „Offen“ und „Ausgeblendet“**
   (Tech Lead, 2026-11-01). Die Spec-Zeile sagt „nach `hiddenSection`“; maßgeblich ist der vom PO freigegebene
   Entwurf (`docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html`, Bildschirm „takeover“), der
   den Abschnitt direkt unter den Gängen zeigt. Grund zusätzlich: Auffindbarkeit. Im Altladen (zwei Gänge, „Offen · 33“)
   lag der Abschnitt am Ende einer langen Liste; Y8/Y9 scheiterten im ersten Grün-Lauf daran, dass die Übersicht nach
   dem Übernehmen nicht mehr bis „Gänge · N“ zurückrollte (UI-Hierarchie beim Fehlschlag: Gang-Zeilen unter der
   Navigationsleiste, Kopf nicht im Baum). Die Übernahme selbst war grün („· 2“, Abschnitt verschwand). Testdatei für
   Y8/Y9 unverändert.
2. **Y1: Gegenprobe „Sonstiges hat keine Wischaktionen“ ist der letzte Schritt** (Tech Lead, 2026-11-01, Testfehler).
   Ein Wisch auf eine Button-Zeile ohne Wischaktionen wählt sie (Bestandsverhalten, auch bei festen Kategorien in
   Läden ohne Gänge; nicht Gegenstand von AC-1). Beleg: Bildschirmaufnahme des ersten Grün-Laufs,
   `y1-wischen-sonstiges-frames.png` (Bild 4: Artikel-Dialog mit „Kategorie: Sonstiges“ nach dem Wisch; danach traf
   `pickerBack` „Abbrechen“, Bilder 5–7 Home-Bildschirm). Y1 prüft jetzt nach dem Sichern („Gouda unter Käse & Co“):
   Dialog erneut öffnen, Kategorie öffnen, auf „Sonstiges“ wischen, `categoryPicker.station.edit.Sonstiges` und
   `…delete.Sonstiges` fehlen; danach keine Navigation mehr. Andere Tests und Helfer unverändert.
3. **Adversary F002 (Nachziehen ohne eigene Wahl):** Nach Umbenennen/Löschen eines Gangs in der Auswahl zieht
   `CategoryPickerView` die Auswahl über `onFollow` nach, nicht über das Auswahl-Binding. Add: `chosenCategory`
   bleibt `nil`, wenn es `nil` war (`StoreCategories.followedChoice`); Edit: `categoryPicked` wird nie neu gesetzt,
   ohne eigene Wahl übernimmt der Dialog nur eine gespeicherte Handwahl aus `item.category` (von `renameStation`
   umgeschrieben). Neue Tests: P5 `testFollowedChoiceKeepsAutomatic`, Y10 `testPickerDeleteWithoutChoiceKeepsAutomatic`
   (sichtbarer Nachweis: Stichwort „gouda“ an „Kühltheke Fertiges“ zieht Gouda nur ohne Handwahl/Merkung um). RED:
   `test-red-f002-ui.txt` (Gouda blieb unter „Milchprodukte“), `test-red-f002-unit.txt` (Funktion fehlte).
4. **Adversary F001:** `StoreDetailView.onDisappear` überspringt den Push in DEBUG bei `-skipCloudKitForScreenshots`
   (wie der Pull); Y7 startet zusätzlich mit diesem Argument (Start in Y7 selbst gebaut, weil der gemeinsame Helfer
   nur ein Seed-Argument nimmt; Helfer unverändert).
5. **Adversary F003:** Die Ablehnungsmeldung im Editor verschwindet, sobald der Name geändert wird.
