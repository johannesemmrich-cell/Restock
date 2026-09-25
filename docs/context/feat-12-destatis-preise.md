# Context: feat-12-destatis-preise (Issue #12)

## Request Summary
`PriceEstimator.estimate` (`SmartCart/Models/ShoppingItem.swift:204-330`) schätzt Artikelpreise über 32 fest verdrahtete Produkt-Keywords + 26 Kategorie-Pauschalen (insgesamt 58 Konstanten, im Ticket auf 59 gerundet). Zwei der häufigsten Kategorien ("Obst & Gemüse", "Lebensmittel") liegen beide bei exakt 2,50 €, ohne Datum, Region oder Inflationsbezug. Ersetzt werden sollen diese Konstanten durch amtliche, datierte Durchschnittspreise von Destatis GENESIS-Online, zur Bauzeit eingebacken (kein Laufzeit-Fetch).

## Related Files
| File | Relevance |
|---|---|
| `SmartCart/Models/ShoppingItem.swift:204-330` | `enum PriceEstimator` — Kernstück: `specificPrices`-Liste (32 Produkt-Keywords) + `switch category` (26 Kategorie-Pauschalen) + `unitDivisor`. Hier werden die Konstanten ersetzt. |
| `SmartCart/Services/AssignmentService+Category.swift:219-225` | `categoryOrder` — die maßgebliche Liste der 26 Kategorienamen, auf die `PriceEstimator`s `switch category` 1:1 abgestimmt sein muss (String-exakt, unlokalisiert). |
| `SmartCart/Views/Store/EditItemView.swift:375,384` | Einziger Aufrufer von `PriceEstimator.estimate` außerhalb von `ShoppingItem.swift` selbst (Neuschätzung beim manuellen Bearbeiten eines Artikels). |
| `SmartCart/Views/Settings/LegalView.swift` | Enthält die bestehende Namensnennung für Open Food Facts (im Datenschutzabschnitt "Barcode-Scanner"). Muster für eine neue Destatis-Namensnennung — dort ist es aber ein Datenschutz-Absatz (personenbezogene Daten verlassen das Gerät); Destatis-Werte sind zur Bauzeit eingebacken, es fließen keine Daten zur Laufzeit. Die Namensnennungspflicht aus "Datenlizenz Deutschland – Namensnennung 2.0" ist trotzdem einzuhalten, gehört aber eher zu Quellenangaben/Impressum als zum Datenschutz-Abschnitt. |

## Existing Patterns
- **Alle bisherigen "eingebackenen" Datentabellen sind reine Swift-Literale** (Dictionaries/`switch`-Ausdrücke), kein JSON/Property-List-Resource im Bundle. Beispiele: `PriceEstimator.specificPrices`, der Kategorie-`switch`, `SeasonalService.currentSuggestions()`, `AssignmentService.drugstoreKeywords`. Es gibt keinen Präzedenzfall für eine gebündelte JSON-Ressource — das im Ticket empfohlene "Einbacken" folgt also dem etablierten Stil und braucht keine neue Bundle-Resource-Infrastruktur.
- Bestehende externe Datenquelle als Vorbild für Namensnennung: Open Food Facts (`BarcodeScannerSheet`, dokumentiert in `LegalView.swift`).
- `unitDivisor(for:)` normalisiert bereits g/ml/mg/cl/dl → Preis pro kg/l; die Destatis-Werte müssen in dasselbe Bezugssystem (i.d.R. € pro kg/Stück) übersetzt werden.

## Dependencies
- **Upstream:** Destatis GENESIS-Online (REST/JSON, Datenlizenz Deutschland – Namensnennung 2.0, kostenfrei, keine Anmeldung für lesenden Zugriff). Werte werden einmalig recherchiert/abgerufen und als Konstanten eingebacken — keine Laufzeit-Abhängigkeit, kein Netzwerkcode, kein Fehlerpfad nötig.
- **Downstream:** `ShoppingItem.init` (Zeile 154, Fallback wenn kein gelernter Preis vorliegt) und `EditItemView` (manuelle Neuschätzung). Beide rufen `PriceEstimator.estimate` unverändert auf — die Signatur ändert sich nicht, nur die internen Werte.

## Existing Specs
- Keine vorhandene Spec zu `PriceEstimator` unter `docs/specs/` (weder in `models/` noch `services/`) — wird in Phase 3 neu angelegt.
- Vorherige Analyse: `docs/context/check-8-bon-zweck.md` (Prüfung #8) — Ursprung dieses Tickets, dort Zeile 339 bestätigt den Ist-Zustand (33/59 Konstanten, war zum damaligen Stand).

## Risks & Considerations
- **Keine bestehenden Unit-Tests für `PriceEstimator.estimate`** (`RestockTests/` hat nur `PriceProvenanceMigrationTests.swift` und `ReceiptParserPriceTests.swift`, beide angrenzend, nicht deckend) — TDD-RED-Phase muss die Testbasis neu aufbauen, nicht nur erweitern.
- **Kategorie-Zuordnung:** Die 26 App-Kategorien (`AssignmentService.categoryOrder`) müssen auf Destatis-Warengruppen gemappt werden; Destatis führt keine 1:1 identischen Gruppen (z. B. "Küchenausstattung", "Schreibwaren" haben keine offensichtliche amtliche Entsprechung als Lebensmittel-Ausgabenstatistik — Destatis liefert in erster Linie Verbraucherpreise für Nahrungsmittel/Getränke, nicht für Non-Food wie Elektronik oder Werkzeug). Das Ticket selbst benennt diese Zuordnung als offene Frage.
- **Bake-Zeitpunkt vs. Laufzeit:** Ticket empfiehlt Einbacken mit Stichtag (Offline-Fähigkeit, keine neue Laufzeit-Abhängigkeit) — passt zum bestehenden Codestil (siehe Existing Patterns). Laufzeit-Abruf wäre die Alternative, aber ohne Präzedenzfall im Code und mit Fehlerpfad-Mehraufwand.
- **Namensnennungspflicht:** "Datenlizenz Deutschland – Namensnennung 2.0" verlangt eine sichtbare Quellenangabe — Platzierung (Impressum, eigener Abschnitt, oder Erweiterung der Datenschutzerklärung) ist in Phase 2/3 zu entscheiden.
- **`specificPrices`-Keyword-Liste bleibt unverändert im Ticket-Scope** — das Ticket adressiert nur die 26 Kategorie-Pauschalen (Destatis liefert Warengruppen-Durchschnitte, keine Einzelprodukte); die 32 Produkt-Keyword-Preise sind nicht Teil dieses Tickets, sollten aber im Kontext nicht versehentlich mitgeändert werden.

## Analysis

### Type
Feature

### ⛔ Kernbefund: Ticket-Annahme durch Recherche widerlegt

Echte Recherche (WebSearch/WebFetch, Stand 2026-09-25) in Destatis GENESIS-Online ergibt: Für praktisch **keine** der 26 Kategorien existiert ein aktuell gepflegter, absoluter Durchschnittspreis in Euro — nur der **Verbraucherpreisindex** (VPI, 2020=100, Prozent-Veränderung).

- Statistik 61111 (VPI Deutschland), Tabellen 61111-0001/-0002/-0004: reine Indexwerte, keine Euro-Beträge (genesis.destatis.de/datenbank/online/statistic/61111).
- "Preisentwicklung für Nahrungsmittel" (Sonderauswertung Jan 2020–Jun 2025): ebenfalls nur Index, und laut Seite explizit **eingestellt** (Stand Juli 2025).
- **Preismonitor** (destatis.de/.../Preismonitor.html) deckt die 26 Kategorie-Cluster thematisch fast ab, liefert aber laut eigener Beschreibung nur Prozent-Abweichungen vom Jahresdurchschnitt 2020 — keine Euro-Beträge, auch nicht für Food.
- Die frühere Publikationsreihe (Fachserie 17) mit Euro-Durchschnittspreisen ausgewählter Nahrungsmittel wurde zum Berichtsmonat Dezember 2022 eingestellt.
- Einzige gefundene aktive Quelle mit Euro-Absolutpreisen: **BMEL "Allgemeine Preisstatistik"** (bmel-statistik.de/preise) — anderes Amt, andere Lizenz, nur Food/Agrar, nicht Destatis.

**Damit trifft die Ticket-Kernannahme ("Destatis liefert datierte, offizielle Durchschnitte je Warengruppe") nicht zu** — weder für die 18 Non-Food-Kategorien noch für die 8 Food-Kategorien.

### Affected Files (bei Umsetzung, Details je nach gewählter Option)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/ShoppingItem.swift:302-330` | MODIFY | 26 Kategorie-Pauschalpreise im `switch category`-Block ersetzen. `specificPrices` (251-284) bleibt unverändert. |
| `RestockTests/PriceProvenanceMigrationTests.swift:36-123` | MODIFY | Assertions auf neue Kategorie-Pauschalpreise anpassen. |
| `RestockTests/ReceiptParserPriceTests.swift:160,227-228,353` | MODIFY | Preis-Schätzungs-Assertions anpassen. |
| `SmartCart/Views/Settings/LegalView.swift` | MODIFY (nur bei Option mit Quellenangabe) | Neuer Quellen-Abschnitt (nicht Datenschutz), nur für tatsächlich Destatis-basierte Kategorien. |
| `SmartCart/Views/Store/EditItemView.swift:375,384` | Kein Code-Update nötig | Ruft `PriceEstimator.estimate` auf, Verhalten ändert sich automatisch mit. |

Keine Änderung nötig: `AssignmentService+Category.swift` (`categoryOrder`, Zeilen 219-225) — bleibt Referenz, 26 Kategorienamen unverändert.

### Scope Assessment
- Option A (Symptom-Fix, s.u.): 1 Datei, ~30-50 LoC.
- Option B (Food-Kategorien per Index-Hochrechnung, s.u.): 2 Dateien, ~80-150 LoC.
- Beide innerhalb des Scoping-Limits (±250 LoC, max. 5 Dateien).
- Risk Level: MEDIUM — nicht wegen Code-Komplexität, sondern wegen falscher Quellenangabe, falls Non-Food-Werte fälschlich als "Destatis" ausgezeichnet würden.

### Technical Approach — abhängig von PO-Entscheidung (siehe Open Questions)
Falls umgesetzt: Swift-Literale im bestehenden Stil (wie `specificPrices`), keine neue JSON-Bundle-Ressource nötig. Da "datiert" zum Kernversprechen gehört, empfiehlt sich pro Kategorie eine kleine Struktur `(amount: Double, asOf: String, source: String)` statt eines nackten `Double`, damit Stichtag/Quelle nachvollziehbar bleiben — nur für Kategorien mit echter Quelle, nicht pauschal für alle 26.

### Vier Alternativen (mit Ausblick, welche bisherige Annahme jeweils kippt)
1. **Nur Symptom fixen (empfohlen):** Kategorie-Pauschalen bleiben Schätzwerte, aber differenzierter als heute (kein "beide häufigsten Kategorien exakt 2,50€" mehr), ohne "amtlich"-Anspruch. Kippt: die Ticket-Kernidee "durch amtliche Destatis-Werte ersetzen" wird zurückgestellt, nicht umgesetzt. Vorteil: ehrlich, geringer Aufwand, kein Etikettenschwindel-Risiko.
2. **Nur Food-Kategorien (~8-10) per Index-Hochrechnung:** historischer Ankerpreis (aus der eingestellten Reihe) × aktueller VPI-Index. Non-Food bleibt Schätzwert. Kippt: "amtlicher Durchschnittspreis" wird zu "Index-basierte Näherung" — schwächere Aussage als im Ticket unterstellt. Nachteil: Genauigkeit unsicher, mehr Rechercheaufwand pro Kategorie.
3. **Alle 26 trotz Unschärfe annähern:** verworfen — für die meisten Kategorien gibt es keine Zahl zum Annähern; Non-Food-Werte wären erfunden und fälschlich als "amtlich" gelabelt.
4. **Zusatzquelle (z. B. BMEL) für Non-Food ergänzen:** neue Lizenz/Quelle, Scope wächst deutlich über das Ticket hinaus, eigenes Ticket nötig.

### Risks & Considerations (neu, aus Recherche)
- `maxPlausibleLineTotal` (30€): bei Index-Hochrechnung (Option 2) können falsche Ankerwerte Preise still verwerfen statt einen Fehler zu zeigen.
- **Größtes Risiko ist inhaltlich/rechtlich, nicht technisch:** Non-Food-Schätzwerte dürfen nicht als "Destatis"/"amtlich" ausgezeichnet werden, wenn dafür keine Zahl existiert — irreführende Quellenangabe wäre schlimmer als der Status quo.
- Namensnennung ("Datenlizenz Deutschland – Namensnennung 2.0") ist eine Lizenz-/Quellenfrage, kein Datenschutzthema — gehört eher in einen neuen "Quellen"-Abschnitt in `LegalView.swift` als in den bestehenden Datenschutz-Absatz, und nur für Kategorien mit echter Destatis-Quelle.

### Open Questions
- [x] **PO-Entscheidung (2026-09-25):** Alternative 1 — nur das gemeldete Symptom beheben. Kategorie-Pauschalen werden differenzierter geschätzt (kein Kollaps mehrerer Kategorien auf denselben Wert wie aktuell "Obst & Gemüse"/"Lebensmittel" bei 2,50€), bleiben aber klar erkennbare Schätzwerte ohne Anspruch auf amtliche Herkunft. Die Destatis-Idee (Alternativen 2-4) wird zurückgestellt, nicht umgesetzt.

### Finaler Scope (nach PO-Entscheidung)
- Nur `SmartCart/Models/ShoppingItem.swift:302-330` (Kategorie-`switch`) wird geändert — Werte differenziert, weiterhin einfache `Double`-Konstanten im bestehenden Stil, kein Struct mit Quellenfeld nötig (kein „datiert"-Versprechen mehr, da keine amtliche Quelle behauptet wird).
- Keine Änderung an `LegalView.swift` — keine Namensnennungspflicht, da keine Destatis-Daten verwendet werden.
- Konkrete neue Preiswerte je der 26 Kategorien werden in Phase 3 (Spec) festgelegt.
- `specificPrices` (Produkt-Keywords) bleibt unverändert.
