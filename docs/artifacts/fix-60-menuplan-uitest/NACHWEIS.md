# Nachweis zu Issue #60 — `testAddingMenuPlanRecipeDoesNotCrash`

Gerät: `Restock-Validate`, `8F696920-4B9A-40A7-96F0-7697BE887CC7`. Immer nur ein `xcodebuild test`
gleichzeitig, keine zusätzlichen Build-Settings (kein `CODE_SIGNING_ALLOWED=NO`).

Befehl je Lauf:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Restock -project Restock.xcodeproj \
  -destination 'platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7' \
  -only-testing:RestockUITests/RestockUITests/testAddingMenuPlanRecipeDoesNotCrash
```

## 1. Reproduktion der Ursache aus #60

`repro-menuplanjson-vor-fix.txt` — der Menüplan des Testgeräts vor der Reparatur, direkt aus den
App-Einstellungen gelesen:

```
["Chili Con Carne","Chili Con Carne","Chili Con Carne","Chili Con Carne","Chili Con Carne","Chili Con Carne","Chili Con Carne"]
```

Sieben von sieben Tagen verplant → `plannedIndices.count == 7` → `MenuPlanView.swift:336` rendert
„Tag hinzufügen" nicht. Genau der Fehlschlag aus #60, verursacht von früheren Testläufen.

## 2. Läufe

| Lauf | Datei | Stand | Ergebnis |
|------|-------|-------|----------|
| 1 | `run1.txt` | vor dem Aufsetzen auf `origin/main` | 1 Test, 0 Fehler, 28,6 s, `** TEST SUCCEEDED **` |
| 2 | `run2.txt` | auf `origin/main` (`cb239f9`) aufgesetzt | 1 Test, 0 Fehler, 29,3 s, `** TEST SUCCEEDED **` |
| 3 | `run3.txt` | dito | 1 Test, 0 Fehler, 30,0 s, `** TEST SUCCEEDED **` |
| 4 | `run4.txt` | dito | **1 Test, 1 Fehler**, 28,7 s — anderer Schritt, siehe unten |
| 5 | `run5.txt` | mit Menü-Härtung | 1 Test, 0 Fehler, 29,7 s, `** TEST SUCCEEDED **` |
| 6 | `run6.txt` | dito | 1 Test, 0 Fehler, 31,1 s, `** TEST SUCCEEDED **` |
| 7 | `run7.txt` | dito | 1 Test, 0 Fehler, 27,5 s, `** TEST SUCCEEDED **` |

Kein Lauf enthält `Retrying`, `Restarting after unexpected exit` oder einen Null-Test-Lauf; jeder
zeigt genau einen ausgeführten Test.

## 3. Der Fehlschlag in Lauf 4 hat eine andere Ursache

`run4.txt:127` — `RestockUITests.swift:290: XCTAssertTrue failed - "Automatisch zuordnen"-Menüeintrag
nicht gefunden`. Also nicht mehr „Tag hinzufügen", sondern ein späterer Schritt.

Vergleich der Protokolle beim Tap auf „+ Liste":

| | Lauf 3 (grün) | Lauf 4 (rot) |
|---|---|---|
| `Synthesize event` | t = 16,89 s | t = 17,50 s |
| danach „App idle" | t = 18,43 s (**1,24 s**) | t = 17,80 s (**0,47 s**) |

Im grünen Lauf kostet die Menü-Präsentation gut eine Sekunde; im roten war die App nach einer
halben Sekunde wieder untätig — das SwiftUI-`Menu` hat den Öffnen-Tap verschluckt, während
`fetchIngredients()` die Zeile neu zeichnete. Der Menüeintrag selbst ist unbedingt vorhanden
(`MenuPlanView.storeTargetMenu`), es gab also kein Menü zum Hineinschauen. Deshalb öffnet der Test
das Menü jetzt bis zu dreimal; die Prüfung selbst bleibt scharf. In den Läufen 5–7 genügte jeweils
der erste Tap.

## 4. Der Test räumt auf

`menuplan-keys-nach-lauf1.txt`. Auch nach Lauf 7 enthalten die App-Einstellungen keinen der vier
Schlüssel `menuPlanJSON`, `menuIngredientsJSON`, `menuPortionsJSON`, `menuAddedDaysJSON` mehr — der
Test hinterlässt keinen Menüplan-Zustand für nachfolgende Tests im selben `xcodebuild test`-Lauf.

## 5. Produktverhalten unverändert

`MenuPlanView.swift` wurde nicht angefasst. Die Bedingung `plannedIndices.count < 7` bleibt: bei
voller Woche verschwindet „Tag hinzufügen" weiterhin.
