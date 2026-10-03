# Mutationsbelege ReplenishmentUITests (Issue #98, Durchgang 2, Adversary Runde 1)

Datum: 2026-10-03, Gerät Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7), Simulator nicht parallel.

Verfahren: Vor allen Mutationen Kopien von `SmartCart/Views/Home/HomeView.swift` und
`SmartCart/Services/HabitService.swift` im Scratchpad abgelegt (SHA-1 `6e46cf35…` bzw. `e19ed152…`).
Ein Skript ersetzt je Mutation genau eine (eindeutige) Textstelle, fährt nur die betroffenen
Einzeltests (`-only-testing:`) und kopiert die Datei danach in einem `finally` zurück; nach jedem
Lauf wurde die SHA-1 gegen die Kopie geprüft (`restored True`). Kein git checkout/stash.
Nach dem letzten Lauf: beide Dateien SHA-identisch mit den Kopien, `HabitService.swift` ohne Diff.

| # | Stelle | Mutation | Test | Ergebnis |
|---|--------|----------|------|----------|
| a | `HomeView.addDueSoonToList()` | `for pattern in dueSoonItems` → `dueSoonItems.prefix(1)` (nur erster Artikel wird angelegt) | `testBannerAddAllAddsEverything` | **ROT** — `ReplenishmentUITests.swift:102`: „Expect predicate `exists == 0` for object "Zeit zum Nachkaufen" StaticText“ (der nicht angelegte Bannerquark bleibt fällig, der Banner verschwindet nicht) |
| b0 | `HomeView.addSingleDueItem()` | nur `context.insert(item)` + `trackAcceptedReplenishment` entfernt | `testBannerPlusAddsItemToStoreList` | grün — **Mutation unwirksam, kein Testmangel**: `makeReplenishmentItem(store:)` setzt `item.store` auf einen verwalteten `Store` (ShoppingItem.swift:119), SwiftData fügt das Objekt dadurch implizit in den Kontext ein; der Artikel wurde also tatsächlich angelegt |
| b | `HomeView.addSingleDueItem()` | Erzeugen und Einfügen des Artikels ganz entfernt (`let item = …`, `context.insert`, `trackAccepted…`), nur der Banner-Eintrag wird entfernt | `testBannerPlusAddsItemToStoreList` | **ROT** — `:102`: „Expect predicate `exists == 0` for object "replenish.also.add.Bannerbutter" Button“ (in Bannerladen steht nur die Vorschlagszeile; genau die F001-Prüfung greift, `listRow` allein hätte die Vorschlags-Cell getroffen) |
| c | `ReplenishmentBlocklist.persist(_:)` (HabitService.swift) | `defaults.set(…)` → `_ = names` (Sperre wird nicht gespeichert) | `testBannerBlockSurvivesRestart`, `testAlsoDueBlockSurvivesRestart` | **beide ROT** — `:162` „„Bannerbutter“ kehrt nach dem Neustart zurück“; `:248` „„Listenreis“ kehrt nach dem Neustart zurück“ |
| d | `ReplenishmentSnoozes.persist(_:)` (HabitService.swift) | `defaults.set(…)` → `_ = map` (Snooze wird nicht gespeichert) | `testBannerStillHaveItHidesSuggestion`, `testAlsoDueStillHaveItHidesSuggestion` | **beide ROT** — `:149` „„Bannerquark“ kehrt nach dem Neustart zurück“; `:233` „„Listennudeln“ kehrt nach erneutem Öffnen zurück“ |

Endlauf auf unverändertem Produktcode (ganze Klasse): 10 Tests, 0 Fehler, `** TEST SUCCEEDED **`
(`test-green-output.txt`).

Hinweis: Nach jedem roten Lauf hängt `xcodebuild` ca. 10 Minuten (Diagnose-Sammlung, bekannt aus
Issue #21), bevor es beendet; die Testergebnisse selbst liegen nach ~25 s vor.
