# Adversary-Dialog — Issue #54 (fix-54-bon-gewicht)

Spec: `docs/specs/views/receipt-save-purchase-quantity.md`
Prüfer: implementation-validator (unabhängig, Spec-getrieben). Protokoll: Orchestrator.

## Checkliste

- [x] AC-1: weightBasis 706 -> Datensatz 706/"g", Preis 1,76 unverändert (testWeightLineGivesGrams, testSaveRecordWeightLineStoresGramsAndPrice, UI-Durchstich AC-7)
- [x] AC-2: Packungsgröße im Namen -> (500,"g"), Rohtext "500g" nicht übernommen (testPackageSizeInNameGivesGrams, testSaveRecordPackageSizeIgnoresRawUnitText)
- [x] AC-3: 1,5L -> (1500,"ml"), 0,5L, 33cl, 1KG -> (1000,"g") (testLiterSizeInNameGivesMilliliters, testEdgeKilogramInNameGivesGrams)
- [x] AC-4: quantity 4 -> (4,""), nichts bekannt -> (1,"") (testQuantityGreaterOneGivesPieces, testNothingKnownGivesOneWithoutUnit, testEdgeQuantityZeroOrFractionWithoutSizeGivesOne)
- [x] AC-5: Übereinstimmung mit learningQuantity/learningUnit bei weightBasis (testAgreesWithLearningQuantityForWeightCases)
- [x] AC-6: Umschalter Gramm/Stück über weightBasis nil/gesetzt (testSwitchingToPiecesFallsBackToQuantity)
- [x] AC-7: UI-Durchstich Speichern -> Ausgabenansicht zeigt "706 g" und 1,76 € (testSavedWeightLineShowsGramsInExpenses, grün im Gesamtlauf)
- [x] AC-8: Rot-Lauf am echten Weg vor dem Fix, inhaltlich (Eintrag sichtbar, "706 g" fehlt), test-red-ui-real-output.txt
- [x] AC-9: Match-Zweig und Preislogik unverändert, Bestandstests grün (ReceiptParserPriceTests 23, ReceiptReviewUITests 22)

## Dialog

### Runde 1

Verdict nach Runde 1: AMBIGUOUS (leicht Richtung VERIFIED). Der eigene Unit-Lauf des Prüfers scheiterte am bekannten Testrunner-Hänger (#63), kein Produktfehler.

- F001 (MEDIUM, spec_violation): Kein Test belegt, dass `save()` den Datensatz über `purchaseRecordQuantity()` anlegt; die 7 Unit-Tests rufen nur die Methode auf.
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
- F002 (MEDIUM, edge_case): Randfälle quantity 0 und 0,5, 1KG ungetestet.
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
- F003 (LOW, edge_case): weightBasis <= 0 ungeschützt; praktisch nicht erreichbar (Parser verlangt weight > 0, Karte setzt <= 0 auf nil).
- F004 (LOW, edge_case): mehrere Größen im Namen ungetestet.
- F005 (LOW, anti_pattern): Cleanup löscht alle PurchaseRecords (nur DEBUG).
  Code reference: SmartCart/SmartCartApp.swift

Reaktion: Developer Agent zog die Datensatz-Erstellung in `EditableReceiptLine.makePurchaseRecord(storeName:)`, `save()` ruft sie auf; 7 neue Tests (3 am Datensatz, 4 Randfälle). Wiring-Probe mit absichtlich falscher Verdrahtung: 14 Tests, 5 Fehler (`test-red-wiring-output.txt`); Probe zurückgenommen.

### Runde 2

Beweise: Gemeinsamer Lauf `test-green-output.txt` — Unit 37 Tests (23 + 14), UI ReceiptReviewUITests 22 Tests, 0 Fehler, TEST SUCCEEDED, kein Retry, kein Runner-Hänger, kein Null-Test-Lauf.

Bewertung des Prüfers:
- F001 behoben: Record-Tests laufen über dieselbe Funktion, die `save()` aufruft; Wiring-Probe beweist Wirksamkeit.
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift
- F002 behoben: neue Randfalltests im Grün-Lauf.
  Code reference: RestockTests/ReceiptSavePurchaseQuantityTests.swift
- F003, F004 als LOW akzeptiert.
- F005 LOW, teilweise belegt: Der gemeinsame Lauf umfasst nur die Klasse ReceiptReviewUITests, nicht alle UI-Klassen. Empfehlung: ganze UI-Suite einmal laufen lassen (in /60-validate).
  Code reference: SmartCart/SmartCartApp.swift

Neue Defekte: keine.

## Verdict: VERIFIED

## Geprüfte Dateien

- sha256:657509822ba09749ae3dd5af789d873fc23446fa506c8b60f934313dc81208f2  RestockTests/ReceiptSavePurchaseQuantityTests.swift
- sha256:9108b7510ece72a7291b02057b245475b872fd4b8d41f993ba88fe79a6c932e7  SmartCart/SmartCartApp.swift
- sha256:c914f8f49b8df9b54d424d8c148be38b24831c6fd63af8099b308e1938586787  SmartCart/Views/Prices/ReceiptScannerView.swift
