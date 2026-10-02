---
entity_id: store-custom-categories-and-manual-order
type: feature
created: 2026-10-01
updated: 2026-10-01
status: draft
workflow: feat-85-86-kategorien-verschieben
tags: [feature, store, category, sorting, shopping-route]
---

# Eigene Kategorien pro Laden (#85) und Verschieben von Hand (#86)

## Approval

- [x] Approved — PO, 2026-10-01, im Chat: „1C 2A 3 lernt 4. ja 5. ja“ zum Entwurf
  https://claude.ai/artifact/NpcWnNt9cwmDxmtS3EQukK

## Purpose

Ergänzt die Sortierung nach Einkaufsweg (#79, `docs/specs/models/shopping-route-order.md`):
eigene Kategorien, die nur in einem Laden gelten („Kühltheke hinten“ bei Lidl), und das
Korrigieren der gelernten Reihenfolge von Hand — Artikel im Modus Einkaufsweg, ganze Abschnitte
im Modus Kategorie.

## Source

- **Neu:** `SmartCart/Models/StoreCategories.swift` (`CustomCategoryEntry`, `StoreCategories`:
  auflösen, Emoji-Vorschlag, Suche, Abgleich), `SmartCart/Views/Store/CategoryPickerView.swift`
  (`CategoryPickerView`, `CustomCategoryEditor`)
- **Geändert:** `Store.swift` (Felder `customCategoryEmojis`, `customCategoryDates`,
  `categoryAssignments`; Kategorie- und Verschiebe-API), `ShoppingRoute.swift`
  (`positionsPreservingOrder`, `applyManualOrder`, `applyManualCategoryOrder`, `renameCategory`),
  `ShoppingItem.init` (gemerkte Kategorie), `AddItemView`, `EditItemView`, `StoreDetailView`,
  `SharedStoreService` (`categoriesJSON`), `SyncCoordinator.apply`, `HomeView`/`AllItemsView`
  (Emoji eigener Kategorien)
- **Tests:** `RestockTests/StoreCategoriesTests.swift`, `RestockTests/ShoppingRouteManualOrderTests.swift`,
  `RestockUITests/ShoppingRouteUITests.swift` (drei neue Tests)

## Eigene Kategorien (#85)

- **Anlegen (Variante C):** Die Zeile „Kategorie“ im Hinzufügen- und Bearbeiten-Dialog öffnet
  `CategoryPickerView` mit Suchfeld. Abschnitt „Bei <Laden>“ (eigene, mit Anzahl offener
  Artikel), darunter „Alle Kategorien“ (feste, nach Anzeigename). Trifft die Suche keine
  vorhandene Kategorie genau, steht oben „„<Name>“ bei <Laden> anlegen“ mit Emoji-Vorschlag
  (`StoreCategories.suggestedEmoji`). Ohne Laden gibt es nur feste Kategorien.
- **Auflösen:** Name getrimmt, Leerzeichenfolgen zusammengefasst; Vergleich ohne Groß-/
  Kleinschreibung und Akzente. Gleicht er einer festen Kategorie (Rohwert oder Anzeigename),
  wird die feste genommen; gleicht er einer vorhandenen eigenen, die vorhandene.
- **Speicher:** Name → Emoji (`customCategoryEmojis`, nur lebende) und Name → Zeitpunkt
  (`customCategoryDates`, auch Löschvermerke) am `Store` — additive SwiftData-Felder mit
  Standardwert, CloudKit-tauglich.
- **Verhalten wie eine normale Kategorie:** Der Artikel trägt den Namen in `category` mit
  `categoryManuallySet = true`; Gruppierung, gelernte Kategorie-Reihenfolge und Teilen
  funktionieren unverändert. Abschnittsüberschriften zeigen das eigene Emoji
  (`Store.categoryEmoji`), auch in den ladenübergreifenden Listen.
- **Merken:** Wählt man eine eigene Kategorie, merkt sich der Laden Artikelschlüssel →
  Kategorie (`categoryAssignments`). `ShoppingItem.init` setzt sie bei jedem neu angelegten
  Artikel, der mit diesem Laden angelegt wird (jeder Weg, der den Laden an `ShoppingItem.init` übergibt). Wählt man später
  eine feste Kategorie, wird die Zuordnung vergessen.
- **Laden wechseln:** Ohne die Kategorie im Ziel-Laden bekommt der Artikel die automatische.
- **Bearbeiten/Löschen:** Wischen in „Bei <Laden>“. Umbenennen nimmt Artikel, Zuordnungen und
  die gelernte Kategorie-Position mit; ein Name, der einer anderen Kategorie gleicht, führt beide
  zusammen. Löschen setzt die Artikel auf ihre automatische Kategorie zurück.
- **Preis:** Für die Schätzung zählt die automatische Kategorie (keine Katalogpreise für eigene).
- **Geteilte Läden:** Feld `categoriesJSON` im geteilten Record; pro Name gewinnt der spätere
  Stand, auch ein Löschvermerk (`StoreCategories.merge`), beim Push wie beim Anwenden eines Pulls.
  Die Zuordnungen fürs Merken bleiben beim Gerät des Nutzers (über die eigene CloudKit-Spiegelung).

## Verschieben von Hand (#86)

- **Variante A:** ···-Menü → „Reihenfolge anpassen“ (in den Modi Einkaufsweg und Kategorie, ab
  zwei nicht dringenden Artikeln). Die Liste zeigt dann nur die verschiebbaren Zeilen mit
  Griffen, „Fertig“ beendet. Für VoiceOver: Aktionen „Nach oben“/„Nach unten“.
- **Einkaufsweg:** Nicht dringende Artikel. `positionsPreservingOrder` behält die längste streng
  aufsteigende Teilfolge der bisherigen Positionen; die gezogene Zeile und alle unpassenden
  werden zwischen ihren Nachbarn interpoliert (am Rand ± 0,02). Artikel ohne eigene Position
  bekommen dabei eine, damit die Reihenfolge hält.
- **Kategorie:** Ganze Abschnitte. Eine gelernte Kategorie wird als Ganzes verschoben (alle
  Positionen um denselben Betrag, Reihenfolge im Abschnitt bleibt), bis ihr Mittelwert auf dem
  Zielplatz liegt; eine ungelernte bekommt den Zielplatz für ihre offenen Artikel.
- **Weiterlernen:** Eine Verschiebung ist ein Startwert. Kein Anheften — das Abhaken bei
  späteren Einkäufen passt die Positionen wie gewohnt an (α = 0,3).
- **Zurücksetzen:** ···-Menü → „Gelernte Reihenfolge zurücksetzen“ (mit Rückfrage): Modell und
  laufender Einkauf leer, bis neu gelernt ist gilt die Kategorie-Reihenfolge.
- Gilt wie der gelernte Weg nur auf diesem Gerät.

## Acceptance Criteria

1. Eine im Dialog angelegte Kategorie erscheint im Modus Kategorie als Abschnitt mit ihrem Emoji.
2. Ein Name, der einer festen Kategorie gleicht, legt keine eigene an.
3. Eigene Kategorien eines Ladens erscheinen in keinem anderen Laden.
4. Ein neu hinzugefügter Artikel landet in der gemerkten eigenen Kategorie seines Ladens.
5. Löschen setzt die Artikel auf die automatische Kategorie zurück; Umbenennen nimmt sie mit.
6. Ziehen im Modus Einkaufsweg ändert die Reihenfolge; nicht gezogene Artikel behalten ihre Position.
7. Ziehen eines Abschnitts im Modus Kategorie ändert die Abschnitts-Reihenfolge.
8. Nach einer Verschiebung lernt das Abhaken weiter.

## Known Limitations

- Die Zuordnungen fürs Merken werden nicht mit anderen Mitgliedern geteilter Läden abgeglichen.
- Im Verschiebe-Modus sind nur die verschiebbaren Zeilen sichtbar (keine dringenden, keine erledigten).
