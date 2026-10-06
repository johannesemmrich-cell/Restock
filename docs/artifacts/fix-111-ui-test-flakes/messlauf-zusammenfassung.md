# Messläufe #111 Durchgang 1 — Zusammenfassung

Verfahren: Wegwerf-Stände `tmp-111-messlauf-vorher` (Stand `main`) und `tmp-111-messlauf-nachher`,
`ci.yml` nur dort geändert (`ci-messlauf.yml`): Job `ui-test` allein, fünf Tests aus AC-6,
`-test-iterations 30`, **kein** `-retry-tests-on-failure`, xcresult immer hochgeladen.
Auswertung: `slow_queries.py` (Anzahl Abfragen > 4 s), `slow_context.py` (Fundstelle je Abfrage).
`ci.yml` auf `main` unverändert.

| Lauf | GitHub-Lauf | Code-Stand | Ausführungen | Fehlschläge | Abfragen > 4 s | längste |
|---|---|---|---|---|---|---|
| Vorher 1 | 37424247389 / Versuch 1 | `main` | 150 | 3 | 19 | 31,05 s |
| Vorher 2 | 37424247389 / Versuch 2 | `main` | 150 | 2 | nicht ausgewertet (Log: `messlauf-vorher2-log-auszug.txt`) | – |
| Nachher 1 | 37424250091 / Versuch 1 | erste Fassung | 150 | 0 | 6 | 7,63 s |
| Nachher 2 | 37424250091 / Versuch 2 | erste Fassung | 150 | 0 | 11 | 21,13 s |
| Nachher 3 | 37461146437 | mit AC-13 (`cf89d2b`) | 150 | 0 | 21 | 27,62 s |

## Fehlschläge vorher (Stand `main`)

- Vorher 1, 2× `testCreatingCustomCategoryFromItemDialog`: „Exceeded timeout of 5 seconds … isHittable == 1“
  (Kachel in `openedStore`, heute `waitUntilHittable`).
- Vorher 1, 1× `testCreatingCustomCategoryFromItemDialog`: „Failed to get matching snapshots: Timed out
  while evaluating UI query“ (`ShoppingRouteUITests.swift:128`, Einzelabfrage 31 s, XCTest-eigene
  Abfragegrenze; durch Fristen nicht behebbar → offene Grenze AC-11).
- Vorher 2, 2× `testSwitchingSortModesReordersList`: „Exceeded timeout of 5 seconds … exists == 0“
  (`ShoppingRouteUITests.swift:101`, Anlass für AC-13).

## Gleiche Runner-Lage (AC-9)

- Nachher 1 und 2: langsame Abfragen kamen vor, lagen aber **nicht** in umgestellten Wartestellen
  (Fundstellen: `messlauf-nachher-fundstellen.txt`, `messlauf-nachher2-fundstellen.txt`).
- Nachher 3: 12 der 21 langsamen Abfragen lagen in den neuen 20-s-Wartestellen („Waiting 20.0s for …“),
  acht davon über 5 s: 19,23 / 15,89 / 10,18 / 8,29 / 7,47 / 6,78 / 6,52 / 6,32 s. Mit der alten
  5-s-Frist hätte jede dieser Stellen den Test scheitern lassen; alle 150 Ausführungen grün
  (`messlauf-nachher3-fundstellen.txt`).

## Statistische Einordnung

Vorher 5/300, nachher 0/450. Ein Beweis, dass nie wieder ein Test zufällig scheitert, ist das nicht;
der stärkere Beleg ist die Fundstellen-Auswertung von Nachher 3 (langsame Abfragen genau an den
umgestellten Stellen, ohne Fehlschlag).
