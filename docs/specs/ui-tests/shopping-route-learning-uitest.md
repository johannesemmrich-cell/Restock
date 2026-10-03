---
entity_id: shopping-route-learning-uitest
type: test
created: 2026-10-03
updated: 2026-10-03
status: draft
workflow: test-98-testluecken
tags: [test, ui-test, store, shopping-route, debug-only]
---

# UI-Test-Durchlauf: Abhaken in der Ladenliste lernt den Einkaufsweg (Issue #98, Durchgang 1)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Bisher wird die Kette `ItemRow`-Haken → `StoreDetailView.toggle(item:)` → `Store.recordCheckOff` →
Trip in der App-Gruppe → `Store.finalizeStaleTrip` → `ShoppingRoute.learn` → `routeModel` →
Sortierung „Einkaufsweg“ von keinem Test als Ganzes geschlossen: `ShoppingRouteTests` prüft die
Regeln mit festen Zeitstempeln, `ShoppingRouteUITests` sät den fertig gelernten Weg. Dieser
Durchgang fügt einen echten Durchlauf hinzu: im Simulator Haken tippen, 31 Minuten simuliert
verstreichen lassen, Liste öffnen, gelernte Reihenfolge sehen. Dazu zwei kleine Testhilfen hinter
`#if DEBUG`. Kein Produktverhalten ändert sich.

Ticket-Rahmen: #98 ist ein Ticket mit mehreren Durchgängen (Entscheidung Henning 2026-10-03), die
Scoping-Limits gelten je Durchgang. Dies ist Durchgang 1.

## Source

- **Neu:** `RestockUITests/ShoppingRouteLearningUITests.swift`
- **Geändert:**
  - `SmartCart/Models/Store.swift` — `finalizeStaleTrip(now:)` (Z. ~271) nimmt als Vorgabe
    `RouteClock.now` statt `Date()`; neuer kleiner Typ `RouteClock` (Release: immer `Date()`;
    DEBUG: `Date()` plus Offset aus dem Launch-Argument)
  - `SmartCart/SmartCartApp.swift` — DEBUG-Launch-Argument `-shoppingRouteNoLearnedModelForUITests`
    in `seedShoppingRouteForUITestsIfNeeded` (Z. ~275); das Lesen des Offsets liegt in `RouteClock`
  - `Restock.xcodeproj/project.pbxproj` — neue Testdatei in `PBXBuildFile`, `PBXFileReference`,
    `PBXGroup` (RestockUITests), `PBXSourcesBuildPhase` des UITests-Targets
- **Nicht geändert:** `StoreDetailView.swift` (die Aufrufe `store.finalizeStaleTrip()` in
  `.onAppear` und `scenePhase` bleiben unverändert und nutzen die neue Vorgabe), `ShoppingRoute.swift`
  (Regeln, `tripGap`, `bulkGap` bleiben), `EditItemView.swift`.

Geschätzter Umfang: 4 Dateien, ca. +150 LoC, davon ca. 20 Produktcode (alles `#if DEBUG`-gesteuert).

## Verhalten

### Testhilfe 1: simulierte Uhr für das Abschließen eines ruhenden Einkaufs

- `RouteClock.now` liefert in Release immer `Date()`. Die Offset-Logik existiert in Release nicht
  (Code unter `#if DEBUG`, nicht nur ein ignorierter Wert).
- In DEBUG liefert `RouteClock.now` `Date()` plus N Minuten, wenn die App mit
  `-routeClockOffsetMinutesForUITests <N>` gestartet wurde; ohne Argument oder bei nicht
  lesbarem Wert `Date()`.
- Der Offset wirkt **nur** über die Vorgabe von `finalizeStaleTrip(now:)` (Öffnen der Ladenansicht,
  Rückkehr in den Vordergrund). Ein expliziter Aufruf `finalizeStaleTrip(now: x)` (Unit-Tests)
  bleibt unverändert.
- **Nachtrag nach PR #104 (CI):** `RouteClock.checkOffTime()` ist die Vorgabe für
  `Store.recordCheckOff(_:batched:at:)`. Release: immer `Date()`. DEBUG: mit
  `-routeCheckOffStepSecondsForUITests <s>` liegt jeder Haken genau s Sekunden nach dem vorigen
  (der erste bei `Date()`), unabhängig vom Tempo des Testläufers; ohne Argument `Date()`.
  Grund: Auf dem CI-Runner lagen drei Taps > 2 s auseinander, Test B („zu Hause“) lernte dort den
  Weg (Gouda, Brot, Apfel). Die Messung vom Mac (Taps ≪ 2 s) hatte das nicht gezeigt.

### Testhilfe 2: Seed ohne gelerntes Modell

- `-shoppingRouteNoLearnedModelForUITests` zusammen mit `-seedShoppingRouteForUITests`: der Seed
  legt Laden „Wegeladen“ mit Brot, Apfel, Gouda (in dieser Reihenfolge hinzugefügt, wie bisher),
  leerem Trip und Modus Einkaufsweg an, aber **ohne** `routeModel` (leeres `ShoppingRouteModel()`).
  Ohne das Argument bleibt der Seed bit-identisch zu heute (Gouda → Brot → Apfel gelernt).
- Ausgangsreihenfolge ohne Modell im Modus Einkaufsweg: feste Supermarkt-Reihenfolge nach
  Kategorie, also Apfel, Brot, Gouda.

### Ablauf Test A „Einkaufsweg wird beim Abhaken gelernt“

1. Start mit `-hasCompletedOnboarding YES -seedShoppingRouteForUITests
   -shoppingRouteNoLearnedModelForUITests`; Kachel „Wegeladen,“ öffnen (Wartezeit 15 s wegen
   kaltem Start).
2. Reihenfolge prüfen: Apfel, Brot, Gouda (Nachweis, dass noch nichts gelernt ist).
3. Haken tippen in der Reihenfolge Gouda, Brot, Apfel; Start mit
   `-routeCheckOffStepSecondsForUITests 5` (5 s zwischen den Haken, Bulk-Erkennung: Abstände
   < `bulkGap` = 2 s zählen als „zu Hause“), keine Wartezeit im Test.
4. App beenden; neu starten **ohne** Seed-Argumente, mit `-routeClockOffsetMinutesForUITests 31`;
   Laden öffnen. `finalizeStaleTrip` sieht > 30 min Ruhe und lernt.
5. Alle drei Artikel sind jetzt im Laden wieder sichtbar: der Test setzt dazu die Haken am Ende
   zurück oder liest die Reihenfolge der abgehakten Artikel aus dem erledigten Bereich — Festlegung
   im Test-Code, Kriterium: gelernte Sortierung ist an der Anzeige ablesbar (siehe offene Punkte
   zu „abgehakte Artikel in der Anzeige“). Erwartet: Gouda, Brot, Apfel.

### Ablauf Test B „Schnelles Abhaken zu Hause lernt nichts“

Gleiche Lage wie A, aber `-routeCheckOffStepSecondsForUITests 0.1`; drei Haken (Gouda, Brot,
Apfel) liegen damit 0,1 s auseinander;
Neustart mit Offset 31; erwartet bleibt die feste Reihenfolge (Apfel, Brot, Gouda), es wurde nichts
gelernt. Schließt die Gegenrichtung der Bulk-Regel.

## Acceptance Criteria

- AC-1: Mit `-seedShoppingRouteForUITests -shoppingRouteNoLearnedModelForUITests` startet die App
  mit Laden „Wegeladen“ (Brot, Apfel, Gouda), leerem Trip und leerem Modell; die Liste zeigt im
  Modus Einkaufsweg die Reihenfolge Apfel, Brot, Gouda.
- AC-2: Ohne `-shoppingRouteNoLearnedModelForUITests` ist der Seed unverändert (Gouda, Brot, Apfel
  gelernt); `ShoppingRouteUITests` läuft ohne Änderung grün.
- AC-3: Test A tippt in der Ladenliste die Haken in der Reihenfolge Gouda, Brot, Apfel mit je
  5 s Abstand (Schrittweite per Launch-Argument), beendet die App, startet sie mit `-routeClockOffsetMinutesForUITests 31`
  neu und öffnet den Laden; die gelernte Reihenfolge ist Gouda, Brot, Apfel.
- AC-4: Test A prüft vor den Haken, dass die Reihenfolge Apfel, Brot, Gouda ist (ohne Lernen
  wäre das Ergebnis dieselbe wie am Anfang, der Test könnte sonst nicht scheitern).
- AC-5: Test B tippt drei Haken mit 0,1 s Abstand (Schrittweite per Launch-Argument), startet mit Offset 31 neu; die Reihenfolge
  bleibt Apfel, Brot, Gouda (nichts gelernt).
- AC-6: Beide Tests benutzen die echten Haken-Elemente der Ladenliste und
  `StoreDetailView.toggle`; es wird kein Trip, kein Modell und kein Zeitstempel von Hand
  gesetzt, außer dem Ausgangs-Seed in AC-1.
- AC-7: `tearDown()` jeder Testklasse-Instanz startet die App einmal mit
  `-clearShoppingRouteSeedForUITests` und beendet sie; danach existiert Laden „Wegeladen“ nicht
  mehr, und sein Trip und sein Modell sind entfernt (der Clear-Pfad ruft über
  `deleteAllStoresAndItems` die `removeRouteData()`-Bereinigung, Z. ~381 SmartCartApp). Ein
  nachfolgender Test sieht kein Restmodell aus Test A.
- AC-8: Der Offset wirkt nur über `Store.finalizeStaleTrip(now:)`-Vorgabe; `recordCheckOff`
  verwendet `RouteClock.checkOffTime()` (ohne Argument echte Zeit). Ein Unit-Test (oder UI-Beleg) zeigt: ohne Argument ist
  `RouteClock.now` ≈ `Date()` (Abweichung < 1 s).
- AC-9: Im Release-Build existiert weder `RouteClock`-Offset-Code noch lesen `Store` oder
  `SmartCartApp` ein Launch-Argument; `finalizeStaleTrip(now:)` hat dort das Verhalten
  `now: Date()` wie vor der Änderung. Nachweis: `xcodebuild -configuration Release` baut
  fehlerfrei, und der Offset-Teil steht in `#if DEBUG`.
- AC-10: Alle bestehenden Unit- und UI-Suiten bleiben grün im gemeinsamen Lauf
  (`xcodebuild test`, Scheme `Restock`, deutsch), insbesondere `ShoppingRouteTests` und
  `ShoppingRouteUITests`.
- AC-11: Stabilität: drei Gesamtläufe der neuen Testklasse in Folge, alle grün (jeweils
  Testzahl > 0, keine Abbrüche, kein Retry-Flag).
- AC-12: Pflicht-Durchlauf: App im Simulator (Stand, den Henning bekommt) starten, in einer
  echten Ladenliste Haken mit Abstand setzen, App mit Offset neu starten, gelernte Reihenfolge
  ansehen; Nachweis als registriertes Artefakt (Commit-Kennung und Zeitstempel passen zum
  Stand), nicht von Hand gesetzt.
- AC-13: Umfang eingehalten: ≤ 5 Dateien, ±250 LoC; keine Änderung an Regeln in
  `ShoppingRoute.swift`.

## Tests

| # | Testfall | Art | Prüft |
|---|----------|-----|-------|
| T1 | `testRouteIsLearnedFromSlowCheckOffs` (Test A) | UI | AC-1, 3, 4, 6 |
| T2 | `testFastCheckOffsAtHomeLearnNothing` (Test B) | UI | AC-1, 5, 6 |
| T3 | tearDown-Prüfung: nach dem Aufräumen startet der Seed-Test B mit leerem Modell (Reihenfolge der Tests egal) | UI | AC-7 |
| T4 | `RouteClock.now` ohne Argument ≈ `Date()` | Unit | AC-8 |
| T5 | Release-Build, `#if DEBUG`-Prüfung per `grep`/Build | Build | AC-9 |
| T6 | Bestandssuiten gemeinsamer Lauf | UI+Unit | AC-2, AC-10 |
| T7 | Wiederholung 3x | UI | AC-11 |
| T8 | Durchlauf im Simulator, Artefakt | manuell-durch-Werkzeug | AC-12 |

Randbedingungen: Wartezeiten großzügig (Kachel 15 s, App-Idle nach kaltem Start bis 15 s);
Tests laufen auf Deutsch (Scheme pinnt `de`/`DE`), Texte wie „Wegeladen,“ sind deutsch;
Seeds räumen in `tearDown()` auf (Projektregel, App-Group-Container überlebt den Test);
Simulator nie parallel nutzen, eigenes Testgerät Restock-Validate.

## Risiken

- **Tippabstand auf dem CI-Runner (eingetreten, PR #104):** Taps brauchen dort > 2 s; Test B lernte
  den Weg. Behoben, indem die App den Abstand der Haken vorgibt (`RouteClock.checkOffTime()`),
  nicht der Testläufer. Der Test hängt damit nicht mehr am Tempo des Runners.
- **App startet ohne Launch-Argumente (eingetreten, PR #104 und lokal in rund jedem 5. Start des
  ersten Tests):** Der Testläufer startet die App gelegentlich ganz ohne Argumente (gemessen am
  App-Protokoll: Prozess ohne `-seed…`, `-AppleLanguages` usw.). Ohne Seed zeigt die Startseite
  „Noch keine Läden“, die Kachel erscheint nie. Kein Produktfehler (CloudKit-Vermutung geprüft und
  verworfen). `openStore` startet die App deshalb einmal neu, wenn die Kachel nach 15 s fehlt.
  Belege: `attempts/b-repro-loop4*.txt`, `test-class-12runs-relaunch-output.txt` (7 von 7 grün).
  Folgearbeit für alle gesäten UI-Tests: Issue #105.
- **Produktcode-Berührung:** `finalizeStaleTrip` ist Produktpfad; Vorgabe `RouteClock.now` darf im
  Release exakt `Date()` bleiben (AC-9).
- **Seed-Wechselwirkung:** `clear...` und `seed...` laufen im selben App-Start nacheinander
  (SmartCartApp Z. 38/39); beide Argumente nie gemeinsam übergeben.
- **Abgehakte Artikel in der Anzeige:** nach den Haken sind die Artikel im Bereich „erledigt“;
  die Reihenfolge dort entspricht ggf. nicht der Sortierung der offenen Liste. Der Test muss einen
  ablesbaren Zustand wählen (Haken beim Neustart zurücknehmen oder erledigt-Bereich lesen),
  ohne den Trip zu verändern, den er prüft. Zurücknehmen nach dem Lernen ist unkritisch, da der
  Trip dann bereits abgeschlossen ist.

## Alternativen

- **Nur Unit-Test über `Store.recordCheckOff` + `finalizeStaleTrip(now:)`:** kein Produktcode,
  aber `StoreDetailView.toggle` (die Verdrahtung) bliebe ungetestet; schließt #98 Punkt 1 nicht.
- **Trip alt säen, nur das Öffnen testen:** wieder halber Weg, das Abhaken fehlt (genau die Lücke).
- **`tripGap` per Launch-Argument auf ca. 3 s verkürzen:** keine Uhr nötig, ändert aber die Regel
  unter Test und trennt Test B (< 2 s) schlechter. Verworfen.
- **Mit Regel statt Test-Hilfe:** nicht anwendbar, es geht um Testverdrahtung, nicht um Logik.
- Gekippte Entscheidung: keine (`docs/specs/models/shopping-route-order.md` bleibt gültig).

## Offene Punkte

- Der Haken über den Bearbeiten-Dialog (`EditItemView.swift:207`) und `applyPendingCheckoffs`
  (Widget/Island, `batched`) sind bewusst **ausgeschlossen**, um die Limits zu halten; sie kommen
  in Durchgang 2/3 von #98.
- Genauer Ort von `RouteClock` (in `Store.swift` am Dateiende oder neben `ShoppingRoute`) wird in
  der Implementierung entschieden; Bedingung: ≤ 5 Dateien insgesamt.
- Nach Abschluss: Verweis in `CLAUDE.md` (Abschnitt Build/UI-Tests, DEBUG-Argumente) ergänzen,
  falls das Limit es erlaubt, sonst im Folgedurchgang.
