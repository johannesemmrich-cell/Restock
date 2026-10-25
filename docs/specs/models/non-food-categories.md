---
entity_id: non-food-categories
type: feature
created: 2026-10-25
updated: 2026-10-25
status: draft
workflow: feat-221-nonfood-kategorien
tags: [feature, category, drugstore, hardware-store, assignment, issue-221]
---

# Kategorien für Drogerie- und Baumärkte (#221)

## Approval

- [ ] Approved — Vorschlag des Tech Lead vom 2026-10-25 auf die PO-Anweisung „Analysiere das Angebot von
  dm und Hornbach (und anderen). Welche zusätzlichen Kategorien brauchen diese Märkte? Lege sie an.“
  Entscheidungen des PO stehen unten als „Vorschlag“ und gelten bis zu seinem Wort als getroffen.

## Ziel

Die 26 festen Kategorien aus `AssignmentService.categoryOrder` bilden einen Supermarkt-Rundgang ab.
Für Drogerien gab es nur Körperpflege, Reinigung, Medikamente und Babybedarf, für Baumärkte
Werkzeug, Garten, Farbe & Lack, Sanitär und Baumaterial; die Zuordnung dahinter kannte je Kategorie
eine Handvoll Stichwörter und fiel sonst auf „Körperpflege“ bzw. „Werkzeug“ zurück. Belegte Folgen
(Python-Nachbildung der Zuordnung, `docs/artifacts/feat-221-nonfood-kategorien/`): Zahnpasta, Tampons,
Toilettenpapier, Müllbeutel und Schwamm → Körperpflege; Lichtschalter → Sanitär; Schrauben, Laminat →
Baumaterial; Haarfarbe → Lebensmittel; Nagellack → Farbe & Lack; Lippenstift → Schreibwaren („stift“);
Crème fraîche, Eiscreme → Körperpflege („creme“); Blumentopf → Küchenausstattung („topf“); Pfanne →
Elektronik („fan“); Rohrzucker → Sanitär („rohr“).

## Analyse der Sortimente (2026-10-25, Websuche; Händlerseiten aus der Cloud nicht direkt erreichbar)

| Händler | Abteilungen laut Navigation | Fehlte uns |
|---|---|---|
| dm | Make-up · Pflege & Parfum · Haare · Gesundheit (Zahnpflege, Vitamine, Verbandsmaterial) · Ernährung · Baby & Kind · Haushalt · Home & Living · Foto · Tier | Make-up/Kosmetik, Haare, Zahnpflege, Hygiene, Tier |
| Rossmann | Make-Up · Pflege & Duft (Gesicht, Haar, Körper, Hygiene, Sonne) · Baby & Spielzeug · Haushalt · Tier · Gesundheit · Lebensmittel · Ideenwelt (Wohnen, Garten, Sport, Bekleidung) | wie dm |
| Müller | Drogerie, Parfümerie, Schreibwaren, Spielwaren, Multimedia, Haushalt | wie dm; Schreibwaren/Spielzeug vorhanden |
| Hornbach | Bad & Sanitär · Baustoffe · Holz · Fenster & Türen · Bodenbeläge & Fliesen · Eisenwaren · Farben, Tapeten · Garten (Erde, Dünger, Bewässerung, Geräte, Möbel, Pflanzen, Teich, Grill) · Heizen, Klima & Lüftung · Küche · Leuchten & Elektro · Maschinen, Werkzeug & Werkstatt · Zoo | Eisenwaren, Holz, Bodenbeläge & Fliesen, Elektroinstallation, Pflanzen |
| OBI | Bauen (Baustoffe, Boden, Wand, Fenster & Türen, Werkzeuge) · Garten & Freizeit (Pflanzen, Gartenbau, Grills, Pools) · Technik · Wohnen (Bodenbeläge) · Küche · Bad | wie Hornbach |
| Bauhaus / toom | Elektro, Sanitär, Werkzeuge, Eisenwaren, Haushalt, Holz, Farben, Fliesen, Garten, Bäderwelt | wie Hornbach |

Quellen: Suchergebnisse zu dm.de (Hauptmenü, „Pflege & Parfum“, „Gesundheit“), rossmann.de (Hauptmenü,
Unterkategorien Make-Up / Baby), hornbach.de (`/c/`, Baustoffe, Garten, Bodenbeläge), obi.de, Store-Checks
der Lebensmittel Zeitung zu OBI und Bauhaus. Abteilungsnamen sind Stand der Suche; die App bildet nicht die
Händlerstruktur ab, sondern Regale, die in mehreren Märkten dieselben sind.

## Entscheidung (Vorschlag)

Neun neue feste Kategorien, Rohwerte deutsch wie die bestehenden, in `categoryOrder` neben ihren
Nachbarregalen (Reihenfolge der alten 26 untereinander unverändert):

| Rohwert | Emoji | de / en | Pauschale | Ladentyp-Liste |
|---|---|---|---|---|
| Haarpflege | 💇 | Haarpflege / Hair Care | 4,20 € | drugstore |
| Zahnpflege | 🦷 | Zahnpflege / Dental Care | 3,30 € | drugstore |
| Kosmetik | 💄 | Kosmetik / Cosmetics | 6,90 € | drugstore (war schon Etikett, jetzt echte Kategorie) |
| Hygieneartikel | 🧻 | Hygieneartikel / Hygiene | 3,60 € | drugstore |
| Tierbedarf | 🐾 | Tierbedarf / Pet Supplies | 4,80 € | drugstore (Regal auch im Supermarkt) |
| Eisenwaren | 🔩 | Eisenwaren / Hardware & Fasteners | 5,50 € | hardware |
| Holz | 🪵 | Holz / Wood | 16,00 € | hardware |
| Boden & Fliesen | 🧱 | Boden & Fliesen / Flooring & Tiles | 18,00 € | hardware |
| Pflanzen | 🌷 | Pflanzen / Plants | 5,90 € | hardware (Schnittblumen auch an der Supermarktkasse) |

Bewusst nicht angelegt: Elektroinstallation (bleibt „Elektronik“, weil eine Glühbirne bei Action und
Hornbach dasselbe Regal ist), Heizung/Klima (bleibt „Sanitär“), Bauelemente wie Türen und Fenster (bleibt
„Baumaterial“), Arbeitsschutz (bleibt „Werkzeug“), Foto, Parfümerie als eigenes Regal (in „Kosmetik“).
Sport (Decathlon) behält seine Ladentyp-Etiketten ohne Artikelkategorien.

`Category.drugstore` verliert das Etikett „Haushalt“ (nie eine Artikelkategorie; alte Läden mit dem
Eintrag bleiben über die übrigen als Drogerie erkennbar) und bekommt die fünf Drogerie-Regale,
`Category.hardware` die vier Baumarkt-Regale. Pauschalen sind handgepflegt (Drogerie-/Baumarkt-Niveau 2026)
und paarweise verschieden zu allen 26 alten; `PriceEstimatorCategoryFallbackTests` prüft jetzt 35.

## Warenkunde (`SmartCart/Services/AssignmentService+NonFoodCategories.swift`)

Eine Tabelle `nonFoodCategoryMap` mit 33 Einträgen und 4425 Stichwörtern (deutsch, Marken, englisch):
Stichwörter → Kategorie → bevorzugter Ladentyp (`"drugstore"`, `"hardware"`, `"variety"` oder nil).
Dazu 195 Wortend-Regeln `nonFoodCategoryEndings` als abstraktes Wissen über deutsche Komposita
(„…schrauben“ → Eisenwaren, „…futter“ → Tierbedarf, „…shampoo“ → Haarpflege, „…fliese“ → Boden & Fliesen,
„…dünger“ → Garten). Die Datei kompiliert in App, Widget und Teilen-Erweiterung.

Regeln von `category(for:)` (geändert in `AssignmentService+Category.swift`):

1. Längstes Non-Food-Stichwort gegen längstes Lebensmittel-Stichwort aus `categoryMap`; das längere
   gewinnt, bei Gleichstand Non-Food. „reinigungsmilch“ (15) schlägt „milch“ (5), „katzenmilch“ gewinnt
   über „katzen“ (6 > 5), „rohrzucker“ (10) schlägt „rohr“ (4) — vorher Sanitär.
2. Trifft kein Non-Food-Stichwort, läuft der alte Weg unverändert (drei Ladentyp-Listen mit
   `detectHardware/Variety/DrugstoreCategory`, dann Lebensmittel-Stichwort).
3. Erst danach die Wortend-Regel auf dem letzten Wort (≥ 4 Zeichen; „LED-Lampe“ zählt als ein Wort),
   zuletzt „Lebensmittel“.
4. **Lebensmittel-Ausnahmen** stehen als eigene Einträge in der Warenkunde mit ihrer Lebensmittel-Kategorie,
   damit das längste Stichwort gewinnt: „pflanzenöl“ vor „pflanze“, „streusel“ vor „streu“, „eiscreme“ und
   „cremefraiche“ vor der alten Drogerie-Regel „creme“, „nagelkäse“ vor „nagel“, „proteinriegel“ vor
   „riegel“.
5. Kurze mehrdeutige Wörter („öl“, „creme“, „band“, „schloss“, „sand“, „tür“, „putz“, „kette“, „reibe“)
   stehen nicht in der Warenkunde; sie bleiben, wo sie waren, mit dem alten Verhalten.

Ladentyp für `assignDetailed`: nennt das längste Non-Food-Stichwort einen Ladentyp, gilt er; trifft ein
Eintrag ohne Ladentyp (Tierbedarf, Schnittblumen, Lebensmittel-Ausnahmen), zählt der Artikel als
Supermarktware, ohne die alten Stichwortlisten zu fragen (Crème fraîche ging bisher über „creme“ zur
Drogerie); ohne Treffer entscheiden die alten Listen wie bisher. Elektro ist zweigeteilt:
Installationsmaterial und Baustrahler → Baumarkt, Leuchtmittel, Wohnraumleuchten, Batterien, Kabel und
Steckdosenleisten → „Sonstiges“ wie bisher (Action). Kerzen bleiben Dekoration, Küchenhelfer bekommen eine
eigene Liste („Pfanne“ nicht mehr Elektronik über „fan“, „Gurkenhobel“ nicht mehr Gemüse).

## Messung (Python-Nachbildung beider Fassungen, 2026-10-25)

- Lebensmittel-Stichwörter aus `categoryMap` als Artikelnamen: 7 von 432 ändern die Kategorie, alle zum
  Besseren (cremefraiche, creme fraiche, eiscreme → Milchprodukte/Tiefkühlkost; multivitaminsaft, whisky,
  whiskey → Getränke; rohrzucker → Gewürze & Backen).
- Alte Non-Food-Stichwörter (drugstore/variety/hardware): 204 von 665 ändern die Kategorie, darunter alle
  oben genannten Fehler; Ladentyp ändert sich bei 47 (33 variety → hardware: Blumenerde, Grill, Gießkanne,
  Pflanzkübel, Sichtschutz …; 8 variety → drugstore: Zahnbürste, Haarbürste, Lippenstift …; 4 drugstore →
  variety: Alufolie, Müllbeutel, Gefrierbeutel, Frischhaltefolie; Nagellack hardware → drugstore).
- 355 realistische Namen (Drogerie, Baumarkt, Lebensmittel, Marken, Fallen): Tabelle in
  `docs/artifacts/feat-221-nonfood-kategorien/zuordnung-alt-neu.md`.

## Tests

- `RestockTests/NonFoodCategoryTests.swift` (K1–K7): Verdrahtung der neun Kategorien (Reihenfolge,
  Anzeige de/en, Emoji, Pauschale), Ladentyp-Listen nur echte Kategorien, kein Stichwort in zwei
  Kategorien, Drogerie-, Tier-, Baumarkt-, Garten-/Pflanzen-Beispiele, Lebensmittel bleiben Lebensmittel,
  Wortend-Regel nur als letzte Stufe, Ladentyp in `assign`, Emoji-Vorschläge eigener Kategorien.
- `PriceEstimatorCategoryFallbackTests`: 26 → 35; `LocalizationKeyParityTests` prüft die neun neuen
  Schlüssel de/en automatisch.

## Offene Grenzen

- Teilstring-Treffer bleiben Teilstring-Treffer: ein Name, der ein Stichwort enthält, bekommt dessen
  Kategorie, auch wenn er etwas anderes meint („Igelfutter“ ist Tierbedarf, „Heu“ ebenso).
- Händlerstrukturen aus Suchtreffern (Stand 2026-10-25), nicht aus den Seiten selbst; Unterkategorien von
  dm „Haare/Ernährung/Baby/Haushalt/Tier“ und Rossmann „Haushalt/Tier/Gesundheit“ waren nicht belegt.
- Bestehende Artikel wechseln nur in der Anzeige (Kategorie wird aus dem Namen gerechnet, solange sie nicht
  von Hand gesetzt ist); eine gelernte Einkaufsweg-Reihenfolge je Kategorie kennt die neuen Regale noch
  nicht und sortiert sie nach `categoryOrder` ein.
- Pauschalen und Stichwörter handgepflegt; die Messung ist eine Python-Nachbildung, nicht der Swift-Lauf.
  Nachweis ist der CI-Lauf (`test`, Hälften A/B unverändert).
- Geklärt mit Issue #224 (PO 2026-10-25, „Hört sich sinnvoll an“): Ein Alles-Laden (Action, Karstadt,
  Woolworth; Ladentyp „Sonstiges“) ist Rückfall-Laden. `Category.isHardwareStore`/`isVarietyStore`
  (`Store.swift`) ignorieren das geteilte Etikett „Werkzeug“: Baumarkt ist, wer ein reines Baumarkt-Regal
  nennt, Sonstiges-Laden, wer ein reines Sonstiges-Regal nennt; ein Laden mit nur „Werkzeug“ zählt wie
  bisher als beides. `assignDetailed` nutzt beide Funktionen für Kandidaten und Rückfall. Belegt in den
  CI-Läufen 40191683943 und 40196002586 (vorher: OSB-Platte → Action, Batterien → Hornbach, je nach
  Besuchshäufigkeit). Test `testGeneralStoreIsFallbackOnlyAndHardwareStoreWinsHardwareItems`,
  `testStoreTypeMarkersIgnoreSharedWerkzeug`.
- Nichts auf Hennings Geräten geprüft.
