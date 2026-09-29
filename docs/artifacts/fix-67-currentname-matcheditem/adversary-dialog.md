# Adversary Dialog - fix-67-currentname-matcheditem (Issue #67)

Spec: docs/specs/views/receipt-review-card.md
  - "Scope-Erweiterung (Issue #67 - 2026-09-29)", Zeilen 309-333
  - "Nachtrag Issue #67 (2026-09-29): `.currentName`-Auswahl bereinigt `matchedItemID`", Zeilen 1079-1113
  - AC-26 (Wortlaut), Zeilen 1690-1693; Testplan-Punkt AC-26, Zeilen 1583-1590
  - Invariante 2, Zeilen 1120-1125
Geaenderte Datei (Arbeitsbaum, UNCOMMITTED): SmartCart/Views/Prices/ReceiptReviewCard.swift
Neuer Test (bereits committet in c9c1c66): RestockTests/ReceiptReviewCardTests.swift:358-375
Prueflauf-Geraet: Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7)

---

### Runde 1 - Anspruch, Diff, Testlaeufe

#### Frage 1.1: Entspricht der Arbeitsbaum-Diff wortgenau dem Spec-Codeblock aus "Nachtrag Issue #67"?

Beleg: Der Diff des Arbeitsbaums gegen HEAD (nicht die Commit-Historie - die Produktiv-Aenderung
ist uncommitted) liefert GENAU einen Hunk, 2 Zeilen, 0 Loeschungen:

```
SmartCart/Views/Prices/ReceiptReviewCard.swift
@@ -544,6 +544,8 @@ struct ReceiptReviewCard: View {
             line.resolvedByAI = true
         case .currentName(let name):
             line.name = name
+            line.matchedItemID = nil
+            line.resolvedByAI = false
         case .receiptText(let name):
```

Spec-Sollzustand (Zeilen 1104-1109):

```swift
case .currentName(let name):
    line.name = name
    line.matchedItemID = nil
    line.resolvedByAI = false
```

Code-Referenz Istzustand: SmartCart/Views/Prices/ReceiptReviewCard.swift:545-548.
Bewertung: PROVEN - zeichengleich, Reihenfolge inklusive. Der Zweig steht jetzt Zeile fuer Zeile
identisch zum daneben liegenden `.receiptText`-Zweig (:549-553), wie die Spec es als Muster nennt.

#### Frage 1.2: Laufen die Tests gruen - und ist es ein echter Lauf, kein Null-Test-Lauf?

Beleg (eigener Lauf, nicht der hinterlegte Output), Zielsuite
RestockTests/ReceiptReviewCardTests auf Geraet 8F696920-4B9A-40A7-96F0-7697BE887CC7:
"Executed 42 tests, with 0 failures (0 unexpected) in 0.029 (0.050) seconds" / "** TEST SUCCEEDED **".
Zeile 84/85 des Laufs nennt die neue Methode ausdruecklich:
"testChoosingCurrentNameAfterAiSuggestionClearsMatchedItemIDAndResolvedByAI passed (0.000 seconds)".
42 statt 0 Tests, kein "Testing cancelled", kein Retry-Flag - kein Null-Test-Lauf.
Deckungsgleich mit dem hinterlegten docs/artifacts/fix-67-currentname-matcheditem/test-green-output.txt
(ebenfalls 42/0, gleiche Geraete-UDID).
Bewertung: PROVEN.

#### Frage 1.3: War der RED-Zustand echt oder nur behauptet?

Beleg: docs/artifacts/fix-67-currentname-matcheditem/test-red-output.txt, Zeilen 273-278:
- ReceiptReviewCardTests.swift:372: error: ... XCTAssertNil failed: "A1FA3BB0-..." - Die zuvor
  ueber den KI-Vorschlag gesetzte matchedItemID darf nicht stehen bleiben.
- ReceiptReviewCardTests.swift:373: error: ... XCTAssertFalse failed - Nach Wahl des aktuellen
  Namens ist keine KI-Zuordnung mehr aktiv.
- "Executed 1 test, with 2 failures" / "** TEST FAILED **"
Genau die zwei neuen Assertions schlagen fehl, die Vorbedingungs-Assertion (:369) und die
Namens-/originalName-Assertions nicht. Kein vorgetaeuschtes RED.
Bewertung: PROVEN.

#### Frage 1.4: Reproduziere ich das RED selbst (Protokoll "Reproduktion zuerst")?

Beleg: Ich habe die beiden Fix-Zeilen im Arbeitsbaum voruebergehend entfernt (Zustand von HEAD
wiederhergestellt) und dieselbe Suite erneut laufen lassen:
"Executed 47 tests, with 5 failures (0 unexpected)" / "** TEST FAILED **", darunter
testChoosingCurrentNameAfterAiSuggestionClearsMatchedItemIDAndResolvedByAI mit exakt den zwei
erwarteten Failures (:372 XCTAssertNil, :373 XCTAssertFalse).
Danach Datei aus der Sicherung zurueckgeschrieben; der Diff gegen HEAD zeigt wieder genau den
2-Zeilen-Hunk, das Testfile ist bit-identisch (md5 f1c9634ffb9cc434c62d03c9194a8ba0 vor und nach
der Pruefung).
Bewertung: PROVEN - der Fix ist nachweislich tragend, nicht nur begleitend.

Zwischenstand Runde 1: Diff = Spec-Wortlaut, GREEN echt, RED echt und selbst reproduziert.
Noch offen: Edge Cases, Regressionsreichweite, Invariante 2, die Scope-Begrenzung
("ausdruecklich NICHT geaendert").

---

### Runde 2 - Adversariales Probing

Fuer diese Runde habe ich fuenf zusaetzliche Testmethoden temporaer an
RestockTests/ReceiptReviewCardTests.swift angehaengt (Praefix testAdv), beide Laeufe gefahren
(mit und ohne Fix) und die Datei danach bit-identisch zurueckgesetzt. Ergebnis mit Fix:
"Executed 47 tests, with 0 failures" / "** TEST SUCCEEDED **".

Probe 1 - `.currentName` OHNE vorherige andere Auswahl (matchedItemID war schon nil):
testAdvCurrentNameWithoutPriorSelectionStaysClean - matchedItemID bleibt nil, resolvedByAI bleibt
false, originalName unveraendert, zweiter Aufruf idempotent. Kein Absturz, kein Seiteneffekt.
BESTANDEN. Ohne Fix schlaegt diese Probe erwartungsgemaess NICHT fehl (der Zustand war schon
sauber) - sie belegt also gerade, dass der Fix hier nichts kaputt macht.

Probe 2 - `.currentName` nach `.listMatch` (die zweite in AC-26 genannte Vorbelegung neben
`.aiSuggestion`, im Entwickler-Test NICHT abgedeckt):
testAdvCurrentNameAfterListMatchClearsID - matchedItemID == nil, resolvedByAI == false.
BESTANDEN. Ohne Fix: XCTAssertNil failed: "95394E85-..." (Zeile 163 des Selbst-RED-Laufs).
Damit ist der Satz der AC-26 "Eine zuvor ueber eine andere Option (z. B. `.aiSuggestion`,
`.listMatch`) gesetzte matchedItemID bleibt nie stehen" fuer BEIDE genannten Optionen belegt,
nicht nur fuer die eine im Entwickler-Test.

Probe 3 - leerer Name als Grenzwert:
testAdvCurrentNameWithEmptyNameDoesNotCrashAndKeepsOriginalName - `.currentName(name: "")` setzt
name == "", bereinigt matchedItemID/resolvedByAI, originalName bleibt. Kein Absturz. BESTANDEN.
(Praktisch unerreichbar: selectionOptions Regel 5 legt bei leerem line.name keine
`.currentName`-Zeile an, ReceiptReviewCard.swift:488-492; Regel 6 :495 erzeugt sie nur als
Rueckfall. Die Funktion selbst ist aber robust.)

Probe 4 - veraendert der Fix ungewollt einen anderen case-Zweig?
testAdvOtherBranchesUnchangedAfterFix prueft nach einem `.currentName`-Durchgang jeweils
`.listMatch` (setzt ID wieder, resolvedByAI false), `.aiSuggestion` (stellt
aiSuggestedMatchedItemID und resolvedByAI == true wieder her - AC-6 intakt), `.receiptText`
(unveraendert nil/false) und `.custom` (weiter ein No-Op, Name und ID bleiben stehen). BESTANDEN -
und zwar sowohl MIT als auch OHNE Fix identisch, was beweist, dass die zwei Zeilen keinen anderen
Zweig beruehren. Code-Referenz: die vier uebrigen Zweige liegen unveraendert bei
SmartCart/Views/Prices/ReceiptReviewCard.swift:535-543 und :549-556.

Probe 5 - Markierungsregel / Regel 9 (kann der Fix zwei Markierungen oder einen Listen-Sprung
ausloesen?): testAdvExactlyOneOptionSelectedAfterCurrentNameTap friert die Optionsliste ein,
waehlt `.aiSuggestion`, dann `.currentName` und zaehlt die markierten Zeilen -> genau 1.
BESTANDEN, mit und ohne Fix gleich.
Zusaetzlich analytisch: refreshOptionsIfNeeded() (:388-391) haengt seit #66 auch an
line.matchedItemID und line.resolvedByAI (:203-205). Der Fix aendert beide Felder, der Guard
"guard !options.contains(where: { isSelected($0) })" haelt aber, weil isSelected(.currentName)
allein den Namen vergleicht (:414-415) und dieser nach dem Tap passt. Die Liste springt nicht
unter dem Finger weg.

Probe 6 - Regressionsreichweite:
- applySelection hat genau zwei Aufrufstellen: select(_:) (:440) und die Tests. select(_:) wird
  ausschliesslich aus dem Button-Label der Auswahlzeile aufgerufen (:214) - es gibt KEINEN
  automatischen Pfad (kein onAppear/onChange), der `.currentName` anwendet. Eine externe
  KI-Nachaufloesung kann die Bereinigung also nicht ungewollt ausloesen.
- Volle Unit-Suite als Regressionsnachweis (eigener Lauf, Target RestockTests):
  "Executed 287 tests, with 0 failures (0 unexpected) in 1.964 (2.049) seconds" /
  "** TEST SUCCEEDED **".
- UI-Suite: kein UI-Test tippt eine `.currentName`-Zeile an.
  testTappingListMatchSelectsThatOption (RestockUITests/ReceiptReviewUITests.swift:424) tippt
  option.2 (Listen-Treffer), testTappingReceiptTextOptionSelectsNormalizedBonText (:993) die
  Bon-Zeile, die drei Custom-Tests option.<aiLineCustomOptionIndex>;
  testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution (:831) und
  testSavingStillWritesLearnedPriceToMatchedItem (:719) lesen nur bzw. speichern ohne
  Auswahlaenderung. Der geaenderte Zweig liegt damit ausserhalb jeder UI-Test-Interaktion.

Probe 7 - Invariante 2 ("nur name/matchedItemID/resolvedByAI aendern sich, originalName bleibt"):
Der Hunk schreibt ausschliesslich line.matchedItemID und line.resolvedByAI - beide sind in
Invariante 2 bereits als veraenderlich benannt. Kein weiteres Feld im Zweig.
Belegt durch die Assertion auf originalName im neuen Test
(RestockTests/ReceiptReviewCardTests.swift:374), durch Probe 1/3 und durch den weiterhin gruenen
Bestandstest testOriginalNameSurvivesAllThreeSelectionPaths (:392-405).
Bewertung: PROVEN.

Probe 8 - Scope-Begrenzung "Ausdruecklich NICHT geaendert":
Der Diff gegen HEAD umfasst 1 Datei, 2 Insertions, 0 Deletions, einziger Hunk bei :544-548.
Damit mechanisch bewiesen unveraendert: isSelected(_:for:customActive:) (:399-421),
selectionOptions(for:) (:460-505), Regel 9 (:198-205 / :388-391),
ReceiptResolutionService.swift, SmartCartApp.swift (kein neuer Seed), project.pbxproj.
Der Hunk liegt vollstaendig innerhalb von applySelection (:533-557).
Bewertung: PROVEN.

---

### Runde 3 - Restzweifel und Spec-Wortlaut-Abgleich

#### Frage 3.1: Kann die neue Bereinigung eine Zuordnung zerstoeren, die der Nutzer nie gewaehlt hat?

Erreichbarer Fall: line.suggestions enthaelt mehr als drei Eintraege (der Resolver liefert bis zu
fuenf), prefix(3) (:461) schneidet den tatsaechlich zugeordneten Treffer ab; Regel 5 (:488-492)
legt dann eine `.currentName`-Zeile mit dem geltenden Namen an, die laut :414-415 als markiert
gilt, WAEHREND matchedItemID gesetzt ist. Tippt der Nutzer auf diese ohnehin markierte Zeile,
faellt die ID - ohne dass er einen anderen Namen gewaehlt haette.
Bewertung: Spec-konform (AC-26 formuliert die Bereinigung ausdruecklich unbedingt: "Wahl der
`.currentName`-Zeile setzt matchedItemID = nil"), und folgenarm: save() sucht bei
matchedItemID == nil exakt ueber die abgehakten Artikel desselben Stores
(SmartCart/Views/Prices/ReceiptScannerView.swift:652-655) - der Name ist in diesem Fall
unveraendert derselbe, der Preis landet also am selben Artikel. Als F003 (LOW) notiert, nicht
verdikt-blockierend.

#### Frage 3.2: Stimmt der Spec-Wortlaut mit dem Code ueberein - oder erbt AC-26 eine veraltete Analogie?

AC-26 begruendet die Bereinigung mit "dieselbe Bereinigung wie bei der Bon-Zeile (AC-21) und
'Anderer Name ...' (AC-7)". Fuer AC-21/`.receiptText` stimmt das exakt (:549-553). Fuer
"Anderer Name ..." gilt es seit Issue #66/AC-25 nur noch eingeschraenkt: applyCustomName
(:562-571) setzt matchedItemID bei wortgleichem Vorschlag AUF DESSEN itemID statt auf nil.
Die operative Anweisung der AC-26 ("setzt matchedItemID = nil und resolvedByAI = false") ist davon
unberuehrt und wird vom Code erfuellt; nur die Begruendungs-Analogie ist ueberholt.
Als F002 (LOW) notiert.

#### Frage 3.3: Ist der Test rueckverfolgbar zur Spec-Nummer?

Der Doc-Kommentar der neuen Testmethode (RestockTests/ReceiptReviewCardTests.swift:358) lautet
"AC-23 (Issue #67)", die Spec fuehrt den Punkt aber als AC-26 (AC-23 ist seit dem gemergten #66
belegt; die Umnummerierung steht in der Commit-Nachricht von c9c1c66). Nur der Kommentar, nicht
der Testname oder die Logik. Als F001 (LOW) notiert.

---

## Structured Findings

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: RestockTests/ReceiptReviewCardTests.swift:358
  Description: Der Doc-Kommentar der neuen Testmethode nennt "AC-23 (Issue #67)".
  Spec requirement: AC-26 - der Punkt ist in der Spec (Zeile 1690) und im Testplan (Zeile 1583)
    als AC-26 gefuehrt; AC-23 gehoert zum bereits gemergten Issue #66.
  Conflict: Rueckverfolgbarkeit Test zu AC bricht bei der naechsten Spec-Lesung; Logik und
    Testname sind korrekt, nur der Kommentar zeigt auf die falsche AC-Nummer.
  Remediation: Kommentar auf "AC-26 (Issue #67)" aendern.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:566
  Description: applyCustomName setzt matchedItemID bei wortgleichem Vorschlag auf dessen itemID
    (Issue #66/AC-25), nicht auf nil.
  Spec requirement: AC-26 (Spec-Zeile 1691) begruendet die neue Bereinigung mit "dieselbe
    Bereinigung wie ... 'Anderer Name ...' (AC-7)".
  Conflict: Die Analogie zu AC-7 gilt seit AC-25 nicht mehr unbedingt - "Anderer Name" bereinigt
    nicht mehr ausnahmslos. Die operative Anweisung der AC-26 selbst ist erfuellt; betroffen ist
    nur der Begruendungssatz der Spec, nicht der Code.
  Remediation: In AC-26 den Verweis auf AC-7 durch AC-21 / .receiptText ersetzen oder um
    "(vor AC-25)" ergaenzen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:461
  Description: prefix(3) kann den tatsaechlich zugeordneten Vorschlag abschneiden; Regel 5
    (:488-492) bietet dann eine bereits markierte .currentName-Zeile an (isSelected vergleicht nur
    den Namen, :414-415). Ein Tap darauf loescht eine matchedItemID, die keine Nutzerauswahl
    gesetzt hat.
  Spec requirement: AC-26 verlangt die Bereinigung unbedingt bei jeder Wahl der .currentName-Zeile.
  Conflict: Kein Widerspruch zur AC - aber ein Nebeneffekt, den die Spec nicht ausdruecklich
    behandelt. Folgenarm, weil save() bei matchedItemID == nil exakt ueber den unveraenderten
    Namen der abgehakten Artikel desselben Stores zuordnet
    (SmartCart/Views/Prices/ReceiptScannerView.swift:652-655).
  Remediation: Keine Codeaenderung noetig; bei Bedarf in "Known Limitations" der Spec aufnehmen.

## Confirmations

Confirmation:
  AC: AC-26
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:545
  Evidence: Der .currentName-Zweig setzt line.name, line.matchedItemID = nil und
    line.resolvedByAI = false (:545-548) - zeichengleich mit dem Spec-Codeblock (Zeilen 1104-1109).
    Eigener GREEN-Lauf 42/0 inkl. der neuen Methode; eigener Selbst-RED nach Entfernen der zwei
    Zeilen 47/5 mit exakt den erwarteten Failures; zusaetzlich fuer die zweite in AC-26 genannte
    Vorbelegung (.listMatch) durch Probe 2 belegt.
  Status: CONFIRMED

Confirmation:
  AC: Invariante 2 (originalName unveraendert)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:546
  Evidence: Der Hunk schreibt ausschliesslich matchedItemID und resolvedByAI - beide in
    Invariante 2 als veraenderlich benannt. Assertion auf originalName im neuen Test (:374),
    Proben 1 und 3, sowie der weiterhin gruene Bestandstest
    testOriginalNameSurvivesAllThreeSelectionPaths (RestockTests/ReceiptReviewCardTests.swift:392).
  Status: CONFIRMED

Confirmation:
  AC: Scope-Begrenzung "Ausdruecklich NICHT geaendert" (Spec-Zeilen 332-333)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:399
  Evidence: Diff gegen HEAD = 1 Datei / 2 Insertions / 0 Deletions, einziger Hunk bei :544-548
    innerhalb applySelection. isSelected (:399-421), selectionOptions (:460-505), Regel 9
    (:198-205, :388-391) tragen keinen Hunk; ReceiptResolutionService.swift, SmartCartApp.swift
    und project.pbxproj sind unveraendert (nicht im Diff).
  Status: CONFIRMED

Confirmation:
  AC: Keine Regression in den vier uebrigen applySelection-Zweigen
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:535
  Evidence: Probe 4 (testAdvOtherBranchesUnchangedAfterFix) prueft .listMatch, .aiSuggestion
    (AC-6-Wiederherstellung), .receiptText und .custom nach einem .currentName-Durchgang - mit und
    ohne Fix identisch bestanden. Volle Unit-Suite: 287 Tests, 0 Failures. Keine
    UI-Test-Interaktion beruehrt den Zweig (Probe 6).
  Status: CONFIRMED

---

## Testlauf-Belege (eigene Laeufe, Geraet Restock-Validate)

1. Zielsuite mit Fix:
   "Executed 42 tests, with 0 failures (0 unexpected) in 0.029 (0.050) seconds" / "** TEST SUCCEEDED **"
2. Zielsuite + 5 adversariale Proben, mit Fix:
   "Executed 47 tests, with 0 failures (0 unexpected) in 0.075 (0.096) seconds" / "** TEST SUCCEEDED **"
3. Selbst-RED (Fix-Zeilen temporaer entfernt), gleiche 47 Tests:
   "Executed 47 tests, with 5 failures (0 unexpected) in 0.385 (0.396) seconds" / "** TEST FAILED **"
   (2 Failures im Entwickler-Test :372/:373, 3 in den Proben 2 und 3)
4. Volle Unit-Suite als Regressionsnachweis:
   "Executed 287 tests, with 0 failures (0 unexpected) in 1.964 (2.049) seconds" / "** TEST SUCCEEDED **"

Arbeitsbaum nach der Pruefung wieder im Ausgangszustand: Testdatei bit-identisch
(md5 f1c9634ffb9cc434c62d03c9194a8ba0), Diff gegen HEAD weiterhin genau der 2-Zeilen-Hunk.

Hinweis an den Aufrufer (kein Finding, keine Codestelle): Im Workflow-Ordner liegen nur
test-red-output.txt und test-green-output.txt. Ein registrierter Simulator-Durchlauf fehlt; der
Spec-Testplan fuer #67 verlangt nur den Unit-Test, die Hausregel "Die App wird benutzt" gilt aber
unabhaengig davon fuer den Abschluss.

===========================================
VERDICT: VERIFIED
===========================================
Die Implementierung hat das adversariale Probing gehalten.
Tests: 42 passed / 0 failed (Zielsuite), 287 passed / 0 failed (volle Unit-Suite), 47 passed /
  0 failed mit den fuenf zusaetzlichen Proben - alles eigene Laeufe auf Restock-Validate, keine
  Null-Test-Laeufe, keine Abbrueche.
RED-Nachweis: echt und von mir selbst reproduziert (5 Failures ohne die zwei Fix-Zeilen).
Edge Cases: 5 Proben (ohne Vorauswahl, nach .listMatch, leerer Name, andere case-Zweige,
  Doppelmarkierung/Regel 9) - keine gebrochen.
Regressionen: keine. applySelection wird nur aus dem Button-Tap aufgerufen; kein automatischer
  Pfad, kein UI-Test beruehrt den Zweig.
Checkliste: AC-26 PROVEN, Invariante 2 PROVEN, Scope-Begrenzung PROVEN, Zweig-Regression PROVEN
  (4/4 Punkte).
Offene, nicht blockierende Punkte: F001 (falsche AC-Nummer im Testkommentar), F002 (ueberholte
  AC-7-Analogie im Spec-Wortlaut), F003 (dokumentierbarer Randfall) - alle LOW.

## Geprüfte Dateien

- sha256:7c2fe52273ee73e575ed3e858d3ef7befd922053d9f988d4a946816a6f5c27f3  RestockTests/ReceiptReviewCardTests.swift
- sha256:2953af57c22c607b42710a6a2d7037324e25688924a00815463f4485e4c24094  SmartCart/Views/Prices/ReceiptReviewCard.swift
