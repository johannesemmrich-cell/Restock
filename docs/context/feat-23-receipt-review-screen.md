# Context: feat-23-receipt-review-screen (Issue #23)

## Request Summary
Der Screen, der nach einem Bon-Import erscheint („Bon scannen — Lidl", Prüf-/Korrekturliste der
erkannten Positionen), ist laut PO praktisch unlesbar. „Solange der nicht überarbeitet ist, ist der
Bon-Import wertlos." Der Screen ist die einzige Stelle, an der der Nutzer gelernte Preise vor dem
Speichern prüft — er ist damit Voraussetzung für den Leitzweck aus #8 (bessere Preise → belastbare
Einkaufssumme → Preisvergleich, Issues #10–#15).

Screenshot (Issue #23, iPhone, Dark Mode, Lidl-Bon, Rücksprung aus „Lidl Plus" = Weg über die
Teilen-Erweiterung): `docs/artifacts/feat-23-receipt-review-screen/issue-23-screenshot.png`.

## Was der Screenshot zeigt (Beobachtung, noch keine Ursache)

| # | Befund | Stelle im Code |
|---|---|---|
| 1 | Pille „KI-Vorschlag" bricht in 4 Zeilen um (`KI-`/`Vor`/`sch`/`lag`) | `ReceiptLineRow`, `Label("KI-Vorschlag", systemImage: "sparkles")` in einem `HStack` neben dem `TextField` — ohne `fixedSize`/`lineLimit`/Layout-Priorität |
| 2 | Namen abgeschnitten: „Griespud…", „Früchtch…", „Pinienke…" | derselbe `HStack`: `TextField` + Stift + Pille konkurrieren mit dem Preisfeld (`frame(width: 62)`) um die Breite |
| 3 | Original-Bontext fehlt — „Fisch 1,99" und „Fisch 7,99" sind nicht zuzuordnen | `EditableReceiptLine.originalName` existiert, wird aber nirgends angezeigt (nur für `ReceiptAliasService.learn` genutzt) |
| 4 | Vorschlags-Chips laufen rechts aus dem Bild und passen inhaltlich nicht („Fisch" → Hafersahne, Flammkuchenteig, Rote Linsen) | `ReceiptResolutionService.resolve` füllt `suggestions` aus `completedItemCandidates(for:in: store.items)` mit `completedItemSuggestionFloor = 0.2` und `limit = 5` — Pool sind ALLE Artikel des Ladens, auch offene |
| 5 | Bearbeiten-Stift kaum sichtbar | `Image(systemName: "pencil")`, 10 pt, `.tertiary` |
| 6 | Toggle, Name, Stift, Pille, Euro-Zeichen, Preisfeld in einer Zeile | `ReceiptLineRow.body`, `HStack(spacing: 10)` |

Nicht auf dem Screenshot, aber Teil desselben Screens: Section-Header „Gefunden: N Positionen",
Footer-Hinweis („Tippe auf einen Namen …"), Bon-Summen-Warnung (`totalMismatchWarning`),
„Ausgewählt"-Summe, „Neues Foto"-Knopf, orange Laden-Bestätigung (`storeNeedsConfirmation`, nur
nach Teilen-Erweiterung). Der Screenshot ist bereits nach unten gescrollt — was oberhalb stand, ist
unbekannt.

## Related Files

| Datei | Relevanz |
|---|---|
| `SmartCart/Views/Prices/ReceiptScannerView.swift` (810 LoC) | Enthält `EditableReceiptLine` (Zeilenmodell, Z. 11–91), `ReceiptScannerView` (Capture/Processing/Review, Z. 95–655), `ReceiptLineRow` (die eigentliche Zeile, Z. 659–770, `private`), `ImagePickerRepresentable`. `save()` (Z. 526–650) schreibt die Preise. |
| `SmartCart/Services/ReceiptResolutionService.swift` (219) | Liefert `ResolvedReceiptLine` mit `name`, `originalName`, `suggestions`, `matchedItemID`, `resolvedByAI`. Vorschlags-Chips entstehen in Z. 76–142. Geteilt mit der Teilen-Erweiterung. |
| `SmartCart/Services/ReceiptParserService.swift` (1310) | `completedItemCandidates` (Z. 1142), `lcsSimilarity` (Z. 1087), Schwellen `completedItemAutoApplyThreshold = 0.6` und `completedItemSuggestionFloor = 0.2` (Z. 1132–1134). |
| `SmartCart/Services/ReceiptShareHandoff.swift` (43) | `SharedReceiptPayload` — Wire-Format Erweiterung → App; enthält `lines`, `rawLines`, `detectedTotal`, `storeConfidentlyDetected`. Einstieg in den Review ohne OCR (`init(store:prefilled:)`). |
| `SmartCart/Extensions/DesignSystem.swift` (269) | Farb-Tokens (`Color.surface/.ink/.textSecondary/.hairline/.accent/.accentContainer/.amber`), `RCRadius` (tag 6 / control 10 / card 14), `cardStyle()`, `PressableButtonStyle`, `toolbarChip`, `ChipToolbarItem`. Keine Typografie-Skala außer `Font.wordmark`. |
| `SmartCart/Views/Store/StoreDetailView.swift` Z. 324/385 | Einstieg Kamera/Fotos: `.sheet { ReceiptScannerView(store:) }` |
| `SmartCart/Views/Home/HomeView.swift` Z. 195 | Einstieg Teilen-Erweiterung: `ReceiptScannerView(store:prefilled:storeConfidentlyDetected:)` via `checkPendingReceiptScan()` |
| `RestockShareExtension/ShareViewController.swift` | Erzeugt das Payload (Stufe 1–4 ohne KI); die App holt Stufe 5 in `reResolveAIIfNeeded()` nach |
| `SmartCart/Views/Prices/ActualPriceEntryView.swift` | Konkurrierender Weg (Gesamtsumme eintippen) — gleiche Zeilen-Optik? Nur Referenz |
| `SmartCart/Views/Components/ItemRow.swift` | Zeilen-Muster der normalen Einkaufsliste (Toggle links, Name, Preis rechts) — Konsistenz-Referenz |

## Existing Patterns

- **Zeile mit Toggle links, Preis rechts**: `ItemRow` (Liste) — der Review-Screen imitiert das,
  hat aber zusätzlich Stift, Pille, Detailzeile und Chips in derselben Zelle.
- **Vorschlags-Chips**: `HomeView` Mengen-Vorschläge nutzen dieselben Bausteine (`RCRadius.tag`,
  `Color.surface`, `.hairline`, `.pressable`, `Haptics.impact(.light)`); `ReceiptLineRow` kopiert
  das in einen horizontalen `ScrollView` ohne Abschluss-Hinweis (Chips laufen aus dem Bild).
- **Laden-Korrektur**: `confirmationDialog` mit einem Button je Laden (wie `HomeView`).
- **Warnungen**: orange Section mit `listRowBackground(Color.orange.opacity(0.08))` — zweimal im
  Screen (Laden unsicher, Summe passt nicht).
- **Art.-50-Kennzeichnung (EU AI Act)**: Die Pille „KI-Vorschlag" ist bewusst dort, wo der Vorschlag
  erscheint (Kommentar in `ReceiptLineRow`). Sie darf beim Umbau nicht verschwinden, nur anders
  dargestellt werden.
- **Strings**: Alle Texte des Screens sind hart im Swift-Code auf Deutsch (kein
  `String(localized:)`, keine Keys in `Resources/de.lproj/Localizable.strings`). Die UI-Tests
  hängen an Anzeigetexten (#18).
- **Design-Ebenen**: `DesignSystem.swift` dokumentiert „Spec §2/§4" (Ebene 0 Haarlinie statt
  Schatten, Ebene 1 Banner, Ebene 2 Sheets). Die Spec-Datei selbst liegt nicht im Repo.

## Dependencies

- **Upstream (was der Screen nutzt)**: Vision-OCR → `ReceiptParserService.parse` →
  `ReceiptResolutionService.resolve` → `EditableReceiptLine`. Store, `PurchaseRecord`-Query,
  `ReceiptAliasService`, `ReceiptNameAIResolver` (FoundationModels), `SyncCoordinator`.
- **Downstream (was von ihm abhängt)**: `save()` schreibt `store.learnedPrices`,
  `item.estimatedPrice`, `PurchaseRecord.actualPrice/date`, lernt Aliase, pusht Sync. Jede Änderung
  an der Zeile darf die Semantik von `name`/`originalName`/`matchedItemID`/`resolvedByAI` nicht
  verändern — `save()` und die Alias-Lernlogik hängen daran (Kommentare in `ReceiptLineRow`).
- **Teilen-Erweiterung**: `ResolvedReceiptLine`/`ReceiptSuggestion` sind `Codable` und liegen als
  Payload in App-Group-UserDefaults. Feldänderungen brauchen Defaults (siehe Kommentare zu
  `weightBasis`/`resolvedByAI`).

## Existing Specs / Kontext

- `docs/context/check-8-bon-zweck.md` — Leitzweck (Phase 1 bessere Preise, Phase 2 Preisvergleich),
  PO-Antworten, Regelweg-vor-Modell-Befund. Enthält bereits den Hinweis: „Kein Test berührt den
  produktiven Speicherpfad" (`save()`).
- `docs/specs/services/receipt-parser-quantity-confirmation.md` — Stückzahl/Gewicht (#9), betrifft
  `detailText` in der Zeile („6 × 0,20 € · 1,5l").
- Keine Spec für den Review-Screen selbst. Kein UI-Test erreicht ihn.

## Bestehende Tests

- Unit: `RestockTests/Receipt*.swift` (Parser, Suggestion-Schwellen, Re-Resolution, AI-Sanitize,
  Price-Learning über `learningQuantity`) — Logik, keine Darstellung.
- UI: `RestockUITests/RestockUITests.swift` (4 Tests, keiner öffnet den Scanner);
  `ReceiptShareExtensionTests.swift` (Cross-App, prüft App-Gruppe/Absturzberichte, nicht die UI).
- Es gibt **kein Bon-Foto-Fixture** im Repo; `ReceiptParserLidlFullReceiptTests` hat rekonstruierte
  Textzeilen eines echten Lidl-Bons.

## Risks & Considerations

1. **Der Screen ist im UI-Test schwer erreichbar**: Kamera/Fotos → OCR läuft im Simulator nicht
   deterministisch. Einziger OCR-freier Einstieg ist `init(store:prefilled:)` über
   `ReceiptShareHandoff` (App-Group-UserDefaults) — ein UI-Test kann die nicht direkt setzen. Für
   RED/GREEN braucht es einen Testeinstieg (Launch-Argument mit Payload o. ä.) — Entscheidung in
   der Analyse.
2. **Reproduktion**: Wird im Simulator nachgestellt — Dark Mode, iPhone-Breite, Zeile mit
   `resolvedByAI = true`, langem Namen und ≥3 Vorschlägen. Ohne Reproduktion kein Fix (globale
   Regel).
3. **Zwei Problemklassen**: (a) Darstellung (Pille, Abschneiden, Stift, Chips-Überlauf) und
   (b) Inhalt (Bontext fehlt, Vorschläge unpassend, Schwelle 0,2). (b) berührt
   `ReceiptResolutionService`/`ReceiptParserService` und die Teilen-Erweiterung. Scoping-Limit
   (4–5 Dateien, ±250 LoC) wird bei (a)+(b) zusammen sehr wahrscheinlich gerissen → Analyse muss
   eine Aufteilung vorschlagen.
4. **EU-AI-Act-Kennzeichnung** muss erhalten bleiben — nur die Form darf sich ändern.
5. **`private struct ReceiptLineRow`** in einer 810-Zeilen-Datei — ein Umbau der Zeile bietet sich
   als eigene Datei an (Registrierung in `project.pbxproj` nötig, siehe CLAUDE.md).
6. **Dark Mode**: Der Screenshot ist dunkel; Tokens kommen aus Asset-Katalog-Farben (`RC*`), also
   müssen beide Modi geprüft werden.
7. **Design-Skill**: Henning will den `frontend-design`-Skill (installiert 2026-09-22) im Entwurf
   sehen — in `/20-analyse` laden, Token-System/Wireframe/Selbstkritik daraus ableiten.
8. **Regelweg vor Modell**: Die unpassenden Chips sind ein Regel-Problem (Schwelle/Pool), kein
   Modell-Problem — Lösung in Regeln, nicht in mehr KI.

## Offene Produktfragen für die Analyse (PO-Input nötig)

- Soll der Original-Bontext je Zeile sichtbar sein (klein unter dem Namen), oder nur auf Tipp?
- Sollen Vorschlags-Chips überhaupt bleiben — oder reicht Tippen auf den Namen mit Auswahl?
- Muss der Preis je Zeile editierbar bleiben, oder genügt Anzeige + An/Aus?

## Analysis

### Type
Feature (Umbau eines bestehenden Screens; die Einzelbefunde sind Layout-Fehler, aber die Lösung
ist ein Neuentwurf der Zeile, kein punktueller Fix).

### Root Cause (belegt im Code, Screenshot reproduziert die Befunde 1–6)

| # | Befund | Ursache (Datei:Zeile) |
|---|---|---|
| 1, 2, 6 | Pille bricht 4-zeilig um, Namen abgeschnitten, alles in einer Zeile | `ReceiptScannerView.swift:684–713`: `HStack(spacing: 4)` mit `TextField` + Stift + `Label("KI-Vorschlag")` — ohne `fixedSize()`/`layoutPriority`. Das Preisfeld hat feste 62 pt, der Toggle 51 pt; SwiftUI verteilt den Rest gleichmäßig auf TextField und Label → das Label bekommt ~40 pt und bricht wortweise um. |
| 3 | Bontext fehlt | `originalName` wird nur in `save()` (Alias-Lernen, Z. 552), `linesNeedingAIReresolution()` (Z. 70) und `learningQuantity()` (Z. 59) gelesen — nie angezeigt. |
| 4 | Chips unpassend + laufen aus dem Bild | `ReceiptResolutionService.swift:89,102`: Pool = `store.items` (alle), Vergleich gegen den **rohen** OCR-Text, `completedItemSuggestionFloor = 0.2` (`ReceiptParserService.swift:1134`). Bei LCS-Ratio 0,2 passt fast jeder Name („Fisch"/„Hafersahne" = 0,40). Der Nutzer sieht aber den KI-Namen, nicht den Rohtext, zu dem die Chips berechnet wurden — die Chips wirken deshalb zufällig. Horizontaler `ScrollView` ohne Abschluss (Z. 749). |
| 5 | Stift unsichtbar | Z. 703: 10 pt, `.tertiary` — im Dark Mode kein Kontrast. |
| — | Zusätzlich: Toggle inkonsistent | `ItemRow.swift:50` nutzt einen Häkchen-Kreis, der Review-Screen einen 51-pt-`Toggle`. |

Warum die Namen so generisch sind („Fisch", „Käse"): Alle Zeilen auf dem Screenshot sind
`resolvedByAI = true` — Stufe 5 (`ReceiptNameAIResolver`, Prompt Z. 1273–1283) liefert „kurze
generische Namen". Das ist kein Layout-Thema, sondern Inhalt von #8/#14 (Regelweg vor Modell) —
hier nur relevant, weil der Bontext als Anker fehlt.

### Design-Entwurf (nach `frontend-design`-Skill: Tokens → Wireframe → Selbstkritik)

**Job des Screens:** Der Nutzer hat den Bon in der Hand und prüft Zeile für Zeile: „Ist das der
richtige Artikel, stimmt der Preis?" Dann Speichern. Das Charakteristische ist der **Bon selbst** —
die Zeile muss die Brücke „Bon-Zeile → Artikel auf meiner Liste" zeigen.

**Tokens (keine neuen — Palette ist durch `DesignSystem.swift` festgelegt):**
- Farbe: `Color.ink` (Name), `Color.textSecondary` (Bontext, Preis-Währung), `Color.accent`/
  `Color.accentContainer` (KI-Marke), `Color.surface` + `Color.hairline` (Chips, Ebene 0),
  `Color.amber` (Warnungen, unverändert).
- Typografie (System-Font, wie `ItemRow`): Name 16 pt regular · Bontext 12 pt, `.textSecondary`,
  Großschreibung **wie auf dem Bon gedruckt** (Rohtext unverändert, keine Label-Kapitälchen) ·
  Preis 16 pt medium tabular · KI-Marke 11 pt semibold · Chips 12 pt medium · Detail 11 pt.
- Layout: linksbündig, Preis rechtsbündig, zwei Informationszeilen pro Position, Chips als dritte
  Zeile nur wenn vorhanden.

**Wireframe (iPhone-Breite, Dark Mode wie Light):**
```
┌────────────────────────────────────────────────┐
│ ◉  SEELACHSFILET 250G                          │  ← Bontext (originalName), 12 pt, secondary
│    Fisch  ✦KI                        1,99 €    │  ← Name (TextField, 16 pt) · KI-Marke fixedSize · Preis
│    ┌──────────┐ ┌────────────┐ ┌──────────┐    │
│    │Lachsfilet│ │Seelachs    │ │Fischstäb.│    │  ← max 3 Chips, Score ≥ 0,45, kein Überlauf
│    └──────────┘ └────────────┘ └──────────┘    │
├────────────────────────────────────────────────┤
│ ◉  KAESE GOUDA JUNG                            │
│    Gouda                             3,99 €    │  ← kein KI-Vorschlag → keine Marke, kein Platzverlust
│    6 × 0,66 € · 400 g                          │  ← Detailzeile (#9) bleibt
└────────────────────────────────────────────────┘
```
- `◉` = derselbe Häkchen-Kreis wie in `ItemRow` (statt `Toggle`): konsistent mit der Liste, spart
  ~30 pt Breite, Bedeutung „wird gespeichert".
- Der **Bontext steht oben** (nicht als Untertitel): Der Nutzer liest vom Bon in der Hand nach unten
  — erst „was stand da", dann „was die App daraus gemacht hat". Bewusste Umkehr des generischen
  Musters „Titel groß, Untertitel klein".
- Editierbarkeit ohne Stift-Icon: Das Namensfeld bekommt eine Haarlinie unten (`Color.hairline`),
  wie ein Formularfeld — sichtbar in beiden Modi, braucht keine Breite. Preisfeld ebenso.
- KI-Marke: `Label("KI-Vorschlag", systemImage: "sparkles").fixedSize()` — bleibt am Ort des
  Vorschlags (Art. 50), aber direkt hinter dem Namen und nie umbrechend. Ist der Name zu lang,
  weicht der Name (`lineLimit(1)`, `truncationMode(.tail)`), nie die Marke oder der Preis.
- Chips: Bekommen keinen Prefix-Text („Meintest du:") — das Wort „Vorschlag" steht schon in der
  Marke und im Footer. Kein horizontaler Scroll mehr: max 3 Chips, bei Überbreite umbrechend
  (`ViewThatFits` oder Flow-Layout) — nichts läuft aus dem Bild.

**Selbstkritik (Skill: „Was würde ich für jeden ähnlichen Screen bauen?"):** Der generische
Entwurf wäre „Name fett, Bontext grau darunter, Pille rechts, Chips scrollbar". Geändert:
(1) Bontext nach oben als Anker — das ist die spezifische Aufgabe dieses Screens, (2) keine
Scroll-Chips mehr — auf einem Prüf-Screen darf nichts verborgen sein, (3) Stift raus, Haarlinie
rein — ein Accessoire weniger. Nicht geändert: Häkchen-Kreis und Preis-rechts — das ist die
Sprache der App, kein Default.

**Echte Alternative (Layout):** Name oben groß, Bontext darunter als Untertitel — vertrauter,
näher am iOS-Standard (`Text`/`Text.secondary`-Paar), aber der Bontext wird zur Fußnote, obwohl er
das Prüfkriterium ist. Nicht empfohlen; wäre eine reine PO-Geschmacksfrage, kein Technik-Thema.

### Affected Files (with changes)

| Datei | Change | Beschreibung |
|---|---|---|
| `SmartCart/Views/Prices/ReceiptLineRow.swift` | CREATE | Neue Zeile (aus `ReceiptScannerView.swift` extrahiert und neu aufgebaut), inkl. `accessibilityIdentifier`s |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | `private struct ReceiptLineRow` entfernen (Z. 665–770); Footer-Text anpassen; IDs auf Speichern-Knopf |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Registrierung der neuen Datei (4 Stellen, manuell — kein Auto-Discovery) |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Launch-Argument `-seedReceiptReviewForUITests`: Laden + Artikel seeden, `ReceiptShareHandoff.store(payload)` mit festem Bon (KI-Zeile, langer Name, ≥3 Chips) — HomeView öffnet das Sheet über den **echten** Weg |
| `RestockUITests/ReceiptReviewUITests.swift` | CREATE | UI-Tests: Sheet erscheint; Bontext sichtbar; Name nicht abgeschnitten (Label == voller Name); KI-Marke einzeilig (Frame-Höhe); max 3 Chips; Speichern schreibt Preis (Nachweis via Store-Detail) |
| `SmartCart/Services/ReceiptResolutionService.swift` | MODIFY | Chips: `limit: 3` explizit; ggf. Vergleich zusätzlich gegen `resolvedName` |
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | `completedItemSuggestionFloor` 0,2 → 0,45 (Messung gegen Lidl-Fixture) |
| `RestockTests/ReceiptParserSuggestionTests.swift` | MODIFY | Test, der den Floor gegen echte Lidl-Zeilen misst („Fisch"/„Hafersahne" raus, „MDHSZ"/„Mozzarella" bleibt) |

### Scope Assessment
- Gesamt: 8 Dateien, ≈ +420 / −110 LoC → **reißt das Limit (4–5 Dateien, ±250 LoC)**.
- Zerlegung in drei Lieferungen, jede innerhalb des Limits:

| Lieferung | Dateien | LoC | Inhalt |
|---|---|---|---|
| A — Testeinstieg | `SmartCartApp.swift`, `ReceiptReviewUITests.swift` (neu), `ReceiptScannerView.swift` (IDs) | ≈ +170 | Seed-Argument + Payload-Fixture + erster UI-Test (Sheet öffnet sich, Zeilen sichtbar). Zeigt RED für B: Test „Name vollständig / Marke einzeilig" schlägt am heutigen Layout fehl. |
| B — Zeilen-Umbau (#23-Kern) | `ReceiptLineRow.swift` (neu), `ReceiptScannerView.swift`, `project.pbxproj` | ≈ +190 / −110 | Wireframe oben. Macht A grün. |
| C — Chip-Regel | `ReceiptResolutionService.swift`, `ReceiptParserService.swift`, `ReceiptParserSuggestionTests.swift` | ≈ +40 | Floor 0,45 + Limit 3, gemessen. Unabhängig von A/B. |

- Risk Level: **MEDIUM** — B berührt nur Darstellung (Semantik von `name`/`originalName`/
  `matchedItemID`/`resolvedByAI` bleibt, `save()` unverändert); C ändert eine Regel, die die
  Teilen-Erweiterung mitnutzt (kein Feld, nur Konstante → kein Wire-Format-Risiko);
  Toolbar-Safe-Area-Falle (`DesignSystem.swift:199–209`) wird nicht berührt.

### Technical Approach (Empfehlung)
1. **Reihenfolge A → B → C.** A liefert den reproduzierbaren Einstieg (Nachstellen im Simulator
   über denselben Weg wie Henning: Teilen-Erweiterung → HomeView → Sheet) und den RED-Test.
2. Zeile nach Wireframe; `fixedSize()` auf der KI-Marke und `layoutPriority`/`lineLimit(1)` auf dem
   Namen sind die technischen Kernpunkte; Häkchen-Kreis wie `ItemRow`; Chips ohne ScrollView.
3. Chip-Regel: Floor 0,45 (über den beobachteten Fehltreffern ≈ 0,40, unter der Auto-Übernahme
   0,6, unter echten Kürzungen 0,57–0,65 laut Kommentar `lcsSimilarity`), Limit 3 per explizitem
   Parameter (der Default 5 und sein Test bleiben). Nulllinie: Unit-Test misst an den Lidl-Zeilen.
4. Keine neue KI, kein Prompt-Umbau (Regelweg vor Modell). Die generischen KI-Namen bleiben Thema
   von #8/#14.

**Verworfen:** Chips durch Tipp-Auswahl-Dialog ersetzen (größerer Umbau, PO-Frage offen, reißt
Limit allein); Limit-Default 5 → 3 (bricht `testCompletedItemCandidatesDefaultLimitIsFive`, war
bewusster PO-Wunsch); Payload aus dem UI-Test-Prozess in die App-Group-Defaults schreiben (Fremd-
prozess, Entitlement-Unsicherheit — Seed im App-Prozess ist deterministisch).

### Dependencies
- `ReceiptShareHandoff.store/takePending` (unverändert) — Träger des Testeinstiegs.
- `HomeView.checkPendingReceiptScan()` (Z. 1565) — braucht ≥1 aktiven Laden → Seed legt ihn an.
- `ItemRow.swift:50` — Häkchen-Kreis-Muster für Konsistenz.
- `ReceiptParserLidlFullReceiptTests` — Datenbasis für die Floor-Messung.
- Wire-Format `ResolvedReceiptLine`/`ReceiptSuggestion`: **keine Feldänderung** in A–C.

### Open Questions (PO)
- [ ] Zerlegung in A/B/C als drei Issues (A und C neu, B = #23) — oder alles in #23 trotz Limit?
- [ ] Bontext immer sichtbar über dem Namen (Empfehlung) — oder nur auf Tipp?
- [ ] Chips bleiben (max 3, strengere Regel) — oder ganz weg zugunsten einer Tipp-Auswahl?
- [ ] Preis je Zeile bleibt editierbar (Empfehlung) — oder nur Anzeige + An/Aus?

### PO-Entscheidungen (2026-09-22, Phase 2)
1. **Zerlegung in drei Schritte, drei Issues:** A = #28 (Testeinstieg, zuerst), B = #23 (Zeilen-Umbau,
   dieser Workflow), C = #29 (Vorschlags-Regel). Reihenfolge A → B → C.
2. **Bontext immer sichtbar, über dem Namen.**
3. **Chips bleiben — max. 3, nur passende** (Schwelle 0,45; → #29).
4. **Preis je Zeile bleibt änderbar.**

### Design-Vorschau (PO will Entwurf vor Spec sehen)
- Datei: `docs/artifacts/feat-23-receipt-review-screen/entwurf-zeile.html` (+ Screenshot)
- Veröffentlicht: https://claude.ai/artifact/5pRovFPPuJFRnL1MuAQAvx — „Heute" neben „Entwurf"
  (Dunkel), heller Modus, Alternative „Bontext unter dem Namen" (nicht empfohlen), Liste der
  sechs Änderungen. Bontexte im Mockup sind Beispiele (echte Lidl-Rohzeilen liegen nicht vor).
- **Status: Freigabe des Entwurfs durch den PO steht aus** — erst danach `/30-write-spec #23`.
  Korrekturen am Entwurf werden hier ergänzt, bevor die Spec entsteht.

### Entwurf, Runde 2 (PO-Feedback 2026-09-22)
PO zu Runde 1: „zu klein, zu eng für eine Touch-Oberfläche". Vorgabe: Position in zwei Abschnitte
teilen — (1) Bontext → KI-Name → 3 antippbare Alternativen, (2) Preis mit Stückzahl/Kilopreis/
Menge/Gewicht. Zwei Alternativvorschläge gewünscht.

Runde 2 (gleiche URL, Version 2): Jede Position ist eine Karte mit zwei Abschnitten.
- **A · Karte mit zwei Abschnitten** (PO-Idee): Bontext + Häkchen 28 pt, Name 20 pt als Feld,
  3 Alternativen als 40-pt-Tasten + „Anders …", Preisblock als drei Spalten (Preis / Menge oder
  Gewicht oder Größe / je Stück oder je kg berechnet).
- **B · Auswahl statt Tippen** (Empfehlung): statt Feld + Chips eine Einfachauswahl mit Zeilen
  à 48 pt: Listen-Treffer (Quelle „auf deiner Liste"), KI-Vorschlag (gekennzeichnet), „Anderer
  Name …" (Tastatur). Bester Treffer vorausgewählt. Preis als eine Zeile „1,99 € · 1 St. · je
  Stück" mit „Ändern". Nachteil: hohe Karten.
- **C · Eine Position nach der anderen**: Vollbild je Position, „2 von 7", Name 28 pt,
  Alternativen als volle Tasten, unten „Nicht speichern" / „Weiter". Nachteil: kein Überblick.
- Preisblock zeigt nur, was `ReceiptLine` liefert: `price`, `quantity`, `unit`, `weightBasis`
  (Gramm) → je Stück = price/quantity, je kg = price/weightBasis·1000 (berechnet, Kontrolle).
- Scope-Hinweis: B/A vergrößern Schritt B (#23) gegenüber der Runde-1-Schätzung (Karte statt
  Zeile, Auswahlliste, Preisblock) — neu schätzen in der Spec; ggf. Preisblock-Editor als
  eigenes Issue.
- **Status: PO-Freigabe einer Variante steht aus.**

### PO-Freigabe Entwurf (2026-09-22): **Variante B · Auswahl statt Tippen**
Verbindliche Grundlage für die Spec (#23, Schritt B):
- Jede Position = Karte, zwei Abschnitte, Häkchen 28 pt oben rechts (abgewählt → gedimmt).
- Abschnitt 1: Bontext (`originalName`, wie gedruckt) → Einfachauswahl, Zeilen à 48 pt, max. 4:
  bis zu 3 Listen-Treffer (Quelle „auf deiner Liste", `matchedItemID`), der KI-Vorschlag
  (`resolvedByAI`, Marke „KI-Vorschlag" an der Zeile — Art. 50), „Anderer Name …" (Tastatur).
  Bester Treffer vorausgewählt; Auswahl setzt `name`/`matchedItemID`/`resolvedByAI` exakt wie
  heute Chip-Tap bzw. manuelle Eingabe (Semantik für `save()` unverändert).
- Abschnitt 2: eine Zeile „Preis · Menge/Gewicht/Größe · je Stück/je kg" + „Ändern" (Preis- und
  Mengeneingabe). Werte nur aus `price`/`quantity`/`unit`/`weightBasis`; je Stück und je kg
  berechnet.
- Section-Kopf: „N Positionen · M ausgewählt · Summe".
- #29 (Vorschlags-Regel) bleibt relevant: liefert die Listen-Treffer für die Auswahlzeilen
  (Schwelle 0,45, max. 3). #28 (Testeinstieg) unverändert vor #23.
- Offen für die Spec: Umfang neu schätzen (Karte + Auswahlliste + Preiszeile + „Ändern"-Eingabe);
  falls > Limit, „Ändern"-Editor als eigenes Issue abtrennen.

### PO-Entscheidung zur Spec (2026-09-22, Phase 3)
- „Bitte direkt Menge und Preis änderbar machen." → „Ändern" in der Preiszeile öffnet Preis **und**
  Menge (Zahl + Umschalter Stück/Gramm). Die Abtrennung des Mengen-Editors als Folge-Issue entfällt.
- Damit ist der größere Umfang (≈ 720 LoC über 5 Dateien, Limit ±250) vom PO in Kauf genommen —
  die A/B/C-Aufteilung bleibt, B wird nicht weiter geteilt.
- Preiszeile zeigt dieselbe Lernbasis wie `save()` (`learningQuantity`: Gewichtszeile → Stückzahl
  → gedruckte Füllmenge via `weightBasisFromName` → 1 Stück), damit der Nutzer den Stück-/Kilopreis
  sieht, den die App lernen wird.
