# Messläufe #111 Durchgang 2 — Zusammenfassung (2026-10-07)

Verfahren: Wegwerf-Stände `tmp-111d2-vorher` und `tmp-111d2-nachher`, nur dort `ci.yml` geändert
(Job `ui-test` allein, vier Tests aus `QuickAddAssignmentUITests`, `-test-iterations 30`, **kein** Retry,
xcresult immer hochgeladen). `ci.yml` auf `main` unverändert.

- **Nachher** (Lauf 37617155363): Stand `0f25033` (Fix), Tests starten mit `toastDuration: 60`.
- **Vorher** (Lauf 37617325110): derselbe Code, aber ein Schritt vor dem Bauen entfernt das Argument aus den
  Tests (`sed`). Ohne Argument gilt die feste Frist (6 s / 3 s), also das Verhalten der Hauptlinie. Grund für
  diesen Aufbau statt eines Hauptstands: Das Festschreiben auf einem Stand ohne Fix und ohne Prüfprotokoll
  lässt das Commit-Gate zu Recht nicht zu; zugleich ist es der sauberere A/B-Vergleich (dieselbe App).
  Abweichung vom Wortlaut „Stand `main`“ in AC-9, Begründung hier festgehalten.

| Lauf | Ausführungen | Fehlschläge | Laufzeit |
|---|---|---|---|
| Vorher | 120 (4 Tests × 30) | 7 | 70 min |
| Nachher | 120 (4 Tests × 30) | 3 | 65 min |

## Fehlschläge nach Ursache

| Test | Meldung | Ursache | Vorher | Nachher |
|---|---|---|---|---|
| `testChangeStoreMovesItemAndRemembersCorrection` | „Laden ändern“ fehlt / Toast nennt neuen Laden nicht | **Toast-Frist abgelaufen** | 2 | 0 |
| `testToastNamesStoreAndOffersChangeAndUndo` | „Rückgängig“ fehlt | **Toast-Frist abgelaufen** | 2 | 0 |
| `testUndoRemovesToastAndItem` | „Rückgängig“ fehlt | **Toast-Frist abgelaufen** | 1 | 0 |
| `testUndoRemovesToastAndItem` | Timeout 5 s auf `exists == 0` | 5-s-Wartefrist, langsame Abfrage | 1 | 0 |
| `testToastNamesStoreAndOffersChangeAndUndo` | „Der Toast nennt den Laden nicht — bekommen: „Nudeln“ → Lidl“ | 5-s-Wartefrist in `labelOf` (Text war richtig, Abfrage zu spät) | 0 | 2 |
| `testToastStaysVisibleLongerThanTwoSeconds` | „Der Toast ist nach drei Sekunden schon weg“ | Dauertest: `sleep(3)` plus langsame Abfrage überschreitet die echte 6-s-Frist | 1 | 1 |
| **Summe** | | | **7** | **3** |

## Einordnung

- Die Ursache, die Durchgang 2 beheben sollte (Toast-Frist läuft ab, bevor der Test fertig liest), kam
  vorher 5-mal vor und nachher **0-mal**.
- AC-10 („0 Fehler bei den drei Toast-Tests“) ist **nicht erfüllt**: `testToastNamesStoreAndOffersChangeAndUndo`
  scheitert zweimal an einer anderen Ursache, der 5-s-Wartefrist von `labelOf`
  (`QuickAddAssignmentUITests.swift:64`). Das ist dasselbe Muster wie in Durchgang 1, nur in dieser Datei
  nicht umgestellt.
- Der Dauertest scheitert vorher wie nachher je einmal. Er läuft absichtlich ohne Argument; sein Aufbau
  (Wartezeit plus Abfrage gegen eine 6-s-Frist) ist auf einem langsamen Runner nicht stabil zu bekommen.
- Statistik: vorher 7/120, nachher 3/120. Zu klein, um mehr als die Richtung zu zeigen; belastbar ist die
  Aufschlüsselung nach Ursache.

## Offen für Durchgang 3

1. `labelOf` und weitere `timeout: 5` in `QuickAddAssignmentUITests` auf `UITestWait` umstellen.
2. Dauertest ohne Zeitabhängigkeit der Abfrage: Frist als testbare Konstante prüfen (Unit-Test) statt per
   UI-Wartezeit. Alternative zum bisherigen Weg.
3. Weiter offen: XCTests eigene Abfragegrenze (31 s), Wettlauf `frame` → `isHittable` → `tap()`.

## Nebenbefund (lokal, nicht aus den Messläufen)

`testAcceptAllAssignsEverythingAndRemovesCard` schlug lokal 2-mal in etwa 15 Läufen fehl („Karte ‚Ohne Laden‘
fehlt“), danach je 10 Wiederholungen mit und ohne Fix fehlerfrei
(`acceptall-*.txt`, `lauf-rot-acceptall-flake.txt`). Der Test zeigt vor der Stelle keinen Toast an.

Rohprotokolle: `messlauf-nachher-log.txt`, `messlauf-vorher-log.txt`.
