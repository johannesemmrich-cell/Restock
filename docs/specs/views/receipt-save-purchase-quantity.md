---
entity_id: receipt-save-purchase-quantity
type: bugfix
created: 2026-10-01
updated: 2026-10-01
status: draft
version: "1.0"
workflow: fix-54-bon-gewicht
tags: [bugfix, receipt, purchase-record, quantity, issue-54]
---

# Bon-Import: Menge und Einheit im Kaufdatensatz (Issue #54)

## Approval

- [ ] Approved

## Purpose

Beim Bon-Import legt `ReceiptScannerView.save()` für eine Position ohne Artikel-Treffer einen
`PurchaseRecord` mit `quantityAmount: line.quantity` und `unit: line.unit` an. Bei Gewichtsware
(`BANANE CHIQUITA 1,76 B` + `0,706 kg x 2,49 EUR/kg`) steht dort „1 / leer" statt „706 g"; bei
gedruckter Packungsgröße im Namen steht ein Rohtext wie `"400g"` im Einheitenfeld. Diese Spec
leitet Menge und Einheit des Datensatzes aus den Informationen ab, die die Zeile bereits trägt —
rein regelbasiert, ohne Modell —, damit Ausgabenansicht, Nachkauf-Intervallrechnung und die
Mengen-Vorbelegung (#57, Stufe „letzter Kauf") eine echte Bezugsgröße sehen. Der Zeilenpreis
(`actualPrice`, bereits der korrekte Gesamtpreis) bleibt unverändert.

Abgespalten von #10 (Umfangsgrenze).

## Source

- **File:** `SmartCart/Views/Prices/ReceiptScannerView.swift`
- **Identifier:** neu: `EditableReceiptLine.purchaseRecordQuantity` (neben `learningQuantity` /
  `learningUnit`, Zeilen 66 / 87); Aufrufstelle: `save()`, `else`-Zweig von `if let match`
  (Zeilen 741-749, `PurchaseRecord(...)` ab Zeile 742)

## Problem und Kontext

Geprüft am Code (2026-10-01):

- `save()` liest im `else`-Zweig nur `line.quantity` / `line.unit`; `weightBasis` bleibt
  ungelesen, obwohl `learningQuantity` (Z. 66) und `learningUnit` (Z. 87) es 50 Zeilen weiter oben
  bereits benutzen — zwei Wahrheiten für dieselbe Zeile.
- `weightBasis` entsteht in `ReceiptParserService` (Z. 378-379) **nur bei Einheit `kg`**
  (`wr.weight * 1000`); Flüssigkeiten kommen nur über den Namen (`packageSizeFromName`).
- `EditableReceiptLine.unit` ist laut Kommentar (Z. 20) die „Größe aus dem Namen, z. B. `1,5l`,
  `400g`", also ein Rohtext mit Zahl. Die Fixture-Zeile `BIO-HACKFLEISCH … 400G` trägt
  `quantity: 1, unit: "400g"` (`SmartCartApp.swift`, Seed `-seedReceiptReviewForUITests`). Folge:
  `ShoppingItem.unitBucket("400g")` fällt in den `default`-Zweig und bildet einen eigenen,
  unvergleichbaren Eimer; `PurchaseDay.collapse` (`unitKey`) und #57 können damit nichts anfangen.
- Die Ausgabenansicht (`PriceOverviewView.swift`, Eintragszeile) blendet die Menge aus, wenn
  `qty == 1 && unit.isEmpty` — bei Fehlerbild „1 / leer" erscheint **nichts**, nicht „1 Stück"
  (Wortlaut-Abweichung zum Issue, gleiche Wirkung).
- **Bisher nicht am echten Lauf reproduziert.** Der Fehler ist am Code belegt; der Beleg „Fehler da"
  entsteht erst im TDD-RED (siehe Gate unten).

Fehlerbilder im `else`-Zweig (kein Artikel-Treffer):

| Zeile | Datensatz heute | Soll |
|---|---|---|
| `0,706 kg x 2,49` (`weightBasis` 706) | 1 / `""` | 706 / `g` |
| `… 400G` im Namen (`unit == "400g"`) | 1 / `"400g"` | 400 / `g` |
| `… 1,5l` im Namen | 1 / `"1,5l"` | 1500 / `ml` |
| `4 x 0,39` (`quantity` 4) | 4 / `""` | 4 / `""` (unverändert) |
| nichts bekannt | 1 / `""` | 1 / `""` (unverändert) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptParserService.packageSizeFromName(_:)` (`ReceiptParserService.swift:924`) | function | Packungsgröße aus dem Namen als `(amount, unit)`, Einheit bereits `"g"` oder `"ml"` |
| `ReceiptParserService.weightBasisFromName(_:)` (`:903`) | function | Von `packageSizeFromName` genutzt; Normierung kg/l ×1000, cl ×10, dl ×100 |
| `EditableReceiptLine.learningQuantity/learningUnit` (`ReceiptScannerView.swift:66,87`) | method | Schwestermethoden (Preis-Lernen); dienen als Gegenprobe für die `weightBasis`-Fälle |
| `PurchaseRecord` (`Models/PurchaseRecord.swift`) | model | `quantityAmount: Double = 1`, `unit: String = ""` — kein Schema-Eingriff |
| `PriceOverviewView` (`Views/Prices/PriceOverviewView.swift`) | view | Anzeige der Menge im Ausgaben-Eintrag; Nachweis-Ort im UI-Durchstich |
| `PremiumService.hasPremiumAccess` | property | Ausgaben-Ansicht ist hinter Pro; im UI-Test über `-premiumForScreenshots` (DEBUG) freigeschaltet |

**Downstream:** Ausgabenansicht, `PurchaseDay.collapse` → `HabitService` (Intervallrechnung),
`ShoppingItem`-Preis-Nachrechnen, Mengen-Vorbelegung #57 (Stufe „history").

## Scope

### Affected Files

| File | Change Type | Description | LoC |
|---|---|---|---|
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | Neue Methode `purchaseRecordQuantity`; `save()` `else`-Zweig ruft sie | ca. +25/-2 |
| `SmartCart/SmartCartApp.swift` | MODIFY | Neuer DEBUG-Seed (nur Bananenzeile); bestehendes Cleanup löscht zusätzlich `PurchaseRecord`s | ca. +30 |
| `RestockTests/ReceiptSavePurchaseQuantityTests.swift` | CREATE | Unit-Tests der Methode inkl. Gegenprobe | ca. +60 |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Durchstich Speichern → Ausgaben zeigt „706 g" | ca. +35 |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der neuen Testdatei an 4 Stellen: `PBXBuildFile`, `PBXFileReference`, `PBXGroup` (RestockTests), `PBXSourcesBuildPhase` | ca. +4 |

### Estimated Changes

- Dateien: 5 (4 inhaltlich + pbxproj), LoC: ca. +150 insgesamt, Produktivcode ca. +25.
  Das Scoping-Limit (±250 LoC, 4-5 Dateien) bleibt eingehalten. Das LoC-Gate zählt Testcode als
  Produktivcode (Issue #36) — bleibt aber mit ca. +150 unter der Schwelle.

### Out of scope (Nicht-Ziele)

- **Match-Zweig (`if let match`, Z. 731-740) bleibt unberührt.** Er setzt nur `actualPrice` und
  `date` und lässt Menge/Einheit des gefundenen Datensatzes unverändert. Ob dort derselbe Fehler
  besteht (z. B. wenn der gefundene Datensatz aus einem Abhaken ohne Menge stammt), ist **nicht
  belegt** und wird hier weder behauptet noch behoben. Siehe Known Limitations.
- **Bestandsdatensätze werden nicht repariert.** Gewicht ist für alte „1 Stück"-Datensätze nicht
  rekonstruierbar.
- **Einheitsverlust kg/l im `ReceiptParserService`** (Parser normiert auf ×1000 und verwirft die
  Einheit) bleibt unverändert.
- Preislogik (`learnedPrices`, `learningQuantity`, `learningUnit`) bleibt unverändert.

## Implementation Details

### 1. Neue Methode `EditableReceiptLine.purchaseRecordQuantity`

Rückgabe: `(amount: Double, unit: String)`. Reiner Regelweg, deterministisch, in dieser
Reihenfolge (erste zutreffende Regel gewinnt):

1. `weightBasis != nil` → `(weightBasis, "g")` (Gewichtszeile `0,706 kg x 2,49` → `(706, "g")`).
2. sonst `quantity > 1` → `(quantity, "")` (Stückzahl, wie bisher).
3. sonst `ReceiptParserService.packageSizeFromName(originalName)` → `(amount, unit)` mit
   Einheit `"g"` oder `"ml"`. **Milliliter bleiben Milliliter**, es wird nicht auf Gramm
   umgerechnet. Tatsächliche Rückgabewerte (geprüft in `ReceiptParserService.swift:903-933`):
   `"…500G"` → `(500, "g")`; `"…1,5l"` → `(1500, "ml")`; `"…0,5L"` → `(500, "ml")`;
   `"…33cl"` → `(330, "ml")`; `"…1kg"` → `(1000, "g")`. Es wird der **letzte** Treffer im Namen
   verwendet.
4. sonst `(1, "")`.

Der Roh-Text `line.unit` (`"400g"`) wird für den `PurchaseRecord` **nicht mehr** verwendet.

Die Methode steht als Methode neben `learningQuantity`/`learningUnit` (Muster der Datei: Formel als
Methode, Test ruft dieselbe Methode statt sie nachzubauen). Die Regeln 1 und 2 sind deckungsgleich
mit der Reihenfolge in `learningQuantity`.

### 2. `save()` — `else`-Zweig

Der `PurchaseRecord(...)`-Aufruf (Z. 742-748) bezieht `quantityAmount` und `unit` aus
`line.purchaseRecordQuantity()`. `itemName`, `storeName`, `actualPrice: line.price` bleiben wie sie
sind.

### 3. Review-Karte: Umschalter Gramm ↔ Stück

Die Review-Karte kann zwischen Gramm und Stück umschalten (`ReceiptReviewCard`, Mengen-Modus).
Beim Umschalten auf Stück wird `weightBasis` zu `nil`, dann gilt `quantity` (Regel 2 bzw. 3/4);
beim Zurückschalten auf Gramm ist `weightBasis` wieder gesetzt (Regel 1). Die Methode liest
ausschließlich den aktuellen Zustand der Zeile und deckt beide Zustände damit ab; es ist keine
Änderung an der Karte nötig. Beide Zustände sind Acceptance Criterion (AC-6).

### 4. UI-Durchstich: DEBUG-Seed

Neuer, eigener DEBUG-Seed in `SmartCartApp.swift` (Launch-Argument
`-seedReceiptReviewWeightLineForUITests`) mit Laden „Lidl" und **nur** der Zeile
`BANANE CHIQUITA` (`weightBasis: 706`, Preis 1,76, `quantity: 1`, `unit: ""`,
`matchedItemID: nil`, kein passender Artikel/Datensatz im Laden). Bewusst **kein** Anhängen an den
bestehenden Seed `-seedReceiptReviewForUITests`: eine fünfte Zeile würde Positionszähler und
Summe in bestehenden Tests verändern (`testSectionHeaderShowsPositionsSelectedAndSum`). Zusätzlich
löst die bestehende Fixture alle vier Zeilen über `matchedItemID` auf, würde also den Match-Zweig
nehmen, nicht den `else`-Zweig.

**Cleanup (Pflicht, `tearDown()`):** `ReceiptReviewUITests.tearDown()` startet bereits mit
`-clearReceiptReviewSeedForUITests`. Dieses Cleanup löscht Läden und Artikel, **nicht** aber
`PurchaseRecord`s, die `save()` standalone einfügt. Ohne Erweiterung bliebe der Banane-Datensatz im
App-Group-Container und tauchte in anderen Tests (Ausgabenansicht) auf. Das Cleanup löscht daher
zusätzlich alle `PurchaseRecord`s.

Der Test startet mit `-premiumForScreenshots` (DEBUG-Argument, schaltet Pro frei), speichert den
Bon, öffnet die Ausgabenansicht (Toolbar-Symbol `chart.bar`), klappt den Einkauf „Lidl" auf (jeder
Einkauf ist eine `DisclosureGroup`) und erwartet den Text „706 g" in der Eintragszeile von
„BANANE CHIQUITA" (Menge wird als `"\(qtyStr) \(unit)"` mit `qtyStr` ganzzahlig gerendert).

## Expected Behavior

- **Input:** Eine Bon-Zeile im Speichern-Weg, für die kein Artikel-Treffer existiert (`else`-Zweig von
  `if let match`), mit `weightBasis`, `quantity` und `originalName`.
- **Output:** Ein neuer `PurchaseRecord` mit (Menge, Einheit) = Gewicht in `g`; sonst Stückzahl > 1 mit
  leerer Einheit; sonst gedruckte Packungsgröße aus dem Namen (`g`/`ml`); sonst (1, leer). Der Preis
  bleibt unverändert der Zeilen-Gesamtpreis.
- **Side effects:** Ausgabenansicht, Intervallrechnung (`HabitService`) und die Mengen-Vorbelegung (#57)
  sehen für künftig importierte Gewichtsware die echte Menge. Bestandsdatensätze bleiben unverändert.

## Alternativen

- **Eine Wahrheit: `learningQuantity`/`learningUnit` direkt wiederverwenden (verworfen).**
  `learningUnit` führt Flüssigkeit als `"g"` (500 ml würde „500 g") und liefert für `quantity > 1`
  `"stk"` statt leer; die Preislern-Methoden haben zudem den Match-Parameter. Eine eigene Methode
  mit sauberer Einheit ist ehrlicher. Gleichzeitig erzwingt die Gegenprobe (AC-5), dass beide
  Methoden bei `weightBasis`-Fällen übereinstimmen. Kippt keine ADR.
- **Packungsgröße aus dem Namen nicht speichern (verworfen, offene Fachfrage s. u.).** Begründung
  dafür: Gewicht ≠ gekaufte Menge („Skyr 500G" ×1 ist ein Stück). Dann gälte nur
  `weightBasis` → g, `quantity > 1` → Stück, sonst „keine Angabe".
- **Modell/KI zur Mengenableitung (verworfen).** Ohne Modell geht es, weil alle Eingaben
  (`weightBasis`, `quantity`, Regex auf dem Namen) bereits deterministisch vorliegen.

### Entscheidungspunkt für den PO: Packungsgröße aus dem Namen im Datensatz speichern?

Offene Fachfrage: Soll „Skyr Natur 500G" als „500 g" im Datensatz stehen oder als „keine Angabe"?

- **Empfehlung: speichern (500 g).** Das ist die Mengenangabe, die #57 (Stufe „letzter Kauf") für
  „zuletzt 500 g" braucht; sie ist ehrlicher als „1 Stück", und `ShoppingItem.learnedRateUsage`
  verhindert, dass daraus ein falscher Gesamtpreis wird.
- **Gegenargument:** Eine Packung von 500 g gekauft ×2 ist 1000 g Ware, aber der Datensatz sagt
  500 g (das Gewicht der Packung, nicht die Gesamtmenge). Das gilt auch bei Regel 2 nicht (dort
  gewinnt `quantity > 1` und die Packungsgröße entfällt), ist aber eine Unschärfe der Regel 3.
- Wird die Empfehlung abgelehnt, entfällt nur Regel 3 (ca. -4 LoC, AC-2 und AC-3 werden zu
  „1 / leer"); der Rest der Spec bleibt unverändert.

## Test Plan

### Unit-Tests (TDD RED) — `RestockTests/ReceiptSavePurchaseQuantityTests.swift` (neu)

Alle Tests rufen `EditableReceiptLine.purchaseRecordQuantity()` direkt auf (nicht eine Nachbildung
der Formel).

- [ ] `testWeightLineGivesGrams` (AC-1): GIVEN eine Zeile `weightBasis: 706`, Preis 1,76 WHEN
  `purchaseRecordQuantity()` THEN `(706, "g")`.
- [ ] `testPackageSizeInNameGivesGrams` (AC-2): GIVEN `originalName` „SKYR NATUR 500G", `quantity` 1,
  `weightBasis` nil, `unit` „500g" WHEN die Methode läuft THEN `(500, "g")`, nicht der Rohtext.
- [ ] `testLiterSizeInNameGivesMilliliters` (AC-3): GIVEN `originalName` „COLA 1,5L" WHEN die
  Methode läuft THEN `(1500, "ml")`.
- [ ] `testQuantityGreaterOneGivesPieces` (AC-4): GIVEN `quantity` 4 (Mengenzeile `4 x 0,39`),
  `weightBasis` nil WHEN die Methode läuft THEN `(4, "")`.
- [ ] `testNothingKnownGivesOneWithoutUnit` (AC-4b): GIVEN `quantity` 1, kein `weightBasis`,
  Name ohne Größe WHEN die Methode läuft THEN `(1, "")`.
- [ ] `testAgreesWithLearningQuantityForWeightCases` (AC-5, Gegenprobe): GIVEN dieselbe Instanz mit
  `weightBasis: 706` WHEN `purchaseRecordQuantity()` und `learningQuantity(matchQuantityAmount: nil)`
  / `learningUnit(matchUnit: nil)` aufgerufen werden THEN stimmen Menge (706) und Einheit („g")
  überein.
- [ ] `testSwitchingToPiecesFallsBackToQuantity` (AC-6): GIVEN eine Zeile mit `weightBasis: 706`
  und `quantity: 2` WHEN `weightBasis` auf `nil` gesetzt wird (Umschalter Gramm → Stück) THEN
  `(2, "")`; WHEN `weightBasis` wieder auf 706 gesetzt wird THEN `(706, "g")`.

### UI-Test — `RestockUITests/ReceiptReviewUITests.swift`

- [ ] `testSavedWeightLineShowsGramsInExpenses` (AC-7): GIVEN der Seed `-seedReceiptReviewWeightLineForUITests`
  mit `-premiumForScreenshots` WHEN der Nutzer im Review-Sheet „Speichern" tippt und die
  Ausgabenansicht öffnet (Einkauf „Lidl" aufklappen) THEN steht beim Eintrag „BANANE CHIQUITA" der
  Text „706 g". `tearDown()` räumt über das bestehende Argument (jetzt inkl. `PurchaseRecord`s) auf.

### Gate: TDD-RED am echten Weg

Der UI-Test (AC-7) und mindestens `testWeightLineGivesGrams` müssen **vor** der Implementierung
**rot** werden (UI-Test: Eintrag zeigt keine Menge bzw. nicht „706 g"). **Wird er nicht rot, ist die
Annahme falsch und der Fix wird nicht gebaut.** Das ist zugleich die Reproduktion am echten Weg
(Speichern → Ausgabenansicht), die für diesen Bug noch aussteht.

Testlauf: Einzelläufe der neuen Tests, danach gemeinsamer Lauf Unit + UI über das Schema (Sprache
`de`/`DE` aus dem Schema). Bekannte Risiken: Testrunner-Hänger (#63), kalter Start (≥ 15 s Wartezeit
einplanen).

## Acceptance Criteria

- **AC-1:** Given eine Bon-Zeile ohne Artikel-Treffer mit `weightBasis` 706 (`0,706 kg x 2,49`,
  Preis 1,76) / When `save()` einen `PurchaseRecord` anlegt / Then hat er `quantityAmount == 706`,
  `unit == "g"` und `actualPrice == 1,76`.
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testWeightLineGivesGrams`
- **AC-2:** Given eine Zeile ohne Gewichtszeile und mit `quantity == 1`, deren Name `500G` (bzw.
  `400G`) enthält / When `purchaseRecordQuantity()` / Then `(500, "g")` bzw. `(400, "g")`; der
  Rohtext `"400g"` landet nicht mehr im `unit`-Feld.
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testPackageSizeInNameGivesGrams`
- **AC-3:** Given eine Zeile ohne Gewichtszeile mit `quantity == 1`, deren Name `1,5L` enthält /
  When `purchaseRecordQuantity()` / Then `(1500, "ml")` (Milliliter bleiben Milliliter, kein
  Umrechnen auf Gramm; `0,5L` → `(500, "ml")`, `33cl` → `(330, "ml")`, `1kg` → `(1000, "g")` wie
  `packageSizeFromName` sie tatsächlich liefert).
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testLiterSizeInNameGivesMilliliters`
- **AC-4:** Given eine Zeile mit `quantity == 4` (`4 x 0,39`) und ohne `weightBasis` / When
  `purchaseRecordQuantity()` / Then `(4, "")`; Given nichts bekannt (`quantity == 1`, kein
  `weightBasis`, keine Größe im Namen) / Then `(1, "")`.
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testQuantityGreaterOneGivesPieces`
    und `::testNothingKnownGivesOneWithoutUnit`
- **AC-5:** Given dieselbe `EditableReceiptLine`-Instanz mit `weightBasis` gesetzt / When
  `purchaseRecordQuantity()` und `learningQuantity(matchQuantityAmount: nil)` /
  `learningUnit(matchUnit: nil)` aufgerufen werden / Then stimmen Menge und Einheit überein
  (Gegenprobe gegen die Schwestermethoden, nur für die `weightBasis`-Fälle).
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testAgreesWithLearningQuantityForWeightCases`
- **AC-6:** Given eine Zeile mit `weightBasis` und `quantity` 2 / When der Umschalter der
  Review-Karte `weightBasis` auf `nil` setzt (Gramm → Stück) / Then liefert die Methode `(2, "")`;
  wird `weightBasis` wieder gesetzt, `(706, "g")`.
  - Test: `RestockTests/ReceiptSavePurchaseQuantityTests.swift::testSwitchingToPiecesFallsBackToQuantity`
- **AC-7 (UI-Durchstich):** Given der Seed mit BANANE CHIQUITA (`weightBasis` 706, Preis 1,76, kein
  Artikel-Treffer) / When der Nutzer den Bon speichert und die Ausgabenansicht öffnet und den
  Einkauf aufklappt / Then zeigt der Eintrag „BANANE CHIQUITA" die Menge „706 g" und den Preis
  1,76 €.
  - Test: `RestockUITests/ReceiptReviewUITests.swift::testSavedWeightLineShowsGramsInExpenses`
- **AC-8 (Gate):** Der Test aus AC-7 (und AC-1) ist vor der Implementierung nachweislich rot
  (TDD-RED am echten Weg), nach der Implementierung grün; wird er nicht rot, wird nicht gefixt.
- **AC-9 (Regression):** Der Match-Zweig und die Preislogik sind unverändert: die Bestandstests
  `ReceiptParserPriceTests` (Bananen-Fall `0,706 kg x 2,49`) und die gesamte
  `ReceiptReviewUITests`-Klasse bleiben im gemeinsamen Lauf grün.
  - Test: `RestockTests/ReceiptParserPriceTests.swift` (Bestand) und
    `RestockUITests/ReceiptReviewUITests.swift` (Bestand)

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion oben ist durch einen automatischen Test belegt, im gemeinsamen
      Lauf grün; der RED-Lauf der Tests aus AC-7/AC-1 ist dokumentiert.
- [ ] Die App wurde mit dem geänderten Stand im Simulator durchgespielt: Bon mit Bananenzeile
      importieren, in der Ausgabenansicht „706 g" tatsächlich sehen.
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Unit + UI im gemeinsamen Lauf grün,
      Seed-Aufräumen verifiziert).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — im Projekt existiert kein ADR-Verzeichnis (`docs/adr/` fehlt).
- **Rationale:** Kleine, lokale Korrektur am Schreibweg; die Ableitung wird als Methode neben den
  Schwestermethoden (`learningQuantity`/`learningUnit`) gebaut, dem bestehenden Muster der Datei
  folgend. Kein Schema-Eingriff (CloudKit-additiv nicht betroffen), kein neues Modell, keine neue
  Abhängigkeit. Das Datenmodell und die Einheitenbehandlung (Gramm/Milliliter getrennt) folgen den
  Entscheidungen aus #10.

## Known Limitations

- **Match-Zweig nicht abgedeckt.** Findet `save()` einen vorhandenen Datensatz (`ownUnpricedRecord`
  oder `looseMatch`), behält dieser seine Menge/Einheit. Ob ein dort angetroffener „1 / leer"-Wert
  denselben Fehler darstellt, ist nicht belegt; falls doch, wäre das ein eigenes Ticket (dann
  anlegen, nicht hier mitreparieren).
- **Bestandsdatensätze** bleiben „1 / leer" bzw. mit Roh-Einheit wie `"400g"`.
- **Kilogramm/Liter-Einheitsverlust im Parser** bleibt (`weightBasis` kennt nur Gramm); für
  `weightBasis` unkritisch, da der Parser es nur für `kg` setzt.
- **Multipack mit Größe im Namen** (`quantity > 1`, z. B. „6X1,5L"): Regel 2 gewinnt, der Datensatz
  trägt die Stückzahl ohne Einheit; die Größe aus dem Namen entfällt.
- **Packungsgröße ≠ gekaufte Gesamtmenge** bei Regel 3 (siehe Entscheidungspunkt).
- **Intervallrechnung ändert sich** für künftig importierte Gewichtsware (`HabitService` rechnet
  mit Gramm statt Stück); Bestandsdaten und neue Daten mischen sich in den Intervallen, unterschiedliche
  Einheiten werden von `PurchaseDay.collapse` nicht addiert („der spätere Kauf gilt").

## Changelog

- 2026-10-01: Initial spec created (Issue #54, Workflow fix-54-bon-gewicht)
