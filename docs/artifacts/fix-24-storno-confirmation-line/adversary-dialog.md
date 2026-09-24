# Adversary Dialog: fix-24-storno-confirmation-line

Spec: docs/specs/fast/fix-24-storno-confirmation-line.md
Geaenderte Produktdatei: SmartCart/Services/ReceiptParserService.swift (Guard Zeile 387-394)
Geaenderte Testdatei: RestockTests/ReceiptParserStornoTests.swift (neuer Test testStornoStaysPendingAcrossSkippedConfirmationLine)

## Testlauf (einmalig, vollstaendig)

Kommando:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Restock -project Restock.xcodeproj -destination platform=iOS-Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7 test -only-testing:RestockTests/ReceiptParserStornoTests -only-testing:RestockTests/ReceiptParserPriceTests

Vollstaendiger Output gespeichert unter: docs/artifacts/fix-24-storno-confirmation-line/adversary-full-test-run.txt

Ergebnis:
Executed 19 tests, with 0 failures (0 unexpected) in 0.031 (0.074) seconds -- ReceiptParserPriceTests
Executed 7 tests, with 0 failures (0 unexpected) in 0.017 (0.019) seconds -- ReceiptParserStornoTests
Executed 26 tests, with 0 failures (0 unexpected) in 0.049 (0.094) seconds -- RestockTests.xctest gesamt
TEST SUCCEEDED

Kein "Executed 0 tests", kein Abbruch, kein Retry-Flag im Output (geprueft per grep auf retry/failed/error: -- einzige Treffer sind erwartete CloudKit-Simulator-Warnungen ohne iCloud-Account, unabhaengig vom Fix, siehe SharedModelContainer.swift-Kommentar).

### Runde 1

- [x] AC-1 geprueft: Test testConfirmationLineAfterStornoDoesNotBecomePhantomPosition (RestockTests/ReceiptParserStornoTests.swift:84-92) nutzt exakt die Spec-Zeilenfolge GOUDA JUNG 1,65 B / LAUGENBROETCHEN 1,56 B / STORNO / -4 Stk x 0,39 und prueft result.count == 2 sowie Abwesenheit eines Namens mit "Stk x". Test lief GRUEN im obigen Lauf.
- [x] Code-Pfad fuer AC-1 gelesen: SmartCart/Services/ReceiptParserService.swift:392-394 -- if pendingStornoCancel, isBareQuantityOrWeightConfirmationLine(trimmed) { continue } -- faengt die Zeile ab, BEVOR sie in den " x "-Zweig (Zeile 405) laufen und dort als Phantom-Position mit dem Zeilentext als Name gespeichert werden kann.
- [x] AC-2 geprueft: neuer Test testStornoStaysPendingAcrossSkippedConfirmationLine (RestockTests/ReceiptParserStornoTests.swift:97-104), Eingabe GOUDA JUNG 1,65 B / STORNO / -4 Stk x 0,39 / GOUDA JUNG -1,65 B, erwartet result.isEmpty. Lief GRUEN im obigen Lauf.
- [x] Code-Pfad fuer AC-2 gelesen: der Guard in Zeile 392-394 veraendert pendingStornoCancel NICHT (kein "= false" im Rumpf). Konsumiert wird die Variable ausschliesslich an zwei Stellen weiter unten: Zeile 544-550 (Namens-/Preis-Zeile) und Zeile 565-571 (reine Preiszeile) -- beide liegen NACH dem neuen Guard und werden von der uebersprungenen Bestaetigungszeile nie erreicht.
- [x] AC-3 geprueft: Regressionstests in RestockTests/ReceiptParserPriceTests.swift (Issue #9, Zeile 306-327, insb. testBareConfirmationLineWithFailedSanityCheckIsConsumedNotAttributed und testBareConfirmationLineAsFirstLineDoesNotCrash) sowie alle Gewichts-/Rechenproben-Tests (testWeightBasedGrundpreisLineComputesCorrectTotal, testWeightLineWithSeparateTotalPriceLineIsNotOverridden, testWeightLineWithNoSeparateTotalFallsBackToComputedTotal) -- Datei wurde laut git diff RestockTests/ReceiptParserPriceTests.swift NICHT veraendert, alle Tests liefen GRUEN.
- [x] Code-Pfad fuer AC-3 gelesen: der bestehende Block Zeile 374-385 (Bestaetigungszeile OHNE STORNO, !pendingStornoCancel-Bedingung) ist durch den Diff unveraendert; der neue Guard steht als eigener if-Block DANACH und wird nur bei pendingStornoCancel == true ueberhaupt erreicht.

Erste Einschaetzung: alle drei ACs scheinen durch Code und Tests belegt. Zu frueh, um zu konvergieren -- Runde 2 prueft, ob die Tests wirklich etwas beweisen (nicht tautologisch sind) und ob es Randfaelle gibt, die die Guard-Platzierung uebersieht.

### Runde 2 (Adversarial Probing)

Probe 1 -- Ist der RED-GREEN-Nachweis fuer AC-1 real, nicht nur eine gruen geschriebene Behauptung? Commit 30a3cdc fuegte den AC-1-Test VOR dem Fix hinzu (RED) und hat den Beweis als Artefakt hinterlegt: docs/artifacts/fix-24-storno-confirmation-line/test-red-output.txt, Zeile 951: XCTAssertEqual failed: drei ist nicht gleich zwei - Erkannt: -4 Stk x 0,39=1.56, Gouda jung=1.65, Laugenbroetchen=1.56. Das belegt exakt den im Spec beschriebenen Bug (Phantom-Position mit dem Zeilentext als Name, Preis 1.56 = 4x0.39 aus der Rechenprobe) VOR dem Fix. Der aktuelle GRUENE Lauf zeigt denselben Test jetzt bestehend. Kein Zirkelschluss -- der Fehler wurde tatsaechlich reproduziert und dann behoben.

Probe 2 -- Ist der AC-2-Test tautologisch (wuerde er auch ohne den neuen Guard gruen sein)? Manuell durchgespielt, was OHNE den Guard mit GOUDA JUNG 1,65 B / STORNO / -4 Stk x 0,39 / GOUDA JUNG -1,65 B passieren wuerde: Zeile 3 haette (da pendingStornoCancel==true den Block 374-385 sperrt) den " x "-Zweig (Zeile 405ff.) erreicht und dort -- wie in Probe 1 belegt -- eine Phantom-Position angelegt. pendingStornoCancel bliebe dabei unangetastet (der " x "-Zweig fasst die Variable nirgends an). Zeile 4 wuerde dann pendingStornoCancel verbrauchen und laut removingMostRecentMatch (Zeile 280-289, lastIndex(where:)) NICHT die Phantom-Position, sondern den echten Gouda-Eintrag entfernen (nur dieser enthaelt "gouda jung") -- Endergebnis waere Phantom=1.56, NICHT leer. Der Test wuerde also OHNE den Fix fehlschlagen -- der Test ist nicht tautologisch, sondern beweist echtes Verhalten. Mit dem tatsaechlichen Guard bleibt Zeile 3 folgenlos, pendingStornoCancel bleibt true, und Zeile 4 entfernt korrekt den einzigen echten Gouda-Eintrag, Ergebnis leer. Bestaetigt durch den gruenen Testlauf.

Probe 3 -- Randfall: mehrere Bestaetigungszeilen direkt hintereinander nach STORNO. Nicht durch einen dedizierten Test abgedeckt, aber durch Code-Lesen beweisbar: der Guard (Zeile 392-394) hat keine Zaehlung/Once-Semantik -- jede Zeile, die isBareQuantityOrWeightConfirmationLine erfuellt, wird uebersprungen, solange pendingStornoCancel == true ist. Kein Fehlverhalten ersichtlich, aber ausserhalb der Spec (Formulierung "eine ... Bestaetigungszeile", Singular). Da Code-Verhalten konsistent mit der Absicht ist (Guard verbraucht den Zustand nie) und kein AC dies verlangt oder ausschliesst, wird dies nicht als Finding, sondern als Beobachtung ohne Blockierwirkung gefuehrt.

Probe 4 -- Beeinflusst der Guard Faelle, in denen pendingName/pendingPrice beim Erreichen der Zeile NICHT nil sind? Code-Lesen: lower.contains("storno") (Zeile 348-352) setzt in JEDEM Fall, in dem STORNO erkannt wird, sofort pendingName = nil und pendingPrice = nil in derselben Zeile, in der pendingStornoCancel = true gesetzt wird. Direkt danach sind beide garantiert nil. Der neue Guard hat daher nie mit einem gesetzten pendingName/pendingPrice zu tun, wenn die Bestaetigungszeile UNMITTELBAR auf STORNO folgt (der in AC-1/AC-2 spezifizierte Fall). Kein Widerspruch zur Spec.

Probe 5 -- Regressionsrisiko durch Scope-Check. git diff --stat zeigt nur 3 Dateien, 26 Zeilen (RestockTests/ReceiptParserStornoTests.swift +12, SmartCart/Services/ReceiptParserService.swift +9, docs/specs/fast/fix-24-storno-confirmation-line.md +5) -- innerhalb der Scoping-Grenzen. parseClassic ist private und wird ausschliesslich von parse aufgerufen (SmartCart/Services/ReceiptParserService.swift:189); keine weiteren Aufrufer, die vom neuen Guard betroffen sein koennten.

- [x] AC-1 erneut bestaetigt (RED-GREEN-Nachweis, nicht nur GREEN-Behauptung)
- [x] AC-2 erneut bestaetigt (Test ist nicht tautologisch, manuell durchgespielt)
- [x] AC-3 erneut bestaetigt (Testdatei unveraendert, alle bestehenden Tests gruen, keine Beruehrung des unveraenderten Codeblocks Zeile 374-385 ausser durch den nachgelagerten neuen if-Block)

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/ReceiptParserService.swift:392-394
  Evidence: Guard faengt pendingStornoCancel und isBareQuantityOrWeightConfirmationLine(trimmed) ab und ueberspringt die Zeile per continue, bevor sie den " x "-Zweig (Zeile 405) erreichen kann. RED-Beweis vor dem Fix in test-red-output.txt Zeile 951 (3 statt 2 Positionen, Phantom-Name "-4 Stk x 0,39"). GREEN-Beweis im aktuellen Lauf: Test testConfirmationLineAfterStornoDoesNotBecomePhantomPosition passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Services/ReceiptParserService.swift:392-394,544-550,565-571
  Evidence: Der neue Guard veraendert pendingStornoCancel nicht; die Variable wird erst an den beiden bestehenden Konsumstellen (544-550 fuer Namens-/Preis-Zeilen, 565-571 fuer reine Preiszeilen) auf false gesetzt. Test testStornoStaysPendingAcrossSkippedConfirmationLine (RestockTests/ReceiptParserStornoTests.swift:97-104) belegt dies End-to-End. Manuell nachvollzogen (Probe 2), dass der Test ohne den Guard fehlschlagen wuerde -- kein Tautologie-Risiko.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Services/ReceiptParserService.swift:374-385
  Evidence: Block unveraendert laut git diff (nur Zeilen 387-394 neu eingefuegt). Bestehende Regressionstests in RestockTests/ReceiptParserPriceTests.swift (unveraendert laut git diff) liefen alle gruen, u. a. testWeightBasedGrundpreisLineComputesCorrectTotal, testWeightLineWithSeparateTotalPriceLineIsNotOverridden, testBareConfirmationLineWithFailedSanityCheckIsConsumedNotAttributed, testBareConfirmationLineAsFirstLineDoesNotCrash -- decken die Rechenprobe (Menge mal Rate ungefaehr Zeilenpreis) und die Bestaetigungszeile ohne STORNO ab.
  Status: CONFIRMED

## Testzusammenfassung

- Testlauf: 26 Tests, 0 Fehler, 0 unerwartet, TEST SUCCEEDED
- Kein Nulltest-Lauf (Executed 26 tests, nicht 0), kein Abbruch, kein Retry
- Vollstaendiger Output: docs/artifacts/fix-24-storno-confirmation-line/adversary-full-test-run.txt
- RED-Vorlauf (vor dem Fix, zum Vergleich): docs/artifacts/fix-24-storno-confirmation-line/test-red-output.txt

## Verdict: VERIFIED

Alle drei Acceptance Criteria sind durch Code-Lesen UND durch einen einzigen vollstaendigen, gruenen Testlauf (26/26) belegt. Der AC-1-Bug wurde vor dem Fix real reproduziert (RED-Artefakt), der AC-2-Test wurde manuell als nicht-tautologisch nachgewiesen, AC-3 bleibt durch unveraenderte Regressionstests abgedeckt. Keine Findings, keine offenen Fragen, die eine BROKEN- oder AMBIGUOUS-Einstufung rechtfertigen. Der einzige entdeckte Randfall (Probe 3, mehrere Bestaetigungszeilen hintereinander) ist von der Spec nicht gefordert und verhaelt sich konsistent mit der Fix-Absicht -- kein Finding.

## Geprüfte Dateien

- sha256:e4b8ed6735dc014c74cdc9825b48dd2838763fcc49a68c5be50ac6176c5dc6d1  SmartCart/Services/ReceiptParserService.swift
