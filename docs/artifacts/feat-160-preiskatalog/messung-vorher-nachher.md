# Preiskatalog (Issues #160–#162): Messung vorher → nachher, nachrechenbar

Stand 2026-10-19. Anlass: PO-Frage „Hast du gute Vorher-Nachher-Tests geschrieben und das Ergebnis
gesichert?“ Die Zahlen der Spec (`docs/specs/models/price-catalog-honest-estimate.md`) stammten aus
einem einmaligen Skript vom 2026-10-18, das nicht abgelegt wurde. Seit diesem Nachtrag rechnet die
Unit-Test-Suite beide Seiten bei jedem CI-Lauf nach.

## Methode

- **Vorher** = Verhalten von `specificPrices` vor #160: 32 Altstichwörter (heute unverändert als
  `PriceCatalog.legacy`), Treffer als Teilstring irgendwo im Namen (`nameLower.contains(key)`).
  Im Test: `PriceCatalogTests.legacySubstringHit(_:)`.
- **Nachher** = `PriceCatalog.match(_:)` (Wortgrenzen bzw. Grundwort eines Kompositums, längster Name
  gewinnt) über den ganzen Katalog.
- **Messmengen**: (a) die eindeutigen Lebensmittel-Stichwörter aus `AssignmentService.categoryMap`
  (dafür aus `category(for:)` als `static let` herausgezogen, Inhalt unverändert); (b) die 100
  Alltagsartikel `PriceCatalogTests.commonGroceries`; (c) fünf Namen, die vorher ein Altstichwort
  als Teilstring trafen (Tomatenmark, Teelicht, Wassermelone, Eierlikör, Brotmesser).

Tests: `testCategoryKeywordCoverageBeforeAndAfter`, `testCommonGroceriesCoverageBeforeAndAfter`,
`testSubstringFalsePositivesExistedBefore` (vorher) und `testWordBoundaryPreventsFalseSubstringMatches`
(nachher) in `RestockTests/PriceCatalogTests.swift`. Die Werte sind als exakte Erwartungen
festgehalten; wer den Katalog oder die Stichwörter ändert, passt sie bewusst an. Zusätzlich hält
ein Mindestwert (≥ 69 % der Stichwörter) die Abdeckung, falls jemand nur die Zahl nachzieht.

## Ergebnis

| Maß | vorher | nachher | Quelle |
|---|---|---|---|
| Lebensmittel-Stichwörter mit Produktpreis (556 eindeutige) | 114 (20,5 %) | 385 (69,2 %) | Test (a) |
| 100 Alltagsartikel mit Produktpreis | 39 | 100 | Test (b) |
| Teilstring-Fehltreffer (5 Namen) | 5 | 0 | Tests (c) |

## Abweichungen zur Spec, ehrlich

- Die Spec nannte „565 Stichwörter, 111 (20 %)“. 565 ist die Zahl der Einträge **mit** Dubletten
  (z. B. „salat“ steht zweimal), eindeutig sind es 556; mit Teilstring-Treffer der 32 Altstichwörter
  sind es 114, nicht 111. Der Unterschied liegt im verlorenen Skript (vermutlich Zählung ohne die
  englischen Altnamen). Maßgeblich ist ab jetzt der Test.
- Der Nachher-Wert „394 (70 %)“ stammte aus einer Python-Nachbildung der Swift-Logik vom
  2026-10-18. Der Swift-Test misst **385 (69,2 %)**: Die Nachbildung war beim Treffer an Wortgrenzen
  bzw. Komposita um neun Stichwörter großzügiger als `PriceCatalog.match`. Maßgeblich ist der Test;
  die Spec-Aussage „70 %“ wird zu „69 %“.

## Läufe

- 2026-10-19, PR #172, CI-Lauf 244 (`0c468f6`): 556 eindeutige Stichwörter, vorher 114, nachher **385** (Pin 394 aus der Nachbildung war falsch, korrigiert); Alltagsartikel 39 → 100 bestätigt; fünf Fehltreffer vorher bestätigt. Übrige 588 Unit-Tests grün.
