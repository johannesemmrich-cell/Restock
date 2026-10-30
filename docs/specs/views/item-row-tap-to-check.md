---
entity_id: item-row-tap-to-check
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: feat-233-abhaken-per-tipp
tags: [feature, itemrow, storedetailview, swipe-actions, context-menu, accessibility, ui-tests]
---

# Abhaken per Tipp auf die ganze Zeile (Issue #233)

## Approval

- [ ] Approved — PO-Freigabe der Spec steht aus. Die Bedienung selbst hat der PO am 2026-10-30
  entschieden (Übergabe Teil 1: Tipp auf Zeile = abhaken/aufheben; Bearbeiten über Wischen links,
  Lang drücken, VoiceOver-Aktion und „Preis?“-Knopf). **Offenlegung Umfang:** Nur das Dateilimit ist
  überschritten: 10 Dateien (davon 2 Produktivdateien, dazu 1 reine DEBUG-Testdaten-Änderung) statt 4–5. Die Zeilen (ca. +140/−15) bleiben unter
  ±250. Drei der Dateien sind kleine Anpassungen bestehender UI-Tests (laut Patch je 2–4 geänderte
  Zeilen). Freigabe dieses Umfangs ist Teil des `approved`.

## Purpose

Beim Einkaufen öffnete ein Tipp auf die Artikelzeile den Bearbeiten-Dialog; ein knapp verfehltes
Kästchen bearbeitete statt abzuhaken. Künftig hakt ein Tipp irgendwo auf der Zeile ab bzw. hebt das
Abhaken auf. Bearbeiten bleibt erreichbar über Wischen nach links, Lang drücken, eine VoiceOver-Aktion
und den „Preis?“-Knopf in der Zeile.

Kein Fehler im Sinn einer Verschlechterung: Das Verhalten war so gebaut. Es ist eine PO-Entscheidung
zur Bedienung.

Bisheriges Verhalten (Stand main 1b190c8): `StoreDetailView` hängt an jede `ItemRow` ein
`.onTapGesture { editingItem = item }`; nur das Kästchen ruft `toggle(item:)`.

## Source

- **Dateien:** `SmartCart/Views/Components/ItemRow.swift`, `SmartCart/Views/Store/StoreDetailView.swift`
- **Identifier:** `ItemRow.onEdit`, `ItemRow.performToggle`, `StoreDetailView.pendingRow`,
  `StoreDetailView.editButton(for:)`, Abschnitt erledigter Artikel (`store.completedItems`).
- Vorlage: Patch `/Users/hem/Downloads/0001-Abhaken-per-Tipp-auf-die-ganze-Zeile-Bearbeiten-ber-.patch`
  (Übergabe), passt sauber auf main, noch nie kompiliert. Wird bei der Umsetzung als Grundlage
  eingespielt; die Spec gilt unabhängig von der Datei.
- Neu durch diese Änderung (existiert auf main noch nicht): `ItemRow.onEdit`, `ItemRow.performToggle`,
  `StoreDetailView.editButton(for:)`, `UITestItemEditor`. Bestehend: `StoreDetailView.pendingRow`,
  `item.action.check` / `item.action.uncheck` (Strings).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `StoreDetailView.toggle(item:)` | function | Abhaken/Aufheben inkl. Routen-Lernen und Live Activity; Zeilentipp ruft denselben Pfad wie das Kästchen |
| `StoreDetailView.editingItem` | state | steuert den Bearbeiten-Dialog |
| `ButtonStyle.pressable` | style | Kästchen bleibt eigener Button |
| `Localizable.strings` `action.edit` | resource | vorhanden (de „Bearbeiten“, en „Edit“), kein neuer Schlüssel |
| `XCUIElement.waitUntilHittable` (Erweiterung in `UITestWait.swift`) | test helper | Wartehilfe für die UI-Tests |
| `ShoppingRouteLearningUITests` (`checkbox(of:in:)`) | test | Bestandsprüfung Routen-Lernen über das Kästchen; Zugriff auf das Kästchen über `cells.containing(...).buttons.firstMatch` als Vorbild |
| `docs/specs/models/shopping-route-order.md` | spec | Abhaken lernt die Route; bleibt unverändert |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | `onEdit`, gemeinsame `performToggle`, `onTapGesture`, VoiceOver-Aktion „Bearbeiten“, „Preis?“ als Knopf |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | beide `ItemRow`-Aufrufe mit `onEdit`; `editButton(for:)` in Wischen (rechts) und Kontextmenü; alter Zeilentipp entfällt |
| `RestockUITests/UITestWait.swift` | MODIFY | Helfer `UITestItemEditor.open(_:in:)` (Lang drücken → „Bearbeiten“) |
| `RestockUITests/ShoppingRouteUITests.swift` | MODIFY | Dialog über den Helfer öffnen |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift` | MODIFY | dito |
| `RestockUITests/LegacyLearnedPriceResetUITests.swift` | MODIFY | dito |
| `SmartCart/SmartCartApp.swift` | MODIFY | nur DEBUG-Testmodus: Launch-Argument `-shoppingRouteUnpricedItemForUITests` legt in „Wegeladen“ zusätzlich einen Artikel ohne Katalogpreis an (damit „Preis?“ erscheint); ohne das Argument ändert sich nichts, nichts davon erreicht Nutzer (PO-Erlaubnis `override` 2026-10-30) |
| `RestockUITests/ItemRowTapUITests.swift` | CREATE | neue Tests für die Akzeptanzkriterien |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Testdatei registrieren |
| `CLAUDE.md` | MODIFY | Verhalten dokumentieren |

### Estimated Changes

- Files: 10 (Produktcode 2 + 1 DEBUG-Testdaten-Zeile in `SmartCartApp.swift`, UI-Tests 4 + 1 Registrierung, Doku 1; neue Datei `ItemRowTapUITests.swift`)
- LoC: +~150/−15 (Patch +64/−15, neue Tests ~80, Testdaten ~6). **Über dem Dateilimit; Freigabe steckt in `approved`.**
  Keine Aufteilung vorgesehen: Die Testanpassungen gehören untrennbar zur Verhaltensänderung.

### Nicht im Umfang

- `HomeView.categoryItemRow` (eigene Zeile), Datenmodell, CloudKit-Schema, Texte außer vorhandenem
  `action.edit`, Layout der Zeile.

## Acceptance Criteria

- **AC-1:** Ein Tipp auf den Namen einer offenen Zeile in der Ladenliste hakt den Artikel ab (er
  erscheint unter „Erledigt“) und öffnet den Bearbeiten-Dialog nicht.
- **AC-2:** Ein Tipp auf den Namen einer erledigten Zeile hebt das Abhaken auf (der Artikel ist wieder
  offen) und öffnet den Bearbeiten-Dialog nicht.
- **AC-3:** Ein Tipp auf das Kästchen löst genau einmal aus (kein doppeltes Umschalten durch Kästchen
  und Zeilentipp): Nach dem ersten Tipp zeigt die Zeile das Häkchen (Bild `checkmark`), nach dem zweiten
  nicht mehr; der Dialog öffnet nie. Das Kästchen hat kein eigenes Label; Tests greifen es über
  `app.cells.containing(.staticText, identifier: <Name>).buttons.firstMatch` an (wie
  `ShoppingRouteLearningUITests.checkbox(of:in:)`).
- **AC-4:** Wischen nach links zeigt bei offenen Zeilen neben „Löschen“ und „Dringend“, bei erledigten
  Zeilen neben „Löschen“ einen Knopf „Bearbeiten“; Tipp darauf öffnet den Bearbeiten-Dialog für genau
  diesen Artikel. Ein voller Wisch löscht weiterhin (Löschen bleibt die äußere Aktion). Der Test deckt
  die offene Zeile ab, die erledigte Zeile wird im Durchlauf (AC-9) gezeigt.
- **AC-5:** Lang drücken auf eine Zeile zeigt „Bearbeiten“ als ersten Eintrag des Kontextmenüs (offene
  und erledigte Zeilen, Kennung `item.action.edit`); Tipp darauf öffnet den Dialog. In geteilten
  Läden folgen darunter wie bisher die Zuweisungs-Einträge.
- **AC-6:** Zeigt die Zeile „Preis?“ (Kategorie-Pauschale; im Test über den Zusatzartikel des Launch-Arguments `-shoppingRouteUnpricedItemForUITests`, weil alle übrigen Testartikel Katalogpreise haben), öffnet ein Tipp genau darauf den
  Bearbeiten-Dialog mit Preisfeld und hakt nicht ab.
- **AC-7:** Das Kästchen bleibt für Bedienhilfen als Knopf erreichbar (in der Zugänglichkeits-Hierarchie
  als `button` innerhalb der Zeile, ohne Label, auffindbar wie in AC-3, automatisch geprüft). Zusätzlich trägt die Zeile die
  benannte VoiceOver-Aktion „Bearbeiten“; XCUITest kann benutzerdefinierte Aktionen nicht auslösen,
  deshalb wird diese Aktion im Durchlauf (AC-9) über den Accessibility Inspector des Simulators belegt
  (Beleg als Bild), nicht per Test.
- **AC-8:** Das Abhaken per Zeilentipp läuft im Code über denselben Pfad wie das Kästchen (eine
  gemeinsame Funktion `performToggle`, Routen-Lernen, Live Activity, Haptik/Animation hängen an
  `toggle(item:)`). Automatisch belegt ist die Gleichheit des Pfads nur indirekt: Die Bestandstests
  `ShoppingRouteUITests`, `AddItemQuantitySuggestionUITests`, `LegacyLearnedPriceResetUITests` (Dialog
  über `UITestItemEditor.open`) und `ShoppingRouteLearningUITests` (Routen-Lernen über das Kästchen)
  bleiben grün. Routen-Lernen und Live Activity per Zeilentipp werden im Durchlauf (AC-9) belegt.
- **AC-9:** Beweis im echten Durchlauf: Im Simulator mit dem Stand dieser Änderung werden Zeile
  antippen, Kästchen antippen, Wischen und Lang drücken einmal als Nutzer durchgespielt und belegt
  (Bildschirmfotos unter `docs/artifacts/feat-233-abhaken-per-tipp/`), einschließlich Beginn der Live
  Activity beim ersten Haken über den Zeilentipp und der VoiceOver-Aktion aus AC-7.

## Test Plan

### Automated Tests (TDD RED vor der Umsetzung)

Neue Klasse `ItemRowTapUITests` (App über `UITestLaunch.start`, gesäter Laden mit mindestens zwei
Artikeln, einer mit „Preis?“):

- [ ] `testTapOnRowChecksItemWithoutOpeningEditor` (AC-1)
- [ ] `testTapOnCompletedRowUnchecksItem` (AC-2)
- [ ] `testTapOnCheckboxTogglesExactlyOnce` (AC-3: zwei Schritte, offen → erledigt → offen, je genau
  eine Änderung der Zähler „offen/erledigt“)
- [ ] `testCheckboxIsExposedAsButton` (AC-7, automatisierbarer Teil)
- [ ] `testSwipeLeftShowsEditAndOpensEditor` (AC-4, inkl. Löschen noch vorhanden)
- [ ] `testLongPressShowsEditFirstAndOpensEditor` (AC-5)
- [ ] `testPricePromptOpensEditorWithoutChecking` (AC-6)

RED-Beleg: Auf dem Stand ohne Patch scheitern AC-1/2/4/5/6 (Zeilentipp öffnet den Dialog, „Bearbeiten“
fehlt). AC-3 und der Test zu AC-7 sind kein RED, sondern Schutz: AC-3 fällt erst durch einen Fehler im
Patch rot (Doppelauslösung); `testCheckboxIsExposedAsButton` ist auf dem alten Stand schon grün und
schützt gegen ein Wegfallen des Knopfs. Die VoiceOver-Aktion selbst ist per UI-Test nicht belegbar (siehe
AC-7) und wird im Durchlauf (AC-9) gezeigt.

### Bestehende Tests

- [ ] `ShoppingRouteUITests`, `AddItemQuantitySuggestionUITests`, `LegacyLearnedPriceResetUITests`,
  `ShoppingRouteLearningUITests` grün (AC-8)

### Durchlauf (Pflicht, AC-9)

Echter Lauf im Simulator, Gerätetests nur auf Hennings ausdrückliches Wort.

## Known Limitations

- **Lang drücken in XCUITest auf iOS 26:** Elementtyp und Kennung der Kontextmenü-Einträge sind nicht
  dokumentiert; `UITestItemEditor.open` sucht über `app.buttons` mit Kennung ODER Beschriftung. Das
  ist ungeprüft und wird im ersten Lauf bestätigt oder korrigiert (Quelle: Recherche in
  `docs/context/feat-233-abhaken-per-tipp.md`).
- Neue Nutzer müssen lernen, dass Bearbeiten nicht mehr per Tipp geht; kein Hinweistext in der App
  (nicht beauftragt).
- Der Patch verlässt sich für VoiceOver auf die benannte Aktion; der Zeilentipp selbst trägt keine
  Button-Eigenschaft, das Kästchen bleibt der Button.

## Alternativen (verworfen)

1. Nur die Tippfläche des Kästchens vergrößern, Zeilentipp bleibt Bearbeiten: löst das Ausgangsproblem
   nur halb.
2. Bearbeiten nur per Wischen: spart kaum Code (Kontextmenü existiert), nimmt Lang drücken weg.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Build erfolgreich (`xcodebuild`, Simulator)
- [ ] Jede Acceptance Criterion ist durch einen automatischen Test, den Bestandslauf oder (nur die
  VoiceOver-Aktion aus AC-7, Routen-Lernen/Live Activity per Zeilentipp aus AC-8 und die erledigte Zeile
  aus AC-4) den Durchlauf AC-9 belegt; die neuen Tests waren vor der Umsetzung rot (AC-1/2/4/5/6)
- [ ] `ItemRowTapUITests` und die drei Bestandsklassen laufen grün
- [ ] Echter Durchlauf im Simulator mit Belegbildern unter `docs/artifacts/feat-233-abhaken-per-tipp/`
  (AC-9) ist registriert
- [ ] `CLAUDE.md` enthält den Absatz „Abhaken beim Einkaufen“; Ticket #233 ist aktualisiert

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Bedienänderung in zwei bestehenden Ansichten nach vorhandenem Muster
  (Wischaktionen, Kontextmenü); keine neue Architektur, keine neue Abhängigkeit.

## Changelog

- 2026-10-30: Zehnte Datei `SmartCartApp.swift` (DEBUG-Testdaten für AC-6) mit PO-`override` ergänzt; Dateizahl 9 → 10.
- 2026-10-30: Erstfassung (Issue #233, aus Übergabe Teil 1).
