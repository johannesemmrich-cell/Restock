# Adversary Dialog Runde 2: fix-10-preis-einheit

Spec: docs/specs/models/learned-price-unit-and-quantity-source.md
Vorgeschichte: docs/artifacts/fix-10-preis-einheit/adversary-dialog.md (Urteil Runde 1: BROKEN,
Grund ausschliesslich AC-20), docs/artifacts/fix-10-preis-einheit/adversary-dialog-widerspruch.md.

### Runde 1 - Widerspruch, AC-20-Gegenprobe und Pruefung der #60-Reparatur

## 0. Ueberpruefung des Widerspruchs zu Runde 1

Der Widerspruch behauptet, test-green-final.txt sei entgegen der Runde-1-Einschaetzung nicht
gegen ein unvollstaendiges Test-Binary gelaufen, weil ReplenishmentPackageCTests.swift durch
Commit d6f8659 (#58) NACH diesem Lauf um acht Testmethoden erweitert wurde.

Eigenstaendig nachvollzogen: das stat des Commits zeigt 110 eingefuegte Zeilen in
RestockTests/ReplenishmentPackageCTests.swift. Zaehlung der Testmethoden: vor jenem Commit 17,
direkt danach 25, aktuell im Arbeitsstand 33.

test-green-final.txt (Testlauf-Start 2026-09-26 15:30:52, laut Protokoll-Zeile
"Test Suite ReplenishmentPackageCTests started at 2026-09-26 15:30:52.768") lief VOR
d6f8659 (2026-09-26 16:33:39). Der Lauf konnte die acht spaeter hinzugekommenen Tests also nicht
ausgefuehrt haben, weil sie zu diesem Zeitpunkt nicht existierten -- kein stiller Ausfall, kein
unvollstaendiges Binary. Der Widerspruch ist korrekt; ich uebernehme das.

Das aendert nichts am Runde-1-Verdikt selbst: BROKEN stand ausschliesslich auf einem echten,
dreifach reproduzierten gemeinsamen Fehlschlag (testAddingMenuPlanRecipeDoesNotCrash,
#10-fremd), nicht auf der jetzt widerlegten Testzahlen-Diskrepanz. Das wird im Widerspruchs-Dokument
selbst schon so festgehalten und hier nur gegengeprueft.

## 1. AC-20 neu bewertet

Zwei unabhaengige, vollstaendige gemeinsame Laeufe nach der #60-Reparatur liegen vor:

- docs/artifacts/fix-10-preis-einheit/test-ac20-gemeinsam.txt (Orchestrator/Implementer,
  2026-09-26 19:13-19:20 Uhr).
- docs/artifacts/fix-10-preis-einheit/adversary-run2.txt (eigener, unabhaengiger Lauf dieser
  Runde, 2026-09-26 19:25-19:31 Uhr, Kommando: xcodebuild test, Simulator Restock-Validate,
  only-testing RestockTests und RestockUITests).

Beide zeigen identisch: RestockTests "Executed 264 tests, with 0 failures (0 unexpected)"
(test-ac20-gemeinsam.txt:779; adversary-run2.txt:780), RestockUITests
"Executed 22 tests, with 1 test skipped and 0 failures (0 unexpected)"
(test-ac20-gemeinsam.txt:2029; adversary-run2.txt:2030), genau einmal TEST SUCCEEDED, kein
TEST FAILED, kein Retrying oder Restarting after unexpected exit, kein Null-Test-Lauf. Die
ReplenishmentPackageCTests-Teilsuite zeigt in beiden Laeufen 33 Tests -- deckungsgleich mit der
aktuellen Dateizahl (33 Testmethoden), also gegen ein vollstaendiges, aktuelles Test-Binary
gelaufen, nicht gegen ein veraltetes wie in Runde 1.

Beide zuvor scheiternden Tests laufen in meinem eigenen Lauf gruen:
testAddingMenuPlanRecipeDoesNotCrash PASSED (25.819s, adversary-run2.txt:1768),
testChangeEditorWorksInDarkMode PASSED (15.774s, adversary-run2.txt:925).

AC-20 ist damit durch zwei unabhaengige, vollstaendige, aktuelle Laeufe belegt. PROVEN.

## 2. Reparatur von Issue #60 geprueft

Der Commit zur Testdatei (5d968eb) zeigt: neues DEBUG-only Startargument
-clearMenuPlanForUITests leert vier UserDefaults-Schluessel (menuPlanJSON, menuIngredientsJSON,
menuPortionsJSON, menuAddedDaysJSON). Abgleich mit SmartCart/Views/Home/MenuPlanView.swift Zeilen
13-17, 148-150, 336: exakt dieselben vier Schluessel, plannedIndices liest meals aus menuPlanJSON
-- Leeren dieses einen Schluessels reicht bereits, um plannedIndices.count auf 0 zu setzen und den
Knopf wieder zu rendern. Ein Vergleich seit dem ersten #10-Commit zeigt KEINE Aenderung an dieser
Datei -- Produktverhalten unveraendert bestaetigt, nicht nur behauptet.

tearDown() (RestockUITests.swift) startet die App erneut mit demselben Loesch-Argument und
terminiert sie wieder; docs/artifacts/fix-60-menuplan-uitest/menuplan-keys-nach-lauf1.txt belegt,
dass nach Lauf 7 keiner der vier Schluessel mehr existiert.

Die Dreifach-Oeffnen-Haertung (Folgecommit 6de6c62) schwaecht die Assertion nicht ab (weiterhin
XCTAssertTrue mit Fehlertext, kein XCTSkip, kein weicherer Timeout) und ist durch eine konkrete,
im Protokoll nachvollziehbare Zeitmessung begruendet (0.47s vs. 1.24s bis App idle, run4.txt vs.
run3.txt). In meinem eigenen Lauf (adversary-run2.txt, Zeilen 1687-1770) genuegte der ERSTE Tap
-- die Schleife wird nicht routinemaessig gebraucht, was zur Diagnose einer seltenen Race zwischen
Tap und Re-Render durch fetchIngredients() passt und gegen eine dauerhaft verdeckte Fehlfunktion
spricht. Dennoch: dieselbe Race koennte theoretisch auch einen echten Nutzer treffen (Tap auf
"+ Liste" genau waehrend die Zeile durch den asynchronen Ingredienten-Abruf neu gezeichnet wird)
-- das ist eine potenzielle, ungetestete Produkt-UX-Frage, aber ausserhalb von MenuPlanView.swift
und ausserhalb von #10s Aenderungsdateien; siehe Finding F004.

Fazit: #60-Reparatur ist eine legitime Testzustands-Haertung, keine Vertuschung. PROVEN
(Produktverhalten unveraendert, Aufraeumen nachgewiesen).

### Runde 2 - Adversarial Probing von AC-1, Stichprobe der uebrigen ACs und neue Befunde

## 3. AC-1 / F001 erneut bewertet

RestockTests/ReceiptParserPriceTests.swift:376-434 unveraendert seit Runde 1:
learnLikeSave ruft learningQuantity und learningUnit (echte Produktivmethoden) auf, dupliziert
aber die drei Schreibzeilen (learnedPrices, learnedPriceUnits, learnedPriceDates) statt
ReceiptScannerView.save() selbst aufzurufen. Issue 59 (state OPEN) dokumentiert exakt diese
Luecke und schlaegt den Schnitt in eine eigene Funktion vor.

Entscheidung: Dies verhindert KEIN VERIFIED. Begruendung: erstens exerzieren
testSavedReceiptDoesNotProduceOneCentItemPrice (AC-17) und
testSavingStillWritesLearnedPriceToMatchedItem (AC-19) den echten save()-Pfad end-to-end und
wuerden eine Regression an genau diesen drei Zeilen ueber ihr sichtbares Symptom auffangen;
zweitens bestaetigt Code-Lektuere von ReceiptScannerView.swift Zeilen 671 bis 680, dass die drei
Zeilen aktuell korrekt sind; drittens ist die Luecke als eigenes Issue 59 offen erfasst, nicht
verschwiegen. Bleibt MEDIUM, dokumentiertes Regressionsrisiko, trotzdem tragbar.

## 4. Stichprobe AC-2 bis AC-10, AC-17, AC-19

Code gegen Spec-Tabelle (ShoppingItem.swift:127-176, learnedRateUsage, unitBucket) Zeile fuer
Zeile verglichen: deckt sich exakt mit der Entscheidungstabelle aus "Implementation Details 3".
EditableReceiptLine.learningUnit (ReceiptScannerView.swift:66-93) spiegelt learningQuantity in
identischer Reihenfolge; testLearningUnitMatchesLearningQuantityBranchForEveryCase
(ReceiptParserPriceTests.swift:441-484) prueft alle fuenf Zweige an derselben Instanz -- kein
nachgebauter Test. ReceiptParserService.packageSizeFromName (ReceiptParserService.swift:924-932)
nutzt weightBasisFromName fuer den Zahlenwert und unterscheidet nur die Anzeige-Einheit ml/g --
deckt sich mit AC-10. ActualPriceEntryView.swift:166 und EditItemView.swift:342-343 decken sich
wortgleich mit Spec-Abschnitten 2 und 8. Alle Stichproben PROVEN, keine Abweichung gefunden.

## 5. Neuer Befund: Spec ueberzeichnet den Stand von Abschnitt 7 (ItemRow)

Die Spec behauptet unter "Nach Issue 57 verschoben": der Code zu Abschnitt 7 (ItemRow) sei in
#10 schon geschrieben, sein Verhalten aber erst in #57 nachzuweisen. Abschnitt 7 selbst nennt ZWEI
Ergaenzungen an der Mengenzeile (beide tatsaechlich vorhanden, ItemRow.swift:85-93) UND eine
Ergaenzung an der Preiszelle: ist estimatedLineTotal nil, quantitySource gleich none und item.unit
gleich g, soll stattdessen die Rate als estimatedPrice mal 100 mit dem Zusatz pro 100 g angezeigt
werden.

ItemRow.swift Zeilen 140 bis 149 (aktuelle Preiszelle) enthaelt diesen Zweig NICHT -- eine Suche
nach estimatedPrice in dieser Datei liefert keinen Treffer, eine Suche nach 100 g im gesamten
Views-Verzeichnis liefert nur Treffer in anderen, #10-fremden Dateien (ReplenishmentStatsView.swift,
ReceiptReviewCard.swift, PaywallView.swift). Die Preiszelle zeigt bei quantitySource gleich none
schlicht gar keinen Preis (weil estimatedLineTotal dort nil ist und die if-let-Bedingung
fehlschlaegt) -- funktional sicher, kein falscher Betrag, aber nicht das von der Spec behauptete
Verhalten.

Das blockiert KEINE AC von #10: die einzige AC, die dieses Verhalten explizit fordert (AC-15,
testItemWithoutEvidenceShowsRateInsteadOfTotal) ist selbst ausdruecklich nach #57 verschoben, und
kein Aufrufpfad in #10 kann quantitySource ueberhaupt auf none setzen (dafuer fehlt
suggestQuantity, das erst #57 liefert) -- der Zweig ist in #10 unreachable, exakt wie von der Spec
selbst fuer den erreichbaren Teil von Abschnitt 7 behauptet. Es ist aber eine falsche
Vollstaendigkeitsbehauptung der Spec, die #57 zu einer kleineren Restarbeit erklaert als sie ist.
Siehe Finding F003.

## Findings

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Description: Spec-Abschnitt Implementation Details 7 und der Vermerk unter Nach Issue 57
    verschoben behaupten, der Code zur Preiszellen-Ergaenzung (Rate als estimatedPrice mal 100
    mit Zusatz pro 100 g statt Gesamtpreis, wenn quantitySource gleich none) sei in #10 bereits
    geschrieben. Er ist es nicht -- ItemRow.swift Preiszelle kennt nur estimatedLineTotal, keinen
    Rate-Fallback.
  Evidence: SmartCart/Views/Components/ItemRow.swift Zeilen 140 bis 149, kein Treffer fuer
    estimatedPrice oder 100 g in dieser Datei; Spec-Datei Abschnitt Implementation Details Punkt
    7, zweiter Absatz, und Abschnitt Nach Issue 57 verschoben.
  Remediation: Spec-Aussage praezisieren, nur der Mengenzeilen-Teil von Abschnitt 7 ist
    vorgeschrieben, oder den fehlenden Preiszellen-Zweig nachtragen, bevor #57 seinen Umfang
    schaetzt. Kein Produktrisiko in #10 selbst, da der Zweig unreachable ist und die aktuelle
    Preiszelle bei fehlendem Gesamtpreis lieber gar nichts zeigt als einen falschen Betrag.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Description: Die #60-Haertung (dreifacher Menu-Oeffnen-Versuch) belegt eine reale, wenn auch
    seltene Race zwischen einem synthetisierten Tap auf plus Liste und dem Re-Rendering der Zeile
    durch fetchIngredients(). Das ist eine Beobachtung ueber das Produktverhalten von SwiftUI Menu
    in MenuPlanView, nicht nur ueber den Testlauf -- ein realer Nutzer, der im selben Moment
    tippt, koennte denselben verschluckten Tap erleben.
  Evidence: docs/artifacts/fix-60-menuplan-uitest/run4.txt (Tap bei t gleich 17.50s, App idle
    bereits bei t gleich 17.80s, 0.47s) gegen run3.txt (Tap bei t gleich 16.89s, App idle erst bei
    t gleich 18.43s, 1.24s); SmartCart/Views/Home/MenuPlanView.swift, fetchIngredients-Aufruf beim
    Anlegen eines Tages, Zeilen um 233 bis 236, triggert das Re-Rendering, das den Tap verschluckt.
  Remediation: Ausserhalb von #10 und #60 als eigenes, kleines UX-Issue erfassen, etwa Menu-Anchor
    stabilisieren oder Tap erst nach settle abfeuern -- keine Aenderung in #10 notwendig oder
    angemessen.

## Confirmations

Confirmation:
  AC: AC-20
  Code reference: docs/artifacts/fix-10-preis-einheit/adversary-run2.txt Zeilen 780 und 2030
  Evidence: Eigener, unabhaengiger gemeinsamer Lauf: 264 von 264 RestockTests, 22 RestockUITests
    (1 uebersprungen), 0 Fehlschlaege, TEST SUCCEEDED, deckungsgleich mit test-ac20-gemeinsam.txt
    (Implementer-Lauf). Beide vollstaendig und aktuell, 33 von 33
    ReplenishmentPackageCTests-Methoden, keine veraltete Zaehlung wie in Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift Zeilen 66 bis 93 und 671 bis 680
  Evidence: Code-Lektuere bestaetigt korrekte Schreibzeilen; testSavedReceiptDoesNotProduceOneCentItemPrice
    (AC-17) und testSavingStillWritesLearnedPriceToMatchedItem (AC-19) exerzieren den echten
    save()-Pfad end-to-end und beide liefen in adversary-run2.txt gruen. Testluecke an den drei
    Schreibzeilen bleibt, Finding F001 aus Runde 1, Issue 59 offen, aber MEDIUM und nicht
    blockierend.
  Status: CONFIRMED, mit dokumentiertem Regressionsrisiko F001 und Issue 59

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 159 bis 165
  Evidence: testLearnedGramPriceIsNotAppliedToItemWithoutQuantity, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 157 bis 165
  Evidence: testLearnedGramPriceAppliesToItemWithGramQuantity, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 161 bis 165
  Evidence: testLearnedPieceRateIsRejectedForWeightItem, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Models/ShoppingItem.swift Zeile 159
  Evidence: testMigrationRepairsCorruptedStoreLearnedPrice, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 161 bis 165 und 261 bis 264
  Evidence: testLearnedGramRateWithoutEvidenceIsKeptAsRate, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 161 bis 165
  Evidence: testLearnedGramRateIsRejectedForKilogramItem, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/ShoppingItem.swift Zeilen 167 bis 176
  Evidence: testUnitBucketMapsSynonymsAndUnknownUnits, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift Zeilen 66 bis 93
  Evidence: testLearningUnitMatchesLearningQuantityBranchForEveryCase, gruen in adversary-run2.txt.
    Alle fuenf Zweige an derselben Instanz gegeneinander geprueft.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Services/ReceiptParserService.swift Zeilen 924 bis 932
  Evidence: testPackageSizeFromNameReturnsLitreAsMillilitre und
    testPackageSizeFromNameAgreesWithWeightBasisFromName, gruen in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift Zeilen 671 bis 680
  Evidence: testSavedReceiptDoesNotProduceOneCentItemPrice, PASSED in adversary-run2.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: RestockUITests/ReceiptReviewUITests.swift Zeilen 667 bis 687
  Evidence: testSavingStillWritesLearnedPriceToMatchedItem, PASSED in adversary-run2.txt.
  Status: CONFIRMED

## Testzusammenfassung

Eigener Lauf, adversary-run2.txt: RestockTests 264 von 264 gruen. RestockUITests 22 Tests, 1
uebersprungen wie erwartet, 0 Fehlschlaege, 21 bestanden. TEST SUCCEEDED. Deckungsgleich mit dem
vom Orchestrator vorgelegten test-ac20-gemeinsam.txt. Alle dreizehn fuer #10 relevanten ACs liefen
dabei gruen.

## Verdict: VERIFIED

Grund: Beide Blocker aus Runde 1 sind aufgeloest. AC-20 ist jetzt durch zwei unabhaengige,
vollstaendige, aktuelle gemeinsame Laeufe belegt, Implementer-Lauf und eigener Pruefer-Lauf mit
identischen Zahlen: 264 von 264 plus 22 mit 1 skip von 22, 0 Fehlschlaege, TEST SUCCEEDED, keine
Retries oder Aborts. Der #10-fremde MenuPlan-Fehlschlag ist durch eine Testzustands-Reparatur
behoben, die das Produktverhalten nachweislich unveraendert laesst und selbst aufraeumt; die
zusaetzliche Dreifach-Oeffnen-Haertung schwaecht keine Assertion ab und ist durch eine konkrete
Zeitmessung begruendet. Der zusaetzlich instabile Dark-Mode-Test lief in beiden aktuellen Laeufen
gruen. AC-1 bleibt mit einer dokumentierten, als Issue 59 erfassten Testluecke an den
Schreibzeilen von save() bestehen -- als MEDIUM eingestuft und durch die End-to-End-Tests AC-17
und AC-19 hinreichend abgefedert, deshalb kein Blocker. Alle dreizehn ACs von #10 (AC-1 bis AC-10,
AC-17, AC-19, AC-20) sind PROVEN. Ein neuer, niedrigschweregradiger Befund F003 betrifft nur die
Vollstaendigkeits-Behauptung der Spec fuer noch unerreichbaren #57-Vorarbeitscode, blockiert aber
keine #10-AC. F004 ist eine Beobachtung ueber eine seltene, #10- und #60-fremde UX-Race in
MenuPlanView, empfohlen als eigenes kleines Issue, ebenfalls kein Blocker fuer #10.

## Geprüfte Dateien

- sha256:7ba458446e568ee9f91dd0ab7c8c9481f2becb25b1346feded45b988482ceb31  RestockUITests/ReceiptReviewUITests.swift
- sha256:4d02f735476731049369b3b116722bb6fc8a0278e14398f0f6c8ac7af123f06d  SmartCart/Models/ShoppingItem.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:73dee034586fb231da514c0789e3b2f563f8f42a85e01666a6606729a0318a31  SmartCart/Views/Prices/ReceiptScannerView.swift
- sha256:2340b989789c617ad59d107e17862ac2a9e6af08e1a4fe3f29c04185a6f95366  docs/artifacts/fix-10-preis-einheit/adversary-run2.txt
