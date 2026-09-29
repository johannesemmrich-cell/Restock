# Context: fix-67-currentname-matcheditem

## Request Summary
In der Bon-Prüf-Karte behält die Auswahl der Option „aktueller Name" (`.currentName`) die zuvor
gesetzte `matchedItemID` bei. `save()` schreibt den gelernten Bonpreis dann direkt auf den Artikel
hinter dieser ID — auch wenn der gerade gewählte Name nicht mehr zu ihm gehört.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | Enthält `applySelection` (Zeile 511–533) mit dem fehlerhaften `.currentName`-Zweig (Zeile 524–525) sowie das korrekte Vorbild `applyCustomName` (Zeile 536–540) und `applyCustomNameOrFallback` (544–566). |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | `EditableReceiptLine` (Feld-Doku `matchedItemID`, Zeile 30–37: „wird zurückgesetzt, sobald der Name danach frei überschrieben wird"). `save()` (Zeile 614ff., insb. 643–656) nutzt `line.matchedItemID` **direkt und ungeprüft** — findet es ein Item, wird kein Namensabgleich mehr gemacht. |
| `RestockTests/ReceiptReviewCardTests.swift` | Bestehende Tests für alle drei anderen Auswahl-Pfade (`listMatch`, `aiSuggestion`, `custom`/`receiptText`) folgen demselben Muster: `applySelection`/`applyCustomName` direkt aufrufen, `line.matchedItemID` prüfen. Kein Test für `.currentName` vorhanden — die Lücke, die den Fehler bisher verdeckt hat. |

## Existing Patterns

**Die drei anderen Auswahl-Pfade setzen `matchedItemID` bereits korrekt:**
- `.listMatch` → setzt `matchedItemID` auf die ID des gewählten Listentreffers (Zeile 516).
- `.aiSuggestion` → stellt die ursprüngliche KI-Zuordnung `aiSuggestedMatchedItemID` wieder her (Zeile 522) — bewusst designt, damit ein KI-Vorschlag nach Zwischenauswahl exakt zurückkommt (siehe Test `testChoosingAiSuggestionRestoresAiStateAfterAnotherSelection`).
- `.receiptText` und `.custom`/`applyCustomName` → setzen `matchedItemID = nil` (Zeile 530, 541), mit derselben Begründung, die der Feld-Kommentar für `matchedItemID` selbst nennt.

Nur `.currentName` (Zeile 524–525) bricht dieses Muster: `line.name = name` ohne jede Berührung
von `matchedItemID` oder `resolvedByAI`.

## Wie der Fehler entsteht (nachvollzogen im Code, nicht vermutet)

1. Beim Öffnen der Karte wird `options` **einmal** aus dem Anfangszustand der Zeile berechnet
   (`selectionOptions`, Zeile ~435 in `ReceiptReviewCard.swift`). Ist der anfängliche Name durch
   keinen der ersten drei Kandidaten (`.listMatch`/`.aiSuggestion`) abgedeckt, wird er selbst als
   `.currentName(name: line.name)` eingefügt (Regel 5) — mit dem `name`, der zu diesem Zeitpunkt
   galt.
2. Der Nutzer wählt danach eine andere Option, z. B. `.aiSuggestion` — `line.name` und
   `line.matchedItemID` ändern sich auf den KI-Vorschlag und dessen Artikel-ID.
3. Der Nutzer überlegt es sich anders und tippt erneut auf die (unverändert in `options`
   festgehaltene) `.currentName`-Zeile. `applySelection` setzt nur `line.name` zurück auf den alten
   Wert — `line.matchedItemID` bleibt die ID aus Schritt 2.
4. `save()` (Zeile 643–645) findet über diese ID ein `ShoppingItem` **ohne jeden Namensabgleich**
   und schreibt den Bonpreis dorthin.

## Warum „auf `nil` setzen" sicher ist (nicht Datenverlust)

`save()` fällt, wenn `matchedItemID == nil`, auf eine **exakte** Namenssuche über alle
abgehakten Artikel dieses Stores zurück (Zeile 653–655: `$0.isCompleted && $0.name.lowercased() ==
lineLower`). Trägt der aktuell gewählte Name (`.currentName`) tatsächlich zu einem abgehakten
Artikel, findet `save()` ihn über diesen Weg genauso zuverlässig wieder — nur eben über den
richtigen, aktuell geltenden Namen statt über eine stehengebliebene fremde ID. Ein „belegter"
Zusammenhang zwischen `.currentName` und einem bestimmten Artikel existiert im aktuellen Zustand
nicht (siehe Auslösung oben) — das rechtfertigt `nil`, nicht ein Versuch, die „richtige" alte ID zu
erraten.

`resolvedByAI` ist von `save()` für die Artikel-Zuordnung **nicht** betroffen (kein Vorkommen in
der Funktion) — nur für die Art.-50-Pillendarstellung, die unabhängig davon über `isSelected(.
aiSuggestion)` (Namensvergleich) gesteuert wird. Ein Leck dort ist kosmetisch und nicht Teil dieses
Tickets; der Fix folgt trotzdem dem Vorbild `applyCustomName`, das beide Felder zusammen zurücksetzt
(Konsistenz zum bestehenden Muster, kein Sonderfall nur für `matchedItemID`).

## Dependencies
- Upstream: `ReceiptResolutionService.resolve` liefert den initialen `matchedItemID`-Wert, mit dem
  `.currentName` beim Öffnen der Karte entsteht — unverändert von diesem Fix.
- Downstream: `ReceiptScannerView.save()` liest `matchedItemID`, ungeprüft gegen den Namen.

## Existing Specs
- `docs/specs/views/receipt-review-card.md` — Spec der Bon-Karte; die Regeln 1–11 zur
  Optionsbildung sind dort dokumentiert und bleiben unverändert. Der Fix ergänzt eine neue Regel
  für den `.currentName`-Auswahl-Effekt.

## Risks & Considerations
- **Kein Datenverlust durch `nil`-Setzen** (siehe oben) — größtes Risiko wäre sonst, eine echte
  Zuordnung zu zerstören; das ist ausgeschlossen, weil der Namens-Fallback in `save()` greift.
- **Reihenfolge mit #66:** Der Adversary-Dialog zu #67 selbst weist darauf hin, dass ein damaliger
  Fix für #66 `.currentName`-Zeilen häufiger erzeugen würde. #66 ist mittlerweile geschlossen
  (2026-09-28) — die Exposition dieses Fehlers ist also bereits erhöht, der Fix ist entsprechend
  relevanter als zum Zeitpunkt der Erstmeldung.
- **Scope:** Eine Datei Produktivcode (`ReceiptReviewCard.swift`), eine Testdatei. Weit innerhalb
  der Scoping-Grenzen.

## Analysis

### Type
Bugfix

### Root Cause (verifiziert im Code, Stand dieser Analyse)
`ReceiptReviewCard.applySelection` (Zeile 511–531) behandelt vier Auswahl-Fälle. Drei davon
setzen `matchedItemID`/`resolvedByAI` explizit (`.listMatch`, `.aiSuggestion`, `.receiptText`);
der vierte, `.currentName` (Zeile 524–525), setzt ausschließlich `line.name` und lässt beide
Felder unverändert:
```
case .currentName(let name):
    line.name = name
```
`ReceiptScannerView.save()` (Zeile 636ff.) liest `line.matchedItemID`, wenn gesetzt, **ohne
Namensabgleich** (Zeile 636–637: `store.items?.first(where: { $0.id == id })`) und schreibt den
Bonpreis auf das damit gefundene Item. Stand eine `matchedItemID` aus einer zuvor gewählten,
anderen Option noch im State, wenn der Nutzer danach zur `.currentName`-Zeile zurückwechselt,
gewinnt bei `save()` diese fremde ID — der Name in der UI zeigt bereits den anderen Wert, die
Preis-Zuordnung folgt aber der alten ID.

Bestätigt: `RestockTests/ReceiptReviewCardTests.swift` deckt `.listMatch`, `.aiSuggestion`,
`.receiptText` und `.custom` je mit einem Test ab, der genau dieses Feld prüft — für
`.currentName` existiert kein solcher Test (Lücke, die den Fehler verdeckt hat).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|--------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | `.currentName`-Zweig in `applySelection` (Zeile 524–525) setzt zusätzlich `matchedItemID = nil` und `resolvedByAI = false` — exakt das Muster von `applyCustomName`/`.receiptText`. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Neuer Test: nach Auswahl von `.aiSuggestion` (setzt `matchedItemID`) zurück zu `.currentName` wechseln → `matchedItemID == nil` und `resolvedByAI == false`. |

### Scope Assessment
- Files: 2
- Estimated LoC: +~20 / -0 (1 Zeile Produktivcode-Ergänzung, ein neuer Test)
- Risk Level: NIEDRIG — isolierte Ein-Zeilen-Änderung, bestehendes Muster wird wiederholt, kein neuer Zustand

### Technical Approach
`.currentName`-Zweig um dieselben zwei Zuweisungen erweitern, die `applyCustomName` bereits für
den strukturell identischen Fall macht:
```
case .currentName(let name):
    line.name = name
    line.matchedItemID = nil
    line.resolvedByAI = false
```
Begründung für „sicher, kein Datenverlust": `save()` fällt bei `matchedItemID == nil` auf eine
exakte Namenssuche über abgehakte Artikel desselben Stores zurück (Zeile 653–655) — trägt der
gerade geltende Name tatsächlich zu einem abgehakten Artikel, wird er darüber wiedergefunden,
nur eben über den korrekten aktuellen Namen statt über eine stehengebliebene fremde ID.

### Dependencies
Keine neuen. Wie im Kontext dokumentiert: `ReceiptResolutionService.resolve` (upstream) und
`ReceiptScannerView.save()` (downstream) bleiben unverändert.

### Open Questions
Keine — Root Cause ist im Code verifiziert, Fix folgt einem bereits etablierten Muster in
derselben Funktion, Fallback-Sicherheit ist durch bestehenden Code (`save()`-Namenssuche) belegt.
