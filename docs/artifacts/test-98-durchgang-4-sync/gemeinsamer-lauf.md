# Gemeinsamer Lauf der Bestandssuiten (T22, #98 Durchgang 4)

Simulator: Restock-Validate, nacheinander, nie parallel. Stand: Merge-Tests, Nachschärfen 1/2, Produktcode nur 2x `private` entfernt.

| Suite | Ergebnis |
|---|---|
| Unit `-only-testing:RestockTests` | Executed 449 tests, 0 failures, TEST SUCCEEDED (darin 15 SharedStoreMergeTests, Start-Hänger trat nicht auf) |
| UI `QuickAddAssignmentUITests` | 12 Tests, 0 Fehler |
| UI `DataResetUITests` | 2 Tests, 0 Fehler |
| UI `ReplenishmentUITests` | 10 Tests, 0 Fehler |

Offene Grenze: Je Klasse ein Lauf. Der Seed-Flake beim ersten App-Start eines xcodebuild-Laufs
(siehe `nachschaerfen-1-2.md`) tritt unabhängig von dieser Änderung auf, auch beim unveränderten Bestandstest.
