# Adversary Dialog — fix-151-price-source
Spec: docs/specs/models/price-source-display.md
Datum: 2026-10-17 13:31

## Checkliste
- [x] **AC-1:** Die Preiswahl aus `ShoppingItem.init` ist als reine Funktion `resolveLearnedPrice` mit Grund herausgezogen; über alle Zeilen von `learnedRateUsage` (Bezugsgröße × Artikeleinheit × `quantitySource`) liefert `init` dieselben Werte (`estimatedPrice`, `unit`, `estimatedPriceIsAutoDerived`) wie der Resolver.
- [x] **AC-2:** Die Parität gilt auch für Teilstring-, Fuzzy- und Tie-Breaker-Treffer sowie für „kein Treffer“; `matchedKey` ist der von `matchingLearnedPriceKey` gewählte Schlüssel.
- [x] **AC-3:** Die Obergrenze gilt unverändert: 200,00 € greift, 200,01 € nicht (Grund `exceedsCap`, Schätzung), Menge 0 wird wie 1 gerechnet.
- [x] **AC-4:** Der Resolver nennt den Grund eindeutig: `noStore`, `noEntry`, `exceedsCap`, `legacyNoUnit`, `unitMismatch`, `applied`, `appliedRateOnly`.
- [x] **AC-5:** `priceOrigin` leitet bei leerem oder unbekanntem `priceSource` aus dem Bool ab (`true` → `estimate`, `false` → `learned`) und liefert aus Altdaten nie `receipt`, `paid` oder `manual`.
- [x] **AC-6:** `ShoppingItem.init` setzt die Quelle: gelernter Preis mit Origin `receipt` → `receipt` mit Datum aus `learnedPriceDates`; Origin `paid` → `paid`; gelernter Preis ohne Origin → `learned`; verworfener oder fehlender Eintrag → `estimate`.
- [x] **AC-7:** `ReceiptLearning.apply` schreibt bei `.apply` und `.rateOnly` `receipt` + Datum zusammen mit dem Preis; bei `.reject` bleiben Preis und Quelle unverändert; `ReceiptScannerView.save()` setzt `learnedPriceOrigins[key] = "receipt"` zusammen mit Preis, Bezugsgröße und Datum.
- [x] **AC-8:** `ActualPriceEntryView.apply` setzt `paid` am Artikel und `learnedPriceOrigins[key] == "paid"`.
- [x] **AC-9:** `EditItemView.save()` setzt bei eingetragenem Preis `manual`, beim Leeren des Feldes `estimate` samt Katalogschätzung und Bool `true`.
- [x] **AC-10:** `LegacyLearnedPriceReset` setzt zurückgesetzte Artikel auf `estimate`; `learnedPrices`, `learnedPriceUnits`, `learnedPriceDates` und `learnedPriceOrigins` des Ladens bleiben unverändert.
- [x] **AC-11:** `LearnedPriceSync.apply` entfernt bei einem fremden, abweichenden Preis den Origin-Eintrag (Anzeige danach „gelernt“), behält ihn bei gleichem Datum und gleichem Betrag, und `LearnedPriceSync.State` überträgt keine Origins.
- [x] **AC-12:** `Store.learnedPriceOrigins` und `ShoppingItem.priceSource`/`priceSourceDate` haben Standardwerte (leer bzw. `nil`) und laden im In-Memory-Container ohne Fehler (additiv, ohne Schema-Bump).
- [x] **AC-13:** Die Quelltexte lauten „Bon · 12.10.“ (ohne Datum „Bon“), „bezahlt“, „gelernt“, „eigener Preis“, „Schätzung“; nur bei `estimate` steht „ca. “ vor dem Betrag; das Accessibility-Label der Preiszelle kombiniert Betrag und Quelle.
- [x] **AC-14:** Abgehakte Artikel zeigen weiter nur echte Preise: abgehakt mit `estimate` → weder Preis noch Quelle; abgehakt mit echter Quelle → Preis und Quelle.
- [x] **AC-15:** Die Dev-Diagnose nennt Schlüssel, Bezugsgröße, Obergrenze und Ergebnis mit Grund und stammt aus derselben Resolver-Kette wie `init`.
- [x] **AC-16:** Alle neuen Texte existieren in de und en und sind dort verschieden vom Schlüssel.
- [x] **AC-17:** In der Artikelzeile sind Schätzung („ca. …“ + „Schätzung“), eigener Preis („2,50“ + „eigener Preis“) und Altdaten-Preis („gelernt“) im echten Durchlauf unterscheidbar; vor der Änderung zeigten Schätzung und eigener Preis denselben Text.
- [x] **AC-18:** Die Preisdiagnose erscheint im Bearbeiten-Dialog nur im Entwicklermodus.
- [x] **AC-19:** Die Bestandstests bleiben grün: `AddItemQuantitySuggestionUITests` (Menge „ca. 400 g“ exakt, Preis-„ca.“ ist ein eigener Text), `LegacyLearnedPriceResetUITests` (`testLegacyPricesAreResetAfterLaunchButManualPriceStays`) und alle Unit-Tests zu gelernten Preisen (`ShoppingItemFuzzyPriceMatchTests`, `PriceProvenanceMigrationTests`, `LegacyLearnedPriceResetTests`, `ReceiptLearningTests`, `LearnedPriceSyncTests`). `RestockUITests/LegacyLearnedPriceResetUITests::testLegacyPricesAreResetAfterLaunchButManualPriceStays` (unverändert, im gemeinsamen Lauf)

## Dialog

### Runde 1
**Adversary:** Gelesen: kompletter Diff gegen HEAD, PriceSourceTests, UI-Tests, Grün-Belege (PriceSourceTests 16/0, LegacyLearnedPriceResetUITests 3/0, AddItemQuantitySuggestionUITests 6/0, Unit-Suite 514/0). Kein eigener xcodebuild-Lauf (Sperren belegt). Alle `estimatedPrice =`-Schreibstellen per grep geprüft: init, EditItemView (3), ReceiptLearning (2), ActualPriceEntryView, LegacyLearnedPriceReset, PriceProvenanceMigration Phase B (Altbestand, einmalig; Quelle bleibt leer, Ableitung korrekt), Seed. Keine nach dem Upgrade laufende Schreibstelle vergisst die Quelle.

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Models/ShoppingItem.swift:136
  Evidence: init ruft resolveLearnedPrice; Äquivalenz zur alten Kette von Hand nachgerechnet (Obergrenze: alt plausibleMatch nil -> learnedRateUsage(nil) = reject, neu exceedsCap -> reject; rateOnly setzt unit g; Bool = price == nil). Test iteriert 60 Zeilen plus Stichproben gegen learnedRateUsage. Beweisschwäche siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Models/ShoppingItem.swift:190
  Evidence: Resolver ruft unverändert matchingLearnedPriceKey; Test deckt Teilstring, Fuzzy, Tie-Breaker (Datum, Alphabet), kein Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/ShoppingItem.swift:199
  Evidence: exceedsCap = entryPrice * (quantityAmount > 0 ? quantityAmount : 1) > 200 (strikt größer, 200,00 greift); identisch zur alten Rechnung.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Models/ShoppingItem.swift:208
  Evidence: Reihenfolge noStore, noEntry, exceedsCap, dann Tabelle; legacyNoUnit nur bei nil/leer (gleiche Trimmung wie learnedRateUsage Zeile 291), sonst unitMismatch; alle 7 Gründe erreichbar.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Models/ShoppingItem.swift:175
  Evidence: priceOrigin: bekannte Kennung gilt, sonst Bool-Ableitung; aus Altdaten nur estimate/learned, auch bei unbekanntem Wert.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/ShoppingItem.swift:150
  Evidence: applyPriceSource: receipt (Datum aus learnedPriceDates[matchedKey]), paid, sonst learned; ohne angewendeten Preis estimate. Bei rateOnly ist price != nil, Quelle aus Origin.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:272
  Evidence: apply setzt receipt+Datum im selben Zug in .apply und .rateOnly (Zeile 277), .reject unberührt; save() ruft learn(...) (Zeile 772), das Preis, Bezugsgröße, Datum, Origin schreibt (ab Zeile 291). Der save()-Aufruf ist nur per Code-Lesung belegt (F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Views/Prices/ActualPriceEntryView.swift:170
  Evidence: Origin paid im Laden und priceSource paid/Datum nil am Artikel im selben Block; beide Aufrufer reichen store durch (Zeilen 136, 144).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Store/EditItemView.swift:372
  Evidence: applyPriceEdit: Zahl > 0 -> manual; leeres Feld -> estimate + Bool true; Einheitenwechsel nur bei Bool true -> estimate. save() ruft die Funktion (Zeile 451). Ungültiger Text ändert nichts, wie vorher.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Models/LegacyLearnedPriceReset.swift:44
  Evidence: priceSource estimate, Datum nil neben Preis und Bool; Läden werden nicht angefasst.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Services/SharedStoreService.swift:603
  Evidence: removeValue bei !samePrice nach dem units-Skip (Zeile 600); State unverändert (keine Origins). Randfall siehe F003.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Models/Store.swift:56
  Evidence: Standardwert [:] am Property und im init (Zeile 144); Artikelfelder Standard leer/nil (ShoppingItem.swift:68-69); additiv, Unit-Suite 514/0 lädt den In-Memory-Container.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Components/ItemRow.swift:173
  Evidence: priceCell: ca. nur über amountPrefix bei estimate, im selben Text wie der Betrag; Warnfarbe amber nur bei estimate; Accessibility-Label kombiniert Betrag und Quelle; Strings in de und en; Gramm-Rate (Zeile 159) geht ebenfalls durch priceCell.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Views/Components/ItemRow.swift:153
  Evidence: showsPrice-Regel (Zeile 192) umschließt Betrag UND Quelle in beiden Zweigen; Regel gleich der alten.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Views/Store/EditItemView.swift:297
  Evidence: Abschnitt ruft PriceDiagnosis.lines -> resolution -> resolveLearnedPrice (dieselbe Kette); zeigt Schlüssel, Bezugsgröße, Obergrenze, Ergebnis mit Grund; nur bei developerMode (Zeile 198).
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: SmartCart/Models/ShoppingItem.swift:431
  Evidence: allLocalizationKeys enthält alle Schlüssel plus 7 Gründe; de- und en-Einträge nachgelesen (je 19 Zeilen), verschieden vom Schlüssel und voneinander.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/SmartCartApp.swift:398
  Evidence: Seed: Kontrollbrot=manual, Altdatenbrot=Altdaten (Zeile 408); testPriceSourceDistinguishesEstimateManualAndLearned liest echte Zeilentexte (Beleg 3/0). Bon/bezahlt nicht im Durchlauf (F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: SmartCart/Views/Store/EditItemView.swift:198
  Evidence: if developerMode { priceDiagnosisSection }; UI-Test prüft beide Zweige im echten Durchlauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: SmartCart/Views/Components/ItemRow.swift:192
  Evidence: Belege: AddItemQuantitySuggestionUITests 6/0, LegacyLearnedPriceResetUITests 3/0, Unit-Suite 514/0; ca. 400 g bleibt eigener Text (Mengenzeile unberührt). Frischer Lauf nötig, falls sich Code nach Runde 1 ändert.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: RestockTests/PriceSourceTests.swift:145
  Description: Das Orakel des Paritätstests (assertInitMatchesResolver) leitet die Erwartung aus dem Resolver-Ergebnis ab, und init ruft denselben Resolver. Der Test fängt eine Abweichung der extrahierten Kette von der ALTEN Kette nicht; nur Stichproben (ab Zeile 187) und Einzelfälle in AC-3/4 sind unabhängig.
  Spec requirement: AC-1 — init liefert über alle Zeilen dieselben Werte wie bisher
  Conflict: Beweiskraft schwächer als der Name; von mir von Hand als äquivalent nachgerechnet, aber kein automatischer Beleg gegen die alte Logik.
  Remediation: Erwartungstabelle der 60 Zeilen handschriftlich (apply/rateOnly/reject) statt aus dem Resolver, oder die alte Kette aus der Versionsverwaltung als Orakel.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:772
  Description: Verdrahtung save() -> learn(), EditItemView.save() -> applyPriceEdit und die ActualPriceEntryView-Aufrufer sind von keinem Test durchlaufen; getestet sind nur die statischen Seams. Bon-/bezahlt-Anzeige mit Datum in der Zeile hat keinen UI-Durchlauf.
  Spec requirement: AC-7, AC-8, AC-17
  Conflict: Ein vergessener Aufruf in save() bliebe grün (Testaufbau stellt den Ausgangszustand selbst her).
  Remediation: Durchlauf im Simulator oder UI-Test mit Bon-Fixture, der "Bon" in der Zeile prüft.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/SharedStoreService.swift:599
  Description: samePrice verlangt gleiches Datum UND gleichen Betrag. Ein Fremdstand mit gleichem Betrag, aber neuerem Datum löscht die Herkunft (Anzeige gelernt).
  Spec requirement: AC-11
  Conflict: Mehrdeutig, ob abweichend über Betrag oder Datum definiert ist; der Ausgang ist der sichere.
  Remediation: In der Spec festhalten oder Test "gleicher Betrag, neueres Datum" ergänzen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:284
  Description: priceSourceDate ist der Lernzeitpunkt (Date()), nicht das Bondatum; "Bon · 12.10." zeigt, wann gescannt wurde. Zwei getrennte Date()-Aufrufe (Zeile 285 und 772) lassen Artikel- und Laden-Datum bei Mitternacht auseinanderlaufen. PriceProvenanceMigration Phase C (ShoppingItem.swift:682) schreibt learnedPrices um, ohne die Herkunft zu berühren (einmalig, Altbestand).
  Spec requirement: AC-6/AC-7 (Datum aus learnedPriceDates)
  Conflict: Spec-konform, aber der Nutzer könnte das Bondatum erwarten.
  Remediation: In Offene Grenzen vermerken; learn() und markReceiptSource dasselbe Datum übergeben.

### Runde 2
**Adversary:** Belege selbst gelesen (adversary-round2-output.txt und die Einzelprotokolle), Testcode nachgelesen, Screenshots aus der Übersicht übernommen (nur Zeilentexte und Farben, kein Dunkelmodus-Bild).

Läufe: PriceSourceTests 18/18 grün; LegacyLearnedPriceResetUITests 3/3 und AddItemQuantitySuggestionUITests 6/6 grün (9/9); volle RestockTests 516/516 grün (erster Versuch hing unter Fremdlast, Runner nie gestartet, 0 Tests, kein Ergebnis, Muster #63, nicht gewertet); ReceiptReviewUITests 23 Tests, 1 rot (testChangeEditorWorksInDarkMode, Preisfeld erscheint nicht) unter paralleler Fremdlast, derselbe Test allein auf frisch gebootetem Gerät ohne Fremdlast grün (52 s). Die Rotprobe liegt in der Bon-Änderungsmaske, deren Code (ReceiptReviewCard) der Diff nicht berührt; Last-Flake bekannter Art (#111), AKZEPTIERT mit Vermerk. xcodebuild endete jeweils nicht selbst und wurde von Hand beendet; maßgeblich sind die Executed-Zeilen.

F001 BEHOBEN: testInitMatchesHandWrittenExpectationsFromPreviousChain stellt eine handgeschriebene Tabelle mit festen Zahlen auf (z. B. Grammrate an Stück-Artikel -> 4,00 Schätzung, Obergrenze 199,98/200,00/200,01 mit 99,99/100/100,005 x 2, Menge 0 mit 200 -> greift). Die Erwartung stammt nicht aus dem Resolver; damit ist die Äquivalenz zur alten Kette automatisch belegt, nicht nur von Hand.

F002 BEHOBEN: testReceiptLearnThenNewItemShowsReceiptWithDate geht learn -> neuer Artikel -> receipt, Datum == learnedAt, Text "Bon · 12.10."; testSavedReceiptShowsReceiptAsPriceSource (UI, grün, 30 s) durchläuft echtes Speichern eines Bons bis zur Anzeige "Bon · " in der Zeile und schließt damit die Verdrahtung save() -> learn() und die Bon-Anzeige im echten Weg. Restlücke: Verdrahtung EditItemView.save() -> applyPriceEdit und ActualPriceEntryView-Aufrufer (Zeilen 136/144) weiter nur per Code-Lesung und über die Seams belegt; "bezahlt" hat keinen Durchlauf. Geringes Risiko (Aufruf je eine Zeile, Lesung eindeutig); als offene Grenze geführt.

F003 offene Grenze (LOW, mehrdeutig, sicherer Ausgang "gelernt"). F004 offene Grenze (LOW, spec-konform: Datum ist Lernzeitpunkt, nicht Bondatum; zwei Date()-Aufrufe; Phase C lässt Herkunft stehen). Beide gehören in "Offene Grenzen" der Spec und sind kein Blocker.

Code reference: SmartCart/Models/ShoppingItem.swift:136
Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:772
Code reference: RestockTests/PriceSourceTests.swift:753

Offene Grenzen (nicht blockierend): F003, F004, "bezahlt" und Edit-Verdrahtung ohne Durchlauf, Dunkelmodus der Preiszelle nicht fotografiert (Farben .amber/.secondary adaptiv), CloudKit-Produktionsschema vor dem Upload per cktool veröffentlichen, nichts auf Hennings Geräten geprüft.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Eigene Prüfung der Schreibstellen von `priceSource`: ShoppingItem.init (immer), ReceiptLearning.apply (Bedingung: Plan nicht .reject), ActualPriceEntryView.apply (Bedingung: itemActualTotal > 0), EditItemView.applyPriceEdit (Bedingung: Feld geändert und gültig bzw. leer; oder Einheit geändert und Bool true), LegacyLearnedPriceReset (Bedingung: Fingerabdruck trifft). Test für diesen Weg: PriceSourceTests über die statischen Seams; die Verdrahtung in save() hat keinen Test (F002).

## Verdict
VERIFIED. 19/19 ACs belegt (Code, Unit 516/516, UI 9/9 plus neuer Bon-Durchlauf, Screenshots). F001 und F002 behoben, F003/F004 als offene Grenzen. Tests: 516 bestanden, 0 fehlgeschlagen, 0 übersprungen (Unit); die eine UI-Rotprobe unter Fremdlast ist allein grün wiederholt.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════

## Geprüfte Dateien

- sha256:ab98a2ae7dd42b0259b06a4c44b6c5cf51e38f16944f0f856cde22da14e80b50  RestockTests/PriceSourceTests.swift
- sha256:056df7fc72d136c7876ce7cbb8eb549040d6bdda86cff311c295f1680104bfeb  SmartCart/Models/LegacyLearnedPriceReset.swift
- sha256:2a031f251614caa1c162e6be4f32edb5d788ea73f4f4af445db1c20b8f48c8fe  SmartCart/Models/ShoppingItem.swift
- sha256:2d1a30e2de57a6d1d16840f3122dbf2d8796167457a7c5e0d5af622af89b4eb6  SmartCart/Models/Store.swift
- sha256:545aefd48e350e14900e67eeef2a8c544ffb808ff761294be71839a5541ed1bb  SmartCart/Services/SharedStoreService.swift
- sha256:c42c8f4e2e3ae9e6f2f1808fc188a90a977c85416b629309c7b97128267b76e3  SmartCart/SmartCartApp.swift
- sha256:cd62ecc6a4ce090d4b6cec149d05e9dd615012a865b6d4c7e594c7274e9b9965  SmartCart/Views/Components/ItemRow.swift
- sha256:03f6521348b966e96cb39a555f700729686587dd3ac31f24c8ea51597db0e06c  SmartCart/Views/Prices/ActualPriceEntryView.swift
- sha256:e5a3f4f257454e476f180a6fcc7f760f8b7fda79aa915997ecb77aad37e66b9f  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:7dc30e3f12783b79e51e03691b446957a7388e367780c6c993faac42a2a618a4  SmartCart/Views/Store/EditItemView.swift

## Prüfbasis

- base: c901ae57bcd49a6837149a31b99eec7f01c28ebc
- blob:eec839ac9ecbd2cc62e0d5b5048a294fab59c0cb  RestockTests/PriceSourceTests.swift
- blob:72d16f338b59a998450c26f56c26a563ed1a5999  SmartCart/Models/LegacyLearnedPriceReset.swift
- blob:f80920e8fa82c39c9455f648a26a765bd6e295be  SmartCart/Models/ShoppingItem.swift
- blob:4535ff47d25872e83d362df0926ae2dc7f63e402  SmartCart/Models/Store.swift
- blob:bb5742dc8c67f800a108c61d141cb7f54a850ad2  SmartCart/Services/SharedStoreService.swift
- blob:0c123ce1c0a7fad7efb35057d49c92ba7b2d1b28  SmartCart/SmartCartApp.swift
- blob:50d453c362da5c7e89379eaf8ed19b2269887805  SmartCart/Views/Components/ItemRow.swift
- blob:c8a1d2e92dd9ff83232108b7414c787bc9fd179d  SmartCart/Views/Prices/ActualPriceEntryView.swift
- blob:c39d577cea0324659bab6f34ec64be844ed2acca  SmartCart/Views/Prices/ReceiptScannerView.swift
- blob:7ee6d62ef7db11c7ec6b2b058129fe2f401344d6  SmartCart/Views/Store/EditItemView.swift
