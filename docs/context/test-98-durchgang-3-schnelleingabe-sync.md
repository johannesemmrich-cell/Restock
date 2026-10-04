# Context: #98 Durchgang 3 — Schnelleingabe (Rest), Geteilte Läden/Sync, deleteStoreFiles

## Request Summary
Ein Ticket, mehrere Durchgänge (Entscheidung Henning 2026-10-03; Limits gelten je Durchgang). Durchgang 1 (PR #104) und 2 (PR #106) sind gemergt.
**Unklarheit im Ticket:** Die Checkliste im ersten Kommentar nennt für Durchgang 3 die Punkte (4) Sync und (8) `deleteStoreFiles`.
Der Abschlusskommentar zu Durchgang 2 nennt dagegen als „Offen: Durchgang 3“ den Rest von Punkt (3) Schnelleingabe.
Beides ist offen. Vorschlag für `/20-analyse`: Schnelleingabe-Rest + (8) in Durchgang 3 (klein, reiner App-Weg), Sync (4) wegen CloudKit
in einen eigenen Teil bzw. Durchgang 4 verschieben — Entscheidung in der Analyse mit dem Limit begründen.

## Stand der Abdeckung

### (3) Schnelleingabe — Rest
`QuickAddAssignmentUITests` (9 Tests) deckt: Zielkarte + Grund, Chip überschreibt, Toast mit „Laden ändern“/„Rückgängig“, Rückgängig,
Toast > 2 s, Unzugeordnet-Karte, Alle übernehmen, Einzelzuordnung. **Fehlt (Ende der Kette):**
- Artikel steht nach Return wirklich in der Liste des Ladens (Ladenliste öffnen).
- „Laden ändern“ im Toast → Korrektur-Sheet (`showStoreCorrection`) → Artikel wechselt den Laden, Korrektur wird gemerkt
  (`StoreAssignmentOverrideService.remember`, `HomeView.swift` ~1546–1557) und gilt beim nächsten Eintippen desselben Namens.
- „500 gramm Hackfleisch“: Menge/Einheit in der Liste sichtbar (Regeln sind in `QuickAddParserTests` unit-getestet, Anzeige nicht).

### (8) `SmartCartApp.deleteStoreFiles` (Notfallpfad, Stufe 3)
`private static`, nur aus `SmartCartApp.init()` erreichbar, wenn `SharedModelContainer.make()` nil liefert. Löscht `*.store`, `-shm`, `-wal` im
App-Group-Container und im alten App-Container, setzt vorher `smartcart.dataResetOccurred` (HomeView zeigt danach einmaligen Hinweis).
Nie ausgeführt; Vorgeschichte: Datenverlust (31.07.2026).
Hürden: Pfad ist `private`, Auslöser (Container-Fehler) lässt sich im Simulator nicht natürlich erzeugen. Optionen für die Analyse:
(a) Funktion auf Verzeichnis-Parameter umstellen und per Unit-Test gegen ein Wegwerf-Verzeichnis fahren (löscht nur `.store*`, lässt Fremddateien stehen);
(b) DEBUG-Launch-Argument, das `SharedModelContainer.make()` scheitern lässt, und UI-Test auf Hinweis „Daten zurückgesetzt“.
(b) fährt den echten Weg (Lehre vom 2026-09-27), (a) ist billiger — Alternative und Kosten in der Analyse gegenüberstellen.

### (4) Geteilte Läden / Sync
- `SyncCoordinator.apply(items:members:deletedIDs:prices:…categories:assignments:modifiedAt:to:)` (`SyncCoordinator.swift:229`) ist reine Merge-Logik
  auf einem `Store` + `ModelContext`: Mitglieder, eigene Kategorien (#85, `StoreCategories.merge`), Zuordnungen (#94), Preise (`LearnedPriceSync.apply`),
  Löschvermerke, Last-write-wins pro Artikel, `markSynced`. **Ohne CloudKit testbar**, wenn `modelContext` injiziert wird (Property existiert) — Unit-Test
  mit In-Memory-Container möglich. `markSynced` nutzt den `SharedStoreService.shared`-Actor (CloudKit nur beim echten Push/Pull).
- `SharedStoreService.merge(local:remote:tombstones:)` (privat, Z. 134) und `mergeIntoRecord` (Z. 83): arbeiten auf `CKRecord`, `CKContainer`
  ist fest im Singleton (`SharedStoreService.swift:8`) → Test braucht Zugang (internal statt private) oder reinen Merge auslagern.
- Vorhandene Unit-Tests: `LearnedPriceSyncTests`, `SharedItemDataPhotoRegressionTests` (nur Encode/Decode), `StoreCategoriesTests`.
- **Nicht automatisierbar:** echtes CloudKit-Teilen mit zweitem Konto (Einladung, Annahme, Push-Benachrichtigung). Muss mit Begründung im Ticket stehen.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `SmartCart/Views/Home/HomeView.swift` | `quickAdd()` Z. 1448, Toast/Korrektur Z. 1503–1557, `showStoreCorrection` Z. 45/244 |
| `SmartCart/Services/AssignmentService.swift`, `StoreAssignmentOverrideService` | Zuordnung + gemerkte Korrektur |
| `RestockUITests/QuickAddAssignmentUITests.swift` | Bestandstests, Seed- und Aufräum-Muster |
| `SmartCart/SmartCartApp.swift` | Notfallpfad Z. 78/126; Seed-/Clear-Launch-Argumente (DEBUG) |
| `SmartCart/Models/SharedModelContainer.swift` | Auslöser des Notfallpfads; Warnkommentar vor Änderung lesen |
| `SmartCart/Services/SyncCoordinator.swift` | `apply`, `pull`, `push`, `pushInBackground` |
| `SmartCart/Services/SharedStoreService.swift` | `merge`, `mergeIntoRecord`, `LearnedPriceSync` |
| `RestockTests/*`, `RestockUITests/*` + `project.pbxproj` | neue Dateien in vier pbxproj-Stellen registrieren |

## Existing Patterns
- Seed per DEBUG-Launch-Argument + eigenes `-clear…ForUITests` im `tearDown()` (App-Group überlebt den Test).
- `openStore`-Wiederholung gegen #105 (App startet gelegentlich ohne Launch-Argumente), Warten auf Feldzustand statt einmaligem Lesen.
- Scheme-Sprache fest Deutsch; Tests asserten auf deutsche Labels.
- Regel vor Modell: alles hier ist deterministisch, kein Modell beteiligt.

## Dependencies
- Upstream: SwiftData, `AssignmentService`, `QuickAddParser`, UserDefaults (Overrides), CloudKit (nur Sync-Netzpfad).
- Downstream: Widget-Reload (`WidgetCenter`), Ladenliste, `UnassignedItemsCard`.

## Existing Specs
- `docs/specs/ui-tests/replenishment-uitest.md`, `docs/specs/ui-tests/shopping-route-learning-uitest.md` (Vorbilder fürs Format)
- `docs/context/test-98-testluecken.md`, `docs/context/test-98-durchgang-2-banner-schnelleingabe.md`

## Risks & Considerations
- Scope: Schnelleingabe-Rest + (8) + (4) zusammen sprengen vermutlich ±250 LoC / 4–5 Dateien → in der Analyse schneiden und Rest ins Ticket schreiben.
- Notfallpfad löscht Daten: Test nie gegen echten App-Group-Container des Entwicklers, nur Wegwerf-Verzeichnis/frischer Simulator.
- Zum Testen privater Funktionen Sichtbarkeit nur minimal ändern (kein Drive-by-Refactoring).
- Der Arbeitszweig steht auf dem Stand vor dem Squash-Merge von PR #106; vor Phase 6 auf `origin/main` zurücksetzen (Diff ist leer, siehe Memory „Squash-Merge lässt Worktree divergieren“).

## Analysis

### Type
Feature (reine Testabdeckung, #98 Durchgang 3). Kein Fehler, keine sichtbare UI-Änderung → keine Entwurfs-Vorschau nötig (Regel „Entwurf vor Spec“ greift nur bei Umgestaltung). Kein Modell beteiligt: alles deterministisch, Regeln vor Modell erfüllt.

### Entscheidung zum Schnitt (Unklarheit aus dem Kontext)
**Durchgang 3 = Schnelleingabe-Rest (3) + `deleteStoreFiles` (8). Sync (4) → Durchgang 4.**
Begründung: Teil (3)+(8) braucht nur den App-Weg im Simulator (~200 LoC, 4–5 Dateien). Sync (4) bräuchte zusätzlich Änderungen an Sichtbarkeit in `SharedStoreService`/Testaufbau mit In-Memory-Container (eigene Testdatei, ~150 LoC) und sprengt zusammen die Limits. Außerdem haben (3)/(8) und (4) kein gemeinsames Ziel (UI-Kette vs. Merge-Logik).

### Affected Files (Durchgang 3)
| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY (+~110) | 3 Tests: Artikel steht in der Ladenliste; „Laden ändern“ → Wechsel + Korrektur gilt beim nächsten Eintippen; „500 gramm Hackfleisch“ zeigt Menge/Einheit |
| `RestockUITests/DataResetUITests.swift` | CREATE (+~70) | Notfallpfad: Seed-Lauf, dann Lauf mit erzwungenem Container-Fehler → Hinweis „Daten zurückgesetzt“, Seed-Läden weg, App bedienbar |
| `SmartCart/SmartCartApp.swift` | MODIFY (+~8, DEBUG) | Launch-Argument `-forceContainerFailureForUITests`: überspringt `SharedModelContainer.make()`, damit Stufe 3 echt durchlaufen wird |
| `SmartCart/Views/Home/QuickAddTargetViews.swift` / `HomeView.swift` | MODIFY (+~6) | Nur falls Identifier für Korrektur-Sheet/Listenzeilen fehlen (Toast hat `quickAdd.toast.change`/`.undo`) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue UI-Testdatei in 4 Stellen registrieren |

Scope: 4–5 Dateien, ca. +200 LoC, Risiko NIEDRIG (Produktcode nur DEBUG-Zweig).

### Technical Approach
- **(3)** Bestehendes Seed-/tearDown-Muster (`-seedQuickAddAssignmentForUITests`/`-clear…`) wiederverwenden. Nach Return die Ladenliste öffnen und den Artikel finden; „Laden ändern“ → anderen Laden wählen → in Ladenliste prüfen; danach denselben Namen erneut tippen und prüfen, dass die Ziel-Karte den gemerkten Laden nennt (Grund-Satz „gemerkt“). Gemerkte Korrektur wird vom bestehenden Clear-Argument geleert (`StoreAssignmentOverrideService`-Reset im Seed) — in Phase 3 verifizieren.
- **(8) Empfehlung (b):** DEBUG-Argument erzwingt den Container-Fehler; UI-Test fährt den echten Weg (Flag setzen → `deleteStoreFiles` → neuer Container → HomeView-Alert `data.reset.*`). Vorher Seed-Lauf, damit Store-Dateien existieren und das Löschen beweisbar ist (Läden „Lidl“/„dm“ danach weg). Nur im Test-Simulator (eigenes Gerät Restock-Validate), nie gegen Entwicklerdaten. Aufräumen: Clear-Lauf + `smartcart.dataResetOccurred` wird von HomeView selbst entfernt.
- Offene Grenze (in jede Zusage): Der natürliche Auslöser (Container-Fehler im Simulator) lässt sich nicht erzeugen; geprüft wird alles ab Stufe 3. Dass `make()` in der Praxis nil liefert, deckt dieser Test nicht ab.

### Alternativen
1. **(a) `deleteStoreFiles` auf Verzeichnis-Parameter umstellen + Unit-Test im Wegwerf-Verzeichnis**: billiger, prüft auch „Fremddateien bleiben stehen“. Aber ändert `private` → intern/parametrisiert und kippt die Entscheidung vom 31.07.2026 („wieder `private`, nur Notfallpfad“), prüft nur die Funktion, nicht die Kette bis zum Hinweis (Lehre 2026-09-27). → Als Ergänzung später möglich, nicht jetzt.
2. **Schnelleingabe-Rest als Unit-Test** (Parser/Override-Service): existiert schon (`QuickAddParserTests`); prüft nicht, ob etwas in der Liste ankommt → verworfen.
3. **Sync zuerst (Durchgang 3 = 4+8)**: möglich, aber ohne zweites iCloud-Konto bleibt echtes Teilen ohnehin nicht automatisierbar; Merge-Logik ist rein, daher günstiger Folgeschritt.

### Dependencies
- Upstream: `SmartCartApp.init` Stufen 1–4, `SharedModelContainer.make()` (Warnkommentar beachtet: nur Aufrufer-Seite DEBUG-Zweig, keine Änderung an `make()`), `StoreAssignmentOverrideService`, `QuickAddParser`.
- Downstream: HomeView-Alert (`data.reset.title/message`), Ladenliste.

### Durchgang 4 (vorgemerkt, wird als Ticket-Kommentar festgehalten)
(4) Sync: `SyncCoordinator.apply` mit In-Memory-Container (Mitglieder, Kategorien #85, Zuordnungen #94, Preise, Löschvermerke, Last-write-wins, `markSynced`); `SharedStoreService.merge` (private → internal oder auslagern). Nicht automatisierbar: echtes CloudKit-Teilen mit zweitem Konto — mit Begründung ins Ticket.

### Open Questions
- [ ] Keine für Henning (alles technische Entscheidung). Offen für Phase 3: genaue Identifier der Ladenliste/Korrektur-Sheet prüfen.
