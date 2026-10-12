# Context: test-98-durchgang-6-laden-einrichtung

## Request Summary

Issue #98 (Testlücke), Durchgang 6 = Punkt 7, zweiter Teil: `StoreSetupView` (Laden-Einrichtung, 47 % Coverage
laut Messung vom 2026-10-02). Gesucht sind UI-Tests, die den echten Weg fahren. PO-Entscheidung 2026-10-12:
Das Ziehen der Reihenfolge wird zuerst am Simulator ausprobiert; stabil → im Durchgang, sonst Folgearbeit.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Views/Settings/StoreSetupView.swift` (353 Z.) | Testgegenstand: `StoreSetupView`, `StoreRow`, `AddCustomStoreView` |
| `SmartCart/Views/Settings/BrowseStoresView.swift` (267 Z.) | Aus der Einrichtung per NavigationLink „Läden aus anderen Ländern hinzufügen“ erreichbar; öffnet selbst `AddCustomStoreView` (Z. 204) |
| `SmartCart/Views/Home/HomeView.swift` | Einstieg: Knopf „Verwalten“ (Z. ~969, nur im Kartenmodus, nicht `listMode`) und „Läden einrichten“ im leeren Zustand (Z. ~1364); beide öffnen `StoreSetupView` als Sheet (Z. 202). `activeStores` (Z. 29) filtert `isActive`, sortiert nach `sortIndex` |
| `SmartCart/SmartCartApp.swift` | DEBUG-Seeds: `-seedQuickAddAssignmentForUITests` (Läden „Lidl“ 🛒 2×/Woche und „dm“ 💄 1×/Woche, löscht vorher alle Läden/Artikel) und `-clearQuickAddAssignmentSeedForUITests`; `-clearOnboardingForUITests` |
| `SmartCart/Models/Store.swift` | `isActive`, `sortIndex` (Standard 0), `emoji`, `visitsPerWeek`, `categories`, `isCustom`, `shareID` |
| `SmartCart/Extensions/DesignSystem.swift:61` | `VisitFrequency` (acht Stufen), Beschriftungen aus `frequency.*` |
| `SmartCart/Resources/de.lproj/Localizable.strings` | Texte für die Tests: `stores.title` „Läden“, `stores.active` „Aktiv“, `stores.inactive` „Inaktiv“, `stores.add.custom` „Eigenen Laden hinzufügen“, `stores.name.placeholder` „Name des Ladens“, `stores.visits.label` „Besuche pro Woche“, `frequency.weekly` „1x pro Woche“, `frequency.twice` „2x pro Woche“, `action.edit` „Bearbeiten“, `action.done` „Fertig“, `action.add` „Hinzufügen“ |
| `RestockUITests/RestockUITests.swift:160–200` | Einziger bestehender Test, der die Einrichtung berührt (Läden einrichten → Browse → Lidl hinzufügen → Sheet wegziehen); Hinweis dort: ein blindes `swipeDown()` scrollt die Liste statt das Sheet zu schließen |
| `RestockUITests/UITestWait.swift` | `UITestWait.defaultTimeout` (20 s), `waitUntilHittable()`, `waitForLabel(contains:)`, `UITestLaunch.start(app, expecting:, description:)` |
| `RestockUITests/QuickAddAssignmentUITests.swift`, `OnboardingUITests.swift` | Vorlagen für Seed, `tearDown()` mit Aufräum-Argument, `tile(_:in:)`-Hilfe (`label BEGINSWITH "Lidl,"`) |

## Existing Patterns

- Gesäte Tests starten über `UITestLaunch.start`, räumen im `tearDown()` mit dem passenden `clear…ForUITests`-Argument auf
  (App-Group-Container überlebt den Test, siehe CLAUDE.md).
- Warten zustandsbasiert (`waitUntilHittable`), keine 5-s-Fristen (CI-Abfragen dauern bis 31 s).
- Kacheln der Startseite sind Buttons mit zusammengesetztem Label („Lidl, 2x pro Woche, Liste ist leer“).
- Neue Testdatei = pbxproj in vier Stellen (CLAUDE.md „Adding new Swift files“).
- Der Seed `-seedQuickAddAssignmentForUITests` genügt vermutlich als Ausgangszustand (zwei Läden); kein neuer Produktcode nötig,
  solange nichts anderes fehlt.

## Dependencies

- Upstream von `StoreSetupView`: SwiftData-Kontext (`context.save()` direkt nach Deaktivieren/Aktivieren/Löschen),
  `Haptics`, `SharedStoreService.leaveBeforeDeleting` (nur bei `shareID != nil`), `BrowseStoresView`, `AddCustomStoreView`,
  `Category`/`AssignmentService.displayCategory`.
- Downstream: `HomeView` (Kacheln), `StoreDetailView`, `SettingsView`, `ReceiptScannerView`, `RecipeImportView` lesen
  `activeStores` (aktiv, sortiert nach `sortIndex`).

## Befunde aus dem Lesen (noch nicht am Simulator belegt)

1. **Löschen geht nur für inaktive Läden:** In „Aktiv“ gibt es per Wischgeste nur „Deaktivieren“; „Löschen“ und „Aktivieren“
   stehen nur in „Inaktiv“. Der Löschweg läuft also immer: deaktivieren → wischen → Löschen → Rückfrage „Markt löschen?“.
2. **Zwei Wege zum Deaktivieren:** Wischgeste (mit `save()`) und der Schalter in der Zeile (`onChange` mit `save()`). Der
   Schalter hat ein leeres Label (`Toggle("")`, `labelsHidden`); ob XCUITest ihn eindeutig je Zeile findet, ist offen.
3. **`sortIndex` wird nirgends außer in `onMove` gesetzt** (Standard 0). Beide Seed-Läden haben `sortIndex` 0, die
   Startreihenfolge ist damit nicht festgelegt. Ein Reihenfolge-Test muss die Reihenfolge VOR dem Ziehen lesen und danach
   die Umkehrung samt Neustart prüfen, nicht eine feste Reihenfolge annehmen.
4. **Reihenfolge zieht nur im Bearbeiten-Modus:** `onMove` greift mit dem Knopf „Bearbeiten“ (`editMode`); `syncOrder` ist
   währenddessen ausgesetzt (`onChange(of: allStores)` nur bei `.inactive`).
5. **Emoji ändern:** Sheet mit Textfeld; das Emoji der Kachel steht im Label der Startseitenkachel nicht als Text, sondern
   als `Text(store.emoji)`. Memory „Emoji-Text bricht Accessibility-Label“ (Issue #46): Emoji hängt sich vorn ans Label,
   BEGINSWITH-Prüfungen können deshalb brechen. Emoji-Eingabe per XCUITest-Tastatur ist unsicher (Simulator hat evtl. keine
   Emoji-Tastatur aktiv; `typeText` mit Emoji-Zeichen ist zu prüfen).
6. **`AddCustomStoreView` ist doppelt erreichbar** (aus der Einrichtung und aus `BrowseStoresView`); der Test nimmt den
   kürzeren Weg aus der Einrichtung. Der Speichern-Knopf („Hinzufügen“) ist bei leerem Namen gesperrt (zweimal
   `.disabled` gesetzt, harmlos). Der Farbwähler (`ColorPicker`) ist kein sinnvoll testbares Ziel.
7. **Bestehender Test deckt nur Browse → Hinzufügen** ab; der neue Test darf ihn nicht ersetzen, nur ergänzen.

## Existing Specs

- `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` — Vorgänger, Format und Offene-Grenzen-Muster
- `docs/specs/ui-tests/test-98-durchgang-3-schnelleingabe-notfallpfad.md`
- Keine eigene Spec zu `StoreSetupView`.

## Risks & Considerations

- **Ziehen in XCUITest:** Websuche (2026-10-12, Apple-Forum/Blogs) liefert nur die SwiftUI-Seite von `onMove`, keine belastbaren
  XCUITest-Berichte. Ob `press(forDuration:thenDragTo:)` auf dem Verschiebegriff im Bearbeiten-Modus stabil klappt, ist offen und
  wird in `/20-analyse` am Simulator mit einem Wegwerf-Test gemessen (mehrere Wiederholungen, auch unter Last, siehe Memory
  „Leerer UI-Test-Start nur unter Last“).
- **Löschen ist destruktiv:** nur gegen die gesäten Testläden im Simulator `Restock-Validate`, nie gegen echte Daten; Aufräumen
  über das bestehende Seed-Clear-Argument.
- **Offene Grenze (in jede Zusage):** „Teilen beenden“ beim Löschen eines geteilten Ladens (`leaveBeforeDeleting`) braucht
  CloudKit und ist nicht automatisiert prüfbar. Punkte 5 (Tagesmitteilung) und 6 (Siri/Widget) aus #98 bleiben offen.
- **Scoping:** Ziel ≈ eine neue Testklasse (~130–180 LoC) + pbxproj + Spec; kein Produktcode erwartet. Wird ein Produktfehler
  gefunden (wie in Durchgang 5), gilt: im Durchgang mitfixen nur mit PO-Wort.
- **Alternative zum Ziehen-Test:** `onMove`-Logik als reine Funktion auslagern und per Unit-Test prüfen (~10 LoC Produktcode);
  prüft die Geste nicht. Kippt keine ADR.
- **Regel vor Modell:** nichts hier braucht ein Sprachmodell.

## Analysis

### Type
Feature (Testlücke, Issue #98 Durchgang 6 — nur Tests, kein Produktcode erwartet)

### Messung: Ziehen der Reihenfolge am Simulator (2026-10-12, Restock-Validate, Wegwerf-Test, zurückgenommen)
Weg: Seed `-seedQuickAddAssignmentForUITests` → „Verwalten“ → „Bearbeiten“ → Verschiebegriffe (2 Stück, per Label-Muster
„anordnen“ gefunden) → `press(forDuration: 0.8, thenDragTo:)` vom ersten Griff auf 1,6 Zeilenhöhen unter den zweiten → „Fertig“.
Reihenfolge gelesen über `app.cells.staticTexts` (Label exakt), NICHT über `app.staticTexts` (die Startseite dahinter liefert Mehrfachtreffer).

| Lauf | Bedingung | Reihenfolge vorher | nachher | Ergebnis |
|------|-----------|--------------------|---------|----------|
| 1 | ohne Last | dm, Lidl | Lidl, dm | grün |
| 2 | ohne Last | dm, Lidl | Lidl, dm | grün |
| 3 | 6 Rechenprozesse Last | dm, Lidl | Lidl, dm | grün |
| 4 | 6 Rechenprozesse Last | Lidl, dm | dm, Lidl | grün |
| 5 | Last (Lauf bis „Fertig“ gelesen, dann Zeitlimit des Hintergrundjobs) | Lidl, dm | dm, Lidl | Ziehen ok, Gesamtlauf abgebrochen |

Befunde: (a) Ziehen ist 4/4 vollständig, 5/5 im Ziehschritt stabil, auch unter Last. (b) Die Startreihenfolge der beiden Seed-Läden
(beide `sortIndex` 0) ist NICHT fest — sie wechselte zwischen Läufen; der Test muss vorher lesen und die Umkehrung prüfen.
(c) Nicht gemessen: Reihenfolge nach App-Neustart (Persistenz von `sortIndex`) und auf der Startseite (Kachelreihenfolge) — kommt in den Test.
(d) Grenze der Messung: Läufe 3–5 waren langsam (~5+ min je Lauf unter Last), 6 geplante Läufe wurden nicht fertig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| RestockUITests/StoreSetupUITests.swift | CREATE | neue Testklasse: Deaktivieren (Wisch + Schalter), Aktivieren, Löschen mit Rückfrage, Eigener Laden, Frequenz ändern, Reihenfolge ziehen + Neustart |
| Restock.xcodeproj/project.pbxproj | MODIFY | neue Datei an vier Stellen |
| docs/specs/ui-tests/test-98-durchgang-6-laden-einrichtung.md | CREATE | Spec |

### Scope Assessment
- Files: 3 (davon 1 Spec); Produktcode: 0
- Estimated LoC: +150–180 Test, +~10 pbxproj
- Risk Level: LOW (nur Tests; Löschen nur gegen gesäte Läden im Simulator, Seed-Clear im tearDown)

### Technical Approach
Eine Klasse `StoreSetupUITests`, Seed `-seedQuickAddAssignmentUITests`-Vorlage, `tearDown` mit `-clearQuickAddAssignmentSeedForUITests`.
Warten zustandsbasiert (`waitUntilHittable`), keine 5-s-Fristen. Reihenfolge-Test: vorher lesen, ziehen, „Fertig“, Umkehrung prüfen,
Sheet schließen und Startseite prüfen, App beenden und neu starten (ohne Seed-Argument, sonst überschreibt der Seed), Umkehrung weiter vorhanden.
Löschweg: deaktivieren → wischen → Löschen → Rückfrage „Markt löschen?“ → Kachel weg; zusätzlich „Abbrechen“ lässt den Laden stehen.
Emoji ändern: nur Sheet öffnen/Abbrechen prüfen, Eingabe des Emoji NICHT testen (Emoji-Tastatur im Simulator unsicher, Memory #46).
ColorPicker nicht testen.
Alternative (verworfen): `onMove` als reine Funktion + Unit-Test — prüft die Geste nicht; die Messung zeigt, dass die Geste stabil ist.
Regel vor Modell: trifft nicht zu, kein Modell beteiligt.

### Dependencies
`SmartCartApp` DEBUG-Seeds (vorhanden), `UITestWait`/`UITestLaunch`, `StoreSetupView`, `HomeView` (Kacheln).
Neustart-Schritt: der Seed darf beim zweiten Start nicht mitlaufen (Seed löscht alle Läden).

### Open Questions
- [ ] Schalter in der Zeile (`Toggle("")`): eindeutig je Zeile findbar? Wird in der TDD-RED-Phase geprüft; sonst nur Wischweg testen.
- [ ] Offene Grenzen für Spec: „Teilen beenden“ beim Löschen geteilter Läden (CloudKit), Emoji-Eingabe, Farbwähler; Punkte 5/6 aus #98 bleiben offen.

## RED-Befunde (2026-10-12, Simulator Restock-Validate, Commit 2098f07)

Stand: `StoreSetupUITests` mit 7 Tests, 6 grün, 1 rot. Beleg: `docs/artifacts/test-98-durchgang-6-laden-einrichtung/test-red-output.txt`, `s1-doppelte-zeile.png`.

1. **Produktfehler (PO 2026-10-12: „jetzt mitfixen“):** Nach dem Deaktivieren steht der Laden doppelt in `StoreSetupView`: weiter in „Aktiv“
   (Zeile ohne Picker, Schalter aus) und zusätzlich in „Inaktiv“. Ursache nach Code: `orderedActiveStores` ist eine lokale Kopie, die nur
   `syncOrder()` neu füllt (`onAppear`, `onChange(of: allStores)` außerhalb des Bearbeiten-Modus); `store.isActive = false` ändert das Array
   `allStores` nicht, `onChange` feuert nicht. Rot: `testDeactivateBySwipeMovesStoreToInactiveAndRemovesTile` (Zeile 119 „Lidl“ steht noch unter „Aktiv“).
   Fix-Richtung: nach dem Deaktivieren (Wischknopf UND Zeilenschalter) `orderedActiveStores` neu aufbauen. Danach prüfen, ob Aktivieren
   (Wisch, Schalter) in „Aktiv“ sauber erscheint und ob Löschen eines Ladens, der noch in `orderedActiveStores` steht, abstürzt (S3 lief grün).
2. **Spec-Abweichungen, die einen Nachtrag brauchen (Spec ist freigegeben; Änderung nur mit „override“ des PO):**
   - Rückfrage „Markt löschen?“ erscheint auf dem iPhone als Einblendmenü (`Popover`/`Sheet`) **ohne** „Abbrechen“-Knopf; Abbrechen = außerhalb tippen
     (`otherElements["PopoverDismissRegion"]`). Der Dialogknopf „Löschen“ steht in `app.sheets`.
   - Weggewischte Zeilen hinterlassen eine Geisterzeile (x < 0) in der Hierarchie; Helfer `rows(_:in:)` filtert `frame.minX >= 0`.
   - Verschiebegriff-Label: „🛒 neu anordnen“ / „💄 neu anordnen“; Ziehen: `press(forDuration: 0.8, thenDragTo:, withVelocity: .slow, thenHoldForDuration: 0.5)` auf Mitte des zweiten Griffs + 20 pt.
   - Neustart-Teil von S6: Reihenfolge überlebt nur, wenn die App vorher in den Hintergrund ging (`XCUIDevice.shared.press(.home)`) bzw. 8 s gewartet wurde;
     direktes `terminate()` nach dem Ziehen verlor die Reihenfolge (2/2). `onMove` ruft kein `context.save()` auf. Als Beobachtung vermerkt, kein Fix beschlossen
     (Nutzerweg „Home, dann beenden“ speichert).
   - AC-10: Zeilenschalter ist in der Hierarchie als `Switch` je Zelle vorhanden (`value` 1/0); noch nicht bedient. In GREEN entscheiden (S8) oder als offene Grenze nennen.
3. Sheet schließen per Ziehen von der Titelzeile (0,15 → 0,95) funktioniert; „Verwalten“ trägt das Label „Verwalten“.
