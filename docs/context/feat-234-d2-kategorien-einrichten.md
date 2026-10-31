# Context: feat-234-d2-kategorien-einrichten (Issue #234, Durchgang 2)

Stand 2026-10-31. Grundlage ist der Stand von Durchgang 1 (PR #240, Zweig
`feat/234-laden-stationen-d1`, validiert, CI läuft). Dieser Arbeitsstand ist auf D1 vorgespult;
D2 wird erst nach dem Merge von #240 auf `main` umgesetzt (Rebase-Gate).

## Request Summary

Henning möchte die Gänge eines Ladens selbst einrichten: Ansicht „Kategorien einrichten“ (anlegen,
umbenennen, ziehen, feste Kategorien je Gang zuordnen, Ausblenden in drei Zuständen), dazu Vorlagen
außer Lidl (Discounter, Vollsortimenter, Drogerie, Baumarkt, „Vorschlag, bitte prüfen“). Die beiden
Zwischen-Menüeinträge aus D1 gehen darin auf.

## Vorgaben aus Issue, D1-Spec (Ausblick) und PO-Entscheidungen

- Issue #234 Punkt 4: ··· → „Kategorien einrichten“: anlegen, umbenennen, ziehen, Standard-Kategorien
  zuordnen, Knopf „Lidl-Vorlage übernehmen“.
- Punkt 6: Ausblenden – feste Kategorien in drei Zuständen (zugeordnet / ausgeblendet / offen);
  Ausgeblendete erscheinen weder in der Auswahl noch als Abschnitt, Artikel dort landen unter „Sonstiges“.
- D1-Spec „Ausblick D2“: ersetzt die zwei Zwischen-Menüeinträge; Stichwörter je Gang; Wischaktionen
  in der Auswahl; Überführung vorhandener eigener Kategorien (#85); Umbenennen zieht Merkungen und
  `stations[].name` mit.
- PO 2026-10-30 (Memory `issue-234-po-entscheidungen`): Vorlagen in D2 = Lidl + je eine Mustervorlage
  Discounter, Vollsortimenter, Drogerie, Baumarkt, in der Einrichtung als „Vorschlag, bitte prüfen“.
  Grund: Recherche `docs/context/gaenge-recherche-maerkte.md` belegt nur Grobes, 12 von 17 Ketten ohne Quelle.
- Regel 2026-09-22: Sichtbare Umgestaltung → Entwurfsvorschau (heute/Entwurf, hell/dunkel,
  Alternative) in `/20-analyse` vor der Spec, unter `docs/artifacts/feat-234-d2-kategorien-einrichten/`.
- Umfang: PO wollte je Durchgang ~250–350 Zeilen; D1 lief am Ende bei ~680 (Gate zählt Additionen inkl.
  UI-Testcode, Memory `issue-234-umfang-akzeptiert`). Schätzung in Gate-Zählweise vorlegen.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Models/StoreCategories.swift` | `Station`, `StationConfig` (`stations`, `hidden`, `date`), `station(forItemNamed:…)`, `resolveStation`, `lidlTemplate`, `otherStationMarker`; hier kommen weitere Vorlagen und reine Änderungsfunktionen (umbenennen, verschieben, zuordnen, ausblenden) hin |
| `SmartCart/Models/Store.swift` | `stationConfig`, `hasStations`, `applyStationConfig`, `removeStations`, `addStation`, `ensureCustomCategory`, `rememberCategory`/`rememberedCategory`, `updateCustomCategory`/`deleteCustomCategory` (Muster für Umbenennen/Löschen mit Merkungen, `routeModel`, `ShoppingRoute.renameCategory`) |
| `SmartCart/Models/ShoppingRoute.swift` | `renameCategory` im `routeModel`; `recordCheckOff` lernt unter Gang-Namen → beim Umbenennen eines Gangs mitziehen |
| `SmartCart/Views/Store/StoreDetailView.swift` | ···-Menü: `stationMenuItem` (D1-Zwischenlösung) und `withStationDialogs` werden durch einen Eintrag „Kategorien einrichten“ ersetzt; `reorderTick` als Auffrischung |
| `SmartCart/Views/Store/CategoryPickerView.swift` | Gang-Modus `stationSections` ohne Wischaktionen (D1); `CustomCategoryEditor` (Zeile ~241) als Vorbild/Baustein für Name+Emoji-Editor |
| `SmartCart/Views/Settings/StoreSetupView.swift` | Laden-Einrichtung (Zeilen, Emoji-Sheet, `onMove` mit `save()`), Muster für Listen mit Ziehen und Emoji-Wahl |
| `SmartCart/Models/Store.swift` `enum Category` (~Z. 850) | Ladentyp: `grocery`, `drugstore`, `hardware`, `variety`, `isHardwareStore`/`isVarietyStore` → Vorschlag, welche Vorlage zu einem Laden passt |
| `SmartCart/Services/AssignmentService+Category.swift` | `categoryOrder` (35 feste Kategorien), `displayCategory`, `categoryEmoji` → Liste für Zuordnen/Ausblenden |
| `SmartCart/SmartCartApp.swift` | DEBUG-Seeds `-seedStationStoreForUITests`/`-clearStationStoreForUITests` (D1), wiederverwendbar |
| `RestockTests/StoreStationsTests.swift`, `RestockUITests/StoreStationsUITests.swift` | D1-Tests; D2 ergänzt (U6/U7 prüfen die Zwischen-Menüeinträge und müssen angepasst werden) |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `station.*`-Schlüssel; neue Texte, `LocalizationKeyParityTests` |
| `Restock.xcodeproj/project.pbxproj` | neue Swift-Datei (Ansicht) von Hand eintragen, App-Ziel |

## Existing Patterns

- Reine Logik in `StoreCategories`/`ShoppingRoute` (statisch, testbar), dünne Hülle in `Store`, Ansicht ruft nur die Hülle (#85/#94/#234 D1).
- Konfiguration als Ganzstand mit Zeitstempel (`StationConfig.date`), jede Änderung setzt `date = Date()` und `Store.bumpRouteRevision()`.
- Umbenennen eigener Kategorien (`updateCustomCategory`): Artikel, Merkungen (`setAssignment`), `routeModel` (`ShoppingRoute.renameCategory`) mitziehen; Löschen: Artikel auf automatische Kategorie, Merkungen weg, gelernte Kategorie-Zuordnung entfernen.
- Gang-Namen, die keine festen Kategorien sind, existieren zusätzlich als eigene Kategorie (`ensureCustomCategory`) → Umbenennen/Löschen eines Gangs muss die eigene Kategorie mitführen.
- Listen mit Ziehen: `onMove` + sofortiges `save()` (Fehlerbefund #98 D6).
- Rückfragen per `confirmationDialog`, stabile `accessibilityIdentifier`, UI-Tests über sichtbare Texte und Kennungen, Seeds räumen im `tearDown` auf.
- Regeln vor Modell: Vorlagen sind statische Daten.

## Dependencies

- Upstream: `AssignmentService.categoryOrder`/`category(for:)`/`displayCategory`, `StoreCategories.normalizedName`/`compareKey`/`suggestedEmoji`, `Category.isHardwareStore`, SwiftData-`Store`.
- Downstream: `StoreDetailView` (Abschnitte, Sortierung), `CategoryPickerView` (Gang-Auswahl), `AddItemView`/`EditItemView` (Merken), `ItemRow` (Untertitel), Widget/Live Activity über `pendingItems`; D3 (Abgleich) liest später `StationConfig` als Ganzstand.

## Existing Specs

- `docs/specs/models/store-stations.md` – D1 (Datenmodell, Auflösung, Vorlage, Ausblick D2/D3); D2 schreibt diese Spec fort oder bekommt eine eigene Spec (`spec_file` vorher setzen, Memory `spec-freeze-ohne-spec-file`).
- `docs/specs/models/store-custom-categories-and-manual-order.md` (#85/#86), `docs/specs/models/shopping-route-order.md` (#79).
- Entwurf D1: `docs/artifacts/feat-234-laden-stationen/entwurfsvorschau.html` (Farben, Stil).

## Offene Fragen für die Analyse (keine PO-Fragen, technisch zu klären)

- Wo lebt „Kategorien einrichten“: eigenes Sheet aus dem ···-Menü der Liste (Issue) – zusätzlich aus Einstellungen → Laden-Einrichtung?
- Drei Zustände je fester Kategorie: Darstellung (je Gang zuordnen + eigener Bereich „Ausgeblendet“ / „Offen“) – Entwurf mit Alternative.
- Stichwörter je Gang bearbeitbar (Ausblick D1) – Umfang; ggf. nur anzeigen.
- Vorlage wählen bei bestehenden Gängen: ersetzen mit Rückfrage; Merkungen auf Gänge, die es danach nicht mehr gibt, fallen nach Regel 1 („veraltet → weiter“) durch – kein Datenverlust.
- Überführung eigener #85-Kategorien: als Gänge übernehmen anbieten?
- Gang löschen: Artikel mit Merkung/Kategorie dieses Gangs → Auflösung neu (Sonstiges oder Stichwort).

## Risks & Considerations

- **Umfang:** neue Ansicht (~250–300 Zeilen), Store-API (~80), vier Vorlagen (~120 Daten), Menü/Picker (~40), Strings, Unit- und UI-Tests → klar über 350 Zeilen. Teilung prüfen (z. B. D2a Einrichten + Ausblenden, D2b Vorlagen + Wischaktionen + Überführung) und dem PO in Gate-Zählweise vorlegen.
- **Umbenennen:** Gang-Name ist Identität – Merkungen (`categoryAssignments`), `item.category` (von Hand gewählt), eigene Kategorie, `routeModel.itemCategories` müssen konsistent mitwandern; sonst fallen Artikel still nach „Sonstiges“.
- **Namenskollision:** Umbenennen auf einen vorhandenen Gang oder auf „Sonstiges“ muss abgelehnt oder zusammengeführt werden (`resolveStation`).
- **Feste Kategorie in zwei Gängen:** Zuordnen muss sie aus dem alten Gang lösen (D1-Test T8-Invariante „keine feste Kategorie in zwei Gängen“).
- **D1-UI-Tests U6/U7** prüfen die Zwischen-Menüeinträge; sie müssen mit der neuen Ansicht angepasst werden (Bestand bewusst ändern, offenlegen).
- **Mustervorlagen ohne Beleg:** klar als Vorschlag kennzeichnen; Werte aus der Recherche, Lidl unverändert.
- **Geteilte Läden** bleiben bis D3 lokal; Hinweis in der Einrichtung ggf. nötig.
- **CloudKit:** kein neues Feld in D2 (alles in `stationConfigJSON`), also kein Schema-Schritt – zu bestätigen.
- Nichts auf Hennings Geräten ohne sein Wort.

## Analysis

Stand 2026-10-31 (3× Explore, 1× Plan; Entwurf https://claude.ai/artifact/XBzwq37We4oCYisq8otfvu,
Datei `docs/artifacts/feat-234-d2-kategorien-einrichten/entwurfsvorschau.html`).

### Type
Feature

### Befunde aus dem Code
- `StationConfig.hidden` wirkt schon in der Auflösung (`StoreCategories.stationForCategory`, einzige
  Lesestelle); gesetzt nur von `lidlTemplate`. Drei Zustände brauchen **kein neues Feld**:
  zugeordnet = in `builtIns` eines Gangs, ausgeblendet = in `hidden`, offen = keins von beiden.
  Alles in `stationConfigJSON` → **kein CloudKit-Schritt** in D2.
- Lidl-Vorlage: 17 feste Kategorien zugeordnet, 9 ausgeblendet (Baumarkt), 9 offen (Lebensmittel,
  Tierbedarf, Haushaltswaren, Küchenausstattung, Elektronik, Textilien, Schreibwaren, Spielzeug, Dekoration).
- `ShoppingRouteModel` hat nur `itemPositions` und `itemCategories`; Umbenennen zieht nur
  `itemCategories` (`ShoppingRoute.renameCategory`). Randfall: Eine laufende Abhak-Sitzung
  (`ShoppingTrip.entries[].category`) trägt den alten Gang-Namen → beim Umbenennen mitziehen oder als
  Grenze dokumentieren.
- `updateCustomCategory` (Guard `isCustomCategory`) greift NICHT für Gänge mit festem Namen
  („Obst & Gemüse“) → eigener Pfad `renameStation`.
- `stationForCategory` prüft `stationNamed(category)` vor `hidden`/`builtIns`: Ein Gang, der wie eine
  feste Kategorie heißt, fängt sie immer (stiller vierter Zustand).
- Gang-Konfiguration reist bisher in keinem Abgleich (`SharedStoreService`/`SyncCoordinator` ohne
  `stationConfigJSON`) → D3.
- Widget-Ziel kompiliert `Store.swift`, `StoreCategories.swift`, `ShoppingRoute.swift`,
  `AssignmentService+Category/+NonFood`, aber NICHT `AssignmentService.swift` → neue Logik darf nur
  `categoryOrder`/`category(for:)` nutzen; Teilen-Erweiterung kompiliert alle.
- D1-UI-Tests U6 (`testMenuEntriesInStoreWithStations`) und U7 (`testRemoveAndReapplyStations`) samt
  Helfern `menuItem`/`confirmMenuAction` und Kennungen `store.menu.applyStationTemplate`,
  `store.menu.removeStations`, `store.stations.confirmApply/confirmRemove` → bewusst anpassen, offenlegen.

### Affected Files (with changes) — Teil 2a
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | reine Funktionen auf `StationConfig`: umbenennen (Kollision über `resolveStation`), verschieben, zuordnen (löst aus anderem Gang und `hidden`), ausblenden, offen setzen, löschen (Kategorien werden offen) |
| `SmartCart/Models/Store.swift` | MODIFY | Hülle: `renameStation` (stations-Name, Merkungen mit Datum, `routeModel`, eigene Kategorie Tombstone, `item.category` bei Handwahl, Emoji), `deleteStation` (Muster `deleteCustomCategory`), ein Schreibpunkt `updateStationConfig` (`date`, `bumpRouteRevision`) |
| `SmartCart/Views/Store/StationSetupView.swift` | CREATE | Übersicht (Gänge mit `onMove`+`save()`, Wischen löschen, „Gang hinzufügen“, Abschnitte „Offen“/„Ausgeblendet“, „Vorlage wählen“, „Gänge entfernen“) + Gang-Detail (Name, Emoji, 35 Häkchen, Stichwörter nur lesend) |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | `stationMenuItem`/`withStationDialogs` → ein Eintrag „Kategorien einrichten“ + Sheet |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | MODIFY | neue `station.setup.*`-Schlüssel, D1-Menüschlüssel ersetzen |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Ansicht im App-Ziel |
| `RestockTests/StoreStationsTests.swift` | MODIFY | reine Funktionen, Umbenennen fester/eigener Gang-Name mit Merkungen und Weg, Löschen, Invariante T8 |
| `RestockUITests/StoreStationsUITests.swift` | MODIFY | U6/U7 auf neue Ansicht, neue Abläufe (anlegen, umbenennen, ziehen, zuordnen, ausblenden) |

Teil 2b (eigener Durchgang): 4 Mustervorlagen (Daten aus `docs/context/gaenge-recherche-maerkte.md`),
Stichwörter bearbeiten, Wischaktionen in `CategoryPickerView` (Gang-Modus, braucht `renameStation`/
`deleteStation` aus 2a), Überführung eigener #85-Kategorien.

### Scope Assessment
- Gesamt D2 (Gate-Zählweise, Additionen inkl. Tests): ca. 1.070 Zeilen.
- Teil 2a: ca. 550–650 Zeilen, 8 Dateien. Teil 2b: ca. 400–450.
- Risk Level: MEDIUM (Umbenennen/Löschen berühren Merkungen, gelernten Weg und Artikelkategorien; ein
  Fehler lässt Artikel still nach „Sonstiges“ fallen).

### Technical Approach
Empfehlung: Muster aus D1 fortführen (reine Logik in `StoreCategories`, dünne Hülle in `Store`,
Ansicht ruft nur die Hülle). Navigation: Übersicht der Gänge → Gang-Detail (Entwurf 1–4).
Alternative: flache Liste aller 35 Kategorien mit Gang-Knopf je Zeile (Entwurf 2b): ~60 Zeilen
weniger, aber Gang-Inhalt nicht zusammen sichtbar, für Stichwörter (2b) doch ein Detail nötig.

Technisch festgelegt (ohne PO, im Entwurf offengelegt):
- Umbenennen auf vorhandenen Gang-Namen, „Sonstiges“/„Other“ oder Marke → abgelehnt mit Hinweis
  (kein Zusammenführen).
- Gang mit Namen einer festen Kategorie (anlegen/umbenennen) → diese Kategorie wird automatisch in
  seine `builtIns` übernommen (aus anderem Gang/`hidden` gelöst); macht den stillen vierten Zustand
  sichtbar.
- Gang löschen → seine festen Kategorien werden „offen“; Löschen des letzten Gangs = „Gänge entfernen“
  mit Rückfrage.
- Vorlage bei vorhandenen Gängen → ersetzen nach Rückfrage; Merkungen/eigene Kategorien bleiben.
- Geteilte Läden: Hinweiszeile „Gänge bleiben bis zum Abgleich auf diesem Gerät“.
- Nur aus ··· der Liste (Issue Punkt 4), nicht zusätzlich aus Einstellungen → Laden-Einrichtung.

### Dependencies
Upstream: `AssignmentService.categoryOrder`/`category(for:)`/`displayCategory`/`categoryEmoji`,
`StoreCategories.normalizedName`/`compareKey`/`resolveStation`/`suggestedEmoji`, `ShoppingRoute.renameCategory`.
Downstream: `StoreDetailView` (Abschnitte, Sortierung), `CategoryPickerView`, `AddItemView`/`EditItemView`,
`ItemRow`, Widget/Live Activity über `pendingItems`; D3 liest `StationConfig` als Ganzstand.
Rebase-Gate: Umsetzung erst nach Merge von PR #240 (D1) auf `main`.

### Open Questions (PO)
- [x] Entwurf: **Empfehlung 1–4 (Übersicht + Gang-Detail)** — PO 2026-10-31. Alternative 2b verworfen.
- [x] Zuschnitt: **zwei Teile** — PO 2026-10-31. Dieser Workflow = Teil 2a (Ansicht mit Lidl-Vorlage,
  ca. 550–650 Zeilen). Teil 2b (4 Mustervorlagen, Stichwörter bearbeiten, Wischaktionen in der Auswahl,
  Überführung #85) als eigener Durchgang danach.
