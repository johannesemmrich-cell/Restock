---
entity_id: price-catalog-data-resource
type: module
created: 2026-10-22
updated: 2026-10-22
status: draft
version: "1.0"
tags: [pricing, models, data, issue-162]
---

# Preiskatalog als Datenressource: JSON-Quelle, erzeugtes Swift, Quelle je Eintrag, Spanne im Sheet

## Approval

- [ ] Approved

## Ziel (Issue #162, Punkte 1, 2, 5, 6)

Der Katalog (528 Einträge, Stand 2026-10) lebt nicht mehr als Swift-Literale, sondern als
Datenressource `data/price-catalog/catalog.json`; `scripts/build-price-catalog.py` erzeugt daraus
`SmartCart/Models/PriceCatalogEntries.swift`. Jeder Eintrag trägt Quelle (`hand`, später
`openprices-de`) und Stichtag (`JJJJ-MM`); das Bearbeiten-Sheet zeigt Spanne, typische Packung und
Quelle. Ein Drift-Test stellt sicher, dass Swift und JSON nicht auseinanderlaufen.

## Entscheidung: erzeugtes Swift statt JSON im Bundle

Das Issue nannte eine Bundle-Ressource. Gewählt ist erzeugtes Swift, weil `ShoppingItem.init` den
Katalog synchron in drei Prozessen liest (App, Widget, Teilen-Erweiterung): Eine Bundle-Ressource
müsste in drei Zielen registriert, beim Start geparst und gegen Lesefehler abgesichert werden, und
`typoCandidates` wird aus den Einträgen vorberechnet. Erzeugtes Swift wird vom Compiler geprüft,
kostet zur Laufzeit nichts und ist byteweise reproduzierbar. Die Datenressource ist trotzdem die
JSON: Pflege, Review und Skripte arbeiten nur dort (Präzedenzfall für gebündelte Daten, siehe
`docs/context/feat-12-destatis-preise.md`).

## Quelle

- `data/price-catalog/catalog.json` — `sources` (Kennung → Label, Stichtag), `groups[]` mit `name`,
  `doc[]` (Kommentarzeilen) und `entries[]`; je Eintrag `names[]`, `package{amount, unit}`,
  `price{low, typical, high}`, `source`, `asOf`. Ein Eintrag je Zeile (diff-freundlich).
- `data/price-catalog/open-prices-medians.json` — optional, erzeugt von `scripts/open-prices-medians.py`
  aus dem Open-Prices-Parquet (Hugging Face `openfoodfacts/open-prices`, ODbL): `asOf`,
  `minimumPrices`, `entries{<erster Name>: {count, medianPerPackage}}`.
- `scripts/build-price-catalog.py` — `validate` (Quelle, Stichtag, Spanne, Packung, normalisierte
  Namen, keine Namenskollision), `render`, `--check` (Drift), `--stats`.
- `SmartCart/Models/PriceCatalogEntries.swift` — erzeugt; `extension PriceCatalog` mit den Listen
  `legacy … sports` und `entries` in unveränderter Reihenfolge (Trefferregel „früherer Eintrag gewinnt“).
- `SmartCart/Models/PriceCatalog.swift` — Logik unverändert; `PriceCatalogEntry.sourceKind`/`sourceDate`,
  `PriceCatalogDisplay.summary(for:)`/`summary(forName:)`/`sourceText(for:)`/`displayDate(_:)`.
- `SmartCart/Views/Store/EditItemView.swift` — Zeile unter dem Preisfeld
  (`editItem.catalogSummary`): „Katalog: 125 g typisch 1,09 €, Spanne 0,79 € – 1,79 € · handgepflegt 10/2026“.
- Texte: `price.catalog.summary`, `price.catalog.package.piece`, `price.catalog.source.hand`,
  `price.catalog.source.openprices` (de/en), registriert über `PriceCatalogDisplay.allLocalizationKeys`.

## Regeln beim Zusammenführen der Quellen

1. Ohne Median: Handwert, Quelle `hand-<asOf>`.
2. Median vorhanden und `count ≥ minimumPrices`: ersetzt den typischen Wert, wenn er innerhalb der
   Handspanne [low, high] liegt → Quelle `openprices-de-<asOf>`; Spanne bleibt die Handspanne.
3. Median außerhalb der Spanne oder zu wenige Preise: Handwert bleibt, der Fall wird in `--stats` gezählt
   (Ausreißer oder andere Packungsgröße; wird vor der Behauptung der Quelle gemessen, Lehre aus #12).

## Tests

- `scripts/test_price_catalog_build.py` — JSON gültig, erzeugtes Swift entspricht JSON, Quellenmuster,
  Kollisionen und Spannenfehler werden erkannt, Merge-Regeln 1–3, Zähler 528.
- `RestockTests/PriceCatalogDataTests.swift` — am kompilierten Katalog: Quelle/Stichtag je Eintrag,
  keine zwei Einträge mit demselben Namen, Namen normalisiert, Spanne aufsteigend, Packung gültig;
  `sourceKind`/`sourceDate`; Anzeigetext (125 g, 1,09, 0,79, 1,79, 10/2026), Stück-Eintrag ohne „1 stk“,
  Quellenlabel, Schlüssel registriert.
- Bestehende `PriceCatalogTests`/`PriceCatalogExpansionTests` unverändert (gleiche Listen, gleiche Werte,
  Rundlauf alt → JSON → neu per Skript belegt: 528 Einträge bitgleich).

## Offene Grenzen

- Open-Prices-Median: Skript und Merge-Regel stehen; die Mediandatei entsteht erst, wenn der Datensatz
  aus der Arbeitsumgebung erreichbar ist (Hugging Face war am 2026-10-22 gesperrt). Bis dahin tragen
  alle Einträge `hand-2026-10`, und `LegalView` nennt Open Prices noch nicht als Katalogquelle.
- Der Drift-Test läuft als Python-Strukturtest; in der CI läuft er nur, wenn der Unit-Job ihn aufruft
  (siehe `ci.yml`, Schritt „Strukturtests“).
- Die Anzeige im Sheet hängt am aktuellen Namen, nicht am gespeicherten Preis: Ein Artikel mit eigenem
  Preis zeigt die Katalogzeile trotzdem (als Vergleichswert gewollt).
- Nichts auf Hennings Geräten geprüft.
