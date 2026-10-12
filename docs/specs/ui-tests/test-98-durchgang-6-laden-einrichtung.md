---
entity_id: test-98-durchgang-6-laden-einrichtung
type: test
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: test-98-durchgang-6-laden-einrichtung
tags: [test, ui-test, store-setup, stores, drag-reorder, delete, destructive]
---

# UI-Test-Durchlauf: Laden-Einrichtung (Issue #98, Durchgang 6)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Punkt 7 aus #98, zweiter Teil. `StoreSetupView` (Laden-Einrichtung, 47 % Coverage laut Messung vom
2026-10-02) ist der Ort, an dem ein Nutzer Läden deaktiviert, wieder aktiviert, löscht, hinzufügt, die
Besuchshäufigkeit ändert und die Reihenfolge der Kacheln festlegt. Heute berührt nur ein einziger Test
diese Ansicht (`RestockUITests.swift`, Zeilen 160–200: Läden einrichten → Browse → Lidl hinzufügen →
Sheet wegziehen). Unbewiesen ist:

1. **Deaktivieren/Aktivieren:** Ein deaktivierter Laden verschwindet aus „Aktiv“, steht unter „Inaktiv“
   **und** seine Kachel verschwindet von der Startseite (die Startseite liest `isActive` über `@Query`;
   die Ansicht schreibt dafür eigens sofort mit `context.save()`). Aktivieren macht das rückgängig.
2. **Löschen:** Löschen gibt es nur für inaktive Läden (Wischgeste → „Löschen“ → Rückfrage „Markt
   löschen?“). „Abbrechen“ muss den Laden stehen lassen, „Löschen“ in der Rückfrage ihn entfernen. Das
   ist die destruktivste Aktion der App und lief noch nie in einem Test.
3. **Eigenen Laden hinzufügen:** „Eigenen Laden hinzufügen“ → Name → „Hinzufügen“ legt einen Laden an,
   dessen Kachel auf der Startseite erscheint; „Hinzufügen“ ist bei leerem Namen gesperrt.
4. **Besuchshäufigkeit ändern:** Die Auswahl „Besuche pro Woche“ in der Zeile ändert die Angabe im
   Label der Kachel auf der Startseite.
5. **Reihenfolge ziehen:** Im Modus „Bearbeiten“ lassen sich aktive Läden ziehen (`onMove` setzt
   `sortIndex`). Unbewiesen ist, dass die gezogene Reihenfolge nach „Fertig“ gilt, auf der Startseite als
   Kachelreihenfolge ankommt und einen App-Neustart überlebt.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 6 = `StoreSetupView`. Punkte 5 (Tagesmitteilung)
und 6 (Siri/Widget) bleiben offen für einen späteren Durchgang.

**Messung vor der Spec (PO-Entscheidung 2026-10-12: erst am Simulator probieren, stabil → im Durchgang):**
Das Ziehen der Reihenfolge wurde in `/20-analyse` mit einem Wegwerf-Test (zurückgenommen, nicht im Diff)
im Simulator Restock-Validate gemessen. Weg: Seed → „Verwalten“ → „Bearbeiten“ → Verschiebegriffe →
`press(forDuration: 0.8, thenDragTo:)` vom ersten Griff auf 1,6 Zeilenhöhen unter den zweiten Griff →
„Fertig“.

| Lauf | Bedingung | Reihenfolge vorher | nachher | Ergebnis |
|------|-----------|--------------------|---------|----------|
| 1 | ohne Last | dm, Lidl | Lidl, dm | grün |
| 2 | ohne Last | dm, Lidl | Lidl, dm | grün |
| 3 | 6 Rechenprozesse Last | dm, Lidl | Lidl, dm | grün |
| 4 | 6 Rechenprozesse Last | Lidl, dm | dm, Lidl | grün |
| 5 | Last (Lauf bis „Fertig“ gelesen, dann Zeitlimit des Hintergrundjobs) | Lidl, dm | dm, Lidl | Ziehen ok, Gesamtlauf abgebrochen |

Befund: Ziehen 4/4 vollständig, 5/5 im Ziehschritt stabil, auch unter Last. Grenze der Messung: Läufe
3–5 dauerten unter Last über 5 Minuten, sechs geplante Läufe wurden nicht fertig; die Reihenfolge nach
Neustart und auf der Startseite wurde nicht gemessen (kommt in den Test, AC-7).

Kein Modell beteiligt, alles deterministisch (Regel vor Modell: nichts hier braucht ein Sprachmodell).

**Offene Grenzen (gelten für jede positive Zusage dieses Durchgangs):**

- **„Teilen beenden“ beim Löschen eines geteilten Ladens** (`SharedStoreService.leaveBeforeDeleting`,
  nur bei `shareID != nil`) braucht CloudKit und ist nicht automatisiert prüfbar. Der Test löscht nur
  nicht geteilte, gesäte Läden.
- **Emoji ändern:** Das Sheet „Emoji ändern“ wird nur geöffnet und mit „Abbrechen“ geschlossen; die
  **Emoji-Eingabe** ist ungeprüft (Emoji-Tastatur im Simulator unsicher; Memory Issue #46: Emoji im
  Label der Kachel hängt sich vorn an und bricht `BEGINSWITH`-Prüfungen).
- Der **Farbwähler** (`ColorPicker`) in „Eigenen Laden hinzufügen“ ist nicht getestet; die Kategorien-
  Auswahl dort ebenfalls nicht.
- Punkte **5 (Tagesmitteilung) und 6 (Siri/Widget)** aus #98 bleiben offen.

## Source

- **Neu:** `RestockUITests/StoreSetupUITests.swift` — eine Klasse mit sieben Tests (S1–S7), tearDown mit
  `-clearQuickAddAssignmentSeedForUITests` (~150–180 LoC, nur Tests).
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — neue Testdatei in `PBXBuildFile`,
  `PBXFileReference`, `PBXGroup` (RestockUITests) und `PBXSourcesBuildPhase` des UITests-Targets
  (~10 LoC; vier Stellen laut `CLAUDE.md` „Adding new Swift files“).
- **Neu:** diese Spec.
- **Nicht geändert (ausdrücklich):** `StoreSetupView`, `StoreRow`, `AddCustomStoreView`,
  `BrowseStoresView`, `HomeView`, `SmartCartApp` (die DEBUG-Seeds `-seedQuickAddAssignmentForUITests` und
  `-clearQuickAddAssignmentSeedForUITests` existieren bereits und genügen), `Store`, alle Texte und
  Layout. **Kein Produktcode**, keine neue `Info.plist`-Berechtigung, kein neuer `@AppStorage`-Schlüssel,
  keine Scheme-Änderung, kein neues Launch-Argument.
- **Bestehender Test bleibt:** `RestockUITests.swift` Zeilen 160–200 (Browse → Lidl hinzufügen) wird
  ergänzt, nicht ersetzt und nicht verändert.

Geschätzter Umfang: 3 Dateien (Test, `project.pbxproj`, Spec), ca. +160–190 LoC, davon 0 Produktcode.
Das liegt unter den Limits (4–5 Dateien, ±250 LoC). Wird ein **Produktfehler** gefunden (wie in
Durchgang 5): Mitfixen nur mit Wort des PO, sonst Ticket.

## Verhalten

### Befunde aus dem Code (gegen die Analyse geprüft)

- **Einstieg:** Auf der Startseite öffnet der Knopf „Verwalten“ (`home.stores.manage`, nur im Kartenmodus
  `!listMode`) die `StoreSetupView` als Sheet (`NavigationStack { StoreSetupView() }`). Im leeren Zustand
  dient „Läden einrichten“ demselben Zweck. Der Test nutzt „Verwalten“ (Seed legt Läden an). Titel der
  Ansicht: „Läden“.
- **Aufbau der Liste:** Abschnitt „Aktiv“ (Zeilen aus `orderedActiveStores`, Kopie von
  `allStores.filter(isActive)` sortiert nach `sortIndex`); Abschnitt „Inaktiv“ nur, solange es inaktive
  Läden gibt; ein Abschnitt ohne Überschrift mit dem Link „Läden aus anderen Ländern hinzufügen“ und dem
  Knopf „Eigenen Laden hinzufügen“. Toolbar rechts: „Bearbeiten“ ↔ „Fertig“ (`editMode`).
- **Wischaktionen (trailing):** In „Aktiv“ **nur** „Deaktivieren“ (`pause.circle`, sofort `save()`). In
  „Inaktiv“ „Löschen“ (destruktiv, setzt nur `storeToDelete`) und „Aktivieren“ (`play.circle`, sofort
  `save()`). Löschen läuft daher immer: deaktivieren → wischen → „Löschen“ → Rückfrage.
- **Rückfrage:** `confirmationDialog` „Markt löschen?“ mit Meldung `"<Name>" und alle zugehörigen Artikel
  werden dauerhaft gelöscht.`, Knöpfe „Löschen“ (destruktiv) und „Abbrechen“. „Löschen“ löscht synchron und
  speichert sofort; `leaveBeforeDeleting` läuft nur bei `shareID != nil` (offene Grenze).
- **Zeilenschalter:** `Toggle("", isOn: $store.isActive)` mit `labelsHidden()` und `onChange` → `save()`
  ist ein zweiter Weg zum Deaktivieren/Aktivieren. Das Label ist leer; aus dem Code lässt sich **nicht**
  belegen, ob XCUITest ihn je Zeile eindeutig findet (erwartet: `cell.switches.firstMatch`, da jede Zeile
  genau einen Schalter hat). **Wird in TDD-RED geprüft; findet er sich nicht eindeutig, wird nur der
  Wischweg getestet** (Schalter als offene Grenze im Ticketkommentar).
- **Besuchshäufigkeit:** Nur bei aktiven Läden zeigt die Zeile einen Picker „Besuche pro Woche“ (Menü).
  Optionen aus `VisitFrequency` (acht Stufen: „1x im Monat“, „2x im Monat“, „1x pro Woche“, „2x pro
  Woche“, „3x pro Woche“, „4x pro Woche“, „5x pro Woche“, „Täglich“). Die Zeile zeigt die aktuelle Stufe
  auch als Untertitel. Die Kachel auf der Startseite trägt die Stufe im Label (Seed: „Lidl, 2x pro
  Woche, …“).
- **Seed-Läden:** `-seedQuickAddAssignmentForUITests` löscht vorher alle Läden und Artikel und legt
  „Lidl“ (🛒, 2x pro Woche) und „dm“ (💄, 1x pro Woche) an. **Beide haben `sortIndex` 0**, `sortIndex`
  wird nur in `onMove` gesetzt. Die Startreihenfolge ist daher **nicht festgelegt** und wechselte in der
  Messung zwischen Läufen (dm, Lidl bzw. Lidl, dm). Der Reihenfolge-Test liest die Reihenfolge vorher und
  prüft die **Umkehrung**, nie eine feste Reihenfolge.
- **Ziehen:** `onMove` greift nur im Modus „Bearbeiten“; währenddessen ist `syncOrder` ausgesetzt
  (`onChange(of: allStores)` nur bei `.inactive`). Die Zeilenreihenfolge wird über `app.cells.staticTexts`
  gelesen (Label exakt Ladenname), **nicht** über `app.staticTexts`: Die Startseite hinter dem Sheet liefert
  Mehrfachtreffer.
- **Eigenen Laden hinzufügen:** `AddCustomStoreView` als Sheet: Feld „Name des Ladens“, Emoji-Feld
  (Platzhalter „🛒“, Vorbelegung „🛒“), Auswahl „Besuche pro Woche“ (Vorbelegung „1x pro Woche“),
  `ColorPicker`, Kategorien. „Hinzufügen“ ist bei leerem Namen gesperrt; „Abbrechen“ schließt. Der
  neue Laden ist `isCustom`, aktiv, `sortIndex` 0; `addStore()` speichert nicht ausdrücklich (SwiftData-
  Autosave) — der Test wartet zustandsbasiert auf die Kachel.
- **Emoji ändern:** Der Emoji-Knopf in der Zeile öffnet ein Sheet „Emoji ändern“ (Textfeld, „Abbrechen“,
  „Speichern“). Der Test öffnet es und bricht ab; das Emoji-Zeichen als Knopflabel wird nicht als Locator
  benutzt (Memory #46), sondern der Knopf als erster Knopf in der Zeile.
- **Kachel-Locator:** Wie in `QuickAddAssignmentUITests`:
  `app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch`. Liegt das
  Sheet vorn, sind Kacheln dahinter nicht antippbar; Kachelprüfungen laufen nach dem Schließen des Sheets
  (Schließen: „Fertig“ im Modus Bearbeiten beendet nur den Modus; das Sheet schließt der Nutzer durch Ziehen
  der Titelzeile nach unten, siehe Hinweis im Bestandstest `RestockUITests.swift`).

### Klasse `StoreSetupUITests`

Start für alle Tests: `-hasCompletedOnboarding YES -seedQuickAddAssignmentForUITests`, über
`UITestLaunch.start(app, expecting: <Kachel Lidl>)`. Wartet zustandsbasiert (`waitUntilHittable`,
`UITestWait.defaultTimeout` 20 s), keine 5-s-Fristen. `tearDown()` startet die App einmal mit
`-hasCompletedOnboarding YES -clearQuickAddAssignmentSeedForUITests` und beendet sie (Muster
`QuickAddAssignmentUITests`; der App-Group-Container überlebt den Test). Die Tests löschen **nur gesäte
oder vom Test selbst angelegte Läden** und laufen **nur im Test-Simulator Restock-Validate**, nie gegen
echte Daten.

Hilfen: `openSetup(app)` (Tipp auf „Verwalten“, wartet auf Titel „Läden“ und „Bearbeiten“),
`closeSetup(app)` (Titelzeile des Sheets nach unten ziehen, Muster Bestandstest, dann Kachel antippbar),
`tile(_:in:)`, `rowNames(app)` (Zeilennamen aus `app.cells.staticTexts`, gefiltert auf „Lidl“, „dm“, …),
`row(_:in:)`.

**S1 `testDeactivateBySwipeMovesStoreToInactiveAndRemovesTile`**

1. Setup öffnen. Zeile „Lidl“ in „Aktiv“ nach links wischen, „Deaktivieren“ antippen.
2. Abschnitt „Inaktiv“ erscheint und enthält „Lidl“; „Lidl“ steht nicht mehr in „Aktiv“ (Picker „Besuche
   pro Woche“ ist in der Zeile weg, da nur für aktive Läden).
3. Sheet schließen: die Kachel `Lidl,` existiert **nicht** mehr auf der Startseite, die Kachel `dm,` ist
   antippbar.

**S2 `testActivateBySwipeRestoresStoreAndTile`**

1. Wie S1 deaktivieren. In „Inaktiv“ „Lidl“ nach links wischen, „Aktivieren“ antippen.
2. „Inaktiv“ verschwindet (kein inaktiver Laden mehr), „Lidl“ steht wieder in „Aktiv“.
3. Sheet schließen: Kachel `Lidl,` ist wieder antippbar.

**S3 `testDeleteInactiveStoreAsksFirstCancelKeepsConfirmRemoves`** (destruktiv, nur gesäter Laden „dm“)

1. „dm“ deaktivieren; in „Inaktiv“ wischen → „Löschen“ antippen. Die Rückfrage „Markt löschen?“ erscheint mit
   der Meldung, die „dm“ nennt.
2. „Abbrechen“ → Rückfrage weg, „dm“ steht weiter in „Inaktiv“.
3. Erneut wischen → „Löschen“ → in der Rückfrage „Löschen“ bestätigen → „dm“ steht in keinem Abschnitt mehr,
   „Inaktiv“ ist weg. Sheet schließen: Kachel `dm,` existiert nicht; `Lidl,` unberührt.
4. Hinweis: „Löschen“ erscheint als Wischknopf und als Dialogknopf; der Dialogknopf wird im Dialog
   (`app.sheets`/`app.alerts` bzw. `app.buttons` nach Erscheinen der Rückfrage) gesucht, nicht blind als
   erster Treffer.

**S4 `testAddCustomStoreCreatesTileAndBlocksEmptyName`**

1. Setup öffnen, „Eigenen Laden hinzufügen“ antippen. „Hinzufügen“ ist deaktiviert (`isEnabled == false`),
   solange der Name leer ist.
2. Feld „Name des Ladens“ antippen, Fokus abwarten (`hasKeyboardFocus`), „Testmarkt“ tippen →
   „Hinzufügen“ aktiv, antippen.
3. Zeile „Testmarkt“ steht in „Aktiv“. Sheet schließen: Kachel `Testmarkt,` ist antippbar (Frequenz im
   Label: „1x pro Woche“, die Vorbelegung).
4. Emoji und Farbe werden nicht bedient (offene Grenze).

**S5 `testChangingVisitFrequencyUpdatesTileLabel`**

1. Setup öffnen, in der Zeile „Lidl“ den Picker „Besuche pro Woche“ öffnen und „3x pro Woche“ wählen.
   Der Untertitel der Zeile zeigt „3x pro Woche“.
2. Sheet schließen: Das Label der Kachel `Lidl,` enthält „3x pro Woche“ (`waitForLabel(contains:)`) und
   nicht mehr „2x pro Woche“.

**S6 `testDragReorderingReversesStoresAndSurvivesRestart`**

1. Setup öffnen. Reihenfolge der Zeilen „Lidl“/„dm“ lesen (`app.cells.staticTexts`) → `vorher`.
2. „Bearbeiten“ antippen (Knopf heißt jetzt „Fertig“). Die beiden Verschiebegriffe suchen (Label-Muster
   „anordnen“, wie in der Messung). `press(forDuration: 0.8, thenDragTo:)` vom ersten Griff auf eine Stelle
   1,6 Zeilenhöhen unter dem zweiten Griff.
3. „Fertig“ antippen. Reihenfolge der Zeilen = Umkehrung von `vorher` (zustandsbasiert gewartet).
4. Sheet schließen: Die Kacheln auf der Startseite stehen in der umgekehrten Reihenfolge (Vergleich der
   Y-Positionen bzw. Reihenfolge der Kacheln; Kacheln liegen im Raster, gelesen über die Frames: erste
   Zeile/Spalte zuerst).
5. App beenden und **ohne Seed-Argument** neu starten (nur `-hasCompletedOnboarding YES`; ein erneuter
   Seed würde alle Läden löschen und neu anlegen). Die Kachelreihenfolge ist weiter die Umkehrung
   (Persistenz von `sortIndex`); Setup öffnen: die Zeilenreihenfolge ebenfalls.
6. Der Test nimmt **keine feste Startreihenfolge** an (beide Seed-Läden `sortIndex` 0).

**S7 `testEmojiSheetOpensAndCancelsWithoutChange`**

1. Setup öffnen, in der Zeile „Lidl“ den Emoji-Knopf (erster Knopf der Zeile) antippen. Das Sheet „Emoji
   ändern“ erscheint. „Abbrechen“ antippen → Sheet weg, die Zeile „Lidl“ steht unverändert da.
2. **Keine Eingabe** und kein „Speichern“ (offene Grenze).

## Acceptance Criteria

- AC-1: Deaktivieren per Wischgeste: Der Laden verschwindet aus „Aktiv“, steht unter „Inaktiv“, und seine
  Kachel ist nach dem Schließen des Sheets von der Startseite verschwunden, die des anderen Ladens bleibt
  (Test S1). Nutzen: Der Nutzer kann einen Laden ausblenden und die Startseite folgt sofort; bisher hat das
  nie ein Test gesehen.
- AC-2: Aktivieren per Wischgeste macht AC-1 rückgängig: Der Laden steht wieder in „Aktiv“, „Inaktiv“
  verschwindet, die Kachel ist zurück (Test S2).
- AC-3: Löschen nur für inaktive Läden und mit Rückfrage: Wischen → „Löschen“ zeigt „Markt löschen?“ mit dem
  Ladennamen; „Abbrechen“ lässt den Laden stehen; Bestätigen mit „Löschen“ entfernt ihn aus der Liste und
  seine Kachel von der Startseite, der andere Laden bleibt (Test S3). Nur gesäte Läden im Test-Simulator
  (Restock-Validate). Offene Grenze: „Teilen beenden“ bei geteilten Läden ungeprüft.
- AC-4: Eigenen Laden hinzufügen: „Hinzufügen“ ist bei leerem Namen gesperrt; mit Namen entsteht die Zeile in
  „Aktiv“ und nach dem Schließen die Kachel auf der Startseite (Test S4). Emoji und Farbe sind nicht
  bedient.
- AC-5: Besuchshäufigkeit ändern: Die neue Stufe steht im Untertitel der Zeile und im Label der Kachel auf
  der Startseite (Test S5).
- AC-6: Reihenfolge ziehen: Im Modus „Bearbeiten“ vertauscht das Ziehen auf dem Verschiebegriff die Läden; nach
  „Fertig“ gilt die Umkehrung der vorher gelesenen Reihenfolge in der Liste (Test S6).
- AC-7: Die gezogene Reihenfolge kommt auf der Startseite als Kachelreihenfolge an und überlebt einen
  App-Neustart ohne Seed-Argument (Test S6). Nutzen: `sortIndex` wird wirklich gespeichert und gelesen;
  die Messung vom 2026-10-12 hat nur das Ziehen selbst belegt.
- AC-8: Der Reihenfolge-Test liest die Startreihenfolge vorher und prüft die Umkehrung; er nimmt keine feste
  Reihenfolge an (beide Seed-Läden `sortIndex` 0). Die Reihenfolge wird über `app.cells.staticTexts` gelesen,
  nicht über `app.staticTexts`.
- AC-9: Emoji-Sheet: „Emoji ändern“ öffnet und schließt mit „Abbrechen“ ohne Änderung (Test S7). Die
  Emoji-Eingabe und der Farbwähler sind ungeprüft und als offene Grenze benannt.
- AC-10: Zeilenschalter: Der Schalter `Toggle("")` einer Zeile wird zum Deaktivieren/Aktivieren bedient, **wenn**
  er in TDD-RED je Zeile eindeutig findbar ist (`cell.switches.firstMatch`); sonst wird nur der Wischweg
  getestet und der Schalter im Ticketkommentar als offene Grenze genannt. Die Entscheidung steht in der
  RED-Protokollzeile des Tests.
- AC-11: Echter Weg statt Nachbau: Alle Tests bedienen sichtbare Elemente (Beschriftungen, Wischgesten,
  Ziehgeste). Läden, Reihenfolge und Frequenzen werden vom Test nicht von Hand gesetzt; erlaubt sind nur der
  bestehende Seed `-seedQuickAddAssignmentForUITests` als Ausgangszustand und sein Aufräum-Argument.
- AC-12: Aufräumen: `tearDown()` startet die App mit `-clearQuickAddAssignmentSeedForUITests`; danach gibt es
  keine Läden und Artikel aus dem Test (auch „Testmarkt“ aus S4 ist weg). Nachweis: Die Bestandssuiten
  (insbesondere `QuickAddAssignmentUITests`, `RestockUITests`, `OnboardingUITests`) laufen im
  gemeinsamen Lauf mit der neuen Klasse grün. Der Lauf zählt: „Executed 0 tests“ oder ein Abbruch ist kein
  Grün; die Testzahl wird geprüft.
- AC-13: Stabilität: Warten nur zustandsbasiert (`waitUntilHittable`, `waitForLabel(contains:)`,
  `UITestWait.defaultTimeout`), keine 5-s-Fristen. Nachweis: mindestens drei Läufe der neuen Klasse
  hintereinander grün, davon mindestens einer unter Rechenlast (Memory „Leerer UI-Test-Start nur unter
  Last“; Messung des Ziehens: 4/4 vollständig, 5/5 im Ziehschritt, auch unter Last).
- AC-14: Der Bestandstest `RestockUITests.swift` Zeilen 160–200 bleibt unverändert und grün.
- AC-15: Umfang und Produktcode: Kein Produktcode im Diff (`SmartCart/` unverändert); ≤ 5 Dateien (geplant 3:
  Test, `project.pbxproj`, Spec), ca. +160–190 LoC. Überschreitung von ±250 LoC wird vor dem Weiterbau
  gemeldet. Wird ein Produktfehler gefunden, wird er nur mit Wort des PO mitgefixt.
- AC-16: Offene Grenzen sind in Spec, Testkommentar (Kopf der Klasse) und Ticketkommentar benannt: „Teilen
  beenden“ beim Löschen geteilter Läden (CloudKit), Emoji-Eingabe, Farbwähler, ggf. Zeilenschalter (AC-10),
  Punkte 5 und 6 aus #98. Keine Zusage dieses Durchgangs lautet „Laden-Einrichtung geprüft“ ohne diese
  Einschränkungen.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | `testDeactivateBySwipeMovesStoreToInactiveAndRemovesTile` (S1) | `StoreSetupUITests` | UI | AC-1, 11 |
| T2 | `testActivateBySwipeRestoresStoreAndTile` (S2) | `StoreSetupUITests` | UI | AC-2, 11 |
| T3 | `testDeleteInactiveStoreAsksFirstCancelKeepsConfirmRemoves` (S3) | `StoreSetupUITests` | UI | AC-3, 11 |
| T4 | `testAddCustomStoreCreatesTileAndBlocksEmptyName` (S4) | `StoreSetupUITests` | UI | AC-4, 11 |
| T5 | `testChangingVisitFrequencyUpdatesTileLabel` (S5) | `StoreSetupUITests` | UI | AC-5, 11 |
| T6 | `testDragReorderingReversesStoresAndSurvivesRestart` (S6) | `StoreSetupUITests` | UI | AC-6, 7, 8, 11 |
| T7 | `testEmojiSheetOpensAndCancelsWithoutChange` (S7) | `StoreSetupUITests` | UI | AC-9 |
| T8 | Zeilenschalter-Entscheidung in TDD-RED (ggf. S1/S2 um Schalterweg ergänzt) | `StoreSetupUITests` | UI | AC-10 |
| T9 | Bestandssuiten im gemeinsamen Lauf mit der neuen Klasse | alle | UI+Unit | AC-12, 14 |
| T10 | Wiederholung mindestens 3x, einmal unter Last (Stabilität, besonders T3 und T6) | neue Klasse | UI | AC-13 |
| T11 | Durchlauf im Simulator, Artefakt durch Werkzeug | — | durch Werkzeug | AC-1, 3, 7, 16 |
| T12 | Diff-Nachweis: Dateizahl, LoC, `SmartCart/` unverändert (`git diff --stat` gegen `origin/main`) | — | Diff | AC-15 |

Start- und Warteregeln: Start über `UITestLaunch.start(_:expecting:)` (zweiter Start mit Messzeile bei
Fehlstart, #105); Warten über `UITestWait` statt `expectation(for: isHittable…)` mit 5 s. Der Tastaturfokus
nach `tap()` wird wie in den Bestandstests per `hasKeyboardFocus` abgewartet, bevor `typeText` läuft.
Szenario pinnt `de`/`DE`; Simulator nie parallel, eigenes Testgerät Restock-Validate.

TDD: Die Klasse wird vor jeder weiteren Änderung geschrieben. Da kein Produktcode entsteht, testen alle Tests
bestehendes Verhalten und dürften sofort grün sein; RED bedeutet hier: Locator und Ablauf werden am
laufenden Simulator belegt (Zeilenschalter, Verschiebegriffe, Dialogknopf „Löschen“). Der Nachweis, dass die
Tests nicht leer laufen, sind **Mutationsproben**: (a) in `StoreSetupView` kurz das `save()` nach dem
Deaktivieren entfernen oder die Kachelfilterung aufheben → S1 muss rot werden; (b) in `onMove` kurz die
`sortIndex`-Zuweisung auskommentieren → S6 muss rot werden (Startseite bzw. Neustart); (c) in der Rückfrage
„Löschen“ kurz nichts löschen → S3 muss rot werden. Alle Änderungen werden vollständig zurückgenommen und
stehen nicht im Endstand des Diffs.

## Risiken

- **Löschen ist destruktiv:** S3 löscht einen Laden samt Artikeln. Nur gesäte Läden, nur im Simulator
  Restock-Validate, Aufräumen über das Seed-Clear-Argument. Der Test darf nie gegen ein Gerät mit echten
  Daten laufen (Regel: Hennings Geräte nur auf sein Wort).
- **Ziehen unter Last:** Die Messung hatte 5/5 stabile Ziehschritte, aber nur 4 vollständige Läufe; unter
  Last dauerten Läufe über 5 Minuten. Der 3x-Lauf mit Last (T10) ist der Beweis; instabiles Ziehen wäre
  Anlass, S6 zu kürzen (Ticketkommentar statt stiller Lockerung).
- **Startreihenfolge:** beide Seed-Läden `sortIndex` 0 → Startreihenfolge wechselt. S6 liest vorher und
  prüft die Umkehrung. Ein Test, der „dm vor Lidl“ annähme, wäre flackernd.
- **Neustart ohne Seed:** Der Seed löscht alle Läden. Der zweite Start in S6 läuft deshalb ohne
  `-seedQuickAddAssignmentForUITests`; sonst würde er die Persistenz überschreiben und der Test wäre blind.
- **Mehrdeutige Locator:** Die Startseite hinter dem Sheet liefert Mehrfachtreffer für `app.staticTexts`;
  Zeilen werden über `app.cells` gelesen. „Löschen“ existiert als Wisch- und Dialogknopf. Der Emoji-Knopf
  trägt das Emoji als Label (Memory #46), daher nicht über das Label suchen.
- **Sheet schließen:** Es gibt keinen Schließen-Knopf; ein blindes `swipeDown()` scrollt die Liste statt des
  Sheets (Hinweis im Bestandstest). Gezogen wird von der Titelzeile.
- **Zustandsrest zwischen Tests:** Seed und selbst angelegte Läden („Testmarkt“) bleiben im App-Group-
  Container (Memory „UI-Test-Seeds müssen aufräumen“, #28). Der gemeinsame Lauf (AC-12) ist der Beweis.
- **Texte:** Die Tests lesen deutsche Beschriftungen („Verwalten“, „Deaktivieren“, „Markt löschen?“, …);
  Textänderungen brechen sie (Hinweis in `CLAUDE.md` gilt).
- **Null-Test-Lauf:** „Executed 0 tests … TEST SUCCEEDED“ nach Abbruch ist kein Grün (Memory); Nachweise
  prüfen Testzahl, Abbrüche und Wiederholungs-Kennzeichen.

## Alternativen

- **(a) `onMove`-Logik als reine Funktion auslagern und per Unit-Test prüfen (~10 LoC Produktcode):**
  verworfen. Prüft nur die Neuordnung eines Arrays, nicht die Ziehgeste, `sortIndex`-Speicherung,
  Kachelreihenfolge oder Neustart; die Messung zeigt, dass die Geste stabil ist. Kippt keine ADR (würde
  nur „Produktcode bleibt unverändert“ dieses Durchgangs aufheben).
- **(b) Ziehen als Folgearbeit vertagen:** verworfen nach Messung (stabil), entsprach der PO-Entscheidung
  vom 2026-10-12 („stabil → im Durchgang“). Wäre die Rückfallposition, falls der 3x-Lauf unter Last bricht.
- **(c) Kein Löschtest (zu destruktiv):** verworfen; nur gesäte Läden im Test-Simulator, mit Rückfrage-
  und Abbrechen-Gegenprobe. Wäre sonst die größte ungetestete Aktion der Ansicht.
- **(d) Seed erweitern (verschiedene `sortIndex` im Seed):** verworfen für diesen Durchgang; würde
  `SmartCartApp` ändern (Produktdatei) und andere Tests berühren. Lesen-vor-Ziehen reicht.
- **(e) Zeilenschalter statt Wischgeste:** kein Ersatz, nur Ergänzung (AC-10), da der Schalter ein leeres
  Label hat und die Auffindbarkeit offen ist.
- **Ohne Modell:** nichts hier braucht ein Sprachmodell; reine Oberflächen- und Zustandsprüfung.
- Gekippte frühere Entscheidung: keine.

**Entscheidung:** Eine neue UI-Testklasse gegen den bestehenden Seed, sieben Abläufe mit Nutzen-Prüfung
(Startseite, Persistenz) statt Existenz, Ziehen im Durchgang (gemessen stabil), Löschen nur gesät im
Simulator, ohne Produktcode.

## Offene Punkte

- Keine für den PO (technische Entscheidungen).
- Offen für die TDD-RED-Phase: Zeilenschalter `Toggle("")` je Zeile eindeutig findbar? (AC-10); genaue
  Locator der Verschiebegriffe und des Dialogknopfs „Löschen“ am laufenden Simulator bestätigen.
- Offene Grenze (gilt für jede Zusage dieses Durchgangs): „Teilen beenden“ beim Löschen eines geteilten
  Ladens (`SharedStoreService.leaveBeforeDeleting`) braucht CloudKit und ist nicht automatisiert prüfbar;
  Emoji-Eingabe und Farbwähler ungeprüft; Punkte 5 (Tagesmitteilung) und 6 (Siri/Widget) aus #98 bleiben
  offen.
- Folgetickets im Ticketkommentar von #98 festhalten (gebündelt nach Ziel), soweit sie anfallen:
  Zeilenschalter (falls nicht findbar), Emoji-Eingabe und Farbwähler, geteilter Laden löschen (CloudKit).
- Nach Abschluss: Verweis auf `StoreSetupUITests` in `CLAUDE.md` (Abschnitt Build/UI-Tests), falls das
  Limit es erlaubt, sonst im Folgedurchgang.
