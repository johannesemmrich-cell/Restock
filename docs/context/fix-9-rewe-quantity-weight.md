# Context: fix-9-rewe-quantity-weight

Issue: #9 — Bon-Scan verliert Stückzahl und Gewicht beim Rewe-Format, dadurch falsch gelernte Preise.
Vorarbeit: `docs/context/check-8-bon-zweck.md` (Prüfung #8, Sonde belegt den Verlust).

## Request Summary
Die Mengen-/Gewichts-Bestätigungszeile des Rewe-eBons ("4 Stk x 0,39", "0,706 kg x 2,49 EUR/kg")
wird heute im Vorfilter verworfen. Sie soll stattdessen ausgewertet und der vorangehenden Position
zugeschrieben werden (Stückzahl → `quantity`, Gewicht → `weightBasis`), ohne dass der bereits korrekte
Zeilenpreis kippt oder eine Phantom-Position entsteht.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/ReceiptParserService.swift:7-25` | `ReceiptLine` — `quantity` (Stückzahl, Review-UI), `weightBasis` (Gramm-Divisor nur fürs Lernen), `unitPrice` |
| `SmartCart/Services/ReceiptParserService.swift:167-207` | `isClassicVatItemCandidateLoose`, `droppingRedundantQuantityConfirmationLines`, `isBareQuantityOrWeightConfirmationLine` — **die Stelle, die Information verwirft** |
| `SmartCart/Services/ReceiptParserService.swift:210-219` | `parse()` — Vorfilter läuft VOR der Formaterkennung, gilt also für alle Bon-Formate |
| `SmartCart/Services/ReceiptParserService.swift:327-600` | `parseClassic` — Hauptschleife mit `pendingName`/`pendingPrice`; der `" x "`-Zweig (`:397-458`) setzt heute `quantity`/`weightBasis` nur, wenn die Gewichtszeile die einzige Preisquelle ist (Lidl) |
| `SmartCart/Services/ReceiptParserService.swift:871-874, 912-923` | `weightTimesRateRegex` / `weightTimesRate(in:)` — liefert (weight, unit "kg"/"stk", rate); genau der Baustein für die Auswertung |
| `SmartCart/Services/ReceiptParserService.swift:547` | Append der klassischen Positionszeile (Name + Preis + MwSt) — die Position, der die Folgezeile zuzuschreiben ist (`results.last`) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:58-60` | `learningQuantity(matchQuantityAmount:)` — Reihenfolge `weightBasis ?? quantity>1 ?? match ?? Name ?? 1`; greift korrekt, sobald die Werte ankommen |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:611-613` | `save()` — `perUnitPrice = price / learningQuantity` → `store.learnedPrices` |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:671-676` | `ReceiptLineRow.detailText` — zeigt `quantity > 1` als "N × Preis"; Brötchen erscheinen künftig als "4 × 0,39 €" (gewollt, wie bei Lidl) |
| `RestockTests/ReceiptParserReweTests.swift` | Echtes Rewe-Fixture (14 Positionen); `testQuantityAndWeightFollowupLinesDoNotOverrideAlreadyKnownTotal` prüft nur `price` — **Testlücke** |
| `RestockTests/ReceiptParserPriceTests.swift` | Referenz-Assertions für `weightBasis == 500` / `quantity == 3` bei Lidl-Format (Gewichtszeile ist dort einzige Preisquelle) |
| `RestockTests/ReceiptParserLidlFullReceiptTests.swift` | Regressionsschutz Lidl (Mehrfachkauf `quantity 3/2`, Gewichtszeile `0,638 kg x 1,29`) |

## Existing Patterns
- **Sanity-Check vor Übernahme:** Der Lidl-Mehrfachkauf-Zweig (`:432-450`) übernimmt `quantity` nur,
  wenn `|price − unitPrice × count| ≤ 0.05`. Dasselbe Muster passt hier: Bestätigungszeile nur
  zuschreiben, wenn Menge × Rate ≈ Preis der Vorzeile (4 × 0,39 = 1,56 ✓; 0,706 × 2,49 = 1,758 ≈ 1,76 ✓).
- **Einheiten-Unterscheidung:** `"kg"` → `weightBasis = weight × 1000` (Gramm, passt zu `ShoppingItem.unit == "g"`),
  `"stk"` → `quantity = weight`. Dokumentiert in der `weightBasis`-Doc und im `" x "`-Zweig.
- **`results.last` als Ziel:** `removingMostRecentMatch` / Pfand-Zeile (`:459ff`) schreiben bereits auf die
  zuletzt erfasste Position zurück — Vorbild für das Zuschreiben der Folgezeile.
- **Tests gegen echte Bons:** Fixtures sind wörtliche Bon-Zeilen; Assertions per `name.contains`.

## Dependencies
- Upstream (was der Parser nutzt): `weightTimesRate`, `isClassicVatItemCandidateLoose`, `repairSplitDecimals`.
- Downstream (wer `quantity`/`weightBasis` liest): `EditableReceiptLine` (Durchreiche), `learningQuantity`,
  `save()` → `store.learnedPrices` → `SyncCoordinator` (geteilte Listen, ungeprüft), `ReceiptLineRow.detailText`.

## Existing Specs
- Keine Spec zum Bon-Parser in `docs/specs/` (nur `models/shared-model-container.md`, `testing/ui-test-language.md`).

## Risks & Considerations
- **Phantom-Position darf nicht zurückkommen** (`testAllFourteenPositionsAreRecognized` == 14). Wird der
  Vorfilter entfernt, muss die Bestätigungszeile in `parseClassic` konsumiert werden, bevor der
  `" x "`-Zweig oder das Preismuster sie als eigene Position anlegt.
- **Lidl-Format unverändert:** Dort trägt die Namenszeile keinen Preis, die Gewichtszeile ist einzige
  Preisquelle — die Unterscheidung (Vorzeile vollständig oder nicht) muss erhalten bleiben.
- **Vorfilter gilt für alle Formate** (läuft vor der Formaterkennung in `parse()`): Ein Ersatz muss auch
  den Euro-Suffix-Parser (Carrefour) nicht verschlechtern — dort gibt es keine solchen Folgezeilen,
  aber der Zähler `classicCount` in `parse()` darf nicht kippen.
- **Rundung beim Gewichts-Check:** 0,706 × 2,49 = 1,75794 vs. 1,76 — Toleranz muss ≥ 0,01 sein.
- **Dauerhaftigkeit:** Bereits falsch gelernte Preise werden durch den Fix nicht korrigiert, nur künftige
  Scans; Korrektur alter Werte ist nicht Teil von #9.
- **Alternative Ansätze** (für die Analyse): (A) Vorfilter behalten, aber Folgezeile an die Vorzeile
  "anheften" (Zeilenpaar) und in `parseClassic` auswerten; (B) Vorfilter entfernen, in `parseClassic`
  die Bestätigungszeile direkt auf `results.last` anwenden; (C) Nachbearbeitung in `parse()` über eine
  Index-Zuordnung — verworfen, weil `results` nicht 1:1 auf Zeilen abbildet.

## Analysis

### Type
Bug (Issue #9)

### Reproduktion (2026-09-21, Sonden danach entfernt, Arbeitsbaum sauber)
1. **Ist-Zustand** (temporärer Test im Rewe-Fixture):
   `PROBE broetchen: price=1.56 quantity=1.0 weightBasis=nil` · `PROBE banane: price=1.76 quantity=1.0 weightBasis=nil`
2. **Vorfilter testweise abgeschaltet:** 15 statt 14 Positionen. Phantom = Name `"Stk x 0,39"`, price 1,56,
   quantity 4. Ursache des Phantoms: der `" x "`-Zweig läuft mit `pendingName == nil` (Vorzeile bereits als
   Position konsumiert, `:547`), `nameChunkBeforeWeightDetail` (`:607`) strippt per `strayBulletPrefixRegex`
   (`^\S\s+(?=[A-Za-z])`, `:600`) die führende `"4 "` als vermeintliches Aufzählungszeichen → Restname
   `"Stk x 0,39"`. Die Bananen-Zeile (`"0,706 …"`, führende Ziffer bleibt) wird dort stumm verworfen —
   Banane bleibt ohne `weightBasis`.
3. `weightTimesRate(in:)` liefert für beide Zeilen korrekt (4, "stk", 0,39) bzw. (0,706, "kg", 2,49).

### Root Cause
`droppingRedundantQuantityConfirmationLines` (`ReceiptParserService.swift:189-200`, Aufruf `:211`) löscht die
Bestätigungszeile aus dem Zeilenstrom, bevor `parseClassic` sie sehen kann. Der Schutz vor der Phantom-Position
ist berechtigt, aber am falschen Ort: Er verwirft die Zeile, statt sie der Vorzeile zuzuschreiben.

**Zusatzbefund (Plan-Agent, verifiziert):** Das Lidl-Fixture (`ReceiptParserLidlFullReceiptTests.swift:28-29`)
hat denselben Aufbau — `"Banane lose  0,82 A"` + `"0,638 kg x 1,29  EUR/kg"`. Die Lidl-Banane verliert heute
ebenfalls ihr Gewicht (kein Test prüft das). Der Fix greift dort mit (0,638 × 1,29 = 0,823 ≈ 0,82).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | Vorfilter `droppingRedundantQuantityConfirmationLines` + Aufruf in `parse()` entfernen (−12 LoC); neuer Zweig in `parseClassic` direkt nach dem Storno-Check (`:382-386`), vor dem `" x "`-Zweig (`:397`): reine Bestätigungszeile ohne `pendingName` → auf `results[last]` zuschreiben (+15–20 LoC); Kommentar `:167-187` anpassen |
| `RestockTests/ReceiptParserReweTests.swift` | MODIFY | Assertions `quantity == 4`, `weightBasis == nil` (Brötchen), `weightBasis == 706`, `quantity == 1` (Banane), Preise unverändert; `count == 14` bleibt |
| `RestockTests/ReceiptParserLidlFullReceiptTests.swift` | MODIFY | Assertion `banane.weightBasis == 638` (Regressionsschutz + Beifang) |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Negativfall `["Produkt  1,00 A", "3 Stk x 0,50"]` (Menge × Rate ≠ Vorpreis) → weiterhin 1 Position, `quantity == 1`, `weightBasis == nil`; Vorzeile ohne Preis (Lidl-Fall `["Aufschnitt", "0,436 kg x 12,49"]`) bleibt unverändert |

### Scope Assessment
- Files: 4 (1 Produktiv, 3 Test)
- Estimated LoC: +50/−15
- Risk Level: MEDIUM — kritischer Pfad Bon-Import, aber lokal begrenzt; gelernte Preise gehen über Sync an geteilte Listen

### Technical Approach (Ansatz B — Empfehlung)
Vorfilter entfernen; in `parseClassic` neuer Zweig **vor** dem bestehenden `" x "`-Zweig:

```
Bedingung: pendingName == nil && pendingPrice == nil && !pendingStornoCancel
           && isBareQuantityOrWeightConfirmationLine(trimmed)
Dann:      Zeile wird IMMER konsumiert (`continue`) — nie eine eigene Position (Phantom-Schutz bleibt
           bedingungslos erhalten, auch wenn die Rechenprobe unten fehlschlägt).
           Nur wenn results.last existiert, weightTimesRate matcht und
           |weight × rate − results.last.price| ≤ 0,01:
             "kg"  → results[last].weightBasis = weight × 1000
             "stk" → results[last].quantity   = weight
           Preis der Vorzeile bleibt unangetastet.
```

Guards begründet: `pendingName == nil` — sonst Lidl-Fall (Namenszeile ohne Preis, Gewichtszeile ist einzige
Preisquelle, bestehender Zweig `:397-458` bleibt zuständig). `pendingPrice == nil` — umgekehrter Lidl-Fall.
`!pendingStornoCancel` — Storno hat Vorrang. Rechenprobe wie im Lidl-Mehrfachkauf-Zweig (`:432-450`).

Formaterkennung in `parse()` (`:218-219`) bleibt unberührt: `isClassicVatItemCandidate` verlangt ein MwSt-Kürzel
am Zeilenende, `isEuroSuffixItemCandidate` 2+-Leerzeichen-Spalten — beides matcht auf Bestätigungszeilen nicht.

**Abweichung von der Plan-Empfehlung:** Der Plan-Agent ließ den Fall „Rechenprobe fehlgeschlagen" in den alten
`" x "`-Zweig durchfallen — das reproduziert dort exakt den Phantom-Bug (`"Stk x 0,50"`). Deshalb: Bestätigungszeile
ohne `pendingName` wird immer konsumiert; die Rechenprobe entscheidet nur, ob zugeschrieben wird.

### Alternativen (unterlegen)
- **A — Zeilenpaar anheften** (Rohtext der Folgezeile an die Namenszeile hängen): bricht die Preis-Regex der
  Namenszeile (`tightRegex`/`looseRegex`, `:330-334`, Preis muss am Zeilenende stehen).
- **C — Index-Zuordnung** nach `parseClassic`: `results` bildet nicht 1:1 auf Zeilen ab (Pfand/Storno verschieben).
- **D — Zeile markieren statt löschen** (Präfix im Rohtext): Rohtext-Manipulation, die alle Regexe berührt.
- **E — Vorfilter behalten, nichts ändern, Lernen aus dem Artikelnamen** (`weightBasisFromName`): löst den
  Stückzahl-Fall (Brötchen) gar nicht und den Gewichtsfall nur bei abgepackter Ware — verworfen.

### Dependencies
- Upstream: `weightTimesRate`, `isBareQuantityOrWeightConfirmationLine` (bleibt, wird zum Erkenner im Parser).
- Downstream: `EditableReceiptLine`, `learningQuantity`, `save()` → `store.learnedPrices` → `SyncCoordinator`;
  `ReceiptLineRow.detailText` zeigt Brötchen künftig als „4 × 0,39 €" (gewollt, wie Lidl-Mehrfachkauf).

### Open Questions
- [ ] Keine PO-Fragen. Rückwirkende Korrektur bereits falsch gelernter Preise ist bewusst nicht Teil von #9
      (eigenes Issue, falls gewünscht).

## TDD RED (2026-09-21)
Lauf: `docs/artifacts/fix-9-rewe-quantity-weight/test-red-output.txt` — 31 Tests, 6 Fehlschläge in 4 Tests.
- RED: AC1/AC2 (`ReceiptParserReweTests`), AC4 (`ReceiptParserLidlFullReceiptTests`), AC7/AC8 (`ReceiptParserPriceTests`).
- GREEN heute, muss bleiben: AC3 (14 Positionen), AC5 (Lidl-Namenszeile ohne Preis), AC6 (Negativfall — heute nur grün, weil der Vorfilter die Zeile löscht).
- **Zusatzerkenntnis AC7:** Eine Bestätigungszeile als allererste Zeile wird HEUTE SCHON zur Phantom-Position `"Stk x 0,39"` — der Vorfilter greift dort nicht (keine Vorzeile). Der neue Zweig (Konsum ohne `pendingName`, unabhängig von `results.last`) deckt das mit ab.
