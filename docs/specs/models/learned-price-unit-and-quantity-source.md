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
gelernte Rate zur Einheit des Artikels überhaupt passt, und lässt sie verwerfen, wenn sie nicht
passt — dann greift die übliche Schätzung statt eines falschen Betrags.

**Nicht mehr Teil dieser Spec:** Die Mengenangabe aus nachweisbarer Evidenz zu belegen (statt aus
einer stillen `1`) und sie auf der Liste als Annahme kenntlich zu machen („ca. 400 g"). Das war
ursprünglich Teil dieses Tickets — PO-Entscheidungen 2 und 3 aus dem Intake — und ist am
2026-09-26 auf ausdrückliche Entscheidung des PO nach **Issue #57** gezogen worden. #10 liefert
also **nur** die Preiskorrektur, nicht die sichtbare, korrigierbare Mengen-Annahme. Begründung und
Umfang der Trennung: Abschnitt „Nach Issue #57 verschoben" unter den Acceptance Criteria.

Ohne diese Vorbelegung bleibt `quantitySource` überall `"user"`, weshalb die Entscheidungstabelle
in #10 praktisch nur zwischen „anwenden" und „verwerfen" unterscheidet. Genau das behebt den
gemeldeten Fehler.

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `init(name:category:quantity:quantityAmount:unit:note:store:)` (Zeile 90-158),
  `var estimatedLineTotal: Double?` (Zeile 166-168), neu: `var quantitySource: String`,
  `static func unitBucket(_:)`
- **Weitere Dateien:** `SmartCart/Models/Store.swift`,
  `SmartCart/Views/Prices/ReceiptScannerView.swift`,
  `SmartCart/Views/Prices/ActualPriceEntryView.swift`,
  `SmartCart/Services/ReceiptParserService.swift`,
  `SmartCart/Views/Components/ItemRow.swift`,
  `SmartCart/Views/Store/EditItemView.swift`
- **Nicht in #10:** `SmartCart/Services/AssignmentService.swift` und
  `SmartCart/Views/Store/AddItemView.swift` — beide gehören mit der Mengen-Vorbelegung zu
  **Issue #57** und bleiben hier unverändert.

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
Annahme markiert) und die Lieferung zunächst in einem Zug freigegeben.

Die Lieferung in einem Zug ist **überholt**: Am 2026-09-26 wurde das Ticket auf PO-Entscheidung
geteilt, die Mengen-Vorbelegung samt der hier gewählten Variante B ist nach **Issue #57** gezogen.
Der Entwurf bleibt gültig und ist dort die Grundlage — er muss nicht neu erstellt oder neu
freigegeben werden.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Store.learnedPriceDates` (`Store.swift:32`) | property | Formvorbild für die additive Parallel-Map; dokumentiert dort, warum kein Schema-Bump nötig ist. |
| `EditableReceiptLine.learningQuantity(matchQuantityAmount:)` (`ReceiptScannerView.swift:66-68`) | method | Bestimmt den Divisor; die neue Einheiten-Ermittlung spiegelt exakt dessen Verzweigung. |
| `ReceiptParserService.weightBasisFromName(_:)` (`ReceiptParserService.swift:903-918`) | function | Liefert die normierte Füllmenge aus einem Namen; Grundlage für Stufe 3, unverändert. |
| `PriceEstimator.estimate(for:category:unit:quantityAmount:)` | function | Rückfallebene, sobald eine gelernte Rate verworfen wird — greift künftig häufiger. |
| `PriceEstimator.maxPlausibleLearnedLineTotal` (200 €) | constant | Bestehende Obergrenze, unverändert; die neue Prüfung tritt daneben, nicht an ihre Stelle. |
| `PurchaseRecord.unit` (`PurchaseRecord.swift:13`) | property | Liefert die Bezugsgröße, wenn ein Bon einem bekannten Kauf zugeordnet ist (`learningUnit(matchUnit:)`). |
| `Color.amber` (`DesignSystem.swift:22`) | token | Tönung der als Annahme markierten Mengenangabe — nur vom mitgelieferten, in #10 unerreichbaren `ItemRow`-Code benutzt, wirksam erst mit **#57**. |

`PurchaseRecord.storeName` / `.quantityAmount` als Evidenzquelle für die Laden-Historie und
`QuantityStepperField` (`AddItemView.swift:72`) als Ort der korrigierbaren Vorbelegung gehören zu
**Issue #57** und werden in #10 nicht angefasst.

## Scope

### In scope

| Datei | Change | Was genau | LoC |
|---|---|---|---|
| `SmartCart/Models/Store.swift` | MODIFY | `learnedPriceUnits: [String: String] = [:]` + Doc-Kommentar nach Muster `learnedPriceDates` | ~10 |
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | `quantitySource: String = "user"`, `unitBucket(_:)`, Entscheidungstabelle in `init`, `estimatedLineTotal`-Gate | ~50 |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `EditableReceiptLine.learningUnit(matchUnit:)` + Schreibzeile in `save()` | ~22 |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | Einheit des Artikels beim manuellen Preis mitschreiben | ~5 |
| `SmartCart/Views/Components/ItemRow.swift` | MODIFY | Mengenzeile beachtet `quantitySource` — Vorarbeit für #57, ohne `suggestQuantity` nicht erreichbar | ~9 |
| `SmartCart/Views/Store/EditItemView.swift` | MODIFY | Menge vom Nutzer geändert → `quantitySource = "user"` | ~4 |
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | `packageSizeFromName(_:) -> (amount: Double, unit: String)?` als Geschwister zu `weightBasisFromName` | ~14 |
| `RestockTests/PriceProvenanceMigrationTests.swift` | MODIFY | Fixtures, eine geänderte Erwartung, neue Tests zur Entscheidungstabelle | ~90 |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Fixtures ergänzen, `learningUnit` mitprüfen | ~12 |
| `RestockTests/PriceEstimatorStagesTests.swift` | MODIFY | Fixture `learnedPriceUnits["milch"] = "stk"`, sonst ist die Stufen-Rangfolge nicht mehr messbar | ~4 |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Durchstich nach dem Bon-Speichern (AC-17) | ~30 |

Produktivcode-Summe: **~203 LoC über 7 Produktdateien** (gemessen, nur hinzugefügte Zeilen).

Die drei Dateien der Mengen-Vorbelegung — `AssignmentService.swift` (`suggestQuantity`),
`AddItemView.swift` (Anbindung) und `RestockTests/AssignmentServiceQuantitySuggestionTests.swift`
(neu) — sind mit AC-11 bis AC-13 nach **Issue #57** gezogen und in diesem Ticket **unverändert**.
Die dort festgehaltene Begründung gilt weiter: Als private Methode einer SwiftUI-View
(`applySuggestedQuantity`, `AddItemView.swift:182-198`) wären die vier Stufen automatisiert nicht
nachweisbar; als statische Funktion auf `AssignmentService` sind sie eine reine Funktion über
Werten und ohne SwiftUI-Umgebung prüfbar.

### Out of scope

- **Mengen-Vorbelegung und ihre Kennzeichnung in der Liste** → **Issue #57** (PO-Entscheidung
  2026-09-26). Umfasst `AssignmentService.suggestQuantity`, die Anbindung in `AddItemView`, die
  Ratenanzeige AC-15 und die Tests zu AC-11…AC-16 und AC-18. Ohne diese Vorbelegung entsteht kein
  Artikel mit `quantitySource != "user"`, weshalb die Entscheidungstabelle in diesem Ticket
  praktisch nur zwischen „anwenden" und „verwerfen" unterscheidet — genau das, was den gemeldeten
  Fehler behebt.
- **Schnell-Eingabe in `HomeView` und `AddItemIntent` (Siri)** bekommen die Stufenlogik nicht.
  Siri hat keinen Bildschirm, auf dem eine Annahme sichtbar und korrigierbar wäre; PO-Entscheidung
  3 verlangt aber genau das. Beide Pfade legen weiterhin mit `quantityAmount = 1`, `unit = ""`,
  `quantitySource = "user"` an und sind durch die Entscheidungstabelle trotzdem vor dem Kernfehler
  geschützt — eine unpassende Rate wird verworfen, nicht multipliziert.
- **Sync geteilter Listen** (`SharedStoreService.encodePrices`/`decodePrices`,
  `SyncCoordinator.apply`) zieht `learnedPriceUnits` **nicht** mit → **Issue #53**. Folge siehe
  „Known Limitations".
  *Nachtrag 2026-10-02:* mit #53 behoben — `LearnedPriceSync` (`SharedStoreService.swift`) überträgt
  die Einheit gemeinsam mit Betrag und Zeitstempel.
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

**Zwei zusammengefasste Eimer — plus literale Einheiten für alles übrige.**
`weightBasisFromName` (`ReceiptParserService.swift:916-917`) und der Gewichtszeilen-Zweig
(`ReceiptParserService.swift:379,432`) normieren `kg` **und** `l` auf denselben Faktor 1000. Aus
dem gespeicherten Preis lässt sich Gramm von Milliliter nicht mehr unterscheiden. Eine dritte,
literal genaue Einheit für **diese** Fälle auszuweisen wäre vorgetäuschte Genauigkeit; die Trennung
von g und ml landet in #15.

Zusammengefasst werden daher nur zwei Gruppen: Stück-Synonyme (`""`, `"stk"`, `"stück"`, `"st"`, …)
zu `"stk"` und Gewichts-/Volumen-Subeinheiten (`"g"`, `"mg"`, `"ml"`, `"cl"`, `"dl"` samt Langformen)
zu `"g"`. **Jede andere Einheit bleibt literal erhalten**, kleingeschrieben — `"kg"`, `"l"`, `"el"`,
`"tl"` landen unverändert in `learnedPriceUnits` (`ShoppingItem.unitBucket`, `default: return
normalized`). Das ist gewollt und gefahrlos, weil literale Eimer nur exakt gegeneinander verglichen
und nie ineinander umgerechnet werden — genau das verlangt AC-7 („keine stille Umrechnung um den
Faktor 1000") und AC-8 führt die literalen Fälle ausdrücklich auf.

*Hinweis auf eine Unschärfe im Code:* Der Doc-Kommentar über `unitBucket`
(`ShoppingItem.swift`) beschreibt zuerst korrekt „alles andere … auf sich selbst", behauptet
im Folgesatz aber „Nur zwei Eimer statt literaler Einheiten". Derselbe Widerspruch, den dieser
Absatz hier hatte. Er ist inhaltlich folgenlos und wird bei der nächsten Berührung der Datei
mitkorrigiert — vermerkt an **#15**, wo die Frage „literale Einheit oder Eimer" sachlich hingehört.

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

> **Abschnitte 6 bis 8 gehören zu Issue #57**, nicht mehr zu diesem Ticket (PO-Entscheidung
> 2026-09-26). Sie bleiben hier als Vorarbeit stehen, damit #57 nicht von vorn anfängt.
>
> **Was in #10 davon schon im Code steht — genau, nicht pauschal:**
> - Abschnitt 7, **Mengenzeile** (AC-14: `"ca. "`-Präfix, `Color.amber`, keine Mengenangabe bei
>   `"none"`): geschrieben.
> - Abschnitt 7, **Preiszelle** (AC-15: Rate `estimatedPrice × 100` als „1,25 €/100 g" statt eines
>   Gesamtbetrags): **NICHT geschrieben.** In `ItemRow` gibt es keinen solchen Fallback; die
>   Preiszelle zeigt bei `estimatedLineTotal == nil` gar nichts. #57 muss das bauen.
> - Abschnitt 8 (AC-16: `EditItemView` setzt `quantitySource = "user"`): geschrieben.
> - Abschnitt 6 (`suggestQuantity`, AC-11 bis AC-13): **NICHT geschrieben.**
>
> Das Verhalten des geschriebenen Teils ist in #10 nicht nachgewiesen (die Tests dafür sind mit
> nach #57 gezogen); belegt ist nur, dass er compiliert und keinen Bestandstest bricht. Erreichbar
> wird er erst mit `suggestQuantity` aus Abschnitt 6.

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

### Nach Issue #57 verschoben

Die Testdatei `RestockTests/AssignmentServiceQuantitySuggestionTests.swift` (sieben Tests zu den
vier Stufen der Mengen-Vorbelegung, AC-11 bis AC-13) sowie vier UI-Tests
(`testAssumedQuantityIsMarkedAsAssumptionInList` AC-14,
`testAssumptionMarkIsReadableInDarkMode` AC-18,
`testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal` AC-16,
`testItemWithoutEvidenceShowsRateInsteadOfTotal` AC-15) sind mit ihren Anforderungen nach
**Issue #57** gezogen und **nicht** Teil von #10. Ihre Beschreibungen stehen dort.

### UI-Tests — `RestockUITests/ReceiptReviewUITests.swift`

| Test | Beweist |
|---|---|
| `testSavedReceiptDoesNotProduceOneCentItemPrice` | Durchstich des reproduzierten Falls: nach „Speichern" steht in der Lidl-Liste am Artikel „Hackfleisch" **kein** Betrag „0,01 €". AC-17. |

Die Tests laufen über die Test-Action des Schemas auf Deutsch (`language="de"`, `region="DE"`) und
prüfen Anzeigetexte. Jede Klasse, die Daten sät, räumt in `tearDown()` über ihr eigenes
Aufräum-Argument wieder auf (`-clearReceiptReviewSeedForUITests`), weil der App-Group-Container den
Lauf überlebt.

**Bestandstests gegenprüfen:** `testSavingStillWritesLearnedPriceToMatchedItem` (Zeile 667-687)
erwartet „0,99" am Artikel „Milch". Die Milch-Zeile hat keine Füllmenge im Namen und lernt
`"stk"` — der Test muss unverändert grün bleiben und ist damit zugleich der Regressionsschutz für
den Stückpreis-Pfad.

## Acceptance Criteria

- **AC-1:** Bon-Zeile `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` für 4,99 € → nach
  `ReceiptScannerView.save()` gilt `store.learnedPrices["bio-hackfleisch gemischt rind & schwein 400 g"] == 4.99/400`
  **und** `store.learnedPriceUnits[...] == "g"`.
- **AC-2:** `ShoppingItem(name: "Hackfleisch", store: store)` ohne Mengenangabe und mit
  `quantitySource == "user"` übernimmt diese Rate **nicht**: `estimatedPriceIsAutoDerived == true`
  und `estimatedLineTotal != 0.0125`.
- **AC-3:** `ShoppingItem(name: "Hackfleisch", quantityAmount: 400, unit: "g", store: store)`
  ergibt `estimatedLineTotal ≈ 4.99` (Genauigkeit 0,01).
- **AC-4:** Ein gelernter Stückpreis (`learnedPriceUnits == "stk"`) wird für einen Artikel mit
  `unit: "g"` verworfen; `estimatedPriceIsAutoDerived == true`.
- **AC-5:** Ein `learnedPrices`-Eintrag **ohne** zugehörigen `learnedPriceUnits`-Eintrag wird
  nie angewendet, auch wenn Betrag und Menge plausibel sind (PO-Entscheidung 1).
- **AC-6:** `quantitySource == "none"` mit gelernter `"g"`-Rate → `estimatedPrice == 4.99/400`,
  `estimatedLineTotal == nil`, `unit == "g"`, `estimatedPriceIsAutoDerived == false`.
- **AC-7:** Eine `"g"`-Rate wird für einen Artikel mit `unit: "kg"` verworfen
  (`estimatedPriceIsAutoDerived == true`) — keine stille Umrechnung um den Faktor 1000.
- **AC-8:** `ShoppingItem.unitBucket` bildet `""`, `"Stk"`, `"Stück"`, `"st"` auf `"stk"` ab,
  `"g"`, `"mg"`, `"ml"`, `"cl"`, `"dl"` auf `"g"`, und lässt `"kg"`, `"l"`, `"el"` unverändert
  kleingeschrieben stehen.
- **AC-9:** Für jeden der fünf Zweige von `learningQuantity` liefert `learningUnit` den in der
  Tabelle unter „Implementation Details 2" genannten Wert — geprüft über dieselbe Instanz von
  `EditableReceiptLine`, nicht über eine nachgebaute Formel.
- **AC-10:** `ReceiptParserService.packageSizeFromName` liefert `("COLA 0,5L") == (500, "ml")`,
  `("SKYR NATUR 500G") == (500, "g")`, `("WEIN 75CL") == (750, "ml")`; der Zahlenwert stimmt für
  alle drei mit `weightBasisFromName` überein.
- **AC-17:** UI-Durchstich: Nach „Speichern" im Bon-Prüf-Screen enthält die Lidl-Liste am
  Artikel „Hackfleisch" **keinen** Betrag „0,01 €".
- **AC-19:** `testSavingStillWritesLearnedPriceToMatchedItem` bleibt unverändert grün — der
  Stückpreis-Pfad („Milch", 0,99 €) ist nicht betroffen.
- **AC-20:** Die gesamte Bestandssuite (Unit + UI) ist im **gemeinsamen** Lauf grün, nicht nur
  je Testklasse einzeln.

### Nach Issue #57 verschoben (PO-Entscheidung 2026-09-26)

AC-11 bis AC-16 und AC-18 beschrieben die **Mengen-Vorbelegung** und ihre Darstellung in der
Liste. Sie sind **nicht** Teil dieses Tickets mehr und stehen unverändert, mit derselben
Nummerierung, in **Issue #57**. Die Nummern bleiben hier absichtlich frei, damit Verweise aus
Kontext, Briefing und Protokollen weiter aufgehen.

**Grund für die Trennung — einer, nicht zwei:**

**Umfang.** Zwanzig Anforderungen über neun Produktdateien sind das Doppelte einer normalen
Änderung. Die Umfangsschranke des Workflows griff mitten in der Umsetzung bei „Produktiv 255/250"
(verschärft durch die Fehlzählung aus #36, die 32 Zeilen Testcode und 20 Zeilen dieser Spec-Datei
als Produktivcode wertete). Der Fehlerfix war zu diesem Zeitpunkt fertig und grün, die
Mengen-Vorbelegung noch nicht begonnen.

**Richtigstellung (2026-09-26):** Als zweiter Grund war hier zunächst „sichtbare Änderung ohne
Entwurfsvorschau" angeführt — das war **falsch**. Die Vorschau existiert:
`docs/artifacts/fix-10-preis-einheit/entwurf.html` zeigt den Ist-Zustand neben drei Entwürfen in
hell und dunkel, und der PO hat am 2026-09-26 **Variante B** gewählt (angenommene Menge sichtbar
als Annahme markiert) — genau das, was AC-14 beschreibt. Die PO-Regel vom 2026-09-22 war also
erfüllt, nicht verletzt. Der Irrtum entstand beim Zurückschneiden dieser Spec, weil der Abschnitt
„Problem und belegte Ursache" nicht mitgelesen wurde.

**Folge für #57:** Dort ist **keine** neue Entwurfsrunde nötig. Der freigegebene Entwurf und die
gewählte Variante liegen vor und gelten weiter.

**Achtung für #57 — und eine ehrliche Einschränkung:** Der Code zu AC-14 (`ItemRow`:
„ca."-Präfix, `Color.amber`, keine Mengenangabe bei `"none"`) und AC-16 (`EditItemView` setzt
`quantitySource = "user"`) ist in diesem Ticket **bereits geschrieben**, sein Verhalten in #10
aber **nicht nachgewiesen** — die vier UI-Tests, die ihn erreichen würden, sind mit AC-14 bis
AC-16 und AC-18 nach #57 gezogen. Belegt ist nur: Er compiliert und bricht keinen der 270
Bestandstests. Mehr als das darf hier nicht behauptet werden.

Erreichbar wird er erst, wenn `suggestQuantity` `quantitySource` auf `"history"` oder `"package"`
setzt. #57 ergänzt daher `suggestQuantity`, die Anbindung in `AddItemView`, AC-15 **und die
Nachweise für diesen schon vorhandenen Code**.

Er wurde bewusst stehen gelassen statt zurückgebaut: Er ist folgenlos, solange `quantitySource`
überall `"user"` bleibt, und #57 braucht ihn ohnehin. Ein Rückbau mit anschließendem Wiederaufbau
wäre Arbeit gegen Arbeit — die Alternative, ihn zu entfernen, bleibt aber offen, falls #57 lange
liegen bleibt und toter Code im Produktivzweig störender wiegt als die doppelte Arbeit.

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
  mit dokumentiertem Datenverlust. Die Entscheidung, **Stück-Synonyme und Gewichts-/Volumen-Subeinheiten
  zu je einem Eimer zusammenzufassen und jede andere Einheit literal zu erhalten** (`"kg"`, `"l"`,
  `"el"`, `"tl"`), ist durch die Normierung in `ReceiptParserService.swift:916` erzwungen: Weil dort
  `kg` und `l` auf denselben Faktor 1000 laufen, wäre eine literal genaue Trennung von Gramm und
  Milliliter vorgetäuschte Genauigkeit — sie ist in #15 auflösbar. Für alle übrigen Einheiten gibt
  es diesen Zwang nicht, deshalb bleiben sie wörtlich stehen und werden nur exakt gegeneinander
  verglichen. Beide sind hier unter „Implementation Details" und „Alternativen (verworfen)"
  begründet und durch AC1, AC5, AC7, AC8 abgesichert; ein eigenes ADR-Dokument wäre für einen
  Bugfix dieses Umfangs unverhältnismäßig.

## Expected Behavior

- Ein Bon wird gescannt und gespeichert. Für jede übernommene Position merkt sich die App neben dem
  Preis, worauf er sich bezieht — auf ein Stück oder auf ein Gramm beziehungsweise Milliliter.
- Steht am Artikel eine passende Mengenangabe, rechnet die App aus Rate und Menge den Betrag —
  400 g Hackfleisch zu 1,25 Cent je Gramm ergeben 4,99 €.
- Passt die gelernte Bezugsgröße nicht zur Einheit des Artikels, wird der gelernte Preis gar nicht
  benutzt; es erscheint die übliche Schätzung. Das gilt auch für einen Artikel ohne Mengenangabe:
  Aus einem Gewichtspreis wird dort **kein** Stückpreis mehr — der gemeldete Fehler „0,01 €".
- Gramm und Kilogramm werden nie stillschweigend ineinander umgerechnet; passt die Einheit nicht
  genau, greift die Schätzung statt eines um Faktor 1000 falschen Betrags.
- Einmalig verschwinden alle bisher gelernten Preise aus der Anzeige, weil ihnen die Bezugsgröße
  fehlt. Beim nächsten Bon-Scan werden sie mit Bezugsgröße neu gelernt.

Die **Vorbelegung** der Menge aus Kaufhistorie oder Packungsgröße und ihre Kennzeichnung in der
Liste („ca. 400 g", Rate statt Gesamtpreis) gehören zu **Issue #57** — siehe „Nach Issue #57
verschoben" unter den Acceptance Criteria.

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
- 2026-09-26: AC-Bullets von `- [ ] **AC1:**` auf `- **AC-1:**` umgestellt. Rein formal, kein Wort
  am Inhalt: `hook_utils.extract_ac_entries()` erkennt nur die zweite Form, wodurch `edit_gate.py`
  jeden Code-Edit mit „`## Acceptance Criteria` has no AC-N entries" abwies.
- 2026-09-26: **Ticket geteilt (PO-Entscheidung).** AC-11 bis AC-16 und AC-18 — die
  Mengen-Vorbelegung und ihre Darstellung in der Liste — sind nach **Issue #57** gezogen. #10
  trägt nur noch die Bezugsgröße am gelernten Preis und den Durchstich AC-17, also die Behebung
  des gemeldeten Fehlers. Grund ist der doppelte Umfang: 20 Anforderungen über neun Dateien, die
  Umfangsschranke griff mitten in der Umsetzung bei 255/250, verschärft durch #36. Verbleibender
  Umfang: 13 Anforderungen, ~203 LoC über sieben Produktdateien.
- 2026-09-26: **Nachbesserung der Teilung**, nach unabhängigem Befund des po-briefer. Zwei
  Widersprüche behoben, die die erste Bereinigung übersehen hatte: (1) Der Test Plan trug noch die
  Testdatei `AssignmentServiceQuantitySuggestionTests.swift` und vier UI-Tests für die
  verschobenen AC-14 bis AC-16 und AC-18 — wer strikt nach Test Plan umgesetzt hätte, hätte Tests
  für Anforderungen gebaut, die laut AC-Liste und Scope nicht mehr zu #10 gehören. Die
  Beschreibungen sind als Kommentar an #57 gesichert. (2) Die Aussage, der Code zu AC-14 und AC-16
  „laufe in der grünen Suite mit", behauptete mehr als belegt war: Die Tests, die ihn erreichen
  würden, sind selbst nach #57 gezogen. Belegt ist nur, dass er compiliert und keinen der 270
  Bestandstests bricht.
- 2026-09-26: **Falsche Begründung zurückgezogen.** Die Teilung war mit zwei Gründen begründet
  worden; der zweite — „sichtbare Änderung ohne Entwurfsvorschau" — war sachlich falsch. Die
  Vorschau existiert als `docs/artifacts/fix-10-preis-einheit/entwurf.html`, und der PO hat am
  2026-09-26 Variante B daraus gewählt. Der Irrtum entstand, weil beim Zurückschneiden der Spec
  der Abschnitt „Problem und belegte Ursache" nicht mitgelesen wurde, in dem die Entwurfsgrundlage
  dokumentiert ist. Es bleibt **ein** Grund für die Teilung: der Umfang. Für #57 folgt daraus, dass
  dort keine neue Entwurfsrunde nötig ist — die Korrektur ist auch an #57 kommentiert. Ebenfalls
  bereinigt: „Purpose", „Source" und „Dependencies" führten die Mengen-Vorbelegung noch als Teil
  von #10, obwohl Scope und AC-Liste sie längst nach #57 verwiesen; „Purpose" ist der Abschnitt,
  den der PO zuerst liest.
- 2026-09-26: Umfangsangabe für #57 präzisiert (Adversary-Befund F003). Die pauschale Aussage, „der
  Code zu Abschnitt 7 (`ItemRow`)" liege in #10 vor, traf nur die Mengenzeile (AC-14). Die
  Preiszelle mit der Rate „1,25 €/100 g" (AC-15) fehlt vollständig — `ItemRow` hat keinen solchen
  Fallback. Jetzt Teil für Teil aufgeführt, damit #57 den Aufwand nicht unterschätzt.
- 2026-09-26: Falsche Absolutaussage „Nur zwei Eimer, keine literalen Einheiten" an **beiden**
  Stellen berichtigt — „Implementation Details 1" und „Architektur-Entscheidung (ADR)". Richtig ist:
  Zusammengefasst werden nur Stück-Synonyme zu `"stk"` und Gewichts-/Volumen-Subeinheiten zu `"g"`;
  jede andere Einheit bleibt literal erhalten (`"kg"`, `"l"`, `"el"`, `"tl"` — `unitBucket`,
  `default: return normalized`), was AC-7 und AC-8 auch verlangen. Der Zwang zur Zusammenfassung
  gilt ausschließlich für g/ml, weil `ReceiptParserService.swift:916` `kg` und `l` auf denselben
  Faktor 1000 normiert.

  Zur Entstehung, damit sich das Muster nicht wiederholt: Die ADR-Stelle wurde erst in einer zweiten
  Runde gefunden, weil zunächst nur die gemeldete Stelle korrigiert worden war. Das war innerhalb
  dieses Tickets der **dritte** Fall derselben Art — punktuell statt über alle Vorkommen. Seither
  gilt: vor jeder Korrektur einer Formulierung erst per Suche alle Fundstellen erheben und jede
  einzeln beurteilen, statt nur die genannte anzufassen.
- 2026-09-26 (Phase 7): **AC-20 belegt, gemeinsamer Lauf grün.** RestockTests 264 Tests, 0 Fehler;
  RestockUITests 22 Tests (1 übersprungen), 0 Fehler; `TEST SUCCEEDED`, ohne Hänger oder Neustart.
  Beleg: `docs/artifacts/fix-10-preis-einheit/validation-full-suite.txt`.

  Drei vorausgegangene Anläufe scheiterten an einem Umgebungsproblem, nicht am Code: „The test
  runner hung before establishing connection" — der Test-Host wartet vergeblich auf das
  Bereitschaftssignal von `testmanagerd` und läuft nach 300 s in `xcodebuild`s Startzeitgrenze. Kein
  Absturzbericht. Bekanntes Xcode-26-Problem (Apple Developer Forums, Thread 805060). Gegenprobe:
  RestockTests allein 264/264 grün
  (`docs/artifacts/fix-10-preis-einheit/validation-unit-only.txt`). Belege der Fehlversuche:
  `validation-attempt1-runner-hang.txt`, `validation-attempt2-runner-hang-und-darkmode.txt`,
  `validation-attempt3-ui-gruen-unit-hang.txt` (alle unter demselben Ordner). Als eigenes Ticket
  erfasst: **#63** (Messreihe 3 von 4 Anläufen betroffen, Vorschlag Wrapper-Skript mit einmaliger
  Wiederholung genau dieses Falls, Alternative getrennte Suiten-Läufe).

  Im zweiten Anlauf fiel zusätzlich `testChangeEditorWorksInDarkMode` aus (Preisfeld erschien
  nicht); im dritten und vierten Anlauf auf aufgeräumter Umgebung lief er grün.

  Der Prüfbefund „AC-5 ohne Testabdeckung" aus der Phase-7-Prüfung wurde widerlegt:
  `testMigrationRepairsCorruptedStoreLearnedPrice` (`RestockTests/PriceProvenanceMigrationTests.swift:286-290`)
  prüft genau diesen Fall — ein reparierter, aber einheitenloser Preis von 2,29 €/500 g wird für
  einen 500-g-Artikel verworfen, obwohl Betrag und Menge plausibel sind.
