---
entity_id: station-setup
type: feature
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: feat-234-d2-kategorien-einrichten
tags: [feature, store, stations, settings-ui, category, shopping-route]
---

# Laden-Stationen einrichten („Kategorien einrichten“), Durchgang 2a (Issue #234)

## Approval

- [ ] Approved

Offenlegung für die Freigabe:

1. **Zuschnitt (PO-Beschluss 2026-10-31).** Durchgang 2 ist in 2a (diese Spec) und 2b geteilt. 2a hat
   rund 640 Zeilen in der Zählweise des Prüfwerkzeugs (alle neuen Zeilen inkl. Tests) in 8 Positionen
   (9 Dateien, die zwei Strings-Dateien zählen als ein Paar). Das liegt über dem Korridor 250–350, ist
   aber vom PO als Zuschnitt akzeptiert. 2b folgt als eigener Durchgang (siehe Ausblick).
2. **Bestehende Tests werden bewusst geändert.** `testMenuEntriesInStoreWithStations` (U6) und
   `testRemoveAndReapplyStations` (U7) in `RestockUITests/StoreStationsUITests.swift` prüfen die
   Zwischen-Menüeinträge aus D1 („Lidl-Vorlage übernehmen“, „Gänge entfernen“) und die kurzen Kennungen
   `store.menu.applyStationTemplate`, `store.menu.removeStations`, `store.stations.confirmApply`,
   `store.stations.confirmRemove`. Diese Einträge entfallen laut D1-Spec („Ausblick D2“) und Issue Punkt 4;
   U6/U7 werden auf die neue Ansicht umgeschrieben (gleiche Absichten AC-14/AC-15 der D1-Spec, neuer Weg).
   Alle anderen D1-Tests bleiben unverändert und müssen grün bleiben.
3. **Abweichung vom Entwurf, technisch begründet:** Das Ziehen der Gänge läuft über einen
   Knopf „Sortieren“ in der Übersicht (Bearbeiten-Modus wie in `StoreSetupView`), nicht über dauerhaft
   sichtbare Griffe. Ein dauerhaft aktiver Bearbeiten-Modus der `List` unterdrückt die Wischgesten
   (Löschen). Alles andere folgt dem freigegebenen Entwurf 1–4.

## Purpose

Seit D1 bekommt ein Laden seine Gänge nur über die fest eingebaute Lidl-Vorlage und kann sie weder
anpassen noch verwerfen außer ganz. Diese Spec liefert die Ansicht „Kategorien einrichten“ (··· in der
Ladenliste): Gänge anlegen, umbenennen, ziehen, löschen, die festen Kategorien je Gang zuordnen und
ausblenden, die Lidl-Vorlage wählen oder die Gänge ganz entfernen. Die beiden D1-Zwischeneinträge im
Menü gehen darin auf. Ein Artikel landet danach beim Umbenennen, Zuordnen oder Ausblenden sofort im
richtigen Abschnitt, ohne dass gemerkte Zuordnungen oder der gelernte Weg verloren gehen.

Aufbau, Datenmodell (`StationConfig`, `Station`), Auflösung Artikel → Gang und Sortierung stehen in
`docs/specs/models/store-stations.md` (D1) und werden hier nicht wiederholt.

## Source

- **Neu:** `SmartCart/Views/Store/StationSetupView.swift` (Übersicht und Gang-Detail)
- **Erweitert:** `SmartCart/Models/StoreCategories.swift` (reine Änderungsfunktionen),
  `SmartCart/Models/Store.swift` (Hülle mit Nebenwirkungen), `SmartCart/Views/Store/StoreDetailView.swift`
  (Menüeintrag und Sheet)
- **Identifier:** `StationSetupView`, `StoreCategories.addingStation(_:emoji:to:)`,
  `StoreCategories.renamingStation(_:to:emoji:in:)`, `StoreCategories.movingStations(_:from:to:in:)`,
  `StoreCategories.assigning(_:toStation:in:)`, `StoreCategories.hiding(_:in:)`,
  `StoreCategories.opening(_:in:)`, `StoreCategories.deletingStation(_:in:)`,
  `StoreCategories.categoryState(_:in:)`, `Store.updateStationConfig(_:)`, `Store.renameStation(_:to:emoji:)`,
  `Store.deleteStation(_:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `StationConfig`, `Station`, `StoreCategories.stationNamed`, `resolveStation`, `normalizedName`, `compareKey`, `suggestedEmoji`, `emojiChoices`, `lidlTemplate` | module (D1) | Datenmodell, Namensvergleich, Kollisionsprüfung, Emoji-Auswahl, Vorlage |
| `AssignmentService.categoryOrder` / `displayCategory` / `categoryEmoji` | service | die 35 festen Kategorien (Rohwerte), Anzeigename und Emoji für die Zeilen; im Widget-Ziel nutzbar, `AssignmentService.swift` selbst wird nicht verwendet |
| `Store.applyStationConfig`, `removeStations`, `addStation`, `ensureCustomCategory`, `rememberCategory`, `setAssignment`, `updateCustomCategory`, `deleteCustomCategory`, `bumpRouteRevision` | model | Muster und Bausteine für Umbenennen und Löschen mit Merkungen, eigener Kategorie und gelerntem Weg |
| `ShoppingRoute.renameCategory`, `ShoppingTrip.entries[].category`, `ShoppingRouteModel.itemCategories` | module | gelernter Weg und laufende Abhak-Sitzung tragen Gang-Namen |
| `StoreSetupView` (Muster `EditMode`, `onMove` + `save()`) | view | Vorbild für Ziehen und sofortiges Speichern |
| `LocalizationKeyParityTests` | test | gleiche Schlüssel und Platzhalter de/en |
| `UITestLaunch`, `UITestWait`, Seeds `-seedStationStoreForUITests` / `-clearStationStoreForUITests` | test helper | wiederverwendet, keine Änderung am Seed |
| `docs/artifacts/feat-234-d2-kategorien-einrichten/entwurfsvorschau.html` | doc | freigegebener Entwurf 1–4 (PO 2026-10-31) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | reine Funktionen auf `StationConfig`: anlegen, umbenennen, verschieben, zuordnen, ausblenden, öffnen, löschen, Zustand je Kategorie, Invarianten (~+70) |
| `SmartCart/Models/Store.swift` | MODIFY | Hülle: `updateStationConfig` (ein Schreibpunkt: `date`, Eigenkategorien, Weg-Version), `renameStation`, `deleteStation` (~+60) |
| `SmartCart/Views/Store/StationSetupView.swift` | CREATE | Übersicht und Gang-Detail (~+220), in `project.pbxproj` einzutragen, App-Ziel |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | `stationMenuItem` und `withStationDialogs` (D1) durch einen Eintrag „Kategorien einrichten“ plus Sheet ersetzen (~+15/−35) |
| `SmartCart/Resources/de.lproj/Localizable.strings`, `en.lproj/Localizable.strings` | MODIFY | neue `station.setup.*`-Schlüssel (~+25 je Datei); die D1-Schlüssel `station.menu.applyTemplate`, `station.template.confirm.*` fallen weg oder werden wiederverwendet (siehe Lokalisierung) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | `StationSetupView.swift` in PBXBuildFile, PBXFileReference, Gruppe `Views/Store`, Sources-Phase des App-Ziels |
| `RestockTests/StoreStationsTests.swift` | MODIFY | Unit-Tests S1–S13 (~+110) |
| `RestockUITests/StoreStationsUITests.swift` | MODIFY | U6/U7 umschreiben, neue Abläufe V1–V7 (~+110) |

Nicht berührt: `CategoryPickerView` (kein Wischen, keine Änderung am Gang-Modus; 2b), `ShoppingRoute.swift`
(Weg-Umbenennung nutzt das vorhandene `renameCategory`), `SmartCartApp.swift` (die D1-Seeds reichen),
`SharedStoreService`/`SyncCoordinator`, Schema, `CLAUDE.md` wird erst mit dem Abschluss ergänzt (Absatz
„Laden-Stationen“ erweitern; keine eigene Position, weil Doku).

### Estimated Changes

- Files: 8 Positionen (9 Dateien)
- LoC (Gate-Zählweise: alle Additionen inkl. Tests): ca. +640 (Produktiv ~+390 inkl. Strings, Tests ~+220,
  `project.pbxproj` +4, Rest Umbauten); Löschungen ~−60 (D1-Menü, Dialoge, alter U6/U7-Körper).
  Spielraum nach oben bis etwa 700, darüber hinaus meldet der Implementierer, bevor er weitermacht.

### Nicht in diesem Durchgang

Siehe Ausblick 2b: vier Mustervorlagen, Stichwörter bearbeiten, Wischaktionen in der Kategorie-Auswahl,
Überführung eigener Kategorien aus #85. Kein CloudKit-Schritt (kein neues Feld).

## Implementation Details

### Menü und Einstieg

- Im ···-Menü der Ladenliste ersetzt **ein** Eintrag „Kategorien einrichten“ (Kennung
  `store.menu.setupStations`, Symbol `square.stack.3d.up`) die D1-Einträge. Er steht in **jedem** Laden,
  auch ohne Gänge. Er öffnet ein Sheet mit einem `NavigationStack` (`StationSetupView`), Titel
  „Kategorien einrichten“, rechts „Fertig“ (`stationSetup.done`).
- Einstieg nur hier (Issue Punkt 4), nicht zusätzlich aus Einstellungen → Laden-Einrichtung.
- `StoreDetailView` zeichnet nach jeder Änderung neu über den bestehenden `reorderTick`; die Ansicht
  gibt dafür beim Schließen (und bei jeder Änderung) den Zähler weiter (Closure `onChange`).

### Reine Funktionen (`StoreCategories`, Datei bleibt in allen drei Zielen kompilierbar)

Alle nehmen eine `StationConfig` und liefern eine neue (Wertsemantik, kein Zugriff auf SwiftData),
`nil` bedeutet „abgelehnt, nichts ändern“. Der Zeitstempel `date` wird nicht hier, sondern in
`Store.updateStationConfig` gesetzt.

- `addingStation(_ input, emoji, to config)`: `resolveStation(input, config)` muss `.new(name)` ergeben,
  sonst `nil` (vorhandener Gang, „Sonstiges“/„Other“, Marke, leer). Der neue Gang wird am Ende
  angehängt (leere `builtIns` und `keywords`). Trägt `name` den Rohwert einer festen Kategorie
  (Vergleich über `compareKey` mit `AssignmentService.categoryOrder`), wird diese Kategorie automatisch
  in seine `builtIns` übernommen (aus anderem Gang und aus `hidden` gelöst).
- `renamingStation(_ old, to input, emoji, in config)`: neuer Name über `resolveStation`; erlaubt ist
  `.new(name)` oder `.existing(name)` mit `name == old` (nur Schreibweise/Emoji ändern). Alles andere
  (anderer vorhandener Gang, „Sonstiges“/„Other“, Marke, leer) → `nil`. Gleiche Übernahme wie beim Anlegen,
  wenn der neue Name eine feste Kategorie benennt. Die `builtIns` und `keywords` des Gangs bleiben, auch
  wenn der alte Name ein fester war (die Kategorie bleibt über `builtIns` im Gang).
- `movingStations(_ config, from: IndexSet, to: Int)`: wie `Array.move`.
- `assigning(_ category, toStation name, in config)`: löst `category` aus jedem anderen Gang und aus
  `hidden`, hängt sie an `builtIns` des Ziels an (keine Doppelung). **Gesperrt** (`nil`), wenn ein Gang
  existiert, der genau diese Kategorie als Namen trägt und nicht das Ziel ist (siehe „Name-gebundene
  Kategorien“).
- `hiding(_ category, in config)`: entfernt `category` aus allen `builtIns`, nimmt sie in `hidden` auf
  (keine Doppelung); gesperrt wie oben.
- `opening(_ category, in config)`: entfernt `category` aus allen `builtIns` und aus `hidden`; gesperrt wie oben.
- `deletingStation(_ name, in config)`: entfernt den Gang; seine `builtIns` sind danach in keinem Gang und
  nicht in `hidden`, also „offen“. Die Stichwörter fallen mit dem Gang weg.
- `categoryState(_ category, in config)` → `.assigned(String)` (Gangname), `.hidden`, `.open`. Gilt auch
  für Kategorien, deren Name ein Gang trägt: `.assigned(dieserGang)`.

**Name-gebundene Kategorien (löst den „stillen vierten Zustand“).** `stationForCategory` (D1) prüft
`stationNamed(category)` vor `hidden`/`builtIns`: Trägt ein Gang den Namen einer festen Kategorie, landet sie
immer dort. Deshalb gilt: Gang anlegen/umbenennen auf diesen Namen übernimmt die Kategorie in seine
`builtIns`; in der Gang-Detailansicht zeigt ihre Zeile im Zielgang ein gesetztes Häkchen (nicht abwählbar,
solange der Name gilt) und in allen anderen Gängen den Hinweis „gehört zu Gang <Name>“ (nicht antippbar). In
der Übersicht erscheint sie weder unter „Offen“ noch unter „Ausgeblendet“. Gang umbenennen oder löschen
gibt sie frei (nach Umbenennen bleibt sie im Gang, Zeile wieder wählbar; nach Löschen ist sie offen).

**Invarianten (Test S9):** Gang-Namen eindeutig (über `compareKey`) und nie „Sonstiges“/„Other“ oder Marke;
jede `builtIns`-/`hidden`-Angabe steht in `categoryOrder`; keine feste Kategorie in zwei Gängen; `hidden`
und alle `builtIns` überschneidungsfrei; jede Kategorie, deren Name ein Gang trägt, steht in dessen `builtIns`.

### Hülle in `Store`

- `updateStationConfig(_ config)`: setzt `date = Date()`, schreibt `stationConfig`, legt für jeden Gang, der
  keine feste Kategorie ist, die eigene Kategorie an (`ensureCustomCategory`, vorhandene bleiben), ruft
  `bumpRouteRevision()`. Einziger Schreibpunkt der Ansicht; ruft nie `removeStations` (das bleibt für den
  letzten Gang). Auf einem Laden ohne Gänge (Feld leer) funktioniert er ebenfalls; erst nach dem Anlegen des
  ersten Gangs ist `hasStations` wahr.
- `renameStation(_ old, to input, emoji)` → neuer Name oder `nil` (abgelehnt):
  1. `renamingStation` auf der aktuellen Konfiguration; `nil` → abbrechen, nichts geändert.
  2. `updateStationConfig(neue Konfiguration)`.
  3. Ist `old` eine eigene Kategorie dieses Ladens (`isCustomCategory(old)`) und der Name ändert sich: ihr
     Eintrag wird mit Löschvermerk (`CustomCategoryEntry(emoji: nil, date: now)`) beendet; der neue Name wird
     als eigene Kategorie angelegt, sofern er keine feste Kategorie ist (Schritt 2). Das Emoji des neuen
     Eintrags kommt aus dem Gang.
  4. Merkungen (`categoryAssignments`) mit Wert `old` werden auf den neuen Namen gesetzt (`setAssignment` mit
     neuem Datum, damit geteilte Läden sie über `assignmentsJSON` bekommen). Die Sonstiges-Marke bleibt.
  5. Artikel dieses Ladens mit `category == old` und `categoryManuallySet == true` bekommen die neue
     Kategorie (`lastModified` jetzt). Artikel mit automatischer Kategorie bleiben unberührt.
  6. `routeModel` über `ShoppingRoute.renameCategory(old, to: neu, in:)`; **die laufende Abhak-Sitzung**
     (`currentTrip.entries`, Feld `category`) wird im selben Zug mitgezogen.
  7. `bumpRouteRevision()`.
- `deleteStation(_ name)`: Konfiguration über `deletingStation`; war es der letzte Gang, ruft die Ansicht
  stattdessen nach Rückfrage `removeStations()` (siehe unten) und dieser Pfad endet dort. Sonst
  `updateStationConfig`; ist der Gang eine eigene Kategorie, `deleteCustomCategory(name)` (setzt Artikel mit
  dieser Kategorie auf die automatische zurück, entfernt Merkungen, löscht gelernte Wegzuordnung); ist er
  ein fester Name, werden nur Merkungen mit diesem Wert vergessen (damit ein später gleich benannter Gang
  sie nicht wiederbelebt); Artikel behalten dort die feste Kategorie.

**Laufende Abhak-Sitzung beim Umbenennen — Entscheidung: mitziehen.** `ShoppingTrip.entries[].category`
trägt seit D1 den Gang-Namen (`recordCheckOff`), und `finalizeTrip` lernt daraus
`itemCategories[key] = category`. Bliebe der alte Name stehen, würde nach dem Umbenennen beim Abschluss der
Sitzung ein Name gelernt, den es nicht mehr gibt; die Artikel der Sitzung verlören ihre Gang-Zuordnung im
gelernten Weg. Das Mitziehen ist eine Schleife von wenigen Zeilen in `Store.renameStation` und reicht an
den vorhandenen Aufbewahrungsort (`currentTrip` ist ein Lese-/Schreib-Wrapper). Beim **Löschen** wird die
Sitzung nicht verändert; die Einträge mit dem gelöschten Namen lernen nichts mehr (Gang-Name existiert
nicht, wird wie ein veralteter Name übergangen) — dokumentierte Grenze.

### Ansicht `StationSetupView`

**Übersicht** (`NavigationStack`-Wurzel, `List`, Texte aus dem freigegebenen Entwurf):

- Oben die Schaltfläche „Vorlage wählen …“ (`stationSetup.template`): öffnet einen `confirmationDialog`
  (Titel „Vorlage wählen“, Meldung „Ersetzt die Gänge dieses Ladens. Gemerkte Zuordnungen und eigene
  Kategorien bleiben.“) mit dem Eintrag „Lidl“ (`stationSetup.templateLidl`). In 2a gibt es nur diese eine
  Vorlage, die weiteren kommen in 2b als weitere Einträge desselben Dialogs. Ohne Gänge im Laden ist die
  Rückfrage derselbe Dialog (die Meldung ist dann trotzdem wahr und harmlos). Bestätigen →
  `applyStationConfig(lidlTemplate)` (Zeitstempel jetzt, Gang-Namen als eigene Kategorien); Artikel
  unberührt.
- Abschnitt „Gänge · N“ (`stationSetup.section.stations`): eine Zeile je Gang (Emoji, Name, Untertitel
  „N Kategorien · M Stichwörter“ bzw. „noch leer“, Pfeil), Kennung `stationSetup.row.<Name>`. Tipp öffnet das
  Detail. `.onMove` (nur im Bearbeiten-Modus, Knopf „Sortieren“ in der Symbolleiste, Kennung
  `stationSetup.sort`) ruft `movingStations` + `updateStationConfig` + `try? context.save()` (Muster aus
  `StoreSetupView`, Fehlerbefund #98 D6). Wischen nach links: „Löschen“ (`stationSetup.row.delete.<Name>`).
  Letzte Zeile „Gang hinzufügen“ (`stationSetup.addStation`) öffnet eine Eingabe (Alert mit Textfeld,
  Kennung `stationSetup.addStation.field`); Ergebnis über `addingStation`; Ablehnung zeigt einen Hinweis
  (siehe Texte).
- Abschnitt „Offen · N“ (`stationSetup.section.open`, Unterzeile „landen unter „Sonstiges““): alle festen
  Kategorien im Zustand `.open`, je Zeile Name (Anzeigename, Emoji) und ein Menü „Zuordnen …“
  (`stationSetup.open.<Rohwert>`) mit allen Gängen plus „Ausblenden“.
- Abschnitt „Ausgeblendet · N“ (`stationSetup.section.hidden`): Kategorien im Zustand `.hidden`
  (durchgestrichen) mit Knopf „Einblenden“ (`stationSetup.hidden.<Rohwert>`) → `opening`.
- Ganz unten (nur wenn Gänge da sind): „Gänge entfernen“ (`stationSetup.remove`, rot) mit
  Rückfrage (`stationSetup.confirmRemove`) → `removeStations()`, danach schließt die Ansicht nicht,
  sondern zeigt den leeren Zustand (nur „Vorlage wählen …“ und „Gang hinzufügen“).
- Hinweiszeile für geteilte Läden (`store.shareID != nil`): „Gänge bleiben bis zum Abgleich auf diesem
  Gerät.“ (`stationSetup.sharedHint`).
- Kein Gang vorhanden: Abschnitt „Gänge“ zeigt nur „Gang hinzufügen“; „Offen“ und „Ausgeblendet“ entfallen,
  weil ohne Gänge alle 35 Kategorien klassisch gelten.

**Gang-Detail** (Push aus der Übersicht, Titel „Gang“):

- Name (Textfeld `stationSetup.detail.name`) und Emoji (Gitter aus `StoreCategories.emojiChoices`, 6
  Spalten wie `CustomCategoryEditor`, Auswahl sofort gespeichert). Der Name wird bei `onSubmit` und beim
  Verlassen der Ansicht übernommen (`renameStation`); abgelehnte Namen zeigen eine rote Hinweiszeile und
  bleiben im Feld, der gespeicherte Name ändert sich nicht (beim Verlassen springt das Feld zurück).
- Abschnitt „Kategorien in diesem Gang · N“: alle 35 festen Kategorien in der Reihenfolge von
  `categoryOrder`, je Zeile Anzeigename und Emoji. Zustand `.assigned(dieser)`: Häkchen
  (`stationSetup.detail.category.<Rohwert>`); Tipp auf eine Zeile mit Häkchen → `opening` (offen); `.open`
  (Untertitel „offen“) und `.hidden` („ausgeblendet“) → Tipp ruft `assigning`; `.assigned(anderer)`
  (Untertitel „jetzt in: <Gang>“) → Tipp holt die Kategorie herüber. Name-gebundene Zeilen wie oben.
- Abschnitt „Stichwörter“: Liste der Stichwörter **nur lesend** (Zusatz „bearbeiten folgt“ entfällt in 2a,
  der Abschnitt heißt „Stichwörter (nur Anzeige)“).
- „Gang löschen“ (`stationSetup.detail.delete`, rot): Rückfrage; Bestätigung ruft `deleteStation` bzw. beim
  letzten Gang `removeStations`.
- Der Titel der Rückfrage nennt die Folge: „Gang „<Name>“ löschen? Seine Kategorien werden offen.“

### Lokalisierung (de + en, `LocalizationKeyParityTests`)

Neue Schlüssel (de / en; Platzhalter je Schlüssel gleich), Entwurfstexte unverändert übernommen:

`station.setup.menu` („Kategorien einrichten“ / „Set up categories“), `station.setup.title` (gleich),
`station.setup.done` („Fertig“ / „Done“), `station.setup.template` („Vorlage wählen …“ / „Choose template …“),
`station.setup.template.title` („Vorlage wählen“ / „Choose template“), `station.setup.template.message`
(„Ersetzt die Gänge dieses Ladens. Gemerkte Zuordnungen und eigene Kategorien bleiben.“ / „Replaces this
store's aisles. Remembered assignments and your own categories are kept.“), `station.setup.template.lidl`
(„Lidl“ / „Lidl“), `station.setup.section.stations` („Gänge · %d“ / „Aisles · %d“),
`station.setup.section.open` („Offen · %d“ / „Open · %d“), `station.setup.section.open.footer` („landen unter
„Sonstiges““ / „end up under “Other””), `station.setup.section.hidden` („Ausgeblendet · %d“ / „Hidden · %d“),
`station.setup.sort` („Sortieren“ / „Sort“), `station.setup.add` („Gang hinzufügen“ / „Add aisle“),
`station.setup.add.prompt` („Name des Gangs“ / „Aisle name“), `station.setup.assign` („Zuordnen …“ /
„Assign …“), `station.setup.hide` („Ausblenden“ / „Hide“), `station.setup.show` („Einblenden“ / „Show“),
`station.setup.remove` („Gänge entfernen“ / „Remove aisles“), `station.setup.shared` („Gänge bleiben bis zum
Abgleich auf diesem Gerät.“ / „Aisles stay on this device until sync is available.“),
`station.setup.row.summary` („%d Kategorien · %d Stichwörter“ / „%d categories · %d keywords“),
`station.setup.row.empty` („noch leer“ / „empty“), `station.setup.detail.title` („Gang“ / „Aisle“),
`station.setup.detail.categories` („Kategorien in diesem Gang · %d“ / „Categories in this aisle · %d“),
`station.setup.detail.in` („jetzt in: %@“ / „currently in: %@“), `station.setup.detail.bound` („gehört zu
Gang %@“ / „belongs to aisle %@“), `station.setup.detail.keywords` („Stichwörter (nur Anzeige)“ /
„Keywords (read only)“), `station.setup.detail.delete` („Gang löschen“ / „Delete aisle“),
`station.setup.delete.title` („Gang „%@“ löschen?“ / „Delete aisle “%@”?“), `station.setup.delete.message`
(„Seine Kategorien werden offen.“ / „Its categories become open.“), `station.setup.name.rejected`
(„Diesen Namen gibt es schon oder er ist nicht erlaubt.“ / „This name is already in use or not allowed.“).
Gestrichen werden die nicht mehr benutzten D1-Schlüssel `station.menu.applyTemplate`,
`station.template.confirm.title`, `station.template.confirm.message`; `station.menu.remove`,
`station.remove.confirm.title`, `station.remove.confirm.message` werden in der Ansicht weiterverwendet (kein
Textverlust). Gang-Namen der Vorlage bleiben deutsch (D1).

### Geteilte Läden

`stationConfigJSON` reist weiter nicht in den Abgleich (D3). Die Ansicht sagt das in der Hinweiszeile.
Umbenennen schreibt Merkungen mit neuem Datum, die über das bestehende `assignmentsJSON` zu Mitgliedern
gehen, wo sie ohne Gang wirkungslos sind (wie die Marke in D1).

### Kein neues Feld, kein Schema-Schritt

Alles liegt in `stationConfigJSON` (D1). Keine Änderung an `@Model`, `@AppStorage`-Schlüsseln oder
`docs/cloudkit/private-schema-aktuell.ckdb`; `MirroredSchemaSnapshotTests` bleiben unverändert. Kein
CloudKit-Deploy-Schritt für diesen Durchgang.

## Test Plan

Alle Tests werden vor der Umsetzung geschrieben (TDD RED: neue Unit-Tests übersetzen nicht bzw. die UI-Tests
scheitern, solange API und Ansicht fehlen; die Umsetzung bringt sie nach GREEN). In-Memory-Container immer
mit `cloudKitDatabase: .none`; jeder angelegte Laden räumt seine App-Gruppen-Schlüssel in `tearDown`
(`removeRouteData`, vorhanden).

### Automated Tests (TDD RED)

Unit, `RestockTests/StoreStationsTests.swift` (neuer Abschnitt „D2a“):

- [ ] S1 `testRenameStationMovesAssignmentsPathAndItems`: GIVEN Laden mit Lidl-Vorlage, Gang „Käse“ mit Merkung „gouda“ → „Käse“, Artikel „Brie“ von Hand in „Käse“, gelernte Position und `itemCategories["gouda"] = "Käse"`, `customCategory` „Käse“ WHEN `renameStation("Käse", to: "Käse & Co")` THEN Gang heißt neu an gleicher Stelle, Merkung, `item.category`, `routeModel.itemCategories` und eigene Kategorie (alter Eintrag mit Löschvermerk, neuer lebend) tragen den neuen Namen, `stationName(of:)` für „Gouda“ und „Brie“ ergibt „Käse & Co“, `pendingItems`-Rang unverändert (AC-3, AC-4)
- [ ] S2 `testRenameRejectsCollisions`: GIVEN Vorlage WHEN Umbenennen von „Käse“ auf „Milchprodukte“ (anderer Gang), „sonstiges“, „Other“, die Marke, „  “ THEN jeweils `nil`, Konfiguration und Weg bytegleich zum Ausgangszustand; auf „käse“ (nur Schreibweise) und „Käsetheke“ THEN erlaubt (AC-5)
- [ ] S3 `testRenameToFixedCategoryNameAdoptsCategory`: GIVEN Gang „Drogerie“ mit `builtIns` [Körperpflege], Kategorie „Tierbedarf“ offen WHEN Gang „Tierbedarf“ per `addingStation` angelegt THEN `builtIns == ["Tierbedarf"]`, keine eigene Kategorie „Tierbedarf“ angelegt; GIVEN „Getränke“ ausgeblendet WHEN Gang „Getränke“ angelegt THEN aus `hidden` gelöst; GIVEN Gang „Käse“ und „Tierbedarf“ offen WHEN „Käse“ per `renamingStation` in „Tierbedarf“ umbenannt THEN Gang heißt „Tierbedarf“ und `builtIns` enthält „Tierbedarf“ (AC-5, AC-9)
- [ ] S4 `testAssignMovesBetweenStationsAndClearsHidden`: GIVEN Vorlage WHEN `assigning("Elektronik", toStation: "Drogerie")` THEN in `builtIns` von Drogerie, in keinem anderen Gang, nicht in `hidden`; WHEN `assigning("Werkzeug", …)` THEN aus `hidden` gelöst; erneutes Zuordnen doppelt nichts (AC-8)
- [ ] S5 `testStatesAssignedHiddenOpen`: GIVEN Vorlage WHEN `categoryState` für „Backwaren“, „Werkzeug“, „Tierbedarf“ THEN `.assigned("Brot & Backwaren")`, `.hidden`, `.open`; nach `hiding("Backwaren")` `.hidden`; nach `opening("Werkzeug")` `.open`; ein Artikel „Hammer“ landet erst nach `assigning("Werkzeug", …)` im Gang, nach `hiding` wieder in „Sonstiges“ (AC-8, AC-9)
- [ ] S6 `testDeleteStationOpensCategoriesAndCleansUp`: GIVEN Vorlage, eigene Kategorie „Käse“ mit Merkung und Handwahl-Artikel WHEN `deleteStation("Käse")` THEN Gang weg, Stichwort „gouda“ greift nicht mehr (Gouda → Sonstiges), Merkung weg, Artikel zurück auf automatische Kategorie, eigene Kategorie mit Löschvermerk, `itemCategories` ohne „Käse“; WHEN `deleteStation("Getränke")` (fester Name) THEN `categoryState("Getränke") == .open`, Artikel mit fester Kategorie „Getränke“ behalten sie, Merkungen mit Wert „Getränke“ weg (AC-10)
- [ ] S7 `testMovingStationsChangesOrderAndRank`: GIVEN Vorlage WHEN `movingStations` verschiebt „Käse“ vor „Obst & Gemüse“ THEN Reihenfolge der `stations` wie erwartet, `stationRank` und `pendingItems` folgen, `builtIns`/`keywords` unberührt (AC-6)
- [ ] S8 `testSetupOnStoreWithoutStations`: GIVEN Laden ohne Gänge WHEN `updateStationConfig` mit `addingStation("Lager")` THEN `hasStations == true`, Gang „Lager“ steht als eigene Kategorie, `date` jetzt; WHEN letzter Gang gelöscht über `removeStations()` THEN `hasStations == false`, eigene Kategorien und Merkungen bleiben (AC-7, AC-11)
- [ ] S9 `testInvariantsHoldAfterOperationSequence`: GIVEN Vorlage WHEN eine feste Folge von 25 Operationen (anlegen, umbenennen, zuordnen, ausblenden, öffnen, löschen, verschieben, auch abgelehnte) THEN nach jedem Schritt: Namen eindeutig und nie „Sonstiges“/Marke, jede Angabe in `categoryOrder`, keine Kategorie in zwei Gängen, `hidden` ∩ `builtIns` leer, jede Name-gebundene Kategorie in ihrem Gang (T8-Invariante der D1-Spec; AC-12)
- [ ] S10 `testNameBoundCategoryCannotBeMovedAway`: GIVEN Gang „Getränke“ (trägt die feste Kategorie) und Gang „Drogerie“ WHEN `assigning("Getränke", toStation: "Drogerie")`, `hiding("Getränke")`, `opening("Getränke")` THEN je `nil`; nach Umbenennen des Gangs auf „Trinken“ THEN `assigning("Getränke", toStation: "Drogerie")` erlaubt (AC-9)
- [ ] S11 `testRenameUpdatesRunningTrip`: GIVEN laufende Abhak-Sitzung mit zwei Einträgen in Gang „Käse“ WHEN Umbenennen THEN `currentTrip.entries[].category` trägt den neuen Namen; WHEN Sitzung abgeschlossen THEN `itemCategories` lernt den neuen Namen, nie den alten; beim Löschen bleibt die Sitzung unverändert (AC-4)
- [ ] S12 `testApplyTemplateReplacesStationsKeepsAssignments`: GIVEN Laden mit selbst angelegtem Gang „Lager“ und Merkung WHEN `applyStationConfig(lidlTemplate)` THEN genau die 12 Gänge, „Lager“ weg, Merkung bleibt erhalten (wirkt nicht, solange es den Gang nicht gibt), eigene Kategorie „Lager“ bleibt (AC-13)
- [ ] S13 `testSetupStringsExistInBothLanguages`: GIVEN alle `station.setup.*`-Schlüssel WHEN kompilierte Tabellen `de`/`en` THEN vorhanden, nicht leer, gleiche Platzhalter (Format `%d`/`%@`) je Schlüssel; `LocalizationKeyParityTests` bleibt grün (AC-14)

UI, `RestockUITests/StoreStationsUITests.swift` (Start über `UITestLaunch.start` mit `-hasCompletedOnboarding YES
-seedStationStoreForUITests`, `tearDown` räumt mit `-clearStationStoreForUITests`; nie `-developerMode`). Der
Seed hat sechs Artikel: Batterien (Sonstiges, automatische Kategorie Elektronik), Milch, Gouda, Salami, Apfel,
Brot (dringend). Prüfen wird immer der Nutzen (Abschnitt in der Liste), nicht nur das Vorhandensein:

- [ ] V1 `testSetupEntryReplacesTemplateEntries` (ersetzt U6, AC-1, AC-2): GIVEN Seed WHEN ···-Menü THEN `store.menu.setupStations` ist da, `store.menu.applyStationTemplate` und `store.menu.removeStations` fehlen; „Reihenfolge anpassen“ weiter nur im Einkaufsweg, nicht im Modus Kategorie
- [ ] V2 `testRenameStationMovesItemsToRenamedSection`: GIVEN Seed, Modus Kategorie WHEN in „Kategorien einrichten“ → Gang „Käse“ → Name „Käsetheke“ → zurück → Fertig THEN die Liste zeigt den Abschnitt „Käsetheke“ mit „Gouda“, den Abschnitt „Käse“ nicht mehr; WHEN Sheet erneut geöffnet THEN die Gang-Zeile heißt „Käsetheke“ (AC-3, AC-4)
- [ ] V3 `testRenameCollisionIsRejected`: GIVEN Seed WHEN Gang „Käse“ auf „Milchprodukte“ umbenannt THEN Hinweis „Diesen Namen gibt es schon …“ sichtbar, nach Zurück/Fertig bleibt „Gouda“ unter „Käse“ und „Milch“ unter „Milchprodukte“ (AC-5)
- [ ] V4 `testAssignOpenCategoryMovesItemToStation` (AC-8): GIVEN Seed WHEN Gang „Drogerie“ → Kategorie „Elektronik“ antippen THEN Zeile zeigt Häkchen; nach Fertig steht „Batterien“ im Abschnitt „Drogerie“ und „Sonstiges“ erscheint nicht mehr
- [ ] V5 `testHideCategoryRemovesItemFromStation` (AC-8, AC-9): GIVEN Seed WHEN in der Übersicht unter „Offen“ → „Zuordnen …“ → Gang „Drogerie“ für „Elektronik“, danach Gang-Detail → Häkchen von „Elektronik“ weg und stattdessen „Elektronik“ → „Ausblenden“ in der Übersicht THEN Abschnitt „Ausgeblendet“ enthält „Elektronik“, die Liste zeigt „Batterien“ wieder unter „Sonstiges“; „Einblenden“ → wieder „Offen“
- [ ] V6 `testAddAndDeleteStationFromSetup` (AC-7, AC-10): GIVEN Seed WHEN „Gang hinzufügen“ → „Lager“, danach im Detail „Gang löschen“ + Bestätigung THEN „Lager“ erscheint in der Gänge-Liste und verschwindet; ein Artikel „Batterien“ wird dazwischen per Auswahl dem Gang „Lager“ zugewiesen (Dialog) und liegt nach dem Löschen wieder in „Sonstiges“
- [ ] V7 `testSortModeReordersStations` (AC-6): GIVEN Seed WHEN „Sortieren“ → Zeile „Käse“ vor „Obst & Gemüse“ ziehen, Fertig THEN die Liste zeigt „Gouda“ oberhalb von „Apfel“ im Modus Kategorie (Abschnitt „Käse“ vor „Obst & Gemüse“)
- [ ] V8 `testRemoveStationsAndApplyTemplate` (ersetzt U7, AC-11, AC-13): GIVEN Seed WHEN „Gänge entfernen“ + Bestätigung THEN klassische Abschnitte (Salami unter „Fleisch & Wurst“), die Ansicht zeigt nur „Vorlage wählen …“ und „Gang hinzufügen“; WHEN „Vorlage wählen …“ → „Lidl“ THEN wieder Gang-Abschnitte (Salami unter „Kühltheke Fertiges“)

Bestehende D1-Tests (U1–U5, U8, T1–T19) laufen unverändert und müssen grün bleiben. U6/U7 sind durch V1/V8 ersetzt
(Offenlegung 2).

Durchlauf (Pflicht, Simulator, Stand dieser Änderung, als Nutzer): Laden ohne Gänge anlegen, „Kategorien
einrichten“ → „Vorlage wählen …“ → „Lidl“, ein Gang umbenennen, eine offene Kategorie zuordnen, eine
ausblenden, einen Gang löschen, Reihenfolge ziehen; Artikel hinzufügen und beide Sortiermodi prüfen;
Bildschirmfotos unter `docs/artifacts/feat-234-d2-kategorien-einrichten/`. Nichts auf Hennings Geräten ohne
sein ausdrückliches Wort.

## Acceptance Criteria

- **AC-1:** Das ···-Menü jeder Ladenliste enthält genau einen Eintrag „Kategorien einrichten“
  (`store.menu.setupStations`), auch in Läden ohne Gänge; „Lidl-Vorlage übernehmen“ und „Gänge entfernen“
  stehen nicht mehr im Menü. (V1)
- **AC-2:** Der Eintrag öffnet eine Ansicht mit Übersicht (Vorlage wählen, Gänge, Offen, Ausgeblendet,
  Gänge entfernen) und Gang-Detail wie im freigegebenen Entwurf 1–4; „Fertig“ schließt sie. (V1, V2)
- **AC-3:** Ein Gang lässt sich umbenennen und mit neuem Emoji versehen. Danach stehen Merkungen
  (`categoryAssignments`), von Hand gesetzte `item.category`, die eigene Kategorie, `routeModel.itemCategories`
  und die Gang-Konfiguration unter dem neuen Namen, die Gang-Reihenfolge bleibt, und kein Artikel rutscht nach
  „Sonstiges“. (S1, V2)
- **AC-4:** Eine laufende Abhak-Sitzung wird beim Umbenennen mitgezogen: `currentTrip.entries[].category`
  trägt den neuen Namen, und nach Abschluss der Sitzung lernt der Weg nur den neuen Namen. (S11)
- **AC-5:** Umbenennen und Anlegen werden abgelehnt (nichts ändert sich, Hinweis sichtbar), wenn der Name
  leer ist, schon ein anderer Gang ihn trägt, „Sonstiges“/„Other“ lautet oder die Marke enthält; nur
  Schreibweise/Emoji des eigenen Gangs bleiben erlaubt. Es wird nie zusammengeführt. (S2, S3, V3)
- **AC-6:** Gänge lassen sich per Ziehen (Knopf „Sortieren“) umordnen; die Reihenfolge wird sofort
  gespeichert (`save()`), und die Liste folgt ihr (Abschnitte und Einkaufsweg). (S7, V7)
- **AC-7:** Ein Gang lässt sich über „Gang hinzufügen“ am Ende der Gänge anlegen, auch in einem Laden ohne
  Gänge (danach `hasStations`); er steht außer bei festem Namen als eigene Kategorie. (S8, V6)
- **AC-8:** Jede feste Kategorie hat genau einen von drei Zuständen, ohne neues Feld: zugeordnet (in
  `builtIns` genau eines Gangs), ausgeblendet (in `hidden`), offen (keins von beiden). Zuordnen löst sie aus
  einem anderen Gang und aus `hidden`; Ausblenden löst sie aus allen Gängen; Einblenden macht sie offen. Die
  Liste folgt sofort: zugeordnete Kategorie → Gang-Abschnitt, offene oder ausgeblendete → „Sonstiges“. (S4, S5,
  V4, V5)
- **AC-9:** Trägt ein Gang den Namen einer festen Kategorie (Anlegen oder Umbenennen), übernimmt er diese
  automatisch; sie ist in anderen Gängen nicht antippbar („gehört zu Gang …“) und weder offen noch
  ausgeblendet wählbar, bis der Gang umbenannt oder gelöscht wird. Es gibt keinen stillen vierten Zustand.
  (S3, S5, S10)
- **AC-10:** Ein Gang lässt sich löschen (Wischen in der Übersicht oder „Gang löschen“ im Detail, jeweils mit
  Rückfrage): seine festen Kategorien werden offen, Stichwörter fallen weg; ist er eine eigene Kategorie,
  gilt das Löschen aus #85 (Artikel zurück auf automatische Kategorie, Merkungen und Wegzuordnung weg); ein
  Gang mit festem Namen lässt Artikel bei ihrer festen Kategorie und vergisst Merkungen auf diesen Namen.
  (S6, V6)
- **AC-11:** Das Löschen des letzten Gangs wird zu „Gänge entfernen“ (Rückfrage); danach ist der Laden ohne
  Gänge (`hasStations == false`), eigene Kategorien und Merkungen bleiben, und die Ansicht zeigt nur „Vorlage
  wählen …“ und „Gang hinzufügen“. (S8, V8)
- **AC-12:** Nach jeder Operation gelten die Invarianten: Gang-Namen eindeutig und nie „Sonstiges“/Marke,
  jede Angabe in `categoryOrder`, keine feste Kategorie in zwei Gängen, `hidden` und `builtIns`
  überschneidungsfrei, Name-gebundene Kategorien im eigenen Gang. (S9)
- **AC-13:** „Vorlage wählen …“ → „Lidl“ ersetzt die Gänge dieses Ladens nach der Rückfrage durch die
  Lidl-Vorlage (Zeitstempel jetzt, Gang-Namen als eigene Kategorien); Artikel, Merkungen und vorhandene
  eigene Kategorien bleiben unberührt. (S12, V8)
- **AC-14:** Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern
  (`LocalizationKeyParityTests` grün); in geteilten Läden erscheint die Hinweiszeile „Gänge bleiben bis zum
  Abgleich auf diesem Gerät.“ (S13)
- **AC-15:** Läden ohne Gänge verhalten sich unverändert (Menü ausgenommen: dort der neue Einstieg); es gibt
  keine Schemaänderung, kein neues `@Model`-Feld und keinen neuen `@AppStorage`-Schlüssel; alle D1-Tests
  außer den bewusst ersetzten U6/U7 und alle Bestandstests bleiben grün. (Regression: Gesamtlauf)

## Known Limitations

- **Stichwörter nur lesend** (2b). Gänge, die der Nutzer anlegt, haben keine Stichwörter; ihre Artikel
  kommen über Handwahl, Merkung und zugeordnete feste Kategorien hinein.
- **Gang-Löschen löscht eine gleichnamige eigene Kategorie aus #85 mit.** Gang-Namen sind zugleich eigene
  Kategorien (D1). Hatte der Nutzer vor D1 schon eine eigene Kategorie gleichen Namens, trifft das Löschen des
  Gangs auch sie (Artikel zurück auf die automatische Kategorie).
- **Umbenennen auf den Namen einer vorhandenen eigenen Kategorie (#85) dieses Ladens**, die nicht zu den
  Gängen gehört: der Gang übernimmt den Namen, Artikel mit dieser Kategorie von Hand landen im Gang. Kein
  Zusammenführen, keine Rückfrage (selten, Überführung in 2b).
- **Laufende Sitzung beim Löschen:** Einträge der Sitzung mit dem gelöschten Gang-Namen lernen nichts mehr.
- **Geteilte Läden:** Gänge bleiben auf dem Gerät (D3); Mitglieder sehen den Laden ohne Gänge, Merkungen
  reisen über `assignmentsJSON` und sind dort wirkungslos.
- **Ziehen** nur im Bearbeiten-Modus („Sortieren“), nicht über dauerhaft sichtbare Griffe wie im Entwurf.
- **Vorlage wählen** bietet in 2a nur „Lidl“ an; der Dialog statt eines eigenen Blatts ist für 2b
  erweiterbar (mehr Einträge), nicht bis zu einem eigenen Vorlagenblatt ausgebaut.
- **Gang-Namen der Vorlage deutsch** auch in der englischen Oberfläche (D1).
- Ob 35 Zeilen im Gang-Detail auf kleinen Geräten und bei sehr großer Schrift bequem bedienbar sind, ist nur im
  Simulator mit den Standardgrößen geprüft, nicht in AccessibilityXXXL.
- Nichts auf Hennings Geräten geprüft; kein CloudKit-Test.

## Alternative (verworfen, PO-Entscheidung 2026-10-31)

Entwurf 2b: eine **flache Liste aller 35 Kategorien** untereinander, rechts je Zeile ein Knopf mit dem Gang,
„Offen“ oder „Ausgeblendet“ (Auswahlmenü), Name/Emoji/Reihenfolge der Gänge in einer eigenen kurzen Liste.
Vorteil: etwa 60 Zeilen weniger, alle Zustände auf einen Blick. Nachteil: Der Inhalt eines Gangs ist nicht
zusammen sichtbar, und für Stichwörter (2b) bräuchte es das Gang-Detail trotzdem. Der PO hat die Übersicht
mit Gang-Detail (Entwurf 1–4) gewählt. Eine frühere Entscheidung wird dadurch nicht gekippt; D1 bleibt
bestehen.

## Ausblick (Durchgang 2b, nicht in dieser Spec)

- Vier Mustervorlagen (Discounter, Vollsortimenter, Drogerie, Baumarkt, „Vorschlag, bitte prüfen“), Daten aus
  `docs/context/gaenge-recherche-maerkte.md`, als weitere Einträge des Vorlagen-Dialogs.
- Stichwörter je Gang bearbeiten.
- Wischaktionen (Bearbeiten/Löschen) im Gang-Modus der `CategoryPickerView`; nutzen `renameStation` und
  `deleteStation` aus 2a.
- Überführung vorhandener eigener Kategorien (#85) als Gänge.
- D3: Abgleich geteilter Läden (siehe D1-Spec).

## Definition of Done

- [ ] Build erfolgreich, alle Unit- und UI-Tests grün (neue Tests waren vor der Umsetzung rot)
- [ ] Echter Durchlauf im Simulator mit Belegbildern registriert
- [ ] `CLAUDE.md`-Absatz „Laden-Stationen“ um Durchgang 2a ergänzt, Issue #234 aktualisiert
- [ ] Rebase auf `main` nach dem Merge von PR #240 (D1) vor Beginn der Umsetzung
- [ ] Kein CloudKit-Schritt nötig (bestätigt: nur `stationConfigJSON`, D1-Feld)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Fortführung des Musters „reine Logik in `StoreCategories`, dünne Hülle in `Store`, Ansicht
  ruft nur die Hülle“ (#85/#94/D1); keine neue Abhängigkeit, kein neues Feld, keine neue Schicht. Die
  Entscheidungen zum Umbenennen (mitziehen, ablehnen statt zusammenführen) und zu Name-gebundenen
  Kategorien sind hier begründet und nicht ADR-würdig.

## Changelog

- 2026-10-31: Initial spec created (Issue #234, Durchgang 2a).
