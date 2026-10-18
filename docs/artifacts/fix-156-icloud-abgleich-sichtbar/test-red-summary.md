# RED-Nachweis #156 (2026-10-18, Simulator Restock-Validate 8F696920-…, ohne Produktänderung)

Lauf mit beiden Sperren (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock` inkl. pid-Datei), 19:29–19:35.

## Unit (`test-red-unit-output.txt`)
`-only-testing` CloudMirrorMonitorTests, StoreDuplicateFinderTests, MirroredSchemaSnapshotTests →
`** TEST FAILED **`, Build des Testziels scheitert: `cannot find type 'OnboardingCloudGate' in scope`
(CloudMirrorMonitorTests.swift:184), `cannot find type 'StoreSnapshot' in scope`
(StoreDuplicateFinderTests.swift:37). T1–T18 erwartungsgemäß rot, weil Monitor, Gate, Finder fehlen.

## UI + Schema (`test-red-ui-output.txt`)
Für diesen Lauf wurden die beiden neuen Unit-Dateien kurz durch `import XCTest` ersetzt (das Scheme baut alle
Testziele), danach bitgleich wiederhergestellt (`red-neutralisiert-sha.txt`, `shasum -c` OK).

- MirroredSchemaSnapshotTests: Executed 4 tests, 1 failure — T19 `testPhotoDataAssetFieldIsListed`:
  „CD_ShoppingItem.CD_photoData_ckAsset (ASSET) fehlt“. T1–T3 bleiben grün.
- ICloudDiagnosticsUITests: Executed 3 tests, 3 failures (T20–T22) — Seed `-seedDuplicateStoresForUITests`
  existiert nicht, Kachel „Lidl“ fehlt nach 2 Starts.
- OnboardingCloudWaitUITests: Executed 2 tests, 2 failures — T23: Hinweis „Deine Läden werden aus iCloud
  geladen …“ fehlt; T24: Kachel „Lidl“ (angekommen) fehlt.
- `Restarting after unexpected exit`: 0. Kein `-retry-tests-on-failure`, keine Iterationen.
