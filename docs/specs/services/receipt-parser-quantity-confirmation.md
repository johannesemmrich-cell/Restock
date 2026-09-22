---
entity_id: receipt-parser-quantity-confirmation
type: bugfix
created: 2026-09-21
updated: 2026-09-22
status: implemented
workflow: fix-9-rewe-quantity-weight
tags: [bugfix, receipt-parser, price-learning]
---

# Bon-Parser wertet Mengen-/Gewichts-Bestätigungszeilen aus

## Approval

- [x] Approved

## Purpose

`ReceiptParserService.parse` verwirft heute bei Bon-Formaten, die den Gesamtpreis bereits auf der
Namenszeile drucken (Rewe-eBon), die direkt darunterstehende Mengen-/Gewichts-Bestätigungszeile
("4 Stk x 0,39", "0,706 kg x 2,49 EUR/kg") komplett, statt sie auszuwerten. Dadurch bleiben
`ReceiptLine.quantity` und `ReceiptLine.weightBasis` bei diesen Positionen auf dem Default (1 /
`nil`), obwohl Stückzahl bzw. Gewicht auf dem Bon eindeutig stehen — beim Lernen des Preises
(`ReceiptScannerView.save()`) wird deshalb der volle Zeilen-Gesamtpreis fälschlich als Stück-
bzw. Gramm-Preis übernommen (z. B. 1,56 € statt 0,39 € pro Brötchen). Dieser Fix wertet die
Bestätigungszeile aus und schreibt Stückzahl/Gewicht der vorangehenden Position zu, ohne deren
bereits korrekten Zeilenpreis zu verändern und ohne eine Phantom-Position zu erzeugen.

## Source

- **File:** `SmartCart/Services/ReceiptParserService.swift`
- **Identifier:** `static func parseClassic(_ lines: [String]) -> [ReceiptLine]` (neuer Zweig),
  `private static func droppingRedundantQuantityConfirmationLines` (entfällt)

## Problem und belegte Ursache

**Root Cause:** `droppingRedundantQuantityConfirmationLines` (`ReceiptParserService.swift:189-200`),
aufgerufen aus `parse()` (`ReceiptParserService.swift:211`), löscht jede Zeile, die
`isBareQuantityOrWeightConfirmationLine` (`ReceiptParserService.swift:202-208`) erkennt, aus dem
Zeilenstrom, sobald die VORHERIGE Zeile bereits ein vollständiger Positions-Kandidat mit eigenem
Preis war (`isClassicVatItemCandidateLoose`, `ReceiptParserService.swift:183-187`). Die Zeile
erreicht `parseClassic` damit nie — Stückzahl/Gewicht gehen ersatzlos verloren.

**Reproduktion (2026-09-21, gegen das bestehende Rewe-Fixture in
`RestockTests/ReceiptParserReweTests.swift`):**
- Ist-Zustand: `ReceiptParserService.parse(reweLines)` liefert für die Brötchen-Position
  `price=1.56 quantity=1.0 weightBasis=nil` und für die Bananen-Position
  `price=1.76 quantity=1.0 weightBasis=nil` — beide Male fehlt exakt die Information aus der
  gelöschten Zeile.
- Wird der Vorfilter probeweise abgeschaltet, entstehen 15 statt 14 Positionen: Der `" x "`-Zweig
  in `parseClassic` (`ReceiptParserService.swift:397-458`) läuft dann mit `pendingName == nil`
  (die Vorzeile wurde bereits als eigene Position angehängt, `ReceiptParserService.swift:547`).
  `nameChunkBeforeWeightDetail` strippt über `strayBulletPrefixRegex` (`^\S\s+(?=[A-Za-z])`) die
  führende "4 " als vermeintliches Aufzählungszeichen, übrig bleibt der Name `"Stk x 0,39"` mit
  Preis 1,56 und `quantity 4` als Phantom-Position. Die Bananen-Zeile ("0,706 …", führende Ziffer
  bleibt erhalten) wird in diesem deaktivierten Zustand dagegen stumm verworfen — die Banane bleibt
  ohne `weightBasis`.
- `weightTimesRate(in:)` (`ReceiptParserService.swift:912-923`) liefert für beide Zeilen bereits
  korrekt verwertbare Werte: `(4, "stk", 0.39)` bzw. `(0.706, "kg", 2.49)`.
- **Zusatzbefund (verifiziert):** Dasselbe Muster steckt im Lidl-Fixture
  (`RestockTests/ReceiptParserLidlFullReceiptTests.swift:29-30`, `"Banane lose  0,82 A"` +
  `"0,638 kg x 1,29  EUR/kg"`) — auch dort verliert die Banane heute ihr Gewicht, ungeprüft von
  keinem bestehenden Test.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `weightTimesRate(in:)` (`ReceiptParserService.swift:912-923`) | function | Liefert `(weight, unit, rate)` aus der Bestätigungszeile — Baustein der Auswertung, unverändert. |
| `isBareQuantityOrWeightConfirmationLine` (`ReceiptParserService.swift:202-208`) | function | Bisher Vorfilter-Erkenner, wird zum Erkenner des neuen Zweigs in `parseClassic`; Regex unverändert. |
| `EditableReceiptLine.learningQuantity` (`SmartCart/Views/Prices/ReceiptScannerView.swift:58-60`) | downstream consumer | Liest `weightBasis`/`quantity` in der Reihenfolge `weightBasis ?? quantity>1 ?? match ?? Name ?? 1` — profitiert unverändert, sobald die Werte ankommen. |
| `ReceiptScannerView.save()` (`SmartCart/Views/Prices/ReceiptScannerView.swift:611-613`) | downstream consumer | `perUnitPrice = price / learningQuantity` → `store.learnedPrices` — hier entsteht der aktuell falsch gelernte Preis. |
| `SyncCoordinator` | downstream consumer | Verteilt `store.learnedPrices` an geteilte Listen; nimmt künftig korrekte statt falsche Stück-/Gramm-Preise ungeprüft entgegen. |
| `ReceiptLineRow.detailText` (`SmartCart/Views/Prices/ReceiptScannerView.swift:671-676`) | downstream consumer | Zeigt `quantity > 1` als "N × Preis" — Brötchen erscheinen künftig als "4 × 0,39 €" (gewollt, analog zum Lidl-Mehrfachkauf). |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | `droppingRedundantQuantityConfirmationLines` und ihr Aufruf in `parse()` entfernen; neuer Zweig in `parseClassic`, unmittelbar nach dem Storno-Check (`:382-386`) und vor dem bestehenden `" x "`-Zweig (`:397`): reine Bestätigungszeile ohne `pendingName`/`pendingPrice` wird konsumiert, ggf. `results.last` zugeschrieben. Kommentar `:167-187` wird an den neuen Ort verschoben und an den neuen Mechanismus angepasst. |
| `RestockTests/ReceiptParserReweTests.swift` | MODIFY | `testQuantityAndWeightFollowupLinesDoNotOverrideAlreadyKnownTotal` um Assertions für `quantity`/`weightBasis` (Brötchen, Banane) erweitert; `testAllFourteenPositionsAreRecognized` bleibt unverändert grün. |
| `RestockTests/ReceiptParserLidlFullReceiptTests.swift` | MODIFY | `testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext` um Assertion `banane.weightBasis == 638` erweitert (Regressionsschutz + Beifang). |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Zwei neue Tests (Negativfall Rechenprobe fehlgeschlagen; Bestätigungszeile als allererste Zeile) sowie ein neuer End-to-End-Test für das Preis-Lernen von Brötchen/Banane nach dem Muster von `assertLearnedPriceRoundTrip`. Bestehende Tests (`testDocumentedWeightLineWithoutSuffixComputesWeightTimesRate`, `testPieceCountLineSetsQuantityNotWeightBasis`) bleiben unverändert grün. |

### Estimated Changes
- Files: 4 (1 Produktivcode, 3 Test)
- LoC: +50/-15

### Out of Scope
- **Rückwirkende Korrektur bereits falsch gelernter Preise** ist nicht Teil dieses Fixes — nur
  künftige Scans lernen korrekt (eigenes Issue, falls gewünscht).
- **Keine UI-Änderung.** Die Anzeige "4 × 0,39 €" in `ReceiptLineRow.detailText` ergibt sich
  automatisch aus dem gesetzten `quantity`, ohne Code-Änderung an der View.
- **Keine Änderung an `parseEuroSuffixStyle`** oder der Formaterkennung in `parse()` — der
  Euro-Suffix-Pfad (Carrefour) kennt keine Bestätigungszeilen dieser Form, `classicCount`/
  `euroSuffixCount` dürfen dadurch nicht kippen.

## Implementation Details

**Ansatz B (aus der Analyse, mit einer Abweichung von der ursprünglichen Plan-Empfehlung):**

Der Vorfilter `droppingRedundantQuantityConfirmationLines` samt Aufruf in `parse()` entfällt. Statt
die Bestätigungszeile vor `parseClassic` zu löschen, wertet `parseClassic` sie selbst aus, in einem
neuen Zweig direkt nach dem Storno-Check (`:382-386`) und vor dem bestehenden `" x "`-Zweig
(`:397`):

```
Bedingung: pendingName == nil && pendingPrice == nil && !pendingStornoCancel
           && isBareQuantityOrWeightConfirmationLine(trimmed)
Dann:      Zeile wird IMMER konsumiert (`continue`) — nie eine eigene Position.
           Nur wenn zusätzlich results.last existiert, weightTimesRate(in: trimmed) matcht und
           |weight × rate − results.last.price| ≤ 0,01:
             unit "kg"  → results[results.count - 1].weightBasis = weight × 1000
             unit "stk" → results[results.count - 1].quantity   = weight
           Der Preis der Vorzeile (results.last.price) bleibt in jedem Fall unangetastet.
```

Die Guards sind identisch zur bisherigen Vorfilter-Logik begründet: `pendingName == nil` schließt
den Lidl-Fall aus (Namenszeile ohne eigenen Preis, die Gewichtszeile bleibt dort über den
bestehenden `" x "`-Zweig `:397-458` die einzige Preisquelle). `pendingPrice == nil` schließt den
umgekehrten Lidl-Fall aus (reine Preiszeile vor der Namenszeile). `!pendingStornoCancel` gibt einer
Storno-Erkennung Vorrang. Die Rechenprobe folgt demselben Muster wie der bestehende
Lidl-Mehrfachkauf-Zweig (`:432-450`, dort Toleranz 0,05).

**Abweichung von der ursprünglichen Plan-Empfehlung:** Der Plan-Agent sah vor, bei fehlgeschlagener
Rechenprobe die Zeile in den alten `" x "`-Zweig durchfallen zu lassen. Das reproduziert dort exakt
den Phantom-Bug aus der Reproduktion oben (`"Stk x 0,50"` als eigene Position). Diese Spec weicht
davon bewusst ab: **Eine reine Bestätigungszeile ohne `pendingName` wird immer konsumiert — nie
als eigene Position angelegt.** Die Rechenprobe entscheidet ausschließlich darüber, ob die Werte
`results.last` zugeschrieben werden, nicht darüber, ob die Zeile verworfen wird.

Die Formaterkennung in `parse()` (`:218-219`) bleibt unberührt: Weder `isClassicVatItemCandidate`
(verlangt ein MwSt-Kürzel am Zeilenende) noch `isEuroSuffixItemCandidate` (verlangt 2+-Leerzeichen-
Spalten mit Währungssymbol) matchen auf Bestätigungszeilen — `classicCount`/`euroSuffixCount`
ändern sich durch diesen Fix nicht.

## Invarianten

1. **Der Zeilenpreis der Vorzeile (`results.last.price`) wird durch die Bestätigungszeile nie
   verändert** — weder bei erfolgreicher noch bei fehlgeschlagener Rechenprobe.
2. **Die Formaterkennung in `parse()` bleibt unverändert**: `euroSuffixCount`/`classicCount` und
   die Weiche zwischen `parseClassic`/`parseEuroSuffixStyle` werden durch diesen Fix nicht
   berührt.
3. **Eine reine Bestätigungszeile ohne `pendingName` erzeugt nie eine eigene Position** —
   unabhängig vom Ausgang der Rechenprobe (Phantom-Schutz bedingungslos).
4. **Der Lidl-Zweig (`" x "`-Zweig, `:397-458`) bleibt für den Fall zuständig, dass die Vorzeile
   nur den Namen ohne Preis trägt** (`pendingName != nil`) — dieser Fix ändert an diesem Zweig
   nichts.
5. Der Vorfilter-Kommentar (`ReceiptParserService.swift:167-187`) wird an die neue Stelle in
   `parseClassic` verschoben und so angepasst, dass er den neuen Mechanismus (Zuschreiben statt
   Löschen) beschreibt, statt gelöscht zu werden — die darin dokumentierte Unterscheidung
   Rewe-/Lidl-Format bleibt inhaltlich richtig und wird weiter gebraucht.

## Test Plan

### Automated Tests (TDD RED)

- [x] **AC1 (RED vor dem Fix, GREEN danach):** GIVEN das Rewe-Fixture mit `"LAUGENBROETCHEN 1,56 B"`
  gefolgt von `"4 Stk x 0,39"` WHEN `ReceiptParserService.parse` aufgerufen wird THEN hat die
  Brötchen-Position `quantity == 4`, `weightBasis == nil`, `price == 1.56` (unverändert).
  Test: `RestockTests/ReceiptParserReweTests.swift` —
  `testQuantityAndWeightFollowupLinesDoNotOverrideAlreadyKnownTotal`.
- [x] **AC2 (RED vor dem Fix, GREEN danach):** GIVEN das Rewe-Fixture mit
  `"BANANE CHIQUITA 1,76 B"` gefolgt von `"0,706 kg x 2,49 EUR/kg"` WHEN `parse` aufgerufen wird
  THEN hat die Bananen-Position `weightBasis == 706`, `quantity == 1`, `price == 1.76`
  (unverändert). Test: `RestockTests/ReceiptParserReweTests.swift` —
  `testQuantityAndWeightFollowupLinesDoNotOverrideAlreadyKnownTotal`.
- [x] **AC3 (schon vor dem Fix GREEN, muss GREEN bleiben):** GIVEN das vollständige Rewe-Fixture
  (14 echte Positionen + 2 Bestätigungszeilen + Kopf-/Fuß-/Steuerzeilen) WHEN `parse` aufgerufen
  wird THEN liefert das Ergebnis genau 14 Positionen (keine Phantom-Position durch den entfernten
  Vorfilter), alle übrigen Preise bleiben unverändert. Test:
  `RestockTests/ReceiptParserReweTests.swift` — `testAllFourteenPositionsAreRecognized`,
  `testItemNamesAndPricesAreCorrect`.
- [x] **AC4 (RED vor dem Fix, GREEN danach):** GIVEN das vollständige Lidl-Fixture mit
  `"Banane lose  0,82 A"` gefolgt von `"0,638 kg x 1,29  EUR/kg"` WHEN `parse` aufgerufen wird
  THEN hat die Bananen-Position `weightBasis == 638`; alle bestehenden Lidl-Assertions
  (`maultaschen.quantity == 3`, `mandeln.quantity == 2`, `broetchen.quantity == 2`, Namen, Preise)
  bleiben unverändert. Test: `RestockTests/ReceiptParserLidlFullReceiptTests.swift` —
  `testMultiBuyLinesHaveCorrectQuantityInFullReceiptContext`.
- [x] **AC5 (schon vor dem Fix GREEN, muss GREEN bleiben):** GIVEN eine Namenszeile OHNE eigenen
  Preis gefolgt von einer Gewichts-/Stückzahlzeile (`["Aufschnitt", "0,436 kg x 12,49"]`,
  `["Eier Freiland", "3 Stk x 0,79"]`) WHEN `parse` aufgerufen wird THEN bleibt das bestehende
  Verhalten erhalten: Gesamtpreis = Gewicht × Rate, `weightBasis`/`quantity` wie heute gesetzt.
  Test: `RestockTests/ReceiptParserPriceTests.swift` —
  `testDocumentedWeightLineWithoutSuffixComputesWeightTimesRate`,
  `testPieceCountLineSetsQuantityNotWeightBasis`.
- [x] **AC6 (heute GREEN durch den alten Vorfilter, muss nach dem Fix GREEN bleiben, jetzt mit
  anderem Mechanismus):** GIVEN `["Produkt  1,00 A", "3 Stk x 0,50"]` (3 × 0,50 = 1,50 ≠ 1,00, die
  Rechenprobe schlägt fehl) WHEN `parse` aufgerufen wird THEN entsteht genau 1 Position mit
  `quantity == 1`, `weightBasis == nil`, `price == 1.00` — die Bestätigungszeile wird konsumiert,
  aber nicht zugeschrieben und nicht als eigene Position angelegt. Test:
  `RestockTests/ReceiptParserPriceTests.swift` — neuer Test
  `testBareConfirmationLineWithFailedSanityCheckIsConsumedNotAttributed`.
- [x] **AC7 (heute GREEN durch den alten Vorfilter, muss nach dem Fix GREEN bleiben):** GIVEN eine
  Bestätigungszeile als allererste Zeile der Eingabe (`results` ist beim Erreichen der Zeile noch
  leer, kein `results.last`) WHEN `parse` aufgerufen wird THEN entsteht keine Position und der
  Aufruf stürzt nicht ab. Test: `RestockTests/ReceiptParserPriceTests.swift` — neuer Test
  `testBareConfirmationLineAsFirstLineDoesNotCrash`.
- [x] **AC8 (RED vor dem Fix, GREEN danach):** GIVEN dieselbe End-zu-Ende-Kette wie
  `assertLearnedPriceRoundTrip` (Parsing → `EditableReceiptLine.learningQuantity` →
  `perUnitPrice` → `store.learnedPrices` → `ShoppingItem.estimatedLineTotal`) für Brötchen
  (`["LAUGENBROETCHEN 1,56 B", "4 Stk x 0,39"]`) und Banane
  (`["BANANE CHIQUITA 1,76 B", "0,706 kg x 2,49 EUR/kg"]`) WHEN der Kreislauf durchlaufen wird
  THEN lernen Brötchen 0,39 €/Stück und Banane 1,76/706 €/g (entspricht 2,49 €/kg). Test:
  `RestockTests/ReceiptParserPriceTests.swift` — neuer Test
  `testLearnedPriceRoundTripForReweBroetchenAndBanane`.

## Acceptance Criteria

- [x] **AC1:** Rewe-Brötchen (`"LAUGENBROETCHEN 1,56 B"` + `"4 Stk x 0,39"`) → `quantity == 4`,
  `weightBasis == nil`, `price == 1.56` unverändert.
- [x] **AC2:** Rewe-Banane (`"BANANE CHIQUITA 1,76 B"` + `"0,706 kg x 2,49 EUR/kg"`) →
  `weightBasis == 706`, `quantity == 1`, `price == 1.76` unverändert.
- [x] **AC3:** Das vollständige Rewe-Fixture liefert weiterhin exakt 14 Positionen, alle übrigen
  Preise unverändert.
- [x] **AC4:** Lidl-Fixture (`"Banane lose  0,82 A"` + `"0,638 kg x 1,29  EUR/kg"`) →
  `weightBasis == 638`; alle bestehenden Lidl-Assertions (quantity 3/2/2, Namen, Preise)
  unverändert.
- [x] **AC5:** Lidl-Fall Namenszeile ohne Preis (`["Aufschnitt", "0,436 kg x 12,49"]`,
  `["Eier Freiland", "3 Stk x 0,79"]`) — bestehendes Verhalten unverändert.
- [x] **AC6:** Negativfall (`["Produkt  1,00 A", "3 Stk x 0,50"]`, Rechenprobe schlägt fehl) →
  genau 1 Position, `quantity == 1`, `weightBasis == nil`, `price == 1.00`; die Bestätigungszeile
  wird konsumiert, nicht zugeschrieben, nicht zur eigenen Position.
- [x] **AC7:** Bestätigungszeile als allererste Zeile → keine Position, kein Absturz.
- [x] **AC8:** Preis-Lernen-Durchstich: Brötchen lernen 0,39 €/Stück, Banane lernt
  1,76/706 €/g (entspricht 2,49 €/kg).

## Alternativen (verworfen)

- **A — Zeilenpaar anheften:** Rohtext der Bestätigungszeile an die Namenszeile hängen und als
  eine gemeinsame Zeile parsen. Verworfen, weil das die Preis-Regex der Namenszeile
  (`tightRegex`/`looseRegex`, `:329-334`) bricht — die verlangt den Preis am Zeilenende, ein
  angehängter Rest würde das Muster verfehlen.
- **C — Nachträgliche Index-Zuordnung** in `parse()` nach `parseClassic`: Verworfen, weil `results`
  nicht 1:1 auf die Eingabezeilen abbildet — Pfand- und Storno-Zeilen verschieben den Index
  während des Parsens, eine nachträgliche Zuordnung wäre nicht zuverlässig rekonstruierbar.
- **D — Zeile im Rohtext markieren statt löschen** (z. B. Präfix einfügen): Verworfen, weil eine
  Rohtext-Manipulation vor dem eigentlichen Parsing alle nachgelagerten Regexe (Preis-, Gewichts-,
  Admin-Erkennung) potenziell mitbetrifft — höheres Risiko als ein lokal begrenzter neuer Zweig in
  `parseClassic`.
- **E — Vorfilter behalten, stattdessen aus dem Artikelnamen lernen** (`weightBasisFromName`):
  Verworfen, weil das den Stückzahl-Fall (Brötchen, "4 Stk") gar nicht löst — im Namen steht keine
  Stückzahl — und den Gewichtsfall nur bei abgepackter Ware mit Größenangabe im Namen selbst löst,
  nicht bei lose gewogener Frischware wie der Banane.

## Risiken

- **Kritischer Pfad:** `ReceiptParserService.parse` wird bei jedem Bon-Scan durchlaufen (Foto-Scan
  und Share-Extension-PDF-Import); ein Fehler im neuen Zweig würde alle Bon-Formate treffen, nicht
  nur Rewe. Deshalb Regressionsschutz über alle drei Test-Dateien (Rewe, Lidl, generische
  Preis-Tests) statt nur über das ursprünglich betroffene Fixture.
- **Sync geteilter Listen:** Gelernte Preise (`store.learnedPrices`) laufen ungeprüft über
  `SyncCoordinator` an alle Mitglieder einer geteilten Liste — ein falsch zugeschriebener Wert
  würde sich dort verbreiten. Die Rechenprobe (AC6) ist die einzige Absicherung gegen eine falsche
  Zuschreibung; sie darf nicht entfernt oder gelockert werden.
- **Toleranz 0,01 wegen Bon-Rundung:** 0,706 × 2,49 = 1,75794, gedruckt wird 1,76 — die Rechenprobe
  muss mit einer Toleranz ≥ 0,01 rechnen, sonst schlägt AC2 trotz korrekter Bon-Daten fehl. Eine zu
  große Toleranz würde umgekehrt AC6 (Negativfall) gefährden; 0,01 ist der in der Analyse belegte,
  knappste noch ausreichende Wert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — es gibt im Projekt kein formales ADR-Verzeichnis (`docs/adr/` existiert
  nicht).
- **Rationale:** Diese Änderung ist eine lokal begrenzte Korrektur eines Vorfilters, der
  Informationen ersatzlos verwarf, statt sie zuzuschreiben — kein Eingriff in die
  Formaterkennung, die Datenmodelle oder die Sync-Architektur. Die einzige risikorelevante
  Entscheidung (Rechenprobe entscheidet nur über Zuschreibung, nicht über Konsum der Zeile) ist
  oben unter "Implementation Details" als bewusste Abweichung von der Plan-Empfehlung begründet
  und durch AC6/AC7 abgesichert; ein separates ADR-Dokument wäre für einen Bugfix dieses Umfangs
  unverhältnismäßig.

## Changelog

- 2026-09-21: Initial spec created
- 2026-09-22: Implementiert und validiert (144 Unit + 5 UI Tests grün, Adversary VERIFIED)
