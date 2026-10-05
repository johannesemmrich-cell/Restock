# Nachschärfen 3: Fremddatei-Schutz in `deleteStoreFiles()` (T20, AC-16)

Stand: Commit `4f01814` plus uncommittete Änderungen dieses Durchgangs, 2026-10-05.
Gerät: Simulator „Restock-Validate“ (UDID 8F696920-4B9A-40A7-96F0-7697BE887CC7, iOS 26.5).

## 1. Vorübergehende Änderung

`SmartCart/SmartCartApp.swift`, `deleteStoreFiles()`, erster Löschfilter (App-Group-Container),
in dem `placeForeignMarkerForUITestsIfNeeded()` die Datei `uitest-foreign-marker.txt` ablegt:

```diff
                 for url in contents where url.pathExtension == "store"
                     || url.lastPathComponent.hasSuffix(".store-shm")
-                    || url.lastPathComponent.hasSuffix(".store-wal") {
+                    || url.lastPathComponent.hasSuffix(".store-wal") || url.pathExtension == "txt" {
```

## 2. Roter Lauf

`-only-testing:RestockUITests/DataResetUITests`, 16:42:53–16:44:31, Exit 65:

```
error: -[RestockUITests.DataResetUITests testAppUsableAfterEmergencyReset] : com.johannesemmrich.Restock crashed
Test Case '-[RestockUITests.DataResetUITests testAppUsableAfterEmergencyReset]' failed (51.320 seconds).
error: -[RestockUITests.DataResetUITests testEmergencyPathDeletesStoresAndShowsNoticeOnce] : com.johannesemmrich.Restock crashed
Test Case '-[RestockUITests.DataResetUITests testEmergencyPathDeletesStoresAndShowsNoticeOnce]' failed (14.233 seconds).
Executed 2 tests, with 2 failures (0 unexpected)
** TEST FAILED **
```

## 3. Beleg, dass die `precondition` ausgelöst hat

Simulator-Protokoll (`simctl spawn … log show --predicate 'eventMessage CONTAINS "Fremddatei"'`):

```
2026-10-05 16:43:24.733 Restock[11740] (libswiftCore.dylib) Restock/SmartCartApp.swift:182: Precondition failed: deleteStoreFiles() hat eine Fremddatei gelöscht: uitest-foreign-marker.txt
2026-10-05 16:44:04.600 Restock[11995] (libswiftCore.dylib) Restock/SmartCartApp.swift:182: Precondition failed: deleteStoreFiles() hat eine Fremddatei gelöscht: uitest-foreign-marker.txt
```

Absturzberichte `~/Library/Logs/DiagnosticReports/Restock-2026-10-05-164347.ips` und
`Restock-2026-10-05-164406.ips` (je ein Bericht pro Test), auslösender Thread:

```
EXC_BREAKPOINT (SIGTRAP), Trace/BPT trap: 5
libswiftCore.dylib  _assertionFailure(_:_:file:line:flags:)
Restock.debug.dylib static SmartCartApp.verifyForeignMarkerForUITests(_:)  SmartCartApp.swift:182
Restock.debug.dylib SmartCartApp.init()                                   SmartCartApp.swift:89
SwiftUI             static App.main()
```

Zeile 182 ist die `precondition(FileManager.default.fileExists(atPath: marker.path), "deleteStoreFiles() hat eine Fremddatei gelöscht: …")`,
Zeile 89 der Aufruf `Self.verifyForeignMarkerForUITests(foreignMarker)` direkt nach `deleteStoreFiles()`.

## 4. Rücknahme

Änderung aus Abschnitt 1 vollständig zurückgedreht. Nachweis:

```
$ git diff --stat SmartCart/SmartCartApp.swift
(leer)
$ git diff --stat origin/main -- SmartCart/SmartCartApp.swift
(leer)
```

## 5. Grüner Lauf nach Rücknahme

`-only-testing:RestockUITests/DataResetUITests`, 16:45:04–16:46:19, Exit 0:

```
Test Case '-[RestockUITests.DataResetUITests testAppUsableAfterEmergencyReset]' passed (20.972 seconds).
Test Case '-[RestockUITests.DataResetUITests testEmergencyPathDeletesStoresAndShowsNoticeOnce]' passed (24.451 seconds).
Executed 2 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

Kein neuer `Restock-*.ips` im grünen Lauf (jüngster Bericht bleibt `Restock-2026-10-05-164406.ips`).

Ergebnis: Die Fremddatei-Prüfung ist wirksam. Ein zu breiter Löschfilter beendet die App im
Notfallpfad mit benannter Meldung, und `DataResetUITests` wird rot.
