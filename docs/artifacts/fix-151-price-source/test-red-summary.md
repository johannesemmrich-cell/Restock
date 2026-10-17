# RED-Nachweis #151 (2026-10-17, Simulator Restock-Validate 8F696920-…, ohne Produktänderung)

## Unit (`test-red-unit-output.txt`)
`xcodebuild test -only-testing:RestockTests/PriceSourceTests` → `** TEST FAILED **`, Build des Testziels
scheitert: `cannot find type 'LearnedPriceResolution' in scope` (PriceSourceTests.swift:126, :146).
16 Tests (AC-1 bis AC-16) erwartungsgemäß rot, weil Resolver, Felder und Nähte fehlen.

## UI (`test-red-ui-output.txt`)
`-only-testing:RestockUITests/LegacyLearnedPriceResetUITests`, Executed 3 tests, 3 failures.
Für diesen Lauf wurde `PriceSourceTests.swift` kurz durch `import XCTest` ersetzt (das Schema baut alle
Testziele), danach bitgleich wiederhergestellt (SHA-1 731c642a…).

- `testPriceSourceDistinguishesEstimateManualAndLearned` (AC-17): „Schätzung“ fehlt in der Zeile
  „Laugenbrötchen groß“, zuletzt `["Laugenbrötchen groß", "·", "Backwaren", "2,50 €"]` — heutiger Stand,
  Schätzung ohne Quelle.
- `testPriceDiagnosisOnlyInDeveloperMode` (AC-18): Abschnitt „Preisdiagnose“ fehlt im Entwicklermodus.
- Bestandstest `testLegacyPricesAreResetAfterLaunchButManualPriceStays` (unverändert): „Altbon-Kachel
  nicht auf dem Home-Screen gefunden“ nach 15 s beim ersten Kaltstart nach Neuinstallation. Nicht durch
  #151 verursacht (kein Produktcode geändert), Muster #105/kalter Start; die beiden neuen Tests (Start
  über `UITestLaunch`) fanden die Kachel im ersten Start (0 Messzeilen „zweiter Start“).
  **Für GREEN/AC-19:** Bestandstest muss im gemeinsamen Lauf grün sein; schlägt der Kaltstart erneut
  zu, Ursache belegen statt wiederholen.
