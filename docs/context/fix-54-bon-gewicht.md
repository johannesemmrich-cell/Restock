# Context: fix-54-bon-gewicht (Issue #54)

## Request Summary

Beim Bon-Import legt `ReceiptScannerView.save()` für eine Position ohne Artikel-Treffer einen neuen
`PurchaseRecord` mit `quantityAmount: line.quantity` und `unit: line.unit` an. Bei Gewichtsware ist
`line.quantity == 1` und `line.unit == ""`, obwohl die Zeile ein Gewicht trägt (`line.weightBasis`).
Belegtes Beispiel: `BANANE CHIQUITA 1,76 B` + `0,706 kg x 2,49 EUR/kg` → Ausgabenhistorie zeigt
„1 Stück, 1,76 €" statt „706 g, 1,76 €". Abgespalten von #10 (Umfangsgrenze).

## Ist-Zustand (geprüft am Code, 2026-10-01)

- **Schreibstelle:** `SmartCart/Views/Prices/ReceiptScannerView.swift:741-749` — der `else`-Zweig
  von `if let match` legt `PurchaseRecord(itemName:storeName:quantityAmount: line.quantity, unit: line.unit, actualPrice:)`
  an. `weightBasis` wird dort **nicht** gelesen.
- **Derselbe `weightBasis` wird 50 Zeilen weiter oben bereits benutzt:** `learningQuantity` (Z. 66)
  und `learningUnit` (Z. 87) lesen ihn. Das Preis-Lernen kennt das Gewicht also, der
  `PurchaseRecord` nicht — zwei Wahrheiten für dieselbe Zeile.
- **`match`-Zweig (Z. 731-740):** setzt nur `actualPrice` und `date`, **lässt Menge und Einheit des
  gefundenen Datensatzes unverändert.** Das Issue nennt ausdrücklich nur „ohne Artikel-Match";
  ob der Match-Fall mitgehört, ist offen (siehe Fragen unten).
- **Zusatzbefund `line.unit`:** Der Kommentar an `EditableReceiptLine.unit` (Z. 20) sagt „Größe aus
  dem Namen, z. B. `1,5l`, `400g`". Ein gedruckter Packungsgröße-Name (`SKYR NATUR 500G`) liefert
  also vermutlich `unit == "500g"` bei `quantity == 1` — ein Text mit Zahl darin im Feld, das
  überall sonst nur die Einheit trägt (`g`, `l`, `stk`). Nicht im Issue, aber derselbe Fehlerort.
  **Noch nicht belegt — in der Analyse am echten Lauf prüfen.**

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptScannerView.swift:15-93` | `EditableReceiptLine` — hier liegen `quantity`, `unit`, `weightBasis`, `learningQuantity`, `learningUnit`. Neue Hilfsmethode gehört **neben** diese beiden (Muster: Formel als Methode, nicht inline) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:614-759` | `save()` — die Fix-Stelle (Z. 742-748) |
| `SmartCart/Services/ReceiptParserService.swift:21,379,432` | `weightBasis` entsteht hier: `wr.weight * 1000`. **Normiert kg UND l auf 1000, die Einheit geht verloren** (laut `fix-10-preis-einheit.md`) |
| `SmartCart/Services/ReceiptParserService.swift:903-940` | `weightBasisFromName`, `packageSizeFromName(_:) -> (amount, unit)?` — liefert Menge **mit** Einheit für gedruckte Packungsgrößen |
| `SmartCart/Models/PurchaseRecord.swift:9-27` | Modell: `quantityAmount: Double = 1`, `unit: String = ""` — kein Schema-Eingriff nötig |
| `SmartCart/Models/PurchaseRecord.swift:180-215` | `PurchaseDay.collapse` — rechnet Intervalle mit `quantityAmount` + `unitKey`; unterschiedliche Einheiten werden **nicht** addiert („der spätere Kauf gilt") |
| `SmartCart/Views/Prices/PriceOverviewView.swift:101,303-305` | Ausgabenansicht — zeigt Menge nur, wenn `qty != 1` oder `unit` nicht leer; bei „1 / leer" zeigt sie gar nichts oder „1" |
| `SmartCart/Services/HabitService.swift:407` | Verbraucher der Historie (Intervallanalyse) |
| `SmartCart/Models/ShoppingItem.swift:545-560` | Liest `mostRecentMatch.quantityAmount` aus der Historie zum Preis-Nachrechnen — **falsche Menge hier verfälscht den Preis**, nicht nur die Anzeige |
| `docs/context/fix-57-menge-vorbelegen.md` | Stufe 2 der Mengen-Vorbelegung („zuletzt 706 g gekauft") liest genau diese Historie — #57 profitiert von #54 |
| `RestockTests/ReceiptParserPriceTests.swift:334-365` | Bestandstest für die Banane (`0,706 kg x 2,49`) — nutzt `learningQuantity/learningUnit`, **kein** Test auf den `PurchaseRecord`. Muss grün bleiben |
| `RestockUITests/ReceiptReviewUITests.swift` | Bestehende UI-Tests des Bon-Imports; mögliche Anbindung für den Durchlauf |

## Existing Patterns

- **Formel als Methode neben den Schwestermethoden, Test ruft dieselbe Methode** (Kommentar
  `ReceiptScannerView.swift:52-63, 70-74`). Ein Test, der die Formel nur nachbaut, fängt eine
  Regression in `save()` selbst nicht. → Neue Logik („welche Menge/Einheit trägt der Datensatz")
  als Methode an `EditableReceiptLine`, nicht inline in `save()`.
- **Einheiten-Eimer:** `ShoppingItem.unitBucket(_:)` bildet Einheiten auf Vergleichsklassen ab;
  `learningUnit` liefert `"g"` / `"stk"`. Das PurchaseRecord-Feld nutzt dagegen freie Texte
  (`"g"`, `"l"`, `""`, `"400g"`).
- **Additiv statt Schema-Bruch** (CloudKit-Zwang, `Store.swift:6-13`): hier nicht nötig, die
  Felder `quantityAmount`/`unit` existieren schon.
- **Lieber kein Wert als ein falscher** (`maxPlausibleLineTotal`): „1 Stück" ist ein erfundener
  Wert; „keine Mengenangabe" wäre ehrlicher, wenn weder Gewicht noch Stückzahl bekannt sind.

## Dependencies

- Upstream: `ReceiptParserService` (setzt `weightBasis`), `ReceiptResolutionService`
  (reicht `weightBasis` durch, Z. 33-37, 189), Review-Karte (kann `weightBasis` vom Nutzer ändern,
  `ReceiptReviewCard.swift:445, 604-634` — Gramm/Stück-Umschalter).
- Downstream: Ausgabenansicht, `PurchaseDay.collapse` → `HabitService` (Nachkaufrhythmus),
  `ShoppingItem`-Preis-Nachrechnen (Z. 545-560), künftige Mengen-Vorbelegung (#57).
- Seiteneffekt-Warnung: Gewicht statt „1 Stück" ändert die Intervallrechnung für künftig
  importierte Gewichtsware. Bestehende Datensätze bleiben „1 Stück" (Reparatur wäre #11-Kategorie,
  nicht Teil dieses Issues).

## Existing Specs

- `docs/specs/models/learned-price-unit-and-quantity-source.md` (#10) — beschreibt `learningUnit`
  und die Einheiten-Entscheidungstabelle; Quelle der Regel „Menge und Einheit gemeinsam".
- Eine Spec für den `PurchaseRecord`-Schreibweg selbst gibt es nicht (noch zu prüfen: `docs/specs/models/`).

## Risks & Considerations

1. **`weightBasis` kennt nur „g".** Eine Flüssigkeit mit Mengenzeile (`1,5 l x 1,29`) wird wie
   Gewicht auf 1500 normiert; schreibt man blind `unit: "g"`, steht „1500 g" statt „1,5 l".
   `learningUnit` hat dieselbe Vereinfachung — die Analyse muss klären, ob sie hier schadet.
2. **Review-Karte kann Gewicht ↔ Stück umschalten** (`quantityMode`): `weightBasis` kann `nil`
   werden, dann trägt `quantity` die Stückzahl. Der Fix muss beide Zustände abdecken.
3. **`match`-Zweig bleibt „1 Stück"** → derselbe Fehler könnte dort weiterbestehen, sobald der
   gefundene Datensatz aus einem Abhaken ohne Menge stammt. Umfang vs. Issue-Wortlaut klären.
4. **Umfangsgrenze:** Fix ist klein (`save()` + 1 Hilfsmethode + Tests). Reparatur alter
   Datensätze und `ReceiptParserService`-Einheitsverlust gehören **nicht** hierher.
5. **Reproduktion zuerst:** Der Fehler ist nur am echten Lauf (Bon-Import im Simulator →
   Ausgabenansicht) bewiesen, nicht aus dem Code. Der Fixture-Bon der Bestandstests enthält den
   Banane-Fall bereits; Weg laut Memory „Reproduktion ohne Code-Änderung".

## Offene Fragen für `/20-analyse`

- Zeigt der Lauf wirklich „1 Stück" (oder gar nichts — die Ansicht blendet `1`/leer evtl. aus)?
- Welche Einheit steht bei gedruckter Packungsgröße (`SKYR NATUR 500G`) tatsächlich im Datensatz?
- Reicht ein Regelweg (Gewicht → `g`, Stückzahl → `stk`, sonst nichts) — ja, kein Modell nötig;
  zu belegen am Lauf.
- Alternative zum bisherigen Weg: den Datensatz gar nicht mehr aus `line.quantity/unit`, sondern
  aus derselben Quelle wie das Preis-Lernen ableiten (`learningQuantity`/`learningUnit`) — eine
  Wahrheit statt zwei. Kippt keine ADR, vereinfacht aber `save()`.

---

## Analysis

### Type
Bug (Datenqualität beim Schreiben des Kaufdatensatzes).

### Recherche (Pflichtschritt)
Keine Fehlermeldung, keine OS-Schnittstelle, kein Fremdsystem — reine App-Logik. Eine Websuche liefert hier
nichts, was der Code nicht schon sagt; deshalb ohne Quellen. (Ehrlich benannt statt übersprungen.)

### Reproduktion — Stand und Lücke
- **Am Code belegt:** `save()` Z. 742-748 schreibt `quantityAmount: line.quantity, unit: line.unit`;
  `weightBasis` wird dort nicht gelesen. Die Fixture-Zeile `BIO-HACKFLEISCH … 400G` trägt
  `quantity: 1, unit: "400g"` (SmartCartApp.swift:362), die Brötchen-Zeile `quantity: 4, unit: ""`.
- **Am echten Lauf NICHT belegt.** Versuch: Bestandstest `testSavedReceiptDoesNotProduceOneCentItemPrice`
  im Simulator `Restock-Validate` mit Datenbank-Mitschnitt. Ergebnis: Test läuft grün durch, aber der
  Mitschnitt fand nie den Speicher der App — die App-Gruppe wird je Lauf neu angelegt und danach
  entfernt, die gefundenen Ordner waren Altlasten (0 Läden / 0 Artikel / 0 Datensätze). Ein vierter
  Lauf mit parallelen Mitschneidern schlug fehl (44 s, 1 Fehler) — vermutlich Störung durch die
  gleichzeitigen Kopierjobs, nicht untersucht.
- **Die Banane fehlt in der Fixture** (alle vier Zeilen haben `weightBasis: nil`). Der Gewichtszweig
  ist also mit der Bestandsfixture ohnehin nicht auslösbar.
- **Konsequenz:** Der Beleg „Fehler da" entsteht im Test-first-Schritt (`/40-tdd-red`): Fixture um
  `BANANE CHIQUITA` (`weightBasis: 706`, Preis 1,76, kein Artikel-Treffer) erweitern, Test geht durch
  den echten Weg (Speichern → Ausgaben-Ansicht) und muss **rot** werden mit „1 Stück/keine Menge".
  **Gate:** Wird er nicht rot, ist die Annahme falsch und der Fix wird nicht gebaut.

### Befund (Ursache, Code-Ebene — Reproduktion siehe Lücke oben)
Zwei Wahrheiten für dieselbe Zeile: das Preis-Lernen (`learningQuantity`/`learningUnit`) kennt
Gewicht und gedruckte Packungsgröße, der Kaufdatensatz liest nur `line.quantity`/`line.unit`.
Drei konkrete Fehlbilder im else-Zweig (kein Artikel-Treffer):

| Zeile | Datensatz heute | Soll |
|---|---|---|
| `0,706 kg x 2,49` (weightBasis 706) | 1 / `""` | 706 / `g` |
| `… 400G` im Namen (unit `"400g"`) | 1 / `"400g"` (Zahl im Einheitenfeld) | 400 / `g` |
| `500 ml`/`1,5l` im Namen | 1 / `"1,5l"` | 1500 / `ml` |
| `4 x 0,39` (quantity 4) | 4 / `""` | 4 / `""` (unverändert) |
| nichts bekannt | 1 / `""` | 1 / `""` (ehrlich: keine Angabe) |

Folgeschaden belegt am Code: `unitBucket("400g")` fällt in den `default`-Zweig und liefert `"400g"` — ein
eigener, unvergleichbarer Eimer; die Mengen-Vorbelegung (#57, Stufe 2) und `PurchaseDay.collapse`
(`unitKey`) können damit nichts anfangen. Risiko 1 aus dem Kontext (Liter als Gramm) ist für
`weightBasis` **entfallen**: der Parser setzt es nur für `kg`; Flüssigkeit kommt nur über den Namen
(`packageSizeFromName`, liefert `ml` korrekt).

### Alle möglichen Ursachen (und was sie ausschließt)
1. `save()` liest `weightBasis` nicht — **bestätigt am Code**.
2. Parser setzt `weightBasis` nicht — ausgeschlossen: `ReceiptParserPriceTests` (Banane) ist grün und
   das Preis-Lernen nutzt denselben Wert.
3. Review-Karte nullt `weightBasis` — nur bei Nutzer-Umschalten Gramm→Stück (gewollt, dann gilt `quantity`).
4. Ausgaben-Ansicht blendet Menge aus — nur Anzeige, `qty != 1 || !unit.isEmpty`; bei 1/leer erscheint
   **nichts** (nicht „1 Stück", wie das Issue formuliert; Wortlaut-Abweichung, Wirkung dieselbe).

### Affected Files
| File | Change | Beschreibung |
|---|---|---|
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | neue Methode `purchaseRecordQuantity(…)` neben `learningQuantity`/`learningUnit`; `save()` else-Zweig ruft sie |
| `RestockTests/…` (neue Datei, in pbxproj registrieren) | CREATE | Unit-Tests der Methode, inkl. Gegenprobe gegen `learningQuantity/learningUnit` an derselben Instanz |
| `SmartCart/SmartCartApp.swift` | MODIFY | Fixture um Bananen-Zeile (DEBUG-Seed) |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Durchstich: Speichern → Ausgaben zeigt „706 g" |
| `docs/specs/…` | CREATE | Spec |

### Scope
- Dateien: 4–5 · LoC: ca. +70 (Produktiv ~+25, Rest Test/Fixture) · Risiko: **Niedrig–Mittel**.
- Risiko: ändert Intervallrechnung (`HabitService`) für künftig importierte Gewichtsware; Bestandsdaten
  bleiben unverändert (Gewicht ist für alte Datensätze nicht rekonstruierbar — kein Reparatur-Issue möglich).
- Match-Zweig (`if let match`) bleibt unberührt, wie im Issue. Ob dort derselbe Fehler steckt, ist nicht belegt.

### Technischer Ansatz (Regelweg, kein Modell)
„Ohne Modell geht es nicht, weil …" — trifft nicht zu; reine Regel, deterministisch:
`weightBasis` → (Wert, `g`) · sonst `quantity > 1` → (quantity, `""`) · sonst
`packageSizeFromName(originalName)` → (Menge, `g`/`ml`) · sonst (1, `""`).
Reihenfolge deckungsgleich mit `learningQuantity`; Unit-Test prüft beide Methoden an derselben Instanz.
Roh-Text `line.unit` („400g") wird für den Datensatz nicht mehr verwendet.

**Alternative (echte):** `learningQuantity`/`learningUnit` direkt wiederverwenden („eine Wahrheit").
Verworfen, weil `learningUnit` Flüssigkeit als `"g"` führt (500 ml würde „500 g") und für `quantity>1`
`"stk"` statt leer liefert. Kippt keine ADR.
**Zweite Alternative:** gar keine Menge speichern, wenn nur die Packungsgröße aus dem Namen stammt
(Gewicht ≠ gekaufte Menge: „Skyr 500G" ×1 ist ein Stück). Das ist die fachlich offene Frage unten.

### Offene Fragen (technisch, von Claude entschieden — Empfehlung)
- [x] Packungsgröße aus dem Namen im Datensatz: **ja** („500 g" ist die Mengenangabe, die #57 Stufe 2
      braucht; sie ist ehrlicher als „1 Stück"). Gegenargument oben genannt.
- [ ] Reproduktion am echten Lauf — bindend in `/40-tdd-red` (Gate s. o.).
