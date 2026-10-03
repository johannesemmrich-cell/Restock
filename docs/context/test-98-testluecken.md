# Context: #98 Testlücken (Durchgang 1: Abhaken + Einkaufsweg lernen)

Ein Ticket, mehrere Durchgänge (Entscheidung Henning 2026-10-03). Umfangslimit gilt je Durchgang.

| Durchgang | Punkte aus #98 | Stand |
|-----------|----------------|-------|
| 1 | (1) Abhaken in der Ladenliste + Lernen des Einkaufswegs | Analyse |
| 2 | (2) Nachkauf-Banner, Vielleicht auch fällig; (3) Schnelleingabe | offen |
| 3 | (4) Geteilte Läden / Sync; (8) deleteStoreFiles | offen |
| 4 | (5) Tagesmitteilung, BGAppRefresh; (6) Siri/Widget; (7) Paywall/Onboarding/Premium/StoreSetup/Dev-Passwort | offen |

## Analysis (Durchgang 1)

### Type
Feature (Testarbeit, kein Produktfehler bekannt). Kleine DEBUG-only Testhilfe im Produktcode.

### Ist-Stand der Kette
`ItemRow`-Haken → `StoreDetailView.toggle(item:)` (Z. 1164) → `Store.recordCheckOff` (Store.swift:246) → `ShoppingRoute.recordCheckOff` (Trip in App-Gruppe) → bei Ruhe > 30 min `finalizeStaleTrip()` (StoreDetailView `.onAppear` Z. 102, `scenePhase` Z. 197) → `ShoppingRoute.learn` → `routeModel` → Sortierung `.route`.
Weitere Haken-Wege: `EditItemView.swift:207`, `applyPendingCheckoffs` (Widget/Island, `batched`).

Vorhandene Tests: `ShoppingRouteTests` (Regeln, Unit, mit festen Zeitstempeln) und `ShoppingRouteUITests` (Anzeige; **sät den gelernten Weg fertig** über `-seedShoppingRouteForUITests`). Kein Test tippt einen Haken und sieht danach eine gelernte Reihenfolge — die Kette `toggle → Trip speichern → finalize → learn → Sortierung` wird nie geschlossen.

### Hürden für einen echten Durchlauf
1. **30-Minuten-Ruhefenster**: gelernt wird erst, wenn der Einkauf ruht. Ein UI-Test kann nicht 30 min warten.
2. **Erkennung „zu Hause abgehakt“** (`isBulkCheckOff`): ≥3 direkt getippte Haken und ≥80 % der Abstände < 2 s → nichts wird gelernt. Schnelle Testtipps würden das auslösen. Vermutung, noch nicht gemessen: im Test ≥ 2,1 s zwischen den Haken warten.
3. **Seed**: der bestehende Seed hat bereits ein gelerntes Modell. Für den Durchlauf braucht es denselben Laden ohne Modell.

### Technischer Ansatz (Empfehlung)
Neuer UI-Test `ShoppingRouteLearningUITests`:
- Test A „Einkaufsweg wird beim Abhaken gelernt“: Laden mit Apfel/Brot/Gouda ohne gelerntes Modell; in der Reihenfolge Gouda, Brot, Apfel antippen (je ≥ 2,1 s Abstand); App beenden; mit simulierter Uhr +31 min neu starten und Laden öffnen → Reihenfolge Gouda, Brot, Apfel (ohne Lernen wäre sie Apfel, Brot, Gouda).
- Test B „Schnelles Abhaken zu Hause lernt nichts“: gleiche Lage, drei Haken im Abstand < 2 s → nach +31 min bleibt die feste Reihenfolge. (Schließt auch die Gegenrichtung der Regel.)
- Beide räumen in `tearDown()` per `-clearShoppingRouteSeedForUITests` auf (Trip und Modell des Seed-Ladens, prüfen, dass `removeRouteData` dabei greift).

Produktcode-Änderung, nur DEBUG:
- Launch-Argument `-routeClockOffsetMinutesForUITests <n>`: `Store.finalizeStaleTrip(now:)` nimmt als Vorgabe `RouteClock.now` (= `Date()` plus Offset, im Release immer `Date()`).
- Launch-Argument `-shoppingRouteNoLearnedModelForUITests` ergänzt den bestehenden Seed: Modell leer lassen.

Geschätzter Umfang: Dateien 4 (`Store.swift`, `SmartCartApp.swift`, neue Testdatei, `project.pbxproj`), ca. +150 LoC, davon ~20 Produktcode.

### Alternativen
- **Nur Unit-Test über `Store.recordCheckOff` + `finalizeStaleTrip(now:)`**: kein Produktcode nötig, aber `StoreDetailView.toggle` (die Verdrahtung, um die es geht) bliebe ungetestet. Würde #98 Punkt 1 nicht schließen.
- **Trip alt säen und nur das Öffnen testen**: wieder halber Weg, das Abhaken fehlt (genau die Lücke).
- **`tripGap` per Launch-Argument verkürzen (z. B. 3 s)**: kein Uhr-Offset, aber ändert die Regel selbst unter Test und lässt Test B (< 2 s) schwerer trennen. Verworfen; Uhr verschieben ist näher am echten Ablauf.
- Gekippte Entscheidung: keine (Spec `docs/specs/models/shopping-route-order.md` bleibt gültig).

### Risiko
Niedrig. Produktcode nur hinter `#if DEBUG`; Release-Verhalten unverändert. Risiko im Test: Tippabstände auf dem CI-Runner (siehe Memory „UI-Test-Wartezeiten“), deshalb drei Läufe als Stabilitätsnachweis.

### Pflicht-Durchlauf (Henning, 2026-09-27)
Vor Abschluss: App im Simulator starten, Haken in einer echten Ladenliste setzen, Ergebnis ansehen; Nachweis über das registrierte Artefakt (siehe #74).

### Open Questions
- [ ] Wirken zwei Haken im Abstand ≥ 2,1 s auf dem Runner zuverlässig als „im Laden“? (wird im ersten Lauf gemessen)
- [ ] Soll auch der Haken über den Bearbeiten-Dialog (`EditItemView:207`) in diesen Durchgang? Empfehlung: nein, später in Durchgang 2/3 mitnehmen, um das Limit zu halten.
