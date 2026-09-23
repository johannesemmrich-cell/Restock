---
entity_id: receipt-review-card
type: feature
created: 2026-09-22
updated: 2026-09-23
status: implemented
workflow: feat-23-receipt-review-screen
tags: [feature, ui, receipt-scanner]
---

# Bon-Prüf-Screen: Positionen als Karte mit Auswahl statt Tippen

## Approval

- [x] Approved

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
| `ReceiptScannerView.save()` (`ReceiptScannerView.swift:540-662`) | Downstream Consumer | Semantik von `name`/`matchedItemID`/`resolvedByAI`/`originalName` darf sich durch diese Spec nicht ändern — `save()` selbst wird nicht angefasst. |
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
5. Gibt es nach Schritt 1-4 keinen einzigen inhaltlichen Kandidaten (kein Treffer, kein
   KI-Vorschlag), wird stattdessen genau ein `.currentName(line.name)` gebildet.
6. `.custom` wird immer als letztes Element angehängt → **max. 4 Optionen insgesamt.**

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

1. **`save()` bleibt unverändert** — keine Änderung an `ReceiptScannerView.swift:540-662`.
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
   `selectionOptions`.

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
- **AC-4:** Der beste Treffer / aktuelle Zustand der Zeile ist vorausgewählt.
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
- **AC-12:** Speichern schreibt weiterhin über den unveränderten `save()`-Pfad (Regressionsschutz).

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
  wäre für einen UI-Umbau dieses Umfangs unverhältnismäßig.

## Definition of Done

Beobachtbar für den PO, ohne Code zu lesen:

- Im Bon-Prüf-Screen ist jede erkannte Position eine eigene Karte: oben der Text, wie er auf dem
  Bon gedruckt steht, darunter antippbare Zeilen mit dem passenden Artikelnamen.
- Ein Treffer aus der eigenen Liste ist vorausgewählt; ist er falsch, reicht ein Antippen einer
  anderen Zeile oder „Anderer Name …", um den Namen zu ändern — keine Tastatur im Normalfall
  nötig.
- Ein von der App vorgeschlagener Name ist als „KI-Vorschlag" erkennbar und bricht nicht mehr
  mitten im Wort um.
- Unten in der Karte stehen Preis sowie, wo erkennbar, Menge/Gewicht und der daraus berechnete
  Stück- oder Kilopreis; Preis und Menge (Stück oder Gramm) lassen sich über „Ändern" korrigieren.
- Ein Häkchen oben rechts an jeder Karte bestimmt, ob die Position beim Speichern berücksichtigt
  wird; die Kopfzeile darüber zeigt jederzeit „N Positionen · M ausgewählt · Summe" korrekt.
- Speichern übernimmt die gewählten Namen und Preise wie bisher in die Liste — kein bisheriges
  Verhalten geht verloren.
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

## Changelog

- 2026-09-22: Initial spec created
- 2026-09-22: Briefing-Fund — Bontext bricht um statt abzuschneiden; AC1-Test an der langen Seed-Zeile
- 2026-09-22: PO-Korrektur — „Ändern" öffnet Preis und Menge (Stück/Gramm), nicht nur Preis; Preiszeile folgt `learningQuantity` inkl. gedruckter Füllmenge
- 2026-09-23: Implementiert und gemergt (`ReceiptReviewCard.swift`, 18 Unit-Tests in `ReceiptReviewCardTests.swift`, 15 UI-Tests in `ReceiptReviewUITests.swift`); `ReceiptLineRow` aus `ReceiptScannerView.swift` entfernt. Status auf `implemented` gesetzt, Test Plan abgehakt.
