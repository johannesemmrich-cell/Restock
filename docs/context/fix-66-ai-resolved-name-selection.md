# Kontext: Issue #66 — Bon-Karte, kein markierter Kreis bei wortgleicher KI-Auflösung

## Ausgangslage

GitHub Issue #66 (gefunden im Adversary-Prüfdialog zu #50, Paket 1, Befund F001, HIGH):
Steht ein Artikel **unabgehakt** auf der Liste eines Ladens und löst Stufe 5
(Apple Intelligence) das Bonkürzel auf **genau diesen Namen** auf, zeigt
`ReceiptReviewCard` keinen markierten Auswahlkreis, obwohl oben der korrekte Name steht.
Alltagsfall: „Butter" steht unabgehakt auf der Liste, Bonzeile „BTR" wird zu „Butter"
aufgelöst.

Root Cause (im aktuellen Code nachvollzogen, Stand `654e692`):
- `ReceiptResolutionService.resolve` (`SmartCart/Services/ReceiptResolutionService.swift:75-195`)
  verknüpft eine Zeile nur dann mit einem Listenartikel (`matchedItemID`), wenn das VOR
  Stufe 5 geschieht (Zeilen 120-141 laufen gegen den Vor-KI-Namen). Für eine Zeile, die
  erst die KI auflöst, bleibt `matchedItemID` deshalb `nil`.
- `ReceiptReviewCard.selectionOptions`/`isSelected` (`SmartCart/Views/Prices/ReceiptReviewCard.swift:388-484`)
  verlangt für eine markierte `.listMatch`-Zeile `!line.resolvedByAI && line.matchedItemID
  == suggestion.itemID`. Die Dedup-Regel 2 hat die `.aiSuggestion`-Zeile vorher schon
  entfernt (namensgleicher `.listMatch` vorhanden) — Ergebnis: keine Zeile markiert.

Eine frühere Sitzung hatte den Fall bereits vollständig durchdacht
(`docs/specs/views/receipt-review-card-nachtrag-1b.md`, „Paket 1b"). Davon ist nur der
Teil zu F002 (Leerzeichen-Rückfall) umgesetzt (`676eb9d`); der Teil zu F001 (dieses
Issue) wurde bewusst zurückgestellt, weil er eine sichtbare Gestaltungsentscheidung ist
(Regel „Entwurf vor Spec bei UI-Änderungen").

## Entwurfsphase (PO-Entscheidung 2026-09-28)

Vorschau veröffentlicht: `docs/artifacts/fix-66-ai-resolved-name-selection/entwurf.html`
(Heute vs. Entwurf A/B, Hell/Dunkel-Umschalter, echte App-Farbtokens).

Drei Varianten verglichen:
- **Entwurf A** — der namensgleiche Listen-Treffer gilt als markiert, auch ohne
  bestehende `matchedItemID`-Verknüpfung. Eine sichtbare Zeile, aber „markiert" bedeutet
  dann nicht mehr zwingend „verknüpft".
- **Entwurf B** (aus Paket 1b vorbereitet) — die KI-Zeile bleibt zusätzlich zum
  Listen-Treffer stehen, trägt die Markierung; ein Tap auf den Listen-Treffer stellt die
  Verknüpfung her. Kostet eine zweite Zeile mit gleichem Namen.
- **Entwurf C** — Wurzelfix in `ReceiptResolutionService`: den `matchedItemID`-Nachgriff
  nach Stufe 5 wiederholen. Sieht wie Entwurf A aus, ändert aber zusätzlich das
  automatische Lernverhalten für unabgehakte Artikel (Invariante 1/AC-12 betroffen).

**PO-Entscheidung:** Entwurf B verworfen (Doppelname). Entwurf C verworfen (Eingriff in
automatische Preis-Zuordnung). **Entwurf A gewählt**, ergänzt um einen vom PO
vorgeschlagenen Mechanismus: Das ohnehin vorhandene Feld „Anderer Name …" — das beim
Antippen bereits mit `line.name` (dem aktuell aufgelösten Namen, nicht dem rohen
Bontext) vorbelegt wird, unverändert lösch-/überschreibbar — übernimmt die Reparatur.
Bestätigt der Nutzer einen Namen, der exakt (case-insensitiv) zu einem `line.suggestions`-
Eintrag passt, wird `matchedItemID` auf dessen `itemID` gesetzt statt auf `nil`
(`applyCustomName`/`applyCustomNameOrFallback`). Keine neue sichtbare Zeile, keine
Änderung an der Vorbelegung selbst.

**Warum das Entwurf C vorgezogen wird:** Die Verknüpfung entsteht nur, wenn der Nutzer
aktiv einen Namen bestätigt — nie automatisch beim Einlesen eines unabgehakten Artikels.
`ReceiptResolutionService`, `save()` und das Lernverhalten bleiben unberührt.

## Analysis

### Type
Bug (mit einer visuellen Gestaltungsentscheidung, siehe oben)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | Markierungsregel für `.listMatch` gelockert (kein `!resolvedByAI`-Erfordernis mehr, `matchedItemID == suggestion.itemID \|\| matchedItemID == nil`); `applyCustomName`/`applyCustomNameOrFallback` gleichen den bestätigten Namen gegen `line.suggestions` ab und setzen `matchedItemID`, statt es immer auf `nil` zu setzen; Regel 9 (`onChange(of: line.name)`) zusätzlich an `matchedItemID`/`resolvedByAI` gehängt (schließt die in #66 Punkt (b) benannte Restlücke). |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Neue/angepasste Unit-Tests für die gelockerte Markierung, das Verknüpfen beim Bestätigen eines passenden Namens, und Regel 9 mit `matchedItemID`/`resolvedByAI`-Änderung ohne Namensänderung. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY (ggf.) | Falls ein neuer Seed nötig ist, um den KI-Zweig ohne Apple Intelligence im Simulator zu zeigen — offene Frage, siehe unten. |

### Scope Assessment
- Files: 2-3
- Estimated LoC: ungefähr +60/-15 (kleiner als die verworfene Paket-1b-Variante B, da keine
  Umsortierung/Platzierungslogik nötig ist)
- Risk Level: NIEDRIG — reine, ohne SwiftUI testbare Funktionen einer Datei; `save()`,
  Wire-Formate und `ReceiptResolutionService` bleiben unberührt.

### Technical Approach
1. Markierungsregel für `.listMatch` in `isSelected`/einer neuen reinen Hilfsfunktion
   (ähnlich `isSelectedIgnoringCustom` aus Paket 1b, aber mit gelockerter Bedingung statt
   der dort vorgesehenen Beibehaltung der KI-Zeile) lockern.
2. `applyCustomName` erhält einen Namensabgleich gegen `line.suggestions`
   (case-insensitiv) und setzt bei Treffer `matchedItemID` statt `nil`; `resolvedByAI`
   bleibt `false` (der Nutzer hat aktiv bestätigt, kein KI-Signal mehr).
3. Regel 9 (`onChange(of: line.name)`) deckt weiterhin nur Namensänderungen ab —
   Issue #66 Punkt (b) fordert zusätzlich eine Reaktion auf reine
   `matchedItemID`/`resolvedByAI`-Änderungen ohne Namensänderung. Wird im selben Zug
   mitbehoben (kleiner, unabhängiger Korrektheits-Nachtrag, keine Gestaltungsfrage).

### Dependencies
Keine. Ausdrücklich NICHT geändert: `ReceiptResolutionService.swift`,
`ReceiptScannerView.swift` (`save()`, `isSavable`), `SmartCartApp.swift`, `project.pbxproj`.

### Nachweisbarkeit — offene Frage für die Spec
Der KI-Zweig (Stufe 5) braucht Apple Intelligence, im Simulator nicht verfügbar. Die
Markierungsregel und der neue Namensabgleich sind als reine Funktionen ohne SwiftUI
unit-testbar (deckt den Kern von #66 ab). Ob zusätzlich ein neuer DEBUG-Seed für einen
Bildschirm-Nachweis des kompletten KI-Zweigs angelegt wird, klärt `/30-write-spec`.

### Open Questions
- [ ] Exakte Formulierung der gelockerten Markierungsregel für den Sonderfall „zwei
  verschiedene Listenartikel mit identischem Namen" (vorbestehende Randbedingung, siehe
  `receipt-review-card-nachtrag-1b.md`, Regel 5) — wird in der Spec präzisiert.
- [ ] Neuer DEBUG-Seed für Bildschirm-Nachweis des KI-Zweigs: ja/nein (siehe oben).
