# Mutationsproben (AC-12), Issue #98 Durchgang 4

Datum: 2026-10-05. Gerät: Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7).
Kommando je Probe: `xcodebuild test -scheme Restock -project Restock.xcodeproj -destination 'platform=iOS Simulator,id=8F696920-…' -only-testing:RestockTests/SharedStoreMergeTests`.
Jeder Lauf: 15 Tests ausgeführt (kein Null-Test-Lauf).

| Probe | Geänderte Zeile | Ergebnis | Rote Tests | Zurückgedreht |
|---|---|---|---|---|
| (a) LWW in `apply` kippen | `SyncCoordinator.swift:260` `guard remote.lastModified >= local.lastModified` → `<=` | 15 Tests, 12 Fehler (alle in einem Test) | `testApplyLastWriteWinsPerItem` (Zeilen 111–129: älterer Remote überschreibt „Alt“ mit „Älter“; neuerer Remote wird verworfen) | ja |
| (b) Tombstone-Löschung entfernen | `SyncCoordinator.swift:253–255` Schleife `for item in … where deletedIDs.contains(item.id) { context.delete(item) }` auskommentiert | 15 Tests, 1 Fehler | `testApplyDeletesOnlyTombstonedItems` (Zeile 100: `["Weg", "Bleibt, fehlt nur remote"]` ≠ `["Bleibt, fehlt nur remote"]`) | ja |
| (c1) `markSynced` direkt hinter `guard let context` verschoben (gleiche Bedingung), Aufruf hinter `save` entfernt — mit der ursprünglichen Testfassung | `SyncCoordinator.swift:230ff.` / `307–309` | **15 Tests, 0 Fehler — Probe NICHT gefangen** | keine | ja |
| (c2) dieselbe Mutation wie (c1), nach Nachschärfen des Tests | wie (c1) | 15 Tests, 1 Fehler | `testApplyAdvancesWatermarkOnlyAfterSaveAndWithModifiedAt` (Zeile 179: Wasserstand bei `ModelContext.willSave` war `t3` statt `t2` — „beim Speichern stand noch der alte Wasserstand“) | ja |
| (d, optional) LWW im Push-Merge kippen | `SharedStoreService.swift:140` `existing.lastModified > item.lastModified` → `<` | 15 Tests, 2 Fehler | `testPushMergeLastWriteWinsBothDirections` (Zeile 226: „Server älter“ statt „Lokal neuer“; Zeile 231: „Lokal neuer“ statt „Server neuer“) | ja |

## Nachschärfen zu (c)

Warum (c1) grün blieb: Der Waisen-Fall im Test (Laden ohne Kontext) bricht am `guard` ab, also
vor dem verschobenen `markSynced`. Ein fehlschlagendes `context.save()` lässt sich im In-Memory-
Kontext ohne Produkteingriff nicht erzeugen (keine `.unique`-Attribute im Schema). Damit war das
Verschieben hinter den `guard` unentdeckbar.

Nachschärfung (nur Testdatei): Im Test `testApplyAdvancesWatermarkOnlyAfterSaveAndWithModifiedAt`
beobachtet ein `NotificationCenter`-Beobachter auf `ModelContext.willSave` (Objekt: Testkontext) den
Wasserstand in dem Moment, in dem gespeichert wird. Ein zweites `apply` mit einem Remote-Artikel
(erzwingt Änderungen, damit wirklich gespeichert wird) und `modifiedAt: t3` muss beim Speichern noch
`t2` sehen (`probe.seen == [t2]`, zugleich Beleg, dass der Beobachter genau einmal feuerte) und
danach `t3`. Mit der Mutation sah der Beobachter `t3`. Der Waisen-Fall bleibt zusätzlich bestehen
(fängt ein Verschieben vor den `guard`).

Grenze: Der Test belegt die Reihenfolge „Wasserstand erst nach Beginn des Speicherns“. Dass ein
**fehlschlagendes** Save den Wasserstand stehen lässt, folgt daraus (der Aufruf steht im selben
`do`-Block hinter `try context.save()`), wird aber nicht mit einem echten Save-Fehler ausgelöst.

## Endstand

Nach allen Proben enthält der Produktcode-Diff nur das Entfernen von `private` bei `mergeIntoRecord`
und `merge(local:remote:tombstones:)` in `SharedStoreService.swift` (2 Zeilen). `SyncCoordinator.swift`
ist unverändert (`git diff --stat` zeigt die Datei nicht). Finaler grüner Lauf:
`test-green-output.txt`.
