# TDD RED, Issue #234 Durchgang 2b-1 (2026-11-01)

Spec: `docs/specs/views/station-templates-keywords.md`. Gerät: Simulator `Restock-Validate-272` (iOS 27.2,
6728F5AB-712F-46E0-A1D1-2047A9771C8E). Beide Laufsperren gehalten.

## Unit (`RestockTests/StoreStationsTests`) — `test-red-unit.txt`

`xcodebuild test -only-testing:RestockTests/StoreStationsTests` → `** TEST FAILED **`, Übersetzungsfehler. Alle
Fehler gehen auf fehlende neue Schnittstellen zurück (keine Tippfehler in Bestands-Namen):

- `StoreCategories.normalizedKeyword`, `addingKeyword`, `checkKeyword`, `removingKeyword` fehlen
- `StoreCategories.discounterTemplate`, `fullRangeTemplate`, `drugstoreTemplate`, `hardwareTemplate`, `allTemplates` fehlen
- `StationSetupRow` nicht sichtbar (heute `private`, `summaryText(categories:keywords:)` fehlt)
- Folgefehler: `KeywordCheck` (`.accepted/.duplicate/.invalid`) unbekannt, Schlüsselpfade auf den fehlenden Vorlagen

Neu bzw. geändert: K1–K7, K9–K11, K8 (`testAllTemplatesSatisfyInvariants` ersetzt T8 `testTemplateIsConsistent`),
S13 (Schlüsselliste ohne `row.summary`, `detail.keywords` mit 1 Platzhalter, 19 neue Schlüssel, Wortlaute).

## UI (`RestockUITests/StationSetupExtrasUITests`) — `test-red-ui.txt`

Lauf in einer Wegwerf-Kopie mit `StoreStationsTests.swift` auf dem Stand von `HEAD`, weil das Unit-Ziel sonst
mitgebaut wird und nicht übersetzt. `Executed 3 tests, with 3 failures`:

| Test | Vorbedingung grün | scheitert an |
|------|-------------------|--------------|
| X1 `testChooseDiscounterTemplateReplacesStations` | Salami unter „Kühltheke Fertiges“, Lidl-Zeile ohne Kennzeichen | „Vorlage Discounter fehlt im Blatt“ (Zeile 290) |
| X2 `testAddKeywordMovesItemIntoStation` | Batterien unter „Sonstiges“, Gang „Drogerie“ geöffnet | Feld „Stichwort hinzufügen“ fehlt (Zeile 136) |
| X3 `testDeleteKeywordMovesItemOut` | Gouda unter „Käse“, Gang „Käse“ geöffnet | Stichwort-Zeile „käse“ fehlt (Zeile 399) |

Die neue Datei ist im UI-Test-Ziel der `project.pbxproj` eingetragen (PBXBuildFile, PBXFileReference, Gruppe,
Sources). CI-Teil D (`ci.yml`) folgt in der Umsetzung.
