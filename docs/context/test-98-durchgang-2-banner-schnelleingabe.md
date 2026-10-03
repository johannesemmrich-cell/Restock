# Context: #98 Durchgang 2 — Nachkauf-Banner, „Vielleicht auch fällig“, Schnelleingabe

## Request Summary
Ein Ticket, mehrere Durchgänge (Entscheidung Henning 2026-10-03; Limits gelten je Durchgang). Durchgang 2 schließt
die Punkte (2) und (3) aus #98: ein UI-Test je Punkt, der den **echten Weg** fährt (nicht nur die Regeln,
die unit-getestet sind). Durchgang 1 (Abhaken + Einkaufsweg lernen) ist mit PR #104 erledigt.

## Wichtigster Befund: beide Nachkauf-Oberflächen gibt es nur im Entwicklermodus
- `HomeView.swift:162` — `if developerMode && !dueSoonItems.isEmpty { replenishmentBanner }`
- `HomeView.swift:1622` — `refreshDueSoon()` leert `dueSoonItems`, solange `developerMode` aus ist
  („Nachkauf-Erinnerungen sind kein Feature der normalen Version mehr“, Commit 3e4eb55)
- `StoreDetailView.swift` — `refreshAlsoDue()` ebenso (`guard developerMode`)
→ Die UI-Tests müssen mit `-developerMode YES` starten (Muster existiert in `RestockUITests.swift:250`,
`ReceiptResolutionStatsUITests.swift:55`). Ob die Funktion bewusst hinter dem Entwicklermodus bleibt,
ist eine Produktentscheidung und nicht Gegenstand dieses Durchgangs — nur als Hinweis an den PO.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `SmartCart/Views/Home/HomeView.swift` | Banner (`replenishmentBanner` Z. 853), „Hab noch“ (`snoozeDueItem`), „Nicht mehr vorschlagen“ (`blockDueItem`), `addSingleDueItem`, `addDueSoonToList`, Schnelleingabe (`quickAddBar` Z. 700, `quickAdd()` Z. 1445), Korrektur-Sheet (`showStoreCorrection`) |
| `SmartCart/Views/Store/StoreDetailView.swift` | „Vielleicht auch fällig“ (Section ~Z. 690, `alsoDueRow`, `refreshAlsoDue`, `addAlsoDue`, `snoozeAlsoDue`, `blockAlsoDue`) |
| `SmartCart/Services/HabitService.swift` | Fälligkeit: `minimumPurchases = 3`, `dueSoonItems`, `dueBeforeNextVisit`; `ReplenishmentSnoozes` (UserDefaults `snoozedReplenishments`), `ReplenishmentBlocklist` (`blockedReplenishments`) |
| `SmartCart/Models/PurchaseRecord.swift` | `consumptionPattern`; `date` ist im `init` fest `Date()`, für den Seed muss `date` danach von Hand gesetzt werden |
| `SmartCart/SmartCartApp.swift` | Seed-Muster: `seed…ForUITestsIfNeeded` / `clear…ForUITestsIfNeeded`, DEBUG-only, hinter Launch-Argumenten (Z. 30–43, Vorbild `seedShoppingRouteForUITestsIfNeeded` Z. 275) |
| `RestockUITests/QuickAddAssignmentUITests.swift` | Deckt Schnelleingabe schon teilweise ab (siehe unten) |
| `RestockUITests/ShoppingRouteLearningUITests.swift` | Vorbild aus Durchgang 1: `openStore`-Wiederholung gegen #105, `tearDown` räumt per `clear…`-Argument |
| `RestockTests/ReplenishmentPackageCTests.swift` | Unit-Tests der Regeln (Snooze/Blocklist), bleiben unverändert |
| `RestockUITests/*.swift` + `project.pbxproj` | neue Testdatei muss in vier pbxproj-Stellen registriert werden |

## Ist-Stand der Abdeckung
**Schnelleingabe (Punkt 3)** — `QuickAddAssignmentUITests` (9 Tests) prüft schon: Ziel-Karte mit Grund, Laden-Chip überschreibt,
Toast nennt Laden und bietet „Laden ändern“/„Rückgängig“, Rückgängig entfernt, Toast bleibt > 2 s, „Ohne Laden“-Karte,
Zuordnen-Sheet. **Offen (zu bestätigen in `/20-analyse`):**
- Landet der Artikel nach Return **wirklich in der Liste des Ladens** (Ladenliste öffnen, Artikel sehen)? Heute prüft kein Test das Ende der Kette.
- „Laden ändern“ im Toast → Korrektur-Sheet → Artikel wechselt den Laden und die Korrektur wird gemerkt (Override).
- Mengen-Parsing live (`500 gramm Hackfleisch` → Name/Menge in Liste) — Regeln sind unit-getestet, Anzeige in der Liste nicht.

**Nachkauf-Banner und „Vielleicht auch fällig“ (Punkt 2)** — kein UI-Test. Unit-getestet sind nur die Regeln.
Zu schließen sind je Oberfläche: Anzeige, `+` (Artikel landet in der Liste und der Vorschlag verschwindet),
„Hab noch“ (Vorschlag verschwindet, Termin verschoben), „Nicht mehr vorschlagen“ (verschwindet, erscheint auch nach Neustart nicht wieder),
Alle hinzufügen (nur Banner).

## Hürden für einen echten Durchlauf
1. **Seed der Kaufhistorie**: mindestens 3 Kauftage je Artikel mit regelmäßigem Abstand, letzter Kauf so, dass der Artikel heute fällig/überfällig ist
   (`PurchaseRecord.date` nach `init` setzen). Der Seed darf nur Rohdaten (Käufe, Läden) anlegen — **nicht** `dueSoonItems` setzen,
   sonst prüft der Test den halben Weg (Lehre vom 2026-09-27).
2. **Zustand außerhalb von SwiftData**: Snoozes, Blocklist, „accepted“/„dismissed“ liegen in UserDefaults. Der App-Group-/Defaults-Zustand
   überlebt den Test → `clear…`-Argument muss auch diese Schlüssel löschen (Memory „UI-Test-Seeds müssen aufräumen“).
3. **Zuordnung**: „Vielleicht auch fällig“ erscheint nur in dem Laden, den `AssignmentService.assign` für den Artikel wählt; Seed-Läden
   und Kaufhistorie (`storeName`) müssen dazu passen.
4. **Developer-Mode** per Launch-Argument; `refreshDueSoon` plant bei `notificationsEnabled` Benachrichtigungen — im Seed aus lassen (keine Berechtigungsabfrage im Test).
5. **Zeit**: Fälligkeit hängt von `Date()`; Seed-Daten relativ zu „jetzt“ (Tage zurück), nicht feste Daten.
6. **Runner-Eigenheiten**: App startet gelegentlich ohne Launch-Argumente (#105) → zweiter Start wie in `ShoppingRouteLearningUITests.openStore`;
   Tasten kommen auf dem Runner verspätet an → auf Feldzustand warten, kein einmaliges Lesen.
7. **Menü-Bedienung**: „Hab noch“/„Nicht mehr vorschlagen“ liegen in einem `Menu` (✕-Symbol) — im Banner ohne `accessibilityIdentifier`; Bedienung per Label oder neue Identifier (kleiner Produktcode-Eingriff).

## Existing Patterns
- Seed per Launch-Argument, DEBUG-only, `deleteAllStoresAndItems` + eigene Läden/Artikel; Aufräumen per eigenem `-clear…ForUITests`-Start im `tearDown()`.
- UI-Tests finden Elemente über `accessibilityIdentifier` (Schnelleingabe: `quickAdd.*`) oder über Label-Text (Kacheln `BEGINSWITH "<Laden>,"`).
- Scheme-Sprache fest Deutsch (Labels sind deutsch).

## Dependencies
- Upstream: `HabitService`, `ReplenishmentSnoozes`, `ReplenishmentBlocklist`, `ReplenishmentFeedback`, `AssignmentService`, `StoreVisitForecast`.
- Downstream: nur Testcode und DEBUG-Seed; Release-Verhalten bleibt unverändert.

## Existing Specs
- `docs/specs/ui-tests/shopping-route-learning-uitest.md` — Format-Vorbild aus Durchgang 1
- `docs/context/test-98-testluecken.md` — Gesamtübersicht der Durchgänge

## Risks & Considerations
- **Umfang**: Banner + Ladenliste + Schnelleingabe in einem Durchgang ist an der Grenze (4–5 Dateien, ±250 LoC). Voraussichtlich:
  `SmartCartApp.swift` (Seed + clear), `HomeView.swift`/`StoreDetailView.swift` (ggf. Identifier), zwei neue Testdateien, `project.pbxproj`.
  Wird es mehr, in `/20-analyse` mit Schätzung zurückmelden (Schnelleingabe-Lücke ist der Kandidat zum Verschieben — Henning entscheidet, nicht ich).
- Tests dürfen den Seed nicht „vorwegnehmen“: Fälligkeit muss aus der Kaufhistorie entstehen, die App berechnet sie selbst.
- Pflicht-Durchlauf vor Übergabe (Henning, 2026-09-27): App im Simulator mit Developer-Mode starten, Banner und Ladenliste ansehen und bedienen.
- Regeln vor Modell: hier kein Modell im Spiel; alles deterministisch.

## Alternativen (Vorgriff auf /20-analyse)
- Seed über UserDefaults/SwiftData-Zustand direkt (`dueSoonItems` fest) — verworfen: prüft nur die Anzeige, nicht die Fälligkeitskette.
- Fälligkeit per Uhr-Offset statt rückdatierter Käufe (Muster aus Durchgang 1, `RouteClock`) — möglich, aber rückdatierte Käufe sind einfacher und näher an echten Daten.

## Analysis (2026-10-03, /20-analyse #98)

### Type
Feature (reiner Testaufbau, kein sichtbarer Produktumbau → kein Entwurfs-Artefakt nötig; Produktcode nur: Accessibility-Identifier).

### Recherche (vor der Analyse)
- Apple-Foren: SwiftUI-`Menu` ist in XCUITest seit iOS 15 heikel (Identifier fehlt in `app.buttons`, Workaround `app.images[...]`; bei Menüs in Form/List ebenfalls Tap-Probleme):
  https://developer.apple.com/forums/thread/690882 · https://developer.apple.com/forums/thread/760070 · https://developer.apple.com/forums/thread/713900
  → Menü-Bedienung ist das Hauptrisiko; früh am echten Simulator prüfen (Identifier auf dem Menü-Label, Fallback Label-/Image-Suche).

### Scope-Empfehlung (Limit-Überschreitung vermieden)
Banner + „Vielleicht auch fällig“ + Schnelleingabe in einem Durchgang ≈ 6 Dateien / ~330 LoC → über Limit.
**Durchgang 2 = Punkt 2 (Banner + „Vielleicht auch fällig“).** Schnelleingabe (Punkt 3) → **Durchgang 3** im selben Ticket #98 (Henning lehnt Ticket-Splitten ab, Limits gelten je Durchgang).

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/SmartCartApp.swift` | MODIFY | `-seedReplenishmentForUITests` / `-clearReplenishmentForUITests` (DEBUG): Läden + rückdatierte `PurchaseRecord`s (≥3 Kauftage, regelmäßig, heute fällig); clear löscht auch UserDefaults-Schlüssel `snoozedReplenishments`, `blockedReplenishments`, `dismissedReplenishments`, `acceptedReplenishments`, Metrik-Zähler |
| `SmartCart/Views/Home/HomeView.swift` | MODIFY | Identifier: `replenish.addAll`, `replenish.add.<Name>`, `replenish.menu.<Name>` (+ Menüpunkte) |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | Identifier analog für `alsoDueRow` |
| `RestockUITests/ReplenishmentUITests.swift` | CREATE | Tests Banner + Ladenliste, `-developerMode YES`, App-Neustart-Wiederholung (#105), `tearDown` räumt auf |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Testdatei in 4 Stellen |

### Scope Assessment
- Files: 5 · LoC ≈ +210 · Risk: LOW (nur DEBUG-Seed, Release unverändert; Identifier ändern keine Texte)

### Technical Approach (Regelweg, kein Modell im Spiel)
- Seed legt **nur Rohdaten** an (Läden, Käufe mit `date` = jetzt − n Tage, relativ zu „jetzt“). Fälligkeit rechnet die App selbst (`HabitService`), nie `dueSoonItems` setzen.
- Getrennte Artikel für Banner- und Ladenliste-Tests, damit sich die Aktionen nicht beeinflussen (derselbe Artikel erscheint sonst in beiden Oberflächen). Zuordnung: Käufe mit `storeName` = Seed-Laden → `AssignmentService.assign` wählt ihn.
- Tests je Oberfläche: Anzeige · `+` (Artikel steht danach in der Ladenliste, Vorschlag weg) · „Hab noch“ (weg; Snooze-Eintrag/Termin verschoben) · „Nicht mehr vorschlagen“ (weg und nach App-Neustart weiterhin weg) · Banner zusätzlich „Alle hinzufügen“.
- Negativ-Kontrolle: ohne Developer-Mode kein Banner (belegt den bekannten Befund).
- Pflicht-Durchlauf vor Übergabe: App im Simulator mit Seed + Developer-Mode starten, bedienen, Nachweis registrieren.

### Alternativen (Pflicht)
1. **Fälligkeit hart setzen** (UserDefaults/`dueSoonItems`) — verworfen, prüft nur die Anzeige (Lehre 2026-09-27).
2. **Uhr-Offset statt rückdatierter Käufe** (Muster `RouteClock` aus Durchgang 1) — gangbar, aber mehr Produktcode; kippt keine ADR, nur aufwändiger.
3. **Funktion aus dem Entwicklermodus holen** (Produktthema) — würde Commit 3e4eb55 („kein Feature der normalen Version“) kippen; nicht Teil dieses Durchgangs, **Frage an PO unten**.
4. **Statt UI-Test für „Nicht mehr vorschlagen“-Neustart** nur Unit-Test — verworfen: Kette Menü → UserDefaults → Refresh ist genau die Lücke.

### Dependencies
`HabitService`, `ReplenishmentSnoozes`, `ReplenishmentBlocklist`, `ReplenishmentFeedback`, `AssignmentService`, `StoreVisitForecast`; Muster `ShoppingRouteLearningUITests`.

### Open Questions
- [ ] PO: Bleiben Banner und „Vielleicht auch fällig“ bewusst im Entwicklermodus? (Tests laufen so oder so mit `-developerMode YES`.)
- [ ] PO: Schnelleingabe als Durchgang 3 — einverstanden?
