# Adversary Dialog — feat-13-preismodell-stufen (Issue #13)

Spec geprueft: docs/specs/models/price-estimator-stages.md
Arbeitsverzeichnis: /Users/hem/Developer/Restock/.claude/worktrees/streamed-enchanting-chipmunk
Rolle: Adversary Validation Agent — Ziel: Beweisen, dass die Implementierung/Dokumentation NICHT haelt.

## Ausgangsthese (zu widerlegen)

Die Spec behauptet: reine Dokumentation + neue Charakterisierungstests, KEIN Produktivcode
geaendert, die zuvor geplante Veraltungsregel wurde vollstaendig gestrichen (nach #49 verschoben),
keine Verhaltensaenderung.

---

### Runde 1 — Grundpruefung

### Frage 1: Wurde wirklich kein Produktivcode geaendert?

Nicht der Behauptung im Commit-Text geglaubt — nachgerechnet (Befehle real per Bash-Tool
ausgefuehrt; Praefix hier bewusst neutral formuliert):

  show --stat e3c1565   (test: Charakterisierungstests ...)
   Restock.xcodeproj/project.pbxproj                  |   4 +
   RestockTests/PriceEstimatorStagesTests.swift       |  48 +++++
   docs/artifacts/.../test-run-01.txt                 | 226 +++++++++++++++++++++
   docs/briefings/feat-13-preismodell-stufen.md       |  32 +++
   docs/context/feat-13-preismodell-stufen.md         | 125 ++++++++++++
   docs/specs/models/price-estimator-stages.md        | 162 +++++++++++++++
   6 files changed, 597 insertions(+)

  show --stat fc197fa   (docs: Testnamen-Platzhalter zuruecksetzen)
   docs/specs/models/price-estimator-stages.md | 6 +++---
   1 file changed, 3 insertions(+), 3 deletions(-)

  show e3c1565 -- SmartCart/Models/ShoppingItem.swift   -> leer
  show fc197fa -- SmartCart/Models/ShoppingItem.swift   -> leer
  diff 9b59d15..HEAD -- SmartCart/Models/ShoppingItem.swift   -> leer

Der einzige Nicht-Doku/Test-Diff ist der project.pbxproj-Eintrag, und der beschraenkt sich
mechanisch auf die drei/vier Registrierungsstellen der neuen Testdatei (BuildFile, FileReference,
Group, SourcesBuildPhase) — keine Produktivcode-Referenz enthalten. Bestaetigt: kein
Produktivcode geaendert.

Gegenprobe: Reicht "seit dem letzten Feature-Commit" (9b59d15) als Vergleichsbasis? Ja —
9b59d15 ("Kategorie-Pauschalpreise ... #12 #47") ist der letzte Commit vor den beiden #13-Commits
auf diesem Branch, und der Diff ueber beide hinweg ist identisch mit der Summe der beiden
Einzel-Commit-Diffs (keine dazwischenliegenden Fremd-Commits).

### Frage 2: Ist die gestrichene Veraltungsregel wirklich sauber entfernt — kein Rest-Code?

  grep -rniE "veralt|stale|180.?day|180.?tag" SmartCart/ RestockTests/

Treffer: ausschliesslich unabhaengige, bereits vor #13 existierende Kommentare zu anderen
Stale-Themen (SharedModelContainer-Fallback, Live-Activity staleDate, Bon-Scanner-UI,
Menueplan-Mengen, EditItemView-Kategorie-Legacy usw.) — keiner davon bezieht sich auf gelernte
Preise oder ein 180-Tage-Fenster. Zusaetzlich geprueft: vollstaendige Historie (alle Branches)
fuer ShoppingItem.swift. Kein Commit zwischen dem letzten Preis-Feature (9b59d15) und HEAD, der
ShoppingItem.swift anfasst. Die Veraltungsregel wurde also nie ins Produktivcode-File
geschrieben (nur in einer inzwischen verworfenen ersten Spec-Fassung geplant) — es gibt nichts
zurueckzunehmen, weil nie etwas committet wurde. Sauber.

### Frage 3: Stimmen die in den Tests hart codierten Preis-Konstanten mit dem echten Code ueberein (kein "Test luegt sich gruen")?

  grep -n milch SmartCart/Models/ShoppingItem.swift
  253:  (["milch", "milk"], 1.20),
  grep -n Milchprodukte SmartCart/Models/ShoppingItem.swift
  305:  case "Milchprodukte": perUnit = 2.00 / divisor

Test erwartet 1.50 (gelernt), 1.20 (Keyword), 2.00 (Kategorie) — deckt sich exakt mit dem
gelesenen Produktivcode (SmartCart/Models/ShoppingItem.swift:253,305). Keine Diskrepanz.

### Frage 4: Laufen die Tests wirklich (kein Nullstand, kein Abbruch)?

Testlauf (echtes dediziertes Restock-Validate-Geraet, UDID 8F696920-...), gespeichert unter
docs/artifacts/feat-13-preismodell-stufen/adversary-test-run.txt:

  Test Suite 'PriceEstimatorStagesTests' passed — Executed 3 tests, 0 failures
  Test Suite 'PriceProvenanceMigrationTests' passed — Executed 7 tests, 0 failures
  Test Suite 'PriceEstimatorCategoryFallbackTests' passed — Executed 8 tests, 0 failures
  Test Suite 'ReceiptParserPriceTests' passed — Executed 19 tests, 0 failures
  Test Suite 'RestockTests.xctest' passed — Executed 37 tests, with 0 failures (0 unexpected)
  TEST SUCCEEDED

3+7+8+19 = 37 — Summe stimmt, kein stiller Teilausfall, kein "Executed 0 tests"-Fehlalarm (siehe
Memory-Eintrag "Null-Test-Lauf ist kein Gruen").

### Zwischenstand nach Runde 1

Alle vier Fragen halten der ersten Pruefung stand. Bewusst nicht konvergiert — Runde 2 geht
gezielt auf Kanten, die eine oberflaechliche erste Runde uebersieht.

---

### Runde 2 — Kantenfaelle und tiefere Pruefung

### Probe 1: Testet AC-1 wirklich "fuzzy"-Matching, oder nur exakte Gleichheit?

Die Spec fordert fuer AC-1 einen "fuzzy zum Artikelnamen passenden Eintrag". Der Test setzt
store.learnedPrices["milch"] = 1.50 bei Artikelname "Milch" — nach Lowercasing exakt
"milch" == "milch". Das ist kein echter Teilstring-Fuzzy-Fall (anders als das im Code
dokumentierte Beispiel "Hackfleisch" versus "Hackfleisch Gemischt 500g").

Bewertung: Kein eigenstaendiger Fund, weil (a) exakte Gleichheit eine gueltige Teilmenge von
"fuzzy" ist (key.contains(itemLower) || itemLower.contains(key), ShoppingItem.swift:129-132,
mit Gleichheit trivial erfuellt), (b) der eigentliche Zweck von AC-1 die Rangfolge Stufe 1 vor
Stufe 2 ist, nicht der Fuzzy-Mechanismus selbst, und (c) der echte Teilstring-Fuzzy-Fall bereits
in PriceProvenanceMigrationTests.testShoppingItemPicksDeterministicWinnerWhenMultipleLearnedPricesMatchWithoutDates
abgedeckt ist — von der Spec selbst explizit als "bereits abgedeckt" referenziert (Test Plan,
Zeile 141-142) und im selben Testlauf gruen bestaetigt. Keine Deckungsluecke.

### Probe 2: Kollidiert der AC-3-Testname "artikel ohne keyword-treffer" versehentlich mit einem der 32 Produkt-Keywords?

Alle 32 specificPrices-Eintraege gelesen (ShoppingItem.swift:251-284). Manuell gegen den
String "artikel ohne keyword-treffer" geprueft — kein Teilstring-Treffer (u.a. kein "reis",
"tee", "ei", "eis" enthalten). Empirisch bestaetigt statt nur behauptet: der Test lief mit
exaktem XCTAssertEqual(item.estimatedPrice, 2.00, ...) gruen — haette ein Keyword versehentlich
getroffen, waere der Preis nicht 2.00 gewesen (kein Keyword-Preis in der Liste ist zufaellig
2.00 / divisor("") fuer "Milchprodukte", da "milch"/"milk" selbst geprueft und mit 1.20 belegt
ist). Kein Fund.

### Probe 3: Plausibilitaets-Schranke (maxPlausibleLearnedLineTotal = 200 EUR) — reisst sie den AC-1-Test?

ShoppingItem.swift:153: gelernter Preis wird verworfen, wenn learnedPrice * quantityAmount groesser
als 200 ist. AC-1-Test nutzt quantityAmount implizit als Default 1 (Init-Default,
ShoppingItem.swift:94) und 1.50 * 1 = 1.50, das liegt weit unter der Schranke, keine Kollision.
Kein Fund, aber eine in der Spec nicht erwaehnte Nebenbedingung (maxPlausibleLearnedLineTotal)
existiert im Code und beeinflusst theoretisch, wann Stufe 1 ueberhaupt greift. Das ist jedoch
bereits vollstaendig durch PriceProvenanceMigrationTests abgedeckt (separate Spec/Ticket, nicht
Gegenstand von #13) und von der hier geprueften Spec korrekt als "unveraendert, ausserhalb des
Scopes" behandelt (Dependencies-Tabelle nennt nur learnedPrices/learnedPriceDates als Referenz,
nicht diese Konstante) — kein Widerspruch, da #13 nur die Rangfolge dokumentiert, nicht jede
Nebenbedingung von Stufe 1.

### Probe 4: Ist die Streichung der Veraltungsregel durch eine nachvollziehbare PO-Entscheidung gedeckt, oder nur behauptet?

docs/context/feat-13-preismodell-stufen.md Zeile 86-96 dokumentiert den PO-Einwand vom
2026-09-25 und die Entscheidung, die Regel nach #49 zu verschieben. Gegengeprueft gegen GitHub:

  issue view 49 --json number,title,state
  Ergebnis: number 49, state OPEN, title "Open Prices als vierte Preisstufe (Community-Preise beim Barcode-Scan)"
  issue view 13 --json number,title,state
  Ergebnis: number 13, state OPEN, title "Open Prices beim Barcode-Scan mitabfragen — echte beobachtete Preise statt Konstanten"

Issue #49 existiert real und passt inhaltlich zur behaupteten Verschiebung. Kein Fund.

### Probe 5: Stimmen die in der Spec zitierten Codezeilen (EditItemView.swift:375,384) tatsaechlich?

Datei gelesen: Zeile 375 "item.estimatedPrice = PriceEstimator.estimate(...)" (rawPrice leer,
Neuschaetzung) und Zeile 384 dieselbe Aufrufstelle im Unit-Wechsel-Zweig — beide Fundstellen
bestaetigt, beide durchlaufen tatsaechlich nie Stufe 1 (direkter PriceEstimator.estimate-Aufruf,
kein store.learnedPrices-Zugriff). Spec-Aussage korrekt.

### Probe 6: DoD-/Approval-Checkboxen in der Spec sind alle unangehakt (Approved, alle drei DoD-Punkte) — Widerspruch zu "fertig"?

Geprueft, ob das ein Blocker ist: Die Checkboxen sind Workflow-Artefakte, die laut Projekt-Historie
(siehe docs/context/... und die Commit-Abfolge) erst nach erfolgreicher Validierung
(Validate-Phase bzw. Adversary-Phase) durch den Workflow selbst gesetzt werden, nicht vom Autor der
Spec vorab. Kein Code- oder Testbefund, sondern reiner Prozessstatus ausserhalb des Pruefauftrags
dieses Agents (Pruefauftrag: Spec-Inhalt gegen Code/Tests, nicht Workflow-Metazustand). Keine
Einstufung als Finding — als Beobachtung vermerkt, nicht als Mangel gewertet.

---

## Strukturierte Confirmations (jede AC einzeln belegt)

Confirmation:
  AC: AC-1 (Stufe 1 schlaegt Stufe 2)
  Code reference: RestockTests/PriceEstimatorStagesTests.swift:16-26
  Code reference: SmartCart/Models/ShoppingItem.swift:127-155
  Evidence: testLearnedPriceTakesPriorityOverProductKeywordAndCategory — Store mit
    learnedPrices["milch"]=1.50, Artikel "Milch"/Kategorie "Milchprodukte" (traefe Keyword 1.20 UND
    Kategorie 2.00). Test-Output: passed (0.003s), estimatedPrice==1.50,
    estimatedPriceIsAutoDerived==false.
  Status: CONFIRMED

Confirmation:
  AC: AC-2 (Stufe 2 schlaegt Stufe 3)
  Code reference: RestockTests/PriceEstimatorStagesTests.swift:30-36
  Code reference: SmartCart/Models/ShoppingItem.swift:247-294
  Evidence: testProductKeywordTakesPriorityOverCategoryFallback — kein Store, Artikel "Milch"/
    Kategorie "Milchprodukte" (Keyword 1.20 vs. Kategorie 2.00). Test-Output: passed (0.000s),
    estimatedPrice==1.20, estimatedPriceIsAutoDerived==true.
  Status: CONFIRMED

Confirmation:
  AC: AC-3 (Stufe 3 greift ohne Stufe 1/2)
  Code reference: RestockTests/PriceEstimatorStagesTests.swift:40-47
  Code reference: SmartCart/Models/ShoppingItem.swift:296-330
  Evidence: testCategoryFallbackUsedWhenNoLearnedPriceAndNoKeywordMatch — kein Store, Artikelname
    ohne Keyword-Treffer, Kategorie "Milchprodukte". Test-Output: passed (0.002s),
    estimatedPrice==2.00, estimatedPriceIsAutoDerived==true.
  Status: CONFIRMED

Confirmation:
  AC: Input/Output/Side-effects unveraendert
  Code reference: SmartCart/Models/ShoppingItem.swift:90-156
  Evidence: Diff ueber beide #13-Commits (e3c1565 und fc197fa) zeigt ShoppingItem.swift mit 0
    Aenderungen; init-Signatur (Zeile 90-98) identisch zur Spec-Behauptung (name, category,
    quantityAmount, unit, store optional). Output-Felder estimatedPrice/estimatedPriceIsAutoDerived
    unveraendert (Zeile 154-155).
  Status: CONFIRMED

Confirmation:
  AC: Veraltungsregel sauber entfernt (kein Rest-Code)
  Code reference: SmartCart/Models/ShoppingItem.swift (kein Treffer)
  Evidence: grep ueber SmartCart/ und RestockTests/ nach veralt/stale/180 liefert ausschliesslich
    themenfremde, vorbestehende Treffer; vollstaendige Historie zeigt keinen Commit zwischen
    9b59d15 und HEAD, der ShoppingItem.swift anfasst — die Regel wurde nie ins Produktivcode-File
    geschrieben.
  Status: CONFIRMED

## Findings

Keine. Jeder geprueft Punkt haelt der adversen Pruefung stand; alle sechs vertieften Kantenfaelle aus
Runde 2 (Fuzzy-Anspruch, Keyword-Kollision, Plausibilitaets-Schranke, PO-Entscheidungs-Nachweis,
Zeilenreferenzen, DoD-Checkboxen) ergaben keinen Widerspruch zur Spec oder zum Code.

## Testnachweis

Vollstaendiger Output: docs/artifacts/feat-13-preismodell-stufen/adversary-test-run.txt
(Geraet: dediziertes Restock-Validate-Simulator, UDID 8F696920-4B9A-40A7-96F0-7697BE887CC7)

  Test Suite 'RestockTests.xctest' passed at 2026-09-25 14:45:08.626.
  Executed 37 tests, with 0 failures (0 unexpected) in 0.058 (0.078) seconds
  TEST SUCCEEDED

---

## VERDICT

===========================================
VERDICT: VERIFIED
===========================================
Tests: 37 passed, 0 failed (PriceEstimatorStagesTests 3/3, PriceProvenanceMigrationTests 7/7,
PriceEstimatorCategoryFallbackTests 8/8, ReceiptParserPriceTests 19/19)
Edge cases: 6 vertieft geprueft (fuzzy-Anspruch von AC-1, Keyword-Kollision im AC-3-Testnamen,
Plausibilitaets-Schranke, PO-Entscheidungs-Nachweis via GitHub, Codezeilen-Referenzen,
DoD-Checkbox-Status) — keine davon bricht die Implementierung/Dokumentation.
Regressionen: Keine — Diff ueber beide #13-Commits zeigt SmartCart/Models/ShoppingItem.swift mit
0 Aenderungen; einziger Nicht-Doku/Test-Diff ist die mechanische Testdatei-Registrierung in
project.pbxproj.
Checkliste: 7/7 Punkte bewiesen (Input, Output, Side effects, Rangfolge, AC-1, AC-2, AC-3) plus
2 zusaetzliche DoD-Punkte (kein Produktivcode geaendert, Veraltungsregel sauber entfernt).

## Geprüfte Dateien

- sha256:08deea362c29a131001ff94a80a8e32a8b42f91191e58cd969de058f9240758e  RestockTests/PriceEstimatorStagesTests.swift
- sha256:a03ee96239ce929ddf3ca471616566adba9cfb8b5dea00ffb8fa8e020e150b28  SmartCart/Models/ShoppingItem.swift

## Geprüfte Dateien

- sha256:08deea362c29a131001ff94a80a8e32a8b42f91191e58cd969de058f9240758e  RestockTests/PriceEstimatorStagesTests.swift
- sha256:a03ee96239ce929ddf3ca471616566adba9cfb8b5dea00ffb8fa8e020e150b28  SmartCart/Models/ShoppingItem.swift
