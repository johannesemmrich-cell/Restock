# Adversary Dialog: fix-10-preis-einheit

Spec: docs/specs/models/learned-price-unit-and-quantity-source.md

Geaenderte Produktdateien laut Vergleich mit dem Ausgangsstand: SmartCart/Models/ShoppingItem.swift,
SmartCart/Models/Store.swift, SmartCart/Services/ReceiptParserService.swift,
SmartCart/Views/Components/ItemRow.swift, SmartCart/Views/Prices/ActualPriceEntryView.swift,
SmartCart/Views/Prices/ReceiptScannerView.swift, SmartCart/Views/Store/EditItemView.swift

Geaenderte Testdateien: RestockTests/PriceEstimatorStagesTests.swift,
RestockTests/PriceProvenanceMigrationTests.swift, RestockTests/ReceiptParserPriceTests.swift,
RestockUITests/ReceiptReviewUITests.swift

## Testlauf 1 - eigener, unabhaengiger Nachbau

Kommando: xcodebuild -scheme Restock -project Restock.xcodeproj -destination Simulator
Restock-Validate, only-testing RestockTests und RestockUITests, test

Vollstaendiger Output: docs/artifacts/fix-10-preis-einheit/adversary-run-1.txt

Ergebnis: RestockTests 256 von 256 gruen. RestockUITests 22 Tests, 1 uebersprungen als erwartet,
2 Fehlschlaege: RestockUITests testAddingMenuPlanRecipeDoesNotCrash, und ReceiptReviewUITests
testChangeEditorWorksInDarkMode. Testlauf endete mit TEST FAILED, exit 65. Kein Nulltest-Lauf,
kein Abbruch, kein Retry-Flag.

### Runde 1 - Abgleich Code gegen jedes der 13 ACs

- [x] AC-2 (ohne Menge, quantitySource=="user" -> Rate NICHT uebernommen): RestockTests/
  PriceProvenanceMigrationTests.swift:111-129 (testLearnedGramPriceIsNotAppliedToItemWithoutQuantity)
  + ShoppingItem.swift:127-146 (learnedRateUsage: kein learnedPriceUnits-Eintrag -> .reject). Test
  lief gruen in adversary-run-1.txt.

- [x] AC-3 (mit quantityAmount:400, unit:"g" -> estimatedLineTotal~=4.99): RestockTests/
  PriceProvenanceMigrationTests.swift:135-150 (testLearnedGramPriceAppliesToItemWithGramQuantity).
  learnedBucket "g" == itemBucket "g" -> .apply, estimatedLineTotal = perUnitPrice*400. Gruen.
- [x] AC-4 (gelernter Stueckpreis fuer unit:"g" -> verworfen): RestockTests/
  PriceProvenanceMigrationTests.swift:154-174 (testLearnedPieceRateIsRejectedForWeightItem). Gruen.
- [x] AC-5 (learnedPrices ohne learnedPriceUnits wird nie angewendet, auch bei Plausibilitaet):
  Der im Testplan angekuendigte dedizierte Test testLearnedPriceWithoutUnitIsNeverApplied existiert
  nicht (grep ueber RestockTests und RestockUITests liefert keinen Treffer). AC-5 wird aber
  funktional durch testMigrationRepairsCorruptedStoreLearnedPrice mitgeprueft
  (PriceProvenanceMigrationTests.swift:255-291): der reparierte Wert (2.29/500) ist fuer einen
  Artikel mit quantityAmount:500, unit:"g" voll plausibel, wird aber verworfen, weil kein
  learnedPriceUnits-Eintrag existiert (Zeile 286-290). Test lief gruen.
- [x] AC-6 (quantitySource=="none" -> Rate bleibt, kein Gesamtpreis, unit wird "g"): RestockTests/
  PriceProvenanceMigrationTests.swift:183-207 (testLearnedGramRateWithoutEvidenceIsKeptAsRate) plus
  ShoppingItem.swift rateOnly-Zweig und estimatedLineTotal-Guard. Gruen.
- [x] AC-7 (g-Rate fuer unit:"kg" verworfen, keine Umrechnung mal 1000): RestockTests/
  PriceProvenanceMigrationTests.swift:213-234 (testLearnedGramRateIsRejectedForKilogramItem). Gruen.
- [x] AC-8 (unitBucket Tabelle): RestockTests/PriceProvenanceMigrationTests.swift:239-250
  (testUnitBucketMapsSynonymsAndUnknownUnits). Gruen.
- [x] AC-9 (learningQuantity und learningUnit synchron ueber alle fuenf Zweige, an derselben
  Instanz): RestockTests/ReceiptParserPriceTests.swift:441-484
  (testLearningUnitMatchesLearningQuantityBranchForEveryCase). Gruen.
- [x] AC-10 (packageSizeFromName Liter und Zentiliter als ml, Zahlengleichheit mit
  weightBasisFromName): RestockTests/ReceiptParserPriceTests.swift:489-519. Gruen.
- [x] AC-17 (UI Durchstich, kein 0,01 am Artikel Hackfleisch nach Speichern): RestockUITests/
  ReceiptReviewUITests.swift:701-729 (testSavedReceiptDoesNotProduceOneCentItemPrice). In meinem
  eigenen Lauf PASSED, 18.778 Sekunden.
- [x] AC-19 (testSavingStillWritesLearnedPriceToMatchedItem bleibt gruen, Milch Pfad 0,99 Euro):
  RestockUITests/ReceiptReviewUITests.swift:667-685. In meinem eigenen Lauf PASSED, 15.905 Sekunden.
- [x] AC-20 (gesamte Bestandssuite im gemeinsamen Lauf gruen): untersucht -- Befund BROKEN, siehe Runde 2 und Finding F002/F003.

- [x] AC-1 (Bon-Zeile lernt Rate und Bezugsgroesse unter demselben Key): Code gelesen,
  ReceiptScannerView.swift:671-680: quantity kommt aus line.learningQuantity, perUnitPrice wird
  daraus gebildet, learnedUnit kommt aus line.learningUnit, danach werden learnedPrices,
  learnedPriceUnits und learnedPriceDates unter demselben Key geschrieben. Fuer die Spec-Fixture
  (Bio-Hackfleisch, 400 Gramm, 4,99 Euro) ergibt sich exakt der AC-1-Wert. Aber: save() ist private,
  kein Test ruft sie auf. Der Test testSavingReceiptStoresPriceAndUnitTogether
  (ReceiptParserPriceTests.swift:392-434) ruft stattdessen einen privaten Helfer learnLikeSave auf
  (Zeile 376-382), der die drei Schreibzeilen aus save() von Hand nachbaut statt sie auszufuehren.
  Eine Regression genau in diesen drei Zeilen von save() selbst wuerde von diesem Test nicht
  erkannt. AC-17 exerziert den echten save()-Pfad end-to-end, prueft aber nur das sichtbare Symptom,
  nicht den literalen Dictionary-Wert aus AC-1.

Vorlaeufige Einschaetzung nach Runde 1: elf der dreizehn ACs direkt und rigoros belegt, AC-1 mit
einer echten Automatisierungsluecke, AC-20 gebrochen. Runde 2 prueft beide Zweifelspunkte gezielt.

### Runde 2 - Adversarial Probing der zwei benannten Zweifelspunkte

Probe 1 - Ist test-green-final.txt, die bisher einzige als gruen behauptete AC-20-Evidenz,
tatsaechlich vollstaendig? Ein Vergleich der Suite-fuer-Suite Testzahlen zwischen
test-green-final.txt (15:30 Uhr, RestockTests insgesamt 248 Tests) und diagnose-nach-merge.txt
(17:05 Uhr, RestockTests insgesamt 256 Tests) zeigt: alle Suiten sind identisch bis auf
ReplenishmentPackageCTests, dort 17 gegen 25 Tests. Die aktuelle Datei
RestockTests/ReplenishmentPackageCTests.swift enthaelt tatsaechlich 25 Testmethoden, unveraendert
seit einem Commit lange vor Ticket 10. Damit steht fest: test-green-final.txt lief gegen ein
unvollstaendiges oder veraltetes Test-Binary, das acht von 256 Testmethoden nie ausfuehrte, aber
trotzdem null Fehler und TEST SUCCEEDED meldete. Diese Evidenz ist als AC-20-Nachweis ungueltig,
unabhaengig vom danach diskutierten MenuPlan-Fehlschlag.

Probe 2 - Mein eigener, frischer Nachbau (adversary-run-1.txt) liefert korrekt 256 von 256
RestockTests, deckt sich also mit diagnose-nach-merge.txt und loest den Verdacht aus Probe 1 fuer
meinen eigenen Testlauf auf. Im UI-Teil traten aber zwei Fehlschlaege auf, nicht nur der bekannte.
Erstens RestockUITests.testAddingMenuPlanRecipeDoesNotCrash, mit identischem Fehler wie zuvor in
diagnose-nach-merge.txt und wie in einem Lauf auf reinem Ausgangsstand ohne jede Ticket-10-Zeile.
Ein Vergleich zeigt, dass die betroffene Datei MenuPlanView.swift durch Ticket 10 nicht veraendert
wurde. Damit ist dreifach unabhaengig bestaetigt: ein Ticket-10-fremder, schon vorher bestehender
Fehlschlag. Zweitens ReceiptReviewUITests.testChangeEditorWorksInDarkMode, neu, in keinem
vorherigen Artefakt als Fehlschlag dokumentiert. Ein Vergleich zeigt, dass an dieser Testdatei
durch Ticket 10 nur eine neue Testmethode ergaenzt wurde, der Dunkelmodus-Test selbst ist
unveraendert. Zwei isolierte Nachlaeufe nur dieses einen Tests zeigten unterschiedliche
Fehlerorte, ein dritter Nachlauf bestand nach siebzehn Sekunden. Die Systemlast zum Zeitpunkt war
erhoeht. Das stuetzt die Deutung als lastbedingte Flakigkeit einer unveraenderten Testdatei, nicht
als funktionale Regression durch Ticket 10.

Probe 3 - Ist der AC-1-Mirror-Test wenigstens nicht tautologisch? Ja: learnLikeSave ruft die
echten Methoden learningQuantity und learningUnit auf der echten Instanz auf, das ist keine Kopie
der Formel. Der Mirror-Anteil betrifft nur die drei Schreibzeilen danach, die in save() Zeile fuer
Zeile identisch dupliziert sind. Ein Regressionsrisiko besteht spezifisch an diesen drei Zeilen:
wuerde save() dort etwas aendern, wuerde kein automatisierter Test das auffangen, weil AC-17 nur
das sichtbare Symptom prueft. Code-Lektuere bestaetigt: die drei Zeilen sind aktuell korrekt.
AC-1 ist heute durch Code-Lektuere plus AC-9 plus AC-17 ausreichend gestuetzt, aber nicht durch
einen direkten automatisierten Test der Schreibzeilen selbst gegen kuenftige Regression
abgesichert. Das ist eine reale Testluecke, keine aktuelle Funktionsluecke.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: RestockTests/ReceiptParserPriceTests.swift:376-434
  Description: AC-1 verlangt eine Zusicherung nach ReceiptScannerView.save(). save() ist eine
  private Methode einer SwiftUI-View und wird von keinem Unit-Test aufgerufen. Der Test ruft
  stattdessen den privaten Helfer learnLikeSave auf, der die drei Schreibzeilen aus save()
  von Hand dupliziert statt sie auszufuehren.
  Spec requirement: AC-1, Rate und Bezugsgroesse muessen nach save() unter demselben Key stehen.
  Conflict: Eine kuenftige Regression an genau diesen drei Zeilen in save() selbst wuerde von
  keinem automatisierten Test erkannt, der Mirror-Test bliebe gruen, weil er die unveraenderte
  Kopie prueft, nicht das Original. AC-17 kompensiert dies nur teilweise, es prueft das sichtbare
  Symptom, nicht den literalen Store-Dictionary-Wert.
  Remediation: Die drei Schreibzeilen aus save() in eine eigene, testbare Funktion ziehen, nach
  demselben Muster wie learningQuantity und learningUnit bereits als Methoden statt Inline-Code
  existieren, oder zumindest einen Kommentar an learnLikeSave, der auf dieses Regressionsrisiko
  verweist.

Finding:
  ID: F002
  Severity: HIGH
  Category: regression
  Code reference: RestockUITests/RestockUITests.swift:238
  Description: testAddingMenuPlanRecipeDoesNotCrash schlaegt im gemeinsamen Lauf zuverlaessig fehl,
  der Knopf zum Hinzufuegen eines Tages im Menueplan wird nicht gefunden. In eigenen unabhaengigen
  Nachlaeufen zweimal reproduziert, sowie in einem dokumentierten Lauf auf reinem Ausgangsstand
  ohne jede Ticket-10-Zeile. Die betroffene Datei MenuPlanView.swift ist durch Ticket 10
  unveraendert.
  Spec requirement: AC-20, die gesamte Bestandssuite ist im gemeinsamen Lauf gruen.
  Conflict: Kein gemeinsamer Lauf der Bestandssuite ist je gruen gewesen, weder in den zuvor
  vorgelegten Laeufen noch in meinem eigenen unabhaengigen Lauf. Die einzige zuvor als gruen
  gemeldete Evidenz ist zusaetzlich ungueltig, weil sie gegen ein unvollstaendiges Test-Binary lief.
  Remediation: Der Fehler ist nicht durch Ticket 10 verursacht und nicht in dessen Dateien
  behebbar. Entweder den Menueplan-Fehler separat vorher beheben, mit einer dokumentierten
  Ausnahme fuer AC-20, oder den betroffenen Test befristet aussetzen mit Verweis auf das
  fremde Issue.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: RestockUITests/ReceiptReviewUITests.swift:750-768
  Description: Im selben gemeinsamen Lauf, der F002 zeigt, schlug zusaetzlich ein zweiter,
  durch Ticket 10 unveraenderter Test fehl, das Preisfeld im Dunkelmodus erschien nicht
  rechtzeitig. Isolierte Nachlaeufe zeigten unterschiedliche Fehlerorte, ein dritter Nachlauf
  bestand. Die Systemlast war zum Zeitpunkt erhoeht.
  Spec requirement: AC-20, gemeinsamer gruener Lauf.
  Conflict: Trotz wahrscheinlicher Lastbedingtheit ist dies eine zweite, bisher undokumentierte
  Fehlschlagsquelle im gemeinsamen Lauf.
  Remediation: Keine Codeaenderung durch Ticket 10 notwendig. Bei wiederholtem Auftreten den
  Testlauf auf einer weniger ausgelasteten Maschine wiederholen, bevor ein AC-20-Nachweis final
  abgenommen wird.

## Confirmations

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Models/ShoppingItem.swift:127-146
  Evidence: testLearnedGramPriceIsNotAppliedToItemWithoutQuantity, gruen in adversary-run-1.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/ShoppingItem.swift:157-160
  Evidence: testLearnedGramPriceAppliesToItemWithGramQuantity, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Models/ShoppingItem.swift:161-165
  Evidence: testLearnedPieceRateIsRejectedForWeightItem, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Models/ShoppingItem.swift:159
  Evidence: testMigrationRepairsCorruptedStoreLearnedPrice, zweiter Teil, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Models/ShoppingItem.swift:261-264
  Evidence: testLearnedGramRateWithoutEvidenceIsKeptAsRate, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Models/ShoppingItem.swift:161-165
  Evidence: testLearnedGramRateIsRejectedForKilogramItem, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/ShoppingItem.swift:167-176
  Evidence: testUnitBucketMapsSynonymsAndUnknownUnits, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:66-93
  Evidence: testLearningUnitMatchesLearningQuantityBranchForEveryCase, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Services/ReceiptParserService.swift:924-932
  Evidence: testPackageSizeFromNameReturnsLitreAsMillilitre und
  testPackageSizeFromNameAgreesWithWeightBasisFromName, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: SmartCart/Views/Prices/ReceiptScannerView.swift:700-714
  Evidence: testSavedReceiptDoesNotProduceOneCentItemPrice, in meinem eigenen Lauf PASSED nach
  18.778 Sekunden, siehe adversary-run-1.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: RestockUITests/ReceiptReviewUITests.swift:667-685
  Evidence: testSavingStillWritesLearnedPriceToMatchedItem, in meinem eigenen Lauf PASSED nach
  15.905 Sekunden, siehe adversary-run-1.txt.
  Status: CONFIRMED

## Testzusammenfassung

Eigener Lauf, adversary-run-1.txt: RestockTests 256 von 256 gruen. RestockUITests 22 Tests, eins
uebersprungen wie erwartet, zwei Fehlschlaege wie oben beschrieben, neunzehn bestanden. Ergebnis
TEST FAILED. Alle dreizehn fuer Ticket 10 relevanten Acceptance Criteria liefen dabei gruen, die
beiden Fehlschlaege betreffen keinen der dreizehn ACs und keine von Ticket 10 geaenderte Datei.
Zwei zusaetzliche isolierte Nachlaeufe des Dunkelmodus-Tests stuetzen die Einordnung als
Lastflakigkeit. Die zuvor als gemeinsamer gruener Lauf gemeldete Evidenz ist ungueltig, weil sie
gegen ein unvollstaendiges Test-Binary lief.

## Verdict: BROKEN

Grund: AC-20 ist nicht erfuellt und war es in keinem der bisher vorgelegten oder von mir selbst
durchgefuehrten Laeufe. Die Regel, niemals VERIFIED zu vergeben wenn ein Test fehlschlaegt, auch
wenn der Fehlschlag unabhaengig erscheint, gilt hier ausdruecklich. Gleichzeitig gilt, ohne etwas
zu beschoenigen: der Menueplan-Fehlschlag ist dreifach unabhaengig als Ticket-10-fremd belegt,
kein Diff zur betroffenen Datei, identischer Fehler auf reinem Ausgangsstand, identischer Fehler
in zwei getrennten frischen Laeufen. Der Dunkelmodus-Fehlschlag ist als lastbedingte Flakigkeit
einer unveraenderten Testdatei einzuordnen. Die dreizehn fuer Ticket 10 relevanten Acceptance
Criteria selbst sind zu zwoelf von dreizehn direkt und rigoros bewiesen. AC-1 ist funktional durch
Code-Lektuere, AC-9 und AC-17 gestuetzt, hat aber eine echte Automatisierungsluecke, siehe F001,
Schweregrad MEDIUM, nicht blockierend fuer die Korrektheit des jetzigen Codes. Der Code selbst, den
Ticket 10 aendert, ist nach Code-Lektuere und Testlauf ohne Befund. Der Blocker ist der woertliche
Anspruch von AC-20 auf einen gemeinsamen gruenen Lauf, der aus Gruenden ausserhalb von Ticket 10
nicht herstellbar war. Das ist eine Tatsache, keine Interpretation, und rechtfertigt keine
VERIFIED-Einstufung nach den Vorgaben dieser Pruefung.

## Geprüfte Dateien

- sha256:a69b911e21d57a6e25be498678bc8e166b335f8df7839fb4182ec92bc2afcd07  RestockTests/ReceiptParserPriceTests.swift
- sha256:7ba458446e568ee9f91dd0ab7c8c9481f2becb25b1346feded45b988482ceb31  RestockUITests/ReceiptReviewUITests.swift
- sha256:5b8d2408c65717596c198b95dc9107984e3c86c534170052bfd3cec72597038a  RestockUITests/RestockUITests.swift
- sha256:4d02f735476731049369b3b116722bb6fc8a0278e14398f0f6c8ac7af123f06d  SmartCart/Models/ShoppingItem.swift
- sha256:b709d56b302b570736637c3f46ce705b7be02483caa5d5aae6094ee8da10a796  SmartCart/Services/ReceiptParserService.swift
- sha256:73dee034586fb231da514c0789e3b2f563f8f42a85e01666a6606729a0318a31  SmartCart/Views/Prices/ReceiptScannerView.swift
