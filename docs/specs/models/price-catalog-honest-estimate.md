---
entity_id: price-catalog-honest-estimate
type: module
created: 2026-10-18
updated: 2026-10-18
status: draft
version: "1.0"
tags: [pricing, models, issue-160, issue-161, issue-162]
---

# Preisschätzung: Katalog, Wortgrenzen, Pauschale ohne Betrag, eigener Preis aus anderem Laden

## Approval

- [ ] Approved

## Purpose

Screenshot vom 2026-10-18: fünf Milchprodukte mit „ca. 2,00 € · Schätzung“ untereinander. Ursache:
32 Stichwörter per Teilstring, sonst Kategorie-Pauschale (20 % der app-eigenen Lebensmittel-
Stichwörter trafen einen Produktpreis). Diese Spec setzt die Schritte 1–3 aus dem Intake
`docs/context/feat-preisschaetzung-vertrauen.intake.md` um.

## Source

- `SmartCart/Models/PriceCatalog.swift` — `PriceCatalogEntry`, `PriceCatalog.match`, `perUnitPrice`, Einträge
- `SmartCart/Models/ShoppingItem.swift` — `ShoppingItem.init` (Stufen), `resolveOtherStorePrice`,
  `priceOrigin`/`priceSourceDetail`, `PriceSourceDisplay.showsPrompt`, `PriceEstimator.resolve`/`categoryFlatRate`
- `SmartCart/Models/LegacyLearnedPriceReset.swift` — `CatalogEstimateRefresh` (einmalig, Flag `priceCatalogRefreshV1Applied`)
- `SmartCart/Views/Components/ItemRow.swift`, `StoreDetailView.swift`, `PriceOverviewView.swift`

## Stufen (Reihenfolge in `ShoppingItem.init`)

| Stufe | Quelle `priceSource` | Anzeige in der Zeile | `estimatedPriceIsAutoDerived` |
|---|---|---|---|
| gelernter Preis dieses Ladens | `receipt`/`paid`/`learned` | Betrag + Quelle | false |
| eigener Preis aus anderem Laden (#161) | `otherStore:<Ladenname>` (`priceOrigin` = `otherStore`) | Betrag + „zuletzt bei Lidl“ | false |
| Katalogtreffer (#162) | `estimate` | „ca. Betrag“ + „Schätzung“ (Warnfarbe) | true |
| Kategorie-Pauschale (#160) | `category` | **„Preis?“** (kein Betrag), zählt nur in Summen | true |
| nichts | `estimate` ohne Preis | „Preis?“ | true |

Die Stufe „anderer Laden“ bekommt die Läden über den neuen Parameter `otherStores` (Quick-Add in
`HomeView`, `AddItemView`, Quick-Add in `StoreDetailView`); Siri, Widget, Sync, Menüplan und
Rezeptimport übergeben nichts und bleiben beim Katalog. Dieselbe Entscheidungstabelle wie im eigenen
Laden (`learnedRateUsage`, Obergrenze 200 €); jüngstes `learnedPriceDates` gewinnt, bei Gleichstand
der alphabetisch kleinere Ladenname.

## Treffer-Regel des Katalogs

- Wörter = Buchstabenfolgen des kleingeschriebenen Namens; Ziffern, Satzzeichen, Bindestriche trennen.
- Ein Name trifft als ganzes Wort oder als Grundwort eines Kompositums (Name ≥ 4 Zeichen,
  Bestimmungswort ≥ 3 Zeichen: „Laugenbrötchen“ → „brötchen“, nicht „Tomatenmark“ → „tomaten“).
- Mehrwortige Namen müssen als Wortfolge vorkommen („saure sahne“).
- Längster Name gewinnt („Hafermilch“ vor „Milch“, „Knoblauch“ vor „Lauch“).

## Umrechnung

`estimatedPrice` bleibt eine Rate je Einheit. Stück/Packung → `typical`; Gewicht/Volumen →
`typical / Packungsgramm × Gramm je Einheit`. `"stk"`-Einträge (die 32 Altstichwörter) gelten auf
Gewicht angewendet weiter als Preis je kg/l, bitgleich zum früheren `unitDivisor`. Die Obergrenze
`maxPlausibleLineTotal` (30 €) gilt unverändert.

## Summen

`StoreDetailView.totalCaption/totalText`, `PriceOverviewView.budgetCaption/budgetText`: „ca.“ vor
dem Betrag und „3 von 6 geschätzt“, sobald Katalog oder Pauschale mitzählen. Das Widget zeigt
bereits „≈“ und bleibt unverändert.

## Messung (Vorher → Nachher)

| Maß | vorher | nachher |
|---|---|---|
| 100 Alltagsartikel (`PriceCatalogTests.commonGroceries`) mit Produktpreis | 39 | 100 |
| 565 Lebensmittel-Stichwörter aus `AssignmentService.category(for:)` mit Produktpreis | 111 (20 %) | 394 (70 %) |
| Screenshot-Artikel mit „2,00 €“ | 5 von 6 | 0 |
| Teilstring-Fehltreffer (Tomatenmark, Teelicht, Wassermelone, Eierlikör, Brotmesser) | 5 | 0 |
| Katalogeinträge / Namen | 32 / 85 | 308 / 805 |

Die Katalogwerte sind handgepflegte Regalpreise (Quelle `hand-2026-10` je Eintrag); der Median aus
dem Open-Prices-Datensatz Deutschland (ODbL) ist als zweite Quelle in #162 beschrieben, aber noch
nicht eingebaut (Host aus der Cloud-Umgebung gesperrt).

## Tests

`RestockTests/PriceCatalogTests.swift` (Screenshot-Artikel, Wortgrenzen, Kompositum, längster Name,
Altwerte, Packung/Spanne, Konsistenz, Abdeckung 100/100, Pauschale → „Preis?“, Summen-Text,
Lokalisierung, anderer Laden inkl. Entscheidungstabelle/Obergrenze/Gleichstand, Auffrischung).
Bestehende Tests unverändert grün erwartet: `PriceSourceTests`, `PriceEstimatorStagesTests`,
`PriceEstimatorCategoryFallbackTests`, `LegacyLearnedPriceResetTests`, `PriceProvenanceMigrationTests`.

## Offene Grenzen

- Nichts auf Hennings Geräten geprüft; Nachweis über die CI-Läufe des PR.
- Katalog ohne regionale Unterschiede, ohne Marken, ohne Bio-Aufschlag; Open-Prices-Median fehlt (#162).
- „Preis?“ ist nur Text in der Zeile; der Tipp auf die Zeile öffnet wie bisher den Bearbeiten-Dialog.
- `CatalogEstimateRefresh` läuft nur in der App, nicht in Erweiterungen; neue Artikel sind dort über
  `init` ohnehin richtig.
- Community-Preise (#163) und KI-Stufe (#164) nicht Teil dieser Spec.
