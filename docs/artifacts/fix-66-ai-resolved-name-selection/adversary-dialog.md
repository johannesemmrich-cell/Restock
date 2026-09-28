# Adversary Dialog - fix-66-ai-resolved-name-selection

Spec: docs/specs/views/receipt-review-card.md (Abschnitt "Nachtrag Issue #66", AC-23/24/25)
Geaenderte Datei: SmartCart/Views/Prices/ReceiptReviewCard.swift
Neue Tests: RestockTests/ReceiptReviewCardTests.swift (MARK "Issue #66")

### Runde 1

#### Anspruch verstehen, Diff gegen Spec pruefen

Frage: Entspricht der tatsaechliche Diff wortgleich dem, was die Spec unter "Nachtrag Issue #66"
Abschnitt a/b/c beschreibt?

Antwort/Beleg: Vergleich des Arbeitsbaum-Diffs gegen den Vorgaenger-Commit fuer
SmartCart/Views/Prices/ReceiptReviewCard.swift zeigt genau drei Aenderungen:
1. isSelected(_:) als private func -> extrahiert zu static func isSelected(_ option:
   ReceiptNameOption, for line: EditableReceiptLine, customActive: Bool) -> Bool.
   .listMatch-Zweig gelockert von "!line.resolvedByAI && line.matchedItemID == suggestion.itemID"
   auf "(line.matchedItemID == suggestion.itemID || line.matchedItemID == nil)" - Wortlaut
   identisch mit Spec Zeilen 886-908.
2. applyCustomName verknuepft matchedItemID ueber
   "line.suggestions.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.itemID"
   statt ausnahmslos nil - identisch mit Spec Zeilen 942-951.
3. Regel 9 (onChange) bekommt zwei zusaetzliche Hooks auf line.matchedItemID/line.resolvedByAI,
   beide rufen dieselbe neue refreshOptionsIfNeeded() wie der bestehende line.name-Hook -
   identisch mit Spec Zeilen 980-994.

Keine Aenderung an selectionOptions(for:) selbst (Regeln 1-8 bleiben unangetastet, per Diff
bestaetigt - kein Hunk in dieser Funktion).

Frage: Laufen die Tests gruen, und ist es ein echter, nicht abgebrochener Lauf?

Beleg (eigener Lauf, nicht der vom Builder mitgelieferte):
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Restock
-project Restock.xcodeproj -destination 'platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7'
-only-testing:RestockTests/ReceiptReviewCardTests test

Ergebnis: "Executed 41 tests, with 0 failures (0 unexpected) in 0.174 (0.500) seconds" /
"** TEST SUCCEEDED **". 41 (nicht 0) Tests, kein Abbruch, keine Retry-Flags - kein Null-Test-Lauf.
Deckt sich mit dem vom Builder hinterlegten
docs/artifacts/fix-66-ai-resolved-name-selection/test-green-output.txt (ebenfalls 41/0).

Frage: War der RED-Zustand vor der Implementierung ein echter Fehlschlag, keine Behauptung?

Beleg: docs/artifacts/fix-66-ai-resolved-name-selection/test-red-unit.txt Zeilen 662-724 zeigt
einen echten Build-Fehler gegen den alten Stand: "'isSelected' is inaccessible due to 'private'
protection level", "Type 'ReceiptReviewCard' has no member 'listMatch'" usw. - die neuen Tests
referenzieren Symbole, die vor der Implementierung nicht existierten (3 failures, ** TEST FAILED
**). Echtes RED, kein vorgetaeuschtes.

Zwischenstand Runde 1: Diff entspricht der Spec woertlich, Tests sind gruen und der RED-Zustand
davor war ein echter Fehlschlag. Noch nicht geprueft: die von der Aufgabe geforderten Edge Cases zu
AC-23/24/25 und die Regressions-Reichweite (Aufrufer von applyCustomName/isSelected).

### Runde 2

#### Adversarial Probing der Edge Cases (AC-23/24/25)

Probe 1 - vorbestehender Randfall darf NICHT mitmarkiert werden: Zwei verschiedene Artikel mit
exakt demselben Namen; line.matchedItemID zeigt auf einen ANDEREN, existierenden Artikel als den
.listMatch-Kandidaten (nicht nil, nicht gleich suggestion.itemID).
Test: testIsSelectedDoesNotMarkListMatchWhenMatchedItemIDPointsToAnotherItem
(RestockTests/ReceiptReviewCardTests.swift, MARK "Issue #66") - GIVEN matchedItemID: UUID()
(fremd), suggestion.itemID verschieden THEN isSelected(...) == false. Bestanden. Die Lockerung
greift nachweislich NUR bei matchedItemID == nil, nicht bei einem gesetzten, abweichenden Wert -
exakt wie Invariante 6 / "Known Limitations" es verlangt.

Probe 2 - die vier unveraenderten isSelected-Zweige (.aiSuggestion, .currentName, .receiptText,
.custom) muessen nachweislich unveraendert bleiben:
Test: testIsSelectedMatchesPreviousBehaviorForAiSuggestionCurrentNameReceiptTextAndCustom prueft
alle vier Zweige explizit inkl. dem customActive-Sonderfall (isSelected(.custom, ..., true) ==
true, isSelected(.currentName, ..., true) == false). Zusaetzlich algebraisch nachvollzogen: die
neue Funktion prueft "if customActive { ... }" zuerst und faellt sonst in denselben Switch - fuer
alle Faelle ausser .listMatch identisches Ergebnis zur alten "!customActive && ..."-Formulierung.
Bestanden.

Probe 3 - Struktur-Invariante "nie zwei Markierungen":
Test: testEveryNamedFixtureEndsWithExactlyOneMarkedOptionAfterIssue66 deckt drei repraesentative
Zustaende ab (F001-Zustand, Regelfall exakte Zuweisung, .currentName-Rueckfall) und zaehlt
markedCount == 1 in jedem Fall. Bestanden.

Probe 4 (Nachfrage, nicht auf den ersten Blick akzeptiert) - AC-24 "matchedItemID ODER
resolvedByAI aendert sich, ohne dass der Name sich aendert": Die Spec (Test Plan, Zeile 1470-1477)
beschreibt exemplarisch einen Zustandswechsel, bei dem BEIDE Felder gemeinsam wechseln
(matchedItemID: id, resolvedByAI: false -> matchedItemID: nil, resolvedByAI: true). Der
tatsaechlich geschriebene Test
testStaleOptionsNoLongerMatchAfterMatchedItemIDAndResolvedByAIChangeWithoutNameChange haelt
matchedItemID konstant auf nil und aendert NUR resolvedByAI (true -> false). Das ist ein anderer
Zustandswechsel als im Test-Plan-Text beschrieben - es gibt KEINEN eigenstaendigen Testfall, der
ausschliesslich matchedItemID aendert (bei konstantem resolvedByAI) und die Guard-Erkennung dafuer
beweist.

Nachgefragt, ob das ein Loch ist: Der Guard selbst (refreshOptionsIfNeeded, siehe
!options.contains(where: { isSelected($0) }), Spec Zeilen 989-993) ist fuer alle drei
onChange-Hooks identischer, geteilter Code - er unterscheidet nicht, WELCHES Feld sich geaendert
hat, sondern prueft nur, ob nach der Aenderung noch irgendeine eingefrorene Option zum neuen
line-Zustand passt. Der bestehende Test beweist damit den Mechanismus (Guard erkennt "keine Option
passt mehr" korrekt), aber er beweist NICHT im beschriebenen Wortlaut den spezifischen
matchedItemID-Pfad isoliert. Da der Mechanismus nachweislich feldagnostisch ist (dieselbe private
Funktion, aufgerufen von allen drei onChange-Modifiern), ist das Risiko einer abweichenden
Fehlfunktion nur fuer den matchedItemID-Hook gering, aber NICHT durch einen eigenstaendigen Test
bewiesen - eine Abweichung zwischen Test-Plan-Text und Testcode.
-> Finding F001 (siehe unten), MEDIUM, kein Blocker.

Probe 5 - AC-25 Namensabgleich, Gross-/Kleinschreibung und Nicht-Treffer:
testApplyCustomNameLinksMatchedItemIDWhenNameEqualsASuggestion (Eingabe "vollmilch" gegen
Vorschlag "Vollmilch" -> matchedItemID gesetzt, resolvedByAI == false) und
testApplyCustomNameLeavesMatchedItemIDNilWhenNoSuggestionMatches (kein Treffer -> nil, wie
bisher) - beide bestanden. Zusaetzlich per Spec-Text bestaetigt (Abschnitt b): alle bisherigen
Aufrufer/Tests von applyCustomName nutzen Fixtures mit suggestions: [], aendern also ihr
Ergebnis nicht (line.suggestions.first { ... } liefert dort nil) - durch den vollstaendigen
Testlauf (41/41 gruen, keine der alten applyCustomName-Tests veraendert laut Diff-Statistik auf
reine Anhaenge beschraenkt) bestaetigt.

Probe 6 - Regression bei Aufrufern ausserhalb der Karte:
Suche nach "applyCustomName" im Quellbaum -> nur SmartCart/Views/Prices/ReceiptReviewCard.swift
und RestockTests/ReceiptReviewCardTests.swift. Suche nach "isSelected" -> zusaetzlich
RestockUITests/ReceiptReviewUITests.swift, aber dort ausschliesslich XCUIElement.isSelected
(Accessibility-Trait), nicht die geaenderte Funktion - kein Regressionsrisiko durch andere
Aufrufer.

Probe 7 - Diff-Umfang der Testdatei: Die Aenderungsstatistik gegen den Vorgaenger-Commit zeigt fuer
RestockTests/ReceiptReviewCardTests.swift ausschliesslich Insertions (155 Zeilen angehaengt am
Dateiende, MARK "Issue #66"), keine Aenderung an bestehenden Testmethoden - die Bedingung aus dem
Auftrag ("sofern keine Testdatei ausser den neu angehaengten #66-Tests veraendert wurde") ist
erfuellt; der 41/0-Gesamtlauf deckt die Punkte 1-27 als Regressionsnachweis vollstaendig ab.

## Strukturierte Befunde

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: RestockTests/ReceiptReviewCardTests.swift (Test
    testStaleOptionsNoLongerMatchAfterMatchedItemIDAndResolvedByAIChangeWithoutNameChange)
  Description: Der Test haelt matchedItemID konstant auf nil und aendert nur resolvedByAI
    (true->false). Der in der Spec (docs/specs/views/receipt-review-card.md Zeilen 1470-1477)
    beschriebene Testfall verlangt einen Zustandswechsel, bei dem matchedItemID UND resolvedByAI
    gemeinsam wechseln (id->nil, false->true). Es existiert kein eigenstaendiger Testfall, der
    ausschliesslich den matchedItemID-Pfad (bei konstantem resolvedByAI) isoliert beweist.
  Spec requirement: AC-24 - "Aendert eine externe Aufloesung matchedItemID ODER resolvedByAI ...
    wird die Auswahlliste ebenfalls einmal neu berechnet."
  Conflict: Die "ODER"-Formulierung impliziert zwei unabhaengig zu beweisende Pfade; nur einer ist
    isoliert getestet. Der Guard (refreshOptionsIfNeeded, ReceiptReviewCard.swift) ist zwar
    feldagnostischer, geteilter Code fuer alle drei onChange-Hooks (line.name/matchedItemID/
    resolvedByAI) - das mindert das Risiko, ersetzt aber keinen eigenstaendigen Testbeweis fuer
    den matchedItemID-Pfad.
  Remediation: Einen zusaetzlichen Unit-Test ergaenzen, der nur line.matchedItemID aendert
    (resolvedByAI und name konstant) und prueft, dass die eingefrorenen Optionen danach nicht mehr
    matchen - deckungsgleich mit dem in der Spec beschriebenen Test-Plan-Wortlaut.

## Bestaetigungen

Confirmation:
  AC: AC-23
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift (isSelected, .listMatch-Zweig);
    RestockTests/ReceiptReviewCardTests.swift
    (testIsSelectedMarksListMatchWhenMatchedItemIDIsNilAndNameEqualsSuggestion,
    testIsSelectedDoesNotMarkListMatchWhenMatchedItemIDPointsToAnotherItem,
    testIsSelectedStillMarksListMatchOnExactAssignment)
  Evidence: F001-Reproduktion (name gleich Vorschlag, matchedItemID nil, resolvedByAI true)
    markiert GENAU den Listen-Treffer (true); der vorbestehende Randfall (fremdes, gesetztes
    matchedItemID) bleibt unmarkiert (false); der Regelfall (exakte Zuweisung) markiert weiterhin
    (true). Alle drei Tests bestanden im eigenen Testlauf (41/0).
  Status: CONFIRMED

Confirmation:
  AC: AC-24
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift (refreshOptionsIfNeeded, drei
    onChange-Hooks); RestockTests/ReceiptReviewCardTests.swift
    (testStaleOptionsNoLongerMatchAfterMatchedItemIDAndResolvedByAIChangeWithoutNameChange)
  Evidence: Guard erkennt korrekt, dass nach einer externen Aenderung ohne Namensaenderung keine
    eingefrorene Option mehr passt - Voraussetzung fuer die Neuberechnung. Mit dem Vorbehalt aus
    F001 (nur der resolvedByAI-Teilpfad isoliert bewiesen, matchedItemID-Teilpfad nur ueber
    geteilten Code mitgedeckt).
  Status: CONFIRMED (mit Vorbehalt, siehe F001)

Confirmation:
  AC: AC-25
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift (applyCustomName);
    RestockTests/ReceiptReviewCardTests.swift
    (testApplyCustomNameLinksMatchedItemIDWhenNameEqualsASuggestion,
    testApplyCustomNameLeavesMatchedItemIDNilWhenNoSuggestionMatches)
  Evidence: Case-insensitiver Treffer verknuepft matchedItemID korrekt, resolvedByAI bleibt false;
    kein Treffer laesst matchedItemID bei nil (Regression zu
    testEnteringCustomNameClearsMatchAndAiFlag bestaetigt durch unveraenderten Bestand dieses
    Tests im Gesamtlauf).
  Status: CONFIRMED

Confirmation:
  AC: Punkte 1-27 (Regression, vor #66 bereits validiert)
  Code reference: RestockTests/ReceiptReviewCardTests.swift (vollstaendige Testklasse, 41 Tests)
  Evidence: Aenderungsstatistik gegen den Vorgaenger-Commit zeigt fuer
    ReceiptReviewCardTests.swift ausschliesslich Insertions (155 Zeilen am Dateiende) - keine
    bestehende Testmethode veraendert. Gesamtlauf: "Executed 41 tests, with 0 failures (0
    unexpected)". Keine andere Testdatei (ReceiptReviewUITests.swift,
    ReceiptScannerReResolutionTests.swift) im Aenderungssatz beruehrt.
  Status: CONFIRMED

## Testlauf (eigener, vollstaendiger Output)

Befehl:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Restock
-project Restock.xcodeproj -destination 'platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7'
-only-testing:RestockTests/ReceiptReviewCardTests test

Auszug:
Test Suite 'ReceiptReviewCardTests' passed at 2026-09-28 22:50:38.130.
	 Executed 41 tests, with 0 failures (0 unexpected) in 0.174 (0.500) seconds
Test Suite 'RestockTests.xctest' passed at 2026-09-28 22:50:38.130.
	 Executed 41 tests, with 0 failures (0 unexpected) in 0.174 (0.500) seconds
Test Suite 'Selected tests' passed at 2026-09-28 22:50:38.130.
	 Executed 41 tests, with 0 failures (0 unexpected) in 0.174 (0.501) seconds
** TEST SUCCEEDED **

===========================================
VERDICT: VERIFIED
===========================================
Tests: 41 passed, 0 failed (eigener Lauf, deckungsgleich mit dem hinterlegten
test-green-output.txt). RED-Nachweis (test-red-unit.txt) zeigt einen echten Build-Fehlschlag vor
der Implementierung (3 failures wegen fehlender/privater Symbole) - keine vorgetaeuschte
RED-Phase.

Checkliste: 30/30 Punkte behandelt.
  - Punkte 1-27: per Regressionslauf bestaetigt (keine bestehende Testmethode veraendert, 41/0
    gruen).
  - AC-23: PROVEN (F001-Reproduktion markiert, vorbestehender Randfall bleibt unmarkiert,
    Regelfall unveraendert).
  - AC-24: PROVEN, mit einem dokumentierten, nicht-blockierenden Vorbehalt (F001 - der
    matchedItemID-Teilpfad ist nur ueber geteilten, feldagnostischen Code mitbewiesen, nicht durch
    einen isolierten Testfall wie im Test-Plan-Text beschrieben).
  - AC-25: PROVEN (Treffer verknuepft, Nicht-Treffer bleibt nil, Regression bestaetigt).

Regressionen: Keine gefunden. applyCustomName und die statische isSelected-Funktion haben keine
Aufrufer ausserhalb von ReceiptReviewCard.swift/ReceiptReviewCardTests.swift; das einzige weitere
isSelected-Vorkommen (ReceiptReviewUITests.swift) ist das unabhaengige XCUIElement.isSelected.

Offener Punkt fuer den Menschen (nicht verdikt-blockierend): F001 - ein zusaetzlicher, isolierter
Unit-Test fuer den matchedItemID-Only-Pfad von AC-24 waere wortgetreuer zum Test-Plan-Text; der
Mechanismus selbst (geteilter, feldagnostischer Guard) ist bereits nachweislich funktionsfaehig.

## Geprüfte Dateien

- sha256:274b8cdd150be189c4a9e3b662be301488ef4e8a6b5489fdedcbe3c9a75a13da  RestockTests/ReceiptReviewCardTests.swift
- sha256:685e5d841b1765845e696409c71a3e45d1461f37193df662e5492843470334f0  SmartCart/Views/Prices/ReceiptReviewCard.swift
