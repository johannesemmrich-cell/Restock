# Adversary-Dialog: fix-9-rewe-quantity-weight

Spec: `docs/specs/services/receipt-parser-quantity-confirmation.md`

## Checkliste (Acceptance Criteria + Invarianten)

- [x] AC1: Rewe-Brötchen → quantity==4, weightBasis==nil, price==1.56 unverändert
- [x] AC2: Rewe-Banane → weightBasis==706, quantity==1, price==1.76 unverändert
- [x] AC3: Vollständiges Rewe-Fixture liefert weiterhin exakt 14 Positionen, übrige Preise unverändert
- [x] AC4: Lidl-Fixture → weightBasis==638; bestehende Lidl-Assertions (quantity 3/2/2, Namen, Preise) unverändert
- [x] AC5: Lidl-Fall Namenszeile ohne Preis — bestehendes Verhalten unverändert
- [x] AC6: Negativfall (Rechenprobe schlägt fehl) → genau 1 Position, quantity==1, weightBasis==nil, price==1.00
- [x] AC7: Bestätigungszeile als allererste Zeile → keine Position, kein Absturz
- [x] AC8: Preis-Lernen-Durchstich Brötchen 0,39 €/Stück, Banane 2,49 €/kg-äquivalent
- [x] INV1: Zeilenpreis der Vorzeile wird durch Bestätigungszeile nie verändert
- [x] INV2: Formaterkennung in parse() (classicCount/euroSuffixCount, Weiche) unverändert
- [x] INV3: Reine Bestätigungszeile ohne pendingName erzeugt nie eine eigene Position
- [x] INV4: Der " x "-Zweig (Lidl, pendingName != nil) ist unverändert
- [x] INV5: Vorfilter-Kommentar wurde verschoben und angepasst, nicht gelöscht

### Runde 1

Beweisforderungen 1–20 formuliert ausschließlich auf Basis der Spec (kein Produktivcode gelesen). Zusammenfassung:
- Forderungen 1–13: konkreter Test-Output plus Code-Zeilen für jedes AC/INV, inkl. Kritik an möglichen Rundungsfehlern (AC2), Force-Unwrap-Risiko (AC7) und Diff-Nachweis statt Behauptung (INV1–INV5).
- Forderungen 14–20: sieben scharfe Zusatzproben außerhalb der Spec — Toleranzgrenze exakt 0,01/0,011, zwei Bestätigungszeilen hintereinander, Einheit "g" statt "kg", Bestätigungszeile nach Pfandzeile, negative Menge/Storno-Interaktion, Bestätigungszeile in Lidl-Mehrfachkauf-Kontext, Euro-Suffix/Carrefour-Bon mit angehängter Bestätigungszeile.

Details: siehe die an den Developer Agent übergebenen Beweisforderungen 1–20 (wortgleich, vorherige Dialog-Runde).

### Runde 2

Beweis-Artefakt: `docs/artifacts/fix-9-rewe-quantity-weight/adversary-probes-output.txt` (realer Testlauf, 47 Tests inkl. 9 temporärer Adversary-Probe-Tests, 0 Fehler). Zusätzlich eigener unabhängiger Nachlauf (38 Basis-Tests, Probe-Code war zu diesem Zeitpunkt bereits entfernt, Arbeitsverzeichnis zeigt nur die modifizierte Produktivdatei als Änderung):

```
Test Suite 'RestockTests.xctest' passed at 2026-09-21 21:40:19.517.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.135 (0.163) seconds
Test Suite 'Selected tests' passed at 2026-09-21 21:40:19.518.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.135 (0.164) seconds
** TEST SUCCEEDED **
```

Deckt sich mit `docs/artifacts/fix-9-rewe-quantity-weight/test-green-output.txt` (ebenfalls 38/0).

### Forderung → Beweis → Bewertung (1–13)

1. **AC1** — Forderung: Test-Output + Code-Zeile `quantity = wr.weight`.
   Beweis: `RestockTests/ReceiptParserReweTests.swift:79-81` (`XCTAssertEqual(broetchen.quantity, 4, …)`, `XCTAssertNil(broetchen.weightBasis)`), selbst gelesen. Code `SmartCart/Services/ReceiptParserService.swift:380-381`: `else if wr.unit == "stk" { results[results.count - 1].quantity = wr.weight }`, selbst gelesen. Test lief im eigenen Lauf grün.
   Bewertung: **AKZEPTIERT**.

2. **AC2** — Forderung: Assertion + Rundungsbeweis für `0.706*1000`.
   Beweis: `ReweTests.swift:84-86`. Code `:378-379` `weightBasis = wr.weight * 1000`. Probe-Ausgabe (Artefakt Z.146-150): `0.706*1000 == 706 exactly? true`, Rechenprobe-Diff `0.00206`. Selbst nachvollzogen — 0,706 lässt sich als Double nicht exakt darstellen, aber `0.706*1000` rundet in der Praxis exakt auf 706.0 (durch Testlauf verifiziert, nicht nur behauptet).
   Bewertung: **AKZEPTIERT**.

3. **AC3** — Forderung: vollständige Namens-/Preisliste, nicht nur Zähler.
   Beweis: Artefakt Z.157-173 druckt alle 14 Namen mit Preisen; nur Laugenbroetchen hat quantity=4, nur Banane weightBasis=706, alle anderen Default (qty=1, weightBasis=nil), Preise stimmen mit dem Fixture überein. Zusätzlich `testItemNamesAndPricesAreCorrect` selbst gelesen — Preis-Assertions passen.
   Bewertung: **AKZEPTIERT**.

4. **AC4** — Forderung: Assertion-Beleg + Bestätigung, dass bestehende Lidl-Assertions in derselben Testmethode weiter grün sind.
   Beweis: `ReceiptParserLidlFullReceiptTests.swift:190-202` (`testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext`, unverändert, quantity 3/2/2 grün) UND separate neue Methode `testWeightConfirmationLineAttachesGramBasisToBanana` (:208-215, `weightBasis==638`, `price==0.82`, `quantity==1`), beide selbst gelesen und im eigenen Testlauf grün.
   Befund A (Abweichung von Scope-Tabelle "Assertion erweitert" → tatsächlich neue Methode): siehe Findings-Block. Inhaltlich vollständig bewiesen, formale Abweichung dokumentiert, kein Blocker.
   Bewertung: **AKZEPTIERT** (mit dokumentierter Abweichung, s. Befund A).

5. **AC5** — Forderung: Diff-Beweis, dass Bestandstests unverändert sind (nicht nur "noch grün").
   Beweis: Diff von `RestockTests/ReceiptParserPriceTests.swift` zeigt genau einen Hunk mit reiner Insertion (nur neue Zeilen, keine Änderung an bestehenden). Blame der bestehenden Testmethoden zeigt ausschließlich den Ursprungscommit vom 2026-08-26, keine Änderung durch diesen Fix. Selbst ausgeführt und geprüft.
   Bewertung: **AKZEPTIERT**.

6. **AC6** — Forderung: Code-Pfad, der beweist, dass `continue` VOR dem `" x "`-Zweig sitzt (kein Durchfallen).
   Beweis: `ReceiptParserService.swift:374-385` selbst gelesen — Bedingung `:374-375`, Rechenprobe `:377` (`abs(wr.weight * wr.rate - last.price) <= 0.01`), `continue` unbedingt bei `:384` (außerhalb des inneren `if let`, laut Einrückung), `" x "`-Zweig beginnt danach bei `:396`. Test `testBareConfirmationLineWithFailedSanityCheckIsConsumedNotAttributed` selbst gelesen, grün.
   Bewertung: **AKZEPTIERT**.

7. **AC7** — Forderung: Guard-Code zeigen, kein Force-Unwrap.
   Beweis: `:376` `if let last = results.last, let wr = weightTimesRate(in: trimmed)` — selbst gelesen, kein Force-Unwrap. Test `testBareConfirmationLineAsFirstLineDoesNotCrash` selbst gelesen, grün.
   Bewertung: **AKZEPTIERT**.

8. **AC8** — Forderung: exakte Zahlenwerte + Formel in `ReceiptScannerView`.
   Beweis: `PriceTests.swift:326-354` (`testLearnedPriceRoundTripForReweBroetchenAndBanane`), selbst gelesen — Brötchen `0.39` (accuracy 0.001), Banane über `estimatedLineTotal` für 1000g `2.49` (accuracy 0.01). Formel `ReceiptScannerView.swift:58-60` (`learningQuantity`) und `:611-613` (`perUnitPrice = quantity > 0 ? line.price / quantity : line.price`) selbst gelesen, beide Codepfade stimmen mit der Testkette überein.
   Bewertung: **AKZEPTIERT**.

9. **INV1** — Forderung: vollständiger Diff des neuen Zweigs, kein `.price =`.
   Beweis: vollständiger Diff der Produktivdatei selbst gelesen — der neue Hunk (`:354-386`) enthält keine Zuweisung an `.price`; die einzigen `.price`-Zuweisungen der Datei sind die unveränderte Pfandzeile (`:468`, Addition) und der unveränderte Euro-Pfad. Bestätigt per Diff, nicht nur Textsuche.
   Bewertung: **AKZEPTIERT**.

10. **INV2** — Forderung: Diff um die classicCount/euroSuffixCount-Zeilen muss 0 Zeilen zeigen.
    Beweis: selbst gelesen, `parse()` (`:176-190`) — `euroSuffixCount`/`classicCount`-Ermittlung und die Weiche sind identisch zum Stand vor dem Fix; einzige Änderung in `parse()` ist die entfernte Vorfilter-Anwendung in der `lines`-Zuweisungszeile (jetzt ohne zusätzlichen Vorfilter-Aufruf). Praxisprobe 20 (Carrefour-Konstrukt) selbst im Artefakt nachvollzogen: die Formaterkennung matcht auf Bestätigungszeilen nicht (kein Preis-Suffix am Zeilenende bzw. keine passende Endung) — Ergebnis-Anzahl bleibt in allen vier Sub-Proben unverändert bei 2.
    Bewertung: **AKZEPTIERT**.

11. **INV3** — Forderung: `continue` unabhängig vom Rechenprobe-Ausgang zeigen.
    Beweis: wie Punkt 6 — `continue` bei `:384` liegt außerhalb des `if let`-Blocks für die Rechenprobe, wird also in jedem Fall erreicht, sobald die äußere Bedingung (`:374-375`) zutrifft. Durch AC6 (Rechenprobe schlägt fehl → trotzdem nur 1 Position) UND AC1/AC2 (Rechenprobe erfolgreich → auch nur 1 Position) doppelt bewiesen.
    Bewertung: **AKZEPTIERT** — mit Verweis auf Befund C (Storno-Interaktion, s. u.): Der Schutz gilt nur, wenn der neue Zweig überhaupt erreicht wird (Bedingung verlangt kein aktives Storno-Flag); bei aktivem Storno-Flag greift stattdessen der unveränderte `" x "`-Zweig, der unter bestimmten Bedingungen weiterhin eine Phantom-Position erzeugen kann — das ist aber vorbestehendes, durch diesen Fix nicht verändertes Verhalten (s. Befund C), keine Verletzung von INV3 selbst, die sich explizit auf "diesen Fix" bezieht.

12. **INV4** — Forderung: 0-Zeilen-Diff für den `" x "`-Zweig.
    Beweis: dritter Diff-Hunk selbst gelesen, endet mit reinem Kontext (Kommentarzeilen des `" x "`-Zweigs) — keine Änderung innerhalb des Zweigs selbst.
    Bewertung: **AKZEPTIERT**.

13. **INV5** — Forderung: Text-Vergleich alt/neu.
    Beweis: selbst im Diff gelesen — alter Kommentar (gelöschter Hunk, Titel "Vorfilterung"/"droppen") vs. neuer Kommentar ("Nur hier greifen, wenn KEIN Name/Preis mehr offen", neuer Absatz zu Konsum/Rechenprobe/Toleranz/unangetastetem Preis) — inhaltlich verschoben und an den neuen Mechanismus angepasst, nicht ersatzlos gelöscht.
    Bewertung: **AKZEPTIERT**.

## Findings (Befunde A–D)

```json
{
  "findings": [
    {
      "id": "F-A",
      "severity": "LOW",
      "category": "spec_violation",
      "code_reference": "RestockTests/ReceiptParserLidlFullReceiptTests.swift:208-215",
      "description": "AC4-Assertion (banane.weightBasis == 638) steht in einer eigenen neuen Testmethode testWeightConfirmationLineAttachesGramBasisToBanana statt, wie die Scope-Tabelle der Spec vorsieht, als Erweiterung von testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext.",
      "spec_requirement": "Scope-Tabelle: testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext um Assertion banane.weightBasis == 638 erweitert",
      "conflict": "Formale Abweichung von der geplanten Testorganisation; inhaltlich ist die Assertion vorhanden und beweist AC4 vollstaendig, nur strukturell an anderer Stelle.",
      "remediation": "Kein Handlungsbedarf fuer dieses Ticket. Falls gewuenscht: Assertion in bestehende Methode verschieben.",
      "blocking": false
    },
    {
      "id": "F-B",
      "severity": "LOW",
      "category": "edge_case",
      "code_reference": "SmartCart/Services/ReceiptParserService.swift:377",
      "description": "Fliesskomma-Vergleich abs(wr.weight * wr.rate - last.price) <= 0.01 ist an der Grenze richtungsabhaengig: Bei einer Differenz von exakt 1 Cent, die in Double auf 0.010000000000000009 statt 0.01 rundet, schlaegt <= 0.01 fehl, obwohl die dezimale Differenz exakt der Toleranzgrenze entspricht. In Gegenrichtung wird dieselbe nominelle 1-Cent-Differenz akzeptiert.",
      "spec_requirement": "Risiken-Abschnitt: Toleranz 0,01 ist der belegte, knappste noch ausreichende Wert.",
      "conflict": "Kein AC verlangt exakt die 0,01-Grenze; die beiden realen Faelle (AC2 Diff 0,00206, AC6 Diff 0,50) sind von der Asymmetrie nicht betroffen. Auswirkung im ungnstigen Fall ist ausschliesslich nicht zugeschrieben, kein Crash, keine Fehlzuordnung.",
      "remediation": "Optional: Toleranzvergleich mit kleinem Epsilon-Puffer robuster machen. Kein Blocker.",
      "blocking": false
    },
    {
      "id": "F-C",
      "severity": "MEDIUM",
      "category": "edge_case",
      "code_reference": "SmartCart/Services/ReceiptParserService.swift:396,535-541",
      "description": "Enthaelt eine Bestaetigungszeile die Zeichenfolge x UND wurde die Vorzeile per STORNO als zu stornierend markiert, greift der neue Schutz-Zweig nicht, die Zeile faellt in den unveraenderten x-Zweig, der die Storno-Pruefung nie erreicht, weil diese erst spaeter im Namenspreis-Pfad liegt. Ergebnis laut Beweisartefakt: Eingabe mit GOUDA, LAUGENBROETCHEN, STORNO, dann einer negativen Stueckzahl-Bestaetigungszeile erzeugt 3 Positionen inklusive einer Phantom-Position mit Name gleich dem Zeilentext, price=1.56, quantity=4.",
      "spec_requirement": "Kein AC/INV dieser Spec adressiert die Interaktion von STORNO-Zeilen mit Bestaetigungszeilen explizit; INV3 bezieht sich nur auf diesen Fix.",
      "conflict": "Bug-Verhalten praeexistent: Der Erkenner fuer vollstaendige Positions-Kandidaten matcht auf das Wort STORNO nicht, daher haette der alte, jetzt entfernte Vorfilter diese Zeile ebenfalls nicht entfernt, dieselbe Zeile waere auch vor dem Fix unveraendert in denselben unveraenderten Zweig gelaufen (laut INV4 0 Diff-Zeilen) und haette denselben Phantom erzeugt. Verifiziert durch Code-Lesen, nicht nur behauptet.",
      "remediation": "Eigenes Issue: Storno-Erkennung muss auch fuer Zeilen greifen, die vorher in diesen Zweig laufen.",
      "blocking": false
    },
    {
      "id": "F-D",
      "severity": "LOW",
      "category": "edge_case",
      "code_reference": "SmartCart/Services/ReceiptParserService.swift:374-385,432-446",
      "description": "Konstruierter Fall: Eine Zeile im Lidl-Mehrfachkauf-Format (setzt quantity ueber den bestehenden priceTimesCount-Pfad) gefolgt von einer weiteren bare-Bestaetigungszeile, deren Rechenprobe knapp innerhalb der Toleranz liegt, ueberschreibt die zuvor korrekt gesetzte quantity mit einem abweichenden Wert.",
      "spec_requirement": "Keine Spec-Anforderung deckt diesen Fall ab (kein bekanntes Bon-Format druckt beide Zeilenarten fuer dieselbe Position).",
      "conflict": "Rein theoretisch, kein reales Fixture oder AC betroffen.",
      "remediation": "Dokumentieren, kein Fix noetig ohne konkreten Bon-Beleg.",
      "blocking": false
    }
  ]
}
```

### Confirmations (AC1-AC8, INV1-INV5)

Alle 13 Punkte sind oben unter "Forderung → Beweis → Bewertung" als AKZEPTIERT mit Code-/Test-Referenz belegt — siehe dort für die jeweilige Evidenz. Kein Punkt ist unbelegt geblieben.

## Verdict

Alle 13 Checklistenpunkte (AC1-AC8, INV1-INV5) sind durch selbst gelesenen Code, selbst gelesene Tests und einen selbst ausgeführten, unabhängigen grünen Testlauf (38/0) belegt. Die vier Befunde A-D sind entweder rein formal (A), eine dokumentierte Fließkomma-Randbedingung ohne AC-Bezug (B), nachweislich vorbestehendes Verhalten außerhalb des Fix-Scopes (C), oder ein rein theoretischer, unbelegter Fall (D) — keiner davon ist eine Regression, die durch diesen Fix eingeführt wurde, und keiner verletzt ein AC oder eine Invariante dieser Spec. Alle vier werden als Folge-Empfehlung dokumentiert, nicht als Blocker gewertet.

## Verdict
**VERIFIED**
