# Context: feat-234-laden-stationen

## Request Summary
Issue #234 (Übergabe 2026-10-30, Teil 2, Entwurf laut Issue vom PO bestätigt; ein Entwurfs-Artefakt
liegt nicht im Repo): Jeder Laden kann eine eigene, fest geordnete Liste von Kategorien („Stationen“)
haben, die Standard-Kategorien bündelt (z. B. „Kühltheke Fertiges“ ← Wurst, Tofu, Dips).
Weitere Teile: eine Lidl-Vorlage, Standard-Kategorien ausblenden, „Sonstiges“ als Auffang und der
Abgleich mit den Mitgliedern geteilter Läden.

## Anforderungen aus dem Issue (Kurzform)
1. Stationen je Laden, feste Reihenfolge, je Station zugeordnete Standard-Kategorien.
2. Laden mit Stationsliste: Kategorieauswahl zeigt nur seine Stationen.
3. Nicht zuordenbar → „Sonstiges“ am Ende; Zuordnung je Artikelname gemerkt (`categoryAssignments`).
4. ··· → „Kategorien einrichten“: anlegen, umbenennen, ziehen, Standard-Kategorien zuordnen, „Lidl-Vorlage übernehmen“.
5. Stationsreihenfolge fest; Abhaken lernt nur die Artikelreihenfolge innerhalb einer Station.
6. Jede Standard-Kategorie hat einen von drei Zuständen (zugeordnet / ausgeblendet / offen). Ausgeblendete erscheinen nicht in der Auswahl und nicht als Abschnitt, ihre Artikel landen unter „Sonstiges“. Die Lidl-Vorlage blendet Baumarkt-Kategorien aus.
7. Geteilte Läden: neues optionales Feld im `SharedStore`-Record (wie `categoriesJSON`), in `SharedStoreSchema.optionalExtensionFields`; Production-Schema der öffentlichen DB vor TestFlight.
8. Neue Store-Felder → privates CloudKit-Schema Dev+Prod vor TestFlight, `MirroredSchemaSnapshotTests`.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/StoreCategories.swift` | Reine Logik eigener Kategorien (#85/#94): `CustomCategoryEntry`, `resolve`, `merge`, `mergeAssignments`. Natürlicher Ort für Stations-Logik (läuft in App, Widget, Teilen-Erweiterung) |
| `SmartCart/Models/Store.swift` (176–555) | Felder `customCategoryEmojis/Dates`, `categoryAssignments/Dates`; `orderedCategories`, `sortInput`, `applyManualCategoryOrder`, `resolveCategory`, `add/update/deleteCustomCategory`, `rememberCategory`, `rememberedCategory`, `adoptCategory`, `pendingItems` (→ `ShoppingRoute.sortedIndices`, Z. 525) |
| `SmartCart/Models/ShoppingRoute.swift` | `categoryPositions`, `orderedCategories` (gelernt → `staticOrder` → alphabetisch), `sortedIndices` (Modi route/category/added), `applyManualCategoryOrder`, `renameCategory`. Hier muss „Station fest, innen gelernt“ greifen |
| `SmartCart/Services/AssignmentService+Category.swift` | `categoryOrder` (35 feste Kategorien, Rohwerte), `category(for:)`, `displayCategory`, `categoryEmoji` |
| `SmartCart/Views/Store/CategoryPickerView.swift` | Auswahl/Anlegen: Abschnitt „Bei <Laden>“ + „Alle Kategorien“; muss bei Stationsliste nur Stationen zeigen |
| `SmartCart/Views/Store/StoreDetailView.swift` | `groupedRegularItems` (Z. 197–204: gruppiert per `Store.displayCategory(of:)`, ordnet per `store.orderedCategories`), ···-Menü (Sortierung, „Reihenfolge anpassen“, Zurücksetzen; Z. 535–560), `reorderSections` (Z. 610ff) |
| `SmartCart/Views/Store/AddItemView.swift`, `EditItemView.swift` | Kategorie-Zeile mit Emoji/Titel (eigene vs. feste) |
| `SmartCart/Views/Home/HomeView.swift` (1205–1220), `AllItemsView.swift` (35–46) | Ladenübergreifende Gruppierung mit `categoryEmoji` |
| `SmartCart/Models/ShoppingItem.swift` (~175) | `init` setzt `rememberedCategory` des Ladens |
| `SmartCart/Services/SharedStoreService.swift` (106–220, 467) | `mergeIntoRecord` schreibt `categoriesJSON`/`assignmentsJSON` (nur bei `includeExtensionFields`), `pull` liest sie; `SharedStoreSchema.optionalExtensionFields` |
| `SmartCart/Services/SyncCoordinator.swift` (~280) | `apply` mergt Kategorien/Zuordnungen beim Pull |
| `RestockTests/StoreCategoriesTests.swift`, `ShoppingRouteTests.swift`, `ShoppingRouteManualOrderTests.swift` | Bestehende Unit-Tests der Bausteine |
| `RestockTests/SharedStoreSchemaTests.swift` | Drift-Test `optionalExtensionFields == ["categoriesJSON", "assignmentsJSON"]` (Z. 55, 249) — muss erweitert werden |
| `RestockTests/MirroredSchemaSnapshotTests.swift` | Feldliste von `Store` (Z. 21–22) — schlägt bei neuem Feld an |
| `RestockTests/SharedStoreMergeTests.swift` | Merge geteilter Läden ohne CloudKit |
| `RestockUITests/ShoppingRouteUITests.swift`, `ShoppingRouteLearningUITests.swift` | UI-Tests Kategorie-Modus/Verschieben/Lernen |
| `docs/cloudkit/private-schema-aktuell.ckdb` | Schema-Vorlage (enthält auch `SharedStore.categoriesJSON`, Z. 173) |

## Existing Patterns
- **Eigene Kategorien (#85)**: Name in `ShoppingItem.category` mit `categoryManuallySet = true`, Emoji/Datum am `Store` als additive Dictionaries; Löschvermerk = Eintrag ohne Emoji; Abgleich pro Name „späterer Stand gewinnt“.
- **Merken (#94)**: `categoryAssignments[itemKey]` + `categoryAssignmentDates`, „vergessen“ = `nil` mit Datum.
- **Reine Logik + dünne Store-Hülle**: `ShoppingRoute`/`StoreCategories` ohne SwiftData/UserDefaults, `Store` liest/schreibt nur.
- **Gelernte Reihenfolge pro Gerät** (`routeModel` in App-Group-UserDefaults), nicht synchronisiert. Stationen dagegen sollen synchronisiert werden (Punkt 7), also als SwiftData-Feld bzw. `SharedStore`-Feld.
- **Schema-Fallback (#121)**: Neue optionale Record-Felder kommen in `optionalExtensionFields`. Lehnt Production sie ab, wird einmal ohne sie gespeichert.
- **Abschnitte**: `groupedRegularItems` gruppiert per Anzeige-Kategorie; die Abschnittsreihenfolge kommt aus `orderedCategories` (gelernte Mittelposition).
- UI-Tests prüfen deutsche Texte und nutzen DEBUG-Seeds mit Aufräum-Argument im `tearDown()`.

## Dependencies
- Upstream: `AssignmentService.category(for:)`/`categoryOrder`/`displayCategory`/`categoryEmoji`, `ShoppingRoute.itemKey`, SwiftData-`Store`, App-Group-UserDefaults (`routeModel`).
- Downstream: `Store.pendingItems` (App, **Widget** und **Teilen-Erweiterung**: Stations-Logik muss in Dateien liegen, die alle drei Ziele kompilieren), StoreDetailView-Abschnitte und Verschieben, Kategorieauswahl in Add/Edit, Home/AllItems-Gruppierung, Live Activity/Widget-Reihenfolge, `SharedStoreService`/`SyncCoordinator`, Preisschätzung (zählt automatische Kategorie, darf nicht kippen).

## Existing Specs
- `docs/specs/models/store-custom-categories-and-manual-order.md` (#85/#86/#94): direkte Vorgängerin, wird fortgeschrieben oder abgelöst.
- `docs/specs/models/shopping-route-order.md` (#79): Lernen des Einkaufswegs.
- `docs/specs/models/non-food-categories.md` (#221): 35 feste Kategorien.
- `docs/specs/services/shared-store-schema-fallback.md` (#121): optionale Record-Felder.
- `docs/specs/models/private-cloudkit-schema.md` (#155): Schema-Pflicht vor TestFlight.

## Risks & Considerations
- **Feste Kategorien sind gröber als die Lidl-Stationen**: „Fleisch & Wurst“ ist eine einzige feste Kategorie, die Vorlage trennt aber „Frisches Fleisch & Fisch“ von „Kühltheke Fertiges (… Wurst …)“. „Tofu“, „Dips“, „Maultaschen“, „Kaffee, Tee“, „Säfte“ und „Käse“ (steckt in „Milchprodukte“) haben keine eigene feste Kategorie. Die Zuordnung „feste Kategorie → Station“ reicht deshalb allein nicht. Für die Feinteilung braucht es die Zuordnung je Artikel (`categoryAssignments`) oder Unterscheidung per Stichwort. Das ist eine **PO-Frage für die Analyse**.
- **Verhältnis zu den eigenen Kategorien aus #85**: Sind Stationen dieselben Objekte wie die heutigen eigenen Kategorien (plus Reihenfolge und Zuordnung), oder neu? Bestehende eigene Kategorien müssen weiter funktionieren bzw. sauber überführt werden.
- **Lernen nur innerhalb der Station** ändert `ShoppingRoute.sortedIndices` (Modus route: gelernte Position bisher global 0…1) und `orderedCategories`. Läden *ohne* Stationen dürfen sich nicht verändern (Regressionsgefahr für #79/#86 und die Bestandstests).
- **„Reihenfolge anpassen“ (Abschnitte)** schreibt heute Lernpositionen. Bei Stationen wird die Reihenfolge fest und ist in „Kategorien einrichten“ zu pflegen. Der Menüeintrag muss angepasst werden.
- **„Sonstiges“** gibt es heute nicht als Kategorie. Es braucht einen Namen und eine Lokalisierung (de/en) und darf mit keinem Artikelnamen kollidieren.
- **Ausblenden** wirkt nur in diesem Laden: In Auswahl und Abschnitten verschwindet die Kategorie, die Preisschätzung (automatische Kategorie) bleibt unverändert.
- **Sync**: Bei Reihenfolge und Zuordnung je Station reicht „späterer Stand pro Name gewinnt“ vielleicht nicht, denn eine Reihenfolge ist eine Liste. Möglich wäre ein ganzer Stand mit Zeitstempel („letzter gewinnt“). Neues Feld in `optionalExtensionFields`, Drift-Tests (`SharedStoreSchemaTests`, `MirroredSchemaSnapshotTests`), `.ckdb` aktualisieren, Dev+Prod deployen (öffentliche DB für `SharedStore`, private für `CD_Store`) vor TestFlight.
- **Umfang**: deutlich über 4–5 Dateien und ±250 LoC (Modell, Sortierlogik, Picker, neue Einrichtungs-Ansicht, Vorlage, Sync, Lokalisierung, Tests). Eine Aufteilung in Durchgänge oder eine Umfangsfreigabe durch den PO ist nötig. Für #98 gilt seit dem 2026-10-03: ein Ticket mit mehreren Durchgängen, die Limits gelten je Durchgang.
- **UI-Entwurf Pflicht** (Regel 2026-09-22): Die Einrichtungs-Ansicht, die geänderte Kategorieauswahl und die Abschnitte brauchen vor der Spec eine Entwurfsvorschau unter `docs/artifacts/feat-234-laden-stationen/`, mit „Heute“-Screenshot, Hell und Dunkel und Alternative. Laut Issue ist ein Entwurf bestätigt, liegt aber nicht im Repo.
- **pbxproj**: Neue Swift-Dateien (z. B. Einrichtungs-Ansicht, Stations-Logik) müssen von Hand eingetragen werden; Stations-Logik zusätzlich in Widget- und Erweiterungsziel.

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | `StationConfig` (Stationen `[{name, builtIns}]` in fester Reihenfolge, `hidden`, `date`), reine Auflösung Artikel → Station, Lidl-Vorlage, Ganzstand-Merge |
| `SmartCart/Models/Store.swift` | MODIFY | Feld `stationConfigJSON` (additiv, Standard leer), ladenbewusste Kategorie `stationCategory(of:)`, Stationsrang an `sortedIndices`/`orderedCategories`, Umbenennen/Löschen einer Station |
| `SmartCart/Models/ShoppingRoute.swift` | MODIFY | `sortedIndices`/`orderedCategories` mit optionalem `stationRank` (nil = heutiges Verhalten bitgenau); gelernte Position nur innerhalb der Station |
| `SmartCart/Views/Store/CategoryPickerView.swift` | MODIFY | Bei Stationsladen nur Stationen + „Sonstiges“ |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | Abschnitte nach Station inkl. „Sonstiges“ am Ende; ···-Menü „Kategorien einrichten“; „Reihenfolge anpassen“ (Abschnitte) entfällt bei Stationsladen |
| `SmartCart/Views/Store/StationSetupView.swift` | CREATE | „Kategorien einrichten“: anlegen, umbenennen, ziehen, Standard-Kategorien je Station (zugeordnet/ausgeblendet/offen), „Lidl-Vorlage übernehmen“ (pbxproj: nur App-Ziel) |
| `SmartCart/Views/Store/AddItemView.swift`, `EditItemView.swift` | MODIFY | Kategorie-Zeile zeigt Station |
| `SmartCart/Services/SharedStoreService.swift`, `SyncCoordinator.swift` | MODIFY | Feld `stationsJSON` push/pull, `optionalExtensionFields` |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Seed/Aufräumer für Stationsladen |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | MODIFY | Texte inkl. „Sonstiges“/„Other“ |
| Tests | CREATE/MODIFY | `StoreCategoriesTests`/neue `StationTests`, `ShoppingRouteTests` (Regression ohne Stationen), `SharedStoreSchemaTests`, `MirroredSchemaSnapshotTests`, `SharedStoreMergeTests`, neue UI-Testklasse |
| `docs/cloudkit/private-schema-aktuell.ckdb` | MODIFY | `CD_Store.CD_stationConfigJSON`, `SharedStore.stationsJSON` |
| CHECK only | – | `CheckoffQueue`, `LiveActivityService`, Widget (erben die Reihenfolge über `pendingItems`), `HomeView`/`AllItemsView` (ladenübergreifend, bleiben bei festen Kategorien), Preisschätzung (bleibt bei automatischer Kategorie) |

### Scope Assessment
- Files: ~11 Produktivdateien + Tests
- Estimated LoC: +700…900 Produktivcode, dazu Tests
- Risk Level: HIGH (Sortierung in App/Widget/Live Activity, Sync geteilter Läden, zwei CloudKit-Schemata)

### Technical Approach (Empfehlung)
- Stationen = bestehende eigene Kategorien (#85) plus eine Konfiguration je Laden (`StationConfig` als JSON-Feld am `Store`). Ohne Konfiguration verhält sich der Laden exakt wie heute.
- Auflösung (Regel, kein Modell): gemerkte Zuordnung → manuell gesetzte Station → feste Kategorie, die einer Station zugeordnet ist → „Sonstiges“ (auch für ausgeblendete und offene).
- „Sonstiges“ ist virtuell (nur Anzeige, lokalisiert), steht immer am Ende und erscheint nur, wenn es Artikel enthält.
- Sortierung: Stationsrang zuerst, darin die gelernte Artikelposition; die gelernte Abschnittsreihenfolge gilt in Stationsläden nicht. Die gelernten Artikelpositionen bleiben erhalten.
- Sync: Ganzstand mit Zeitstempel, der spätere gewinnt (Einrichtung ändert sich selten); neues optionales Feld `stationsJSON`.
- Migration: keine automatische. Beim ersten Öffnen von „Kategorien einrichten“ werden vorhandene eigene Kategorien als Stationen vorgeschlagen.
- Feste Kategorien sind gröber als die Lidl-Vorlage (Fleisch & Wurst eins, Käse in Milchprodukte, kein Tofu/Dips/Kaffee). Die Vorlage bildet die Grobstruktur ab, die Feinteilung entsteht durch Merken je Artikel. Alternativ eine Stichwortliste je Station (Regel), siehe offene Fragen.
- Durchgänge (Vorschlag Plan): D1 Logik+Sortierung+Feld, D2 Anzeige+Auswahl, D3 Einrichten-Ansicht, D4 Ausblenden+Lidl-Vorlage, D5 Sync+Schema.

### Alternatives
- A: Nur feste Reihenfolge + Zuordnung für eigene Kategorien, ohne Ausblenden und ohne Vorlage. Das ist etwa der halbe Umfang, kippt aber die Issue-Punkte 4 und 6.
- B: Vorlage ohne Ausblende-Zustand; alles nicht Zugeordnete geht nach „Sonstiges“. Das kippt Issue-Punkt 6 (Baumarkt-Kategorien verschwinden aus der Auswahl).
- Kippt in beiden Fällen und im Hauptweg: Spec #85/#86 AC7 und #79 AC7 (gelernte Abschnittsreihenfolge) gelten für Stationsläden nicht mehr; für Läden ohne Stationen bleiben sie.

### Dependencies
`Store.pendingItems` → HomeView, StoreCard, CheckoffQueue, LiveActivityService, Widget. Stationslogik muss in den Dateien liegen, die App, Widget und Teilen-Erweiterung kompilieren (`StoreCategories`, `Store`, `ShoppingRoute`).

### Technische Festlegungen (ohne PO-Frage)
- „Sonstiges“: Name „Sonstiges“/„Other“, immer letzter Abschnitt, nur sichtbar mit Artikeln, nicht hinter dringenden (dringende bleiben oben).
- Modus „Hinzugefügt“ bleibt unverändert.
- Ladenübergreifende Listen (Home, Alle Artikel) bleiben bei festen Kategorien.
- Bestehende gelernte Abschnittsreihenfolge wird in Stationsläden nicht gelesen, aber auch nicht gelöscht (Rückweg ohne Verlust).

### PO-Entscheidungen (2026-10-30)
- [x] Feinteilung: **Stichwortliste je Station** in der Lidl-Vorlage (Regel); Auflösung: gemerkte Zuordnung → manuell gesetzte Station → Stichwort einer Station → zugeordnete feste Kategorie → „Sonstiges“.
- [x] Feste Stationsreihenfolge in **„Einkaufsweg“ und „Kategorie“**; „Hinzugefügt“ unverändert.
- [x] **Drei Durchgänge**: D1 Stationen + Sortierung + Anzeige in der Liste (inkl. Feld, Auswahl nur Stationen); D2 „Kategorien einrichten“ + Lidl-Vorlage + Ausblenden; D3 Abgleich geteilter Läden + Schema.

### Open Questions
- [x] Entwurfsvorschau: `docs/artifacts/feat-234-laden-stationen/entwurfsvorschau.html`, veröffentlicht https://claude.ai/artifact/BCbeKenFfDrWuq8YqyTfXB. **PO 2026-10-30: Entwurf 1–3 freigegeben** (Kategorie-Modus mit Gang-Abschnitten; Einkaufsweg flach in Gang-Reihenfolge, Untertitel = Gang; Auswahl nur Gänge + „Sonstiges“). Alternative 2b verworfen.
- [ ] Entwurfsvorschau (Heute/Entwurf/Alternative, hell+dunkel) unter `docs/artifacts/feat-234-laden-stationen/` vor der Spec
