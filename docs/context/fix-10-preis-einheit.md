# Context: fix-10-preis-einheit (Issue #10)

## Request Summary

Ein gelernter Preis (`Store.learnedPrices`) ist ein nackter `Double` ohne Einheit. Dadurch wird ein
pro Gramm gelernter Preis beim Anlegen eines Artikels ohne Mengenangabe als Stückpreis übernommen —
real beobachtet: „Seitan" zeigt **0,01 €** (PO, 2026-09-25). Der Preis soll seine Bezugsgröße
mitführen; zusätzlich (PO-Einwand im Intake) braucht ein Preis pro kg eine **Bezugsmenge**, sonst
gibt es keinen Gesamtpreis — und diese Annahme muss sichtbar und korrigierbar sein.

## PO-Entscheidungen aus dem Intake (2026-09-26)

1. **Altdaten ohne Einheit werden nicht angewendet** — es greift die normale Schätzung; beim nächsten
   Bon-Scan wird mit Einheit neu gelernt. Nachträgliche Reparatur bleibt Issue #11.
2. **Mengen-Vorbelegung gehört in den Umfang**, Reihenfolge:
   1. Vom Nutzer eingegebene Menge
   2. Letzte gekaufte Menge dieses Artikels in diesem Laden (`PurchaseRecord`)
   3. Auf dem Bon gedruckte Packungsgröße (`ReceiptParserService.weightBasisFromName`)
   4. Keine Evidenz → **kein Gesamtpreis**, nur die Rate pro Einheit
3. Keine Zwangsabfrage beim Hinzufügen (zerstört schnelles Eintippen), aber auch keine stille
   `quantityAmount = 1` mehr. Annahme sichtbar + korrigierbar.
4. **Abgespalten** (Umfangsgrenze): #53 Sync geteilter Listen, #54 `PurchaseRecord`-Gewicht.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Models/Store.swift:27-32` | `learnedPrices: [String: Double]` + `learnedPriceDates` — hier entsteht das neue Einheitsfeld |
| `SmartCart/Models/ShoppingItem.swift:112-157` | `init`: Fuzzy-Lookup in `learnedPrices`, Plausibilitätsgrenze, Zuweisung an `estimatedPrice`. **Zentrale Fix-Stelle** |
| `SmartCart/Models/ShoppingItem.swift:158-170` | `estimatedLineTotal` = `estimatedPrice × quantityAmount` — die Multiplikation, die heute mit der falschen Einheit rechnet |
| `SmartCart/Models/ShoppingItem.swift:236-248` | `maxPlausibleLearnedLineTotal` (200 €) — fängt nur zu HOHE Werte ab, nicht den 0,01-€-Fall |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:642-650` | Schreibstelle beim Bon-Speichern: `perUnitPrice = line.price / learningQuantity` |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:64-67` | `learningQuantity(matchQuantityAmount:)` — bestimmt den Divisor und damit implizit die Einheit |
| `SmartCart/Services/ReceiptParserService.swift:379,432` | `weightBasis = wr.weight * 1000` — **normalisiert kg UND l auf 1000, verwirft die Einheit** |
| `SmartCart/Services/ReceiptParserService.swift:903-918` | `weightBasisFromName` — dito: gibt g/ml zurück, Einheit fällt weg. Zugleich Quelle für Stufe 3 der Mengen-Vorbelegung |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift:152-165` | Zweite Schreibstelle (manuelle Preiseingabe) — schreibt ebenfalls ohne Einheit |
| `SmartCart/Views/Components/ItemRow.swift:85-88` | Zeigt `quantity` + `unit` bereits an, sobald `quantity != "1"` ODER `unit` nicht leer |
| `SmartCart/Views/Components/ItemRow.swift:140-144` | Preis-Anzeige über `estimatedLineTotal` + `estimatedPriceIsAutoDerived` |
| `SmartCart/Views/Store/EditItemView.swift:339,364-385` | Korrekturweg für Menge/Preis; rechnet `estimatedPrice` bei Mengen-/Einheitswechsel neu |
| `SmartCart/Models/PurchaseRecord.swift:9-19` | `quantityAmount` + `unit` — Datenquelle für Stufe 2 der Mengen-Vorbelegung |
| `RestockTests/ReceiptParserPriceTests.swift` | Bestandstests zur Pro-Gramm-Falle (Skyr, Banane) — müssen grün bleiben |
| `RestockTests/PriceProvenanceMigrationTests.swift` | Bestandstests zur Altdaten-Reparatur — Regel 1 (Altdaten nicht anwenden) berührt genau dieses Verhalten |

## Existing Patterns

- **Additives paralleles Dictionary statt Schema-Bruch.** `learnedPriceDates: [String: Date]` wurde
  genau so ergänzt (`Store.swift:28-32`, Kommentar dort): kein Versionsbump, CloudKit-tauglich, weil
  jede gespeicherte Eigenschaft einen Standardwert hat. Derselbe Weg trägt `learnedPriceUnits`.
- **CloudKit-Zwang:** jede skalare Eigenschaft braucht Standardwert, jede To-many-Relationship muss
  optional sein (`Store.swift:6-13,34-40`) — sonst `SwiftDataError.loadIssueModelContainer`.
- **Preis pro Einheit ist kanonisch.** `learnedPrices` und `estimatedPrice` halten immer eine Rate;
  `estimatedLineTotal` multipliziert erst bei der Anzeige (`check-8-bon-zweck.md:43-44`).
- **Divisor-Formel als Methode, nicht inline**, damit Tests exakt dieselbe Formel aufrufen statt sie
  nachzubilden (`learningQuantity`, Doc-Kommentar `ReceiptScannerView.swift:52-63`). Ein neues
  Einheits-Ergebnis gehört in dieselbe Methode, nicht daneben.
- **Ein einziger Konstruktor als Engstelle:** 17+ Erzeugungsstellen (Quick-Add, AddItemView, Siri-
  Intent, Widget, MenuPlan, RecipeImport, HomeView-Vorschläge, StoreDetailView, SyncCoordinator)
  laufen alle durch `ShoppingItem.init`. Ein Fix dort deckt jeden Weg ab.
- **Lieber kein Preis als ein falscher** — bereits etabliert bei `maxPlausibleLineTotal`
  (`ShoppingItem.swift:228-235`, Müllbeutel-50l-Fall): „Ein fehlender Preis ist ehrlicher als ein
  sicher falscher."
- **Regeln vor Modell.** Alle vier Stufen der Mengen-Vorbelegung sind deterministisch (Historie,
  RegEx auf dem Bon-Namen). Kein Sprachmodell nötig.

## Dependencies

**Upstream (was der betroffene Code nutzt):**
- `ReceiptParserService.weightBasisFromName` / `weightTimesRate` — liefern Menge, kennen die Einheit,
  geben sie aber nicht heraus
- `PriceEstimator.estimate(for:category:unit:quantityAmount:)` — Fallback, wenn kein gelernter Preis
  angewendet wird (greift nach Regel 1 künftig häufiger)
- `PurchaseRecord` (über `store.items?.purchaseRecords`) — Evidenzquelle Stufe 2
- `UserIdentity`, `QuickAddParser` (liefert `quantityAmount`/`unit` beim Schnell-Eintippen)

**Downstream (was auf den betroffenen Code baut):**
- `ItemRow` (Listenanzeige), `PriceOverviewView` (Ausgaben), `EditItemView` (Korrektur)
- `SharedStoreService.mergePrices` + `SyncCoordinator.apply` — geteilte Listen → **Issue #53**
- `HabitService` / `PurchaseRecord.consumptionPattern` — liest Menge/Einheit der Historie
- Issue #11 (Altdaten reparieren), #15 (Phase 2 Preisvergleich) bauen fachlich hierauf auf

## Existing Specs

- `docs/specs/models/price-estimator-category-fallback.md` — `PriceEstimator`-Kategoriewerte
  (Issue #12). Berührt dieselbe Datei `ShoppingItem.swift`, aber einen anderen Block (`switch
  category`, Zeilen 302–329). Kein Konflikt, Status `draft`/nicht approved.
- `docs/specs/services/receipt-parser-quantity-confirmation.md` — Issue #9, die Mengen-/Gewichtszeile
  wird ausgewertet statt verworfen. **Direkte Vorbedingung, geschlossen.**
- `docs/specs/views/receipt-review-card.md`, `docs/specs/testing/receipt-review-test-entry.md` —
  Bon-Prüf-Screen; liefert den automatisierten Testeinstieg ohne Kamera/OCR.
- `docs/context/check-8-bon-zweck.md:170-180, 233-240` — Ursprungsanalyse, benennt exakt diesen
  Befund und empfahl Variante „B — A plus Einheit am gelernten Preis".

## Befund aus dem Kontext-Sammeln (neu, nicht im Ticket)

Die Einheit ist am Schreibort **bereits deterministisch bekannt** — sie ergibt sich aus dem
verwendeten Divisor in `learningQuantity`:

| Divisor-Quelle | Einheit des gelernten Preises |
|---|---|
| `weightBasis` (Gewichtszeile „0,706 kg x 2,49") | pro g bzw. pro ml |
| `quantity > 1` (Mengenzeile „4 Stk x 0,39") | pro Stück |
| `matchQuantityAmount` (abgehakter Artikel) | Einheit **dieses** Artikels (`item.unit`) |
| `weightBasisFromName` („SKYR NATUR 500G") | pro g bzw. pro ml |
| Fallback 1 | pro Stück |

Es muss also nichts erraten werden. Zwei Stellen verwerfen die Einheit allerdings aktiv:
`ReceiptParserService.swift:379` und `:432` rechnen `wr.weight * 1000` — dieselbe Zahl für „0,500 kg"
und „0,5 l". `weightTimesRate` gibt die Einheit zurück, der Aufrufer ignoriert sie. Ohne diese
Korrektur lässt sich g nicht von ml unterscheiden.

## Risks & Considerations

- **Bereich mit belegtem Datenschaden.** `SharedModelContainer.make()` trägt eine Warnung über einen
  früheren Datenverlust; `PriceProvenanceMigration` existiert wegen des 1145-€-Bugs. Eine echte
  Schema-Migration ist hier zu vermeiden → additives Feld, keine neue Entität.
- **Regel 1 lässt sichtbar Preise verschwinden.** Alle heute gelernten Preise sind einheitenlos und
  werden nicht mehr angewendet. Erwartbare PO-Wahrnehmung: „Preise sind weg." Vom PO bewusst
  entschieden, muss in der Vorschau und in den Release-Hinweisen stehen.
- **Bestandstests hängen an der alten Semantik.** `PriceProvenanceMigrationTests` prüft, dass ein
  einheitenloser Altwert *repariert und angewendet* wird. Regel 1 sagt: nicht anwenden. Beide Aussagen
  müssen in der Analyse gegeneinander aufgelöst werden — Bestandstest anpassen ist erlaubt, ihn
  stillschweigend löschen nicht.
- **g/ml-Kollision.** Bis `ReceiptParserService` die Einheit durchreicht, ist „pro g" von „pro ml"
  nicht zu trennen. Für die reine Fehlerbehebung (Seitan) genügte „Gewicht/Volumen", für Issue #15
  (Preisvergleich) nicht.
- **Mengen-Vorbelegung ändert sichtbares Verhalten.** Wird die Menge in den Artikel geschrieben
  (`quantityAmount`/`unit`/`quantity`), zeigt `ItemRow` sie ohne jede UI-Änderung an (Zeile 85-88) und
  `EditItemView` erlaubt die Korrektur. Das hält den Umfang bei 5 Dateien — muss dem PO aber als
  Entwurf vorgelegt werden (Regel „Entwurf vor Spec"), weil aus „Seitan" auf der Liste „200 g Seitan"
  wird.
- **Fuzzy-Lookup bleibt unscharf.** Der Treffer-Match (`key.contains(itemLower) || itemLower.contains(key)`)
  ist unverändert grob; Issue #52 behandelt das separat. Die Einheit macht ihn nicht besser, aber auch
  nicht schlechter.
- **Umfangsgrenze ist knapp.** 5 Produktdateien bei erlaubten 4–5, plus Tests. Bekannter Stolperstein:
  das LoC-Gate zählt Testcode als Produktivcode (Issue #36) — grünen Zwischenstand sichern, bevor die
  Tests wachsen.
- **UI-Tests hängen an Anzeigetexten** (Issues #18/#20). Ändert sich der Zeilentext („200 g Seitan"),
  können Bestandstests brechen.

## Offene Punkte für `/20-analyse`

1. Fehler zuerst reproduzieren: „Seitan …200G" scannen, dann „Seitan" ohne Menge hinzufügen → 0,01 €
   muss mit eigenen Augen erscheinen, bevor irgendetwas geändert wird.
2. Entwurfs-Vorschau (Pflicht, PO-Regel): heutiger Listenausschnitt neben Entwurf, echte App-Farben,
   hell und dunkel, mindestens eine Alternative (Menge in den Artikel schreiben vs. Annahme separat
   als „ca. 200 g" kennzeichnen).
3. Konflikt `PriceProvenanceMigrationTests` ↔ Regel 1 auflösen.
4. Entscheiden, ob g/ml-Trennung jetzt oder in #15 landet.

---

# Analysis (Phase 2, 2026-09-26)

## Type

**Bugfix** — mit einem vom PO bewusst hinzugenommenen Verhaltenszusatz (Mengen-Vorbelegung,
PO-Entscheidung 2 aus dem Intake).

## Reproduktion — erledigt, im echten App-Pfad

Belege liegen unter `docs/artifacts/fix-10-preis-einheit/`:
`repro-heute-lidl-liste.png` (Bildschirmfoto aus dem laufenden Simulator) und
`repro-testlauf.log` (`Executed 1 test, with 0 failures`, kein Abbruch, kein Retry).

Der gemeldete Fall steckte bereits in der Bestands-Fixture des Bon-Prüf-Screens — es musste dafür
**keine Zeile Code geändert werden**:

1. `xcodebuild test -only-testing:RestockUITests/ReceiptReviewUITests/testSavingStillWritesLearnedPriceToMatchedItem`
   auf `Restock-Validate` (UDID `8F696920-4B9A-40A7-96F0-7697BE887CC7`).
2. Die Fixture-Zeile `BIO-HACKFLEISCH GEMISCHT RIND SCHWEIN 400G` kostet 4,99 €
   (`SmartCartApp.swift:249-253`).
3. Der Test tippt „Speichern" und öffnet die Lidl-Liste.
4. **Sichtbar in der Liste: „Hackfleisch — 0,01 €", Gesamtbetrag „4,98 €" statt rund 10 €.**

Identisches Symptom wie der vom PO gemeldete Seitan-Fall. Der Simulator wurde währenddessen
im Sekundentakt abfotografiert; das verwertbare Einzelbild ist `repro-heute-lidl-liste.png`.

## Root Cause — belegt, präziser als die Ursprungsvermutung

Die Rechenkette mit Zahlen:

| Schritt | Stelle | Wert |
|---|---|---|
| Packungsgröße aus dem Bonnamen lesen | `ReceiptParserService.swift:903-918` `weightBasisFromName` | `400` |
| Divisor bestimmen | `ReceiptScannerView.swift:66-68` `learningQuantity(matchQuantityAmount:)` | `400` |
| Rate bilden und speichern | `ReceiptScannerView.swift:646-648` | `4,99 / 400 = 0,0125` → `store.learnedPrices[key]` |
| Rate beim Anlegen holen | `ShoppingItem.swift:127-139` Fuzzy-Lookup | `0,0125` |
| Plausibilität prüfen | `ShoppingItem.swift:152-153` gegen `maxPlausibleLearnedLineTotal` (200 €) | besteht |
| Zeilensumme bilden | `ShoppingItem.swift:166-168` | `0,0125 × 1 = 0,0125` → **0,01 €** |

**Das Lernen ist nicht kaputt.** `weightBasisFromName` wurde genau für diesen Fall gebaut
(Skyr-Bug, Kommentar `ReceiptParserService.swift:889-902`) und liefert korrekt einen
Pro-Gramm-Preis. Zwei Lücken erzeugen den Fehler:

1. **`Store.learnedPrices: [String: Double]` trägt keine Bezugsgröße.** `ShoppingItem.init` kann
   nicht erkennen, dass die Rate „pro Gramm" gilt, und multipliziert sie mit `quantityAmount = 1`.
2. **Der Plausibilitäts-Guard kennt nur eine Obergrenze.** `maxPlausibleLearnedLineTotal` = 200 €
   fängt den 1145-€-Skyr-Fall ab; es gibt **keine Untergrenze**, also fällt 0,0125 durch jede
   vorhandene Prüfung.

Eine zweite, alternative Ursache wurde gesucht und nicht gefunden.

## Technischer Ansatz (Empfehlung)

**Additive parallele Map `Store.learnedPriceUnits: [String: String] = [:]`**, exakt nach dem
Muster von `learnedPriceDates` (`Store.swift:27-32`) — kein Schema-Bruch, kein Versionsbump,
CloudKit-tauglich, weil skalar mit Standardwert.

**Wertebereich: zwei Eimer, nicht literale Einheiten** — `"stk"` (Stückpreis) und `"g"`
(Gewichts-/Volumen-Subeinheit; deckt g, mg, ml, cl, dl ab).

**Begründung für die g/ml-Frage (offener Punkt 4 aus dem Kontext, hiermit entschieden):**
`weightBasisFromName` und `ReceiptParserService.swift:379,432` normieren kg **und** l auf
dieselbe Zahl. Eine literal-genaue dritte Einheit auszuweisen wäre vorgetäuschte Genauigkeit,
solange die Quelle sie gar nicht hergibt. Die g/ml-Trennung landet in **#15 (Preisvergleich)**,
wo sie fachlich gebraucht wird — für diesen Fehler ist sie nicht nötig.

**Entscheidungstabelle in `ShoppingItem.init`** (ersetzt den ungeprüften Zugriff, Zeile 127-139):

| gelernte Einheit | Artikel-Einheit | Ergebnis |
|---|---|---|
| fehlt (alle Bestandsdaten) | beliebig | verwerfen → `PriceEstimator` (PO-Regel 1) |
| `"stk"` | `""`, `"stk"`, `"stück"` | anwenden |
| `"stk"` | g/mg/ml/cl/dl/kg/l | verwerfen → `PriceEstimator` |
| `"g"` | g/mg/ml/cl/dl | anwenden |
| `"g"` | `""`, `"stk"`, kg, l | verwerfen → `PriceEstimator` |

Ein Helfer `unitBucket(_:)` macht den Vergleich symmetrisch und deckt zusätzlich den Fall ab,
dass beide Seiten literal dieselbe exotische Einheit tragen (z. B. beide `"kg"`, wie es
`ActualPriceEntryView` erzeugen kann).

**Schreibstellen:** `ReceiptScannerView` bekommt eine Schwester-Methode
`learningUnit(matchUnit:)` direkt neben `learningQuantity` — dieselbe Verzweigung, dasselbe
Prinzip „Formel lebt als Methode, damit Tests sie aufrufen statt sie nachzubilden".
`ActualPriceEntryView.swift:161-164` schreibt schlicht `item.unit`, dort ist die Einheit bereits
vertrauenswürdig bekannt.

**Mengen-Vorbelegung (4 Stufen) konzentriert in `AddItemView.swift`** — im Code verifiziert:

- **Stufe 1** (Nutzereingabe) existiert bereits als `guard quantity.isEmpty else { return }`
  in `applySuggestedQuantity(for:)` (`AddItemView.swift:182-183`) — unverändert.
- **Stufe 2** (letzter Kauf **in diesem Laden**) ist zu 90 % fertig: `applySuggestedQuantity`
  filtert `allRecords` heute nur nach Name (`AddItemView.swift:186-188`). Ergänzung:
  zusätzlich auf `record.storeName` filtern (`PurchaseRecord.swift:11` — Feld existiert).
- **Stufe 3** (Packungsgröße im getippten Namen) ist neu: `weightBasisFromName` auf den
  eingegebenen Namen anwenden. Dieselbe Funktion, reiner Text-RegEx, kein Bon nötig.
- **Stufe 4** (keine Evidenz) über ein additives `quantityIsUncertain: Bool = false` am
  `ShoppingItem`; `estimatedLineTotal` liefert dann `nil` statt zu multiplizieren, die Anzeige
  fällt auf die Rate zurück.

**Sichtbar und korrigierbar ohne neue Oberfläche:** Die Stufen 1–3 schreiben in die bereits
vorhandenen `$quantity`/`$unit`-Bindings von `QuantityStepperField` (`AddItemView.swift:72`) —
die Vorbelegung erscheint live im Formular und ist vor dem Hinzufügen änderbar, genau wie es
Stufe 2 heute schon tut. Danach zeigt `ItemRow` sie ohne jede UI-Änderung an (Zeile 85-88) und
`EditItemView` erlaubt die Korrektur.

**Bewusst außerhalb:** Schnell-Eingabe in `HomeView` und `AddItemIntent` (Siri) bekommen die
Stufenlogik nicht — Siri hat keinen Bildschirm, auf dem eine Annahme sichtbar wäre, und es
würde die Dateigrenze sprengen. Beide Pfade sind durch die Entscheidungstabelle trotzdem vor
dem Kernfehler geschützt: ein unpassender Treffer wird verworfen, nicht multipliziert.

## Alternativen (PO-Regel „in Alternativen denken")

Dem PO als Entwurfs-Vorschau vorgelegt (`docs/artifacts/fix-10-preis-einheit/entwurf.html`,
veröffentlicht unter https://claude.ai/artifact/AwBQGPWJAdch2aNkPMonUL):

- **A — Menge steht am Artikel** (oben beschrieben). Empfehlung.
- **B — Annahme als Annahme markiert** („ca. 400 g", getönt). Braucht zusätzlich ein Merkmal
  „woher stammt diese Menge" am Artikel plus eine neue Darstellungsregel in `ItemRow` → 6.+7.
  Datei, sprengt den Rahmen. Eigenes Ticket wert.
- **C — kein Preis statt eines angenommenen.** Kippt PO-Entscheidung 2 (Mengen-Vorbelegung).
  Kleinster Eingriff, aber der echte Bon-Preis wird dauerhaft nie wieder angewendet, solange der
  Artikel ohne Menge angelegt wird.

Zusätzlich technisch geprüft und **nicht** empfohlen: `estimatedLineTotal` app-weit von „immer
ein Euro-Betrag" auf „Betrag **oder** Rate" umstellen. Spart die ganze Einheiten-Map, bricht
aber die dokumentierte Konvention (`ShoppingItem.swift:158-168`) an über zehn Anzeigestellen,
darunter die proportionale Bon-Aufteilung in `ActualPriceEntryView.save()`.

## Affected Files

| File | Change | Beschreibung | LoC (geschätzt) |
|------|--------|--------------|-----|
| `SmartCart/Models/Store.swift` | MODIFY | `learnedPriceUnits` + Doc-Kommentar | ~8 |
| `SmartCart/Models/ShoppingItem.swift` | MODIFY | `unitBucket`-Helfer, Entscheidungstabelle in `init`, `quantityIsUncertain`, `estimatedLineTotal`-Gate | ~45 |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `learningUnit(matchUnit:)` + Schreibzeile | ~20 |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | MODIFY | Schreibzeile für die Einheit | ~5 |
| `SmartCart/Views/Store/AddItemView.swift` | MODIFY | Laden-Filter (Stufe 2), Stufe 3, Übergabe Stufe 4 | ~35 |
| `RestockTests/PriceProvenanceMigrationTests.swift` | MODIFY | Fixtures + eine inhaltlich geänderte Erwartung + neue Tests | ~75 |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Fixtures ergänzen | ~6 |

## Scope Assessment

- Produktdateien: **5** (Grenze 4–5, eingehalten)
- Produktivcode: **~113 LoC** (Grenze ±250)
- Testcode: ~80 LoC — **Achtung Issue #36**: das LoC-Gate zählt Testcode als Produktivcode mit.
  Grünen Zwischenstand sichern, bevor die Tests wachsen.
- Risiko: **MITTEL** — Bereich mit dokumentiertem Datenverlust, aber rein additiv, ohne
  Schema-Migration und ohne neue Entität.

## Testkonflikt (offener Punkt 3 aus dem Kontext, hiermit aufgelöst)

Sechs Bestandstests setzen `store.learnedPrices[key]` ohne Einheit und erwarten, dass der Wert
angewendet wird — nach PO-Regel 1 wird er künftig verworfen:

- `PriceProvenanceMigrationTests.swift`: `testShoppingItemStillUsesPlausibleLearnedPrice`
  (Z. 78-86), `testShoppingItemAcceptsLegitimatelyExpensiveLearnedPrice` (Z. 69-77) —
  brauchen je **eine zusätzliche Fixture-Zeile** (`learnedPriceUnits[key] = "g"`), die Aussage
  des Tests bleibt erhalten.
- `ReceiptParserPriceTests.swift`: `assertLearnedPriceRoundTrip` (Z. 140-161, zweimal genutzt)
  und `testFlatPricePackagedItemWithoutWeightLineLearnsCorrectPerGramPrice` (Z. 205-229) —
  dito.
- `PriceProvenanceMigrationTests.swift`: **`testMigrationRepairsCorruptedStoreLearnedPrice`
  (Z. 94-124) ändert seine Aussage.** Er behauptet heute, ein reparierter einheitenloser
  Altwert werde anschließend angewendet (Z. 122-123, erwartet 2,29 €). PO-Regel 1 sagt das
  Gegenteil. Der Test wird **umgestellt, nicht gelöscht**: die Migration repariert den Wert
  weiterhin (Z. 116-118 bleibt), aber das daraufhin angelegte Item bekommt einen Schätzpreis
  (`estimatedPriceIsAutoDerived == true`) statt der 2,29 €. Die Änderung wird in der Spec
  ausdrücklich ausgewiesen.

## Dependencies & Risiken

- **Geteilte Listen verlieren gelernte Preise, bis #53 nachzieht.** `SharedStoreService`
  (`encodePrices`/`decodePrices`, Z. 384-410; `mergePrices`, Z. 141) und `SyncCoordinator.apply`
  (Z. 235-242) übertragen `learnedPrices` + `learnedPriceDates`. Eine dritte Map mitzuziehen
  bräuchte zwei weitere Dateien und ist als **#53 abgespalten**. Folge: Ein auf Gerät A
  gelernter Preis kommt auf Gerät B ohne Einheit an und wird dort wie ein Altdatum behandelt —
  also nicht angewendet. **Kein Falschpreis-Risiko** („lieber kein Preis als ein falscher"
  bleibt gewahrt), aber spürbarer Funktionsverlust für geteilte Listen. Muss im Code kommentiert
  und an #53 vermerkt werden, sonst wird es als neuer Fehler gemeldet.
- **Einmaliger sichtbarer Preisverlust** (PO-Entscheidung 1): alle heute gelernten Preise sind
  einheitenlos und werden nicht mehr angewendet. In der Entwurfs-Vorschau eigens dargestellt.
  Gehört in die Release-Hinweise.
- **CloudKit:** unkritisch — skalares Dictionary mit Standardwert, keine Relationship betroffen.
- **Fuzzy-Match bleibt grob** (`ShoppingItem.swift:129-131`). Die Einheitenprüfung filtert nur
  nach Dimension, nicht nach Produktidentität. Unverändert, separat als **#52**.
- **UI-Tests hängen an Anzeigetexten** (#18/#20). Variante A ändert den Zeilentext
  („400 g Hackfleisch") — Bestandstests prüfen.

## Reihenfolge (jeder Zwischenstand kompiliert und ist grün)

1. `Store.swift`: Feld ergänzen (isoliert lauffähig).
2. `ShoppingItem.swift`: `unitBucket` + Entscheidungstabelle **gemeinsam** mit den
   Fixture-Ergänzungen der sechs Bestandstests — sonst gibt es einen roten Zwischenstand.
3. `ReceiptScannerView.swift` + `ActualPriceEntryView.swift`: Schreibstellen. Ab hier lernt das
   System neue Preise korrekt.
4. `ShoppingItem.swift`: `quantityIsUncertain` + `estimatedLineTotal`-Gate (additiv, Default
   `false` hält alle übrigen Erzeugungsstellen unverändert).
5. `AddItemView.swift`: Stufen 2–4.
6. Neue gezielte Tests für Entscheidungstabelle und Stufen.

## Erledigte offene Punkte aus dem Kontext

1. ✅ Fehler reproduziert — Bildschirmfoto + Protokoll unter `docs/artifacts/fix-10-preis-einheit/`.
2. ✅ Entwurfs-Vorschau erstellt und veröffentlicht (hell + dunkel, drei Varianten).
3. ✅ Testkonflikt aufgelöst — siehe oben, ein Test wird umgestellt, fünf bekommen Fixtures.
4. ✅ g/ml-Trennung entschieden — nicht jetzt, sondern in #15.

## Open Questions

- [ ] **PO: Variante A, B oder C?** Empfehlung A. Blockiert `/30-write-spec`.

## PO-Entscheidung (2026-09-26, nach der Entwurfs-Vorschau)

**Variante B gewählt.** Die angenommene Menge wird auf der Liste als Annahme kenntlich gemacht
(„ca. 400 g", getönt) und nicht wie eine selbst eingetippte Menge dargestellt. A und C sind
damit vom Tisch. Die offene Frage aus dem Abschnitt `## Open Questions` ist beantwortet.

Der PO hat dabei die in der Vorschau genannten Kosten von B gesehen („braucht zusätzlich ein
Merkmal ‚woher stammt diese Menge' am Artikel plus eine neue Darstellungsregel") und sich
trotzdem für B entschieden.

### Was B gegenüber A zusätzlich verlangt

1. **Herkunft der Menge am `ShoppingItem` merken** — Nutzer / Kaufhistorie / Packungsgröße aus
   dem Namen / keine Evidenz. Additiv mit Standardwert, damit alle übrigen Erzeugungsstellen
   unverändert bleiben (CloudKit-Muster wie bei `learnedPriceUnits`).
2. **Darstellungsregel in `ItemRow.swift:85-88`** — angenommene Mengen bekommen „ca." und die
   getönte Schrift (`Color.amber`); selbst eingetippte Mengen sehen aus wie heute.
3. **Zurücksetzen der Herkunft beim Korrigieren** — ändert der Nutzer die Menge in
   `EditItemView`, gilt sie als seine eigene und die Markierung verschwindet.

### Folge für den Umfang

Statt der in der Analyse geschätzten 5 Produktdateien sind es **6 bis 7**:
zusätzlich `SmartCart/Views/Components/ItemRow.swift` und voraussichtlich
`SmartCart/Views/Store/EditItemView.swift`. Produktivcode ~150 LoC statt ~113 — weiterhin
deutlich unter der 250-LoC-Grenze, aber über der Grenze von 4–5 Dateien.

Achtung Issue #36: Das LoC-Gate zählt Testcode als Produktivcode mit. Bei ~150 LoC Produktcode
plus Tests wird die 250er-Grenze real erreicht — grünen Zwischenstand sichern, bevor die Tests
wachsen.

### Auswirkung auf UI-Tests

Variante B ändert den Zeilentext auf der Liste („ca. 400 g Hackfleisch"). Bestandstests, die auf
Anzeigetexte prüfen (#18/#20), müssen gegengeprüft werden.

### Umfangsentscheidung des PO (2026-09-26)

**Variante B wird in EINEM Zug geliefert**, nicht aufgeteilt. Der PO hat die Überschreitung der
Grenze von 4–5 Dateien (auf 6–7) ausdrücklich freigegeben, nachdem ihm beide Wege mit ihren
Kosten vorgelegt wurden. Die 250-LoC-Grenze bleibt bindend.

Diese Freigabe gilt für Issue #10 und begründet keine allgemeine Anhebung der Grenze.
