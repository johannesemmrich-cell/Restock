# Context: fix-195-ocr-kyrillisches-a

## Request Summary
Issue #195: Auf iOS 27.0 findet der Streifen-Test T1 (`ReceiptTextRecognizerTests`) 15 statt 18 Positionen. Auf iOS 26.5 war er grün.
PO-Entscheidung (2026-10-21): voller Prozess, Lösung als Regel im Parser (kein Modell-/Anfrage-Umbau).

## Reproduktion und Root Cause (belegt)
- Reproduziert am 2026-10-21 auf `Restock-Validate-27` (iOS 27.0), Stand `d8e0479`: drei Fehlschläge in T1 (Zeilen 52/54/56), 15 statt 18 Positionen.
  Beleg: `docs/artifacts/fix-195-ocr-kyrillisches-a/repro-t1-ios27-rot.txt`.
- Rohblöcke (`diagnose-varianten-ios27.txt`): Vision liefert „Haferflocken  0,85 \u{410}“, „Broetchen Laugen  0,78 \u{410}“, „Kaffee Bohnen  8,99 \u{410}“ — das Steuerkürzel „A“ als kyrillisches А (U+0410).
- Die Parser-Zeilenmuster erlauben am Zeilenende nur `[ABM12E\*]` (lateinisch). Die Zeile gilt nicht als Position.
- Nicht die Ursache: Streifen-Logik (#120), Streifenkanten, Endsumme (68,69 wird erkannt).
- Anfrage-Varianten (iOS 27): Sprachkorrektur an → 18, Schnellmodus → 18; Revision 2, nur de-DE, Mindesthöhe → 15 (unverändert). Beide 18er-Wege sind Modellwege und kippen AC-9 aus #120 bzw. sind ungenauer.
- Gleiches kyrillisches А trat schon auf iOS 26 im Einzelzug auf (`docs/artifacts/fix-120-bon-lange-bilder/ist-zustand-erzeugtes-bild.txt`): kein reines iOS-27-Phänomen, nur häufiger.
- Recherche: Apple hat iOS-27-Texterkennungsmodelle (`_e5`) still getauscht, Entwicklerberichte zu fehlenden Zeilen und kyrillischen Doppelgängern: forums/thread/845452, forums/thread/851862, macshot#439. Keine Apple-Antwort, keine neue Revisionsnummer.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/ReceiptParserService.swift` | `parse` (:176) und `detectedTotal(from:)` (:214) normalisieren beide die Zeilen per `repairSplitDecimals` (:243); Zeilenmuster mit `[ABM12E\*]` an :140, :255, :296, :300, :304, :984. Hier greift die Regel. |
| `SmartCart/Services/ReceiptParserService.swift:677` | `containsCyrillic` — Cyrillic-Filter im Euro-Suffix-Pfad; Vorsicht, damit die neue Wandlung ihn nicht aushebelt. |
| `RestockTests/ReceiptTextRecognizerTests.swift` | T1 (rot, braucht Vision) — Wächter. Neuer Parser-Test ohne Vision gehört in `ReceiptParserPriceTests.swift`. |
| `RestockTests/ReceiptParserPriceTests.swift` | Heimat für den neuen reinen Parser-Test. |

## Existing Patterns
- Normalisierung vor dem Parsen in `parse`/`detectedTotal` (`repairSplitDecimals`), ein Ort für beide Wege.
- Kyrillisches „х“→„x“ im Euro-Suffix-Pfad (`parseEuroSuffixStyle`, :689): gleiches Muster „Homoglyph zurückwandeln“.

## Dependencies
- Upstream: Vision-Blöcke → `reconstructLines`.
- Downstream (Verbraucher): `ReceiptScannerView.process` (:722–728) und `ShareViewController` (:145–198). Beide rufen `reconstructLines`, `detectedTotal`, `parse` — eine Änderung in `parse`/`detectedTotal` wirkt auf App-Scanner und Teilen-Weg gleichzeitig.

## Existing Specs
- `docs/specs/services/receipt-text-recognizer-tiling.md` (AC-9: Anfrage-Einstellungen unverändert) — bleibt unberührt.
- `docs/specs/services/receipt-share-extension-recognizer.md`.

## Alternativen (und was sie kippen würden)
- Sprachkorrektur an / `.fast`: Modellweg, kippt AC-9 (#120), Namen werden zu Wörterbuch-Wörtern bzw. ungenauer. Nicht gewählt.
- Test anpassen (nur 15 erwarten): verdeckt echten Nutzerverlust, verworfen.
- Gewählt: Regel im Parser — kyrillische Doppelgänger (А В Е М) werden nur als alleinstehendes Kürzel am Zeilenende nach einem Preis in lateinische gewandelt.

## Risks & Considerations
- Wandlung eng halten: nur Kürzel direkt nach einem Preis am Zeilenende, nicht in Namen (kyrillische Zeichen in Namen sind im Euro-Suffix-Pfad ein Verwerfungs-Signal).
- Zeichen 1 und 2 sind bereits ASCII; relevante Homoglyphen sind А (U+0410), В (U+0412), Е (U+0415), М (U+041C).
- Gemeinsame Zeilen-Normalisierung für `parse` und `detectedTotal`, damit beide dieselbe Sicht haben.
- Offene Grenze: weitere Fehllesungen von Vision (z. B. „ął“ statt „B“, beobachtet in #120) sind nicht Teil.
- Haupt-Ordner ist veraltet (93 Änderungen zurück); Analyse lief im Arbeitsordner `issue-195`.

## Analysis

### Type
Bug

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | Neue Zeilen-Normalisierung `normalizeTaxCodeHomoglyph` (kyrillisches А/В/Е/М als alleinstehendes Kürzel nach Preis am Zeilenende → lateinisch), aufgerufen in `parse` und `detectedTotal` neben `repairSplitDecimals` |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Neue reine Parser-Tests (ohne Vision): Wandlung greift, Namen mit Kyrillisch bleiben unberührt, Euro-Suffix-Verwerfung bleibt, `detectedTotal` |

### Scope Assessment
- Files: 2 (T1 in `ReceiptTextRecognizerTests` bleibt unverändert als Wächter)
- Estimated LoC: +~60/-0 (Regel ~15, Tests ~45)
- Risk Level: LOW — enge Regel, wirkt gleichzeitig auf App-Scanner und Teilen-Erweiterung

### Technical Approach
Ohne Modell: Ein Regex (`(\d[,\.]\d{2})\s*([АВЕМ])\s*$` → lateinischer Buchstabe) vor dem Parsen. Ohne Modell geht es hier nicht nur besser, sondern ist die Ursache selbst deterministisch (Zeichentausch, kein Sprachverstehen). Nur das Kürzel direkt hinter einem Preis am Zeilenende wird gewandelt, nie Namen. Alternativen (Sprachkorrektur an, Schnellmodus: Modellwege, kippen AC-9 aus #120; Test auf 15 senken: verdeckt Nutzerverlust) verworfen.

### Dependencies
Upstream: Vision → `reconstructLines`. Downstream: `ReceiptScannerView.process`, `ShareViewController`.

### Open Questions
- [ ] keine
