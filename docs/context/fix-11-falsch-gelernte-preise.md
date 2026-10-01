# Context: fix-11-falsch-gelernte-preise (Issue #11)

## Request Summary
Bereits falsch gelernte Preise (um den Mengenfaktor zu hoch, z. B. 1,56 € statt 0,39 € je
Laugenbrötchen) sollen nachträglich korrigiert werden, nicht nur ab jetzt richtig gelernt.
PO-Entscheidung steht im Issue. Offen: Erkennungskriterium und Verhalten bei geteilten Listen.

## Zeitleiste (aus `git log origin/main`)
| Datum | Änderung | Wirkung auf die Daten |
|---|---|---|
| bis 2026-09-21 | Rewe-Format verliert Stückzahl/Gewicht | Zeilensumme wird als Stückpreis gelernt (Quelle der Falschwerte) |
| 2026-09-22 | #9 (#26) Parser übernimmt Stückzahl/Gewicht | ab hier wird richtig gelernt |
| 2026-09-27 | #10 (#64) `learnedPriceUnits` + Entscheidungstabelle | Einträge OHNE Einheit werden nie angewendet |
| 2026-10-01 | #54 (#81) Menge/Einheit im `PurchaseRecord` | davor sind Menge/Einheit der Kaufdatensätze unzuverlässig |
| 2026-10-01 | Build 8 (TestFlight) enthält alle drei | |

## Befund: was ist heute noch falsch und sichtbar? (aus Code gelesen, noch NICHT am laufenden Stand reproduziert)

1. **`Store.learnedPrices` ohne `learnedPriceUnits`-Eintrag ist seit #10 inert.**
   `ShoppingItem.init` (`ShoppingItem.swift:137-195`) und der Rückschreib-Zweig in
   `ReceiptScannerView.save()` (`:735-750`) verwerfen sie über `learnedRateUsage` (`.reject`).
   Die Altlast verfälscht also keine NEUEN Artikel mehr. Sie ist aber auch nutzlos: richtig
   gelernte Altpreise stehen ungenutzt da (Folgekosten: Katalogschätzung statt echtem Preis).
2. **Bereits gespeicherte `ShoppingItem.estimatedPrice`-Werte sind unberührt.**
   Wurde ein Artikel vor #10 mit einem gelernten Falschwert angelegt, trägt er
   `estimatedPriceIsAutoDerived == false` und behält den Wert. `ItemRow` zeigt ihn auch bei
   abgehakten Artikeln (nur Preise mit „echter Herkunft“ werden dort gezeigt), und
   `PriceOverviewView` summiert ihn ins Budget. Kein Gate fängt das ab.
3. **Die bestehende Migration fängt den Faktor-4-Fall nicht.**
   `PriceProvenanceMigration` Phase C (`ShoppingItem.swift:540-561`, Flag
   `priceProvenanceMigrationV3Applied`, läuft einmalig) greift nur bei Subeinheit (g/ml…),
   Menge > 10 und Gesamtpreis > 200 €. Ein 1,56-€-Brötchen liegt weit darunter.
4. **`PurchaseRecord.actualPrice` ist die Zeilensumme** (`ReceiptScannerView.swift:116, :757`),
   also in sich stimmig. Falsch/unzuverlässig vor #54 sind `quantityAmount` und `unit` des
   Datensatzes. HYPOTHESE, noch zu belegen: Aus alten Kaufdaten lässt sich der richtige
   Stückpreis deshalb nicht sicher zurückrechnen (Menge fehlt dort ebenso).
5. **Sync-Stolperfalle (neu entdeckt, noch nicht reproduziert):**
   `SyncCoordinator.apply` (`:236-243`) und `SharedStoreService.mergePrices` (`:141-155`)
   übernehmen Preis und Datum eines Schlüssels, aber NICHT `learnedPriceUnits` (#53). Ein
   remote stehender, veralteter Falschpreis mit neuerem Datum kann so einen lokal korrigierten
   Preis überschreiben, während die lokale Einheit stehen bleibt. Dann wäre ein Falschwert MIT
   Einheit „gültig“ und würde angewendet. Das ist relevant für jede Korrektur, die Einheiten setzt.

## Related Files
| Datei | Relevanz |
|---|---|
| `SmartCart/Models/ShoppingItem.swift` | `init` (Anwendung gelernter Preise), `learnedRateUsage`, `PriceEstimator`-Grenzen (`maxPlausibleLineTotal` 30 €, `maxPlausibleLearnedLineTotal` 200 €), `PriceProvenanceMigration` (Vorlage) |
| `SmartCart/Models/Store.swift` | `learnedPrices`, `learnedPriceDates`, `learnedPriceUnits`; Kommentar nennt #11 ausdrücklich als Reparatur der Altdaten |
| `SmartCart/Models/PurchaseRecord.swift` | `actualPrice` (Summe), `quantityAmount`, `unit` |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | `save()` schreibt Rate, Einheit, Datum, Rückschreibung und Datensatz |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | zweiter Lernweg (Gesamtsumme tippen, proportional verteilen, `:152-175`) |
| `SmartCart/Services/SyncCoordinator.swift`, `SharedStoreService.swift` | Preis-Merge geteilter Listen, ohne Einheit und ohne Plausibilität |
| `SmartCart/SmartCartApp.swift` (`:527`) | Startpunkt der Migration; DEBUG-Seeds (`:233`) für UI-Durchstich |
| `SmartCart/Views/Components/ItemRow.swift`, `PriceOverviewView.swift` | Stellen, an denen ein Falschwert sichtbar wird |
| `RestockTests/PriceProvenanceMigrationTests.swift`, `ShoppingItemFuzzyPriceMatchTests.swift`, `PriceEstimatorStagesTests.swift` | bestehende Tests als Muster |

## Existing Patterns
- Rate je Einheit ist kanonisch; Gesamtpreis = Rate × Menge erst bei der Anzeige.
- Einmal-Migration über `UserDefaults`-Flag + `ModelContext`-Fetch (`PriceProvenanceMigration`).
- Entscheidungstabelle als reine, testbare Funktion (`learnedRateUsage`).
- Reine Regeln statt Modell (PO-Regel „Regeln vor Modell“): Preislogik ist deterministisch.
- Test-Seeds im UI-Test müssen in `tearDown()` aufräumen (Projekt-CLAUDE.md).

## Dependencies
- Upstream: `PurchaseRecord`-Historie, `ReceiptAliasService` (Namensidentität), SwiftData/CloudKit.
- Downstream: `ItemRow`, `PriceOverviewView`, Sync geteilter Listen, künftige #15 (Preisvergleich)
  und #53 (Einheit über geteilte Listen).

## Existing Specs
- `docs/specs/models/learned-price-unit-and-quantity-source.md` (#10)
- `docs/specs/models/receipt-save-purchase-quantity.md` (#54)
- `docs/specs/services/receipt-parser-quantity-confirmation.md` (#9)
- `docs/context/check-8-bon-zweck.md` (Ausgangsanalyse, Prüfung #8)

## Risks & Considerations
- **Es gibt kein Merkmal „dieser Eintrag ist falsch“.** Vor #9 ist ein Falschwert nicht von
  einem echten teuren Preis zu unterscheiden. Eine Korrektur ohne Beleg kann Richtiges zerstören.
- Die zu schätzende Population ist unbekannt: Wie viele Einträge hat Henning ohne Einheit, und
  wie viele davon sind tatsächlich zu hoch? Die Analyse braucht echte Zahlen (Daten von Hennings
  Gerät sind aus dieser Sitzung nicht lesbar; Wegwerf-Kopie mit nachgestelltem Zustand nötig).
- Eine Reparatur, die Einheiten setzt, hängt mit #53 (Einheit über Sync) zusammen — siehe Punkt 5.
- Datenänderung an CloudKit-gespiegelten Modellen: kein Schema-Bump nötig, wenn nur Werte
  geändert werden.

## Alternativen, die die Analyse prüfen muss (PO-Regel „in Alternativen denken“)
- **A. Automatische Reparatur** nach dem Muster von Phase C, Kriterium aus `PurchaseRecord`s.
  Kippt nur dann, wenn sich Falschwerte aus den Daten sicher erkennen lassen (siehe Punkt 4).
- **B. Verwerfen statt reparieren:** Altlast ohne Einheit löschen (ist ohnehin inert), betroffene
  `estimatedPrice` mit Herkunft „gelernt“ vor #10 auf die Katalogschätzung zurücksetzen; der
  nächste Bon lernt neu. Einfach, kein Erkennungskriterium. Verliert richtige Altpreise.
- **C. Nutzer korrigiert selbst:** gelernte Preise je Laden anzeigen, ändern oder löschen.
  Kippt die PO-Entscheidung „automatisch bereinigen“ aus dem Issue.
- **D. Nichts tun für `learnedPrices`, nur die sichtbaren `estimatedPrice` bereinigen**, weil
  die Altlast seit #10 inert ist. Kleinster Eingriff; zu prüfen, ob Punkt 2 praktisch vorkommt.

## Offene Frage an die Analyse (Phase 2)
- Wie viele sichtbare Falschwerte gibt es tatsächlich (Punkt 2), und lässt sich das im
  Simulator mit dem Altstand nachstellen? Ohne Reproduktion keine Empfehlung.
