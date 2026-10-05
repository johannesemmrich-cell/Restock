# Nachschärfen 1 und 2 — RED-/GREEN-Belege (#98, Durchgang 4)

Simulator: Restock-Validate. Rohlogs und .xcresult lagen im Scratchpad der Sitzung.

## Nachschärfen 2 (AC-15): Mengenzeile nur in der Zeile „Hackfleisch“

- RED: Suche kurz auf `app.navigationBars.firstMatch.staticTexts["500 gramm"]` gelenkt →
  `QuickAddAssignmentUITests.swift:344: XCTAssertTrue failed - Die Mengenzeile „500 gramm“ fehlt in der Zeile von „Hackfleisch“`.
  Die Zeile „Hackfleisch“ wurde vorher gefunden: der rote Befund kommt von der Eingrenzung.
- Zurückgestellt: `row.staticTexts["500 gramm"]`.
- GREEN: `testQuantityAndUnitShownInList` in 3 von 3 Läufen grün (22 s).

## Nachschärfen 1 (AC-14): „Lidl“ nicht im Dialog, Probe und Gegenprobe gegen dieselbe Sammlung

- RED: Negativprobe kurz auf `dialogChoice("dm")` gestellt →
  `QuickAddAssignmentUITests.swift:298: XCTAssertFalse failed - Der Dialog bietet den Laden an, in dem der Artikel schon liegt`
  (gültiger Lauf `red-n1-retry2`). Zwei frühere Läufe waren ungültig (Seed-Flake, siehe unten).
- Zurückgestellt: `dialogChoice("Lidl")`.
- GREEN: `testChangeStoreMovesItemAndRemembersCorrection` im Klassenlauf grün, im Einzellauf 1 von 3.

## Stabilität: Befund und Gegenprobe

`testChangeStoreMovesItemAndRemembersCorrection` war als **erster** Test eines xcodebuild-Laufs in 2 von 3 Läufen rot
(Zeile 297: Seed-Läden fehlen, Dialog hat nur „OK“). Videos aus dem .xcresult zeigen „Noch keine Läden“. Die Startargumente
kommen an (Simulator-Protokoll `-seedQuickAddAssignmentForUITests`), es ist also nicht #105.

Gegenprobe mit dem **unveränderten** Bestandstest `testAddedItemAppearsInStoreList`, 3 Einzelläufe
(`gegenprobe-bestandstest-1..3.txt`): Lauf 1 rot (`Kachel „Lidl“ nicht gefunden`), Lauf 2 und 3 grün.
→ Das Problem „Seed fehlt beim ersten App-Start nach der Installation“ besteht unabhängig von Nachschärfen 1/2.
Ursache ungeklärt; Folgearbeit gehört zu den Flakes (#111).

## Wiederholung nach Adversary Runde 1

Präzisierung der früheren Zeile „im Einzellauf 1 von 3“: gemeint war 1 grüner von 3 Einzelläufen
(2 rot am Seed-Flake). Neue Zählung, Simulator Restock-Validate, Einzelläufe nacheinander
(`-only-testing:RestockUITests/QuickAddAssignmentUITests/<Test>`), am 2026-10-05 ab 17:16.
Vorher wurde der Simulator neu gestartet (Aufräumen nach einer Mutationsprobe der Unit-Tests).
Logs: `wiederholung-r1-<Test>-<Lauf>.txt`.

| Test | Lauf 1 | Lauf 2 | Lauf 3 | grün |
|------|--------|--------|--------|------|
| `testChangeStoreMovesItemAndRemembersCorrection` | rot | grün | grün | 2 von 3 |
| `testQuantityAndUnitShownInList` | grün | rot | grün | 2 von 3 |

Rote Läufe:
- Change-Store Lauf 1 (erster UI-Start nach Simulator-Neustart und Neuinstallation):
  `QuickAddAssignmentUITests.swift:51: Asynchronous wait failed: Exceeded timeout of 10 seconds … hasKeyboardFocus == 1
  … "Schnell hinzufügen…" TextField`. Fehlerort ist der unveränderte Helfer `typeIntoQuickAdd`, nicht der
  geänderte Testteil (Diff-Bereiche ab Zeile 283). Anderes Muster als der Seed-Flake: das Feld war da, bekam
  nach dem Tippen aber 10 s lang keinen Fokus.
- Quantity Lauf 2 (kein Erststart, der Lauf davor war grün):
  `QuickAddAssignmentUITests.swift:335: XCTAssertTrue failed - Ziel-Karte nennt Lidl nicht`. Die
  Debug-Beschreibung im .xcresult zeigt `quickAdd.target` mit Label „Noch kein Laden, Landet unter „Ohne Laden““,
  die Seed-Läden fehlten also: dasselbe Muster wie oben (Seed fehlt), Zeile 335 liegt vor dem geänderten
  Bereich. Der Flake tritt damit **nicht nur** beim ersten Start nach Installation auf.

Die geänderten Assertions (Change-Store: Zeilen 283–300, Quantity: Zeilen 341–346) sind in keinem Lauf rot
geworden; beide roten Läufe scheitern vorher. Einordnung: Flakes, gehören zu #111.

Nebenbefund: In Change-Store Lauf 2 und Quantity Lauf 2 und 3 hing `xcodebuild` nach dem fertigen Test
rund 10 Minuten (bekannter Diagnose-Hänger, Issue #21). Change-Store Lauf 2 wurde dabei vom Zeitlimit
meines Aufrufs abgebrochen (`** BUILD INTERRUPTED **`), der Test selbst lief vorher durch:
`Test Case … passed (46.636 seconds)`, `Executed 1 test, with 0 failures`.
