# Context: import-dialog-textfeld-bontext

## Request Summary
PO-Rückmeldung zum Bon-Importdialog (Prüfkarte): Der Original-Bontext soll immer als editierbare
Eingabe nutzbar sein. Das bisherige Feld „Anderer Name …" erschien erst nach Antippen, war vorab
nicht sichtbar und wurde mit dem gerade gewählten Namen gefüllt (KI-Name, Listentreffer oder
Bontext — je nach Auswahl, ohne erkennbares Muster). Die Zeile „wie auf dem Bon" (Issue #65,
Paket 2) war eine Doppelung des Bontexts. Gewünscht: der Bontext, wortweise großgeschrieben, als
Vorausfüllung eines dauerhaft sichtbaren Textfelds.

## Entscheidungen (PO)
- Die Auswahlzeile „wie auf dem Bon" entfällt ersatzlos.
- Das Textfeld ist immer sichtbar (letzte Zeile jeder Karte) und vorausgefüllt mit
  `normalizedReceiptText(originalName)`; bei leerem Bontext mit `line.name`.
- Antippen von Kreis oder Feld wählt die Zeile; Feldinhalt gilt sofort als Name; Leeren fällt auf
  die vorherige Auswahl zurück (Regel 10, unverändert).
- Design wurde vor Freigabe im Canvas „Bon-Karte Textfeld" gezeigt (2026-10-01).

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | `ReceiptNameOption.receiptText` und `shouldOfferReceiptTextOption` entfernt; Regel 7 entfernt; `customNameRow(identifier:)` immer sichtbar; `activateCustom()`; `customFieldSeed(for:)`. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | Hinweistext unter der Liste angepasst. |
| `RestockTests/ReceiptReviewCardTests.swift` | Tests der Bon-Zeile entfernt, Zählungen 5→4 / 3→2, zwei Tests für `customFieldSeed`. |
| `RestockUITests/ReceiptReviewUITests.swift` | `Seed.aiLineCustomOptionIndex` 2→1; `testCustomFieldIsPrefilledWithCapitalizedBonText` ersetzt den Test der Bon-Zeile. |
| `docs/specs/views/receipt-review-card.md` | Nachtrag „Textfeld statt Bon-Zeile", AC-27, AC-21/22 als entfallen markiert, Invariante 5 und AC-2 angepasst. |
| `CLAUDE.md` | Abschnitt `ReceiptReviewCard` beschreibt das Textfeld statt der Bon-Zeile. |

## Nicht geändert
`save()`, `EditableReceiptLine`, Wire-Format, Regel 9–11, `applyCustomName`/`applyCustomNameOrFallback`.

## Validierung
CI auf PR #84 (Kopf `3016adc`): `test` und `ui-test` grün. Ein zwischenzeitlich roter, unabhängiger
Test (`AddItemQuantitySuggestionUITests.testCorrectingQuantityRemovesAssumptionMarkAndRestoresTotal`,
Hittability) lief nach dem Merge von `main` durch; Ursache nicht nachgewiesen (vermutlich wackelig).
