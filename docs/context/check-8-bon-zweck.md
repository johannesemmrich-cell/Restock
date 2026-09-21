# Context: check-8-bon-zweck (Issue #8)

## Request Summary
Henning fragt, welchem Zweck das Einlesen von Kassenbons überhaupt dient — und ob dabei
(a) mehrere Artikel je Zeile und (b) Kilo-/Grundpreise korrekt erkannt werden. Ergebnis der
Prüfung ist zunächst ein Befund mit Alternativen, keine Änderung.

## Die Kette in vier Schritten

| Schritt | Ort | Was passiert |
|---|---|---|
| 1. Aufnahme | `ReceiptScannerView` (Kamera/Fotobibliothek), `RestockShareExtension/ShareViewController` (Bild aus fremder App, z. B. Lidl+) | Vision-OCR, `reconstructLines` gruppiert Textblöcke nach Bildzeile |
| 2. Parsen | `ReceiptParserService` (1310 LoC) | Rohzeilen → `ReceiptLine { name, price, quantity, unit, weightBasis }` |
| 3. Auflösen | `ReceiptResolutionService` (5 Stufen), `ReceiptAliasService` | OCR-Kürzel → echter Artikelname; Stufe 1 gelernter Alias … Stufe 5 Apple Intelligence |
| 4. Lernen | `ReceiptScannerView.save()` (Zeile ~605–650) | schreibt `store.learnedPrices` (pro Einheit), `item.estimatedPrice`, `PurchaseRecord.actualPrice` |

## Der behauptete Zweck — wo die Daten sichtbar werden

- **Budget des aktuellen Einkaufs**: `PriceOverviewView` summiert `estimatedLineTotal` der offenen
  Artikel („X Artikel mit bekannten Preisen").
- **Preis am Listeneintrag**: `ItemRow` zeigt `estimatedLineTotal` — bei abgehakten Artikeln nur
  dann, wenn der Preis eine echte Herkunft hat (`estimatedPriceIsAutoDerived == false`).
- **Ausgabenhistorie**: `PriceOverviewView` gruppiert `PurchaseRecord.actualPrice` nach Einkauf,
  Laden und Monat (inkl. Diagramm).

## Relevante Dateien

| Datei | Relevanz |
|---|---|
| `SmartCart/Services/ReceiptParserService.swift` (1310) | Kern: Mengen-, Gewichts- und Storno-Erkennung, Formaterkennung Lidl/Rewe |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` (810) | Review-UI **und** `save()` — die einzige Stelle, die Bon-Daten dauerhaft schreibt |
| `SmartCart/Services/ReceiptResolutionService.swift` (219) | Namensauflösung, geteilt zwischen App und Teilen-Erweiterung |
| `SmartCart/Services/ReceiptAliasService.swift` (74) | gelernte Kürzel aus Nutzerkorrekturen |
| `SmartCart/Services/ReceiptShareHandoff.swift` (43) | Übergabe Erweiterung → App über App-Gruppe |
| `SmartCart/Models/ShoppingItem.swift` | `estimatedPrice` (pro Einheit), `estimatedLineTotal`, `PriceEstimator`, `PriceProvenanceMigration` |
| `SmartCart/Models/Store.swift` | `learnedPrices` / `learnedPriceDates` |
| `SmartCart/Views/Prices/PriceOverviewView.swift` (371) | einziger Ort, an dem die Ausgabenhistorie sichtbar wird |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` (232) | **konkurrierender** Weg: Gesamtsumme eintippen, proportional verteilen |
| `SmartCart/Services/SyncCoordinator.swift`, `SharedStoreService.swift` | mischen `learnedPrices` zwischen Mitgliedern geteilter Listen |

## Bestehende Muster

- **Preis pro Einheit ist kanonisch.** `learnedPrices` und `estimatedPrice` halten immer eine Rate
  pro Einheit; `estimatedLineTotal` multipliziert erst bei der Anzeige mit `quantityAmount`.
- **Menge und Gewicht sind bewusst getrennt.** `quantity` = Stückzahl („4 Stk x 0,39", Multipack
  „6X1.5L"), `weightBasis` = Gewicht in Gramm („0,706 kg x 2,49 EUR/kg"). Gewicht landet
  absichtlich NICHT in `quantity`.
- **Die Umrechnung sitzt in einer einzigen Funktion**: `EditableReceiptLine.learningQuantity` —
  `weightBasis ?? (quantity > 1 ? quantity : (matchQuantityAmount ?? weightBasisFromName ?? 1))`.
  Danach `perUnitPrice = line.price / quantity`.
- **Drei Preisquellen konkurrieren**: Katalogschätzung (`PriceEstimator`), manuelle Gesamtsumme
  (`ActualPriceEntryView`), Bon-Scan. Nur die letzten beiden setzen
  `estimatedPriceIsAutoDerived = false`.
- Dieselbe Erkennungslogik läuft in zwei Prozessen (App + Erweiterung) — deshalb sind
  Auflösung und Parsing aus der View ausgelagert und `Codable`.

## Dependencies

- **Upstream**: Vision (OCR), FoundationModels/Apple Intelligence (Stufe 5 der Auflösung),
  SwiftData, App-Gruppe für den Handoff.
- **Downstream**: `ShoppingItem.init` (Preis-Seed neuer Artikel), `ItemRow`, `PriceOverviewView`,
  `ActualPriceEntryView`, `SyncCoordinator`/`SharedStoreService` (verteilt gelernte Preise an
  andere Mitglieder), `PriceProvenanceMigration`.

## Einstiegspunkte für den Nutzer

- Bon scannen: nur aus der Liste eines Ladens (`StoreDetailView`, Kamerasymbol).
- Bild teilen: aus fremder App über die Teilen-Erweiterung → `HomeView` öffnet den Scanner.
- Gesamtsumme eintippen: ebenfalls `StoreDetailView`.
- Ausgabenübersicht: `HomeView` → `PriceOverviewView`.

## Bestehende Tests

`RestockTests/Receipt*.swift` + `PriceProvenanceMigrationTests.swift` ≈ 1160 Zeilen.
Beide Fragen aus Issue #8 sind namentlich abgedeckt, u. a.:
`testWeightLineSetsGramWeightBasisNotQuantity`, `testPieceCountLineSetsQuantityNotWeightBasis`,
`testBarePriceTimesCountLearnsPerUnitPriceNotLineTotal`,
`testFlatPricePackagedItemWithoutWeightLineLearnsCorrectPerGramPrice`,
`testWeightBasisFromNameHandlesKgLiterAndCentiliterUnits`.
→ Die Analyse muss also nicht „gibt es das?" klären, sondern „trägt es in der Praxis?".

## Risiken & offene Punkte für /20-analyse

1. **Zweck-Verhältnis.** Rund 2.500 Zeilen Erkennungscode plus eine eigene Teilen-Erweiterung
   dienen zwei Anzeigen (Budget, Ausgabenhistorie). Der manuelle Weg (Gesamtsumme eintippen)
   liefert die Ausgabenhistorie mit einem Bruchteil des Aufwands. Echte Alternativen ernsthaft
   prüfen — auch „Bon-Scan reduzieren oder streichen".
2. **Belegter Datenschaden in genau diesem Bereich.** `PriceProvenanceMigration` existiert, weil
   früher Gesamtpreise als Preis-pro-Einheit gespeichert wurden (Pro-Gramm-Fehler). Falsch
   gelernte Preise sind dauerhaft und werden über `SyncCoordinator` an andere Mitglieder verteilt.
3. **`learningQuantity` mischt vier Quellen** (Gewicht, Stückzahl, historische Menge, Name) in
   einer Zeile. Reihenfolgefehler wären schwer zu bemerken und direkt datenschädlich.
4. **`looseMatch` ist unscharf** (reines `contains`, nur durch eine LCS-Schwelle gebremst) —
   ein Bonpreis kann auf einem fremden Artikel landen.
5. **Auffindbarkeit**: Der Scan ist nur in der Liste eines einzelnen Ladens erreichbar. Wenn der
   Zweck „Ausgaben im Blick" ist, ist das ein ungünstiger Ort.
6. **Kein bestehender Spec** zu diesem Bereich (`docs/specs/` enthält nur `shared-model-container.md`).

## Messgröße, die der Analyse fehlt
Wie oft wird real gescannt und wie viele Positionen je Bon werden korrekt erkannt? Dazu gibt es
heute keine Zahl. Die Analyse sollte sie an echten Bons erheben, statt den Nutzen zu behaupten.

---

# Analysis

## Type

**Prüfung mit Befund** (weder Bug noch Feature im engeren Sinn). Ergebnis ist eine
Entscheidungsgrundlage für Henning, keine Änderung. Die konkreten Arbeitspakete hängen davon ab,
welche der Alternativen unten gewählt wird.

## Die beiden Fragen aus Issue #8 — beantwortet und belegt

Beide Fragen haben **keine einheitliche Antwort**. Sie hängt am Bonformat:

| Bonformat | Mehrere Artikel erkannt? | Kilo-/Grundpreis erkannt? |
|---|---|---|
| **Lidl-Stil** (Namenszeile ohne Preis, Menge/Gewicht in der Folgezeile) | **Ja** | **Ja** |
| **Rewe-eBon-Stil** (Preis steht schon auf der Namenszeile) | **Nein** | **Nein** |
| Carrefour/französisch | Stückzahl ja, Gewicht nein | **Nein** (nur `kg`/`stk`) |
| Aldi, Edeka, Netto, Kaufland | ungeprüft — kein Testfixture vorhanden | ungeprüft |

### Beweis für den Rewe-Fall (ausgeführt, nicht behauptet)

Eine temporäre Sonde im bestehenden Testfixture `ReceiptParserReweTests` (nach dem Lauf wieder
entfernt, Arbeitskopie ist sauber) ergab für den echten Rewe-Bon:

```
PROBE broetchen: price=1.56 quantity=1.0 weightBasis=nil unitPrice=1.56
PROBE banane:    price=1.76 quantity=1.0 weightBasis=nil unitPrice=1.76
```

Die Bonzeilen dazu lauten `"LAUGENBROETCHEN 1,56 B"` / `"4 Stk x 0,39"` und
`"BANANE CHIQUITA 1,76 B"` / `"0,706 kg x 2,49 EUR/kg"`. Die Stückzahl **4** und das Gewicht
**706 g** stehen wörtlich auf dem Bon und kommen im Ergebnis nicht an.

### Ursache

`ReceiptParserService.droppingRedundantQuantityConfirmationLines` (`:189-200`) **löscht** die
Mengen-/Gewichtszeile aus dem Zeilenstrom, bevor der Parser überhaupt läuft — immer dann, wenn die
vorherige Zeile schon Name + Preis + Steuerkennzeichen trägt. Die Absicht war, Phantom-Positionen
zu verhindern (Kommentar `:172`: „beobachtet: '4 Stk x 0,39' wurde selbst zu einer Position"). Der
Zeilenpreis bleibt dabei korrekt — aber Stückzahl und Gewicht sind weg.

### Folge: falsch gelernte Preise

`ReceiptScannerView.save()` (`:611-613`) rechnet `perUnitPrice = line.price / learningQuantity`.
Ohne `weightBasis` und mit `quantity == 1` fällt `learningQuantity` (`:58-60`) auf die Menge des
zufällig gematchten Listenartikels bzw. auf eine Zahl aus dem Artikelnamen zurück:

- **Laugenbrötchen:** gelernt werden **1,56 € pro Stück** statt 0,39 € — Faktor 4 zu hoch.
- **Banane:** gelernt werden **1,76 € pro Stück** statt 2,49 €/kg — die Einheit kippt still.
- **Konstruktion „GEHACKT 500G 1,76 A" + gelöschte Zeile „0,706 kg x 2,49":** der Name liefert
  500 g, tatsächlich waren es 706 g → gelernt 3,52 €/kg statt 2,49 €/kg, **41 % zu hoch**.

Die bestehenden Tests fangen das nicht: `testQuantityAndWeightFollowupLinesDoNotOverrideAlready­KnownTotal`
(`ReceiptParserReweTests.swift:73-81`) prüft ausschließlich `price`, nie `quantity` oder `weightBasis`.

## Weitere Befunde

### 1. Die Ausgaben-Übersicht zeigt gescannte Bons nie an

`PriceOverviewView.swift:35-44` rendert den Abschnitt „Kassenbons" **unbedingt** als leeren
Platzhalter — auch nach erfolgreichen Scans. Der Hinweistext verweist zudem auf ein
„Kamera-Symbol oben rechts", das es in `StoreDetailView` nicht gibt: Der Scan steckt im
Drei-Punkte-Menü (`StoreDetailView.swift:322`), erscheint nur bei bereits abgehakten Artikeln und
ist kostenpflichtig. Der prominenteste Ort für den behaupteten Nutzen ist damit tote UI.

### 2. Der gelernte Preis trägt keine Einheit

`Store.learnedPrices` ist ein `[String: Double]` ohne Einheitsfeld (`Store.swift:27`). Ob
`0,002493` „pro Gramm" oder `1,76` „pro Stück" bedeutet, ergibt sich erst aus dem Kontext eines
späteren Artikels. Genau dieser Konstruktionsfehler hat den „Skyr 500 g → 1145 €"-Bug erzeugt.
`PriceProvenanceMigration` (`ShoppingItem.swift:364-425`) repariert die **Altdaten** — die Ursache
besteht unverändert fort.

### 3. Falsche Preise verbreiten sich ungeprüft an Mitglieder

`SyncCoordinator.swift:229-235` und `SharedStoreService.swift:141-155` übernehmen einen fremden
Preis allein nach Zeitstempel. Keine Plausibilitätsprüfung, kein Vergleich mit dem bisherigen Wert.
Ein falsch gelernter Kilopreis wandert in jede geteilte Liste.

### 4. Der `PurchaseRecord` verliert das Gewicht ganz

`ReceiptScannerView.swift:644-651` legt neue Kaufdatensätze mit `quantityAmount: line.quantity`
(= 1) und `unit: line.unit` (= `""`) an — nicht mit dem erkannten Gewicht. In der
Ausgabenhistorie steht für 706 g Bananen „1 Stück, 1,76 €".

### 5. Kein Test berührt den produktiven Speicherpfad

140 Unit-Tests laufen, alle grün (ausgeführt, iPhone-17-Simulator, 0 Fehlschläge). Aber `save()`
ist privat und Teil einer SwiftUI-View; kein Test ruft sie auf. `ReceiptParserPriceTests.swift:131-139`
dokumentiert selbst, dass die dortige Formelkopie „eine Regression in `save()` selbst NICHT bemerkt".
Es gibt außerdem kein einziges echtes Bonbild und keinen echten OCR-Rohtext als Fixture — alle
Tests arbeiten mit handgetipptem Text (`ReceiptParserLidlFullReceiptTests.swift:10-16`: „KEIN
tatsächlicher Vision-Rohdump").

### 6. Aufwand gegen Nutzen

| | Zeilen |
|---|---|
| Bon-Scan (Implementierung + Teilen-Erweiterung) | 2.812 |
| Bon-Scan (Tests) | 1.237 |
| **Bon-Scan gesamt** | **4.049** |
| Manuelle Preiseingabe (`ActualPriceEntryView`) | 232 |

Verhältnis **17 : 1**. `ReceiptParserService.swift` allein hat 18 Commits, davon trägt der Großteil
„fix:" im Titel. Es gibt **keinerlei Telemetrie** im Projekt — keine Zahl dazu, wie oft gescannt
wird oder wie gut es trifft.

Ausschließlich der Bon-Scan liefert: echte Einzelpreise statt verteilter Anteile, die Füllmenge aus
dem Bontext, Kaufdatensätze für Spontankäufe, und die automatische Ladenerkennung. Das ist der
echte Mehrwert — er hängt aber genau an der Mengen-/Gewichtserkennung, die im Rewe-Fall nicht trägt.

## Scope Assessment

- Dateien: abhängig von der Entscheidung (siehe Alternativen), 1–5
- Geschätzte LoC: +30/−5 (Alternative A) bis +150/−2.900 (Alternative C)
- Risiko: **Mittel bis Hoch** — jede Änderung am Lernpfad schreibt dauerhafte Daten, die über die
  Synchronisation an andere Mitglieder wandern und nur durch eine weitere Migration korrigierbar
  sind. Das ist in genau diesem Bereich schon einmal passiert.

## Alternativen

### A — Die gelöschte Zeile auswerten statt wegwerfen (kleinster Eingriff)

`droppingRedundantQuantityConfirmationLines` übernimmt Stückzahl und Gewicht in die vorherige
Position, statt die Zeile zu verwerfen. Der Zeilenpreis bleibt unangetastet, die Phantom-Position
wird weiterhin verhindert. Betrifft ~2 Dateien, ~30 Zeilen. Löst Hennings beide Fragen für das
Rewe-Format. Löst **nicht** die fehlende Einheit im Datenmodell.

### B — A plus Einheit am gelernten Preis

Zusätzlich bekommt `learnedPrices` eine mitgeführte Einheit, sodass „pro Gramm" und „pro Stück"
unterscheidbar werden. Beseitigt die Ursache hinter `PriceProvenanceMigration`. Kippt die
implizite Entscheidung „Preis pro Einheit ist kanonisch, Einheit ergibt sich aus dem Kontext".
Braucht eine weitere Datenmigration — in einem Bereich mit belegtem Datenschaden.

### C — Bon-Scan auf das reduzieren, was er beweisbar kann

Der Scan liefert zuverlässig **Artikelnamen und Zeilenpreise**. Beim Mengen-/Gewichtsteil ist er
formatabhängig. Möglich wäre: Bon-Scan füllt die Ausgabenhistorie (Name + Zeilenpreis, das trägt),
schreibt aber **keine gelernten Pro-Einheit-Preise** mehr. Das Preislernen übernimmt allein die
manuelle Eingabe. Spart auf Dauer den Großteil der 18 Fix-Commits und entschärft den
Datenschaden-Pfad vollständig. Kippt die ADR „Bon-Scan lernt Preise".

### D — Erst messen, dann entscheiden

Bevor irgendetwas geändert wird: eine schlichte Zählung einbauen (wie viele Positionen je Scan,
wie viele mit Menge/Gewicht, wie oft überhaupt gescannt). Kostet ~40 Zeilen. Danach ist die
Zweck-Frage mit Zahlen statt mit Vermutungen zu beantworten. Nachteil: verzögert den Fix der
belegten Fehlerkette um eine Nutzungsperiode.

**Empfehlung: A zuerst, danach D.** Die Fehlerkette ist belegt und schädigt Daten dauerhaft —
sie zu schließen sollte nicht auf eine Messung warten. Die grundsätzliche Zweck-Frage (C) ist eine
Produktentscheidung und sollte auf Zahlen stehen, nicht auf meinem Eindruck.

## Dependencies

`ReceiptParserService` → `ReceiptScannerView.save()` → `Store.learnedPrices` /
`ShoppingItem.estimatedPrice` / `PurchaseRecord.actualPrice` → `SyncCoordinator` /
`SharedStoreService` (verteilt an Mitglieder) → `ItemRow`, `PriceOverviewView`,
`PriceProvenanceMigration`.

## Open Questions (PO-Entscheidung nötig)

- [ ] Welche Alternative (A / B / C / D) wird verfolgt?
- [ ] Soll die tote „Kassenbons"-Sektion in der Ausgaben-Übersicht entfernt oder mit echten Bons
      gefüllt werden?
- [ ] Sollen bereits falsch gelernte Preise nachträglich korrigiert werden (weitere Migration),
      oder reicht es, ab jetzt richtig zu lernen?

---

## Reihenfolge korrigiert (2026-09-21)

Ich hatte am 2026-09-21 vorschnell nach der technischen Richtung gefragt (Mengen retten /
Einheit speichern / Preislernen abschalten / erst messen) und aus den Antworten einen
Ticket-Zuschnitt abgeleitet. Henning hat das gestoppt: **Zuerst muss der Zweck des Features
definiert sein.** Die damaligen Antworten (B / Bons auflisten / Altdaten korrigieren) sind
damit hinfaellig — sie beantworteten die falsche Frage. Es wurden keine Tickets angelegt.

Die Zweck-Definition ist eine PO-Entscheidung. Was ich dazu beitragen kann, steht unten.

## Material fuer die Zweck-Entscheidung

### Was der Bon-Scan heute beweisbar leistet

| Faehigkeit | Stand |
|---|---|
| Artikelnamen von der Kassenzeile lesen | traegt (fuenfstufige Aufloesung inkl. gelernter Kuerzel) |
| Zeilenpreis lesen | traegt |
| Laden automatisch erkennen | traegt |
| Stueckzahl / Gewicht lesen | **formatabhaengig** — Lidl ja, Rewe nein, Aldi/Edeka/Netto/Kaufland ungeprueft |
| Daraus einen korrekten Preis pro Stueck bzw. pro Kilo lernen | **nein**, solange das Vorige nicht traegt |

### Was er kostet

4.049 Zeilen gegen 232 Zeilen des manuellen Wegs. 18 Aenderungen allein am Erkennungs-Kern,
ueberwiegend Fehlerbehebungen. Keine Telemetrie — es gibt keine Zahl zur tatsaechlichen Nutzung.

### Moegliche Zwecke — sie fuehren zu verschiedenen Produkten

1. **Ausgaben im Blick behalten.** Braucht Name + Zeilenpreis + Datum + Laden. Das traegt heute
   schon. Der manuelle Weg leistet dasselbe mit einem Bruchteil des Aufwands; der Scan spart
   Tippen und erfasst zusaetzlich Spontankaeufe, die nie auf der Liste standen.
2. **Budget des naechsten Einkaufs abschaetzen.** Braucht einen korrekten Preis PRO EINHEIT,
   also genau die Faehigkeit, die heute formatabhaengig scheitert. Anspruchsvollster Zweck.
3. **Preise zwischen Laeden vergleichen.** Braucht Preis pro Einheit plus die Einheit selbst —
   beides fehlt im Datenmodell.
4. **Tippen sparen.** Dann zaehlt vor allem die Namenserkennung; Preise waeren Beiwerk.

Jeder dieser Zwecke rechtfertigt einen anderen Zuschnitt — und Zweck 1 und 4 rechtfertigen den
heutigen Erkennungsaufwand nicht.

## Open Questions (PO-Entscheidung, blockierend)

- [ ] **Welchem Zweck soll das Einlesen von Kassenbons dienen?** Erst danach ist entscheidbar,
      ob und wie die belegte Mengen-/Gewichtsluecke geschlossen wird.

---

## Zweck-Antwort des PO (2026-09-21)

Henning zu den vier Zwecken:

1. **Ausgaben im Blick** — verworfen: „geht besser über das Bank-Konto".
2. **Budget abschätzen** — „könnte helfen".
3. **Preise zwischen Läden vergleichen** — „starkes Argument, insbesondere wenn wir es schaffen,
   User-generated Content zu aggregieren."
4. Rückbau — nicht gewählt.

Zusatzbefund von Henning: „Es ergibt keinen Sinn, dass aktuell alle Artikel 2,50 € kosten."
Dazu die Frage: **Gibt es Quellen im Internet für bessere Preisschätzungen?**

### Befund zu „alle Artikel 2,50 €"

Bestätigt. `PriceEstimator.estimate` (`ShoppingItem.swift:247-330`) kennt **33 fest verdrahtete
Produktpreise** und fällt sonst auf **26 Kategorie-Pauschalen** zurück. Die beiden häufigsten
Lebensmittel-Kategorien — „Obst & Gemüse" (`:303`) und „Lebensmittel" (`:312`) — stehen beide auf
exakt **2,50 €**. Alle Werte sind Konstanten im Quelltext: ohne Datum, ohne Region, ohne
Inflationsbezug, seit Einführung unverändert.

### Recherche: Preisquellen (2026-09-21, vorher nie untersucht)

Im Projekt existiert dazu **keine frühere Analyse** — weder in `docs/`, noch in den Issues.
Open Food Facts wird bereits genutzt, aber nur für Produktnamen per Barcode
(`BarcodeScannerView.swift:100`), nicht für Preise.

**1. Open Prices (Open Food Facts) — https://prices.openfoodfacts.org**

Offene, crowdgesammelte Preisdatenbank. Selbst abgefragt am 2026-09-21, ohne Anmeldung:

| Kennzahl | Wert |
|---|---|
| Preise weltweit | 314.450 |
| Läden weltweit | 7.298 |
| Läden in Deutschland | **1.064** (Platz 2 nach Frankreich mit 2.497) |
| Preise in Deutschland | **16.736** |
| Größte deutsche Quellen | Netto, EDEKA, Netto Marken-Discount |

Abfrage per Barcode funktioniert und liefert Preis, Währung, Datum, Laden und Land
(`/api/v1/prices?product_code=<EAN>&order_by=-date`). Lesen braucht keine Anmeldung. Beiträge
verlangen ein Open-Food-Facts-Konto und einen **Beleg als Foto — Preisschild oder Kassenbon**.

Das ist genau das von Henning genannte „User-generated Content aggregieren" — es existiert bereits,
Restock könnte lesen **und** beitragen. Die App scannt Barcodes ohnehin schon.

**Einschränkung, ehrlich benannt:** 16.736 Preise verteilt auf 1.064 deutsche Läden sind für das
Sortiment eines Supermarkts dünn. Die Trefferquote je einzelnem Artikel ist niedrig; die Quelle
taugt als Ergänzung, nicht als Alleinversorgung.

**2. Destatis GENESIS-Online — https://genesis.destatis.de**

Amtliche Durchschnittspreise und Verbraucherpreisindex, REST/JSON, kostenfrei, Datenlizenz
Deutschland – Namensnennung 2.0. Liefert keine Einzelprodukte, aber datierte, offizielle
Durchschnitte je Warengruppe. Damit ließen sich die 26 eingefrorenen Kategorie-Pauschalen durch
regelmäßig aktualisierte, inflationsbereinigte Werte ersetzen — **rein deterministisch, ohne
Sprachmodell.**

**3. preis-daten.de** — kommerzieller Anbieter, Preisabfragen per API. Nicht geprüft, kostenpflichtig.

**4. Supermarkt-Apps abgreifen** — technisch möglich, aber undokumentiert, rechtlich fragwürdig
und brüchig. Nicht zu empfehlen.

### Regelweg vor Modellweg

Beide tragfähigen Quellen sind Daten und Regeln, kein Sprachmodell: Destatis liefert die Nulllinie
(amtlicher Durchschnitt je Kategorie, datiert), Open Prices den Einzelfall (echter beobachteter
Preis je Barcode). Der heutige Zustand — 59 handgeschriebene Konstanten ohne Datum — ist beiden
unterlegen.

### Verbindung zurück zu Issue #8

Der Bon-Scan wäre unter Zweck 3 nicht mehr nur Selbstzweck, sondern **Beitragsquelle**: ein Bon
liefert echte Preise mit Beleg. Das setzt aber genau die Kette voraus, deren Lücke oben belegt ist
(Stückzahl/Gewicht → Preis pro Einheit → Einheit mitführen). Zusätzlich wäre es eine
Datenschutz-Entscheidung, ob Preis- und Ladendaten das Gerät verlassen — die App hält heute alles
privat (eigene iCloud, kein Backend).

## Open Questions (PO)

- [ ] Wird Zweck 3 (Preisvergleich / bessere Schätzungen) als Leitzweck gesetzt?
- [ ] Sollen Preisdaten das Gerät verlassen dürfen (Beitrag an Open Prices)?
- [ ] Sofort umsetzbar und unabhängig: Kategorie-Pauschalen durch Destatis-Werte ersetzen.

---

## Leitzweck gesetzt (Henning, 2026-09-21)

**Phase 1:** Bessere Preise → dadurch belastbare Schätzung der Einkaufssumme.
**Phase 2:** Preisvergleich — „Was spare ich wahrscheinlich durch Wahl eines anderen Geschäfts?"

Preisdaten **dürfen das Gerät verlassen** (Beitrag an Open Prices ist damit freigegeben).

## Punkt 4: Regelwerk statt LLM bei der Bon-Verarbeitung

### Wo heute überhaupt ein Modell läuft

Genau **eine** Stelle: Stufe 5 der Namensauflösung (`ReceiptNameAIResolver`,
`ReceiptParserService.swift:1229-1310`). Das Parsen selbst (Preise, Mengen, Gewicht, Storno,
Pfand, Formaterkennung, Ladenerkennung) ist vollständig regelbasiert — dort ist nichts zu holen.

Stufe 5 greift nur, wenn die Stufen 1–4 alle nichts liefern, und hat genau eine Aufgabe:
ein unbekanntes OCR-Kürzel zu einem Produktnamen ausschreiben. Sie läuft on-device, mit
25-Sekunden-Abbruch, und nie in der Teilen-Erweiterung (Speicherlimit).

### Das Projekt dokumentiert bereits zwei Fälle, in denen die Regel gewonnen hat

1. **13.08.2026** (`ReceiptParserService.swift:1017-1022`): Das Modell machte aus
   „Hakle ToiPa Traumweich 8x130Bl" eine **„Flaschenbürste"** statt Toilettenpapier. Behoben durch
   *einen* Wörterbucheintrag. Der Kommentar im Code sagt es selbst: „ein deterministischer
   Wörterbuch-Treffer hier schaltet die unzuverlässige KI-Stufe für diesen sehr verbreiteten
   Artikel komplett aus, statt sie zu korrigieren."
2. **24.08.2026** (`ReceiptParserService.swift:1236-1241`): Vier erfundene
   „Pizza Baguette"-Positionen, deren Preise exakt der MwSt-Tabelle und der Bon-Summe entsprachen.
   Das Modell musste für jeden Text, der Stufe 5 erreicht, *etwas* erfinden. Behoben durch einen
   Prompt-Ausweg (`KEIN_PRODUKT`) — also durch **noch mehr Modell**, obwohl eine Steuer-,
   Summen- oder Zahlungszeile deterministisch erkennbar ist und `isAdminLine` dafür bereits
   existiert. Hier wurde ein Regelproblem mit einem Prompt zugedeckt.

### Was sich durch Regeln besser erfassen lässt — konkret

**a) Der eigene Wortschatz wird gebaut, aber nie als Regel benutzt.**
`ReceiptResolutionService.knownItemNames` (`:200-215`) stellt aus Kaufhistorie und aktueller
Liste **40 eigene Artikelnamen** zusammen — und reicht sie ausschließlich als unverbindlichen
Hinweis in den Prompt („bevorzuge eine Übereinstimmung, falls plausibel"). Ein deterministischer
Abgleich gegen dieselben 40 Namen findet nicht statt, obwohl mit `lcsSimilarity`
(`ReceiptParserService.swift:1092+`) die passende Funktion bereits im Haus ist und in Stufe 3
genau dafür verwendet wird. **Dieselben Daten, einmal als Regel und einmal als Prompt-Hinweis —
nur der Prompt-Weg ist verdrahtet.** Das ist der größte und billigste Hebel.

**b) Stufe 4 sucht nur im selben Laden.**
`historyMatch(for:in:storeName:)` filtert die Kaufhistorie auf den aktuellen Laden. Wer denselben
Joghurt sonst bei Rewe kauft und diesmal bei Lidl, fällt unnötig auf das Modell durch. Die
Ausweitung auf alle Läden (mit dem Laden als Rangkriterium statt als Filter) ist eine reine
Regeländerung.

**c) Das Abkürzungswörterbuch ist ein Startsatz.**
21 Kürzel plus 4 Mehrwort-Phrasen (`:1011-1036`). Bewusst konservativ gehalten — aber es wächst
nur, wenn jemand einen Fehler meldet. Mit Open Prices und Open Food Facts stehen ab jetzt echte
deutsche Produktnamen als Quelle zur Verfügung, aus denen sich das Wörterbuch datengetrieben
erweitern lässt statt einzeln per Bugreport.

**d) Verwaltungszeilen gehören in den Filter, nicht in den Prompt.**
Der `KEIN_PRODUKT`-Ausweg behandelt ein Symptom. Jede Zeile, die das Modell als Nicht-Produkt
einstufen soll, hätte `isAdminLine` vorher aussortieren müssen. Der Prompt-Ausweg kann bleiben
(Sicherheitsnetz), aber die Fälle gehören gezählt und in Regeln überführt.

### Die Nulllinie fehlt

Es gibt **keine Messung**, wie oft Stufe 5 überhaupt anspringt und wie oft ihr Ergebnis richtig
ist. Ohne diese Zahl ist jede Aussage über den Nutzen des Modells Behauptung — meine eingeschlossen.
Erster Arbeitsschritt des zugehörigen Tickets ist daher, die Durchfall-Quote je Stufe zu zählen,
nicht der Umbau.

### Empfehlung

Reihenfolge: (1) Quote messen → (2) Punkt a) umsetzen (Wortschatz als Regel, vor Stufe 5) →
(3) Punkt b) → (4) erneut messen. Bleibt danach ein Rest, für den nur ein Sprachmodell taugt,
darf Stufe 5 bleiben. Fällt die Quote gegen null, entfällt sie samt Zeitbudget und Sonderweg für
die Teilen-Erweiterung.

---

## Angelegte Tickets (2026-09-21)

| # | Inhalt | Hängt ab von |
|---|---|---|
| #9 | Stückzahl/Gewicht beim Rewe-Format gehen verloren (Fehler, belegt) | — |
| #10 | Einheit am gelernten Preis mitführen | #9 |
| #11 | Bereits falsch gelernte Preise korrigieren | #9, #10 |
| #12 | Kategorie-Pauschalen durch Destatis-Werte ersetzen | — |
| #13 | Open Prices beim Barcode-Scan abfragen | — |
| #14 | Regelwerk statt Sprachmodell bei der Namenserkennung (erst messen) | — |
| #15 | Phase 2: Preisvergleich zwischen Geschäften | #9, #10, #12, #13 |

#8 bleibt als Prüfungs-Ticket offen und trägt das Ergebnis als Kommentar.

**Sofort startbar, unabhängig voneinander:** #9, #12, #13, #14.

Prüfung damit abgeschlossen.
