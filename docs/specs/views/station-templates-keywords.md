---
entity_id: station-templates-keywords
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: feat-234-d2b-vorlagen-stichwoerter
tags: [feature, store, stations, settings-ui, templates, keywords]
---

# Laden-Stationen: Mustervorlagen, Stichwörter bearbeiten, Einzahl, Durchgang 2b-1 (Issue #234)

## Approval

- [ ] Approved

Offenlegung für die Freigabe:

1. **Zuschnitt (PO-Beschluss 2026-11-01).** Durchgang 2b ist in 2b-1 (diese Spec) und 2b-2 geteilt. 2b-1 hat
   rund 600 Zeilen in der Zählweise des Prüfwerkzeugs (alle neuen Zeilen inkl. Tests und Vorlagendaten), in
   8 Positionen (9 Dateien, die zwei Strings-Dateien zählen als ein Paar). Der PO hat ~540 akzeptiert; die
   Schätzung hier liegt etwas darüber, weil die vier Vorlagen als Daten allein etwa 110 Zeilen tragen. Das liegt
   über dem Korridor 250–350 und ist vom PO als Zuschnitt akzeptiert. Spielraum nach oben bis etwa 700, darüber
   hinaus meldet der Implementierer, bevor er weitermacht.
2. **Abweichung vom Entwurf, vom PO entschieden (2026-11-01):** Die Drogerie-Vorlage hat den Gang „Essen & Trinken“ (🌿) statt
   „Lebensmittel“ (🌿) wie in der Vorschau. Ein Gang, der „Lebensmittel“ heißt, trägt den Namen einer festen
   Kategorie und würde sie als Name-gebundene Kategorie (Spec 2a) an sich ziehen. „Lebensmittel“ ist aber der
   Rückfall für Unerkanntes und steht laut D1-Invariante in keinem Gang. Inhalt und Emoji des Gangs bleiben wie
   im Entwurf. Alle anderen Gang-Namen, Emojis und Kategorien stammen aus Abschnitt 2 der freigegebenen Vorschau.
3. **Die Stichwort-Spalten der Vorschau sind gekürzt (… am Ende).** Diese Spec legt die vollständigen Listen
   fest (Abschnitt „Inhalte der vier Vorlagen“). Sie enthalten alle in der Vorschau genannten Stichwörter und
   ergänzen sie um wenige gängige Wörter, jeweils innerhalb der Invarianten (≤ 15 je Gang).
4. **Ein bestehender Test wird bewusst geändert.** `testSetupStringsExistInBothLanguages` (S13) in
   `RestockTests/StoreStationsTests.swift` führt `station.setup.row.summary` und `station.setup.detail.keywords`
   in seiner festen Schlüsselliste. Beide entfallen bzw. ändern ihren Platzhalter; die Liste wird nachgezogen.
   `testTemplateIsConsistent` (T8) wird von der Lidl-Vorlage auf alle fünf Vorlagen verallgemeinert (gleiche
   Invarianten, mehr Eingaben). Alle anderen Tests bleiben unverändert und müssen grün bleiben.

## Purpose

Seit 2a kann ein Laden nur die Lidl-Vorlage wählen, und die Stichwörter eines Gangs lassen sich nur ansehen.
Diese Spec liefert vier weitere Mustervorlagen (Discounter, Vollsortimenter, Drogerie, Baumarkt), gewählt in
einem eigenen Blatt mit dem Hinweis „Vorschlag, bitte prüfen“, die Bearbeitung der Stichwörter je Gang (Wort
hinzufügen, per Wischen löschen, Hinweis bei gleichem Wort in einem anderen Gang) und die grammatisch richtige
Einzahl „1 Kategorie“ und „1 Stichwort“ in der Gang-Zeile. Wer einen Laden mit anderem Aufbau als Lidl hat,
bekommt damit einen brauchbaren Ausgangspunkt, und wer einen Artikel falsch einsortiert sieht, kann ihm per
Stichwort den richtigen Gang geben.

Datenmodell (`StationConfig`, `Station`), Auflösung Artikel → Gang und Sortierung stehen in
`docs/specs/models/store-stations.md` (D1), die Einrichtungsansicht in `docs/specs/views/station-setup.md` (2a).
Beides wird hier nicht wiederholt.

## Source

- **Neu:** `SmartCart/Models/StoreTemplates.swift` (die vier Vorlagen als Daten), `RestockUITests/StationSetupExtrasUITests.swift`
- **Erweitert:** `SmartCart/Models/StoreCategories.swift` (reine Stichwort-Funktionen),
  `SmartCart/Views/Store/StationSetupView.swift` (Vorlagen-Blatt, Stichwort-Abschnitt, Einzahl),
  `.github/workflows/ci.yml` (Teil D)
- **Identifier:** `StoreCategories.discounterTemplate`, `.fullRangeTemplate`, `.drugstoreTemplate`,
  `.hardwareTemplate`, `StoreCategories.allTemplates`, `StoreCategories.normalizedKeyword(_:)`,
  `StoreCategories.checkKeyword(_:inStation:config:)`, `StoreCategories.addingKeyword(_:toStation:in:)`,
  `StoreCategories.removingKeyword(_:fromStation:in:)`, `StationSetupRow.summaryText(categories:keywords:)`,
  `StationTemplateSheet`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| D1 (PR #240) und 2a (PR #243) | feature | gemergt; `StationConfig`, `lidlTemplate`, `StationSetupView`, `Store.applyStationConfig`, `Store.updateStationConfig` |
| `StoreCategories.stationForKeywords` (privat), `compareKey`, `normalizedName`, `emojiChoices`, `builtInCategory(named:)` | module | Auflösung nach Stichwort (Wort gleicht oder endet auf Stichwort, längstes gewinnt, bei Gleichstand früherer Gang), Namensvergleich, Emoji-Prüfung der Vorlagen |
| `AssignmentService.categoryOrder` | service | die 35 festen Kategorien (Rohwerte) als Quelle der `builtIns` und `hidden` der Vorlagen |
| `Store.applyStationConfig(_:)`, `Store.updateStationConfig(_:)` | model | Anwenden einer Vorlage (Zeitstempel jetzt, Gang-Namen als eigene Kategorien) bzw. Speichern einer Stichwortänderung (ein Schreibpunkt, `bumpRouteRevision`) |
| `menuplan.daysadded.*` (`MenuPlanView.swift`) | pattern | Vorbild für Einzahl/Mehrzahl über ein Schlüsselpaar `.one`/`.other` und Auswahl im Code per `count == 1` |
| `LocalizationKeyParityTests`, S13 | test | gleiche Schlüssel und Platzhalter de/en |
| `UITestLaunch`, `UITestWait`, Seed `-seedStationStoreForUITests`, Aufräumer `-clearStationStoreForUITests` | test helper | wiederverwendet, keine Änderung am Seed |
| `docs/context/gaenge-recherche-maerkte.md` | doc | Datenquelle der Vorlagen (Aldi Süd, Edeka/Kaufland, dm abgeleitet, Hornbach) |
| `docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html` | doc | freigegebener Entwurf 1, 3 und Inhalte (PO 2026-11-01) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreTemplates.swift` | CREATE | vier Vorlagen als `extension StoreCategories` plus `allTemplates` (~+130); in `project.pbxproj` nur im App-Ziel einzutragen, weil nur `StationSetupView` sie benutzt (der Implementierer prüft per Bau von Widget- und Teilen-Ziel, dass keine andere Stelle sie braucht) |
| `SmartCart/Models/StoreCategories.swift` | MODIFY | `normalizedKeyword`, `checkKeyword`, `addingKeyword`, `removingKeyword` (~+45) |
| `SmartCart/Views/Store/StationSetupView.swift` | MODIFY | Vorlagen-Blatt statt `confirmationDialog`, Rückfrage vor dem Ersetzen vorhandener Gänge, Stichwort-Abschnitt editierbar, `summaryText` mit Einzahl (~+110/−25) |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | Vorlagen-Namen, Badge, Stichwort-Texte und -Hinweise, `row.categories.*`, `row.keywords.*` (~+22 je Datei; `row.summary` und `detail.keywords` ersetzt) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | `StoreTemplates.swift` (App-Ziel) und `StationSetupExtrasUITests.swift` (UI-Test-Ziel) in PBXBuildFile, PBXFileReference, Gruppe, Sources-Phase |
| `RestockTests/StoreStationsTests.swift` | MODIFY | T8 verallgemeinert, Stichwort-Tests K1–K10, Einzahl K11, S13-Schlüsselliste (~+190) |
| `RestockUITests/StationSetupExtrasUITests.swift` | CREATE | neue Klasse mit X1–X3 (~+110) |
| `.github/workflows/ci.yml` | MODIFY | Matrix-Teil D mit `EXTRA_CLASSES`, B überspringt die Klasse (~+12) |

Nicht berührt: `SmartCartApp.swift` (die vorhandenen Seeds reichen: Lidl-Laden mit sechs Artikeln),
`CategoryPickerView.swift`, `Store.swift`, `ShoppingRoute.swift`, `SharedStoreService`/`SyncCoordinator`,
Schema. `CLAUDE.md` wird erst mit dem Abschluss ergänzt (Absatz „Laden-Stationen“ erweitern; Doku, keine eigene Position).

### Estimated Changes

- Files: 8 Positionen (9 Dateien)
- LoC (Gate-Zählweise: alle Additionen inkl. Tests): ca. +600 (Produktiv ~+310 inkl. Vorlagendaten und Strings,
  Tests ~+300, `project.pbxproj` +8, `ci.yml` +12); Löschungen ~−30 (Dialog, `row.summary`).
- Eigene Schätzung: 560–650, PO-Zusage ~540. Meldet der Implementierer mehr als 700, hält er an.

### Nicht in diesem Durchgang (2b-2)

Wischaktionen (Bearbeiten/Löschen) in der Kategorie-Auswahl (`CategoryPickerView`), Übernahme früherer eigener
Kategorien aus #85, und die vier in 2a vorgemerkten UI-Tests (Wisch-Löschen in der Übersicht, „gehört zu Gang …“,
Emoji-Auswahl, Hinweis bei geteilten Läden) samt Seeds `-seedLegacyCustomCategoriesForUITests` und
`-seedStationStoreSharedForUITests`. Nicht dabei: Abgleich der Gänge geteilter Läden (D3). Kein CloudKit-Schritt.

## Implementation Details

### Inhalte der vier Vorlagen (`StoreTemplates.swift`)

Reine Daten, Form wie `lidlTemplate` (`StationConfig` mit `date: Date(timeIntervalSince1970: 0)`;
`Store.applyStationConfig` setzt den Zeitstempel). Abkürzung „Drogerie-8“ = Körperpflege, Haarpflege, Zahnpflege,
Kosmetik, Hygieneartikel, Reinigung, Medikamente, Babybedarf. „Baumarkt-9“ = Werkzeug, Eisenwaren, Garten, Pflanzen,
Farbe & Lack, Sanitär, Boden & Fliesen, Holz, Baumaterial. „Lebensmittel“ steht in keinem Gang. Stichwörter sind
klein geschrieben, einzelne Wörter mit mindestens 3 Zeichen, höchstens 15 je Gang.

**`discounterTemplate`** (Muster Aldi Süd, 10 Gänge, `hidden` = Baumarkt-9):

| # | Gang | Emoji | `builtIns` | Stichwörter |
|---|------|-------|-----------|-------------|
| 1 | Obst & Gemüse | 🥦 | Obst & Gemüse | – |
| 2 | Fleisch & Fisch | 🥩 | Fleisch & Wurst | fisch, lachs, forelle, garnelen, hähnchen, bratwurst, hackfleisch, steak, schnitzel |
| 3 | Backstation | 🥖 | Backwaren | – |
| 4 | Wurst, Käse & Molkerei | 🧀 | Milchprodukte | käse, wurst, würstchen, salami, schinken, aufschnitt, gouda, mozzarella, eier, margarine |
| 5 | Kühlregal Fertiges | 🧊 | – | tofu, hummus, salatbox, dip, tzatziki, maultaschen, nudelsalat, kartoffelsalat |
| 6 | Trockensortiment | 🥫 | Konserven, Gewürze & Backen, Snacks | kaffee, tee, nudeln, reis, mehl, müsli, schokolade |
| 7 | Tiefkühl | ❄️ | Tiefkühlkost | pizza, pommes, fischstäbchen, eiscreme |
| 8 | Getränke | 🥤 | Getränke | – |
| 9 | Drogerie & Baby | 🧴 | Drogerie-8, Tierbedarf | – |
| 10 | Aktionsware | 🛒 | Haushaltswaren, Küchenausstattung, Elektronik, Textilien, Schreibwaren, Spielzeug, Dekoration | – |

**`fullRangeTemplate`** (Muster Edeka/Kaufland, 12 Gänge, `hidden` = Baumarkt-9):

| # | Gang | Emoji | `builtIns` | Stichwörter |
|---|------|-------|-----------|-------------|
| 1 | Obst & Gemüse | 🥦 | Obst & Gemüse | – |
| 2 | Backwaren | 🥖 | Backwaren | – |
| 3 | Fleisch, Wurst & Fisch | 🥩 | Fleisch & Wurst | fisch, lachs, forelle, garnelen, hähnchen, hackfleisch, steak, schnitzel |
| 4 | Käse | 🧀 | – | käse, gouda, edamer, emmentaler, mozzarella, feta, parmesan, camembert, brie, gorgonzola |
| 5 | Molkerei & Kühlung | 🥛 | Milchprodukte | eier, margarine, tofu, hummus, tzatziki, dip |
| 6 | Konserven & Nährmittel | 🥫 | Konserven, Gewürze & Backen | nudeln, reis, mehl, müsli, haferflocken |
| 7 | Süßwaren & Snacks | 🍫 | Snacks | kaffee, tee, schokolade, kekse, gummibärchen |
| 8 | Tiefkühl | ❄️ | Tiefkühlkost | pizza, pommes, fischstäbchen, eiscreme |
| 9 | Drogerie & Haushalt | 🧴 | Drogerie-8, Haushaltswaren, Küchenausstattung | – |
| 10 | Tierbedarf | 🐾 | Tierbedarf | – |
| 11 | Non-Food | 🛒 | Elektronik, Textilien, Schreibwaren, Spielzeug, Dekoration | – |
| 12 | Getränke | 🥤 | Getränke | – |

**`drugstoreTemplate`** (Muster dm, abgeleitet, 11 Gänge, `hidden` leer):

| # | Gang | Emoji | `builtIns` | Stichwörter |
|---|------|-------|-----------|-------------|
| 1 | Kosmetik | 💄 | Kosmetik | – |
| 2 | Haarpflege | 💇 | Haarpflege | – |
| 3 | Körperpflege | 🧴 | Körperpflege | – |
| 4 | Zahnpflege | 🦷 | Zahnpflege | – |
| 5 | Gesundheit | 💊 | Medikamente | – |
| 6 | Hygiene | 🧻 | Hygieneartikel | – |
| 7 | Baby | 👶 | Babybedarf | – |
| 8 | Haushalt & Reinigung | 🧼 | Reinigung, Haushaltswaren, Küchenausstattung | – |
| 9 | Tierbedarf | 🐾 | Tierbedarf | – |
| 10 | Essen & Trinken | 🌿 | Snacks, Getränke, Konserven, Gewürze & Backen | kaffee, tee |
| 11 | Kasse & Geschenke | 🛒 | Schreibwaren, Spielzeug, Dekoration, Elektronik, Textilien | – |

**`hardwareTemplate`** (Muster Hornbach, 8 Gänge, `hidden` leer):

| # | Gang | Emoji | `builtIns` | Stichwörter |
|---|------|-------|-----------|-------------|
| 1 | Garten & Pflanzen | 🌷 | Garten, Pflanzen | – |
| 2 | Deko & Leuchten | 💡 | Dekoration | lampe, leuchte, glühbirne |
| 3 | Bad & Sanitär | 🚿 | Sanitär | – |
| 4 | Fliesen & Boden | 🧱 | Boden & Fliesen | – |
| 5 | Farben & Tapeten | 🎨 | Farbe & Lack | tapete, pinsel |
| 6 | Werkzeug & Maschinen | 🔧 | Werkzeug | hammer, bohrer, säge |
| 7 | Eisenwaren & Befestigung | 🔩 | Eisenwaren | dübel, schraube, nagel, haken |
| 8 | Holz & Baustoffe | 🪵 | Holz, Baumaterial | – |

Gang-Namen, die zugleich eine feste Kategorie benennen (Vollsortimenter „Backwaren“, „Tierbedarf“, „Getränke“,
„Obst & Gemüse“; Drogerie „Kosmetik“, „Haarpflege“, „Körperpflege“, „Zahnpflege“, „Tierbedarf“; Discounter
„Getränke“, „Obst & Gemüse“) tragen diese Kategorie in ihren `builtIns` (Invariante der Name-gebundenen
Kategorien aus 2a). `StoreCategories.allTemplates` ist die geordnete Liste `[(id, template)]` für das Blatt mit den
Kennungen `lidl`, `discounter`, `fullRange`, `drugstore`, `hardware` (Reihenfolge wie im Entwurf: Lidl zuerst,
dann Discounter, Vollsortimenter, Drogerie, Baumarkt). Lidl bleibt in `StoreCategories.swift` unverändert.

Alle Emojis der Tabellen stehen in `StoreCategories.emojiChoices`. Die Blatt-Symbole 🏷️ (Discounter, Lidl),
🏬 (Vollsortimenter), 🧴 (Drogerie), 🔨 (Baumarkt) sind nur Anzeige im Blatt und gehören keiner Vorlage.

### Vorlagen-Blatt (`StationTemplateSheet`)

- „Vorlage wählen …“ (`station.setup.template`) öffnet statt des `confirmationDialog` aus 2a ein Sheet mit
  `NavigationStack`, Titel „Vorlage wählen“, links „Abbrechen“ (`stationSetup.template.cancel`). Oben eine Zeile
  mit der bisherigen Meldung („Ersetzt die Gänge dieses Ladens. Gemerkte Zuordnungen und eigene Kategorien
  bleiben.“).
- Eine Zeile je Vorlage (fünf): Blatt-Symbol, Name, Untertitel „N Gänge“ (`station.setup.template.count`), bei den
  vier Mustern das Kennzeichen „Vorschlag, bitte prüfen“ (`station.setup.template.hint`, Badge). Lidl trägt kein
  Kennzeichen. Kennungen: `stationSetup.templateLidl` (unverändert, damit der Bestandstest V8 gültig bleibt),
  `stationSetup.templateDiscounter`, `stationSetup.templateFullRange`, `stationSetup.templateDrugstore`,
  `stationSetup.templateHardware`.
- Tipp auf eine Zeile: Hat der Laden **keine Gänge**, wird die Vorlage sofort angewendet
  (`applyStationConfig`) und das Blatt geschlossen. Hat er **Gänge**, fragt zuvor ein `confirmationDialog`
  „Vorhandene Gänge ersetzen?“ (`station.setup.template.replace.title`, Meldung wie oben, Knopf „Ersetzen“,
  Kennung `stationSetup.templateReplace`); Abbrechen lässt alles unverändert. Die Rückfrage ist neu gegenüber 2a
  (dort war der Dialog selbst die Rückfrage); der Nutzer sieht damit nur dann einen Bestätigungsschritt mehr,
  wenn Gänge da sind.
- Artikel, Merkungen und vorhandene eigene Kategorien bleiben unberührt (`applyStationConfig`, S12 aus 2a).
  Merkungen auf Gang-Namen, die die neue Vorlage nicht kennt, wirken nicht mehr und bleiben gespeichert.

### Reine Funktionen für Stichwörter (`StoreCategories`)

Wertsemantik wie in 2a: `nil` = abgelehnt, nichts ändern. Der Zeitstempel wird nicht hier, sondern in
`Store.updateStationConfig` gesetzt.

- `normalizedKeyword(_ input: String) -> String?`: Zeichen am Anfang und Ende (Leerzeichen, Zeilenumbruch) weg,
  klein schreiben. `nil`, wenn das Ergebnis leer ist, kürzer als 3 Zeichen ist, ein Leerzeichen (auch innen)
  enthält oder ein Zeichen enthält, das kein Buchstabe und keine Ziffer ist (Bindestrich, Punkt, Marke u. a.).
  Begründung: `stationForKeywords` zerlegt den Artikelnamen an allem, was kein Buchstabe oder keine Ziffer ist,
  in Wörter; ein Stichwort mit Trenner könnte nie ein Wort treffen.
- `checkKeyword(_ input: String, inStation name: String, config:) -> KeywordCheck`:
  `.invalid` (Eingabe verletzt `normalizedKeyword` oder der Gang existiert nicht), `.duplicate` (im selben Gang
  schon vorhanden, Vergleich über `compareKey` der kleingeschriebenen Form), sonst `.accepted(others: [String])`
  mit den Namen **anderer** Gänge (in Gang-Reihenfolge), die dasselbe Stichwort schon führen.
- `addingKeyword(_ input: String, toStation name: String, in config:) -> StationConfig?`: `.accepted` →
  normalisiertes Stichwort wird am Ende der `keywords` des Gangs angehängt; `.invalid` und `.duplicate` → `nil`.
  Ein Stichwort in einem anderen Gang blockiert **nicht**.
- `removingKeyword(_ keyword: String, fromStation name: String, in config:) -> StationConfig?`: entfernt genau
  dieses Stichwort (Vergleich über `compareKey`); `nil`, wenn Gang oder Stichwort nicht vorkommt.
- Keine Obergrenze für Nutzer. Die Grenze „höchstens 15 Stichwörter“ gilt nur als Invariante der mitgelieferten
  Vorlagen (K8).

Auflösung bei gleichem Stichwort in mehreren Gängen ist unverändert die D1-Regel: längstes Stichwort gewinnt, bei
Gleichstand (also immer bei demselben Wort) der frühere Gang. Der Hinweis bei der Eingabe sagt deshalb „Der Gang
weiter oben in der Liste gewinnt“. Das Ändern der Reihenfolge der Gänge ändert, wer gewinnt.

### Stichwort-Abschnitt im Gang-Detail (`StationDetailView`)

Ersetzt den Abschnitt „Stichwörter (nur Anzeige)“:

- Kopf „Stichwörter · N“ (`station.setup.detail.keywords`, Platzhalter `%d`). Eine Zeile je Stichwort in
  gespeicherter Reihenfolge (Kennung `stationSetup.keyword.row.<wort>`); Wischen nach links zeigt „Löschen“
  (`stationSetup.keyword.delete.<wort>`), Wirkung `removingKeyword` + `store.updateStationConfig` + `save()`.
  Keine Rückfrage (ein Stichwort ist schnell wieder angelegt). Ohne Stichwörter steht „noch leer“
  (`station.setup.row.empty`).
- Darunter ein Textfeld „Stichwort hinzufügen“ (`stationSetup.keyword.field`, Autokorrektur und automatische
  Großschreibung aus) mit Knopf „Hinzufügen“ (`stationSetup.keyword.add`) und `onSubmit` mit gleicher Wirkung:
  - `.accepted(others: [])` → speichern, Feld leeren.
  - `.accepted(others: [...])` → speichern, Feld leeren, **Hinweiszeile** (`stationSetup.keyword.notice`):
    „„<Wort>“ steht auch in „<Gang>“. Der Gang weiter oben in der Liste gewinnt.“ Bei mehreren anderen Gängen
    werden ihre Namen mit Komma verbunden. Der Hinweis bleibt, bis das Feld erneut bearbeitet oder die Ansicht
    verlassen wird.
  - `.duplicate` → nichts speichern, Feld behalten, rote Hinweiszeile „„<Wort>“ steht hier schon.“
  - `.invalid` → nichts speichern, Feld behalten, rote Hinweiszeile „Ein Stichwort ist ein einzelnes Wort mit
    mindestens 3 Buchstaben.“ (`stationSetup.keyword.invalid`).
- Die Liste der Kategorien, Name, Emoji und „Gang löschen“ sind unverändert.
- Wirkung auf die Ladenliste: `updateStationConfig` erhöht die Weg-Version; die Liste zeichnet über den vorhandenen
  `onChange`-Zähler neu. Ein neues Stichwort sortiert Artikel um, die weder gemerkt (`categoryAssignments`) noch von
  Hand kategorisiert sind; Merkung und Handwahl gewinnen weiterhin davor (D1-Reihenfolge).

### Einzahl und Mehrzahl

- `station.setup.row.summary` entfällt. Neue Schlüsselpaare `station.setup.row.categories.one` („1 Kategorie“ /
  „1 category“) und `.other` („%d Kategorien“ / „%d categories“) sowie `station.setup.row.keywords.one`
  („1 Stichwort“ / „1 keyword“) und `.other` („%d Stichwörter“ / „%d keywords“). Auswahl per `count == 1`
  (Muster `menuplan.daysadded.*`).
- `StationSetupRow.summaryText(categories:keywords:)` (statisch, rein) verbindet beide Teile mit „ · “; sind beide
  Zahlen 0, liefert die Zeile weiter „noch leer“.

### Lokalisierung (de + en, `LocalizationKeyParityTests`)

Neue Schlüssel (de / en; Platzhalter je Schlüssel gleich):

`station.setup.template.discounter` („Discounter“ / „Discounter“), `station.setup.template.fullrange`
(„Vollsortimenter“ / „Full-range supermarket“), `station.setup.template.drugstore` („Drogerie“ / „Drugstore“),
`station.setup.template.hardware` („Baumarkt“ / „Hardware store“), `station.setup.template.count` („%d Gänge“ /
„%d aisles“), `station.setup.template.hint` („Vorschlag, bitte prüfen“ / „Suggestion, please review“),
`station.setup.template.cancel` („Abbrechen“ / „Cancel“), `station.setup.template.replace.title`
(„Vorhandene Gänge ersetzen?“ / „Replace existing aisles?“), `station.setup.template.replace.confirm`
(„Ersetzen“ / „Replace“), `station.setup.detail.keywords` (geändert: „Stichwörter · %d“ / „Keywords · %d“,
ein Platzhalter), `station.setup.keyword.placeholder` („Stichwort hinzufügen“ / „Add keyword“),
`station.setup.keyword.add` („Hinzufügen“ / „Add“), `station.setup.keyword.delete` („Löschen“ / „Delete“),
`station.setup.keyword.notice` („„%@“ steht auch in „%@“. Der Gang weiter oben in der Liste gewinnt.“ /
„“%@” is also in “%@”. The aisle higher up in the list wins.“, zwei Platzhalter),
`station.setup.keyword.duplicate` („„%@“ steht hier schon.“ / „“%@” is already here.“),
`station.setup.keyword.invalid` („Ein Stichwort ist ein einzelnes Wort mit mindestens 3 Buchstaben.“ / „A keyword
is a single word with at least 3 letters.“), `station.setup.row.categories.one/.other`,
`station.setup.row.keywords.one/.other` (siehe oben). Gestrichen: `station.setup.row.summary`. Gang-Namen der
Vorlagen bleiben deutsch auch in der englischen Oberfläche (bekannte Grenze seit D1).

### CI-Teil D

`StationSetupExtrasUITests` kommt in eine eigene Gruppe, damit Teil C (`StoreStationsUITests`, ~49 von 60 min) nicht
über das Limit wächst. In `ci.yml`: Matrix `half: [A, B, C, D]`, `EXTRA_CLASSES: "StationSetupExtrasUITests"`; Teil D
wählt nur diese Klassen (wie C mit `SOLO_CLASSES`); Teil B überspringt `EXTRA_CLASSES` zusätzlich zu `HEAVY_CLASSES`
und `SOLO_CLASSES`; A und C bleiben unverändert. Strukturtests unter `scripts/` werden bei Bedarf auf vier Teile
nachgezogen (der Implementierer sucht per `grep` nach `SOLO_CLASSES`/`half:`; beim Schreiben dieser Spec gab es in
`scripts/*.py` keine Treffer).

### Kein neues Feld, kein Schema-Schritt

Alles liegt in `stationConfigJSON` (D1). Keine Änderung an `@Model`, `@AppStorage`-Schlüsseln oder
`docs/cloudkit/private-schema-aktuell.ckdb`; `MirroredSchemaSnapshotTests` bleiben unverändert. Kein CloudKit-Deploy.

## Test Plan

Alle Tests werden vor der Umsetzung geschrieben (TDD RED: die Unit-Tests übersetzen nicht, solange API und
Vorlagen fehlen; die UI-Tests scheitern, solange Blatt und Stichwort-Feld fehlen). In-Memory-Container immer mit
`cloudKitDatabase: .none`; jeder angelegte Laden räumt seine App-Gruppen-Schlüssel in `tearDown` (`removeRouteData`).

### Automated Tests (TDD RED)

Unit, `RestockTests/StoreStationsTests.swift` (neuer Abschnitt „D2b-1“):

- [ ] K1 `testNormalizedKeyword`: GIVEN Eingaben WHEN `normalizedKeyword` THEN „  Käse “ → „käse“, „GOUDA“ → „gouda“, „ab“ → `nil`, „kein käse“ → `nil`, „bio-käse“ → `nil`, „“ → `nil`, „   “ → `nil`, „käse2“ → „käse2“ (AC-6)
- [ ] K2 `testAddingKeywordAppendsNormalized`: GIVEN `lidlTemplate` WHEN `addingKeyword(" BERGKÄSE ", toStation: "Käse")` THEN `keywords` des Gangs endet auf „bergkäse“, alle anderen Gänge, `hidden` und `builtIns` unverändert (AC-7)
- [ ] K3 `testDuplicateKeywordInSameStationRejected`: GIVEN Lidl-Vorlage WHEN `addingKeyword("KÄSE", toStation: "Käse")` und `addingKeyword("gouda ", toStation: "Käse")` THEN je `nil`, `checkKeyword` liefert `.duplicate`; `addingKeyword("ab", …)` liefert `nil`, `checkKeyword` `.invalid` (AC-8)
- [ ] K4 `testSameKeywordInOtherStationAcceptedWithHint`: GIVEN Lidl-Vorlage WHEN `checkKeyword("wurst", inStation: "Käse")` THEN `.accepted(others: ["Kühltheke Fertiges"])`, `addingKeyword` liefert eine Konfiguration; WHEN der Artikel „Wurst“ aufgelöst wird THEN gewinnt der frühere Gang („Kühltheke Fertiges“ steht vor „Käse“); WHEN „Bratwurst“ (längeres Stichwort „bratwurst“ in „Frisches Fleisch & Fisch“) THEN dieser Gang; WHEN dasselbe Stichwort in zwei Gängen steht und die Gänge per `movingStations` getauscht werden THEN gewinnt der nun frühere (AC-9)
- [ ] K5 `testRemovingKeyword`: GIVEN Lidl-Vorlage WHEN `removingKeyword("GOUDA", fromStation: "Käse")` THEN „gouda“ fehlt, die übrigen Stichwörter des Gangs in gleicher Reihenfolge; WHEN unbekanntes Stichwort oder unbekannter Gang THEN `nil` (AC-10)
- [ ] K6 `testKeywordMovesItemBetweenStations`: GIVEN Lidl-Vorlage, Artikel „Batterien“ (nicht gemerkt, nicht von Hand) steht in „Sonstiges“ WHEN `addingKeyword("batterien", toStation: "Drogerie")` THEN `station(forItemNamed:…)` ergibt „Drogerie“; WHEN `removingKeyword` THEN wieder `nil`; GIVEN Artikel mit Merkung auf „Käse“ WHEN Stichwort für „Drogerie“ THEN Merkung gewinnt (AC-11)
- [ ] K7 `testKeywordSaveUsesUpdateStationConfig`: GIVEN `Store` mit Lidl-Vorlage (In-Memory) WHEN Stichwort per `addingKeyword` + `updateStationConfig` THEN `stationConfig` enthält es nach erneutem Dekodieren, `date` ist jetzt, die Weg-Version ist erhöht, der `ShoppingRoute`-Rang des Artikels folgt dem neuen Gang (AC-7, AC-11)
- [ ] K8 `testAllTemplatesSatisfyInvariants` (verallgemeinert T8): GIVEN `StoreCategories.allTemplates` (Lidl, Discounter, Vollsortimenter, Drogerie, Baumarkt) WHEN je Vorlage geprüft THEN Gang-Zahl 12, 10, 12, 11, 8; Namen eindeutig über `compareKey` und nie „Sonstiges“/„Other“; jede `builtIns`- und `hidden`-Angabe steht in `categoryOrder`; keine Kategorie in zwei Gängen; `hidden` ∩ `builtIns` leer; „Lebensmittel“ in keinem Gang und nicht in `hidden`; jede Kategorie, deren Name ein Gang trägt, steht in dessen `builtIns`; `hidden` hat 9 Einträge bei Lidl, Discounter und Vollsortimenter und 0 bei Drogerie und Baumarkt; jedes Emoji ∈ `emojiChoices`; je Gang höchstens 15 Stichwörter, jedes unverändert gleich `normalizedKeyword(…)` und innerhalb des Gangs eindeutig (AC-1, AC-3)
- [ ] K9 `testTemplateSamples`: GIVEN die vier neuen Vorlagen WHEN Beispielartikel aufgelöst werden THEN Discounter: „Salami“ → „Wurst, Käse & Molkerei“, „Bratwurst“ → „Fleisch & Fisch“, „Zahnpasta“ → „Drogerie & Baby“; Vollsortimenter: „Gouda“ → „Käse“, „Zahnpasta“ → „Drogerie & Haushalt“; Drogerie: „Zahnpasta“ → „Zahnpflege“; Baumarkt: „Hammer“ → „Werkzeug & Maschinen“, „Tapete“ → „Farben & Tapeten“. Ergibt die Warenkunde für einen Beispielartikel eine andere Kategorie, wählt der Implementierer einen anderen Artikel derselben Kategorie und vermerkt das im Test, ändert aber nie die Vorlage zur Anpassung des Tests (AC-4)
- [ ] K10 `testApplyEveryTemplateKeepsAssignments`: GIVEN Laden mit selbst angelegtem Gang „Lager“, Merkung und eigener Kategorie WHEN `applyStationConfig(template)` für jede der fünf Vorlagen THEN genau die Gänge der Vorlage, „Lager“ fehlt unter den Gängen, Merkung und eigene Kategorie „Lager“ bleiben, die Gang-Namen sind eigene Kategorien (sofern keine feste Kategorie), `date` ist jetzt (AC-5)
- [ ] K11 `testSummaryTextUsesSingular`: GIVEN `StationSetupRow.summaryText` WHEN (1, 1), (2, 3), (1, 0), (0, 1), (0, 0) THEN „1 Kategorie · 1 Stichwort“, „2 Kategorien · 3 Stichwörter“, „1 Kategorie · 0 Stichwörter“, „0 Kategorien · 1 Stichwort“, „noch leer“ (deutsche Tabelle) (AC-12)
- [ ] S13 angepasst `testSetupStringsExistInBothLanguages`: feste Schlüsselliste ohne `row.summary`, mit allen neuen Schlüsseln und ihrer Platzhalterzahl (`detail.keywords` 1, `keyword.notice` 2, `keyword.duplicate` 1, `row.categories.other` 1, `row.keywords.other` 1, `template.count` 1, übrige 0), de und en vorhanden, nicht leer; `LocalizationKeyParityTests` bleibt grün (AC-13)

UI, `RestockUITests/StationSetupExtrasUITests.swift` (Start über `UITestLaunch.start` mit `-hasCompletedOnboarding YES
-seedStationStoreForUITests`, `tearDown` räumt mit `-clearStationStoreForUITests`; nie `-developerMode`). Der Seed hat
die Lidl-Vorlage und sechs Artikel: Batterien (Sonstiges), Milch, Gouda, Salami, Apfel, Brot (dringend). Geprüft
wird der Nutzen (Abschnitt in der Liste, Modus Kategorie), nicht nur das Vorhandensein:

- [ ] X1 `testChooseDiscounterTemplateReplacesStations` (AC-1, AC-2, AC-5): GIVEN Seed (Gänge vorhanden) WHEN „Kategorien einrichten“ → „Vorlage wählen …“ THEN das Blatt zeigt fünf Zeilen, die vier Muster tragen „Vorschlag, bitte prüfen“, Lidl nicht; WHEN „Discounter“ tippen THEN die Rückfrage „Vorhandene Gänge ersetzen?“ erscheint, und nach Abbrechen sind die Lidl-Gänge unverändert; WHEN erneut „Discounter“ + „Ersetzen“ THEN die Übersicht zeigt „Gänge · 10“ mit „Backstation“, und nach Fertig steht „Salami“ in der Liste (Modus Kategorie) im Abschnitt „Wurst, Käse & Molkerei“, vorher unter „Kühltheke Fertiges“
- [ ] X2 `testAddKeywordMovesItemIntoStation` (AC-6, AC-7, AC-8, AC-9, AC-11): GIVEN Seed WHEN Gang „Drogerie“ → Stichwort „ Batterien “ (mit Großbuchstaben und Leerzeichen eingegeben) hinzufügen THEN die Zeile `stationSetup.keyword.row.batterien` steht da und das Feld ist leer; WHEN dasselbe Stichwort erneut THEN die rote Zeile „steht hier schon“ und nichts verdoppelt sich; WHEN „ab“ THEN die Zeile zum Mindestumfang; WHEN „wurst“ im Gang „Käse“ THEN die Hinweiszeile nennt „Kühltheke Fertiges“ und das Stichwort ist gespeichert; nach Fertig steht „Batterien“ im Abschnitt „Drogerie“ und der Abschnitt „Sonstiges“ ist nicht mehr da
- [ ] X3 `testDeleteKeywordMovesItemOut` (AC-10, AC-11): GIVEN Seed, „Gouda“ liegt im Abschnitt „Käse“ WHEN Gang „Käse“ → Stichwort „gouda“ per Wischen löschen THEN die Zeile verschwindet; nach Fertig steht „Gouda“ nicht mehr im Abschnitt „Käse“ (er fällt auf seine automatische Kategorie, vermutlich „Milchprodukte“; geprüft wird nur: nicht mehr in „Käse“, noch in der Liste vorhanden); Wiedereinfügen des Stichworts holt ihn zurück

Die Einzahl (AC-12) ist per Unit-Test K11 belegt; die Gang-Zeile hat keinen eigenen UI-Test (Known Limitations).

Bestehende Tests (D1: T1–T19 außer T8, U1–U5, U8; 2a: S1–S17, V1–V10) laufen unverändert und müssen grün
bleiben. V-Tests, die Zeilentext „N Kategorien“ lesen, werden angepasst, falls sie an „1 Kategorien“ gebunden waren
(der Implementierer sucht per `grep`; Einzahl ändert nur Zeilen mit genau 1).

Durchlauf (Pflicht, Simulator, Stand dieser Änderung, als Nutzer): Laden ohne Gänge → „Kategorien einrichten“ →
„Vorlage wählen …“ → je eine der fünf Vorlagen, Gänge ansehen, Artikel hinzufügen und beide Sortiermodi prüfen;
im Gang ein Stichwort hinzufügen (Duplikat, anderer Gang, zu kurz) und per Wischen löschen; Bildschirmfotos unter
`docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/`. Nichts auf Hennings Geräten ohne sein ausdrückliches Wort.

## Acceptance Criteria

- **AC-1:** „Vorlage wählen …“ öffnet ein Blatt mit fünf Vorlagen: Lidl und die vier Muster Discounter,
  Vollsortimenter, Drogerie, Baumarkt (Name, „N Gänge“); die vier Muster tragen sichtbar „Vorschlag, bitte
  prüfen“, Lidl nicht. (X1, K8)
- **AC-2:** Eine gewählte Vorlage ersetzt die Gänge des Ladens: sofort, wenn der Laden keine Gänge hat; nach
  einer Rückfrage „Vorhandene Gänge ersetzen?“, wenn er welche hat; Abbrechen ändert nichts. (X1)
- **AC-3:** Jede der fünf Vorlagen erfüllt die Invarianten: Gang-Zahl 12/10/12/11/8, Gang-Namen eindeutig und nie
  „Sonstiges“, alle Kategorien gültig, „Lebensmittel“ in keinem Gang und nicht ausgeblendet, keine Kategorie in
  zwei Gängen, Name-gebundene Kategorien im eigenen Gang, Emoji aus der Auswahl, höchstens 15 Stichwörter je Gang,
  jedes Stichwort normalisiert und im Gang eindeutig. Baumarkt-Kategorien sind in Lidl, Discounter und
  Vollsortimenter ausgeblendet, in Drogerie und Baumarkt nicht. (K8)
- **AC-4:** Die Vorlagen sortieren Beispielartikel in den erwarteten Gang (Salami, Bratwurst, Zahnpasta, Gouda,
  Hammer, Tapete). (K9)
- **AC-5:** Das Anwenden einer Vorlage lässt Artikel, Merkungen und vorhandene eigene Kategorien unberührt und
  legt Gang-Namen (außer festen Kategorien) als eigene Kategorien an; der Zeitstempel ist jetzt. (K10, X1)
- **AC-6:** Ein Stichwort wird beim Hinzufügen getrimmt und klein geschrieben; es muss ein einzelnes Wort aus
  Buchstaben und Ziffern mit mindestens 3 Zeichen sein, sonst wird es abgelehnt (nichts gespeichert, Hinweis
  sichtbar). (K1, X2)
- **AC-7:** Ein gültiges Stichwort wird am Ende der Stichwörter des Gangs gespeichert (über
  `store.updateStationConfig`, `date` jetzt, Weg-Version erhöht); für Nutzer gibt es keine Obergrenze. (K2, K7, X2)
- **AC-8:** Ein Stichwort, das im selben Gang schon steht (Vergleich ohne Groß-/Kleinschreibung), wird abgelehnt
  mit dem Hinweis „steht hier schon“; nichts ändert sich. (K3, X2)
- **AC-9:** Steht dasselbe Stichwort schon in einem anderen Gang, wird es angenommen; der Hinweis nennt die
  anderen Gänge und „Der Gang weiter oben in der Liste gewinnt“. Die Auflösung folgt unverändert der D1-Regel
  (längstes Stichwort, bei Gleichstand der frühere Gang). (K4, X2)
- **AC-10:** Ein Stichwort lässt sich per Wischen (nach links, „Löschen“) ohne Rückfrage entfernen; die Reihenfolge
  der übrigen bleibt. (K5, X3)
- **AC-11:** Hinzufügen und Entfernen wirken sofort auf die Ladenliste: ein Artikel ohne Merkung und ohne
  Handwahl wechselt in den Gang des Stichworts bzw. zurück; Merkung und Handwahl gewinnen weiter davor. (K6, K7,
  X2, X3)
- **AC-12:** Die Gang-Zeile zeigt „1 Kategorie“ und „1 Stichwort“ in der Einzahl, sonst Mehrzahl, „noch leer“ bei
  0 und 0; beides in Deutsch und Englisch. (K11)
- **AC-13:** Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern
  (`LocalizationKeyParityTests` und S13 grün). (S13)
- **AC-14:** Die neue UI-Testklasse läuft in einem eigenen CI-Teil D; Teil B überspringt sie, A und C bleiben
  unverändert. Kein neues `@Model`-Feld, kein neuer `@AppStorage`-Schlüssel, keine Schemaänderung; Läden ohne
  Gänge verhalten sich unverändert; alle Bestandstests bleiben grün (außer den in der Offenlegung genannten
  angepassten S13/T8). (Gesamtlauf, CI)

## Known Limitations

- **Drogerie-Vorlage ist nur abgeleitet** (Beschreibungen von dm, nicht belegt; `gaenge-recherche-maerkte.md`). Das
  Kennzeichen „Vorschlag, bitte prüfen“ ist deshalb Pflicht. Auch Discounter (Aldi Süd), Vollsortimenter
  (Edeka/Kaufland) und Baumarkt (Hornbach) belegen nur die grobe Reihenfolge; die Stichwörter sind gewählt, nicht
  gemessen, und die Gang-Folge einzelner Märkte weicht ab. Der Nutzer passt an.
- **Vorlagen-Namen deutsch auch in der englischen Oberfläche** (D1); nur die Blatt-Namen sind übersetzt.
- **Gang „Essen & Trinken“ statt „Lebensmittel“** in der Drogerie-Vorlage (Offenlegung 2): unerkannte
  Lebensmittel landen dort weiter unter „Sonstiges“.
- **Stichwörter bleiben Wortenden:** keine Mehrzahl-Erkennung („Bratwürste“), kein Teilstring in der Wortmitte; ein
  kurzes Stichwort (3 Buchstaben) trifft viele Wörter am Ende („tee“ → „Eistee“, „Fliedertee“). Der Nutzer sieht
  keine Vorschau, welche Artikel ein neues Stichwort trifft.
- **Kein Umbenennen eines Stichworts**, nur Löschen und neu anlegen. Keine Rückfrage beim Löschen.
- **Hinweis „Gang weiter oben gewinnt“** gilt für dasselbe Wort in zwei Gängen; ein längeres, anderes Stichwort
  eines späteren Gangs gewinnt weiter davor (D1-Regel), der Hinweis nennt das nicht.
- **Ein Stichwort mit Bindestrich oder Punkt** wird abgelehnt, auch wenn der Nutzer es für einen Artikelnamen mit
  Bindestrich meint; er legt dann das Wortende an („cola“ statt „coca-cola“).
- **Geteilte Läden:** Gänge und Stichwörter bleiben lokal (D3).
- **Vorlage wählen ersetzt, mischt nie.** Eigene Gänge und eigene Stichwörter gehen dabei verloren (nach Rückfrage).
- Die Einzahl in der Gang-Zeile ist nur per Unit-Test (`summaryText`) belegt, nicht per UI-Test.
- Leistung großer Listen mit sehr vielen Nutzer-Stichwörtern (`stationForKeywords` prüft alle Stichwörter je
  Artikel) ist nicht gemessen.
- Nichts auf Hennings Geräten geprüft; kein CloudKit-Test. Das Vorlagen-Blatt und der Stichwort-Abschnitt sind nur
  im Simulator mit Standardschrift geprüft, nicht in AccessibilityXXXL.

## Alternativen (verworfen oder offen)

| Punkt | Gewählt (PO 2026-11-01) | Alternative | Folge der Alternative |
|-------|--------------------------|-------------|-----------------------|
| Vorlage wählen | eigenes Blatt mit Kennzeichen | Systemmenü, Hinweis als Text hinter dem Namen | ~40 Zeilen weniger; der Hinweis geht leicht unter |
| Stichwörter | Zeilen, Wisch-Löschen, Feld | Wortwolke mit ✕ | kompakter, kleine Tippziele |
| Doppeltes Stichwort in anderem Gang | annehmen mit Hinweis | ablehnen | strenger als das Modell, nähme dem Nutzer ein sinnvolles Überstimmen |
| Zuschnitt | zwei Durchgänge 2b-1 / 2b-2 | ein Durchgang (~1.000 Zeilen) | Limit ×4 |
| Stichwort-Vorschläge | keine, nur Regeln (Wortende, Liste) | Sprachmodell schlägt Stichwörter vor | nicht erwogen: Ohne Modell geht es, weil das Zuordnen deterministisch über Wortenden läuft |

Keine frühere Entscheidung wird gekippt; D1 und 2a bleiben bestehen.

## Definition of Done

- [ ] Build erfolgreich, alle Unit- und UI-Tests grün (neue Tests waren vor der Umsetzung rot)
- [ ] CI Teil D läuft grün, A, B, C unverändert innerhalb von 60 Minuten
- [ ] Echter Durchlauf im Simulator mit Belegbildern registriert
- [ ] `CLAUDE.md`-Absatz „Laden-Stationen“ um Durchgang 2b-1 ergänzt, Issue #234 aktualisiert
- [ ] Kein CloudKit-Schritt nötig (bestätigt: nur `stationConfigJSON`, D1-Feld)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Fortführung des Musters „reine Logik in `StoreCategories`, Speichern über `Store.updateStationConfig`,
  Ansicht ruft nur die Hülle“ (#85/#94/D1/2a). Vorlagen sind reine Daten wie `lidlTemplate`; keine neue
  Abhängigkeit, kein neues Feld, keine neue Schicht. Die Stichwort-Regeln (Einzelwort, ≥ 3 Zeichen, Duplikat nur im
  selben Gang abgelehnt) folgen der bestehenden Auflösung und sind keine neue Architektur.

## Changelog

- 2026-11-01: Initial spec created (Issue #234, Durchgang 2b-1).
- 2026-11-01: Drogerie-Gang 10 heißt „Essen & Trinken“ (PO-Entscheidung statt „Snacks & Getränke“).
