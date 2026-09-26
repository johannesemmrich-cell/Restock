---
entity_id: learned-price-unit-and-quantity-source
type: bugfix
created: 2026-09-26
updated: 2026-09-26
status: draft
workflow: fix-10-preis-einheit
tags: [bugfix, price-learning, swiftdata, units]
---

# Bezugsgröße am gelernten Preis und Herkunft der Mengenangabe

## Approval

- [x] Approved — PO, 2026-09-26, auf Grundlage des unabhängigen Briefings
  `docs/briefings/fix-10-preis-einheit.md`. Ausdrücklich mit abgenommen: die Kaufhistorie bleibt
  vorerst falsch (#54), der Preisvergleich zwischen Läden bleibt unerreicht (#15), geteilte Listen
  verlieren gelernte Preise bis #53.

## Purpose

`Store.learnedPrices` hält einen nackten `Double` ohne jede Bezugsgröße. Ein Preis, der beim
Bon-Scan korrekt als Rate **pro Gramm** gelernt wurde (`4,99 € ÷ 400 g = 0,0125 €/g`), wird beim
Anlegen eines gleichnamigen Artikels **ohne Mengenangabe** blind als Stückpreis übernommen und mit
`quantityAmount = 1` multipliziert — die Liste zeigt **0,01 €**. Diese Spec gibt dem gelernten
Preis seine Bezugsgröße (`"stk"` oder `"g"`), lässt `ShoppingItem.init` entscheiden, ob eine
gelernte Rate zur Einheit des Artikels überhaupt passt, und belegt die Mengenangabe aus
nachweisbarer Evidenz statt aus einer stillen `1`. Weil eine so belegte Menge eine Annahme der App
ist und keine Eingabe des Nutzers, wird sie auf der Liste als Annahme kenntlich gemacht
(„ca. 400 g") und bleibt korrigierbar.

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `init(name:category:quantity:quantityAmount:unit:note:store:)` (Zeile 90-158),
  `var estimatedLineTotal: Double?` (Zeile 166-168), neu: `var quantitySource: String`,
  `static func unitBucket(_:)`
- **Weitere Dateien:** `SmartCart/Models/Store.swift`,
  `SmartCart/Views/Prices/ReceiptScannerView.swift`,
  `SmartCart/Views/Prices/ActualPriceEntryView.swift`,
  `SmartCart/Services/AssignmentService.swift`,
  `SmartCart/Services/ReceiptParserService.swift`,
  `SmartCart/Views/Store/AddItemView.swift`,
  `SmartCart/Views/Components/ItemRow.swift`,
  `SmartCart/Views/Store/EditItemView.swift`

## Problem und belegte Ursache

**Root Cause — zwei Lücken, nicht eine:**

1. **`Store.learnedPrices: [String: Double]` (`Store.swift:27`) trägt keine Bezugsgröße.** Der
   Divisor, aus dem sich die Einheit ergibt, ist am Schreibort bekannt
   (`EditableReceiptLine.learningQuantity(matchQuantityAmount:)`, `ReceiptScannerView.swift:66-68`),
   wird aber nicht mitgespeichert (`ReceiptScannerView.swift:646-648`).
2. **Der Plausibilitäts-Guard in `ShoppingItem.init` (Zeile 152-153) kennt nur eine Obergrenze.**
   `PriceEstimator.maxPlausibleLearnedLineTotal` = 200 € fängt den historischen
   „Skyr 500 g → 1145 €"-Fall ab. Eine **Untergrenze existiert nicht**, also fällt `0,0125` durch
   jede vorhandene Prüfung.

**Das Lernen selbst ist nicht defekt.** `ReceiptParserService.weightBasisFromName`
(`ReceiptParserService.swift:903-918`) wurde genau für Ware mit Füllmengenangabe im Namen gebaut
(Kommentar Zeile 889-902, „Skyr-Bug") und liefert hier korrekt 400.

**Rechenkette des gemeldeten Falls:**

| Schritt | Stelle | Wert |
|---|---|---|
| Füllmenge aus dem Bonnamen lesen | `ReceiptParserService.swift:903-918` | `400` |
| Divisor bestimmen | `ReceiptScannerView.swift:66-68` | `400` |
| Rate bilden und speichern | `ReceiptScannerView.swift:646-648` | `4,99 / 400 = 0,0125` |
| Rate beim Anlegen holen (Fuzzy-Treffer) | `ShoppingItem.swift:127-146` | `0,0125` |
| Plausibilität prüfen (nur nach oben) | `ShoppingItem.swift:152-153` | besteht |
| Zeilensumme bilden | `ShoppingItem.swift:166-168` | `0,0125 × 1` → **0,01 €** |

**Reproduktion (2026-09-26, echter App-Pfad, ohne jede Codeänderung):**

`xcodebuild test -only-testing:RestockUITests/ReceiptReviewUITests/testSavingStillWritesLearnedPriceToMatchedItem`
auf dem Simulator `Restock-Validate` (`8F696920-4B9A-40A7-96F0-7697BE887CC7`). Die
Bestands-Fixture `SmartCartApp.seedReceiptReviewForUITestsIfNeeded` enthält bereits den Fall:
Zeile `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` für 4,99 €
(`SmartCartApp.swift:249-253`). Der Test speichert den Bon und öffnet die Lidl-Liste.

- Ist-Zustand: Die Liste zeigt **„Hackfleisch — 0,01 €"** und als geschätzten Gesamtbetrag
  **4,98 €** statt rund 10 €.
- Belege: `docs/artifacts/fix-10-preis-einheit/repro-heute-lidl-liste.png` (Bildschirmfoto),
  `docs/artifacts/fix-10-preis-einheit/repro-testlauf.log`
  (`Executed 1 test, with 0 failures`, kein Abbruch, kein Retry).
- Identisches Symptom wie der vom PO gemeldete Fall „Seitan zeigt 0,01 €" (2026-09-25).

**Entwurfs-Grundlage:** `docs/artifacts/fix-10-preis-einheit/entwurf.html` (veröffentlicht unter
https://claude.ai/artifact/AwBQGPWJAdch2aNkPMonUL) zeigt den Ist-Zustand neben drei Entwürfen in
hell und dunkel. Der PO hat am 2026-09-26 **Variante B** gewählt (angenommene Menge sichtbar als
Annahme markiert) und die Lieferung in einem Zug freigegeben.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Store.learnedPriceDates` (`Store.swift:32`) | property | Formvorbild für die additive Parallel-Map; dokumentiert dort, warum kein Schema-Bump nötig ist. |
| `EditableReceiptLine.learningQuantity(matchQuantityAmount:)` (`ReceiptScannerView.swift:66-68`) | method | Bestimmt den Divisor; die neue Einheiten-Ermittlung spiegelt exakt dessen Verzweigung. |
| `ReceiptParserService.weightBasisFromName(_:)` (`ReceiptParserService.swift:903-918`) | function | Liefert die normierte Füllmenge aus einem Namen; Grundlage für Stufe 3, unverändert. |
| `PriceEstimator.estimate(for:category:unit:quantityAmount:)` | function | Rückfallebene, sobald eine gelernte Rate verworfen wird — greift künftig häufiger. |
| `PriceEstimator.maxPlausibleLearnedLineTotal` (200 €) | constant | Bestehende Obergrenze, unverändert; die neue Prüfung tritt daneben, nicht an ihre Stelle. |
| `PurchaseRecord.storeName` / `.quantityAmount` / `.unit` (`PurchaseRecord.swift:11-13`) | properties | Evidenzquelle für Stufe 2. |
| `Color.amber` (`DesignSystem.swift:22`) | token | Tönung der als Annahme markierten Mengenangabe. |
| `QuantityStepperField` (`AddItemView.swift:72`) | view | Zeigt die Vorbelegung live und macht sie vor dem Hinzufügen korrigierbar — keine neue Oberfläche nötig. |

## Scope

### In scope

| Datei | Change | Was genau | LoC |
|---|---|---|---|
| `SmartCart/Models/Store.swift` | MODIFY | `learnedPriceUnits: [String: String] = [:]` + Doc-Kommentar nach Muster `learnedPriceDates` | ~10 |
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | `quantitySource: String = "user"`, `unitBucket(_:)`, Entscheidungstabelle in `init`, `estimatedLineTotal`-Gate | ~50 |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `EditableReceiptLine.learningUnit(matchUnit:)` + Schreibzeile in `save()` | ~22 |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | Einheit des Artikels beim manuellen Preis mitschreiben | ~5 |
| `SmartCart/Services/AssignmentService.swift` | MODIFY | `suggestQuantity(itemName:storeName:purchaseRecords:)` — die vier Stufen als reine, testbare Funktion | ~32 |
| `SmartCart/Views/Store/AddItemView.swift` | MODIFY | Ruft `suggestQuantity` auf, reicht `quantitySource` an den Konstruktor | ~18 |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | „ca."-Markierung, Ratenanzeige bei fehlender Evidenz | ~20 |
| `SmartCart/Views/Store/EditItemView.swift` | MODIFY | Menge vom Nutzer geändert → `quantitySource = "user"` | ~5 |
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | `packageSizeFromName(_:) -> (amount: Double, unit: String)?` als Geschwister zu `weightBasisFromName` | ~14 |
| `RestockTests/PriceProvenanceMigrationTests.swift` | MODIFY | Fixtures, eine geänderte Erwartung, neue Tests zur Entscheidungstabelle | ~90 |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Fixtures ergänzen | ~10 |
| `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` | CREATE | Nachweis der vier Stufen (AC11–AC13) | ~80 |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Durchstich nach dem Bon-Speichern, „ca."-Markierung hell und dunkel, Zurücksetzen beim Korrigieren | ~70 |

Produktivcode-Summe: **~180 LoC über 9 Produktdateien.**

**Warum die vier Stufen nicht in `AddItemView` bleiben:** Als private Methode einer SwiftUI-View
(`applySuggestedQuantity`, `AddItemView.swift:182-198`) sind sie automatisiert nicht nachweisbar —
AC11 bis AC13 wären dann Beschreibungen ohne Beweis. Als statische Funktion auf `AssignmentService`
(dort steht bereits die Logik, die aus Artikelname und Kaufhistorie eine Voreinstellung ableitet,
`AssignmentService.swift:79-180`, mit eigener Testdatei `RestockTests/AssignmentServiceTests.swift`)
sind sie eine reine Funktion über Werten und ohne SwiftUI-Umgebung prüfbar.

### Out of scope

- **Schnell-Eingabe in `HomeView` und `AddItemIntent` (Siri)** bekommen die Stufenlogik nicht.
  Siri hat keinen Bildschirm, auf dem eine Annahme sichtbar und korrigierbar wäre; PO-Entscheidung
  3 verlangt aber genau das. Beide Pfade legen weiterhin mit `quantityAmount = 1`, `unit = ""`,
  `quantitySource = "user"` an und sind durch die Entscheidungstabelle trotzdem vor dem Kernfehler
  geschützt — eine unpassende Rate wird verworfen, nicht multipliziert.
- **Sync geteilter Listen** (`SharedStoreService.encodePrices`/`decodePrices`,
  `SyncCoordinator.apply`) zieht `learnedPriceUnits` **nicht** mit → **Issue #53**. Folge siehe
  „Known Limitations".
- **Reparatur der einheitenlosen Altdaten** → **Issue #11** (PO-Entscheidung 1: Altdaten werden
  nicht angewendet, nicht repariert).
- **Trennung von Gramm und Milliliter** im gelernten Preis → **Issue #15**.
- **Schärfe des Fuzzy-Match** (`ShoppingItem.swift:129-131`) → **Issue #52**, unverändert.
- **Gewicht am `PurchaseRecord`** → **Issue #54**.

## Implementation Details

### 1. Bezugsgröße am gelernten Preis

```swift
/// Bezugsgröße pro `learnedPrices`-Eintrag: "stk" (Stückpreis) oder "g" (Gewichts- bzw.
/// Volumen-Subeinheit — g, mg, ml, cl, dl). Additiv wie `learnedPriceDates`, kein Schema-Bump,
/// CloudKit-tauglich, weil skalar mit Standardwert. Fehlt ein Key hier, stammt der Preis aus der
/// Zeit vor dieser Änderung und wird NIE angewendet (PO-Entscheidung 1, Reparatur: Issue #11).
var learnedPriceUnits: [String: String] = [:]
```

**Nur zwei Eimer, keine literalen Einheiten.** `weightBasisFromName`
(`ReceiptParserService.swift:916-917`) und der Gewichtszeilen-Zweig
(`ReceiptParserService.swift:379,432`) normieren `kg` **und** `l` auf denselben Faktor 1000. Aus
dem gespeicherten Preis lässt sich Gramm von Milliliter nicht mehr unterscheiden. Eine dritte,
literal genaue Einheit auszuweisen wäre vorgetäuschte Genauigkeit. Die Trennung landet in #15.

### 2. Einheit am Schreibort ermitteln

`EditableReceiptLine.learningUnit(matchUnit:)` spiegelt die Verzweigung von `learningQuantity`
eins zu eins — als Methode neben dieser, nicht als Kopie der Formel an der Aufrufstelle (Muster
aus dem Doc-Kommentar `ReceiptScannerView.swift:52-63`):

| Divisor-Quelle in `learningQuantity` | `learningUnit` liefert |
|---|---|
| `weightBasis` (Gewichtszeile „0,706 kg x 2,49") | `"g"` |
| `quantity > 1` (Mengenzeile „4 Stk x 0,39") | `"stk"` |
| `matchQuantityAmount` (abgehakter Artikel) | `unitBucket(matchUnit)` |
| `weightBasisFromName(originalName)` („… 400G") | `"g"` |
| Fallback `1` | `"stk"` |

Beide Methoden **müssen dieselbe Verzweigung in derselben Reihenfolge** treffen; ein Test sichert
das ab (siehe Test Plan).

`ActualPriceEntryView.apply(itemActualTotal:to:)` (`ActualPriceEntryView.swift:153-164`) skaliert
bereits exakt auf `item.quantityAmount`, die Einheit ist dort vertrauenswürdig bekannt:
`store.learnedPriceUnits[key] = ShoppingItem.unitBucket(item.unit)`.

### 3. Entscheidungstabelle in `ShoppingItem.init`

`unitBucket(_:)` bildet eine Einheit auf ihren Eimer ab: `""`, `"stk"`, `"stück"`, `"st"` → `"stk"`;
`"g"`, `"mg"`, `"ml"`, `"cl"`, `"dl"` → `"g"`; alles andere (`"kg"`, `"l"`, `"el"`, `"tl"`, …) auf
sich selbst, kleingeschrieben.

| gelernte Bezugsgröße | `unitBucket(item.unit)` | `quantitySource` | Ergebnis |
|---|---|---|---|
| fehlt (Altdaten) | beliebig | beliebig | **verwerfen** → `PriceEstimator` |
| `"stk"` | `"stk"` | beliebig | **anwenden**, Gesamtpreis = Rate × Menge |
| `"stk"` | `"g"`, `"kg"`, `"l"`, … | beliebig | **verwerfen** → `PriceEstimator` |
| `"g"` | `"g"` | beliebig | **anwenden**, Gesamtpreis = Rate × Menge |
| `"g"` | `"stk"` (also auch `unit == ""`) | `"none"` | **als Rate anwenden**, **kein** Gesamtpreis |
| `"g"` | `"stk"` (also auch `unit == ""`) | `"user"` | **verwerfen** → `PriceEstimator` |
| `"kg"`, `"l"`, sonstige | identischer Eimer | beliebig | **anwenden** |
| `"kg"`, `"l"`, sonstige | abweichender Eimer | beliebig | **verwerfen** → `PriceEstimator` |

Die bestehende Obergrenze (`ShoppingItem.swift:152-153`) bleibt unverändert davor bestehen; die
neue Prüfung entscheidet **zusätzlich**, nicht stattdessen.

Zeile 5 der Tabelle ist PO-Entscheidung 2, Stufe 4: Die Rate vom Bon ist echt und bleibt nützlich,
auch wenn keine Menge belegbar ist — nur ein *Gesamtpreis* darf daraus nicht entstehen. Die Rate
wird in `estimatedPrice` übernommen, `estimatedPriceIsAutoDerived = false`, und `item.unit` wird
auf `"g"` gesetzt, damit die Anzeige weiß, worauf sich die Rate bezieht.

### 4. Zeilensumme

```swift
var estimatedLineTotal: Double? {
    guard quantitySource != "none" else { return nil }
    return estimatedPrice.map { $0 * (quantityAmount > 0 ? quantityAmount : 1) }
}
```

### 5. Herkunft der Mengenangabe

Ein einziges neues Feld am `ShoppingItem`, kein zweites Kennzeichen:

```swift
/// Woher die Mengenangabe stammt: "user" (eingetippt oder korrigiert), "history" (letzter Kauf
/// desselben Artikels in diesem Laden), "package" (Füllmenge im Artikelnamen), "none" (keine
/// Evidenz — dann gibt es keinen Gesamtpreis, nur die Rate). Standardwert "user" hält alle
/// bestehenden Erzeugungsstellen unverändert; CloudKit verlangt den Standardwert ohnehin.
var quantitySource: String = "user"
```

Neuer Konstruktor-Parameter `quantitySource: String = "user"` — der Standardwert lässt die über
siebzehn bestehenden Erzeugungsstellen (Quick-Add, Siri-Intent, Widget, MenuPlan, RecipeImport,
HomeView-Vorschläge, StoreDetailView, SyncCoordinator) unverändert.

### 6. Vier Stufen in `AddItemView`

Die Stufenlogik zieht aus `AddItemView` heraus in eine reine, testbare Funktion:

```swift
/// Leitet aus nachweisbarer Evidenz eine Mengen-Voreinstellung für einen neu anzulegenden
/// Artikel ab. Reine Funktion über Werten — kein SwiftUI, kein ModelContext —, damit die vier
/// Stufen einzeln nachweisbar sind statt nur beschrieben.
static func suggestQuantity(itemName: String, storeName: String, purchaseRecords: [PurchaseRecord])
    -> (quantity: String, unit: String, source: String)
```

Aufgerufen aus `applySuggestedQuantity(for:)` (`AddItemView.swift:182-198`), das danach nur noch
den Guard aus Stufe 1 hält und das Ergebnis in `quantity`, `unit` und einen neuen
`@State private var quantitySource: String = "user"` schreibt.

1. **Nutzereingabe** — bestehender Guard `guard quantity.isEmpty else { return }` (Zeile 183),
   bleibt in der View. `suggestQuantity` wird dann gar nicht erst gerufen; `quantitySource`
   bleibt `"user"`.
2. **Letzter Kauf in diesem Laden** — der bestehende Namensfilter (Zeile 186-188) zieht in die
   Funktion um und bekommt zusätzlich `record.storeName == storeName`. Findet sich darüber nichts,
   wird **nicht** auf laden-übergreifend zurückgefallen — PO-Entscheidung 2 nennt ausdrücklich
   „in diesem Laden". → `source == "history"`.
3. **Füllmenge im getippten Namen** — `ReceiptParserService.packageSizeFromName(itemName)`.
   → `source == "package"`.
4. **Keine Evidenz** — leere Menge, leere Einheit. → `source == "none"`.

`addItem()` (`AddItemView.swift:200-218`) reicht `quantitySource` an den Konstruktor durch.

**Neue Geschwister-Funktion im Parser**, weil `weightBasisFromName` nur eine Zahl zurückgibt und
für die Anzeige die literale Einheit gebraucht wird — „ca. 500 g" für eine 0,5-l-Flasche wäre
sichtbar falsch:

```swift
/// Wie `weightBasisFromName`, gibt zusätzlich die Anzeige-Einheit zurück ("g" oder "ml").
/// Dieselbe Regex, dieselbe Normierung — `weightBasisFromName` bleibt der Durchreiche-Wert für
/// den Preis-Divisor, diese Variante liefert, was am Artikel angezeigt wird.
static func packageSizeFromName(_ name: String) -> (amount: Double, unit: String)?
```

Für den Preis-Eimer bleiben `"g"` und `"ml"` ununterscheidbar (beide → `"g"`); nur die **Anzeige**
unterscheidet sie. Das ist kein Widerspruch zur Zurückstellung von #15: dort geht es darum, aus
einem *gespeicherten* Preis nachträglich die Einheit zu erfahren, hier ist sie im Moment des
Lesens noch vorhanden.

### 7. Anzeige in `ItemRow`

Die Mengenzeile (`ItemRow.swift:85-88`) bekommt zwei Ergänzungen:

- Bedingung zusätzlich `item.quantitySource != "none"` — ohne belegte Menge wird gar keine
  Mengenangabe gezeigt (sonst stünde dort „1 g").
- Bei `quantitySource == "history"` oder `"package"`: Text mit Präfix `"ca. "` und
  `.foregroundStyle(Color.amber)` statt `.secondary`. Bei `"user"` unverändert wie heute.

Die Preiszelle (`ItemRow.swift:140-144`): Ist `estimatedLineTotal == nil`, `quantitySource == "none"`
und `item.unit == "g"`, wird stattdessen die Rate als `estimatedPrice × 100` mit dem Zusatz
`/100 g` angezeigt. In allen übrigen Fällen bleibt die Zelle unverändert.

### 8. Korrektur setzt die Herkunft zurück

`EditItemView.save()` (`EditItemView.swift:335-339`): Direkt nach dem Schreiben von
`item.quantityAmount` folgt `item.quantitySource = "user"`. Sobald der Nutzer die Menge angefasst
hat, ist sie seine — die Markierung verschwindet und der Gesamtpreis wird wieder gebildet.

## Invarianten

- **`learnedPrices` bleibt kanonisch eine Rate pro Einheit.** Diese Spec ändert nichts daran, was
  dort steht, sondern ergänzt nur, worauf es sich bezieht.
- **`estimatedPrice` bleibt eine Rate pro Einheit.** Nur `estimatedLineTotal` entscheidet, ob
  daraus ein Betrag gebildet wird.
- **Lieber kein Preis als ein falscher.** Jeder Zweifelsfall der Entscheidungstabelle endet beim
  `PriceEstimator`, nie bei einer geratenen Umrechnung.
- **Keine Schema-Migration.** Beide neuen Felder sind additiv mit Standardwert; kein bestehender
  Datensatz wird angefasst.
- **Ein einziger Konstruktor bleibt die Engstelle.** Jede Erzeugungsstelle profitiert von der
  Entscheidungstabelle, ohne selbst angefasst zu werden.
- **`learningQuantity` und `learningUnit` bleiben deckungsgleich.** Dieselbe Reihenfolge, dieselben
  Bedingungen.

## Test Plan

### Unit-Tests — `RestockTests/PriceProvenanceMigrationTests.swift`

**Neu:**

| Test | Beweist |
|---|---|
| `testLearnedGramPriceIsNotAppliedToItemWithoutQuantity` | Der gemeldete Fehler: `learnedPrices["hackfleisch"] = 4.99/400`, `learnedPriceUnits = "g"`, Item ohne Menge → `estimatedLineTotal` ist **nicht** 0,0125; der Preis stammt vom Schätzer (`estimatedPriceIsAutoDerived == true`). |
| `testLearnedGramPriceAppliesToItemWithGramQuantity` | Dasselbe Item mit `quantityAmount: 400, unit: "g"` → `estimatedLineTotal ≈ 4,99`. |
| `testLearnedPieceRateIsRejectedForWeightItem` | `"stk"`-Rate + Item in `"g"` → verworfen, Schätzer greift. |
| `testLearnedGramRateWithoutEvidenceIsKeptAsRate` | `quantitySource = "none"` → `estimatedPrice == 0,0125`, `estimatedLineTotal == nil`, `unit == "g"`. |
| `testLearnedPriceWithoutUnitIsNeverApplied` | PO-Entscheidung 1: Eintrag ohne `learnedPriceUnits`-Schlüssel wird verworfen, egal wie plausibel. |
| `testLearnedGramRateIsRejectedForKilogramItem` | `"g"`-Rate + Item in `"kg"` → verworfen (Gramm/Milliliter nicht unterscheidbar, siehe #15). |
| `testUnitBucketMapsSynonymsAndUnknownUnits` | `""`/`"Stk"`/`"Stück"` → `"stk"`; `"g"`/`"ml"`/`"cl"` → `"g"`; `"kg"` bleibt `"kg"`. |
| `testQuantitySourceDefaultsToUserForAllExistingCallSites` | Der Standardwert hält bestehende Erzeugungsstellen unverändert. |

**Geändert — Fixtures ergänzen, Aussage bleibt:**

- `testShoppingItemAcceptsLegitimatelyExpensiveLearnedPrice` (Zeile 70-78)
- `testShoppingItemStillUsesPlausibleLearnedPrice` (Zeile 80-92)
- `testShoppingItemPicksDeterministicWinnerWhenMultipleLearnedPricesMatchWithoutDates` (Zeile 52-68)
- `testShoppingItemRejectsImplausibleLearnedPriceAndFallsBackToEstimator` (Zeile 30-50)

Je eine zusätzliche Zeile `store.learnedPriceUnits[key] = "g"` bzw. `"stk"`, damit der Preis
überhaupt noch angewendet wird. Die geprüfte Aussage bleibt unverändert.

**Geändert — Aussage ändert sich (bewusst, PO-Entscheidung 1):**

- **`testMigrationRepairsCorruptedStoreLearnedPrice` (Zeile 94-124).** Er behauptet heute zweierlei:
  die Migration repariert den einheitenlosen Altwert (Zeile 116-118, `2.29 / 500`) **und** ein
  danach angelegtes Item übernimmt ihn (Zeile 120-123, erwartet `estimatedLineTotal == 2.29`). Der
  erste Teil bleibt unverändert gültig. Der zweite Teil wird umgestellt: Weil
  `PriceProvenanceMigration` keinen `learnedPriceUnits`-Eintrag schreibt, gilt der reparierte Wert
  weiterhin als einheitenlos und wird **nicht** angewendet — das Item bekommt einen Schätzpreis
  (`estimatedPriceIsAutoDerived == true`). **Der Test wird umgestellt, nicht gelöscht**, und
  behält damit seine Schutzwirkung für die Migration selbst.

Unverändert bleiben `testMigrationLeavesLegitimatelyExpensiveLearnedPriceUntouched` (Zeile 132-155)
und `testMigrationLeavesPlausibleStoreLearnedPricesUntouched` (Zeile 157-176) — sie prüfen die
Migration, nicht die Anwendung.

### Unit-Tests — `RestockTests/ReceiptParserPriceTests.swift`

**Geändert — Fixtures ergänzen und Einheit mitprüfen:** `assertLearnedPriceRoundTrip`
(Zeile 140-161, genutzt von `testLearnedPriceRoundTripWithHistoricalMatch` und
`testLearnedPriceRoundTripWithoutHistoricalMatch`),
`testFlatPricePackagedItemWithoutWeightLineLearnsCorrectPerGramPrice` (Zeile 205-229),
`testLearnedPriceRoundTripForReweBroetchenAndBanane` (Zeile 332-360).

`assertLearnedPriceRoundTrip` bekommt einen zusätzlichen Parameter `expectedUnit: String` und
prüft ab jetzt **beide** Werte gemeinsam: `store.learnedPrices[key]` **und**
`store.learnedPriceUnits[key]`. Damit hat AC1 einen eigenen Nachweis am Schreibweg selbst, nicht
nur mittelbar über den Durchstich in der Oberfläche.

**Neu:**

| Test | Beweist |
|---|---|
| `testSavingReceiptStoresPriceAndUnitTogether` | AC1 am Schreibweg: Die Bon-Zeile `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` für 4,99 € legt in einem Zug `4.99/400` **und** die Bezugsgröße `"g"` unter demselben Schlüssel ab. Gegenprobe: die Zeile `MILCH` ohne Füllmenge legt `1.19` und `"stk"` ab. |
| `testLearningUnitMatchesLearningQuantityBranchForEveryCase` | Für alle fünf Zweige liefern `learningQuantity` und `learningUnit` zusammenpassende Werte. |
| `testPackageSizeFromNameReturnsLitreAsMillilitre` | `"COLA 0,5L"` → `(500, "ml")`, `"SKYR NATUR 500G"` → `(500, "g")`, `"WEIN 75CL"` → `(750, "ml")`. |
| `testPackageSizeFromNameAgreesWithWeightBasisFromName` | Beide Funktionen liefern für dieselben Namen denselben Zahlenwert. |

### Unit-Tests — `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` (neu)

Deckt die vier Stufen der Mengen-Vorbelegung ab. Ohne diese Datei wären AC11 bis AC13 bloße
Beschreibungen ohne Nachweis.

| Test | Beweist |
|---|---|
| `testSuggestsQuantityFromLastPurchaseInSameStore` | Kaufhistorie mit 400 g bei „Lidl" → `("400", "g", "history")`. AC11, erster Teil. |
| `testIgnoresPurchaseHistoryFromOtherStore` | Derselbe Artikel, 400 g bei „Rewe", Abfrage für „Lidl" → kein Treffer aus Stufe 2. AC11, zweiter Teil. |
| `testFallsBackToPackageSizeInTypedName` | Ohne Historie, Name „Skyr Natur 500g" → `("500", "g", "package")`. AC12. |
| `testFallsBackToLitrePackageSizeWithMillilitreUnit` | Name „Cola 0,5L" → `("500", "ml", "package")` — keine Gramm-Anzeige für Flüssiges. |
| `testReturnsNoneWithoutAnyEvidence` | Weder Historie noch Füllmenge → `("", "", "none")`. AC13, erster Teil. |
| `testAveragesRecentPurchasesLikeBefore` | Das bestehende Mittelungsverhalten über die letzten fünf Käufe (`AddItemView.swift:190-196`) bleibt beim Umzug unverändert. |
| `testSuggestionIsNotConsultedWhenUserTypedQuantity` | Stufe 1 hat Vorrang: eine eingetippte Menge ergibt stets `"user"`. AC13, zweiter Teil. |

### UI-Tests — `RestockUITests/ReceiptReviewUITests.swift`

| Test | Beweist |
|---|---|
| `testSavedReceiptDoesNotProduceOneCentItemPrice` | Durchstich des reproduzierten Falls: nach „Speichern" steht in der Lidl-Liste am Artikel „Hackfleisch" **kein** Betrag „0,01 €". AC17. |
| `testAssumedQuantityIsMarkedAsAssumptionInList` | Ein Artikel mit angenommener Menge zeigt in der Zeile „ca. 400 g"; ein Artikel mit eingetippter Menge zeigt „400 g" ohne „ca.". AC14. |
| `testAssumptionMarkIsReadableInDarkMode` | Dieselbe Markierung im Dunkelmodus (`XCUIDevice.shared.appearance = .dark`), Muster wie `testOriginalTextAndAiMarkAreReadableInDarkMode` (Zeile 690). AC18. |
| `testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal` | Menge über „Bearbeiten" ändern und speichern → „ca." verschwindet aus der Zeile und es steht wieder ein Gesamtbetrag statt einer Rate. AC16. |
| `testItemWithoutEvidenceShowsRateInsteadOfTotal` | Artikel ohne jede Mengen-Evidenz zeigt „€/100 g" statt eines Gesamtbetrags und gar keine Mengenangabe. AC15. |

Die Tests laufen über die Test-Action des Schemas auf Deutsch (`language="de"`, `region="DE"`) und
prüfen Anzeigetexte. Jede Klasse, die Daten sät, räumt in `tearDown()` über ihr eigenes
Aufräum-Argument wieder auf (`-clearReceiptReviewSeedForUITests`), weil der App-Group-Container den
Lauf überlebt.

**Bestandstests gegenprüfen:** `testSavingStillWritesLearnedPriceToMatchedItem` (Zeile 667-687)
erwartet „0,99" am Artikel „Milch". Die Milch-Zeile hat keine Füllmenge im Namen und lernt
`"stk"` — der Test muss unverändert grün bleiben und ist damit zugleich der Regressionsschutz für
den Stückpreis-Pfad.

## Acceptance Criteria

- [ ] **AC1:** Bon-Zeile `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` für 4,99 € → nach
  `ReceiptScannerView.save()` gilt `store.learnedPrices["bio-hackfleisch gemischt rind & schwein 400 g"] == 4.99/400`
  **und** `store.learnedPriceUnits[...] == "g"`.
- [ ] **AC2:** `ShoppingItem(name: "Hackfleisch", store: store)` ohne Mengenangabe und mit
  `quantitySource == "user"` übernimmt diese Rate **nicht**: `estimatedPriceIsAutoDerived == true`
  und `estimatedLineTotal != 0.0125`.
- [ ] **AC3:** `ShoppingItem(name: "Hackfleisch", quantityAmount: 400, unit: "g", store: store)`
  ergibt `estimatedLineTotal ≈ 4.99` (Genauigkeit 0,01).
- [ ] **AC4:** Ein gelernter Stückpreis (`learnedPriceUnits == "stk"`) wird für einen Artikel mit
  `unit: "g"` verworfen; `estimatedPriceIsAutoDerived == true`.
- [ ] **AC5:** Ein `learnedPrices`-Eintrag **ohne** zugehörigen `learnedPriceUnits`-Eintrag wird
  nie angewendet, auch wenn Betrag und Menge plausibel sind (PO-Entscheidung 1).
- [ ] **AC6:** `quantitySource == "none"` mit gelernter `"g"`-Rate → `estimatedPrice == 4.99/400`,
  `estimatedLineTotal == nil`, `unit == "g"`, `estimatedPriceIsAutoDerived == false`.
- [ ] **AC7:** Eine `"g"`-Rate wird für einen Artikel mit `unit: "kg"` verworfen
  (`estimatedPriceIsAutoDerived == true`) — keine stille Umrechnung um den Faktor 1000.
- [ ] **AC8:** `ShoppingItem.unitBucket` bildet `""`, `"Stk"`, `"Stück"`, `"st"` auf `"stk"` ab,
  `"g"`, `"mg"`, `"ml"`, `"cl"`, `"dl"` auf `"g"`, und lässt `"kg"`, `"l"`, `"el"` unverändert
  kleingeschrieben stehen.
- [ ] **AC9:** Für jeden der fünf Zweige von `learningQuantity` liefert `learningUnit` den in der
  Tabelle unter „Implementation Details 2" genannten Wert — geprüft über dieselbe Instanz von
  `EditableReceiptLine`, nicht über eine nachgebaute Formel.
- [ ] **AC10:** `ReceiptParserService.packageSizeFromName` liefert `("COLA 0,5L") == (500, "ml")`,
  `("SKYR NATUR 500G") == (500, "g")`, `("WEIN 75CL") == (750, "ml")`; der Zahlenwert stimmt für
  alle drei mit `weightBasisFromName` überein.
- [ ] **AC11:** `AssignmentService.suggestQuantity` liefert für einen Artikel, der in diesem Laden
  zuletzt mit 400 g gekauft wurde, `("400", "g", "history")` — dieselbe Abfrage mit einem Kauf
  desselben Artikels in einem **anderen** Laden liefert keinen Treffer aus Stufe 2.
- [ ] **AC12:** `AssignmentService.suggestQuantity` liefert ohne Kaufhistorie für den Namen
  `"Skyr Natur 500g"` das Ergebnis `("500", "g", "package")` und für `"Cola 0,5L"` das Ergebnis
  `("500", "ml", "package")`.
- [ ] **AC13:** `AssignmentService.suggestQuantity` liefert ohne Historie und ohne Füllmenge
  `("", "", "none")`; hat der Nutzer eine Menge eingetippt, wird die Funktion gar nicht erst
  gerufen und der Artikel entsteht mit `quantitySource == "user"`.
- [ ] **AC14:** In der Liste zeigt ein Artikel mit `quantitySource == "history"` oder `"package"`
  den Text `"ca. 400 g"` in `Color.amber`; mit `quantitySource == "user"` den Text `"400 g"` wie
  bisher; mit `quantitySource == "none"` gar keine Mengenangabe.
- [ ] **AC15:** In der Liste zeigt ein Artikel mit `quantitySource == "none"` und `unit == "g"`
  statt eines Gesamtpreises die Rate `"1,25 €/100 g"` (= `estimatedPrice × 100`).
- [ ] **AC16:** Ändert der Nutzer die Menge in `EditItemView` und speichert, gilt
  `quantitySource == "user"`, die „ca."-Markierung verschwindet und `estimatedLineTotal` liefert
  wieder einen Betrag.
- [ ] **AC17:** UI-Durchstich: Nach „Speichern" im Bon-Prüf-Screen enthält die Lidl-Liste am
  Artikel „Hackfleisch" **keinen** Betrag „0,01 €".
- [ ] **AC18:** Die „ca."-Markierung ist im Dunkelmodus lesbar (eigener UI-Test).
- [ ] **AC19:** `testSavingStillWritesLearnedPriceToMatchedItem` bleibt unverändert grün — der
  Stückpreis-Pfad („Milch", 0,99 €) ist nicht betroffen.
- [ ] **AC20:** Die gesamte Bestandssuite (Unit + UI) ist im **gemeinsamen** Lauf grün, nicht nur
  je Testklasse einzeln.

## Alternativen (verworfen)

- **A — Angenommene Menge wie eine eingetippte darstellen.** Die Menge stünde ohne „ca." und ohne
  Tönung in der Zeile. Spart das Feld `quantitySource` in der Anzeige sowie die Änderungen an
  `ItemRow` und `EditItemView` — fünf statt acht Dateien. **Vom PO am 2026-09-26 verworfen**, weil
  der Nutzer dann nicht unterscheiden kann, welche Menge er selbst gesetzt hat und welche die App
  geraten hat. Widerspricht PO-Entscheidung 3.
- **C — Kein Preis statt eines angenommenen.** Passt die gelernte Rate nicht zur Einheit des
  Artikels, greift der Schätzer; keine Menge wird vorbelegt. Kleinster Eingriff, keine sichtbare
  Änderung an der Liste. **Vom PO verworfen**, weil der echte, vom Bon gelernte Preis dann bei
  jedem mengenlosen Anlegen erneut verfällt. Kippt PO-Entscheidung 2.
- **`estimatedLineTotal` app-weit von „immer ein Betrag" auf „Betrag oder Rate" umstellen.** Spart
  die gesamte Einheiten-Map. Verworfen, weil es die im Code dokumentierte Konvention
  (`ShoppingItem.swift:158-165`) an über zehn Anzeige- und Summenstellen bricht, darunter die
  proportionale Aufteilung in `ActualPriceEntryView.save()` (Zeile 128-129).
- **Zwei Felder statt einem** (`quantityIsUncertain: Bool` neben einer Herkunft). Verworfen, weil
  „keine Evidenz" bereits ein Wert der Herkunft ist; zwei Felder könnten widersprüchlich werden.
- **`learnedPrices` auf einen Struct-Wert umstellen** (`{ price, unit, date }`). Sauberer, aber ein
  echter Schema-Bruch an einer Stelle mit dokumentiertem Datenverlust
  (`SharedModelContainer.swift`, Kopfkommentar) und mit drei Sync-Kodierstellen. Verworfen zugunsten
  der additiven Parallel-Map, die im Projekt bereits zweimal erprobt ist.
- **Gramm und Milliliter jetzt schon trennen.** Verworfen, weil die Quelle beides auf denselben
  Faktor normiert (`ReceiptParserService.swift:916`); eine dritte Einheit wäre vorgetäuschte
  Genauigkeit. Verschoben auf #15.

## Risiken

- **Umfang deutlich über der Hausgrenze.** Neun Produktdateien statt der üblichen vier bis fünf,
  ~180 LoC. **Vom PO am 2026-09-26 zweimal ausdrücklich freigegeben**: zuerst bei sechs bis sieben
  Dateien, dann erneut bei neun, nachdem ihm die Aufteilung in zwei Lieferungen jeweils als
  Alternative mit konkreten Zahlen vorlag. Die Freigabe gilt für #10 und hebt die Grenze nicht
  allgemein an.
- **LoC-Gate zählt Testcode als Produktivcode** (Issue #36). ~180 LoC Produktcode plus ~250 LoC
  Tests überschreiten die 250er-Grenze sicher. Gegenmaßnahme: nach Schritt 4 der Reihenfolge einen
  grünen Zwischenstand sichern und die Umsetzung in zwei gesicherte Abschnitte teilen, bevor die
  Testdateien wachsen. Das Gate wird während der Umsetzung anschlagen — das ist eingeplant, kein
  Fehler.
- **Sichtbarer einmaliger Preisverlust.** Alle heute gelernten Preise sind einheitenlos und werden
  ab dieser Änderung nicht mehr angewendet (PO-Entscheidung 1). Erwartbare Wahrnehmung: „Die Preise
  sind weg." Gehört in die Release-Hinweise. Reparatur: #11.
- **Bestandstests hängen an Anzeigetexten** (#18/#20). Die „ca."-Markierung ändert den Zeilentext.
  Jeder UI-Test, der einen Mengentext prüft, muss gegengeprüft werden.
- **Bereich mit dokumentiertem Datenverlust.** `SharedModelContainer.make()` trägt eine Warnung im
  Kopfkommentar. Gegenmaßnahme: rein additive Felder, keine Migration, keine neue Entität, keine
  Änderung an der Container-Verzweigung.
- **Der Fuzzy-Match bleibt grob.** Die Einheitenprüfung filtert nach Dimension, nicht nach
  Produktidentität — ein falscher Namenstreffer mit zufällig passender Einheit rutscht weiterhin
  durch (#52). Diese Änderung verschlimmert das nicht.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — im Projekt existiert kein formales ADR-Verzeichnis (`docs/adr/` fehlt).
- **Rationale:** Die Entscheidung, die Bezugsgröße als additive Parallel-Map statt als
  Struct-Wert zu führen, folgt einem im Projekt bereits zweimal erprobten Muster
  (`learnedPriceDates`, `categoryManuallySet`) und vermeidet einen Schema-Bruch in einem Bereich
  mit dokumentiertem Datenverlust. Die Entscheidung, nur zwei Eimer statt literaler Einheiten zu
  führen, ist durch die Normierung in `ReceiptParserService.swift:916` erzwungen und in #15
  auflösbar. Beide sind hier unter „Implementation Details" und „Alternativen (verworfen)"
  begründet und durch AC1, AC5, AC7, AC8 abgesichert; ein eigenes ADR-Dokument wäre für einen
  Bugfix dieses Umfangs unverhältnismäßig.

## Expected Behavior

- Ein Bon wird gescannt und gespeichert. Für jede übernommene Position merkt sich die App neben dem
  Preis, worauf er sich bezieht — auf ein Stück oder auf ein Gramm beziehungsweise Milliliter.
- Wird derselbe Artikel später auf die Liste gesetzt, schlägt die App eine Menge vor, sobald sie
  eine belegen kann: zuerst die zuletzt in diesem Laden gekaufte Menge, sonst die Füllmenge, die im
  Namen steht. Die Vorbelegung erscheint im Hinzufügen-Formular und ist dort änderbar.
- Auf der Liste steht eine angenommene Menge als „ca. 400 g" in der Warnfarbe. Eine selbst
  eingetippte Menge steht dort wie bisher.
- Lässt sich keine Menge belegen, zeigt die Liste keinen Gesamtpreis, sondern die Rate: „1,25 €/100 g".
- Passt die gelernte Bezugsgröße nicht zur Einheit des Artikels, wird der gelernte Preis gar nicht
  benutzt; es erscheint die übliche Schätzung.
- Wird die Menge nachträglich geändert, gilt sie als Eingabe des Nutzers: Die Markierung
  verschwindet und aus Rate und Menge wird wieder ein Gesamtpreis.
- Einmalig verschwinden alle bisher gelernten Preise aus der Anzeige, weil ihnen die Bezugsgröße
  fehlt. Beim nächsten Bon-Scan werden sie mit Bezugsgröße neu gelernt.

## Known Limitations

- **Geteilte Listen verlieren gelernte Preise, bis #53 nachzieht.** `SharedStoreService` und
  `SyncCoordinator` übertragen `learnedPrices` und `learnedPriceDates`, aber nicht
  `learnedPriceUnits`. Ein auf Gerät A gelernter Preis kommt auf Gerät B ohne Bezugsgröße an und
  wird dort wie ein Altdatum behandelt — also nicht angewendet. **Kein Falschpreis-Risiko**, aber
  ein fehlender Preis. Muss an der Kodierstelle kommentiert und an #53 vermerkt werden, sonst wird
  es als neuer Fehler gemeldet.
- **Gramm und Milliliter bleiben im gespeicherten Preis ununterscheidbar.** Ein Preis pro Gramm und
  ein Preis pro Milliliter liegen im selben Eimer. Für diesen Fehler ohne Folge, für den
  Preisvergleich in #15 nicht ausreichend.
- **Ein Preis pro Kilogramm oder Liter wird nicht umgerechnet**, sondern verworfen — die Richtung
  der Umrechnung wäre nur mit der Unterscheidung aus #15 sicher.
- **Schnell-Eingabe und Siri belegen keine Menge.** Dort gilt weiterhin „eine Einheit", und eine
  unpassende gelernte Rate wird verworfen statt angewendet.
- **Einheitenlose Altdaten bleiben liegen**, bis #11 sie repariert.

## Changelog

- 2026-09-26: Initial spec created
- 2026-09-26: Nachweislücke geschlossen — die vier Stufen der Mengen-Vorbelegung ziehen aus der
  Hinzufügen-Ansicht in `AssignmentService.suggestQuantity` um und bekommen eine eigene Testdatei;
  AC11–AC13 sind damit belegbar statt nur beschrieben. AC15 und AC16 bekommen je einen UI-Test.
  Umfang dadurch neun Produktdateien / ~180 LoC, vom PO erneut freigegeben.
- 2026-09-26: AC1 bekommt einen eigenen Nachweis am Schreibweg — `assertLearnedPriceRoundTrip`
  prüft Preis und Bezugsgröße gemeinsam, dazu ein eigener Test für Gewichts- und Stückfall.
