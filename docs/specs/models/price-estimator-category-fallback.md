---
entity_id: price-estimator-category-fallback
type: module
created: 2026-09-25
updated: 2026-09-25
status: draft
version: "1.0"
tags: [pricing, models, issue-12]
---

# PriceEstimator — Kategorie-Pauschalpreise

## Approval

- [ ] Approved

## Purpose

`PriceEstimator.estimate` schätzt einen Pauschalpreis pro kg/Liter/Stück, wenn für einen
Artikel weder ein gelernter Preis noch ein Treffer in `specificPrices` vorliegt. Der
Kategorie-`switch` (26 Kategorien) lieferte bisher an mehreren Stellen exakt denselben Wert
für unterschiedliche Kategorien (am auffälligsten: "Obst & Gemüse" und "Lebensmittel", beide
2,50 €) — dieser Entity-Spec differenziert alle 26 Werte, sodass keine zwei Kategorien mehr
kollidieren.

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `enum PriceEstimator`, `switch category` (Zeilen 302–329)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `AssignmentService.categoryOrder` (`AssignmentService+Category.swift:219-225`) | Referenz | Maßgebliche Liste der 26 Kategorienamen (String-exakt) — unverändert, nur Lesezugriff |
| `ShoppingItem.init` | Aufrufer | Fallback wenn kein gelernter Preis vorliegt — Signatur unverändert |
| `EditItemView.swift:375,384` | Aufrufer | Neuschätzung beim manuellen Bearbeiten — Signatur unverändert |

## Scope

- **Affected Files:** `SmartCart/Models/ShoppingItem.swift` (einzige Datei)
- **Estimated Changes:** ~12 LoC (12 von 26 `case`-Zeilen im bestehenden `switch` bekommen einen
  neuen Zahlenwert; kein neuer Code, keine neue Struktur, keine Signaturänderung)

Keine Testdatei-Änderung nötig: `grep` über `RestockTests/` und `RestockUITests/` nach allen
12 geänderten Kategorienamen (`category: "..."`) ergab keine Treffer — die bestehende
Testsuite referenziert ausschließlich unveränderte Kategorien (`Milchprodukte`,
`Fleisch & Wurst`).

## Implementation Details

Root Cause: der `switch`-Block ordnete mehreren Kategorien denselben Literal-Wert zu
(4 Kollisionsgruppen zu je 2–4 Kategorien plus das im Ticket genannte Paar). PO-Entscheidung
(siehe `docs/context/feat-12-destatis-preise.md`, 2026-09-25): Alternative 1 — nur das Symptom
beheben, keine "amtliche" Quelle behaupten. Fix: pro Kollisionsgruppe bleibt ein Wert als Anker
unverändert, die übrigen Werte der Gruppe werden auf einen plausiblen, aber abweichenden
Pauschalpreis gesetzt. `specificPrices` (Zeilen 251–284) bleibt unangetastet.

Vollständiger neuer `switch`-Block (ersetzt Zeilen 302–329 1:1, nur die markierten Werte ändern
sich):

```swift
switch category {
case "Obst & Gemüse": perUnit = 2.50 / divisor
case "Fleisch & Wurst": perUnit = 4.50 / divisor
case "Milchprodukte": perUnit = 2.00 / divisor
case "Backwaren": perUnit = 2.20 / divisor              // geändert, war 2.00
case "Getränke": perUnit = 1.50 / divisor
case "Tiefkühlkost": perUnit = 3.50 / divisor
case "Snacks": perUnit = 1.80 / divisor
case "Gewürze & Backen": perUnit = 3.20 / divisor       // geändert, war 2.00
case "Konserven": perUnit = 1.70 / divisor              // geändert, war 2.00
case "Lebensmittel": perUnit = 2.90 / divisor           // geändert, war 2.50
case "Körperpflege": perUnit = 4.00 / divisor
case "Reinigung": perUnit = 3.90 / divisor              // geändert, war 3.50
case "Medikamente": perUnit = 6.00 / divisor
case "Babybedarf": perUnit = 8.00 / divisor
case "Haushaltswaren": perUnit = 5.00 / divisor
case "Küchenausstattung": perUnit = 9.50 / divisor      // geändert, war 8.00
case "Elektronik": perUnit = 14.00 / divisor            // geändert, war 10.00
case "Textilien": perUnit = 7.00 / divisor              // geändert, war 8.00
case "Schreibwaren": perUnit = 3.00 / divisor
case "Spielzeug": perUnit = 10.00 / divisor
case "Dekoration": perUnit = 6.50 / divisor             // geändert, war 6.00
case "Werkzeug": perUnit = 12.00 / divisor
case "Garten": perUnit = 7.50 / divisor                 // geändert, war 8.00
case "Farbe & Lack": perUnit = 15.00 / divisor
case "Sanitär": perUnit = 11.50 / divisor               // geändert, war 10.00
case "Baumaterial": perUnit = 13.50 / divisor           // geändert, war 12.00
default: perUnit = nil
}
```

Aufgelöste Kollisionsgruppen (Anker unverändert, übrige Werte der Gruppe angepasst):

| Gruppe (vorher identisch) | Anker (unverändert) | Neue Werte |
|---|---|---|
| Obst & Gemüse / Lebensmittel (2,50 €) | Obst & Gemüse: 2,50 € | Lebensmittel: 2,90 € |
| Milchprodukte / Backwaren / Gewürze & Backen / Konserven (2,00 €) | Milchprodukte: 2,00 € | Backwaren: 2,20 €, Gewürze & Backen: 3,20 €, Konserven: 1,70 € |
| Tiefkühlkost / Reinigung (3,50 €) | Tiefkühlkost: 3,50 € | Reinigung: 3,90 € |
| Medikamente / Dekoration (6,00 €) | Medikamente: 6,00 € | Dekoration: 6,50 € |
| Babybedarf / Küchenausstattung / Textilien / Garten (8,00 €) | Babybedarf: 8,00 € | Küchenausstattung: 9,50 €, Textilien: 7,00 €, Garten: 7,50 € |
| Elektronik / Spielzeug / Sanitär (10,00 €) | Spielzeug: 10,00 € | Elektronik: 14,00 €, Sanitär: 11,50 € |
| Werkzeug / Baumaterial (12,00 €) | Werkzeug: 12,00 € | Baumaterial: 13,50 € |

## Expected Behavior

- **Input:** `category` (einer der 26 Namen aus `AssignmentService.categoryOrder`), `unit`,
  `quantityAmount` — unverändert gegenüber heute.
- **Output:** `Double?` Pauschalpreis pro Einheit — unverändert in Mechanik (`unitDivisor`,
  `maxPlausibleLineTotal`-Kappung), nur die 12 Konstanten oben ändern sich. Alle 26
  Kategorie-Werte sind danach paarweise verschieden.
- **Side effects:** keine.

## Known Limitations

- Die neuen Werte sind weiterhin Entwickler-Schätzwerte, keine amtlichen/datierten Preise —
  die im Ticket ursprünglich gewünschte Destatis-Anbindung wurde recherchiert und
  zurückgestellt (siehe `docs/context/feat-12-destatis-preise.md`, Alternativen 2–4: Destatis
  führt für praktisch keine der 26 Kategorien einen aktuell gepflegten Euro-Durchschnittspreis,
  nur einen Index).
- Keine Quellenangabe/Namensnennung in `LegalView.swift` nötig, da keine externen Daten
  verwendet werden.
- `specificPrices` (32 Produkt-Keywords) bleibt außerhalb des Scopes — dort können weiterhin
  mehrere Keywords denselben Preis teilen (kein gemeldetes Symptom für diese Liste).

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt
- [ ] Kein Paar der 26 Kategorie-Pauschalpreise liefert mehr denselben Wert
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün — insbesondere
      `PriceProvenanceMigrationTests` und `ReceiptParserPriceTests`, die unveränderte
      Kategorien wie "Milchprodukte"/"Fleisch & Wurst" verwenden)

## Acceptance Criteria

- **AC-1:** Given die 26 Kategorie-Zweige in `PriceEstimator.estimate` / When ihre Preise
  (unit="", quantityAmount=1) für alle 26 Namen aus `AssignmentService.categoryOrder`
  eingesammelt werden / Then sind alle 26 Werte paarweise verschieden.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-2:** Given category "Obst & Gemüse" und category "Lebensmittel" / When
  `PriceEstimator.estimate` für beide mit unit="", quantityAmount=1 aufgerufen wird / Then
  liefert "Obst & Gemüse" 2,50 € und "Lebensmittel" 2,90 € — unterschiedlich (das im Ticket
  genannte Symptom).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-3:** Given die vier vormals identischen Kategorien "Milchprodukte", "Backwaren",
  "Gewürze & Backen", "Konserven" / When gleich abgefragt / Then liefern sie 2,00 € / 2,20 € /
  3,20 € / 1,70 € — alle vier verschieden.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-4:** Given die vier vormals identischen Kategorien "Babybedarf", "Küchenausstattung",
  "Textilien", "Garten" / When gleich abgefragt / Then liefern sie 8,00 € / 9,50 € / 7,00 € /
  7,50 € — alle vier verschieden.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-5:** Given die drei vormals identischen Kategorien "Elektronik", "Spielzeug", "Sanitär"
  / When gleich abgefragt / Then liefern sie 14,00 € / 10,00 € / 11,50 € — alle drei
  verschieden.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-6:** Given die Paare "Tiefkühlkost"/"Reinigung", "Medikamente"/"Dekoration",
  "Werkzeug"/"Baumaterial" / When gleich abgefragt / Then unterscheidet sich jedes Paar
  (3,50 €/3,90 €, 6,00 €/6,50 €, 12,00 €/13,50 €).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-7:** Given ein Artikelname, der eines der 32 `specificPrices`-Keywords trifft (z. B.
  "Milch") / When `PriceEstimator.estimate` aufgerufen wird / Then bleibt der zurückgegebene
  Preis unverändert gegenüber heute (Regression: `specificPrices` bleibt außerhalb des Scopes).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-8:** Given eine Kategorie, die nicht in `AssignmentService.categoryOrder` vorkommt /
  When `PriceEstimator.estimate` aufgerufen wird / Then liefert die Funktion weiterhin `nil`
  (Verhalten des `default`-Falls unverändert).
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*

## Test Plan

Automatische Tests (jeweils an eine AC oben gebunden), neue Datei
`RestockTests/PriceEstimatorCategoryFallbackTests.swift`:
- `testAllCategoryFallbackPricesAreDistinct()` — AC-1
- `testObstUndGemueseDiffersFromLebensmittel()` — AC-2
- `testMilchproduktGruppeIstDifferenziert()` — AC-3
- `testBabybedarfGruppeIstDifferenziert()` — AC-4
- `testElektronikGruppeIstDifferenziert()` — AC-5
- `testVerbleibendePaareSindDifferenziert()` — AC-6
- `testSpecificPricesBleibenUnveraendert()` — AC-7
- `testUnbekannteKategorieLiefertNil()` — AC-8

Bestehende Suiten laufen unverändert mit (Regression, keine Anpassung nötig):
- `RestockTests/PriceProvenanceMigrationTests.swift`
- `RestockTests/ReceiptParserPriceTests.swift`

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Wertänderung innerhalb einer bestehenden Funktion, keine
  Architekturänderung. Die zugrundeliegende Produktentscheidung (Destatis-Ansatz
  zurückgestellt zugunsten von Alternative 1) ist in `docs/context/feat-12-destatis-preise.md`
  dokumentiert (PO-Entscheidung 2026-09-25).

## Changelog

- 2026-09-25: Initial spec created
