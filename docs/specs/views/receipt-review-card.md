---
entity_id: receipt-review-card
type: feature
created: 2026-09-22
updated: 2026-09-27
status: draft
workflow: fix-50-import-dialog-design
workflow_history: [feat-23-receipt-review-screen, fix-37-receipt-name-preselect]
tags: [feature, ui, receipt-scanner]
---

# Bon-Prüf-Screen: Positionen als Karte mit Auswahl statt Tippen

## Approval

- [ ] Approved

## Purpose

Ersetzt die heutige, unlesbare Zeile im Bon-Prüf-Screen (`ReceiptLineRow` — Namen abgeschnitten,
KI-Pille bricht vierzeilig um, Bontext gar nicht sichtbar) durch eine Karte je Position: oben der
gedruckte Bontext und eine antippbare Auswahl des richtigen Artikelnamens (Listen-Treffer,
KI-Vorschlag, eigener Name), unten eine Preiszeile mit Menge/Gewicht und berechnetem Stück-/
Kilopreis. Macht den Bon-Import erstmals auf dem iPhone verlässlich prüfbar — laut PO bisher
„wertlos", solange dieser Screen unlesbar ist (Issue #23).

## Source

- **File:** `SmartCart/Views/Prices/ReceiptReviewCard.swift` (neu)
- **Identifier:** `struct ReceiptReviewCard`, `enum ReceiptNameOption`,
  `static func selectionOptions(for:)`, `static func priceSummary(for:)`,
  `static func applyQuantityEdit(_:mode:value:)`, `static func sectionHeaderText(count:selected:sum:)`

## Problem und Design-Grundlage

Vollständige Ursachenanalyse und der freigegebene Entwurf stehen in
`docs/context/feat-23-receipt-review-screen.md`. Verbindlich für diese Spec ist ausschließlich der
letzte Abschnitt dort: „PO-Freigabe Entwurf (2026-09-22): Variante B · Auswahl statt Tippen" plus
die vier „PO-Entscheidungen (2026-09-22, Phase 2)". Visuelle Referenz:
`docs/artifacts/feat-23-receipt-review-screen/entwurf-zeile.html`, Abschnitt „B · Auswahl statt
Tippen" (Dark und Light umschaltbar).

**Reihenfolge, verbindlich:** A (#28, Testeinstieg) → B (#23, diese Spec) → C (#29,
Vorschlags-Regel). #28 ist zum Zeitpunkt dieser Spec noch OPEN/nicht umgesetzt — siehe
„Dependencies" und „Risiken".

**Nachtrag Issue #37 (2026-09-24):** Die ursprüngliche Fassung dieser Spec (Regeln 3/5 in
„Implementation Details" Abschnitt 2) ließ eine Lücke: Entspricht keiner der bis zu 3 angezeigten
Kandidaten-Zeilen dem aktuell geltenden Namen der Position, war dieser Name weder anwählbar noch
vorausgewählt — Widerspruch zu AC-4. Vollständige Ursachenanalyse und PO-Entscheidung dazu stehen in
`docs/context/fix-37-receipt-name-preselect.md`. Diese Spec-Erweiterung schließt die Lücke; siehe
neue Regel 5 unten, präzisiertes AC-4 und den erweiterten Test Plan.

**Nachtrag Issue #50, Paket 1 (2026-09-27):** Issue #50 („Import Dialog entspricht nicht dem
Design") meldete Punkt 2 („Anderer Name" zeigt den oft sinnvollen Vorschlag erst nach Auswahl") und
Punkt 4 („keine Option markiert"). Ursachenanalyse in `docs/context/fix-50-import-dialog-design.md`
(Abschnitte „Befund", „Analysis" und „Nachtrag") zeigt: `@State options` (Abschnitt 5 unten) wird
zwar bewusst eingefroren (siehe dortiger Kommentar), führt sich aber NIE nach, wenn `line.name`
sich von AUSSEN ändert — insbesondere durch `ReceiptScannerView.reResolveAIIfNeeded()` beim
Teilen-Handoff, das NACH dem ersten Zeichnen der Karte läuft. Dabei entdeckt (PO-Hinweis
2026-09-27): derselbe Mechanismus lässt sich zweitens auch rein lokal auslösen, wenn der Nutzer
das vorbelegte Feld „Anderer Name …" bis auf null Zeichen leert — Issue #50 bekommt dadurch eine
dritte Zusage. Issue #50 ist zweigeteilt (PO-Entscheidung 2026-09-27): **Paket 1** (diese
Erweiterung) behebt Punkt 2 und Punkt 4 sowie den PO-Fund; **Paket 2 (Issue #65, NICHT Teil
dieser Erweiterung)** macht den Bontext lesbar (15 pt, `Color.ink`), kopierbar
(`.contextMenu`) und als eigene, antippbare Auswahlzeile „wie auf dem Bon" verfügbar — dafür ändert
sich Invariante 5 (max. 3 inhaltliche Optionen), was Paket 1 ausdrücklich NICHT tut: es fügt
keine neue Options-Zeile hinzu und verschiebt daher keinen `option.<k>`-Index. Details, Regeln
9-11 und der erweiterte Test Plan: Abschnitt „Nachtrag Issue #50, Paket 1" unten.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| Issue #28 (Testeinstieg: `-seedReceiptReviewForUITests`, `RestockUITests/ReceiptReviewUITests.swift` Grundgerüst, erste `accessibilityIdentifier`s) | Voraussetzung | Liefert den einzigen OCR-freien, reproduzierbaren UI-Test-Einstieg (Sheet öffnet über den echten Weg `HomeView.checkPendingReceiptScan()`). Ohne #28 gibt es keinen RED-Nachweis für diese Spec — B kann nicht vor A starten. |
| Issue #29 (Vorschlags-Regel, Schwelle 0,45, Limit 3) | Unabhängig, folgt später | Liefert bessere Listen-Treffer für die Auswahlzeilen. B funktioniert bereits mit dem heutigen Floor 0,2/Limit 5 — die Karte selbst kappt auf max. 3 inhaltliche Optionen (siehe Implementation Details), unabhängig davon, wie viele `suggestions` der Service liefert. |
| `ReceiptResolutionService.resolve` (`ReceiptResolutionService.swift:74-194`) | Service | Liefert `suggestions: [ReceiptSuggestion]`, `matchedItemID`, `resolvedByAI` je Zeile — unverändert konsumiert, keine Änderung an diesem Service in dieser Spec. |
| `EditableReceiptLine` (`ReceiptScannerView.swift:11-90`) | Model | Trägerstruktur der Zeile; bekommt zwei neue, NICHT-Codable Felder (siehe Implementation Details). |
| `ItemRow.swift:37-61` (Häkchen-Kreis) | View-Pattern | Vorlage für das 28-pt-Häkchen der Karte — gleiches visuelles Muster, andere Größe. |
| `DesignSystem.swift` (`Color.ink/.textSecondary/.surface/.hairline/.accent/.accentContainer`, `RCRadius`, `cardStyle()`, `PressableButtonStyle`) | Design-Tokens | Einzige erlaubte Farb-/Radius-Quelle — keine neuen Tokens. |
| `ReceiptParserService.weightBasisFromName` (`ReceiptParserService.swift:894-909`) und `EditableReceiptLine.learningQuantity` (`ReceiptScannerView.swift:58-60`) | Regel | Bestehende Regel für die im Bontext gedruckte Füllmenge — `priceSummary` nutzt sie unverändert, damit die Anzeige dieselbe Basis zeigt, mit der `save()` lernt. Keine Änderung an beiden. |
| `ReceiptScannerView.save()` (`ReceiptScannerView.swift:600-…`) | Downstream Consumer | Semantik von `name`/`matchedItemID`/`resolvedByAI`/`originalName` darf sich durch diese Spec nicht ändern. **Seit Issue #50, Paket 1 (2026-09-27) eine gezielte Ausnahme:** `save()` überspringt eine Position mit leerem Namen vollständig (siehe „Nachtrag Issue #50, Paket 1", Regel 11) — bewusste, punktuelle Änderung von Invariante 1, keine sonstige Berührung von `save()`. |
| `ResolvedReceiptLine`/`ReceiptSuggestion` (`ReceiptResolutionService.swift:8-44`) | Wire-Format | Unverändert. Die neuen `EditableReceiptLine`-Felder sind bewusst NICHT Teil dieser `Codable`-Typen (rein UI-lokaler Zustand, keine Prozessgrenze). |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | CREATE | Neue Karten-View + `ReceiptNameOption` + drei reine, testbare Funktionen (`selectionOptions`, `priceSummary`, `sectionHeaderText`) + `accessibilityIdentifier`s. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `private struct ReceiptLineRow` entfernen (Z. 667-776); `EditableReceiptLine` um zwei neue Felder erweitern (Z. 42 ff.) und an allen drei Konstruktionsstellen setzen (Z. 147-167, 521-534, 79-89); `reviewView` (Z. 355-462): Section-Header/Footer ersetzen, separate „Ausgewählt"-Section (Z. 443-451) entfernen (im neuen Section-Kopf enthalten), `ForEach` auf `ReceiptReviewCard` umstellen, Listenzeilen-Darstellung auf Karten umstellen (`listRowBackground`/`listRowSeparator`/`listRowInsets`). |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung von zwei neuen Swift-Dateien (`ReceiptReviewCard.swift`, `ReceiptReviewCardTests.swift`) an je 4 Stellen (CLAUDE.md) — kein Auto-Discovery. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Aufbauend auf dem Grundgerüst aus #28: Tests für Karten-Interaktion ergänzen (Bontext, KI-Marke, Auswahlzeilen, „Ändern", Häkchen, Section-Kopf, Speichern-Nachweis). |
| `RestockTests/ReceiptReviewCardTests.swift` | CREATE | Unit-Tests für `selectionOptions`, `priceSummary`, `sectionHeaderText` und die Auswahl-Semantik. |

### Estimated Changes
- Files: 5 (am oberen Ende des Scoping-Limits „max. 4-5 Dateien")
- LoC: ≈ **+590 / −130** (≈ 720 gesamt) — **reißt das Standard-Scoping-Limit von ±250 LoC**
  deutlich. Aufschlüsselung: `ReceiptReviewCard.swift` ≈ +230 (Karten-View, Mengen-Editor + vier reine
  Funktionen + Optionstyp); `ReceiptScannerView.swift` ≈ +55/−120 (Zeile raus, zwei neue Felder,
  drei Konstruktionsstellen angepasst, Section-Umbau); `project.pbxproj` ≈ +16 (zwei Dateien × 4
  Stellen); `ReceiptReviewUITests.swift` ≈ +115 (neun UI-Tests, siehe Test Plan);
  `ReceiptReviewCardTests.swift` ≈ +175 (achtzehn Unit-Tests). Der Mengen-Editor (≈ +40 View, +35 Tests) ist
  auf PO-Wunsch vom 2026-09-22 enthalten; der Rest der Überschreitung kommt aus der Karte selbst
  (Auswahlliste statt einer Zeile) und aus den laut Testing-Strategie verpflichtenden Unit- und
  UI-Tests, nicht aus vermeidbarem Zusatzumfang. **Empfehlung an den PO:
  Überschreitung bewusst akzeptieren** (die dreistufige Aufteilung A/B/C wurde am 2026-09-22
  bereits genau mit dieser Begründung getroffen), alternativ weitere Aufteilung von B in
  Karten-UI+Unit-Tests vs. UI-Test-Vertiefung erwägen.

### Out of Scope
- **Issue #50, Paket 2 (Issue #65) — gehört ausdrücklich NICHT zu dieser Erweiterung:**
  - Bontext von 13 pt / `Color.textSecondary` auf 15 pt / `Color.ink`.
  - Kontextmenü „Kopieren" am Bontext.
  - Bontext als eigene, antippbare Auswahlzeile „wie auf dem Bon" mit wortweiser Großschreibung.
  - Jede Änderung an Invariante 5 („höchstens 3 inhaltliche Optionen") und an
    `ReceiptParserService`.

  Paket 1 fügt bewusst keine neue Options-Zeile hinzu und verschiebt daher keinen `option.<k>`-
  Index — eine zusätzliche Auswahlzeile ist genau der Schnitt, der Paket 2 vorbehalten bleibt.
- **Größe (`unit`, z. B. „400g") editierbar machen.** Der Mengen-Editor ändert Stückzahl oder
  Gewicht; die im Bontext gedruckte Füllmenge bleibt Anzeige. Wer sie korrigieren will, wechselt
  auf „Gramm" und trägt das Gewicht ein (überschreibt die Füllmenge als Lernbasis, siehe
  `learningQuantity`).
- **Vorschlags-Regel (Floor/Limit) ändern.** Bleibt #29; diese Karte konsumiert `suggestions`
  unverändert und kappt selbst auf max. 3 inhaltliche Optionen.
- **Lokalisierung.** Alle Strings bleiben hart auf Deutsch im Swift-Code, wie im gesamten Screen
  heute (kein `String(localized:)`).
- **Testeinstieg selbst (#28).** Das Seed-Launch-Argument, das erste UI-Test-Grundgerüst und die
  ersten `accessibilityIdentifier`s werden hier vorausgesetzt, nicht gebaut.
- **`ReceiptResolutionService`/`ReceiptParserService`.** Keine Änderung an Auflösung, Schwellen
  oder Formaterkennung.

### Scope-Erweiterung (Issue #37 — 2026-09-24)

Korrektur der unter „Nachtrag Issue #37" beschriebenen Regellücke. Deutlich unterhalb des
Standard-Scoping-Limits, da rein additive Bedingungserweiterung in einer bereits bestehenden,
reinen Funktion.

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | Nur `selectionOptions(for:)`: neue Regel 5 (siehe „Implementation Details" Abschnitt 2) zwischen der bisherigen Kappung auf 3 (Regel 4) und dem Leer-Fallback (jetzt Regel 6). Keine andere Funktion/View betroffen. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Zwei neue Testfälle (Kandidat-Mismatch mit gesetztem `line.name`; Kandidat-Mismatch mit leerem `line.name` als Regressionsschutz) sowie eine ergänzte Vorauswahl-Assertion im bestehenden Test `testFiveSuggestionsAreCappedToThreeListMatches`. |

- Files: 2
- LoC: ≈ **+25 / −5** — deutlich unter dem Standard-Scoping-Limit von ±250 LoC.
- Risk Level: LOW — isolierte, bereits heute pure/testbare Funktion ohne SwiftUI-State, keine
  Berührung von `save()`, `ReceiptResolutionService` oder Wire-Formaten.

### Scope-Erweiterung (Issue #50, Paket 1 — 2026-09-27)

Behebt Punkt 2 und Punkt 4 aus Issue #50 sowie den während der Analyse gefundenen dritten Fall
(leerer Name über „Anderer Name …"). Siehe „Nachtrag Issue #50, Paket 1" unten für die volle
Herleitung, Regeln 9-11, Invarianten und den Test Plan.

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | `.onChange(of: line.name)` führt die eingefrorenen `options` nach, wenn keine Option mehr zu `line.name` passt (Regel 9); neuer `@State private var previousSelectionBeforeCustom`, in `select(_:)` beim Betreten von `.custom` gesetzt (Regel 10); neue reine Funktion `applyCustomNameOrFallback(_:name:previousSelection:)` neben dem bestehenden `applyCustomName` (Regel 10); `customNameRow()`s `.onChange(of: customName)` ruft die neue Funktion statt `applyCustomName` direkt. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | Neue reine Regel `EditableReceiptLine.isSavable(_:)` direkt neben `learningQuantity`/`learningUnit`; `save()`s Eingangsfilter (`parsedLines.filter { $0.isIncluded && $0.price > 0 }`, Z. 601) ruft sie statt der inline-Bedingung (Regel 11). |
| `SmartCart/SmartCartApp.swift` | MODIFY | Neuer, eigenständiger DEBUG-Seed `seedReceiptReviewUnresolvedLineForUITestsIfNeeded(context:)` — Testeinstieg für den reproduzierten Fall. Vollständig beschrieben in `docs/specs/testing/receipt-review-test-entry.md`, „Nachtrag Issue #50, Paket 1"; hier nur referenziert, weil diese Spec keine Testinfrastruktur-Entscheidungen trifft. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Drei neue Tests für `applyCustomNameOrFallback`: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName` (leerer Name fällt zurück), `testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName` (KI-Zustand — `matchedItemID` UND `resolvedByAI` — wird mit zurückgeholt), `testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged` (nicht-leerer Name verhält sich wie bisher). |
| `RestockTests/ReceiptScannerReResolutionTests.swift` | MODIFY | Zwei neue Tests für `isSavable`: `testIsSavableRejectsLineWithEmptyName` (leerer oder nur aus Leerzeichen bestehender Name → `false`) und `testIsSavableKeepsIncludedNamedLineAndRejectsOldCases` (nicht-leerer Name mit Preis → `true`; abgewählt oder Preis 0 → weiterhin `false`). |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Zwei neue Tests, `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` (derselbe Testname wie „Test 3" in `docs/specs/testing/receipt-review-test-entry.md` — es entsteht nur EIN Test) und `testClearingCustomNameFieldKeepsPreviousItemName`. Erster Test am reproduzierten Fall (BTR-Zeile über den neuen Seed): nach `reResolveAIIfNeeded()` ist genau eine Auswahlzeile markiert, und ihr Label zeigt den aufgelösten Namen. Neuer Test für den PO-Fund: vollständiges Leeren von „Anderer Name …" lässt das Häkchen-Label nie mit einem leeren Namen enden. |

- Files: **6** — eine Datei über dem Ziel „max. 4-5 Dateien". Die Überschreitung kommt vom
  `isSavable`-Unit-Test: er gehört inhaltlich zu `ReceiptScannerView` (`save()`s
  Fallback-Suche), nicht zur Karte — `ReceiptReviewCardTests.swift` prüft laut eigenem
  Kopfkommentar „ausschließlich die reinen Funktionen der Karte". Verworfene Alternative: beide
  Tests trotzdem in dieselbe Datei zwingen, um bei 5 Dateien zu bleiben — verworfen, weil das die
  thematische Trennung der Testdateien verwischt, die diese Codebase sonst konsequent einhält
  (je eine Datei pro Parser-Format/-Thema, siehe `ReceiptParserStornoTests.swift`,
  `ReceiptParserReweTests.swift` usw.). `ReceiptScannerReResolutionTests.swift` prüft bereits
  `EditableReceiptLine`/`ReceiptScannerView`-Regeln ohne SwiftUI und ist damit der treffendere,
  nicht der zusätzliche, Ort.
- LoC: ≈ **+215 / −10** (≈ 225 gesamt) — über der ursprünglichen Schätzung von ≈ 150 LoC aus der
  Analyse (die den `isSavable`-Test und dessen eigene Testdatei noch nicht vorsah), aber
  innerhalb des Standard-Limits von ±250 LoC. Das LoC-Gate zählt Testcode als Produktivcode
  (Memory `loc-gate-zaehlt-testcode-als-produktiv`) — die Reihenfolge in `/50-implement` sieht
  deshalb einen grünen Zwischenstand vor: zuerst die drei Produktivcode-Änderungen (Card, Scanner,
  Seed) committen und bauen, danach die drei Testdateien.
- Risk Level: MITTEL — isoliert auf einen bereits produktiven Screen, aber mit einem (kleinen,
  gezielten) Eingriff in `save()`, der aus Invariante 1 eine bewusste Ausnahme macht.

## Implementation Details

### 1. Zwei neue, nicht-Codable Felder auf `EditableReceiptLine`

```swift
/// KI-Vorschlag und zugehörige Artikel-Zuordnung, unabhängig von der aktuellen Auswahl — erlaubt,
/// die KI-Options-Zeile nach einer zwischenzeitlich anderen Auswahl wieder exakt herzustellen
/// (resolvedByAI = true, matchedItemID wie ursprünglich). Gesetzt an allen drei Konstruktions-
/// stellen, wann immer `resolvedByAI` dort true ist. NIE Teil von `ResolvedReceiptLine`/
/// `ReceiptSuggestion` (Wire-Format) — rein lokaler Anzeigezustand für Schritt B.
var aiSuggestedName: String? = nil
var aiSuggestedMatchedItemID: UUID? = nil
```

Gesetzt in `init(store:prefilled:)` (Z. 152-164) und im `process()`-Mapping (Z. 522-534) aus
`line.resolvedByAI ? line.name : nil` / `line.resolvedByAI ? line.matchedItemID : nil`. In
`mergeAIReresolution` (Z. 79-89) zusätzlich: `if r.resolvedByAI { result[index].aiSuggestedName =
r.name; result[index].aiSuggestedMatchedItemID = r.matchedItemID }`.

### 2. `ReceiptNameOption` und `selectionOptions(for:)`

```swift
enum ReceiptNameOption: Identifiable {
    case listMatch(ReceiptSuggestion)   // Quelle "auf deiner Liste"
    case aiSuggestion(name: String)     // Marke "KI-Vorschlag"
    case currentName(name: String)      // Fallback, wenn weder Treffer noch KI-Vorschlag existiert
    case custom                         // "Anderer Name …", immer letzte Zeile
}
```

Regeln (deterministisch, unit-testbar ohne UI):
1. Inhaltliche Kandidaten sammeln: bis zu 3 `.listMatch` aus `line.suggestions` (in Service-
   Reihenfolge) und, falls `line.aiSuggestedName != nil`, eine `.aiSuggestion`.
2. Dedup case-insensitiv über den Namen: hat ein `.listMatch` denselben Namen wie die
   `.aiSuggestion`, entfällt die `.aiSuggestion` (der Listen-Treffer belegt den Platz).
3. Das Element, dessen Name case-insensitiv `line.name` entspricht, gilt als „vorausgewählt" und
   wird an die erste Stelle sortiert; die übrigen behalten ihre relative Reihenfolge.
4. Die inhaltlichen Kandidaten werden auf **max. 3** gekappt (vorausgewählter Kandidat zählt mit).
5. **(Issue #37, 2026-09-24)** Entspricht nach Schritt 3/4 **kein** verbliebener Kandidat
   case-insensitiv `line.name`, UND ist `line.name` **nicht leer**: `.currentName(line.name)` wird
   zusätzlich als vorausgewählte Zeile an Position 0 eingefügt. Ist die Kandidatenliste dadurch
   länger als 3, entfällt der letzte (schwächste, am weitesten hinten stehende) Kandidat, sodass es
   bei max. 3 inhaltlichen Kandidaten bleibt (Invariante 5, AC-2 unverändert gültig). Ist
   `line.name` leer, greift diese Regel nicht — weiter mit Regel 6 (heutiges Verhalten bleibt
   unverändert). Ist `line.name` bereits unter den Kandidaten vertreten (Regel 3 greift bereits),
   ändert sich ebenfalls nichts.
6. Gibt es nach Schritt 1-5 keinen einzigen inhaltlichen Kandidaten (kein Treffer, kein
   KI-Vorschlag, und Regel 5 hat mangels Kandidaten oder leerem `line.name` nicht gegriffen), wird
   stattdessen genau ein `.currentName(line.name)` gebildet. *(Vormals Regel 5 der Ursprungsfassung
   dieser Spec — inhaltlich unverändert.)*
7. `.custom` wird immer als letztes Element angehängt → **max. 4 Optionen insgesamt.**
   *(Vormals Regel 6 der Ursprungsfassung dieser Spec — inhaltlich unverändert.)*

### 3. `priceSummary(for:)`

Zeigt genau die Basis, mit der `save()` den Preis lernt: dieselbe Reihenfolge wie
`EditableReceiptLine.learningQuantity` (`ReceiptScannerView.swift:58-60`) — `weightBasis` aus der
Gewichtszeile, sonst `quantity > 1`, sonst die im Bontext gedruckte Füllmenge über die bestehende
Regel `ReceiptParserService.weightBasisFromName(originalName)` (`ReceiptParserService.swift:894`),
sonst 1 Stück. Keine neue Parsing-Logik; einzige Auslassung gegenüber `learningQuantity` ist
`matchQuantityAmount` (braucht den zugeordneten Artikel — nicht Teil der Karte).

```swift
static func priceSummary(for line: EditableReceiptLine) -> String {
    let p = currency(line.price)
    if let w = line.weightBasis, w > 0 {
        return "\(p) · \(Int(w.rounded())) g · \(currency(line.price / w * 1000)) je kg"
    }
    if line.quantity > 1 {
        return "\(p) · \(Int(line.quantity)) St. · \(currency(line.price / line.quantity)) je Stück"
    }
    if let w = ReceiptParserService.weightBasisFromName(line.originalName), w > 0 {
        let per = line.unit.lowercased().hasSuffix("l") ? "je l" : "je kg"   // l/ml/cl/dl → je l
        return "\(p) · \(line.unit) · \(currency(line.price / w * 1000)) \(per)"
    }
    return "\(p) · 1 St. · \(p) je Stück"
}
```

Fall 3 zeigt die Größe so, wie `line.unit` sie aus dem Namen trägt (z. B. „400g", „1,5l"), ohne
Umformatierung; ist `line.unit` leer, obwohl `weightBasisFromName` trifft, wird der Rechenwert
trotzdem gezeigt (Segment 2 entfällt dann). Fall 4 entspricht dem Entwurf („1,99 € · 1 St. ·
1,99 € je Stück") — bewusst redundant, damit jede Karte dieselbe Dreiteilung hat. Damit deckt die
Anzeige alle Fälle des Mockups (Stück, Gewichtszeile, gedruckte Füllmenge) ab, und der Nutzer sieht
vor dem Speichern denselben Stück-/Kilopreis, den die App lernen wird.

### 4. `sectionHeaderText(count:selected:sum:)`

`"\(count) Positionen · \(selected) ausgewählt · \(currency(sum))"` — ersetzt den heutigen
Section-Header „Gefunden: N Positionen" UND die separate „Ausgewählt"-Section (Z. 443-451), die
entfällt. Footer-Text wird von „Tippe auf einen Namen um ihn zu korrigieren …" auf einen Hinweis
zur Auswahl-Interaktion geändert: „Tippe eine Zeile an, um den Artikel zu wählen, oder „Anderer
Name …" für eine eigene Eingabe."

### 5. Karten-Aufbau (`ReceiptReviewCard`)

Zwei `part`-Bereiche in einer `VStack`, getrennt durch eine 1pt-Linie in `Color.hairline`
(entspricht `.part + .part { border-top }` im Mockup); äußere Kontur/Fläche wie `cardStyle()`
(`Color.surface`, `RCRadius.card`, `Color.hairline`-Rahmen). Kein `.listRowBackground`/Standard-
Trennlinie der `List` — stattdessen `.listRowBackground(Color.clear)`,
`.listRowSeparator(.hidden)`, `.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing:
16))`, damit jede Karte als eigene Fläche im Seitenfluss schwebt (Ebene 0, DesignSystem §4).

**Abschnitt 1:** Kopfzeile mit `originalName` (linksbündig, `Color.textSecondary`, 13pt,
`fixedSize(horizontal: false, vertical: true)` ohne `lineLimit` — der Bontext bricht bei
Überlänge in eine zweite Zeile um und wird NIE abgeschnitten oder umformatiert; ein abgeschnittener
Text ist genau der Fehler aus dem Screenshot zu #23. Bon-Zeilen sind maximal ~40 Zeichen breit,
auf iPhone-Breite bei 13 pt also höchstens zwei Zeilen) und dem 28×28pt Häkchen rechts (gleiches Muster wie
`ItemRow.swift:42-53`: `RoundedRectangle`, `Color.accent`-Fülllung + Haken wenn `isIncluded`,
`Color.hairlineStrong`-Kontur sonst; Eckenradius 8pt statt `ItemRow`s 6pt, da 28pt Kantenlänge
sonst zu rund wirkt — kein neuer globaler Token, lokale Konstante in der Datei). Darunter die
Optionszeilen aus `selectionOptions(for: line)`, je 48pt hoch, Radio-Punkt links (22pt,
`Color.accent` gefüllt wenn ausgewählt), Name mittig (`lineLimit(1)`), rechts je nach Fall
„auf deiner Liste" (`.listMatch`) oder die KI-Marke `Label("KI-Vorschlag", systemImage:
"sparkles").fixedSize()` (`.aiSuggestion`, exakt wie heute in `ReceiptLineRow.swift:712-719`,
Art.-50-Kennzeichnung bleibt an der Options-Zeile). `.custom` öffnet bei Tap ein `TextField`
(`Color.hairline`-Unterlinie statt Radio-Punkt), das direkt fokussiert; Eingabe ruft die
Custom-Auswahl-Logik pro Tastendruck auf (gleiches Live-Binding-Muster wie die heutige
`TextField`-Binding-Closure in `ReceiptLineRow.swift:695-702`).

**Abschnitt 2:** eine Zeile mit `priceSummary(for: line)` links und „Ändern" rechts
(`Color.accent`, 15pt semibold). Tap auf „Ändern" setzt lokalen `@State isEditing = true` und
klappt darunter eine Editor-Zeile auf (PO-Entscheidung 2026-09-22: Preis **und** Menge änderbar):

- **Preis** — das unveränderte bestehende Preisfeld
  (`TextField("0,00", value: $line.price, format: .number.precision(.fractionLength(2)))`,
  `.keyboardType(.decimalPad)`). Bleibt der Zeilen-**Gesamt**preis, wie heute.
- **Menge** — ein Zahlenfeld plus Umschalter „Stück | Gramm" (segmentierter `Picker`). Der
  Umschalter startet auf „Gramm", wenn `weightBasis != nil`, sonst auf „Stück". Die Zuweisung
  läuft über eine reine, testbare Funktion
  `static func applyQuantityEdit(_ line: inout EditableReceiptLine, mode: QuantityMode, value: Double)`:
  - `.pieces`: `quantity = max(1, value.rounded())`, `weightBasis = nil`
  - `.grams`: `weightBasis = value > 0 ? value : nil`, `quantity = 1`
  Damit bleibt `learningQuantity` (`ReceiptScannerView.swift:58-60`) die einzige Lernformel —
  der Editor schreibt nur die Felder, die sie liest; `save()` bleibt unangetastet. `unit` und
  `originalName` werden nie verändert.

Die Editor-Zeile bleibt nach der Eingabe offen; `priceSummary` darüber aktualisiert sich live
über die `$line`-Bindings — der Nutzer sieht sofort den neuen Stück-/Kilopreis, den die App lernen
wird.

**Auswahl-Callbacks** (drei kleine, private Methoden in der View, rufen exakt die heutige
`save()`-relevante Zuweisung auf):
- Listen-Treffer: `line.name = suggestion.name; line.matchedItemID = suggestion.itemID;
  line.resolvedByAI = false` — identisch zum heutigen Chip-Tap (`ReceiptLineRow.swift:754-756`).
- KI-Vorschlag: `line.name = line.aiSuggestedName ?? name; line.matchedItemID =
  line.aiSuggestedMatchedItemID; line.resolvedByAI = true`.
- Eigener Name: `line.name = newValue; line.matchedItemID = nil; line.resolvedByAI = false` —
  identisch zum heutigen `TextField`-Binding (`ReceiptLineRow.swift:696-701`).

`originalName` wird durch keinen dieser drei Pfade verändert.

### Nachtrag Issue #50, Paket 1 (2026-09-27): Auswahl stimmt wieder

Volle Herleitung in `docs/context/fix-50-import-dialog-design.md` (Abschnitte „Befund",
„Analysis", „PO-Entscheidungen" und „Nachtrag"). Drei Zusagen, alle in derselben Erweiterung:

1. Der aufgelöste Name steht sichtbar als markierte Zeile — nicht erst im Feld „Anderer Name …".
2. Es ist immer genau eine Option markiert (für eine Zeile mit nicht-leerem `line.name`).
3. Ein leerer Name ist kein speicherbarer Zustand.

#### Regel 9 — Optionen nachführen, nicht neu berechnen (Zusagen 1+2)

Der Grund fürs Einfrieren aus Abschnitt 5 oben bleibt gültig: `selectionOptions` sortiert die
aktuell gewählte Option nach vorn (Regel 3), eine Neuberechnung bei JEDER Änderung ließe die eben
angetippte Zeile unter dem Finger nach vorn springen. Die Lücke war nicht das Einfrieren selbst,
sondern dass es NIE endet: Ändert sich `line.name` von AUSSEN (`ReceiptScannerView.
reResolveAIIfNeeded()`, nach dem ersten Zeichnen der Karte), bleibt `options` auf dem alten Namen
stehen, und keine Zeile passt mehr — „Häkchen gesetzt, kein Kreis gefüllt" (Punkt 4), der neue Name
erscheint nur noch vorbelegt im Feld „Anderer Name …" (Punkt 2, `select(.custom)`, Abschnitt 5 oben,
Z. 358-362).

Die minimale Korrektur führt `options` NUR dann nach, wenn NACH der Änderung keine der
bestehenden Zeilen mehr zu `line.name` passt:

```swift
.onChange(of: line.name) { _, _ in
    guard !options.contains(where: { isSelected($0) }) else { return }
    options = Self.selectionOptions(for: line)
}
```

Nach jedem Nutzer-Tap (Listen-Treffer, KI-Vorschlag, `.currentName`) setzt der jeweilige
Auswahl-Callback `line.name` exakt auf den Namen der eben angetippten Option — `isSelected` für
genau diese Option wird dadurch sofort wieder `true`, der Guard schlägt fehl, `options` bleibt
unverändert stehen. Das Springen aus Abschnitt 5 bleibt damit ausgeschlossen. Während `.custom`
aktiv ist (`customActive == true`), liefert `isSelected(.custom)` unabhängig vom Namen `true` —
der Guard verhindert eine Neuberechnung also auch während der Eingabe im Feld „Anderer Name …",
wo `options` ohnehin nicht sichtbar ist. Nur eine externe Änderung, der KEINE bestehende Option
mehr entspricht, löst die Neuberechnung aus; Regel 5 (Abschnitt 2 oben) sorgt dann dafür, dass der
neue Name selbst als vorausgewählte `.currentName`-Zeile erscheint — Zusage 1 ist damit ohne neue
Regel in `selectionOptions` erledigt, allein durch das Nachführen des `onAppear`-Aufrufers.

**Reichweite von Zusage 2 („immer genau eine Option markiert"):** Gilt für jede Zeile mit
nicht-leerem `line.name` — siehe Invariante 6 unten und „Known Limitations" für die bewusst
unverändert gebliebene Ausnahme bei leerem Namen (Regel 6, unverändert seit Issue #37).

#### Regel 10 — Leerer Name ist kein speicherbarer Zustand (Zusage 3)

PO-Hinweis 2026-09-27 (siehe Kontext-Dokument, „Nachtrag"): `select(.custom)` belegt das Feld mit
`line.name` vor (Abschnitt 5, Z. 358-362); `customNameRow()`s `.onChange(of: customName)` ruft
bisher unconditional `applyCustomName(&line, name: newValue)` — auch für `newValue == ""`. Leert
der Nutzer das Feld vollständig, steht `line.name == ""` — und `save()` legt für diese Position
einen Kaufdatensatz OHNE Namen an und lernt einen Preis unter dem leeren Schlüssel (Regel 11
unten, mit dem vollständigen Befund).

**Entschieden: Rückfall**, nicht Sperre des Speicherns — hält den Screen bedienbar, statt den
Nutzer vor eine gesperrte Schaltfläche zu stellen. Präzise beantwortet:

- **„Die vorher gewählte Option"** ist die Auswahl, die unmittelbar VOR dem Öffnen von „Anderer
  Name …" galt — als `(name, matchedItemID, resolvedByAI)`-Tripel in einem neuen `@State private
  var previousSelectionBeforeCustom` festgehalten, geschrieben in `select(_:)` genau in dem
  Moment, in dem `.custom` gewählt wird (vor `customActive = true`, Abschnitt 5, Z. 370-376).
  **Alle drei Felder** werden restauriert, nicht nur der Name — sonst käme z. B. ein KI-Vorschlag
  nach dem Rückfall ohne seine Art.-50-Kennzeichnung zurück, obwohl er vorher genau diese trug.
- **Wann greift der Rückfall:** bei JEDEM leeren Zwischenstand, sofort — nicht erst beim Verlassen
  des Feldes. Konsistent mit dem bestehenden Muster dieser Karte, dass jeder Tastendruck sofort
  wirkt (Abschnitt 5, „Eingabe ruft die Custom-Auswahl-Logik pro Tastendruck auf", Invariante 2
  im Test Plan); ein Verlassen-des-Feldes-Hook existiert an dieser Stelle nicht, und ein Tipp
  woanders hin (z. B. das Häkchen) könnte einen Zwischenzustand sonst ungeprüft übernehmen.
- **Was NICHT zurückgesetzt wird:** das sichtbare Textfeld (`customName`) bleibt leer. Nur
  `line.name`/`matchedItemID`/`resolvedByAI` fallen zurück. Würde auch `customName` befüllt,
  könnte der Nutzer ab einem leeren Feld nie mehr einen neuen Namen eintippen, ohne dass das Feld
  sich unter dem Finger sofort wieder mit dem alten Namen füllt.
- **Es gibt keine vorher gewählte Option, wenn …:** In der Praxis nicht erreichbar — `.custom`
  wird ausschließlich durch Tippen auf eine bestehende, bereits benannte Auswahlzeile betreten
  (Listen-Treffer/KI-Vorschlag/`.currentName` tragen alle einen nicht-leeren Namen), und ein
  zuvor über diese Regel bereits zurückgefallener Zustand ist selbst wieder nicht-leer. Als reine
  Verteidigungsmaßnahme (keine bekannte Auslösung): Ist der festgehaltene Name dennoch leer, fällt
  `applyCustomNameOrFallback` stattdessen auf `line.originalName` zurück (`matchedItemID = nil`,
  `resolvedByAI = false`) — der Bontext selbst ist nie leer, sobald eine Karte überhaupt existiert.

Neue reine Funktion, NEBEN dem bestehenden `applyCustomName` (das für nicht-leere Namen
unverändert bleibt und von der neuen Funktion aufgerufen wird — kein bestehender Aufrufer/Test
von `applyCustomName` selbst ändert sich):

```swift
static func applyCustomNameOrFallback(
    _ line: inout EditableReceiptLine,
    name: String,
    previousSelection: (name: String, matchedItemID: UUID?, resolvedByAI: Bool)
) {
    guard !name.isEmpty else {
        let fallback = previousSelection.name.isEmpty
            ? (name: line.originalName, matchedItemID: nil, resolvedByAI: false)
            : previousSelection
        line.name = fallback.name
        line.matchedItemID = fallback.matchedItemID
        line.resolvedByAI = fallback.resolvedByAI
        return
    }
    applyCustomName(&line, name: name)
}
```

`customNameRow()`s `.onChange(of: customName)` ruft ab jetzt `Self.applyCustomNameOrFallback(&line,
name: newValue, previousSelection: previousSelectionBeforeCustom ?? (line.name, line.matchedItemID,
line.resolvedByAI))` statt `Self.applyCustomName(&line, name: newValue)`.

#### Regel 11 — Verteidigung in der Tiefe: leere Position wird nicht gespeichert

Bewusste, punktuelle Änderung von **Invariante 1** („`save()` bleibt unverändert").

**Korrektur der Analyse vom 2026-09-27 (festgestellt in `/40-tdd-red`, vor dem ersten Test):**
Der Kontext-Nachtrag behauptete, ein leerer Name treffe über die laxe Fallback-Suche
(`looseMatch`, `ReceiptScannerView.swift:646-651`) den erstbesten Kaufdatensatz dieses Ladens und
überschreibe dessen Preis und Datum. **Das ist nicht der Fall.** `looseMatch` wird nirgends direkt
benutzt, sondern ausschließlich über `match` (Z. 660-665), und dort steht eine
Ähnlichkeitsschwelle davor: `ReceiptParserService.lcsSimilarity(line.name, looseMatch.itemName) >=
completedItemAutoApplyThreshold` (0,6). `lcsSimilarity` bricht bei einem leeren Eingabestring
sofort mit 0 ab (`guard !aChars.isEmpty, !bChars.isEmpty else { return 0 }`,
`ReceiptParserService.swift:1113`). 0 < 0,6 → `match == nil`. Ein leerer Name kann also **keinen
fremden Kaufdatensatz verfälschen**; die Probe
`docs/artifacts/fix-50-import-dialog-design/probe-empty-name.swift` hat nur den `contains`-Teil
gemessen und den nachgelagerten Filter übersehen.

**Was bei leerem Namen wirklich passiert** (abgelesen an `save()`, `ReceiptScannerView.swift:600-760`):

| Stelle | Wirkung bei leerem `line.name` | Bewertung |
|---|---|---|
| `ReceiptAliasService.learn` (Z. 612) | bricht ab (`guard key.count >= 3, !name.isEmpty`, `ReceiptAliasService.swift:35`) | bereits geschützt |
| `matchedItem` (Z. 628-641) | kein Artikel trägt einen leeren Namen → `nil` | harmlos |
| `match` (Z. 660-665) | `nil`, siehe Korrektur oben | harmlos |
| `itemToUpdate` (Z. 692) | `nil` → kein Artikel bekommt einen falschen Preis | harmlos |
| `store.learnedPrices[""]`, `learnedPriceUnits[""]`, `learnedPriceDates[""]` (Z. 678-680) | ein Preis wird unter dem **leeren Schlüssel** gelernt | Datenmüll im Laden, wird nie wieder angewandt |
| `PurchaseRecord(itemName: "", …)` (Z. 731-737) | ein **namenloser Kaufdatensatz mit Preis** landet in der Ausgabenhistorie | echter Schaden: sichtbar in der Ausgaben-Ansicht, geht in die Nachkauf-Analyse ein |

Der Guard gehört damit **nicht** in `looseMatch`, sondern an den Eingang von `save()`: eine
Position ohne Namen wird gar nicht gespeichert. Das trifft beide echten Wirkungen in einem Zug
und lässt die Fallback-Suche unberührt.

Neue, reine Regel direkt neben `learningQuantity`/`learningUnit` auf `EditableReceiptLine` — dort,
weil die Bedingung eine Aussage über die ZEILE ist, nicht über die View:

```swift
/// Darf diese Position gespeichert werden? (Issue #50, Paket 1, Verteidigung in der Tiefe.)
///
/// Trägt die bisher in `save()` inline stehende Bedingung (`isIncluded && price > 0`) und
/// ergänzt sie um den leeren Namen: `save()` würde sonst einen `PurchaseRecord` OHNE Namen
/// anlegen und einen Preis unter dem leeren Schlüssel lernen (siehe Regel 11 der Spec).
static func isSavable(_ line: EditableReceiptLine) -> Bool {
    line.isIncluded
        && line.price > 0
        && !line.name.trimmingCharacters(in: .whitespaces).isEmpty
}
```

`save()`, Z. 601: `let included = parsedLines.filter { EditableReceiptLine.isSavable($0) }` statt
`parsedLines.filter { $0.isIncluded && $0.price > 0 }`. Keine weitere Zeile von `save()` ändert sich.

**Alternative, verworfen: Guard weglassen, weil Zusage 3 die Ursache in der Karte schon
schließt.** Verworfen aus zwei Gründen: (1) `@State customActive` fällt beim Zellen-Recycling
der `List` auf `false` zurück (bestehendes, dokumentiertes Risiko dieser Karte, siehe Kontext-
Dokument) — ein Zwischenzustand könnte dadurch theoretisch überleben, ohne dass die Karte selbst
ihn noch zeigt. (2) Sunk-Cost-unabhängig: eine künftige, andere Quelle für einen leeren Namen
(z. B. eine Änderung an `ReceiptResolutionService`/`ReceiptParserService`, außerhalb dieses
Tickets) würde den Datenschaden sonst kommentarlos zurückbringen. Der Guard kostet vier Zeilen
und macht `save()` robust gegen eine Annahme, die die Karte nur GERADE JETZT erfüllt.

### `accessibilityIdentifier`-Schema (neu, koordiniert mit #28)

| Element | Identifier |
|---|---|
| Karte | `receiptReview.line.<index>.card` |
| Häkchen | `receiptReview.line.<index>.checkbox` |
| Bontext | `receiptReview.line.<index>.originalName` |
| Auswahlzeile *k* (inkl. „Anderer Name …" als letzte) | `receiptReview.line.<index>.option.<k>` |
| Textfeld „Anderer Name" | `receiptReview.line.<index>.customNameField` |
| Preiszeilen-Text | `receiptReview.line.<index>.price` |
| Preis-Eingabefeld (nach „Ändern") | `receiptReview.line.<index>.priceField` |
| Mengen-Eingabefeld (nach „Ändern") | `receiptReview.line.<index>.quantityField` |
| Umschalter Stück/Gramm | `receiptReview.line.<index>.quantityMode` |
| „Ändern"-Knopf | `receiptReview.line.<index>.changeButton` |
| KI-Marke (an der `.aiSuggestion`-Zeile) | `receiptReview.line.<index>.aiMark` |
| Section-Kopf | `receiptReview.sectionHeader` |

Diese Tabelle ist die verbindliche Namensgrundlage für #23; sollte #28 zuerst abweichende
Identifier für Bontext/Preis/KI-Marke/Speichern einführen, wird bei der Implementierung von #23
auf die dort bereits gemergten Strings angeglichen (keine zwei parallelen Schemata).

## Invarianten

1. **`save()` bleibt bis auf eine gezielte Ausnahme unverändert.** Seit Issue #50, Paket 1
   (2026-09-27) überspringt der Eingangsfilter von `save()` eine Position mit leerem Namen
   (Regel 11) — bewusste, begründete Abweichung von der ursprünglichen Fassung dieser Invariante
   („keine Änderung an `ReceiptScannerView.swift`"). Die Fallback-Suche `looseMatch` selbst bleibt
   unangetastet; keine andere Zeile von `save()` ändert sich.
2. **`originalName` wird durch keine Auswahl-Interaktion verändert** — nur `name`,
   `matchedItemID`, `resolvedByAI` ändern sich, wie heute.
3. **Die Art.-50-Kennzeichnung („KI-Vorschlag", `sparkles`) bleibt immer an der Stelle sichtbar,
   an der der KI-Name tatsächlich zur Auswahl steht** — verschwindet nie, auch nicht nach
   Dedup-Regel 2 (dort geht nur die separate KI-Zeile auf, wenn ein identischer Listen-Treffer
   existiert; der KI-Name selbst bleibt über den Listen-Treffer weiterhin wählbar).
4. **`ResolvedReceiptLine`/`ReceiptSuggestion` (Wire-Format) bekommen keine neuen Felder** — die
   KI-Merk-Felder sind ausschließlich lokaler `EditableReceiptLine`-Zustand.
5. **Die Karte zeigt höchstens 3 inhaltliche Auswahl-Optionen**, unabhängig davon, wie viele
   `suggestions` `ReceiptResolutionService` liefert (heute bis zu 5) — Regel 4 aus
   `selectionOptions`. Bleibt durch die Issue-#37-Erweiterung (Regel 5) unverändert gültig: die
   neue Regel fügt maximal eine Zeile ein und entfernt dafür eine bestehende. Paket 1 (Issue #50)
   fügt KEINE neue Options-Zeile hinzu — diese Invariante und alle `option.<k>`-Indizes bleiben
   unverändert; Paket 2 (Issue #65) wird diese Invariante ändern.
6. **(Issue #50, Paket 1) Genau eine Option ist markiert, sofern `line.name` nicht leer ist.**
   Gilt für jede Zeile, deren `matchedItemID`/`resolvedByAI` aus einem der bekannten
   Zuweisungswege stammen (`applySelection`, `applyCustomName`/`applyCustomNameOrFallback`, oder
   direkt aus `ReceiptResolutionService.resolve` über `mergeAIReresolution`) — sichergestellt
   durch Regel 9 (Nachführen) zusammen mit den unveränderten Regeln 3/5/6. Ist `line.name` leer,
   bleibt das bestehende, durch Issue #37 bewusst unveränderte Verhalten gültig (siehe Known
   Limitations): keine Option ist automatisch markiert, bis der Nutzer selbst wählt — dieser Fall
   ist mit Regel 10 (Zusage 3) für den EINZIGEN produktiv erreichbaren Weg zu einem leeren Namen
   (das Feld „Anderer Name …" leeren) ausgeschlossen, aber nicht für eine Zeile, die bereits mit
   leerem `line.name` aus der Auflösung kommt (außerhalb des Scopes von Paket 1).

## Test Plan

### Automated Tests (TDD RED)

**Unit — `RestockTests/ReceiptReviewCardTests.swift`:**

- [x] **AC2/AC4:** GIVEN eine Zeile mit `resolvedByAI = true`, `aiSuggestedName` gesetzt und 2
  `suggestions` WHEN `selectionOptions(for:)` aufgerufen wird THEN liefert es genau 4 Optionen:
  KI-Zeile + 2 Treffer + `.custom`, KI-Zeile zuerst (aktuell ausgewählt).
- [x] **AC2:** GIVEN eine Zeile mit 5 `suggestions`, kein KI-Vorschlag WHEN `selectionOptions(for:)`
  aufgerufen wird THEN liefert es genau 3 `.listMatch` + `.custom` (nicht 5).
- [x] **AC2:** GIVEN eine `suggestions`-Liste, deren erster Eintrag denselben Namen wie
  `aiSuggestedName` trägt (case-insensitiv) WHEN `selectionOptions(for:)` aufgerufen wird THEN
  erscheint der Name nur einmal (als `.listMatch`, keine separate `.aiSuggestion`).
- [x] **AC2:** GIVEN eine Zeile ohne `suggestions` und ohne `aiSuggestedName` WHEN
  `selectionOptions(for:)` aufgerufen wird THEN liefert es genau `.currentName(line.name)` +
  `.custom` (2 Optionen).
- [x] **AC5:** GIVEN eine Zeile WHEN ein `.listMatch`-Callback mit einem `ReceiptSuggestion`
  aufgerufen wird THEN gilt `name == suggestion.name`, `matchedItemID == suggestion.itemID`,
  `resolvedByAI == false`, `originalName` unverändert.
- [x] **AC6:** GIVEN eine Zeile mit `resolvedByAI = true`, dann manuell auf einen Listen-Treffer
  umgeschaltet WHEN der `.aiSuggestion`-Callback erneut aufgerufen wird THEN gilt `resolvedByAI ==
  true`, `name == aiSuggestedName`, `matchedItemID == aiSuggestedMatchedItemID`.
- [x] **AC7:** GIVEN eine Zeile mit `matchedItemID` gesetzt WHEN der `.custom`-Callback mit einem
  neuen Namen aufgerufen wird THEN gilt `matchedItemID == nil`, `resolvedByAI == false`,
  `originalName` unverändert.
- [x] **AC8:** GIVEN `price = 1.99, quantity = 1, unit = "", originalName = "FISCHSTAEBCHEN 15ST"`,
  `weightBasis = nil` WHEN `priceSummary(for:)` aufgerufen wird THEN liefert es
  `"1,99 € · 1 St. · 1,99 € je Stück"` (Fall 4; „15ST" ist keine g/kg/l-Einheit, Regel erfindet
  nichts — vgl. `testWeightBasisFromName`-Negativfall in `ReceiptParserPriceTests.swift:236`).
- [x] **AC8:** GIVEN `price = 3.99, quantity = 1, unit = "400g", originalName = "GOUDA JUNG 400G"`,
  `weightBasis = nil` WHEN `priceSummary(for:)` aufgerufen wird THEN liefert es
  `"3,99 € · 400g · 9,98 € je kg"` (Fall 3 über `weightBasisFromName`).
- [x] **AC8:** GIVEN `price = 1.29, quantity = 1, unit = "1,5l", originalName = "COLA 1,5L"` WHEN
  `priceSummary(for:)` aufgerufen wird THEN liefert es `"1,29 € · 1,5l · 0,86 € je l"` (Fall 3,
  Flüssigkeit → „je l").
- [x] **AC8:** GIVEN `price = 1.60, quantity = 4` WHEN `priceSummary(for:)` aufgerufen wird THEN
  liefert es `"1,60 € · 4 St. · 0,40 € je Stück"`.
- [x] **AC8:** GIVEN `price = 7.99, weightBasis = 250` WHEN `priceSummary(for:)` aufgerufen wird
  THEN liefert es `"7,99 € · 250 g · 31,96 € je kg"`.
- [x] **AC11:** GIVEN `count = 7, selected = 6, sum = 18.94` WHEN `sectionHeaderText(...)`
  aufgerufen wird THEN liefert es `"7 Positionen · 6 ausgewählt · 18,94 €"`.
- [x] **AC9:** GIVEN `price = 1.60, quantity = 1` WHEN `applyQuantityEdit(mode: .pieces, value: 4)`
  aufgerufen wird THEN gilt `quantity == 4`, `weightBasis == nil`, `price == 1.60` (unverändert)
  und `priceSummary` liefert `"1,60 € · 4 St. · 0,40 € je Stück"`.
- [x] **AC9:** GIVEN `price = 7.99, quantity = 3` WHEN `applyQuantityEdit(mode: .grams, value: 250)`
  aufgerufen wird THEN gilt `weightBasis == 250`, `quantity == 1` und `priceSummary` liefert
  `"7,99 € · 250 g · 31,96 € je kg"`.
- [x] **AC9:** GIVEN eine Zeile WHEN `applyQuantityEdit(mode: .pieces, value: 0)` aufgerufen wird
  THEN gilt `quantity == 1` (Untergrenze, kein Teilen durch null in `learningQuantity`).
- [x] **AC9:** GIVEN `weightBasis = 250, unit = "250g", originalName = "LACHS 250G"` WHEN
  `applyQuantityEdit` in beliebiger Reihenfolge aufgerufen wird THEN bleiben `unit` und
  `originalName` unverändert.
- [x] **Invariante 2:** GIVEN eine Zeile mit `originalName = "FISCHSTAEBCHEN 15ST"` WHEN
  nacheinander alle drei Callback-Arten aufgerufen werden THEN bleibt `originalName` nach jedem
  Aufruf exakt `"FISCHSTAEBCHEN 15ST"`.

**Issue #37 — Regel 5 (`selectionOptions`, neu; TDD RED, wird in `/40-tdd-red` geschrieben):**

- [ ] **AC-4 (Issue #37):** GIVEN eine Zeile `name: "Milch"` mit 3 `.listMatch`-Kandidaten
  ("Hafermilch", "Buttermilch", "Vollmilch"), von denen keiner case-insensitiv `"Milch"` entspricht,
  und keinem `aiSuggestedName` WHEN `selectionOptions(for:)` aufgerufen wird THEN ist `options[0]`
  `.currentName("Milch")`, die drei ursprünglichen Treffer sind auf zwei reduziert (der zuletzt
  gereihte, "Vollmilch", entfällt), und die Gesamtzahl bleibt bei 4 Optionen (3 inhaltliche
  Kandidaten + `.custom`).
- [ ] **Regression (Issue #37):** GIVEN eine Zeile mit leerem `name` (`""`) und denselben 3
  `.listMatch`-Kandidaten wie oben, von denen keiner (naturgemäß) `line.name` entspricht WHEN
  `selectionOptions(for:)` aufgerufen wird THEN bleibt die Kandidatenliste unverändert bei den 3
  Treffern + `.custom` (4 Optionen) — keine zusätzliche `.currentName`-Zeile, heutiges Verhalten
  (Regel 6, vormals Regel 5) bleibt unberührt.
- [ ] **AC-4 (Issue #37, Ergänzung zu bestehendem Test):** Der bestehende Test
  `testFiveSuggestionsAreCappedToThreeListMatches` (`name: "Milch"`, Treffer "Hafermilch/
  Buttermilch/Vollmilch/Kondensmilch/Reismilch" — keiner entspricht `"Milch"`) wird um eine
  Vorauswahl-Assertion ergänzt: THEN ist `options[0]` `.currentName("Milch")`, und für dieses
  Element liefert die Auswahl-Logik der Karte (`isSelected`) `true`. Dieser Test konstruierte das
  Symptom-Szenario aus Issue #37 bereits vor dieser Erweiterung, prüfte die Vorauswahl bisher aber
  nicht.

**Issue #50, Paket 1 (neu; TDD RED, wird in `/40-tdd-red` geschrieben):**

- [ ] **AC-15 (`applyCustomNameOrFallback`):** GIVEN eine Zeile mit `matchedItemID` gesetzt und
  `previousSelection = (name: "Vollmilch", matchedItemID: <id>, resolvedByAI: false)` WHEN
  `applyCustomNameOrFallback(&line, name: "", previousSelection:)` aufgerufen wird THEN gilt
  `line.name == "Vollmilch"`, `line.matchedItemID == <id>`, `line.resolvedByAI == false` — der
  leere Zwischenstand wird nie in `line` geschrieben.
  Test: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName`.
- [ ] **AC-15 (KI-Zustand):** GIVEN `previousSelection = (name: "Frische Vollmilch", matchedItemID:
  <aiID>, resolvedByAI: true)` WHEN mit leerem Namen aufgerufen wird THEN gilt `resolvedByAI ==
  true` UND `matchedItemID == <aiID>` — beweist, dass alle drei Felder zurückgeholt werden, nicht
  nur der Name. Test: `testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName`.
- [ ] **AC-15 (Regression, nicht-leerer Name):** GIVEN ein beliebiges `previousSelection` WHEN mit
  einem nicht-leeren Namen aufgerufen wird THEN verhält sich die Funktion exakt wie das bestehende
  `applyCustomName` (`matchedItemID == nil`, `resolvedByAI == false`, `originalName` unverändert)
  — der Rückfall greift ausschließlich beim leeren Zwischenstand.
  Test: `testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged`.
- [ ] **AC-16 (`isSavable`, in `RestockTests/ReceiptScannerReResolutionTests.swift`):** GIVEN
  eine angehakte Zeile mit `price == 1.99` und `name == ""` (und ebenso eine mit `name == "   "`)
  WHEN `EditableReceiptLine.isSavable(_:)` aufgerufen wird THEN liefert es `false` — `save()`
  überspringt diese Position und legt weder einen namenlosen Kaufdatensatz noch einen Lern-Eintrag
  unter dem leeren Schlüssel an. Test: `testIsSavableRejectsLineWithEmptyName`.
- [ ] **AC-16 (Regression, bisherige Bedingungen):** GIVEN eine angehakte Zeile mit
  `name == "Butter"` und `price == 1.99` WHEN `isSavable(_:)` aufgerufen wird THEN liefert es
  `true`; für dieselbe Zeile mit `isIncluded == false` bzw. `price == 0` weiterhin `false` —
  beweist, dass die Regel die bisher inline stehende Bedingung unverändert mitträgt.
  Test: `testIsSavableKeepsIncludedNamedLineAndRejectsOldCases`.

**UI — `RestockUITests/ReceiptReviewUITests.swift`** (Einstieg über `-seedReceiptReviewForUITests`
aus #28, fester Bon mit mind. einer KI-Zeile, langem Namen und ≥3 `suggestions`):

- [x] **AC1:** Bontext jeder Karte ist sichtbar und sein Label entspricht exakt dem gesäten
  Rohtext — geprüft auch an der langen Bon-Zeile des Seeds aus #28 (≥ 40 Zeichen, so lang wie die
  längste Zeile eines Lidl-Bons); ein `XCUIElement.label`, das kürzer ist oder mit „…" endet,
  lässt den Test fehlschlagen.
- [x] **AC3:** Die KI-Marke an der KI-Optionszeile ist einzeilig (Frame-Höhe unter der einer
  2-zeiligen Darstellung) und sichtbar.
- [x] **AC2:** Eine Karte mit KI-Vorschlag und ≥3 Treffern zeigt höchstens 4 Auswahlzeilen
  (`receiptReview.line.0.option.0` … `.option.3` existieren, `.option.4` existiert nicht).
- [x] **AC5:** Tippen auf eine Listen-Treffer-Zeile wählt sie aus (Radio-Zustand) und übernimmt den
  Namen sichtbar in der Karte.
- [x] **AC7:** Tippen auf „Anderer Name …" zeigt ein fokussiertes Tastaturfeld
  (`receiptReview.line.0.customNameField`).
- [x] **AC9:** Tippen auf „Ändern" zeigt Preis- und Mengenfeld samt Umschalter; nach Eingabe
  eines neuen Preises zeigt die Preiszeile den neuen Betrag; nach Umschalten auf „Stück" und
  Eingabe „4" zeigt sie „4 St." und den neuen Stückpreis.
- [x] **AC10:** Häkchen einer Karte abwählen senkt „M ausgewählt" und die Summe im Section-Kopf um
  genau den Preis dieser Position.
- [x] **AC11:** Der Section-Kopf zeigt „N Positionen · M ausgewählt · Summe" mit den erwarteten
  Werten für den gesäten Bon.
- [x] **AC12 (Regression):** Speichern führt zu einem sichtbaren Preis am zugeordneten Artikel in
  `StoreDetailView` (gleicher Nachweisweg wie die bestehenden `save()`-Tests) — beweist, dass die
  neue Karte keine Semantik von `save()` verändert.

**Issue #50, Paket 1 — neue UI-Tests** (Einstieg über den zweiten, ausdrücklich gegenläufigen
Seed `-seedReceiptReviewUnresolvedLineForUITests`; Details, Fixture und die benannte Ausnahme von
Invariante 1 stehen in `docs/specs/testing/receipt-review-test-entry.md`, „Nachtrag Issue #50,
Paket 1"):

- [ ] **AC-13/AC-14 (der reproduzierte Fall):** GIVEN die fünfte Bon-Zeile des neuen Seeds
  (`name == originalName == "BTR"`, `resolvedByAI == false` — verletzt Invariante 1 des
  Testeinstiegs ABSICHTLICH, damit `reResolveAIIfNeeded()` tatsächlich läuft) WHEN der Prüf-Screen
  öffnet und die Namensauflösung (Wörterbuch-Stufe, „btr" → „Butter", ohne Apple Intelligence)
  durchgelaufen ist THEN zeigt `receiptReview.line.4.option.0` das Label „Butter" und
  `isSelected == true`; unter allen `receiptReview.line.4.option.<k>` (k = 0…3) ist GENAU EINE
  Zeile markiert. Vor Regel 9 blieb `option.0` auf „BTR" stehen und keine Zeile war markiert —
  exakt der Screenshot-Befund aus Issue #50.
  Test: `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` — zeichengenau
  derselbe Testname wie „Test 3" in `docs/specs/testing/receipt-review-test-entry.md`; es
  entsteht nur EIN Test, hier aus Sicht der Karte, dort aus Sicht des Testeinstiegs beschrieben.
- [ ] **AC-15 (PO-Fund, UI-Nachweis):** GIVEN die KI-Zeile des BESTEHENDEN Seeds
  (`receiptReview.line.0`, Name „Frische Vollmilch 3,5 %") WHEN „Anderer Name …" angetippt, das
  vorbelegte Feld vollständig geleert (nicht neu befüllt) wird THEN zeigt
  `receiptReview.line.0.checkbox` weiterhin „Position übernehmen: Frische Vollmilch 3,5 %" — nie
  einen leeren Namen. Vor Regel 10 hätte jeder gelöschte Buchstabe den Namen live überschrieben,
  bis er bei vollständigem Leeren leer gewesen wäre.
  Test: `testClearingCustomNameFieldKeepsPreviousItemName`.

**Bestehende Tests, unverändert (bestätigt für Paket 1):**
`testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches`
(`RestockTests/ReceiptReviewCardTests.swift`) bleibt unverändert — er prüft die reine Funktion
`selectionOptions` bei bereits leerem `line.name`, eine Eingangsbedingung, die Paket 1 nicht
ändert. Regel 10 (Rückfall) verhindert nur, dass die VIEW `line.name` überhaupt erst leer setzt —
sobald ein Aufrufer (wie dieser Test) direkt eine Zeile mit `name: ""` konstruiert, bleibt das
Verhalten von `selectionOptions` exakt das aus Issue #37 (Regel 6). Alle vier Options-Index-Tests
aus der Analyse-Risikoliste (`testCardShowsAtMostFourSelectionOptions`,
`testTappingListMatchSelectsThatOption`, `testCustomNameOptionOpensFocusedTextField`,
`testTypingCustomNameIsAppliedWithEveryKeystroke`) bleiben ebenfalls unverändert: Paket 1 fügt
keine neue Options-Zeile hinzu, also verschiebt sich kein `option.<k>`-Index.

**Dark/Light:** mindestens `AC1`, `AC3` und `AC9` zusätzlich einmal mit dem Launch-Argument
`-AppleInterfaceStyle Dark` ausgeführt (zweiter Testlauf derselben Methoden oder parametrisierte
Variante) — Dark ist der im Original-Screenshot (Issue #23) reproduzierte Fall.

**Nulllinie/RED-Nachweis:** Gegen das heutige Layout (`ReceiptLineRow`) schlagen mindestens AC1
(Bontext existiert nicht), AC3 (Marke bricht vierzeilig um, Frame-Höhe-Assertion schlägt fehl) und
AC2 (keine Auswahlzeilen, nur ein `TextField` + Scroll-Chips) fehl — das sind die RED-Tests, die
diese Spec GREEN macht.

## Acceptance Criteria

- **AC-1:** Jede Karte zeigt den vollständigen, unveränderten Bontext (`originalName`) —
  auch bei Überlänge umbrechend, nie abgeschnitten.
- **AC-2:** Jede Karte zeigt max. 4 Auswahlzeilen (max. 3 inhaltliche + „Anderer Name …").
- **AC-3:** Die KI-Marke ist an der KI-Options-Zeile sichtbar, einzeilig, nie umbrechend.
- **AC-4:** Der beste Treffer / aktuelle Zustand der Zeile ist vorausgewählt. Entspricht keiner der
  bis zu 3 angezeigten Kandidaten-Zeilen dem aktuell für die Position geltenden Namen (`line.name`)
  UND ist `line.name` nicht leer, wird der geltende Name zusätzlich als eigene Zeile angeboten und
  ist vorausgewählt — dafür entfällt der schwächste (am weitesten hinten stehende) der bisherigen
  Kandidaten (Issue #37, Regel 5 in `selectionOptions`, siehe Implementation Details). Ist
  `line.name` leer, bleibt das bisherige Verhalten unverändert.
- **AC-5:** Wahl eines Listen-Treffers setzt `name`/`matchedItemID`/`resolvedByAI` exakt wie der
  heutige Chip-Tap.
- **AC-6:** Wahl des KI-Vorschlags stellt `resolvedByAI = true` und den KI-Namen wieder her,
  auch nach zwischenzeitlich anderer Auswahl.
- **AC-7:** „Anderer Name …" öffnet ein Textfeld; Eingabe setzt `matchedItemID = nil`,
  `resolvedByAI = false`, `originalName` bleibt unverändert.
- **AC-8:** Die Preiszeile zeigt Preis · Menge/Gewicht/Größe · je Stück/je kg/je l nach den in
  `priceSummary` festgelegten Regeln (Gewichtszeile, Stückzahl > 1, gedruckte Füllmenge, 1 Stück)
  — dieselbe Basis, mit der `save()` den Preis lernt.
- **AC-9:** „Ändern" öffnet Preisfeld und Mengen-Editor (Zahl + Stück/Gramm); neuer Preis und
  neue Menge erscheinen sofort in der Preiszeile, `unit`/`originalName` bleiben unverändert.
- **AC-10:** Häkchen abwählen dimmt die Karte und senkt „M ausgewählt"/Summe im Section-Kopf.
- **AC-11:** Section-Kopf zeigt „N Positionen · M ausgewählt · Summe" korrekt.
- **AC-12:** Speichern schreibt weiterhin über den `save()`-Pfad (Regressionsschutz) — bis auf die
  gezielte, in AC-16 beschriebene Ausnahme unverändert.
- **AC-13 (Issue #50, Zusagen 1+2):** Ändert sich `line.name` von AUSSEN (z. B. durch
  `reResolveAIIfNeeded()` nach dem ersten Zeichnen der Karte), UND passt danach keine der
  bestehenden Auswahlzeilen mehr dazu, wird die Auswahlliste einmal neu berechnet (Regel 9) — der
  neue Name erscheint als eigene, vorausgewählte Zeile (Regel 5), nicht erst im Feld „Anderer
  Name …". Passt eine bestehende Zeile weiterhin (z. B. nach einem Nutzer-Tap), bleibt die Liste
  unverändert stehen — das bewusste Einfrieren aus Abschnitt 5 bleibt für diesen Fall erhalten.
- **AC-14 (Issue #50, Zusage 2):** Für jede Zeile mit nicht-leerem `line.name`, deren
  `matchedItemID`/`resolvedByAI` aus einem der bekannten Zuweisungswege stammen, ist immer genau
  eine Auswahlzeile markiert — beweisbar am reproduzierten Fall: „Karte zeigt genau einen
  gefüllten Auswahlkreis, nie null und nie zwei." Siehe Invariante 6.
- **AC-15 (Issue #50, Zusage 3):** Leert der Nutzer das vorbelegte Feld „Anderer Name …"
  vollständig, fällt die Karte auf die Auswahl zurück, die unmittelbar zuvor galt (Name,
  `matchedItemID` UND `resolvedByAI` gemeinsam) — `line.name` wird nie leer geschrieben. Das
  sichtbare Textfeld selbst bleibt dabei leer, der Nutzer kann sofort weitertippen.
- **AC-16 (Issue #50, Verteidigung in der Tiefe):** Eine Position mit leerem Namen wird beim
  Speichern vollständig übersprungen — es entsteht kein Kaufdatensatz ohne Namen in der
  Ausgabenhistorie und kein gelernter Preis unter dem leeren Schlüssel; unabhängig davon, ob ein
  leerer Name die Karte je erreicht (AC-15 schließt das für den bekannten Weg aus).

## Alternativen (verworfen)

- **Variante A — Karte mit Feld + Chip-Tasten** (PO-Idee, Runde 2): Name als Eingabefeld,
  3 Alternativen als 40-pt-Chip-Tasten daneben, Preisblock als drei Spalten (Preis/Menge/
  berechneter Kilopreis). Verworfen laut PO-Freigabe zugunsten B: zwei gleichwertige Wege zum
  selben Ziel (Feld tippen ODER Chip tippen) sind auf einer Touch-Oberfläche weniger eindeutig als
  eine einzige Auswahlliste; würde die Freigabe „Variante B" vom 2026-09-22 zurücknehmen. Bliebe
  die kompaktere Alternative, falls sich B in der Praxis als zu hoch (viele Karten) erweist.
- **Variante C — Eine Position nach der anderen** (Vollbild je Position, „2 von 7"): Verworfen,
  weil kein Überblick über die Bon-Summe/den Fortschritt besteht, bis alle Positionen durchlaufen
  sind — bei 20 Positionen unpraktisch für den eigentlichen Zweck des Screens (Bon-Summe prüfen).
  Würde ebenfalls die Freigabe „Variante B" zurücknehmen.
- **Layout-Alternative „Bontext unter dem Namen"** (Runde 1, im Kontext-Dokument dokumentiert):
  Name groß oben, Bontext als kleiner Untertitel darunter — näher am iOS-Standardmuster
  (`Text`/`Text.secondary`), macht den Bontext aber zur Fußnote, obwohl er das eigentliche
  Prüfkriterium des Screens ist. Verworfen; würde PO-Entscheidung 2 vom 2026-09-22 („Bontext immer
  sichtbar, über dem Namen") zurücknehmen.
- **Mengen-Editor als Folge-Issue abtrennen** (nur Preis unter „Ändern"): War der Vorschlag der
  Analyse für den Fall der Scoping-Überschreitung und die erste Fassung dieser Spec. Verworfen
  durch PO-Entscheidung vom 2026-09-22 („bitte direkt Menge und Preis änderbar machen") — eine
  falsch erkannte Menge ist gerade der Fall, in dem der Nutzer sonst einen falschen Preis lernen
  lässt.
- **Freie Mengen-Einheit (Stück/g/kg/l/ml) im Editor**: Verworfen — `save()` kennt nur die
  Lernbasis „Stück" oder „Gramm-Äquivalent" (`learningQuantity`); mehr Einheiten im Editor würden
  Umrechnungslogik in die View holen, die es nirgends sonst gibt. Zwei Stellungen reichen.
- **Issue #37 — Alternative A: AC-4 einschränken** (Karten ohne Vorauswahl zulassen): Verworfen
  durch PO-Entscheidung 2026-09-24 — ehrlicher gegenüber dem lückenhaften Ist-Zustand, löst aber
  das eigentliche Nutzerproblem (kein Weg, den geltenden Namen wiederzufinden) nicht.
- **Issue #37 — Alternative B: geltenden Namen nur als Hinweistext in der Kopfzeile zeigen** (nicht
  wählbar): Verworfen durch PO-Entscheidung 2026-09-24 — kostet keine Auswahlzeile, macht den
  Zustand nach versehentlicher Auswahl einer anderen Option aber nicht mehr per Tipp
  wiederherstellbar.
- **Issue #50, Paket 1 — Alternative A: Prüf-Screen erst zeigen, wenn `reResolveAIIfNeeded()`
  durch ist** (z. B. `phase` erst auf `.review` setzen, wenn die Nachauflösung fertig ist).
  Behebt Punkt 2/4 an der Wurzel und würde Regel 9 überflüssig machen. Verworfen: kostet sichtbare
  Wartezeit beim Öffnen aus der Teilen-Erweiterung (genau der Weg, den Punkt 4 betrifft) und ändert
  am eigentlichen Kern — eine Auswahlliste, die ihren Zustand nicht nachführt — nichts. Bei jeder
  künftigen Quelle für eine Namensänderung NACH dem ersten Zeichnen (iCloud-Nachzug, künftiges
  Alias-Lernen) wäre der Fehler zurück. Würde keine bestehende Entscheidung/ADR kippen (#23 traf
  dazu keine explizite Festlegung), aber die in Issue #28 festgelegte Reihenfolge „Sheet öffnet
  sofort über `HomeView.checkPendingReceiptScan()`" faktisch aufweichen.
- **Issue #50, Paket 1 — Alternative B: `options` bei jedem Zeichnen neu berechnen** statt
  nachzuführen (kein `@State`, `selectionOptions(for: line)` direkt im `body`). Verworfen: würde
  den Grund fürs Einfrieren aus Abschnitt 5 (Kommentar Z. 78-83) und dessen Nachweis
  (`testTappingListMatchSelectsThatOption`, „Radio-Zustand nach Tap bleibt stehen") direkt
  zurücknehmen — die eben angetippte Zeile spränge unter dem Finger wieder nach vorn, sobald
  `selectionOptions`s Regel 3 sie nur wegen ihrer neuen Position umsortiert.
- **Issue #50 — Alternative: den Guard in `save()` weglassen, weil Zusage 3 die Ursache in der
  Karte schon schließt** (siehe Regel 11): Verworfen — `@State customActive` fällt beim
  Zellen-Recycling der `List` auf `false` zurück (ein bereits dokumentiertes Risiko dieser Karte),
  und eine künftige, andere Quelle für einen leeren Namen außerhalb dieser Karte würde den
  Datenschaden sonst wieder zurückbringen. Eine Bedingung im bestehenden Eingangsfilter ist
  billiger als diese Annahme.
- **Issue #50 — Alternative: den Guard in `looseMatch` setzen** (die Fassung dieser Spec vor der
  Korrektur in Regel 11): Verworfen, weil er dort nichts bewirkt — die Ähnlichkeitsschwelle vor
  `match` fängt einen leeren Namen bereits ab, und die zwei echten Wirkungen (namenloser
  Kaufdatensatz, Lern-Eintrag unter leerem Schlüssel) entstehen hinter dieser Stelle. Belegt in
  Regel 11 mit Zeilennummern.

## Risiken

- **#28 ist Voraussetzung und zum Zeitpunkt dieser Spec noch nicht umgesetzt.** Ohne
  `-seedReceiptReviewForUITests` und das UI-Test-Grundgerüst gibt es keinen reproduzierbaren
  RED-Nachweis für diese Spec — Implementierung von #23 kann nicht sinnvoll vor #28 beginnen.
- **Hohe Karten bei vielen Positionen.** Ein Bon mit 20 Positionen ergibt 20 Karten mit je bis zu
  4 Auswahlzeilen — deutlich mehr Scroll-Strecke als die heutige einzeilige Darstellung. Bewusst
  in Kauf genommen (PO-Freigabe kennt diesen Nachteil, siehe Mockup-Contra-Punkt).
- **`List`-Performance mit eingebetteten `TextField`s.** Jede Karte kann potenziell zwei
  `TextField`s enthalten (Custom-Name, Preis) — bei vielen sichtbaren Karten gleichzeitig ein
  bekanntes SwiftUI-`List`-Performance-Risiko; durch Lazy-Rendering der `List` grundsätzlich
  entschärft, aber nicht spezifisch getestet in dieser Spec.
- **Dark Mode.** Der ursprüngliche Bug-Screenshot (#23) ist Dark Mode; alle Tokens kommen aus
  Asset-Katalog-Farben (Any + Dark) — Dark/Light-Testabdeckung ist im Test Plan explizit
  aufgenommen, aber nicht für jeden Test dupliziert (Umfang).
- **UI-Tests hängen an Anzeigetexten (#18).** Wie der gesamte Screen heute — eine künftige
  Text-Änderung an Section-Kopf/Footer/„Ändern"/„Anderer Name …" bricht diese Tests, ohne dass
  Lokalisierungs-Keys das auffangen.
- **Wire-Format-Disziplin.** Die zwei neuen `EditableReceiptLine`-Felder dürfen nie versehentlich
  in `ResolvedReceiptLine`/`ReceiptSuggestion` „hochwandern" (z. B. bei einem künftigen Refactoring,
  das die Typen zusammenlegt) — würde die Share-Extension-Prozessgrenze und alte, bereits
  gespeicherte Payloads gefährden (siehe `ResolvedReceiptLine`-Doku zu Decodier-Kompatibilität).
- **`save()`-Semantik.** Jede Abweichung der drei Auswahl-Callbacks von den heutigen
  Zuweisungsmustern (Chip-Tap/TextField-Binding) würde stillschweigend falsche Preise/Aliase lernen
  — abgesichert über Invariante 1-2 und AC5/AC7/AC12.
- **Scoping-Limit-Überschreitung.** Siehe „Estimated Changes" — ≈720 LoC über 5 Dateien reißt das
  Standard-Limit von ±250 LoC klar. Diese Spec benennt das explizit, statt es zu verschleiern;
  Entscheidung (akzeptieren vs. weiter aufteilen) liegt beim PO vor Beginn der Implementierung.
- **Issue #50, Paket 1 — Datei-/LoC-Überschreitung, kleiner als oben, aber real.** 6 statt der
  Ziel-5 Dateien (siehe „Scope-Erweiterung (Issue #50, Paket 1)"), ≈ 225 statt ≈ 150 geschätzter
  LoC — noch innerhalb des Standard-Limits von ±250, aber mit weniger Reserve als in der Analyse
  angenommen. Empfehlung an `/50-implement`: Produktivcode zuerst committen (grüner
  Zwischenstand), dann die drei Testdateien — das LoC-Gate zählt Testcode als Produktivcode
  (Memory `loc-gate-zaehlt-testcode-als-produktiv`).
- **Determinismus des neuen Seeds hängt von einer Annahme ab, die außerhalb dieser Spec liegt.**
  Der Nachweis von AC-13/AC-14 setzt voraus, dass kein anderer Test je einen Alias für den Bontext
  „BTR" lernt (`ReceiptAliasService`, Stufe 1 der Auflösung, läuft VOR dem Abkürzungswörterbuch) —
  sonst würde Stufe 1 statt des Wörterbuchs greifen und die Karte einen anderen Namen als „Butter"
  zeigen. Aktuell tut das kein bestehender Test; Details und die Parallel-Einschränkung des
  bestehenden Seeds (Apple-Intelligence-Verfügbarkeit) stehen in
  `docs/specs/testing/receipt-review-test-entry.md`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — es gibt im Projekt kein formales ADR-Verzeichnis (`docs/adr/` existiert
  nicht), wie bereits in der Vorgänger-Spec (`receipt-parser-quantity-confirmation.md`)
  festgehalten.
- **Rationale:** Diese Änderung ist ein UI-Umbau einer bestehenden View ohne Eingriff in
  Datenmodelle, Sync-Architektur oder Wire-Formate. Die zwei architekturnäheren Entscheidungen
  dieser Spec — (1) „Auswahl statt Freitext" als primäre Interaktion für die Namensklärung
  (statt Textfeld + Chips) und (2) ein neues, bewusst nicht-`Codable`s View-Model-Feld
  (`aiSuggestedName`/`aiSuggestedMatchedItemID`) auf `EditableReceiptLine`, um den KI-Namen nach
  einer Zwischenauswahl wiederherstellbar zu halten — sind oben unter „Implementation Details"
  vollständig begründet und über Invariante 3-4 sowie AC6 abgesichert. Ein separates ADR-Dokument
  wäre für einen UI-Umbau dieses Umfangs unverhältnismäßig. Die Issue-#37-Erweiterung (2026-09-24)
  ist eine reine Bedingungserweiterung innerhalb der bereits bestehenden, reinen Regel-Funktion
  `selectionOptions` — ändert an dieser Einschätzung nichts, kein eigenes ADR nötig. Die
  Issue-#50-Erweiterung, Paket 1 (2026-09-27), ist ebenfalls kein eigenes ADR wert: Regel 9 führt
  einen bestehenden `@State` nach, statt ihn neu zu entwerfen; Regel 10 fügt eine reine Funktion
  neben eine bestehende; Regel 11 ergänzt eine Bedingung im bestehenden Eingangsfilter von
  `save()`. Die einzige
  Invarianten-Änderung (Nr. 1) ist im Text selbst begründet und gegen eine Alternative
  abgewogen (siehe „Alternativen").

## Definition of Done

Beobachtbar für den PO, ohne Code zu lesen:

- Im Bon-Prüf-Screen ist jede erkannte Position eine eigene Karte: oben der Text, wie er auf dem
  Bon gedruckt steht, darunter antippbare Zeilen mit dem passenden Artikelnamen.
- Ein Treffer aus der eigenen Liste ist vorausgewählt; ist er falsch, reicht ein Antippen einer
  anderen Zeile oder „Anderer Name …", um den Namen zu ändern — keine Tastatur im Normalfall
  nötig.
- Passt keiner der angezeigten Treffer zum bereits eingetragenen Namen der Position, erscheint
  dieser Name selbst zusätzlich als eigene, angehakte Zeile (Issue #37) — der Nutzer verliert den
  aktuellen Stand nie aus den Augen.
- Ein von der App vorgeschlagener Name ist als „KI-Vorschlag" erkennbar und bricht nicht mehr
  mitten im Wort um.
- Unten in der Karte stehen Preis sowie, wo erkennbar, Menge/Gewicht und der daraus berechnete
  Stück- oder Kilopreis; Preis und Menge (Stück oder Gramm) lassen sich über „Ändern" korrigieren.
- Ein Häkchen oben rechts an jeder Karte bestimmt, ob die Position beim Speichern berücksichtigt
  wird; die Kopfzeile darüber zeigt jederzeit „N Positionen · M ausgewählt · Summe" korrekt.
- Speichern übernimmt die gewählten Namen und Preise wie bisher in die Liste — kein bisheriges
  Verhalten geht verloren.
- **(Issue #50, Paket 1)** Ändert sich der Namensvorschlag einer Karte NACH dem Öffnen (z. B. beim
  Zurückkommen aus einer geteilten App), zeigt die Karte den neuen Namen sofort als markierte
  Zeile — nicht mehr „Häkchen gesetzt, kein Kreis gefüllt", und der Name steht nicht mehr nur
  versteckt im Feld „Anderer Name …".
- **(Issue #50, Paket 1)** Leert man das Feld „Anderer Name …" versehentlich vollständig, bleibt
  die Position unter ihrem vorherigen Namen gespeichert, statt kommentarlos ohne Namen dazustehen.
- Alle zugehörigen automatisierten Tests (Unit und UI, siehe Test Plan) sind grün; keine manuelle
  Nachprüfung durch den PO nötig.

## Expected Behavior

- Öffnet sich der Bon-Prüf-Screen (Kamera/Fotos-Scan oder Rücksprung aus einer geteilten App wie
  „Lidl Plus"), erscheint für jede erkannte Position sofort eine Karte im oben beschriebenen
  Aufbau — keine zusätzliche Ladezeit gegenüber heute.
- Tippen auf eine Auswahlzeile wechselt sofort (ohne Bestätigungsdialog) den Namen dieser Karte
  und aktualisiert `matchedItemID`/`resolvedByAI` entsprechend der Quelle der Auswahl.
- Tippen auf „Anderer Name …" öffnet die Tastatur direkt an dieser Karte; jede Eingabe wird laufend
  übernommen (kein separater „Übernehmen"-Schritt), identisch zum heutigen Verhalten.
- Tippen auf „Ändern" bei der Preiszeile öffnet Preis- und Mengenfeld direkt an dieser Karte; die
  Anzeige darüber aktualisiert sich, sobald ein neuer Wert eingegeben oder Stück/Gramm umgeschaltet
  wird.
- Ab-/Anwählen des Häkchens dimmt/hellt die Karte sofort auf und aktualisiert Section-Kopf-Zahl und
  -Summe ohne spürbare Verzögerung.
- „Speichern" bleibt erst aktiv, wenn mindestens eine Position ausgewählt ist und (falls
  zutreffend) der Laden bestätigt wurde — unverändert zum heutigen `canSave`-Verhalten.

## Known Limitations

- Der Mengen-Editor kennt nur „Stück" und „Gramm" (ml zählen als Gramm-Äquivalent, wie beim
  Preis-Lernen heute). Die im Bontext gedruckte Größe („400g") lässt sich nicht als Text ändern —
  nur durch Eintragen eines Gewichts überschreiben.
- Die Qualität der Listen-Treffer hängt weiterhin von der heutigen, noch nicht verschärften
  Vorschlags-Regel ab (Floor 0,2, Limit 5 vor Kappung auf 3) — bis #29 umgesetzt ist, können
  darunter auch inhaltlich unpassende Treffer als Auswahlzeile erscheinen (die Karte zeigt sie
  dann trotzdem an, kappt nur die Anzahl, nicht die Qualität).
- Ohne #28 lässt sich diese Karte nicht automatisiert im UI-Test erreichen — die Implementierung
  dieser Spec setzt voraus, dass #28 bereits gemerged ist.
- Bei sehr vielen Positionen (z. B. 20+) wird der Screen deutlich länger als heute (Trade-off der
  PO-freigegebenen Variante B, siehe Alternativen/Risiken).
- **Issue #37, ungelöster Randfall:** Sind nach Kappung auf 3 (Regel 4) weniger als 3 Kandidaten
  vorhanden (1 oder 2), UND passt keiner zu `line.name`, fügt Regel 5 den geltenden Namen hinzu,
  ohne dass ein Kandidat entfallen muss (die Kandidatenzahl bleibt dann unter 3) — dieser Teilfall
  ist von der PO-Entscheidung implizit mitgetragen (Ziel „max. 3 inhaltliche Kandidaten" bleibt
  gewahrt), aber nicht gesondert im Issue diskutiert worden, da das reproduzierte Symptom stets 3
  Kandidaten zeigte.
- **Issue #50, Paket 1, bewusst NICHT behoben:** Eine Zeile, die bereits MIT leerem `line.name`
  aus der Auflösung kommt (z. B. ein OCR-Fund ohne erkennbaren Namen — außerhalb des Scopes, gehört
  zu `ReceiptResolutionService`/`ReceiptParserService`), zeigt weiterhin keine automatisch
  markierte Option, bis der Nutzer selbst wählt (Regel 6, unverändert seit Issue #37). Regel 10
  (Zusage 3) schließt nur den EINEN produktiv erreichbaren Weg zu einem leeren Namen (das Feld
  „Anderer Name …" bis auf null Zeichen leeren).
- **Issue #37/#50, vorbestehende, ungeprüfte Randbedingung:** Trägt ein `.listMatch`-Kandidat
  denselben Namen wie `line.name` (Regel 3 sortiert ihn dadurch nach vorn), aber sein
  `suggestion.itemID` weicht von `line.matchedItemID` ab (zwei verschiedene Artikel mit exakt
  gleichem Namen im selben Laden), kann `isSelected` für diese Zeile `false` liefern, obwohl Regel
  5 mangels Namens-Mismatch keinen `.currentName`-Ausweg einfügt — eine Karte ohne markierte Zeile
  trotz nicht-leerem Namen. Vorbestehend seit Issue #37 (Regel 3/5 unverändert), von Paket 1 weder
  eingeführt noch behoben; Invariante 6 ist deshalb ausdrücklich auf Zeilen beschränkt, deren
  `matchedItemID`/`resolvedByAI` aus einem der bekannten Zuweisungswege stammen.

## Changelog

- 2026-09-22: Initial spec created
- 2026-09-22: Briefing-Fund — Bontext bricht um statt abzuschneiden; AC1-Test an der langen Seed-Zeile
- 2026-09-22: PO-Korrektur — „Ändern" öffnet Preis und Menge (Stück/Gramm), nicht nur Preis; Preiszeile folgt `learningQuantity` inkl. gedruckter Füllmenge
- 2026-09-23: Implementiert und gemergt (`ReceiptReviewCard.swift`, 18 Unit-Tests in `ReceiptReviewCardTests.swift`, 15 UI-Tests in `ReceiptReviewUITests.swift`); `ReceiptLineRow` aus `ReceiptScannerView.swift` entfernt. Status auf `implemented` gesetzt, Test Plan abgehakt.
- 2026-09-24: Issue #37 — PO-Entscheidung: Entspricht keiner der bis zu 3 Kandidaten-Zeilen dem
  aktuell geltenden Namen der Position und ist dieser nicht leer, wird er zusätzlich als eigene,
  vorausgewählte Zeile angeboten (schwächster bisheriger Kandidat entfällt). AC-4 präzisiert, neue
  Regel 5 in `selectionOptions` ergänzt (Implementation Details Abschnitt 2), Test Plan um zwei neue
  Fälle plus Ergänzung des bestehenden Tests erweitert, Scope um die Issue-#37-Erweiterung ergänzt.
  Approval auf offen zurückgesetzt, erneute Freigabe erforderlich.
- 2026-09-27: Issue #50, Paket 1 — PO-Entscheidung: eingefrorene Auswahlliste wird nachgeführt,
  wenn `line.name` sich von außen ändert und keine Option mehr passt (Regel 9); ein leeres Feld
  „Anderer Name …" fällt auf die vorherige Auswahl zurück statt `line.name` leer zu schreiben
  (Regel 10); `save()`s Eingangsfilter überspringt Positionen mit leerem Namen (Regel 11, gezielte
  Änderung von Invariante 1 — die in der Analyse behauptete Wirkung über `looseMatch` wurde in
  `/40-tdd-red` widerlegt und in Regel 11 richtiggestellt). Neue Invariante 6, AC-13 bis AC-16,
  Test Plan erweitert. Status auf
  `draft` gesetzt, Approval erneut zurückgesetzt. Issue #50, Paket 2 (Bontext lesbar/kopierbar/
  wählbar) bleibt Issue #65 vorbehalten, nicht Teil dieser Erweiterung.
</content>
