# Context: fix-37-receipt-name-preselect

## Request Summary

Issue #37: Trägt eine Bon-Zeile bereits einen Namen (z. B. „Milch") und passen dazu mehrere
Artikel der Liste (Hafermilch, Buttermilch, Vollmilch), zeigt die Bon-Prüf-Karte nur die drei
Treffer plus „Anderer Name …". Der bereits eingetragene Name selbst steht weder zur Auswahl noch
ist irgendeine Zeile vorausgewählt — Widerspruch zu AC-4 der Spec („Der beste Treffer / aktuelle
Zustand der Zeile ist vorausgewählt."). Die Lücke ist bekannt, dokumentiert und bewusst mit
wörtlicher Spec-Umsetzung in #23 hingenommen worden; jetzt ist die PO-Entscheidung fällig.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift:399-427` | `selectionOptions(for:)` — die reine Regel-Funktion (Regeln 1–6), hier klafft die Lücke zwischen Regel 3 (Vorauswahl nur bei Namensgleichheit) und Regel 5 (`.currentName` nur wenn *kein* Kandidat existiert) |
| `RestockTests/ReceiptReviewCardTests.swift` | Bestehende Unit-Tests für `selectionOptions`, exaktes Testmuster (`makeLine`, `describe`) für neue Fälle wiederverwendbar |
| `docs/specs/views/receipt-review-card.md` | AC-4, AC-2, Invariante 5 (max. 3 inhaltliche Optionen), Test Plan — muss um den neuen Fall ergänzt werden |
| `docs/context/feat-23-receipt-review-screen.md:326-337` | Ursprünglicher Befund („Regellücke"), nennt exakt dieselben zwei Alternativen wie #37 |
| `SmartCart/Services/ReceiptResolutionService.swift` | Liefert `suggestions`/`aiSuggestedName` — unverändert, nur Konsument der Lücke, nicht ihre Quelle |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:540-662` (`save()`) | Invariante 1 der Spec: bleibt unverändert — Auswahl beeinflusst nur `name`/`matchedItemID`/`resolvedByAI`, nicht den Lernpfad |

## Existing Patterns

- Reine, ohne SwiftUI testbare Funktionen für alle Karten-Regeln (`selectionOptions`,
  `applySelection`, `applyCustomName`, `priceSummary`, …) — neue Logik gehört in dasselbe Muster,
  kein View-State nötig.
- `ReceiptNameOption` hat bereits einen Fall `.currentName(name:)` für genau diesen Zweck — er wird
  heute nur erreicht, wenn `candidates.isEmpty` ist (Regel 5). Die Erweiterung ist eine
  Bedingungsänderung, kein neuer Optionstyp.
- Tests folgen strikt GIVEN/WHEN/THEN mit AC-Verweis in der Testmethode/im Kommentar (siehe
  Test Plan der Spec).

## Dependencies

- Upstream: `EditableReceiptLine.name/suggestions/aiSuggestedName` — Datenquelle für
  `selectionOptions`, unverändert.
- Downstream: `ReceiptReviewCard.body`/`optionRow` rendert `options` 1:1 — keine Änderung an der
  View selbst erwartet, nur an der Regel-Funktion, die sie füttert.

## Existing Specs

- `docs/specs/views/receipt-review-card.md` — AC-4 (Vorauswahl), AC-2 (max. 4 Auswahlzeilen),
  Invariante 5 (max. 3 inhaltliche Optionen). Diese Spec wird erweitert, kein neues Dokument.

## Risiken & Alternativen (aus dem Issue, für die Analyse-Phase)

1. **Empfehlung (Issue):** Den bereits eingetragenen Namen immer als erste Auswahlzeile anbieten
   und vorauswählen, wenn kein Kandidat ihm entspricht — dabei entfällt bei bereits drei Treffern
   einer davon (Invariante 5/AC-2 bleiben gewahrt, „eine Auswahlzeile mehr" ist der Kostenpunkt).
2. **Alternative A:** AC-4 einschränken — festschreiben, dass Karten ohne Vorauswahl vorkommen
   dürfen. Ehrlicher gegenüber dem Ist-Zustand, löst das Nutzerproblem aber nicht.
3. **Alternative B:** Den aktuellen Namen nur in der Kopfzeile anzeigen (Zusatztext neben dem
   Bontext), nicht als wählbare Option — kostet keine Zeile, aber der Zustand ist dann nicht per
   Tipp wiederherstellbar, falls versehentlich eine andere Option gewählt wurde.

Die Entscheidung zwischen diesen dreien ist eine echte PO-Entscheidung (Produktverhalten, kein
Implementierungsdetail) und gehört in `/20-analyse` vor die Spec-Erweiterung.

## Analysis

### Type
Bug

### PO-Entscheidung (2026-09-24)
Empfehlung 1 aus dem Issue gewählt: **Der geltende Name wird zusätzlich als eigene, vorausgewählte
Zeile angeboten.** Beispiel aus der Rückfrage: Gilt für eine Position bereits „H-Milch" und die drei
angezeigten Alternativen sind „Hafermilch/Buttermilch/Vollmilch", muss „H-Milch" selbst als vierte,
angehakte Auswahlmöglichkeit erscheinen — nicht nur die drei textähnlichen Treffer. Alternative A
(Vorauswahl aufgeben) und Alternative B (nur Hinweistext) sind damit verworfen.

### Root Cause (bestätigt, siehe Gegenprüfung durch `analysis-challenger`)
`SmartCart/Views/Prices/ReceiptReviewCard.swift:399-427`, `selectionOptions(for:)`: Schritt 3
(Vorauswahl) greift nur, wenn ein Kandidat namensgleich mit `line.name` ist; Schritt 5 (Fallback auf
`.currentName`) greift nur, wenn `candidates.isEmpty` ist. Gibt es ≥1 Kandidaten, von denen aber
keiner `line.name` entspricht, fällt der geltende Name komplett durch — weder anwählbar noch
vorausgewählt. Exakt reproduziert am Beispiel `name: "Milch"` mit Treffern „Hafermilch/Buttermilch/
Vollmilch/Kondensmilch/Reismilch" (deckungsgleich mit dem bestehenden, aber lückenhaften Test
`ReceiptReviewCardTests.swift:146-156`, der nur die Anzahl, nicht die Vorauswahl prüft). Die Lücke
steckt bereits in der Spec selbst (Regeln 3/5 in `docs/specs/views/receipt-review-card.md:135-139`),
nicht nur im Code — AC-4 ist für diesen Fall bisher nicht eindeutig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | `selectionOptions(for:)`: neue Regel — kein Kandidat entspricht `line.name` UND `line.name` ist nicht leer → geltenden Namen als `.currentName(line.name)` an Position 0 einfügen, dafür den schwächsten der bis dahin bis zu 3 Kandidaten (letzte Position, da `suggestions` bereits nach Relevanz sortiert ankommen) fallen lassen. Ergebnis bleibt bei max. 3 inhaltlichen Optionen + `.custom` (Invariante 5/AC-2 unverändert). |
| `docs/specs/views/receipt-review-card.md` | MODIFY | AC-4 präzisieren und Regel 3/5 in „Implementation Details" um den neuen Fall ergänzen (Reihenfolge der Prüfung: Namensgleichheit → sonst geltenden Namen einfügen+vorausw. → sonst `.currentName`-Fallback bei leeren Kandidaten bleibt wie heute). |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Neue Fälle: (a) 3 Treffer, keiner passt zu `line.name` → `line.name` erscheint vorausgewählt, ein Treffer entfällt; (b) `line.name` leer → bisheriges Verhalten (kein zusätzlicher Kandidat, kein Absturz); (c) bestehender Test `testFiveSuggestionsAreCappedToThreeListMatches` um eine Vorauswahl-Assertion ergänzen, da er das Symptom-Szenario bereits konstruiert, es aber bisher nicht prüft. |

### Scope Assessment
- Files: 3
- Estimated LoC: ≈ +25/-5 (reine Regeländerung in einer Funktion + Spec-Text + 2-3 neue Unit-Tests) — deutlich innerhalb des Standard-Scoping-Limits.
- Risk Level: LOW — isolierte, bereits heute pure/testbare Funktion ohne SwiftUI-State, keine Berührung von `save()`, `ReceiptResolutionService` oder Wire-Formaten.

### Technical Approach
Die Korrektur bleibt eine reine Bedingungserweiterung in `selectionOptions(for:)`, kein neuer
Optionstyp (`.currentName` existiert bereits). Nach Schritt 4 (Kappung auf 3) zusätzlich prüfen: Ist
`line.name` nicht leer und unter den verbliebenen Kandidaten nicht vertreten? Dann `.currentName(line.name)`
an Position 0 einsetzen und den letzten Kandidaten (Index 2) entfernen — Ergebnis bleibt bei
höchstens 3 inhaltlichen Kandidaten. Ist `line.name` leer, bleibt das heutige Verhalten unverändert
(kein zusätzlicher Kandidat).

### Dependencies
Unverändert gegenüber „Related Files"/„Dependencies" oben — keine neuen Abhängigkeiten durch die
PO-Entscheidung.

### Open Questions
Keine offenen Fragen mehr.
