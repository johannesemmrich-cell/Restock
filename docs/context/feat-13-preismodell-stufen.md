# Context: feat-13-preismodell-stufen (Issue #13, neu gefasst)

## Request Summary
Nicht mehr "Open Prices beim Barcode-Scan mitabfragen" (ursprünglicher Ticket-Titel), sondern
ein allgemeines, dokumentiertes **Stufenmodell**, nach dem `PriceEstimator`/`ShoppingItem.init`
einen Artikelpreis ermittelt: welche Quelle vor welcher, ab wann eine Quelle als veraltet gilt,
und ob/wie eine neue externe Quelle (z. B. Open Prices) überhaupt eine zusätzliche Stufe
rechtfertigt — nach der Destatis-Lehre aus Issue #12 (siehe unten) nur, wenn recherchiert und
nicht nur behauptet.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/ShoppingItem.swift:112-155,204-338` | Kernstück der heutigen Preisermittlung: `init` wählt `learnedPrice` (fuzzy Store-Match) vor `PriceEstimator.estimate` (Produkt-Keyword vor Kategorie-Pauschale). Genau hier entsteht die neue Stufenreihenfolge. |
| `SmartCart/Models/Store.swift:27-32,106-107` | `learnedPrices: [String: Double]` + `learnedPriceDates: [String: Date]` — die einzige Preisquelle mit echtem Datum heute. Wird aktuell nur als Tie-Breaker bei mehreren fuzzy-Treffern genutzt, nicht als Veraltungs-Kriterium. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:643-652` | Schreibt `learnedPrices`/`learnedPriceDates` aus einem gescannten Bon — eine der beiden Quellen für "gelernten Preis". |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift:152-164` | Schreibt `learnedPrices`/`learnedPriceDates` aus manueller Preiseingabe — die zweite Quelle für "gelernten Preis". |
| `SmartCart/Models/PurchaseRecord.swift:15,19,26` | `actualPrice: Double?` je Kauf — historische Preis-Einzelwerte, aktuell nicht in die Schätzung einbezogen (nur `learnedPrices`, das den letzten/fuzzy-besten Wert hält, nicht die Historie). |
| `SmartCart/Views/Components/BarcodeScannerView.swift:96-110` | `ProductLookup.lookup(barcode:)` — bestehendes Muster für einen externen Lesezugriff (Open Food Facts): `try?`, Fehler → `nil`, kein Retry, kein Caching, kein User-Fehlerpfad. Vorbild für eine mögliche Open-Prices-Anbindung. |
| `SmartCart/Views/Settings/LegalView.swift:73-74,89,185,248` | Bestehende Datenschutz-Passage für Open Food Facts (nur EAN wird übertragen). Muster für eine neue Passage, falls eine externe Preisquelle hinzukommt. |
| `docs/specs/models/price-estimator-category-fallback.md` | Aktuelle (Issue #12) Spec der Kategorie-Pauschalen — bleibt als unterste Stufe bestehen, wird durch dieses Ticket nicht verändert, nur eingeordnet. |
| `docs/context/feat-12-destatis-preise.md` | Direkter Vorläufer, **gestern (2026-09-25) abgeschlossen**: Destatis liefert keine amtlichen Euro-Durchschnittspreise mehr (nur VPI-Index) — Kernannahme des Ursprungstickets war falsch. Zentrale Lehre für dieses Ticket: keine externe Quelle ungeprüft übernehmen. |
| `SmartCart/Services/SyncCoordinator.swift:235-242` | Zeigt, wie `learnedPriceDates` bereits für Last-Write-Wins beim Sync zwischen Geräten verwendet wird — ein Präzedenzfall für "Datum entscheidet", nur bisher nicht für Veraltung. |

## Existing Patterns
- **Zwei-Stufen-Fallback existiert bereits, ist aber nicht als Modell dokumentiert:** `ShoppingItem.init` (Zeile 154) probiert `learnedPrice` zuerst, sonst `PriceEstimator.estimate`. Letzteres selbst hat intern wieder zwei Stufen: `specificPrices` (32 Produkt-Keywords) vor Kategorie-Pauschale. De facto also schon 3 Stufen, nirgends als Konzept benannt oder mit einer Spec belegt.
- **Externe Lesezugriffe sind immer "silent fail"**: `ProductLookup.lookup` (Barcode) ist das einzige Beispiel für einen Netzwerkaufruf im Preis-/Produktkontext — Vorbild für "Ausfall darf den Scan/die Schätzung nie blockieren" (explizit als offene Frage in Issue #13 genannt).
- **Datierte Werte gibt es nur bei `learnedPrices`** (`learnedPriceDates`), aktuell nur zum Auflösen mehrdeutiger fuzzy-Treffer, nicht zur Alters-/Veraltungsbewertung.
- **Regeln vor Modell** (Henning, globale Regel): Für alles, was sich deterministisch lösen lässt (Rangfolge von Quellen, Alters-Schwellwert, Einheiten-Umrechnung), ist kein Sprachmodell nötig — passt zum bestehenden Stil, der komplett ohne LLM auskommt.

## Dependencies
- **Upstream:** `PriceEstimator.estimate` wird aufgerufen von `ShoppingItem.init` (Zeile 154, einziger automatischer Aufrufer) und `EditItemView.swift:375,384` (manuelle Neuschätzung). Eine neue Stufe muss beide Aufrufer transparent bedienen — Signatur-Kompatibilität ist ein hartes Kriterium (bestehende Spec zu #12 hält das bereits fest).
- **Downstream:** `estimatedLineTotal`, Budget-Summen in `HomeView`/`StoreDetailView`, `estimatedPriceIsAutoDerived`-Flag (steuert vermutlich eine UI-Kennzeichnung "geschätzt" vs. "gelernt") — alles hängt an `estimatedPrice`.
- **Mögliche neue Upstream-Abhängigkeit:** Open Prices API (`prices.openfoodfacts.org`, `GET /api/v1/prices?product_code=<EAN>`) — ungeprüft, ob Datenlage für deutsche Supermarktartikel trägt (Ticket nennt selbst 16.736 Preise auf 1.064 Läden als "dünn").

## Existing Specs
- `docs/specs/models/price-estimator-category-fallback.md` — unterste Stufe (Kategorie-Pauschale), Status `draft`, bleibt inhaltlich unverändert.
- Keine Spec für die `learnedPrice`-Stufe oder die Gesamt-Rangfolge — wird in diesem Ticket erstmals dokumentiert.

## Risks & Considerations
- **Wiederholungsrisiko der Destatis-Lehre:** Jede neue externe Preisquelle (Open Prices oder andere) braucht echte Recherche zur Datenabdeckung, bevor sie als Stufe eingeplant wird — sonst droht dieselbe nachträgliche Korrektur wie bei #12.
- **Ausfallverhalten:** Eine neue Netzwerkstufe darf laut Ticket "den Scan nie blockieren" — das bestehende `ProductLookup`-Muster (silent `nil`) ist Vorbild, aber `ShoppingItem.init` ist synchron und nicht-async; eine echte Laufzeitabfrage würde eine async Neu-Schätzung nach Item-Erstellung erfordern (Architekturfrage für Phase 2).
- **Veraltungsschwelle:** `learnedPriceDates` existiert, wird aber nirgends gegen ein Alter geprüft — "ab wann gilt ein Preis als veraltet?" (Ticket-eigene offene Frage) ist eine reine PO-/Domänenentscheidung, kein technisches Problem.
- **Datenschutz:** Nur bei tatsächlicher Netzwerk-Stufe relevant — `LegalView.swift` müsste ergänzt werden (Muster liegt vor).
- **Scope-Gefahr:** Das Ticket fragt nach einem *Konzept*, nicht zwingend nach sofortiger Umsetzung aller Stufen — Phase 2 muss klären, ob Open Prices als konkrete neue Stufe vorgeschlagen wird oder das Konzept zunächst nur die *bestehenden* drei Stufen (gelernt / Produkt-Keyword / Kategorie) explizit macht und Open Prices als geprüfte, aber zurückgestellte Option führt (Alternativen-Pflicht).

## Alternativen (mind. eine echte, per globaler Regel "In Alternativen denken")
1. **Konzept nur für bestehende Quellen** (gelernter Preis → Produkt-Keyword → Kategorie-Pauschale), Open Prices bleibt geprüfte, aber nicht integrierte Option. Kippt: Issue #13 würde nicht als "neue Datenquelle" umgesetzt, sondern nur als "bestehende Logik dokumentiert und um eine Veraltungsregel ergänzt".
2. **Konzept inkl. Open Prices als neue Zwischenstufe** (zwischen gelernt und Kategorie-Pauschale), abhängig von einer noch durchzuführenden Recherche zur Datenabdeckung in Phase 2 — Standardrichtung des Ursprungstickets.
3. **Kein neues Stufenmodell, nur `learnedPriceDates` für Veraltung nutzbar machen** — kleinster Eingriff, würde aber Hennings ausdrücklichen Wunsch nach einem "stufenweisen Modell" nicht erfüllen.

Welche Alternative trägt, entscheidet sich erst nach der Recherche in Phase 2 (Analyse).

## Analysis

### Type
Feature

### Recherche: Open Prices Datenabdeckung (2026-09-25, per curl gegen `https://prices.openfoodfacts.org/api/v1/`)
- **Store-Ebene:** 1.073 deutsche Läden, 16.798 Preiseinträge insgesamt (Summe über `price_count` aller Läden mit `osm_address_country__like=Deutschland`) — deckt sich mit dem im Ticket genannten Stand vom 2026-09-21 (1.064 Läden/16.736 Preise). Große Ketten sind vertreten: EDEKA (81 Läden/1.947 Preise), Netto Marken-Discount (48/1.527), Lidl (131/1.253), Kaufland (74/1.020), Rewe (72+88 Läden/1.572 kombiniert), Aldi Nord+Süd (68/993), Rossmann (36/269), dm (58/231), Penny (27/216), tegut (13/75).
- **Artikel-Ebene ist die eigentlich relevante Kennzahl — und dort ist die Abdeckung dünn:** Stichprobe von 8 sehr bekannten Supermarktartikeln (Coca-Cola 0,5l, Nutella 400g, Haribo Goldbären, Milka Alpenmilch, Barilla Spaghetti, Rewe-Eigenmarke Vollmilch, Alpro Hafermilch, Landliebe Joghurt) gegen `GET /api/v1/prices?product_code=<EAN>`: 4 von 8 Barcodes hatten **weltweit** 0 Preiseinträge; nur 1 Treffer kam aus Deutschland (Barilla Spaghetti: 1 von 20 weltweiten Einträgen). Gleicher Fehler wie bei Destatis in #12: eine plausibel aussehende Gesamt-Kennzahl (Store-Abdeckung) sagt nichts über die für den Use Case entscheidende Kennzahl (Trefferquote pro gescanntem Artikel) aus.
- **API-Detail:** Der Parameter `location_country` existiert nicht (die REST-API ignoriert unbekannte Query-Parameter kommentarlos — sieht wie ein Treffer aus, ist aber immer der Weltweit-Wert). Korrekt ist die Filterung über `/api/v1/locations?osm_address_country__like=Deutschland` und Aggregation über `price_count`.
- Lesezugriff (GET) braucht keine Authentifizierung.

### Recherche: Alternative community-basierte Preisquellen (2026-09-25, WebSearch)
Explizit auf Wunsch geprüft, ob es eine Alternative zu Open Prices gibt, die ebenfalls auf Community-Basis funktioniert. Ergebnis: **Nein.** Gefundene Optionen sind ausnahmslos kommerziell/nicht community-basiert:
- `product-search.net`, Barcode Lookup, Go-UPC: kostenpflichtige Barcode-Kataloge (Produktinfo, keine verifizierten Live-Preise).
- Apify-Scraper (z. B. für Asia-Supermärkte), fooddatascrape.com, actowizsolutions.com: kommerzielle Scraper-Dienste, kein Community-Ursprung, ToS-Risiko beim Scrapen einzelner Handelsketten.
- Destatis (bereits in #12 geprüft): keine Einzelprodukt-Preise, nur VPI-Index.
- Es existiert keine offizielle API deutscher Supermärkte für Preise (Geschäftsinteresse steht dem entgegen).

Open Prices bleibt damit die einzige Quelle, die "echte, community-beobachtete Preise" liefert. **Entscheidung (PO, 2026-09-25): Open Prices wird integriert.**

### Technischer Ansatz — kein Architekturbruch nötig
Der befürchtete Sync-zu-Async-Umbau von `ShoppingItem.init` ist **nicht erforderlich**. Der Barcode-Scan-Ablauf ist bereits heute asynchron und der Barcode wird danach verworfen:
- `AddItemView.swift:157`: `BarcodeScannerSheet { _, productName in ... }` — der Barcode-Parameter wird mit `_` verworfen.
- `BarcodeScannerView.swift:22`: `let name = await ProductLookup.lookup(barcode: barcode)` — bereits ein `Task { await ... }`, bevor `onResult` (und später, oft nach manueller Bearbeitung, `addItem()`) läuft.

Ein zusätzlicher Open-Prices-Abruf kann in genau dieser bereits-asynchronen Stelle huckepack laufen (Barcode in `@State` behalten statt verwerfen, Ergebnis bei `addItem()` als zusätzlicher optionaler Parameter an `ShoppingItem.init` übergeben). `ShoppingItem.init` selbst bleibt synchron. Nur für den Barcode-Scan-Pfad relevant — die QuickAdd-Freitext-Erfassung (kein EAN vorhanden) ist von Open Prices grundsätzlich ausgeschlossen.

### Scope-Aufteilung (LoC-Gate)
Veraltungsregel + Stufenmodell-Doku + Open-Prices-Stufe + Datenschutz-Ergänzung + Tests zusammen wurden auf ~5-6 Dateien / ~180-280 LoC geschätzt — über dem Scoping-Limit (4-5 Dateien, ±250 LoC). Deshalb aufgeteilt:
- **#13 (dieses Ticket, reduzierter Scope):** bestehendes 3-Stufen-Modell (gelernter Preis → Produkt-Keyword → Kategorie-Pauschale) dokumentieren + Veraltungsregel für gelernte Preise. Klein, unabhängig, kein Netzwerkzugriff.
- **#49 (neu angelegt):** Open Prices als vierte Stufe beim Barcode-Scan, inkl. Datenschutz-Ergänzung in `LegalView.swift`. Setzt #13 voraus (Stufenmodell muss zuerst stehen).

### PO-Einwand und Scope-Reduktion (2026-09-25, während `/30-write-spec`)
Henning, nach Vorlage der ersten Spec-Fassung: Der Preisverfall (Rückfall auf Produkt-Keyword/
Kategorie-Pauschale nach 180 Tagen) sei "nice-to-have", und es sei unklar, ob die Pauschale
wirklich *besser* ist als ein 180 Tage alter, aber echter, laden- und artikelspezifischer Preis.
Berechtigt: eine generische Pauschale hat keinerlei Bezug zu Laden oder Artikel, ein alter
gelernter Preis sehr wohl. Der Rückfall ergibt erst Sinn, wenn eine tatsächlich bessere Quelle
existiert — das ist Open Prices (#49), nicht die heutige Pauschale.

**Entscheidung (PO, 2026-09-25):** Die Veraltungsregel wird komplett aus #13 entfernt und nach
#49 verschoben, wo "veraltet" gegen einen echten, aktuelleren Marktpreis fällt statt gegen eine
grobe Schätzung. #13 wird auf reine Dokumentation reduziert — keine Verhaltensänderung.

### Affected Files (with changes) — Scope von #13
| File | Change Type | Description |
|------|-------------|--------------|
| `docs/specs/models/price-estimator-stages.md` | CREATE | Reine Dokumentations-Spec für das bestehende 3-Stufen-Modell (gelernter Preis → Produkt-Keyword → Kategorie-Pauschale). Keine Verhaltensänderung. Hält fest, dass die Veraltungsregel bewusst nicht hier, sondern in #49 eingeführt wird. |
| `RestockTests/PriceEstimatorStagesTests.swift` (neu) | CREATE | Charakterisierungstests, die die heutige Stufenreihenfolge als Regressionsschutz festschreiben (kein neues Verhalten, nur Absicherung des Status quo). |

### Scope Assessment (#13)
- Files: 2 (nur Doku + neue Testdatei, keine Produktivcode-Änderung)
- Estimated LoC: ~0 Produktivcode, ~+40-60 Testcode (Charakterisierungstests), innerhalb des Scoping-Limits
- Risk Level: MINIMAL — keine Verhaltensänderung, kein Netzwerkzugriff, keine Architekturänderung, reine Dokumentation + Regressionstests für den Status quo.

### Technical Approach
Alternative 1 aus dem Kontext-Abschnitt (nur bestehende Quellen dokumentieren), reduziert um die
Veraltungsregel: nach PO-Einwand (siehe oben) bleibt von Alternative 3 ("Veraltung nutzbar
machen") in #13 nichts übrig — sie wandert komplett zu #49. #13 dokumentiert ausschließlich den
Status quo. Alternative 2 (Open Prices als weitere Stufe) bleibt wie zuvor nach #49 verschoben.

### Dependencies
1. Dokumentation des bestehenden 3-Stufen-Modells als neue Spec (keine Verhaltensänderung).
2. Charakterisierungstests, die den Status quo absichern.
3. Danach #49 (Open Prices + Veraltungsregel gegen einen dann besseren Rückfallwert), das auf der
   hier dokumentierten Stufenreihenfolge aufbaut.

### Open Questions
- [x] Rangfolge der Preisquellen für #13 → gelernter Preis → Produkt-Keyword → Kategorie-Pauschale (bestätigt, keine Änderung ggü. heutigem Code).
- [x] Veraltungsschwelle für gelernte Preise → gehört NICHT zu #13, verschoben nach #49 (PO-Entscheidung, 2026-09-25, nach Einwand: Pauschale ist kein besserer Rückfall als ein alter echter Preis).
- [x] Open Prices integrieren? → Ja, aber als eigenes Ticket #49.
- [x] Exakte Formulierung der Spec (`docs/specs/models/price-estimator-stages.md`) → siehe Spec-Datei.
