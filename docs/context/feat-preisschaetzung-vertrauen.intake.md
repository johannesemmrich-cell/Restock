# Intake — Preisschätzung: „ca. 2,00 €“ fünfmal untereinander (Issues #160–#164)

Workflow: `feat-preisschaetzung-vertrauen` · Track: je Issue in Phase 1 festlegen (#160 Standard; #163 und #164 mit Datenabfluss und öffentlicher Datenbank voraussichtlich Full Process) · Datum: 2026-10-18

## Ursprungsmeldung (Henning, 2026-10-18)

Screenshot der Rewe-Liste: Mozzarella, Schlagsahne, Parmesan, Marmelade, Tomatenmark stehen alle
mit „ca. 2,00 € · Schätzung“ untereinander, Gauda mit „ca. 2,50 €“. Frage: „Was würde ein User
denken, wenn er diese Preise sieht mit dem Vermerk Schätzung? So ist das eine Katastrophe.“
Auftrag: recherchieren, wie sich das dramatisch verbessern lässt.

## Klärung durch den PO (2026-10-18)

- **Nutzer sollen sich gegenseitig helfen.** Der PO ging davon aus, dass Open Prices schon
  angebunden ist und die App Preise bereits teilt. Beides trifft nicht zu (Ist-Stand unten).
  → #163.
- **Harmlose Daten dürfen das Gerät verlassen, und KI darf verwendet werden** — nur nicht dort,
  wo deterministische Regeln oder Code besser sind. Das ersetzt die bisher engere Lesart von
  „Regeln vor Modell“ (`docs/context/feat-13-preismodell-stufen.md`): Daten und Regeln zuerst,
  KI für den Rest. → #164, und Netzzugriff in #162/#163 ist damit zulässig.

## Was der Nutzer sieht (Einschätzung)

Fünf gleiche Beträge mit demselben Vermerk lesen sich als „die App rät mit einer Pauschale“.
Das kostet Vertrauen auch in die echten Preise („Bon“, „bezahlt“, #151), und alle Summen
(Listensumme `StoreDetailView`, „Budgetschätzung“ `PriceOverviewView`, Widget) sind aus diesen
Pauschalen gebaut. #151 hat die Quelle sichtbar gemacht; dadurch fällt die Schwäche der untersten
Stufe jetzt auf.

## Ist-Stand im Code (geprüft 2026-10-18)

- `PriceEstimator.estimate` (`SmartCart/Models/ShoppingItem.swift`): 32 Stichwörter mit
  Festpreis (`specificPrices`), sonst Pauschale je Kategorie („Milchprodukte“ 2,00 €,
  „Konserven“ 1,70 €, „Lebensmittel“ 2,90 € seit PR #47; ältere Artikel tragen die Altwerte,
  daher Marmelade 2,00 € und Gauda 2,50 € im Screenshot).
- Messung gegen die 565 Lebensmittel-Stichwörter aus `AssignmentService.category(for:)`
  (Skript: Python-Nachbau der Stichwortsuche, Scratch-Lauf, nicht eingecheckt):

  | Kategorie | Stichwörter | mit Produktpreis | nur Pauschale |
  |---|---|---|---|
  | alle Lebensmittel | 565 | 111 (20 %) | 454 |
  | Milchprodukte | 40 | 13 | 27 |
  | Tiefkühlkost | 23 | 1 | 22 |
  | Obst & Gemüse | 136 | 14 | 122 |

- Teilstring-Fehltreffer durch `nameLower.contains`: „Tomatenmark“ → „tomaten“ (2,00 €),
  „Wassermelone“ → „wasser“ (0,90 €), „Buttermilch“ → „milch“, „Teelicht“ → „tee“,
  „Eierlikör“ → „eier“, „Käsekuchen“ → „käse“.
- Gelernte Preise werden nur im **selben Laden** gesucht (`resolveLearnedPrice`); eigene
  Bonpreise anderer Läden (`PurchaseRecord.actualPrice`, `learnedPrices` anderer Läden) bleiben
  ungenutzt.
- **Keine Open-Prices-Integration.** Einziger Open-Food-Facts-Aufruf: Produktname per Barcode
  (`BarcodeScannerView.swift`). Lesen von Open Prices ist #49 (offen, nur Barcode-Pfad).
- **Kein Teilen mit fremden Nutzern.** `LearnedPriceSync` (`SharedStoreService.swift`) gleicht
  gelernte Preise nur zwischen Mitgliedern eines geteilten Ladens ab (Haushalt).

## Recherche externer Quellen (2026-10-18; `prices.openfoodfacts.org` und Hugging Face sind aus der Cloud-Umgebung gesperrt, Zahlen aus der Repo-Analyse vom 25.09.)

- **Open Prices (Open Food Facts):** einzige Community-Preisdatenbank. Deutschland ~1.073 Läden,
  ~16.800 Preise; Stichprobe 4 von 8 gängigen Barcodes weltweit ohne Eintrag (`docs/context/feat-13-preismodell-stufen.md`).
  Lesen per Barcode nur im Scan-Pfad (#49). Der Gesamtdatensatz liegt täglich als Parquet
  (Hugging Face `openfoodfacts/open-prices`, ODbL) vor → Mediane je Produktkategorie zur
  Bauzeit möglich (#162). Beitragen verlangt ein OFF-Konto und ordnet Preise einem Nachweis
  (Bonfoto/Preisschild, CC-BY-SA) zu; Beitragende erscheinen als Hash (#163, Details in der Spec
  zu bestätigen).
- **Destatis:** seit 2022 keine absoluten Durchschnittspreise, nur Index (#12, erledigt).
- **Händler-APIs:** existieren nicht; Marktguru u. ä. nur per inoffiziellem Scraping
  (Rechtsrisiko) — verworfen.
- **Eigene Daten der App:** Bon-Scan und „Preis eintragen“ liefern Artikel, Laden, Preis je
  Einheit und Datum — die unterschätzte Quelle (#161, #163).

## Beschlossene Aufteilung (fünf Issues, Reihenfolge = Stufenmodell)

| Schritt | Issue | Inhalt | Abhängigkeit |
|---|---|---|---|
| 1 | #160 | Pauschale nicht als Artikelpreis zeigen („Preis?“), Summen mit „x von y geschätzt“, Wortgrenzen-Treffer, `priceSource` trennt Produktliste/Pauschale | — |
| 2 | #161 | Eigene Preise aus anderen Läden („zuletzt bei Lidl“) | #160 |
| 3 | #162 | Katalog als JSON-Ressource, 500–800 Einträge, Packung + Spanne + Datum + Quelle (Open Prices DE + Handpflege) | #160 |
| 4 | #163 | Preise teilen: eigener Community-Pool (CloudKit public) und Beitrag an Open Prices, Opt-in | #160; Schema vor TestFlight |
| 5 | #164 | KI-Schätzung (Gerätemodell zuerst) nur für den Rest, mit Nachweis gegen Prüfsatz | #160, sinnvoll nach #162 |

Zielreihenfolge im `PriceEstimator`: eigener Preis dieser Laden → eigener Preis anderer Laden →
Community → Katalog → KI → Pauschale (nur noch Rechengröße für Summen).

## Typische Werte für die sechs Artikel aus dem Screenshot (Erfahrungswerte, nicht gemessen)

| Artikel | heute | realistisch |
|---|---|---|
| Mozzarella 125 g | 2,00 € | 1,00–1,30 € |
| Schlagsahne 200 g | 2,00 € | 0,90–1,20 € |
| Parmesan 200 g | 2,00 € | 3,50–4,50 € |
| Marmelade 450 g | 2,00 € | 1,50–3,00 € |
| Tomatenmark 200 g | 2,00 € | 0,90–1,30 € |
| Gouda 400 g | 2,50 € | 3,50–4,50 € |

## Betroffener Code (erste Sichtung, nicht abschließend)

- `SmartCart/Models/ShoppingItem.swift` — `PriceEstimator`, `resolveLearnedPrice`, `priceSource`
- `SmartCart/Views/Components/ItemRow.swift` — Betrag + Quellzeile
- `SmartCart/Views/Store/StoreDetailView.swift`, `SmartCart/Views/Prices/PriceOverviewView.swift`,
  `SmartCartWidgets/ShoppingListWidget.swift` — Summen aus `estimatedLineTotal`
- `SmartCart/Views/Prices/ReceiptScannerView.swift`, `ActualPriceEntryView.swift` — Schreibstellen
  für Community-Beiträge (#163)
- `SmartCart/Services/SharedStoreService.swift` — Vorbild für öffentliche CloudKit-Records (#163)
- `SmartCart/Services/RecipeRecognitionService.swift` — Vorbild für `FoundationModels` (#164)
- Bestehende Specs: `docs/specs/models/price-estimator-stages.md`,
  `price-estimator-category-fallback.md`, `price-source-display.md`,
  `learned-price-unit-and-quantity-source.md`
