# RED-Lauf #145 Durchgang 4 (2026-10-19)

Stand: Tip-Commit `6cff9ae` plus die uncommitteten Testdateien `RestockTests/PremiumServiceTests.swift`
(U1–U12 + `testUnknownScenarioFallsBackToStoreKit` für AC-13) und `RestockUITests/PurchaseUITests.swift` (P1–P11).
Gerät: `Restock-Validate` (iOS 26.5), beide Sperren gehalten (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock` mit pid).

## Unit (`test-red-unit-output.txt`)

`xcodebuild test -only-testing:RestockTests/PremiumServiceTests` → `** TEST FAILED **`, Kompilierfehler:
`cannot find type 'PurchaseStore' / 'PurchaseOffer' / 'PurchaseOutcome' / 'EntitlementRecord' in scope`.
Die Naht existiert noch nicht. Erwartetes RED.

## UI (`test-red-ui-output.txt`)

Weil das Schema das Unit-Ziel mitbaut und das nicht kompiliert, lief die UI-Klasse in einer Wegwerf-Kopie
des Arbeitsstands, in der nur `PremiumServiceTests.swift` geleert war; der Produktcode ist der heutige.
Daher stehen in den Fehlerzeilen Pfade unter `scratchpad/wt-copy/`.

`Executed 11 tests, with 11 failures` — alle aus dem erwarteten Grund:

| Test | Fehlschlag | Grund heute |
|------|------------|-------------|
| P1 success | Rezeptplan öffnet sich nicht | Szenario-Argument unbekannt, keine Produkte, DEBUG schließt die Paywall still |
| P2 cancel | Kaufknopf nicht wieder bereit | Paywall schließt in DEBUG still statt offen zu bleiben |
| P3 pending | Hinweis „wartet auf Zustimmung“ fehlt | Hinweis gibt es noch nicht |
| P4 fail | „Kauf fehlgeschlagen: Testfehler Kauf“ fehlt | kein Ersatz-Appstore |
| P5 productMissing | Ladefehler-Text fehlt | DEBUG schließt still (Lücke) |
| P6 restoreNone | „Kein Kauf gefunden“ fehlt | Wiederherstellen ohne Fund ist still |
| P7 restoreFound | Paywall schließt nicht | kein Ersatz-Appstore |
| P8 restoreFail | Fehlertext fehlt | `try? AppStore.sync()` verschluckt |
| P9 | Kauf-Hinweis fehlt | Hinweis gibt es noch nicht |
| P10 | Hinweis erscheint nicht | Hinweis gibt es noch nicht |
| P11 Chip | Breite 40 pt < 80 pt (hell) | Chip zeigt „…“, Screenshot `red-chip-hell-40pt.png` |

P11 bricht nach „hell“ ab (`continueAfterFailure = false`), „dunkel“ wurde nicht gemessen. Die Ursache des
Chips wird in Phase 6 vor dem Fix nachgestellt (AC-14).
