# Adversary-Dialog: fix-37-receipt-name-preselect

Spec: `docs/specs/views/receipt-review-card.md`
Fokus dieses Dialogs: Issue #37 (neue Regel 5 in `selectionOptions(for:)`, AC-4-Praezisierung).
Punkte 1-9, 11-18: Stichprobe (bereits durch frueheren, gemergten Workflow #23 bewiesen).

### Runde 1 - Erstpruefung

### Testlauf (Gesamtsuite, vorgelegtes Artefakt)

test-green-output.txt zeigt: Executed 165 tests, with 0 failures (0 unexpected).
TEST SUCCEEDED. ReceiptReviewCardTests innerhalb dieses Laufs: 21 Tests, 0 Fehler.

### Isolations-Check (Stichprobe Punkte 1-9, 11-18)

Der Commit-Vergleich zu diesem Workflow zeigt ausschliesslich zwei geaenderte Dateien:
RestockTests/ReceiptReviewCardTests.swift (57 Zeilen) und
SmartCart/Views/Prices/ReceiptReviewCard.swift (15 Zeilen).
SmartCart/Views/Prices/ReceiptScannerView.swift (traegt save()) wurde zuletzt im vorherigen,
bereits gemergten #23-Workflow veraendert, nicht in diesem. Der Diff innerhalb
ReceiptReviewCard.swift (Zeilen 419-437) zeigt Regel 5 exakt zwischen der bisherigen Regel 4
(Kappung) und der bisherigen Regel 5/jetzt 6 (Leer-Fallback) eingefuegt - keine andere Funktion,
kein UI-Test veraendert.
Ergebnis: Punkte 1-9 und 11-18 sind durch diesen Workflow nicht angefasst; sie bleiben auf dem
Stand des bereits gemergten und getesteten #23-Workflows.

### Hauptfokus AC-4 (Issue #37) - erste Pruefung der Testfaelle a-e

| Teilfall | Test | Ergebnis |
|---|---|---|
| a) 3 Kandidaten, keiner passt, Name nicht leer | testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches (Zeile 171-189) und testFiveSuggestionsAreCappedToThreeListMatches (Zeile 151-166) | PASSED - options[0] == aktuell:Milch, Vollmilch entfaellt, 4 Optionen gesamt |
| b) weniger als 3 Kandidaten, keiner passt | kein Test im Test Plan/Testfile gefunden | LUECKE |
| c) line.name leer | testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches (Zeile 193-209) | PASSED - keine currentName-Zeile, 3 Treffer bleiben |
| d) line.name bereits unter Kandidaten (case-insensitiv) | testPreselectedListMatchIsSortedFirstRegardlessOfCase (Zeile 117-143) | PASSED (indirekt) - options[0] ist listMatch, nicht currentName; Regel 5 griff nicht |
| e) Reihenfolge-Erhalt der uebrigen Kandidaten | testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches (Zeile 184-185) | PASSED - Hafermilch vor Buttermilch, Reihenfolge erhalten |

Erstbefund: 4 von 5 Teilfaellen durch existierende, gruene Tests bewiesen. Teilfall b) ist im
Test Plan der Spec selbst nicht vorgesehen (nur zwei neue Tests plus eine Ergaenzung, siehe Spec
Zeile 369-388) und im Testfile nicht vorhanden - das ist eine Luecke, kein Beweis vorhanden.
Kein vorschnelles VERIFIED - Runde 2 folgt mit eigener Verifikation von Teilfall b) und
zusaetzlichen Stichproben.

### Runde 2 - Vertiefung

### Eigener Testlauf (frisch, unabhaengig vom vorgelegten Artefakt)

Gezielter Rerun von RestockTests/ReceiptReviewCardTests auf Simulator Restock-Validate
(8F696920-4B9A-40A7-96F0-7697BE887CC7), Ergebnis gespeichert unter
adversary-rerun-receiptreviewcard.txt: Executed 21 tests, with 0 failures (0 unexpected).
TEST SUCCEEDED. Bestaetigt den vorgelegten Lauf unabhaengig - keine Diskrepanz.

### Eigene Probe fuer Teilfall b) (Luecke aus Runde 1)

Da kein Test fuer "weniger als 3 Kandidaten, keiner passt" existiert, wurde ein temporaerer
Testfall in RestockTests/ReceiptReviewCardTests.swift ergaenzt, ausgefuehrt und anschliessend
vollstaendig wieder entfernt (keine bleibende Aenderung). Der Testfall (Name "Milch", nur zwei
Suggestions "Hafermilch"/"Buttermilch", keine passt) lieferte als Ergebnis genau vier Optionen:
aktuell:Milch, treffer:Hafermilch, treffer:Buttermilch, eigener (siehe
adversary-probe-caseB.txt) - Test lief gruen (TEST SUCCEEDED).

Das Verhalten stimmt exakt mit der in der Spec dokumentierten "Known Limitation" ueberein
(docs/specs/views/receipt-review-card.md Zeile 583-588): bei zwei Kandidaten wird eine
currentName-Zeile eingefuegt, ohne dass etwas entfernt wird (Ergebnis bleibt bei drei
inhaltlichen Kandidaten, Invariante 5/AC-2 weiterhin gewahrt). Verhalten korrekt - aber
ungetestet im ausgelieferten Testfile. Die Testdatei wurde danach vollstaendig auf den
urspruenglichen Stand zurueckgesetzt (Probe vollstaendig entfernt, keine bleibende Aenderung
im Arbeitsverzeichnis, per Abgleich mit dem committeten Stand bestaetigt).

### Weitere Nachfragen (Skeptiker-Runde)

1. Wechselwirkung Regel 3 / Regel 5: Kann Regel 5 faelschlich feuern, obwohl Regel 3 bereits
   einen Treffer nach vorne sortiert hat? Nein - Regel 5 prueft erneut ueber die volle, bereits
   sortierte Kandidatenliste (case-insensitiver Vergleich mit line.name, ReceiptReviewCard.swift
   Zeile 428, im Rahmen der erlaubten Isolationspruefung gelesen) - ein durch Regel 3 nach vorne
   geholter Treffer bleibt also in der Liste und verhindert das Feuern von Regel 5. Test d)
   belegt dies bereits (options[0] bleibt listMatch, keine currentName-Zeile).
2. Whitespace-Namen (ein einzelnes Leerzeichen): Swifts isEmpty ist bei einem reinen Leerzeichen
   false, Regel 5 wuerde also feuern. Kein Test deckt diesen Grenzfall ab. Praktisch
   unwahrscheinlich (OCR liefert keine reinen Leerzeichen als Namen), daher nur als
   LOW-Beobachtung vermerkt, kein eigener Fund.
3. AC-2/Invariante 5 nach der Aenderung insgesamt noch gueltig? Bestaetigt durch frischen Rerun:
   testFiveSuggestionsAreCappedToThreeListMatches und
   testPreselectedListMatchIsSortedFirstRegardlessOfCase liefern weiterhin options.count == 4
   (max. 3 inhaltliche plus eigener Name) - keine Regression.

## Structured Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: RestockTests/ReceiptReviewCardTests.swift:151-209
  Description: Das Testfile deckt Issue #37 Regel 5 nur fuer den Fall mit genau 3 verbliebenen
    Kandidaten ab (Verdraengung des schwaechsten) sowie den Leer-Namen-Regressionsfall. Der in
    der Spec selbst als "ungeloester Randfall" benannte Fall - weniger als 3 Kandidaten, keiner
    passt zu line.name - hat keinen automatisierten Test.
  Spec requirement: AC-4 (Issue #37) / Known Limitations (docs/specs/views/receipt-review-card.md
    Zeile 583-588) beschreibt dieses Verhalten explizit als erwartet (Ziel max. 3 inhaltliche
    Kandidaten bleibt gewahrt), aber der Test Plan (Zeile 369-388) sieht dafuer keinen Test vor.
  Conflict: Kein Test schuetzt diesen dokumentierten Fall vor kuenftiger Regression - ein
    Refactoring von selectionOptions koennte dieses Verhalten stillschweigend brechen, ohne dass
    eine rote Testreihe das anzeigt. Durch eigene Adversary-Probe (siehe Runde 2) verifiziert,
    dass das aktuelle Verhalten korrekt der Spec entspricht - es ist also aktuell kein Bug,
    sondern eine Testabdeckungsluecke.
  Remediation: Einen dauerhaften Testfall analog zur Adversary-Probe (2 Kandidaten, keiner
    passt, Name nicht leer, Ergebnis 3 inhaltliche Kandidaten ohne Entfernung) in
    RestockTests/ReceiptReviewCardTests.swift aufnehmen.

## Confirmations

Confirmation:
  AC: Punkt 10 / AC-4 (Issue #37), Teilfall a
  Code reference: RestockTests/ReceiptReviewCardTests.swift:171-189
  Evidence: testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches - 3 Kandidaten, keiner
    passt zu "Milch"; options[0] == aktuell:Milch, Vollmilch (schwaechster) entfaellt, 4 Optionen
    gesamt. PASSED in Gesamtlauf (165/165) und im gezielten Rerun (21/21).
  Status: CONFIRMED

Confirmation:
  AC: Punkt 10 / AC-4 (Issue #37), Teilfall c
  Code reference: RestockTests/ReceiptReviewCardTests.swift:193-209
  Evidence: testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches - leerer Name, 3
    Treffer bleiben unveraendert, keine currentName-Zeile. PASSED.
  Status: CONFIRMED

Confirmation:
  AC: Punkt 10 / AC-4 (Issue #37), Teilfall d
  Code reference: RestockTests/ReceiptReviewCardTests.swift:117-143
  Evidence: testPreselectedListMatchIsSortedFirstRegardlessOfCase - Name "vollmilch" (klein)
    entspricht case-insensitiv dem Treffer "Vollmilch"; options[0] bleibt listMatch, keine
    zusaetzliche currentName-Zeile entsteht (options.count bleibt 4). PASSED.
  Status: CONFIRMED

Confirmation:
  AC: Punkt 10 / AC-4 (Issue #37), Teilfall e
  Code reference: RestockTests/ReceiptReviewCardTests.swift:184-188
  Evidence: testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches - nach Einfuegen von
    aktuell:Milch bleiben Hafermilch und Buttermilch in urspruenglicher Reihenfolge, Vollmilch
    (zuletzt gereiht) entfaellt. PASSED.
  Status: CONFIRMED

Confirmation:
  AC: Punkt 10 / AC-4 (Issue #37), Teilfall b
  Code reference: RestockTests/ReceiptReviewCardTests.swift (temporaere Adversary-Probe, entfernt)
  Evidence: Eigens ausgefuehrte, danach zurueckgesetzte Probe (siehe Runde 2) zeigt: bei 2
    Kandidaten ohne Treffer wird aktuell:Milch eingefuegt, ohne dass ein Kandidat entfaellt
    (Ergebnis: 3 inhaltliche Kandidaten, Invariante 5 gewahrt) - entspricht exakt der in den
    Known Limitations dokumentierten Erwartung. Verhalten CONFIRMED, Testabdeckung selbst als
    F001 gemeldet.
  Status: CONFIRMED (Verhalten), siehe F001 fuer die fehlende dauerhafte Testabdeckung

Confirmation:
  AC: Punkte 1-9, 11-18 (Stichprobe, Issue #23, bereits gemergt)
  Code reference: SmartCart/Views/Prices/ReceiptReviewCard.swift:419-437
  Evidence: Der Vergleich zum vorherigen Commit zeigt, dass ausschliesslich selectionOptions(for:)
    innerhalb von ReceiptReviewCard.swift veraendert wurde (Regel 5 zwischen Regel 4 und Regel
    6/Leer-Fallback eingefuegt); ReceiptScannerView.swift (traegt save(), AC-12) wurde seit dem
    #23-Commit nicht mehr veraendert. Gesamttestlauf 165/165 gruen, inkl. aller unveraenderten
    AC1/2/3/5/6/7/8/9/10/11/12-Tests aus der #23-Suite.
  Status: CONFIRMED (unveraendert seit #23, keine Regression durch #37 festgestellt)

## VERDICT

Alle 5 Teilfaelle (a-e) des Hauptfokus AC-4/Issue #37 sind durch konkrete Testnachweise belegt -
vier durch das ausgelieferte, gruene Testfile, einer (b) durch eine selbst ausgefuehrte, danach
zurueckgesetzte Adversary-Probe, da der ausgelieferte Test Plan diesen Fall nicht abdeckt. Die
Stichprobe der Punkte 1-9/11-18 zeigt keine Beruehrung durch diesen Workflow. Ein Fund (F001,
MEDIUM, Testabdeckungsluecke, kein Verhaltensfehler) bleibt offen.

===========================================
VERDICT: VERIFIED
===========================================
Finding F001 (MEDIUM, edge_case, Testabdeckungsluecke fuer dokumentierten Randfall b) steht
offen, blockiert aber nicht: Verhalten selbst wurde durch eigene Probe als korrekt bestaetigt,
es ist keine Spec-Verletzung, sondern eine fehlende Regressionssicherung fuer einen von der Spec
selbst als "ungeloest/nicht gesondert diskutiert" deklarierten Fall.
Tests: 165 passed, 0 failed (Gesamtsuite); 21 passed, 0 failed (gezielter Rerun
  ReceiptReviewCardTests)
Edge cases: a) PROVEN, b) PROVEN via eigener Probe (Testabdeckung fehlt, siehe F001), c) PROVEN,
  d) PROVEN, e) PROVEN
Regressionen: Keine - Isolation von selectionOptions bestaetigt, ReceiptScannerView.swift/save()
  seit #23 unveraendert, AC-2/Invariante 5 (max. 3 inhaltliche Kandidaten) weiterhin gruen
Checklist: 18/18 Punkte abgedeckt (17 Confirmed direkt/durch Stichprobe, 1 Confirmed mit
  begleitendem MEDIUM-Fund zur Testabdeckung)

Empfehlung: F001 vor dem naechsten Refactoring von selectionOptions als dauerhaften Testfall
nachtragen (kleiner Zusatz, kein Blocker fuer diesen Workflow).

## Geprüfte Dateien

- sha256:5b6e045309fa541000f187c62d1fd3227b620d8b69285ff1484632dfde1b1918  RestockTests/ReceiptReviewCardTests.swift
- sha256:268ac620b0bdca87d28cf1959a6e99b8d9805be2811ff15dee9cc2f83908aa32  SmartCart/Views/Prices/ReceiptReviewCard.swift

## Geprüfte Dateien

- sha256:5b6e045309fa541000f187c62d1fd3227b620d8b69285ff1484632dfde1b1918  RestockTests/ReceiptReviewCardTests.swift
- sha256:268ac620b0bdca87d28cf1959a6e99b8d9805be2811ff15dee9cc2f83908aa32  SmartCart/Views/Prices/ReceiptReviewCard.swift
