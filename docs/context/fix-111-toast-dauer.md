# Context: fix-111-toast-dauer (#111, Durchgang 2)

## Request Summary
Der Schnell-Hinzufügen-Toast steht fest 6 s (`HomeView.swift:1479`). Auf dem CI-Runner brauchen
einzelne UI-Abfragen 3–4 s (Messung Durchgang 1), mehrere Prüfungen hintereinander überschreiten die 6 s;
`testToastNamesStoreAndOffersChangeAndUndo` sieht den Toast dann nicht mehr. Ziel: Toast-Tests beim ersten
Versuch grün, ohne dass der Toast im echten Betrieb länger oder kürzer steht.
Übergeordnet: #111, Plan und Recherche in `docs/context/fix-111-ui-test-flakes.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Home/HomeView.swift:1479` | Aufruf `showQuickAddToast(..., duration: 6)` nach dem Hinzufügen |
| `SmartCart/Views/Home/HomeView.swift:1495` | `showQuickAddToast`: Ausblend-Timer per `asyncAfter`, Token gegen ältere Timer, bleibt stehen solange `showStoreCorrection` offen |
| `SmartCart/Views/Home/HomeView.swift:229` | Neustart der Frist nach Schließen des Laden-Dialogs, fest `duration: 3` |
| `SmartCart/SmartCartApp.swift:70,190,289` | Muster für DEBUG-Launch-Argumente (`ProcessInfo.processInfo.arguments.contains`) |
| `RestockUITests/QuickAddAssignmentUITests.swift` | `launchedApp()` (Z. 33), Toast-Tests Z. 139, 153, 172, 275 |

## Betroffene Tests
- Lesen den Toast-Inhalt, brauchen Zeit: `testToastNamesStoreAndOffersChangeAndUndo` (139),
  `testUndoRemovesToastAndItem` (153), `testChangeStoreMovesItemAndRemembersCorrection` (275, mehrere Schritte nach dem Toast).
- Echte Dauer prüfen, bleibt ohne Argument: `testToastStaysVisibleLongerThanTwoSeconds` (172).
- Warten nur kurz auf Existenz des Toasts (260, 340): kein Bedarf.

## Existing Patterns
- DEBUG-Launch-Argumente werden in `SmartCartApp` per `ProcessInfo.processInfo.arguments` gelesen, in `#if DEBUG` gekapselt.
- Tests starten über `launchedApp()` mit `app.launchArguments`.

## Dependencies
- Upstream: `ProcessInfo`, `DispatchQueue.main.asyncAfter`.
- Downstream: nur die oben genannten UI-Tests; kein anderer Aufrufer von `showQuickAddToast` mit 6 s (Z. 229 nutzt 3 s).

## Alternativen
- A (Plan): Launch-Argument setzt die Anzeigedauer (z. B. 60 s) nur in drei Tests.
- B: Launch-Argument schaltet das Ausblenden in Tests ganz ab; robuster, aber Ausblend-Fehler fielen nur im Dauertest auf.
- C: Alle Prüfungen in einem Zug vor Ablauf lesen (Test umbauen). Verworfen: Einzelabfrage 31 s (XCTest-Grenze) bleibt unlösbar, Frist bleibt Glückssache.
Empfehlung: A. Kein ADR wird gekippt.

## Existing Specs
- Keine eigene Spec zum Toast gefunden außer dem Plan in `fix-111-ui-test-flakes.md`; `docs/specs` wird in `/30-write-spec` geprüft.

## Risks & Considerations
- Argument nur in `#if DEBUG`, im Release bleibt 6 s (Release-Build prüfen).
- Test-Dauer: Bei 60 s Anzeigedauer darf kein Test auf das Verschwinden warten (`testUndoRemovesToastAndItem` wartet auf Verschwinden nach Undo: das geschieht durch Undo, nicht durch den Timer, also unkritisch).
- Offene Grenzen bleiben: XCTest-Abfragegrenze, Wettlauf `frame`→`isHittable`→`tap()`.
- Nachweis: 30 Wiederholungen auf dem Runner vorher/nachher (wie Durchgang 1), danach Durchlauf im Simulator.
- Die Dateien-Grenze (4–5) wird mit 3 Dateien eingehalten.

## Analysis

### Type
Bug (Test-Flake, Ursache in #111 belegt; Durchgang 2 von 3)

### Befund der Code-Prüfung (2026-10-07)
Der Toast hat **drei** Fristen, nicht eine:
- `HomeView.swift:1483` — nach dem Hinzufügen: 6 s
- `HomeView.swift:229` — Neustart nach Schließen des Laden-Dialogs: 3 s
- `HomeView.swift:1561` — Toast „verschoben nach …“ nach Laden-Wechsel: 3 s

`testChangeStoreMovesItemAndRemembersCorrection` (Z. 275) liest die Toast-Meldung („dm“) direkt nach dem Wechsel — also gegen die 3-s-Frist von Z. 1561, nicht gegen die 6 s. Eine Einzelabfrage von 4 s reicht dort für einen Fehlschlag. Ein Argument, das nur die 6 s ändert, ließe diesen Test offen.
Konsequenz: Eine Stelle, die **alle drei** Fristen aus einem Wert bestimmt (Hilfsfunktion im `showQuickAddToast`: Test-Wert ersetzt `duration`, wenn das Argument gesetzt ist).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Home/HomeView.swift` | MODIFY | `showQuickAddToast` nimmt unter `#if DEBUG` die Dauer aus dem Launch-Argument `-quickAddToastDurationForUITests <Sekunden>` (gilt für alle drei Aufrufe); Release unverändert |
| `RestockUITests/QuickAddAssignmentUITests.swift` | MODIFY | `launchedApp(toastDuration:)`; 3 Tests (139, 153, 275) mit 60 s; Dauertest (172) ohne Argument |
| `RestockUITests/UITestWait.swift` | (kein Bedarf) | bleibt unberührt |

Hinweis zur Umsetzung: `UserDefaults.standard.double(forKey:)` liest `-key value` aus den Launch-Argumenten ohne eigenes Parsen; im Release-Build wird der Zweig nicht kompiliert.

### Scope Assessment
- Files: 2 (ggf. 3 mit Spec/Doku)
- Estimated LoC: +25/-5
- Risk Level: LOW (nur DEBUG-Zweig; Release-Verhalten gleich; Dauertest schützt die echte Frist)

### Technical Approach
Empfehlung A (Launch-Argument setzt Anzeigedauer, 60 s, nur in drei Tests), erweitert auf alle drei Fristen.
Alternativen: B (Ausblenden in Tests ganz aus) — verworfen, weil dann auch der Dauertest nichts mehr zur Frist sagen könnte und ein Ausblend-Fehler unentdeckt bliebe; C (Prüfungen in einem Zug lesen) — verworfen, Einzelabfrage bis 31 s bleibt Glückssache. Kein ADR wird gekippt. Regel-vor-Modell nicht berührt.

### Nachweis (für Spec/TDD)
- RED: Test, der mit Argument 60 s den Toast nach z. B. 8 s noch sieht (schlägt ohne Argument fehl), plus Dauertest ohne Argument bleibt grün.
- 30 Wiederholungen der drei Toast-Tests auf dem Runner vorher/nachher; Durchlauf im Simulator (Toast steht im Release-Verhalten weiter 6 s).
- Offene Grenzen unverändert: XCTest-Abfragegrenze (31 s), Wettlauf frame → isHittable → tap().

### Dependencies
`ProcessInfo`/`UserDefaults` (Argumente), `DispatchQueue.main.asyncAfter`; kein anderer Aufrufer außer den drei genannten Stellen.

### Open Questions
- [ ] Keine Rückfrage an den PO nötig (rein technisch). Übernahme von Durchgang 1+2 weiterhin erst nach #115-Fix und grüner CI (PO-Entscheidung 2026-10-06).
