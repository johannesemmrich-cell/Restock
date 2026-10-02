---
entity_id: shopping-route-order
type: feature
created: 2026-09-30
updated: 2026-09-30
status: draft
workflow: feat-79-einkaufsweg-sortierung
tags: [feature, store, sorting, shopping-route]
---

# Ladenliste nach gelerntem Einkaufsweg sortieren (Issue #79)

## Approval

- [x] Approved — PO, 2026-09-30, im Chat („Ja, passt. Auch die Reihenfolge der Kategorien mit
  einzubeziehen ist eine gute Idee“), inkl. der vorgeschlagenen Voreinstellungen (pro Gerät,
  alte Werte verwerfen).

## Purpose

Die offenen Artikel eines Ladens stehen in der Reihenfolge, in der der Nutzer sie bei früheren
Einkäufen dort abgehakt hat (sein Weg durch den Laden). Wählbar pro Laden neben der Gruppierung
nach Kategorien, deren Reihenfolge ebenfalls aus dem Weg gelernt wird.

## Source

- **Neu:** `SmartCart/Models/ShoppingRoute.swift` — `StoreSortMode`, `ShoppingTrip`,
  `ShoppingRouteModel`, `ShoppingRoute` (reine Logik; App, Widget und Share Extension)
- **Geändert:** `SmartCart/Models/Store.swift` (`sortMode`, `routeModel`, `currentTrip`,
  `recordCheckOff`, `recordUncheck`, `finalizeStaleTrip`, `orderedCategories`, `pendingItems`;
  `recordCompletionOrder` entfernt), `SmartCart/Views/Store/StoreDetailView.swift` (···-Menü,
  Aufzeichnung, Gruppen-Reihenfolge), `SmartCart/Views/Home/HomeView.swift`,
  `SmartCart/Views/Settings/SettingsView.swift` (globaler Schalter entfernt),
  `SmartCart/Services/HabitService.swift` (`formalKey` delegiert an `ShoppingRoute.itemKey`),
  `SmartCartWidgets/ShoppingListWidget.swift` (Drain + Tipp im Widget zeichnen ebenfalls auf)
- **Tests:** `RestockTests/ShoppingRouteTests.swift`

## Vorher (Mängel)

| Mangel | Ursache |
|---|---|
| Zählung beginnt nach Verlassen der Ladenansicht bei 0 | Reihenfolge nur in `@State completionOrder` |
| Kurze und lange Einkäufe verzerren sich | absolute Position statt relativer |
| Nachträgliches Abhaken zu Hause wird gelernt | keine Erkennung |
| Neue Artikel immer am Ende | Standardwert 999 |
| Ein Ausreißer halbiert den Wert | Mittelung 50/50 |
| Kategorien in fester Reihenfolge | `AssignmentService.categoryOrder` |
| Nicht pro Laden wählbar | globaler Schalter in den Einstellungen |

## Verhalten

### Sortiermodus (`StoreSortMode`, pro Laden, ···-Menü → „Sortieren“)

- **Einkaufsweg** (`route`): gelernte Position; ein nie abgehakter Artikel erhält die mittlere
  Position seiner Kategorie in diesem Laden; ohne beides dahinter in Kategorie-Reihenfolge.
- **Kategorie** (`category`): Abschnitte je Kategorie, Kategorien nach ihrer mittleren gelernten
  Position, ungelernte dahinter in `AssignmentService.categoryOrder`, unbekannte alphabetisch;
  innerhalb einer Kategorie nach gelernter Position.
- **Hinzugefügt** (`added`): Hinzufügedatum.
- In allen Modi: Dringende zuerst, Gleichstand nach Hinzufügedatum.
- Gespeichert in der App-Group-Suite unter `sortMode_<storeID>`. Ohne Wert gilt
  `migratedDefault`: früher „Nach Kategorie gruppieren“ → Kategorie, sonst globaler Schalter
  „Automatisch nach Einkaufsreihenfolge sortieren“ an → Einkaufsweg, aus → Hinzugefügt.

### Lernen

- Jeder Haken in der Ladenansicht wird an den laufenden Einkauf (`ShoppingTrip`, App-Group
  `shoppingTrip_<storeID>`) angehängt; pro Einkauf zählt jeder Artikel nur beim ersten Haken.
  Rücknahme entfernt ihn aus dem Einkauf.
- Ein Einkauf endet, wenn seit dem letzten Haken mehr als 30 Minuten vergangen sind. Gelernt wird
  beim nächsten Haken oder beim Öffnen der Ladenansicht (`finalizeStaleTrip`, nach dem Nachtragen
  der Dynamic-Island-Warteschlange).
- Aus der Warteschlange nachgetragene Haken (`batched`) setzen den laufenden Einkauf fort; nur
  ein Einkauf, der älter als 6 Stunden ist, wird vorher abgeschlossen (`batchedTripGap`).
- Der Sortiermodus wird beim ersten Lesen in der Haupt-App festgeschrieben, damit Widget und
  Share Extension (die `groupByCategory` aus `UserDefaults.standard` nicht sehen) gleich sortieren.
- Auch Abhaken/Zurücknehmen im Bearbeiten-Sheet (`EditItemView`) wird aufgezeichnet.
- Position im Einkauf: `index / (n − 1)` ∈ 0…1. Erstbeobachtung wird übernommen, danach
  gleitendes Mittel `alt + 0,3 · w · (neu − alt)` mit `w = min(1, (n − 1) / 4)`: Einkäufe unter
  5 Artikeln lernen anteilig schwächer.
- Einkäufe mit weniger als 2 Artikeln werden nicht gelernt.
- **Zu Hause nachgetragen:** Bei mindestens 3 direkt angetippten Haken und mindestens 80 % der
  Abstände unter 2 s wird der Einkauf verworfen. Aus der Dynamic-Island-/Widget-Warteschlange
  nachgetragene Haken (`batched`) zählen für die Reihenfolge, nicht für diese Prüfung.
- Artikelschlüssel: `ShoppingRoute.itemKey` = `ReplenishmentItemIdentity.formalKey` (eine
  Implementierung). Bon-Aliase werden nicht aufgelöst, weil `ReceiptAliasService` in Widget und
  Share Extension fehlt; offene Listenartikel tragen ohnehin den Listennamen, nicht den Bontext.
- Gelerntes Modell pro Gerät (App-Group `shoppingRoute_<storeID>`), nicht in SwiftData/CloudKit
  und nicht in geteilten Listen.
- Kassenbon-Reihenfolge fließt nicht ein (Reihenfolge an der Kasse, nicht im Laden).
- `Store.itemOrderMap` wird weder gelesen noch geschrieben (Schemafeld bleibt); bis neu gelernt
  ist, gilt die Kategorie-Reihenfolge.
- `Store.routeRevisionKey` wird bei jeder Änderung hochgezählt; `StoreDetailView` und `HomeView`
  beobachten ihn per `@AppStorage`.

## Acceptance Criteria

1. Normalisierte Position unabhängig von der Einkaufsgröße.
2. Späterer Einkauf verschiebt eine Position um 30 % (volles Gewicht) bzw. anteilig weniger.
3. Nachträgliches Abhaken im Sekundentakt wird nicht gelernt; zwei schnelle Nachbarn im Laden schon.
4. Verlassen und Wiederöffnen der Ansicht innerhalb von 30 Minuten setzt den Einkauf fort.
5. Unbekannter Artikel steht bei seiner Kategorie, nicht am Ende.
6. Ohne Gelerntes: Kategorie-Reihenfolge.
7. Kategorie-Modus zeigt die Abschnitte in gelernter Ladenreihenfolge.
8. Bisherige Einstellungen bestimmen den Anfangsmodus.

## Known Limitations

- Die Ladenkarten-Vorschau auf der Startseite übernimmt den Modus des Ladens (flach sortiert).
- Ein Einkauf, der seit über 30 Minuten ruht, wird beim Öffnen der Ladenansicht, bei der Rückkehr
  in die App mit offener Ladenansicht (#94) oder beim nächsten Haken gelernt. Nur wer die App über
  30 Minuten durchgehend im Vordergrund auf der Liste lässt, sieht sie beim ersten Haken des
  nächsten Einkaufs einmal neu sortiert.
- App und Widget schreiben Einkauf und Modell ohne prozessübergreifende Sperre (wie der
  bestehende Drain); bei gleichzeitigem Abhaken kann ein einzelner Eintrag verloren gehen.
- Die Einstellungsseite „Benachrichtigungen“ ist nur noch im Developer Mode sichtbar, weil der
  einzige andere Eintrag (der globale Sortierschalter) entfallen ist.
