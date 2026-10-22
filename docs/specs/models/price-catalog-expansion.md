---
entity_id: price-catalog-expansion
type: module
created: 2026-10-22
updated: 2026-10-22
status: draft
version: "1.0"
tags: [pricing, models, community, issue-162, issue-163]
---

# Preiskatalog: Drogerie, Haushalt, Sport, Marken, Mehrzahl, Tippfehler; Community über alle Ketten

## Approval

- [ ] Approved

## Ziel

Produktentscheidung des PO vom 2026-10-22. Der Katalog aus #160–#162 deckte fast nur Lebensmittel ab:
von den 100 Drogerie-Stichwörtern des `AssignmentService` hatten 52 einen Katalogpreis, „Hack“,
„Spüli“, „Tabs“, „Milka“, „Joghurts“ oder „Banan“ fielen auf die Pauschale („Preis?“), und
„Fahrradschlauch“ bekam über die Grundwort-Regel den Lauchpreis. Community-Preise (#163) galten nur
ab drei Beobachtungen derselben Kette.

## Quelle

- `SmartCart/Models/PriceCatalog.swift` — neue Listen `legacyAliases`, `foodAdditions`, `drugstore`,
  `householdMore`, `sports`; Regeln `singularCandidates`, `wordMatches`/`blockedHeadEndings`, `typoMatch`/`isOneEditApart`
- `SmartCart/Models/CommunityPriceCache.swift` — `CommunityPrice.allChainsMarker`, `resolve` mit Rückfall, `Resolution.source`
- `SmartCart/Services/CommunityPriceService.swift` — `fetchCommunityRecordsAllChains`, zweite Abfrage in `refresh`
- `SmartCart/Models/ShoppingItem.swift` — `PriceSourceDisplay.text` („Community · andere Läden“), Schlüssel in `allLocalizationKeys`
- Tests: `RestockTests/PriceCatalogExpansionTests.swift`, `RestockTests/CommunityPriceTests.swift`, `RestockTests/PriceCatalogTests.swift` (Zähler)

## Katalog

| Liste | Einträge | Inhalt |
|---|---|---|
| `legacyAliases` | 18 | Marken/Kurzformen zu den 32 Alt-Stichwörtern mit deren unveränderten Werten (Hack, Spüli, Milka, Persil/Ariel, Hakle, Duschbad, Zahncreme/Elmex, Semmel, Erdäpfel …) |
| `foodAdditions` | 17 | Schweinefleisch, Kefir, Gorgonzola, Grapefruit, Ciabatta, Muffin, Cappuccino, Strudel … |
| `drugstore` | 40 | Haarfarbe, Gesichtspflege, Baby, Erkältung, Desinfektion, Kosmetik, Verbandsmaterial … |
| `householdMore` | 70 | Reinigung, Wäsche, Küche, Tier, Garten, Kleinkram, Schreibwaren |
| `sports` | 75 | Fahrrad (Schlauch, Mantel, Licht, Schloss …), Ballsport, Schwimmen, Fitness, Outdoor/Trekking-Nahrung, Bekleidung |

Dazu Marken und Varianten als weitere Namen bestehender Einträge (Oatly → Hafermilch, Alpro →
Sojamilch, Philadelphia → Frischkäse, Senseo/Nespresso → Kaffeepads, Rama → Margarine, Nivea →
Bodylotion/Creme, Zewa → Küchenrolle, Somat/Finish/Tabs → Spülmaschinentabs, Lenor → Weichspüler,
Biermarken, Einzahlformen wie „erdbeere“, „kirsche“) und englische Drogerie-Stichwörter. Die 32
Alt-Einträge (`PriceCatalog.legacy`) sind unverändert, weil sie die Messbasis „vorher“ sind.
Preise: handgepflegt, Stand 2026, Discounter-/Drogerie-Niveau (Eigenmarke als untere Grenze).
Einträge über `PriceEstimator.maxPlausibleLineTotal` (30 €, z. B. Zelt, Laufschuhe) liefern weiter
keine Schätzung; sie stehen im Katalog, damit der Name nicht über ein kürzeres Grundwort trifft.

## Regeln von `PriceCatalog.match`

1. Ganzes Wort oder Grundwort eines Kompositums wie bisher (Name ≥ 4 Zeichen, Bestimmungswort ≥ 3), längster Name gewinnt, bei Gleichstand der frühere Eintrag.
2. **Mehrzahl:** Jedes Wort wird zusätzlich ohne -en, -n, -s bzw. -e geprüft, wenn ≥ 4 Zeichen Stamm bleiben („Joghurts“ → joghurt, „Erdbeerjoghurts“ → joghurt). Ausnahmen `nonPluralEndings` (Reise, Ballen, Hacke). Umlaut-Plurale nur als eigene Namen.
3. **Sperr-Endungen** `blockedHeadEndings`: Endet ein Wort auf z. B. „schlauch“, „schwein“, „preis“, „feier“, „krawatte“, gilt ein darin steckender kürzerer Name (lauch, wein, reis, eier, watte) nicht als Grundwort. „Fahrradschlauch“ ist zusätzlich eigener Sporteintrag.
4. **Tippfehler** nur, wenn Regel 1–2 nichts finden: ein Wort ≥ 5 Buchstaben, genau ein Schritt (Einfügen, Löschen, Vertauschen; Ersetzen erst ab 7 Buchstaben) von einem einwortigen Namen ≥ 5 Buchstaben mit gleichem Anfangsbuchstaben; alle Kandidaten müssen zu genau einem Eintrag gehören.
5. Mehrwortige Namen nur als ganze Wortfolge, ohne Mehrzahl- und Tippfehler-Regel.

### Entscheidungen

- **Ersetzen erst ab 7 Buchstaben** (enger als „1 Schritt ab 5 Buchstaben“): Beim Abgleich mit einer
  deutschen Wortliste (enz/german-wordlist, 291 437 großgeschriebene Wörter) erzeugten Ersetzungen
  in 5–6 Buchstaben 329 Treffer, fast alle echte andere Wörter („Seite“ → Seife, „Biene“ → Birne,
  „Bahnen“ → Bohnen). Einfügen/Löschen trifft überwiegend Einzahl/Mehrzahl und echte Tippfehler
  („Jogurt“, „Kondom“, „Banan“). Nach der Einschränkung 415 Tippfehler-Treffer in der ganzen Liste.
- **Sperrliste statt Silbenanalyse:** Einfach, nachprüfbar, je Eintrag begründet; in der Wortliste
  sperrt sie 419 Grundwort-Treffer, die die alte Regel mit dem neuen Katalog geliefert hätte (269×
  „…preis/…kreis“ → Reis, 49× „…stabs“ → Tabs, 47× „…feier/…geier“ → Eier, 19× „…rama“, 10×
  „…lawine“ → wine, dazu Schlauch, Krawatte, Stopfen); in der Durchsicht alle zu Recht.
- Kurze, mehrdeutige Namen bewusst **nicht** aufgenommen: „topf“ (Eintopf), „becher“ (Eisbecher),
  „korn“ (Vollkorn), „erde“ (Pferde, Beschwerde), „reibe“ (Schreiben), „puter“ (Computer),
  „schüssel“ (Tippfehler „Schlüssel“), „ball“/„bälle“ (Schneebälle, Abiball).

### Messung (Python-Nachbildung der Regeln, gegen die alte Regel geeicht: 556/114/385 wie im Test)

| Größe | vorher | nachher |
|---|---|---|
| Lebensmittel-Stichwörter `AssignmentService.categoryMap` mit Katalogtreffer | 385 / 556 | 432 / 556 |
| Drogerie-Stichwörter `drugstoreKeywords` | 52 / 100 | 97 / 100 |
| Gemischtwaren-Stichwörter `varietyStoreKeywords` | 15 / 322 | 117 / 322 |
| Katalogeinträge | 308 | 528 |

## Community über alle Ketten

- Hat die eigene Kette kein Aggregat (weniger als 3 Beobachtungen in 180 Tagen), fragt `refresh`
  ein zweites Mal **ohne Kettenfilter** (`itemKey IN …`, sortiert nach `observedAt` absteigend, Limit 400)
  nur für diese Schlüssel. Beide Felder sind im Schema schon QUERYABLE bzw. SORTABLE — kein neues
  Feld, kein neuer Record-Typ, kein neuer Index.
- Aggregat wie bisher (Median der jüngsten 20, ab 3, häufigste Bezugsgröße), abgelegt unter der
  Kette `"*"` (`CommunityPrice.allChainsMarker`) im selben Zwischenspeicher.
- `resolve`: eigene Kette vor `"*"`; verwirft Einheitentabelle oder Obergrenze die eigene Kette,
  wird nicht auf `"*"` ausgewichen. Quelle `"community:*"`, `priceOrigin` = `community`, Anzeige
  „Community · andere Läden · TT.MM.“ (`price.source.community.allchains[.undated]`, de/en).
- Scheitert nur die zweite Abfrage, bleiben die Ergebnisse der eigenen Kette gespeichert.

## Offene Grenzen

- Werte handgepflegt, nicht gegen Kassenbons oder Open Prices geprüft (#162); Spannen grob.
- Tippfehler- und Mehrzahl-Regel können echte andere Wörter treffen (Wortliste: „Kirche“ → Kirsche,
  „Strudel“ war vor dem eigenen Eintrag Sprudel); Genitivformen werden wie Mehrzahl behandelt.
- Englische Namen im Katalog nehmen an der Tippfehler-Stufe teil („Crema“ → cream → Sahne).
- Kettenübergreifende Abfrage nicht gegen echtes CloudKit geprüft (öffentliche Datenbank, Production);
  bei sehr vielen Beobachtungen schneidet das Limit 400 die ältesten ab.
- Swift-Code in dieser Umgebung nicht kompiliert; Zählerwerte aus der Python-Nachbildung, CI prüft.
- Nichts auf Hennings Geräten geprüft.
