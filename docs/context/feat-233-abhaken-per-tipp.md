# Context: feat-233-abhaken-per-tipp

## Request Summary
Beim Einkaufen soll ein Tipp irgendwo auf die Artikelzeile abhaken bzw. wieder aufheben. Bisher öffnete ein Tipp auf die Zeile den Bearbeiten-Dialog; ein knapp verfehltes Kästchen bearbeitete statt abzuhaken (Übergabe 2026-10-30, Teil 1; PO hat die Bedienung entschieden). Bearbeiten wandert zu Wischen links, Lang drücken, VoiceOver-Aktion und dem „Preis?“-Knopf.

## Ausgangslage
Fertiger Patch liegt vor: `/Users/hem/Downloads/0001-Abhaken-per-Tipp-auf-die-Ganze-Zeile-…patch` (7 Dateien, +64/−15). `git apply --check` auf aktuellem main (1b190c8) sauber. Noch nie kompiliert, nie getestet.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Components/ItemRow.swift` | Zeile; neu `onEdit`, `onTapGesture(performToggle)`, VoiceOver-Aktion, „Preis?“ als Knopf |
| `SmartCart/Views/Store/StoreDetailView.swift` | Zwei ItemRow-Aufrufe (offene Zeilen `pendingRow`, erledigte Zeilen ~Z. 461); `onTapGesture { editingItem = item }` entfällt; neuer `editButton(for:)` in Wischen und Kontextmenü |
| `RestockUITests/UITestWait.swift` | Neuer Helfer `UITestItemEditor.open` (Lang drücken → „Bearbeiten“) |
| `RestockUITests/ShoppingRouteUITests.swift:127` | tippte auf „Gouda“, um den Dialog zu öffnen |
| `RestockUITests/AddItemQuantitySuggestionUITests.swift:127` | dito „Bio Käse“ |
| `RestockUITests/LegacyLearnedPriceResetUITests.swift:121` | dito `openEditor` |
| `CLAUDE.md` | Beschreibung des neuen Verhaltens |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `action.edit` existiert bereits („Bearbeiten“ / „Edit“), kein neuer Schlüssel nötig |

## Existing Patterns
- `ItemRow` ist nur in `StoreDetailView` (2 Stellen) eingebunden. `HomeView.categoryItemRow` ist eine eigene Zeile und bleibt unberührt.
- Bearbeiten-Dialog wird über `editingItem` gesteuert.
- UI-Tests nutzen `UITestWait` (`waitUntilHittable`) statt fester Fristen.

## Dependencies / Dependents
- Upstream: `toggle(item:)` in `StoreDetailView` (Abhaken, Wegelernen via `ShoppingRoute`), `editingItem`-Sheet.
- Downstream: Alle UI-Tests, die per Tipp auf einen Namen den Editor öffnen. Gefunden sind genau die drei im Patch geänderten. `RestockUITests.swift` öffnet den Editor nicht (nur `plus.circle.fill` im Laden-Stöbern).
- `OnboardingUITests` tippt `staticTexts["Lidl"]`/`["Rewe"]` – andere Ansicht, nicht betroffen.

## Existing Specs
- `docs/specs/models/shopping-route-order.md` (Abhaken lernt Route; Abhaken-Verhalten bleibt gleich, nur der Auslöser wächst)
- Keine Spec zur Zeilen-Interaktion; neue Spec nötig.

## Risks & Considerations
- **Nie kompiliert:** Build und die drei UI-Tests sind der eigentliche Nachweis.
- **Verschachtelte Tipps:** Kästchen-`Button` liegt in einer Zeile mit `onTapGesture`; ein Tipp aufs Kästchen darf nur einmal auslösen (kein Doppel-Toggle). Muss im Test belegt werden.
- **Wischen:** `editButton` kommt zusätzlich zu „Löschen“ und „Dringend“ in die rechte Wischleiste; voller Wisch bleibt Löschen (`allowsFullSwipe`, Reihenfolge prüfen: Löschen muss das erste/äußere Element bleiben).
- **Test neu schreiben:** Es gibt keinen Test, der beweist, dass ein Tipp auf die Zeile abhakt und den Editor NICHT öffnet. Muss vor der Umsetzung als UI-Test rot geschrieben werden (TDD).
- **Umfang:** 7 Dateien, ~80 Zeilen. Über der Dateigrenze 4–5, bei Spec offenlegen.
- **Dev-Feedback-Knopf / Live Activity:** Abhaken startet die Live Activity beim ersten Haken – Tipp auf die Zeile löst nun denselben Pfad aus, zu prüfen.
- Geräte-Tests nur auf Hennings Wort; Simulator genügt.

## Analysis

### Type
Feature (Bedienungsänderung, vom PO entschieden). Kein Fehler im engeren Sinn: Ein knapp verfehltes Kästchen öffnete bisher den Bearbeiten-Dialog.

### Recherche (vor der Analyse)
- Zeilen in einer SwiftUI-`List` sind eine einzige Tippfläche; mehrere `Button`s in einer Zeile können gemeinsam auslösen, sofern kein `.plain`/`.borderless`-Stil gesetzt ist ([Codemia](https://codemia.io/knowledge-hub/path/swiftui_-_multiple_buttons_in_a_list_row)). Das Kästchen hat `.buttonStyle(.pressable)` (eigener Stil), der „Preis?“-Knopf bekommt im Patch `.plain`.
- `onTapGesture` statt `Button` verliert die Button-Eigenschaft für VoiceOver; Gegenmittel `.accessibilityAddTraits(.isButton)` ([Codemia](https://codemia.io/knowledge-hub/path/swiftui_-_multiple_buttons_in_a_list_row), [Apple-Forum](https://developer.apple.com/forums/thread/651722)). Der Patch ersetzt das durch eine benannte VoiceOver-Aktion „Bearbeiten“; das Kästchen bleibt als Button erreichbar.
- Für XCUITest ist Lang drücken auf iOS 26 nicht belegt: Weder Elementtyp noch Kennung der Kontextmenü-Einträge sind dokumentiert, nur `press(forDuration:)` selbst ([Apple-Doku](https://developer.apple.com/documentation/xcuiautomation/xcuielement/press(forduration:))). Der Helfer `UITestItemEditor.open` sucht deshalb über Kennung ODER Beschriftung in `app.buttons`; das ist unbewiesen und der wahrscheinlichste Ausfallpunkt im Test.
- Keine Fallberichte gefunden, die Wischen + Lang drücken + Zeilentipp zusammen als Konflikt beschreiben. Das ersetzt den Lauf nicht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Views/Components/ItemRow.swift | MODIFY | `onEdit`, `performToggle`, Zeilentipp, VoiceOver-Aktion, „Preis?“ als Knopf |
| SmartCart/Views/Store/StoreDetailView.swift | MODIFY | beide ItemRow-Aufrufe, `editButton(for:)` in Wischen und Kontextmenü |
| RestockUITests/UITestWait.swift | MODIFY | Helfer `UITestItemEditor.open` |
| RestockUITests/ShoppingRouteUITests.swift | MODIFY | Editor über Helfer öffnen |
| RestockUITests/AddItemQuantitySuggestionUITests.swift | MODIFY | dito |
| RestockUITests/LegacyLearnedPriceResetUITests.swift | MODIFY | dito |
| RestockUITests/(neu, z. B. ItemRowTapUITests.swift) | CREATE | Beweis: Tipp auf Zeile hakt ab und öffnet NICHT den Dialog; Tipp aufs Kästchen löst nur einmal aus; Wischen zeigt „Bearbeiten“ |
| CLAUDE.md | MODIFY | Verhalten beschreiben |
| Restock.xcodeproj/project.pbxproj | MODIFY | neue UI-Testdatei registrieren |

### Scope Assessment
- Files: 9 (Patch 7 + neuer Test + pbxproj), Produktivcode nur 2
- Estimated LoC: +~140/−15 (Patch 64/15 + neuer Test ~70)
- Risk Level: MEDIUM (Kernpfad der Liste; Lang-drücken-Test auf iOS 26 unbewiesen)

### Technical Approach
Patch einspielen (er passt sauber), davor den neuen UI-Test rot schreiben (TDD): Auf altem Stand öffnet der Zeilentipp den Dialog, der Test erwartet Abhaken. Danach Patch → grün. Zusätzlich die drei bestehenden Tests, dann echter Durchlauf im Simulator (Zeile antippen, wischen, lang drücken).

### Alternativen (zum Befund)
1. **Patch wie vorliegend (Empfehlung):** Zeilentipp = Abhaken, Bearbeiten über Wischen/Lang drücken/„Preis?“. Passt zur PO-Entscheidung, kleinste Änderung.
2. **Nur Tippfläche des Kästchens vergrößern**, Zeilentipp bleibt Bearbeiten: kleinerer Eingriff, aber verfehlte Tipps neben der Fläche öffnen weiter den Dialog – löst das Ausgangsproblem nur halb. Kippt keine ADR.
3. **Tipp = Abhaken, Bearbeiten nur per Wischen** (ohne Lang drücken und Kontextmenü): weniger Code und kein unbewiesener Lang-drücken-Test, aber Kontextmenü „Zuweisen an…“ in geteilten Läden bliebe ohne Platz für Bearbeiten nicht erreichbar → Kontextmenü existiert ohnehin, daher wenig Ersparnis.
Regelweg vor Modell: nicht relevant (reine Bedienung, kein Modell).

### Dependencies
Siehe oben: nur `StoreDetailView` nutzt `ItemRow`.

### Open Questions
- [ ] Hält der Zeilentipp zusammen mit Wischen und Lang drücken auf iOS 26 stabil? → klärt der Test.
- [ ] Löst der Zeilentipp die Live Activity wie der Kästchentipp aus (derselbe `toggle`-Pfad)? → im Durchlauf prüfen.
- Umfang 9 Dateien/~150 Zeilen liegt über der 4–5-Dateien-Grenze: wird in der Spec offengelegt (PO-Freigabe).
