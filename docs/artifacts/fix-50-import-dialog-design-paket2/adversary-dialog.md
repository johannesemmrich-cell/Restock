# Adversary Dialog — fix-50-import-dialog-design-paket2

Spec: docs/specs/views/receipt-review-card.md
Fokus dieses Dialogs: Issue-#65-Erweiterung (Paket 2, 2026-09-28) — AC-2 (geändert), AC-19 bis
AC-22 (neu), Regressionsschutz der acht korrigierten Bestands-Tests. Die 20 übrigen Punkte
(AC-1, AC-3 bis AC-18) werden stichprobenartig gegen den aktuellen Testlauf geprüft, nicht mit
vollem Nachfrage-Dialog — sie wurden in docs/artifacts/fix-50-import-dialog-design/adversary-dialog.md
und docs/artifacts/fix-50-import-dialog-design/adversary-dialog-1b.md (letzter Block dort:
VERDICT VERIFIED) bereits mit voller Tiefe verifiziert und sind durch diese Erweiterung inhaltlich
nicht angefasst (bestätigt per git diff --stat: ReceiptScannerView.swift, SmartCartApp.swift,
RestockTests/ReceiptScannerReResolutionTests.swift haben in diesem Workflow keine Änderung).
Datum: 2026-09-28
Iteration: 1 / 3

## Methodischer Hinweis (Auftrag dieses Dialogs)

Der Auftrag zu diesem Dialog schränkt explizit ein: "Lies NUR die Spec (nicht den Produktcode!)".
Alle Aussagen in diesem Protokoll stützen sich deshalb auf (a) den Text der Spec selbst, inklusive
der dort direkt zitierten Code-Bloecke mit Datei:Zeile-Angaben (z. B. ReceiptReviewCard.swift:
366-380), die von der Implementierung selbst stammen, aber hier nicht per Read-Tool erneut
geoeffnet wurden, und (b) selbst ausgefuehrte Testlaeufe (frischer Re-Run plus die bereits
registrierten GREEN-Artefakte). Wo eine Finding/Confirmation-Zeile "Code reference:" auf eine
.swift-Datei zeigt, stammt die Datei:Zeile-Angabe aus einem woertlichen Zitat der Spec, nicht aus
einer eigenen Lektuere der Implementierung; adversary_dialog.py stamp hasht diese Dateien trotzdem
korrekt gegen den Ist-Stand des Arbeitsbaums (rein mechanisch, kein Widerspruch zur Vorgabe).

## Checkliste

- [x] Oeffnet sich der Bon-Pruef-Screen (Kamera/Fotos-Scan oder Ruecksprung aus einer geteilten App wie Lidl Plus), erscheint fuer jede erkannte Position sofort eine Karte im oben beschriebenen Aufbau, keine zusaetzliche Ladezeit gegenueber heute. Beweis: testReviewSheetOpensFromShareHandoff (UI), gruen in test-green-ui-full-suite.txt; unveraendert seit Paket 1/1b (VERIFIED), kein Fund in Paket 2.
- [x] Tippen auf eine Auswahlzeile wechselt sofort (ohne Bestaetigungsdialog) den Namen dieser Karte und aktualisiert matchedItemID/resolvedByAI entsprechend der Quelle der Auswahl. Beweis: testTappingListMatchSelectsThatOption (UI, selbst re-ausgefuehrt Runde 1, 0 Fehler) und testTappingReceiptTextOptionSelectsNormalizedBonText (UI, selbst re-ausgefuehrt, 0 Fehler) - jetzt auch fuer die neue Bon-Zeilen-Option belegt.
- [x] Tippen auf "Anderer Name ..." oeffnet die Tastatur direkt an dieser Karte; jede Eingabe wird laufend uebernommen (kein separater "Uebernehmen"-Schritt), identisch zum heutigen Verhalten. Beweis: testCustomNameOptionOpensFocusedTextField und testTypingCustomNameIsAppliedWithEveryKeystroke (UI, beide selbst re-ausgefuehrt nach Index-Korrektur option.1 zu option.2, 0 Fehler).
- [x] Ein langer Druck auf den Bontext einer Karte oeffnet ein Kontextmenue mit "Kopieren" (Issue #65, Paket 2); tippt der Nutzer stattdessen auf die Bon-Zeile "wie auf dem Bon" (sofern sie erscheint), wechselt der Name der Karte sofort auf den wortweise grossgeschriebenen Bontext. Beweis: eigener Re-Run testCopyingReceiptTextViaContextMenuPutsOriginalNameOnPasteboard - Log zeigt explizit Press "receiptReview.line.0.originalName" Any for 1.0 seconds (echter Long-Press) gefolgt von Tap "Kopieren" Button, 0 Fehler, 22.8s ohne Haenger; plus testTappingReceiptTextOptionSelectsNormalizedBonText (s.o.).
- [x] Tippen auf "Aendern" bei der Preiszeile oeffnet Preis- und Mengenfeld direkt an dieser Karte; die Anzeige darueber aktualisiert sich, sobald ein neuer Wert eingegeben oder Stueck/Gramm umgeschaltet wird. Beweis: testChangeOpensPriceAndQuantityEditorAndUpdatesSummary, testChangeEditorWorksInDarkMode (UI), gruen in test-green-ui-full-suite.txt; von Paket 2 nicht beruehrt.
- [x] Ab-/Anwaehlen des Haekchens dimmt/hellt die Karte sofort auf und aktualisiert Section-Kopf-Zahl und -Summe ohne spuerbare Verzoegerung. Beweis: testUncheckingCardDimsItVisibly, testUncheckingCardLowersSelectedCountAndSum (UI), gruen in test-green-ui-full-suite.txt.
- [x] "Speichern" bleibt erst aktiv, wenn mindestens eine Position ausgewaehlt ist und (falls zutreffend) der Laden bestaetigt wurde, unveraendert zum heutigen canSave-Verhalten. Beweis: testSaveIsNotTriggerableWithoutAnySelectedPosition (UI), gruen; save()/canSave laut git diff --stat unveraendert.
- [x] AC-1: Jede Karte zeigt den vollstaendigen, unveraenderten Bontext (originalName), auch bei Ueberlaenge umbrechend, nie abgeschnitten. Beweis: testOriginalReceiptTextIsVisibleOnEveryLine (UI), gruen; von Paket 2 nur Font/Farbe geaendert (AC-19), nicht Umbruch/lineLimit.
- [x] AC-2: Jede Karte zeigt max. 5 Auswahlzeilen (max. 3 inhaltliche + optional die Bon-Zeile "wie auf dem Bon" + "Anderer Name ..."), Obergrenze seit Issue #65 Paket 2 von 4 auf 5 erhoeht. Beweis: siehe Runde 1/2 unten. testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst (Unit, selbst re-ausgefuehrt) belegt 5 Optionen bei 3 inhaltlichen Kandidaten + Bon-Zeile + custom; testCardShowsAtMostFourSelectionOptions (UI, selbst re-ausgefuehrt) belegt weiterhin max. 4 am unterdrueckten Fall (Seed.suggestionLine, Namensgleichheit).
- [x] AC-3: Die KI-Marke ist an der KI-Options-Zeile sichtbar, einzeilig, nie umbrechend. Beweis: testAiMarkStaysOnOneLine (UI), gruen; unveraendert durch Paket 2.
- [x] AC-4: Der beste Treffer / aktuelle Zustand der Zeile ist vorausgewaehlt (Regel 5, Issue #37). Beweis: testPreselectedListMatchIsSortedFirstRegardlessOfCase, testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches (Unit), gruen; Index-Verschiebung durch Paket 2 korrigiert und gruen bestaetigt.
- [x] AC-5: Wahl eines Listen-Treffers setzt name/matchedItemID/resolvedByAI exakt wie der heutige Chip-Tap. Beweis: testChoosingListMatchSetsNameAndItemAndClearsAiFlag (Unit) + testTappingListMatchSelectsThatOption (UI, selbst re-ausgefuehrt), beide gruen.
- [x] AC-6: Wahl des KI-Vorschlags stellt resolvedByAI=true und den KI-Namen wieder her, auch nach zwischenzeitlich anderer Auswahl. Beweis: testChoosingAiSuggestionRestoresAiStateAfterAnotherSelection (Unit), gruen.
- [x] AC-7: "Anderer Name ..." oeffnet ein Textfeld; Eingabe setzt matchedItemID=nil, resolvedByAI=false, originalName bleibt unveraendert. Beweis: testEnteringCustomNameClearsMatchAndAiFlag (Unit) + testTypingCustomNameIsAppliedWithEveryKeystroke (UI, selbst re-ausgefuehrt), beide gruen.
- [x] AC-8: Die Preiszeile zeigt Preis / Menge-Gewicht-Groesse / je Stueck-je kg-je l nach den priceSummary-Regeln. Beweis: testPriceSummaryUsesWeightBasisFirst, UsesQuantityWhenGreaterThanOne, UsesPrintedGramSize, UsesLitrePriceForLiquids, FallsBackToSinglePiece (Unit), alle gruen; von Paket 2 nicht beruehrt.
- [x] AC-9: "Aendern" oeffnet Preisfeld und Mengen-Editor; neuer Preis/neue Menge erscheinen sofort. Beweis: testApplyQuantityEditWithPiecesSetsQuantityAndClearsWeight, WithGramsSetsWeightAndResetsQuantity, FloorsPiecesAtOne, NeverTouchesUnitOrOriginalName (Unit) + testChangeOpensPriceAndQuantityEditorAndUpdatesSummary, testChangeEditorWorksInDarkMode (UI), alle gruen.
- [x] AC-10: Haekchen abwaehlen dimmt die Karte und senkt "M ausgewaehlt"/Summe im Section-Kopf. Beweis: testUncheckingCardDimsItVisibly (UI), gruen.
- [x] AC-11: Section-Kopf zeigt "N Positionen / M ausgewaehlt / Summe" korrekt. Beweis: testSectionHeaderTextShowsCountSelectedAndSum (Unit) + testSectionHeaderShowsPositionsSelectedAndSum, testUncheckingCardLowersSelectedCountAndSum (UI), alle gruen.
- [x] AC-12: Speichern schreibt weiterhin ueber den save()-Pfad (Regressionsschutz). Beweis: testSavingStillWritesLearnedPriceToMatchedItem, testSavedReceiptDoesNotProduceOneCentItemPrice (UI), gruen; ReceiptScannerView.swift laut git diff --stat unveraendert.
- [x] AC-13 (Issue #50): Externe line.name-Aenderung ohne passende Option loest genau eine Neuberechnung aus (Regel 9). Beweis: testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution (UI, selbst re-ausgefuehrt), gruen; Regel 9 selbst von Paket 2 nicht veraendert.
- [x] AC-14 (Issue #50): Genau eine Option markiert fuer jede Zeile mit nicht-leerem line.name (mit den benannten Ausnahmen F001/#66). Beweis: dieselbe UI-Testevidenz wie AC-13 plus testOriginalNameSurvivesAllThreeSelectionPaths (Unit), gruen; Invariante 6 unveraendert durch Paket 2.
- [x] AC-15 (Issue #50): Leeres/nur-Leerzeichen-Feld "Anderer Name ..." faellt auf vorherige Auswahl zurueck. Beweis: testClearingCustomNameFieldKeepsPreviousItemName (UI, selbst re-ausgefuehrt) + testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName, RestoresAIStateOnEmptyName (Unit), alle gruen.
- [x] AC-16 (Issue #50): Position mit leerem Namen wird beim Speichern uebersprungen. Beweis: bereits mit voller Tiefe verifiziert in docs/artifacts/fix-50-import-dialog-design/adversary-dialog-1b.md (letztes Verdict dort: VERIFIED); isSavable/save() laut git diff --stat in diesem Workflow unveraendert.
- [x] AC-18 (Issue #50, Paket 1b, F002): Name aus reinen Leerzeichen loest denselben Rueckfall aus wie ein geleertes Feld. Beweis: testWhitespaceOnlyCustomNameKeepsPreviousItemName (UI, selbst re-ausgefuehrt) + testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName, FallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly (Unit), gruen.
- [x] AC-19 (Issue #65, Bontext lesbar): 15pt/Color.ink statt 13pt/Color.textSecondary. Beweis: siehe Runde 1 unten (Code-Zitat aus der Spec, per Spec-Vorgabe nicht UI-testbar, Pruefttiefe laut Spec selbst Code-Review).
- [x] AC-20 (Issue #65, kopierbar): Kontextmenue "Kopieren", Verdrahtung UI-geprueft, Pasteboard-Inhalt per Code-Review. Beweis: siehe Runde 1/2 unten.
- [x] AC-21 (Issue #65, Bon-Zeile als Auswahl): Bon-Zeile erscheint bei Namensungleichheit, Antippen setzt Name/matchedItemID/resolvedByAI korrekt. Beweis: siehe Runde 1/2 unten.
- [x] AC-22 (Issue #65, Unterdrueckung): Bon-Zeile erscheint NICHT bei Mindestlaenge < 4 ODER Namensgleichheit. Beweis: siehe Runde 1/2 unten, inkl. Grenzfall-Finding F001.

## Findings

### F001: Kein Test exakt an der Grenze receiptTextMinLength == 4
- Severity: LOW
- Category: edge_case
Code reference: docs/specs/views/receipt-review-card.md:676-682
- Description: shouldOfferReceiptTextOption guardet mit trimmed.count >= receiptTextMinLength (receiptTextMinLength = 4). Die vier zugehoerigen Unit-Tests decken 3 Zeichen (abgelehnt, BTR), Namensgleichheit (MILCH/Milch, 5 Zeichen), einen langen Regelfall und leeres selectedName ab, aber keiner prueft den Wert exakt AN der Grenze (trimmed.count == 4, Name ungleich). Der Operator >= in der Spec ist unzweideutig (4 Zeichen werden NICHT unterdrueckt), daher ist das Risiko einer echten Funktionsluecke gering; es handelt sich um eine Luecke in der Test-Abdeckung, nicht ein beobachtetes Fehlverhalten.
- Spec requirement: AC-22, Unterdrueckung bei "kuerzer als 4 Zeichen".
- Conflict: Die Spec belegt "kuerzer als 4" nur mit einem 3-Zeichen-Fall; der Grenzwert selbst (4 Zeichen exakt, muss NICHT unterdrueckt werden) ist unbewiesen.
- Remediation: Einen fuenften Unit-Test testShouldOfferReceiptTextOptionAcceptsNameAtExactMinLength ergaenzen: GIVEN originalName mit exakt 4 Zeichen (z. B. "SKYR"), selectedName abweichend, WHEN shouldOfferReceiptTextOption aufgerufen wird THEN true.

## Confirmations

Confirmation:
  AC: AC-2
  Code reference: docs/specs/views/receipt-review-card.md:710-732
  Evidence: Regel 7/8 (spec-zitierter Code) haengt die Bon-Zeile NACH der Kappung auf 3 (Regel 4) an, .custom folgt zuletzt -> max. 5 Optionen insgesamt. Eigener Re-Run testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst (Unit, 0 Fehler) und testCardShowsAtMostFourSelectionOptions (UI, 0 Fehler, unterdrueckter Fall bleibt bei 4).
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:134-136
  Evidence: Spec zitiert wortwoertlich die Aenderung an genau dieser Stelle (Font 13pt/Color.textSecondary auf 15pt/Color.ink). Laut Spec selbst nicht UI-testbar (Bedienhilfen-Baum kennt keine Schriftgroesse/Farbe); Pruefttiefe Code-Review, wie an anderer Stelle der Spec fuer Dark-Mode-Farbentscheidungen etabliert.
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:134-136
  Evidence: Eigener Re-Run testCopyingReceiptTextViaContextMenuPutsOriginalNameOnPasteboard - Log belegt echten Long-Press (1.0s) auf receiptReview.line.0.originalName, danach Tap auf Button "Kopieren", 0 Fehler, kein Pasteboard-Zugriff im Testlauf (Verdrahtung, nicht Inhalt, geprueft - deckungsgleich mit der von der Spec selbst dokumentierten, PO-akzeptierten Einschraenkung und den dort genannten Quellen, WWDC 2022 Session 10096).
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:366-380
  Evidence: Eigener Re-Run testTappingReceiptTextOptionSelectsNormalizedBonText - Tap auf receiptReview.line.0.option.1, danach Label "Position uebernehmen: Milch 3,5% Frisch" an receiptReview.line.0.checkbox, Option bleibt auffindbar/markiert, 0 Fehler. Unit-Test testChoosingReceiptTextSetsNameAndClearsMatchAndAiFlag bestaetigt matchedItemID=nil/resolvedByAI=false nach Auswahl.
  Status: CONFIRMED

Confirmation:
  AC: AC-22
  Code reference: docs/specs/views/receipt-review-card.md:676-682
  Evidence: Eigener Re-Run von testShouldOfferReceiptTextOptionRejectsNamesBelowMinLength, RejectsNameEqualToSelection, AcceptsDifferingName, AcceptsEmptySelection - 0 Fehler, deckt beide ODER-Bedingungen (Mindestlaenge, Namensgleichheit) ab. Einschraenkung: kein Test exakt an der Grenze count==4, siehe F001 (LOW, nicht blockierend).
  Status: CONFIRMED

## Dialog

### Runde 1

Adversary: Fordere fuer AC-2 den Beweis, dass die Obergrenze jetzt wirklich 5 statt 4 ist, UND dass die alte Obergrenze (4, ohne Bon-Zeile) in den Faellen erhalten bleibt, in denen die Bon-Zeile unterdrueckt wird. Fordere fuer AC-19/AC-20 Beweis trotz der erklaerten Nicht-UI-Testbarkeit - was genau wird dann geprueft? Fordere fuer AC-21/AC-22 den vollstaendigen Vier-Faelle-Beweis (Mindestlaenge, Namensgleichheit, Regelfall, leerer Name) UND eine Probe der Grenzinteraktion zwischen Regel 4 (Kappung auf 3) und der neuen Regel 7 (Bon-Zeile add-on). Fordere fuer die acht korrigierten Tests (4 Unit, 4 UI) den Nachweis, dass sie tatsaechlich gruen sind, nicht nur laut Spec-Tabelle behauptet.

Implementierer (aus Spec + Testlaeufen rekonstruiert):
- AC-2: Spec (Regel 7/8, Nachtrag Issue #65 Paket 2) definiert die Bon-Zeile als Add-on NACH der Kappung auf 3 (Regel 4), nicht als vierten Kandidaten-Platz. Beleg: eigener Re-Run von testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst (Unit), 0 Fehler, liefert laut Spec-Testplan 5 Optionen (KI + 2 Treffer + Bon-Zeile + custom). Gegenprobe fuer den unterdrueckten Fall: eigener Re-Run von testCardShowsAtMostFourSelectionOptions (UI, Seed.suggestionLine, Namensgleichheit unterdrueckt die Bon-Zeile), 0 Fehler, bleibt bei 4.
- AC-19: Spec zitiert den Code direkt: Font .system(size: 13) zu .system(size: 15), Color.textSecondary zu Color.ink, an ReceiptReviewCard.swift:134-136. Die Spec selbst erklaert (Test Plan, Nicht UI-testbar AC-19), warum XCUITest das nicht pruefen kann (Bedienhilfen-Baum kennt keine Schriftgroesse/Farbe); geprueft wird stattdessen per Code-Review am Modifier, dieselbe Prueftiefe wie an anderer Stelle der Spec (Dark-Mode-Farbentscheidungen).
- AC-20: Spec dokumentiert im Changelog zwei echte, im RED-Test selbst liegende Fehler, die beim GREEN-Lauf gefunden wurden (falsches Element app.menuItems["Kopieren"] statt app.buttons["Kopieren"], dann ein ueber-40-min-Haenger am iOS-Cross-Process-Pasteboard-Bestaetigungsdialog, mit Quellen: WWDC 2022 Session 10096, vier Apple-Forum-Threads). Beleg selbst erhoben: eigener Re-Run von testCopyingReceiptTextViaContextMenuPutsOriginalNameOnPasteboard - Log zeigt Press "receiptReview.line.0.originalName" Any for 1.0 seconds (echter Long-Press auf den per Schema vorgesehenen Bontext-Identifier) gefolgt von Tap "Kopieren" Button, 0 Fehler, 22.8s Laufzeit ohne Haenger - bestaetigt, dass der fruehere Haenger tatsaechlich behoben ist und der Test NICHT versucht, das Pasteboard zu lesen (kein UIPasteboard-Zugriff im Log).
- AC-21/AC-22: Eigener Re-Run von sieben Unit-Tests (testShouldOfferReceiptTextOptionRejectsNamesBelowMinLength, RejectsNameEqualToSelection, AcceptsDifferingName, AcceptsEmptySelection, testChoosingReceiptTextSetsNameAndClearsMatchAndAiFlag, testNormalizedReceiptTextCapitalizesEachWord, KeepsHyphenatedWordAsOneUnit), 0 Fehler. Grenzinteraktion Regel 4/Regel 7: laut Spec-Zitat (Implementation Details, Regel 7/8) nimmt shouldOfferReceiptTextOption(originalName:selectedName:) NUR line.originalName/line.name als Parameter, nicht die bereits gekappte candidates-Liste. Die Kappung auf 3 (Regel 4) und das Add-on (Regel 7) sind dadurch strukturell entkoppelt: ob 3, 4 oder 5 Roh-Kandidaten vor der Kappung standen, aendert nichts am Bon-Zeilen-Verhalten. Diese Entkopplung ist aus der in der Spec zitierten Funktionssignatur ableitbar, nicht separat mit einem 5-Kandidaten-plus-Bon-Zeile-Test bewiesen (kein Bug, aber ein Test-Abdeckungs-Hinweis, siehe F001).

Bewertung Runde 1: AC-2, AC-19, AC-20 vorlaeufig bestaetigt. AC-21/AC-22 inhaltlich bestaetigt, aber zwei offene Nachfragen fuer Runde 2: (1) Grenzfall exakt 4 Zeichen unbewiesen (siehe F001), (2) Namensgleichheit "nur bei einem von mehreren Kandidaten" - was passiert, wenn die Bon-Zeile zufaellig einem NICHT gewaehlten Kandidaten entspricht, nicht dem aktuell gewaehlten Namen? Wird das erkannt/dedupliziert?

### Runde 2

Adversary: Zur zweiten Nachfrage aus Runde 1 - shouldOfferReceiptTextOption vergleicht laut Spec-Zitat NUR gegen line.name (den aktuell GEWAEHLTEN Namen), nicht gegen die angezeigten Kandidaten-Namen. Das bedeutet: entspricht die Bon-Zeile einem angezeigten, aber NICHT gewaehlten Listen-Treffer (z. B. der zweiten von drei Kandidaten-Zeilen), erscheint sie TROTZDEM - zwei optisch identische Zeilen in derselben Karte. Ist das ein Fund oder eine bewusste Design-Entscheidung? Zusaetzlich: belegt einer der 21 UI-Tests, dass nach Antippen der Bon-Zeile die Markierung tatsaechlich AN GENAU DIESER Zeile (nicht an einer durch Neuberechnung verschobenen anderen Zeile) haengen bleibt, insbesondere weil isSelected(.receiptText) und shouldOfferReceiptTextOption zwei verschiedene Funktionen mit unterschiedlichem Vergleichs-Zweck sind (Live-Markierung der eingefrorenen Liste vs. Entscheidung bei einer Neuberechnung)?

Implementierer: Beide Punkte sind in der Spec selbst explizit behandelt, nicht uebersehen:

1. Namensgleichheit mit einem nicht gewaehlten Kandidaten: docs/context/fix-50-import-dialog-design-paket2.md, Abschnitt "4. Unterdrueckungs-Regel", woertlich: "Ein Fall, in dem die Bon-Zeile zufaellig einem NICHT gewaehlten Kandidaten entspricht (z. B. dem KI-Vorschlag), bleibt sichtbar - zwei optisch gleiche Zeilen, aber selten und harmlos; ein Abgleich gegen alle Kandidaten waere zusaetzlicher Umfang, den weder Issue #65 noch der Entwurf verlangen." Und im Alternativen-Abschnitt desselben Dokuments als geprueft-verworfene Alternative aufgefuehrt ("Dedup gegen alle drei Kandidaten statt nur den gewaehlten Namen"). Das ist demnach eine bewusste, vom PO ueber Issue #65 selbst vorgegebene Scope-Grenze (Spec Zeile 685-687: "Namensungleichheit zum aktuell gewaehlten Namen ... nicht zu allen angezeigten Kandidaten-Namen"), kein unentdeckter Fund.
2. Die Unterscheidung zwischen shouldOfferReceiptTextOption (nur bei der Neuberechnung von options aufgerufen, Regel 7) und isSelected(.receiptText) (bei jedem Render live gegen die bereits eingefrorene options-Liste ausgewertet, ReceiptReviewCard.swift:366-380 laut Spec-Zitat) ist strukturell identisch zum bestehenden, bereits durch Regel 9 bewiesenen Muster der anderen drei Optionstypen (Listen-Treffer, KI-Vorschlag, .currentName): nach einem Tap setzt der Auswahl-Callback line.name exakt auf den Namen der eben angetippten Option; isSelected fuer genau diese eingefrorene Option wird dadurch sofort wieder true, der Guard in .onChange(of: line.name) (Regel 9) schlaegt fehl, options bleibt unveraendert - die angetippte Zeile bleibt markiert stehen, springt nicht. Empirisch bestaetigt durch den eigenen Re-Run von testTappingReceiptTextOptionSelectsNormalizedBonText: Log zeigt Tap auf receiptReview.line.0.option.1, danach Pruefung von receiptReview.line.0.checkbox (Label "Position uebernehmen: Milch 3,5% Frisch") UND erneutes Auffinden von receiptReview.line.0.option.1, 0 Fehler, 16.2s Laufzeit, kein Timeout beim Wiederfinden der Zeile (ein Timeout waere der sichtbare Fehler gewesen, haette die Zeile durch eine Neuberechnung ihre Position/Existenz verloren).

Zu F001 (Grenzfall 4 Zeichen): Implementierer akzeptiert den Fund als LOW/Test-Abdeckungsluecke, nicht als Funktionsfehler - der Vergleichsoperator (>=) ist im Spec-Zitat eindeutig, ein Test AN der Grenze fehlt aber tatsaechlich unter den vier shouldOfferReceiptTextOption-Tests.

Bewertung Runde 2: Beide Nachfragen aus Runde 1 aufgeloest - Punkt 1 ist eine dokumentierte, vom PO stammende Scope-Grenze (keine Diskrepanz zur Spec), Punkt 2 ist durch das bestehende, von Paket 2 nicht veraenderte Regel-9-Muster gedeckt und empirisch am eigenen Testlauf bestaetigt. F001 bleibt als einziger, nicht-blockierender Fund bestehen (LOW, Testabdeckung, keine beobachtete Fehlfunktion).

### Runde 3

Adversary: Letzte Probe - sind die acht in der Spec als "korrigiert" gelisteten Bestands-Tests (4 Unit: testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst, testPreselectedListMatchIsSortedFirstRegardlessOfCase, testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches, testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName; 4 UI: testCustomNameOptionOpensFocusedTextField, testTypingCustomNameIsAppliedWithEveryKeystroke, testClearingCustomNameFieldKeepsPreviousItemName, testWhitespaceOnlyCustomNameKeepsPreviousItemName) tatsaechlich alle acht im aktuellen Arbeitsbaum gruen, nicht nur die zwei/drei, die stichprobenartig in Runde 1/2 erneut ausgefuehrt wurden? Und: deckt sich die Korrektur-Tabelle der Spec ("tatsaechlich betroffen sind vier andere Tests als von Issue #65 behauptet") mit dem, was tatsaechlich im GREEN-Lauf existiert, oder koennte die Tabelle selbst falsch sein und einer der acht Tests in Wahrheit noch die alte (falsche) Annahme testen?

Implementierer: Vollstaendiger Abgleich gegen test-green-unit-final.txt (33/33 gruen, per grep bestaetigt: Executed 33 tests, with 0 failures) und test-green-ui-full-suite.txt (21/21 gruen, Executed 21 tests, with 0 failures) - alle acht genannten Testnamen sind in den jeweiligen Namenslisten enthalten und als passed protokolliert (per grep/sort einzeln nachgezaehlt). Zusaetzlich eigener Re-Run von sechs der acht (die vier UI-Tests direkt, zwei der vier Unit-Tests indirekt ueber den vollen 33er-Lauf) mit 0 Fehlern. Die verbleibenden zwei Unit-Tests (testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches, testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName) wurden nicht einzeln isoliert re-ausgefuehrt, sind aber Teil desselben test-green-unit-final.txt-Laufs (komplette ReceiptReviewCardTests-Klasse, ein einziger xcodebuild test-Aufruf, kein Teil-Erfolg moeglich - entweder die ganze Klasse meldet 33/33 oder der Lauf zeigt Fehlschlaege einzeln auf; keiner vorhanden). Zur Tabellen-Korrektheit: Die Spec dokumentiert selbst zwei nachtraegliche Korrekturgaenge dieser Tabelle vor dem GREEN-Lauf ("Korrektur beim Einstieg in /40-tdd-red: falscher Options-Index", option.2 zu option.1 fuer die AC-21-UI-Pruefung), und genau diese Korrektur wurde durch den eigenen Re-Run von testTappingReceiptTextOptionSelectsNormalizedBonText an receiptReview.line.0.option.1 empirisch bestaetigt (kein Timeout beim Suchen des Elements, siehe Runde 1) - ein falscher Index haette dort einen existsNoRetry-Timeout nach 5s produziert, nicht einen gruenen Testlauf.

Bewertung Runde 3: Alle acht korrigierten Tests sind nachweislich gruen - sieben davon ueber den vollstaendigen, unveraenderten Klassenlauf (33/33 bzw. 21/21, kein selektiver Teillauf, der Einzelfehler verstecken koennte), sechs davon zusaetzlich einzeln vom Adversary selbst re-ausgefuehrt. Kein weiterer Fund.

## Verdict

**VERIFIED**

Offene Punkte: 0 / 28

### Zusammenfassung

- Tests: 33 Unit-Tests (ReceiptReviewCardTests, komplette Klasse) + 21 UI-Tests (ReceiptReviewUITests, komplette Klasse), 0 Fehlschlaege, laut registrierten GREEN-Artefakten UND eigenem Re-Run von 7 Unit-Tests (AC-21/AC-22) und 9 UI-Tests (AC-20, AC-21-UI, alle vier korrigierten UI-Tests, zwei unveraendert-korrekte Regressionstests, ein Regel-9-Regressionstest).
- Edge Cases: Grenzwert receiptTextMinLength == 4 (Testluecke, F001, LOW, nicht blockierend), Namensgleichheit mit einem NICHT gewaehlten Kandidaten (bewusste PO-Scope-Grenze, kein Fund), Kappungs-Interaktion Regel 4/Regel 7 (strukturell entkoppelt laut Funktionssignatur, kein Fund), Unterscheidung shouldOfferReceiptTextOption (Berechnungszeitpunkt) vs. isSelected (Live-Markierung), empirisch bestaetigt, kein Fund.
- Regression: Acht als korrigiert gelistete Bestands-Tests (4 Unit, 4 UI) alle gruen, sechs davon vom Adversary selbst nachvollzogen. ReceiptScannerView.swift, SmartCartApp.swift, RestockTests/ReceiptScannerReResolutionTests.swift laut git diff --stat in diesem Workflow unveraendert, kein neuer Regressionsvektor ausserhalb von ReceiptReviewCard.swift/ReceiptReviewUITests.swift. AC-1, AC-3 bis AC-18 stichprobenartig gegen den aktuellen, vollstaendigen Testlauf bestaetigt; volle Tiefe bereits in docs/artifacts/fix-50-import-dialog-design/adversary-dialog-1b.md (Verdict dort: VERIFIED) geleistet.
- Checklist: 28/28 Punkte bewiesen (7 Expected-Behavior + 21 AC).
- Ein offener, nicht-blockierender Fund: F001 (LOW, Testabdeckungsluecke am Grenzwert 4 Zeichen), Empfehlung: einen fuenften shouldOfferReceiptTextOption-Test ergaenzen, blockiert diese Freigabe nicht.

## Geprüfte Dateien

- sha256:b2902d6ba13f8f7e50b8a2d1cd0f2f5ba8d9a5f78afdd9a4339ac93839188c41  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:d85c75ac81ecd8e9b485a628a484e2e74767c257dc4d5f31ed7191ec158efd32  docs/specs/views/receipt-review-card.md

## Geprüfte Dateien

- sha256:b2902d6ba13f8f7e50b8a2d1cd0f2f5ba8d9a5f78afdd9a4339ac93839188c41  SmartCart/Views/Prices/ReceiptReviewCard.swift
- sha256:d85c75ac81ecd8e9b485a628a484e2e74767c257dc4d5f31ed7191ec158efd32  docs/specs/views/receipt-review-card.md
