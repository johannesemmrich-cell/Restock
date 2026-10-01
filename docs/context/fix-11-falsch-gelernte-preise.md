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

---

# Analysis (Phase 2, 2026-10-01)

## Type
Bug (Altdaten-Reparatur). Kein sichtbares Redesign → keine Artefakt-Vorschau nötig (nur bei Alternative C).

## Recherche (zuerst)
Gesucht: Muster für einmalige Datenreparatur bei SwiftData/CloudKit und für nachträgliche Preisbereinigung.
Ergebnis dünn und nur bestätigend: Einmal-Migration mit Versions-Flag in UserDefaults ist das übliche
Muster (Apple-Foren: developer.apple.com/forums/thread/756538, /744491); für Preis-Ausreißer gilt in der
Fachliteratur „erst erkennen, dann mit dem Nutzer bestätigen“ — es gibt kein verlässliches
Reparaturkriterium ohne Beleg. Nichts davon ersetzt die eigene Reproduktion unten.

## Reproduktion (Simulator `Restock-Validate`, aktueller Stand = HEAD, Build 8)
Echter Weg: Alt-Stand vor #10 (`3af1d03^`) in Wegwerf-Kopie gebaut, Bestands-UI-Test ohne Aufräumen
gefahren. Der Test brach VOR dem Speichern ab (Kachel nicht anklickbar) → der Bon wurde nicht gespeichert,
das alte Speichern ließ sich also NICHT im echten Ablauf auslösen. Ausweg (offen so benannt):
Der Speicher stammt aus dem echten Alt-Build (Schema ohne `learnedPriceUnits`), die Falschwerte habe ich
von Hand in diesen Alt-Speicher geschrieben: `learnedPrices = {"brötchen": 1.56}` ohne Einheit,
abgehakter Artikel „Brötchen“ mit `estimatedPrice 1.56`, `estimatedPriceIsAutoDerived = 0`.
Dann aktuellen Stand darüber installiert und normal gestartet.
- **Beobachtet:** App startet, Daten bleiben unverändert (`learnedPrices` weiter ohne Einheit,
  `estimatedPrice` weiter 1,56 mit „echter Herkunft“). Keine Migration greift.
- **Nur gelesen, nicht gesehen** (Simulator fensterlos, kein Tippen auf die Lidl-Kachel möglich):
  `ItemRow.swift:153` zeigt bei abgehakten Artikeln mit echter Herkunft `estimatedLineTotal` → „1,56 €“.
  `ShoppingItem.markPending()` (`:317-340`) setzt den Preis NICHT zurück → wird der Artikel wieder
  aktiviert, summiert `PriceOverviewView.swift:158` den Falschwert ins Budget.
- Nicht belegt: wie viele solcher Einträge Hennings echtes Gerät hat (nicht lesbar).

## Ursachenkette (Code-Stellen)
1. Quelle: Parser verlor Stückzahl (behoben #9). 2. `learnedPrices` ohne Einheit: seit #10 inert
(`learnedRateUsage` → `.reject`), heilt sich beim nächsten Scan selbst (Überschreiben mit Einheit,
`ReceiptScannerView.swift:717-719`). 3. Einziger Weg, auf dem Altwerte heute Schaden machen:
bereits gespeicherte `ShoppingItem.estimatedPrice` mit `estimatedPriceIsAutoDerived == false`
(Liste bei abgehakten, Budget nach Reaktivierung). 4. Artikelpreise werden NICHT synchronisiert
(`SharedItemData` enthält keinen Preis, geprüft) — nur `learnedPrices`, und die immer ohne Einheit
(→ #53), also bei anderen Mitgliedern ohnehin inert. Eine „Mitkorrektur bei anderen“ ist daher
weder nötig noch möglich; sie läge in #53.
5. `PriceProvenanceMigration` Phase C fängt Faktor 4 nicht (nur Subeinheit, Menge > 10, > 200 €).

## Erkennungskriterium — Befund
Es gibt KEIN Merkmal „falsch“. Ein rein regelbasierter Weg, der Falsches erkennt, existiert nicht.
Regelbasiert möglich ist nur: „Wert stammt aus der Zeit vor der Einheit“ (Fingerabdruck:
Artikel mit echter Herkunft, aber im Laden kein Eintrag MIT Einheit zum Namen).
Unsicherheit: Der Bon-Scan speichert unter dem aufgelösten Bon-Namen, der Artikel kann anders heißen
→ Fingerabdruck kann auch nach #10 gelernte, richtige Preise treffen. Braucht Datums-Grenze oder Test.
Rückrechnen aus `PurchaseRecord` (actualPrice ÷ quantityAmount) wäre eine Regel, ist aber unsicher:
Menge im Datensatz vor #54 ist die geplante Menge; bei Menge 1 entstünde derselbe Falschwert, nur
jetzt MIT Einheit und damit „gültig“ — schlechter als heute.

## Alternativen (PO-Regel)
- **A. Rückrechnen aus Kaufdaten** (Muster Phase C). Kippt nichts, aber siehe oben: kann Falsches
  legitimieren. Verworfen.
- **B/D. Zurücksetzen statt reparieren (Empfehlung):** einmalige Migration setzt Artikelpreise mit
  Altherkunft auf die Katalogschätzung zurück und markiert sie als „geschätzt“; `learnedPrices` ohne
  Einheit bleiben unangetastet (inert, selbstheilend). Kein Erkennungskriterium für „falsch“ nötig,
  ohne Modell. Kosten: richtige Altpreise gehen verloren, nächster Bon lernt sie neu.
- **C. Nutzer korrigiert selbst** (Preise je Laden ansehen/ändern/löschen). Kippt PO-Entscheidung
  „automatisch bereinigen“; mehr UI, Entwurf vorab nötig.
- **E. Nichts tun:** Altwerte verschwinden von selbst, sobald ein Artikel erledigt und gelöscht oder neu
  gescannt wird. Kostet nichts, lässt aber das Budget bei reaktivierten Artikeln falsch.

## Scope-Schätzung (für B/D)
~3 Dateien (`ShoppingItem.swift` Migration, `SmartCartApp.swift` Aufruf, 1 Testdatei), ca. +120 LoC.
Risiko: Mittel — Datenänderung an CloudKit-gespiegelten Werten, Fingerabdruck kann Richtiges treffen.

## Offene Fragen
- [x] PO (2026-10-01): Zurücksetzen auf Schätzung (B/D) gewählt; Verlust richtiger Altpreise akzeptiert.
- [ ] Fingerabdruck-Grenze: Datum (Release-Stand von #10 auf Hennings Gerät) oder Namensabgleich?
  Wird in Phase 3 mit Tests an echten Konstellationen (Name ≠ Bon-Name) festgelegt.
