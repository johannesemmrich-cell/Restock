# RED-Hinweise für /50-implement (#234, Durchgang 3)

Stand 2026-11-02, Phase 5. Spec: `docs/specs/services/shared-store-stations-sync.md`.

## Signaturen, die die Tests erwarten

- `StoreCategories.mergeStationConfig(local: StationConfig?, remote: StationConfig?) -> StationConfig?`
- `StoreCategories.encodeStationConfig(_ config: StationConfig) -> String`
- `StoreCategories.decodeStationConfig(_ json: String?) -> StationConfig?`
- `Store.adoptRemoteStationConfig(_ config: StationConfig)`
- `SharedStoreService.MergedState` mit neuem letzten Element `stations: StationConfig?` (Tests lesen `result.stations`)
- `SyncCoordinator.apply(items:members:…assignments:stations:modifiedAt:to:)`, `stations: StationConfig? = nil`
- Record-Feld `stationsJSON` (gleiche Kodierung wie `Store.stationConfigJSON`)

## Abweichungen von der Spec-Testliste (technisch nötig, Tech Lead)

1. **T12 (`testApplyAndRemoveStations`, Bestand) geändert:** prüfte `stationConfigJSON == ""` nach
   `removeStations()`. Mit dem Löschvermerk (Spec e) wäre das falsch; jetzt `stationConfig?.stations == []`.
   Die Spec nennt nur vier geänderte Bestandsstellen, diese fünfte fehlte dort.
2. **T5 und T8 bekommen lokale Gänge** (`applyStationConfig(lidlTemplate)`): `stationsJSON` wird laut Spec (c) nur
   geschrieben, wenn das Merge-Ergebnis nicht `nil` ist. Ohne Gänge fehlte das Feld, und T5/T8 könnten nie grün werden.
3. **T8 liest jetzt die `.ckdb`:** Die Spec sagt, T8 vergleiche Code und Schemadatei; tatsächlich verglich T8 nur mit
   der Liste im Test. Ergänzt um `publishedSharedStoreFields()` (Typ `SharedStore`, ohne `___`-Systemfelder und
   `GRANT`). Grün erst mit der Zeile `stationsJSON STRING QUERYABLE SEARCHABLE SORTABLE,` in
   `docs/cloudkit/private-schema-aktuell.ckdb` (alphabetisch nach `pricesJSON`, vor `storeColorHex`).
4. **G9 prüft zusätzlich den englischen Text** (Spec verlangt de und en, die Bestandsprüfung hatte nur de).
5. `extensionFields` in `SharedStoreSchemaTests` enthält jetzt `stationsJSON`; damit prüfen T1, T2, T16 und T17 über
   `assertNoExtensionFields` automatisch auch, dass der Fallback `stationsJSON` weglässt.

## Schutztests (mit Platzhaltern schon grün, bewusst)

G2 (`testMergeStationConfigTieKeepsLocal`), M3 (`testPushMergeStationsAbsentOrWithoutExtensionFields`),
M5 (`testApplyStationsOlderOrMissingKeepsLocal`) prüfen „nichts tun“-Fälle; ein Platzhalter, der nichts tut, erfüllt sie.
Sie fangen eine falsche Umsetzung (Gleichstand → remote, leeres Feld geschrieben, Fallback schreibt Feld, älterer
Stand überschreibt).

## RED-Läufe (Simulator `Restock-Validate-272`, iOS 27.2)

- `test-red-output.txt`: echter Arbeitsstand, `TEST FAILED` beim Übersetzen (fehlende API, `MergedState.stations`,
  `apply(stations:)`). Der Übersetzer bricht nach der ersten Datei ab.
- `test-red-stubs-output.txt`: Wegwerf-Kopie mit leeren Platzhaltern (Signaturen oben, ohne Wirkung), damit jede
  Testdatei übersetzt: 105 Tests, 18 Testfälle rot aus dem erwarteten Grund (G1, G3–G8, M1, M2, M4, M6, M7, T5, T6,
  T8, T17, T12, Hinweistext), alle anderen Bestandstests der drei Klassen grün. Platzhalter liegen nicht im Repo.
- `test-red-ui-y7.txt`: Y7 in derselben Kopie, rot mit altem Hinweistext („Gänge bleiben bis zum Abgleich auf diesem Gerät.“).
