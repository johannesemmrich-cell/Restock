---
entity_id: price-estimator-stages
type: module
created: 2026-09-25
updated: 2026-09-25
status: draft
version: "1.0"
tags: [pricing, models, issue-13]
---

# Preisermittlung — Stufenmodell (Dokumentation, Status quo)

## Approval

- [ ] Approved

## Purpose

`ShoppingItem.init` ermittelt heute schon nach einem impliziten Drei-Stufen-Modell einen
Artikelpreis, ohne dass dieses Modell irgendwo dokumentiert oder mit einer Spec belegt ist:

1. **Gelernter Preis** (`Store.learnedPrices`, fuzzy-Match auf den Artikelnamen) — kommt aus
   einem gescannten Bon (`ReceiptScannerView`) oder einer manuellen Preiseingabe
   (`ActualPriceEntryView`).
2. **Produkt-Keyword** (`PriceEstimator.estimate` → `specificPrices`, 32 Einträge).
3. **Kategorie-Pauschale** (`PriceEstimator.estimate` → `switch category`, dokumentiert in
   [`price-estimator-category-fallback.md`](price-estimator-category-fallback.md)).

**Diese Spec ändert nichts am Verhalten.** Sie macht das bestehende Modell erstmals explizit und
sichert die Stufenreihenfolge mit Charakterisierungstests gegen stillen Drift ab.

### Warum keine Veraltungsregel (mehr) in diesem Ticket

Eine frühere Fassung dieser Spec sah zusätzlich vor, einen gelernten Preis nach 180 Tagen zu
verwerfen und auf Stufe 2/3 zurückzufallen. PO-Einwand (Henning, 2026-09-25, siehe
`docs/context/feat-13-preismodell-stufen.md`): eine generische Produkt-Keyword- oder
Kategorie-Pauschale hat keinerlei Bezug zu Laden oder Artikel — es ist unklar, ob sie wirklich
näher an der Realität liegt als ein 6 Monate alter, aber echter, laden- und artikelspezifischer
Preis. Der Rückfall ergibt erst Sinn, sobald eine tatsächlich bessere Quelle existiert. Das ist
**Open Prices (#49)**, nicht die heutige Pauschale. Die Veraltungsregel wandert deshalb komplett
nach #49, wo "veraltet" gegen einen echten, aktuelleren Marktpreis fällt statt gegen eine grobe
Schätzung. #13 liefert dafür die hier dokumentierte, unveränderte Grundlage.

## Source

- **File:** `SmartCart/Models/ShoppingItem.swift`
- **Identifier:** `ShoppingItem.init` (Zeilen 112–155), `enum PriceEstimator` (ab Zeile 204)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Store.learnedPrices` / `Store.learnedPriceDates` (`Store.swift:27,32`) | Datenquelle | Gelernter Preis pro Artikel-Key; nur Lesezugriff, unverändert |
| `ShoppingItem.init` | Referenz | Bestehende Stufenreihenfolge, unverändert |
| `PriceEstimator.estimate` | Referenz | Stufe 2/3, Signatur und Werte unverändert |
| `EditItemView.swift:375,384` | Referenz | Ruft `PriceEstimator.estimate` direkt auf, durchläuft Stufe 1 grundsätzlich nie — unverändert, außerhalb des Scopes |
| [`price-estimator-category-fallback.md`](price-estimator-category-fallback.md) | Referenz | Unterste Stufe (Kategorie-Pauschale) bleibt inhaltlich unverändert, wird hier nur eingeordnet |

## Scope

- **Affected Files:**
  - `docs/specs/models/price-estimator-stages.md` (diese Datei — reine Dokumentation)
  - `RestockTests/PriceEstimatorStagesTests.swift` (neu — Charakterisierungstests)
- **Kein Produktivcode wird geändert.** `SmartCart/Models/ShoppingItem.swift` bleibt unangetastet.
- **Estimated Changes:** 0 LoC Produktivcode, ~40–60 LoC neue Tests.
- Kein Netzwerkzugriff, keine Architekturänderung, keine Signaturänderung, keine
  Schema-Änderung.

## Implementation Details

Keine. Diese Spec dokumentiert ausschließlich den heutigen Code:

```swift
// ShoppingItem.init, vereinfacht:
let learnedPrice = /* fuzzy Match gegen store.learnedPrices, siehe Zeilen 127-153 */
self.estimatedPrice = learnedPrice ?? PriceEstimator.estimate(for: name, category: category, unit: unit, quantityAmount: quantityAmount)
self.estimatedPriceIsAutoDerived = (learnedPrice == nil)

// PriceEstimator.estimate, vereinfacht:
// 1. specificPrices (32 Produkt-Keywords) — erster Treffer gewinnt
// 2. switch category (26 Kategorie-Pauschalen)
// 3. sonst nil
```

Die einzige "Aktion" dieses Tickets ist das Anlegen von Charakterisierungstests, die diese
Reihenfolge explizit durch Assertions belegen — heute schon grün, ohne jede Codeänderung.

## Expected Behavior

- **Input:** `name`, `category`, `quantityAmount`, `unit`, `store` (optional) an
  `ShoppingItem.init` — unverändert.
- **Output:** `estimatedPrice` (Double?), `estimatedPriceIsAutoDerived` (Bool) — unverändert.
- **Side effects:** keine.
- **Rangfolge (dokumentiert, nicht verändert):** gelernter Preis (Stufe 1) schlägt
  Produkt-Keyword (Stufe 2) schlägt Kategorie-Pauschale (Stufe 3) schlägt `nil`.

## Known Limitations

- Gelernte Preise werden unabhängig von ihrem Alter verwendet — keine Veraltungsprüfung. Das ist
  in diesem Ticket bewusst so belassen (siehe "Warum keine Veraltungsregel" oben), nicht
  vergessen.
- Eine vierte Stufe (Open Prices) ist bewusst **nicht** Teil dieser Spec — siehe Issue **#49**,
  das auch die Veraltungsregel für Stufe 1 mitbringt.
- Die manuelle Neuschätzung in `EditItemView.swift` (Zeilen 375/384) durchläuft Stufe 1
  grundsätzlich nicht — unverändert, außerhalb des Scopes.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt
- [ ] Kein Produktivcode wurde geändert (reiner Doku- + Test-Commit)
- [ ] Die bestehende Testsuite läuft unverändert grün (reine Ergänzung, keine Regression möglich)

## Acceptance Criteria

- **AC-1:** Given ein `Store`, dessen `learnedPrices` einen fuzzy zum Artikelnamen passenden
  Eintrag enthält, UND der Artikelname zusätzlich ein `specificPrices`-Keyword träfe / When ein
  `ShoppingItem` mit diesem Namen und Store angelegt wird / Then gewinnt der gelernte Preis
  (Stufe 1 vor Stufe 2), `estimatedPriceIsAutoDerived == false`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-2:** Given kein Store bzw. kein fuzzy passender gelernter Preis, UND der Artikelname
  trifft ein `specificPrices`-Keyword / When ein `ShoppingItem` angelegt wird / Then wird der
  Produkt-Keyword-Preis verwendet, nicht die Kategorie-Pauschale (Stufe 2 vor Stufe 3),
  `estimatedPriceIsAutoDerived == true`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*
- **AC-3:** Given kein Store, kein Keyword-Treffer, aber eine bekannte Kategorie / When ein
  `ShoppingItem` angelegt wird / Then wird die Kategorie-Pauschale verwendet (Stufe 3),
  `estimatedPriceIsAutoDerived == true`.
  - Test: *(wird nach der TDD-RED-Phase eingetragen)*

## Test Plan

Automatische Tests (jeweils an eine AC oben gebunden), neue Datei
`RestockTests/PriceEstimatorStagesTests.swift`:
- `testLearnedPriceTakesPriorityOverProductKeywordAndCategory()` — AC-1
- `testProductKeywordTakesPriorityOverCategoryFallback()` — AC-2
- `testCategoryFallbackUsedWhenNoLearnedPriceAndNoKeywordMatch()` — AC-3

Bereits abgedeckt durch bestehende Suiten (kein neuer Test nötig, keine Duplizierung):
- Deterministischer Tie-Breaker bei mehreren fuzzy-Treffern ohne Datum:
  `PriceProvenanceMigrationTests.testShoppingItemPicksDeterministicWinnerWhenMultipleLearnedPricesMatchWithoutDates`
- Unbekannte Kategorie → `nil`: `PriceEstimatorCategoryFallbackTests.testUnbekannteKategorieLiefertNil`

Bestehende Suiten laufen unverändert mit (Regression, keine Anpassung nötig):
- `RestockTests/PriceProvenanceMigrationTests.swift`
- `RestockTests/PriceEstimatorCategoryFallbackTests.swift`
- `RestockTests/ReceiptParserPriceTests.swift`

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Dokumentation bestehenden Verhaltens plus Charakterisierungstests, keine
  Codeänderung, kein Architekturbruch. Die Entscheidung, die Veraltungsregel nach #49 zu
  verschieben, ist in `docs/context/feat-13-preismodell-stufen.md` dokumentiert (PO-Entscheidung
  2026-09-25, nach Einwand gegen den ursprünglichen Ansatz).

## Changelog

- 2026-09-25: Initial spec created (inkl. Veraltungsregel)
- 2026-09-25: Veraltungsregel nach PO-Einwand entfernt und auf #49 verschoben — Spec auf reine
  Dokumentation reduziert
