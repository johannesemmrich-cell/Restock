# Context: fix-50-import-dialog-design

Issue: #50 „Import Dialog entspricht nicht dem Design" · Track: Standard · Phase 1, 2026-09-27
Die PO-Klärung der vier Punkte steht in `docs/context/fix-50-import-dialog-design.intake.md`
und ist Teil dieses Kontexts.

## Request Summary

Der Bon-Prüf-Screen (`ReceiptScannerView` → `ReceiptReviewCard`) soll dem Design entsprechen:
Der Bontext in jeder Karte ist zu klein und nicht markierbar/kopierbar; ein guter Namensvorschlag
wird erst sichtbar, nachdem man „Anderer Name …" auswählt; und es gibt Karten, in denen gar keine
Option markiert ist. Zusätzlich vom PO freigegeben: den Bontext als eigene, antippbare Option mit
normalisierter Schreibweise anbieten.

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | Die Karte selbst: Bontext-Zeile (Z. 118–127), Auswahlzeilen (`optionRow`, Z. 172–219), eingefrorener Zustand `@State options` (Z. 84) mit `onAppear` (Z. 108), `isSelected` (Z. 341–356), `select` (Z. 358–373), reine Regel `selectionOptions(for:)` (Z. 398–439). Hauptänderungsort aller vier Punkte. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | `EditableReceiptLine` (Z. 11–110) inkl. `linesNeedingAIReresolution`/`mergeAIReresolution`; `.task { await reResolveAIIfNeeded() }` (Z. 316) und `reResolveAIIfNeeded()` (Z. 326–336) — schreiben `line.name` NACH dem ersten Zeichnen; Abschnitts-Kopf/Fußnote der Liste (Z. 465–500); `save()` (ab Z. 600). |
| `SmartCart/Services/ReceiptResolutionService.swift` | Liefert `suggestions`, `matchedItemID`, `resolvedByAI`; setzt `originalName: line.name` (Z. 185) — der Bontext der Karte ist also der Parser-Name, nicht der reine OCR-Rohtext. |
| `SmartCart/Services/ReceiptParserService.swift` | `smartCapitalize` (Z. 1008–1019) — die bereits existierende Großschreibungs-Normalisierung, an vier Parser-Stellen angewandt. Für Punkt 3 (Normalisierung) die entscheidende Fundstelle. |
| `SmartCart/Extensions/DesignSystem.swift` | Farb-Tokens und `RCRadius`. **Kein Typografie-Token vorhanden** — alle Schriftgrößen der Karte stehen als `\.font(.system(size: …))` hart im Code. |
| `RestockUITests/ReceiptReviewUITests.swift` | 17 bestehende UI-Tests auf genau diesem Screen, u. a. auf Options-Indizes (`option.0`…`option.4`), Section-Kopf und Bontext-Sichtbarkeit. Jede Änderung an Reihenfolge oder Anzahl der Optionen bricht sie. |
| `RestockTests/ReceiptReviewCardTests.swift` | Unit-Tests der reinen Regeln (`selectionOptions`, `priceSummary`, `sectionHeaderText`). |
| `SmartCart/SmartCartApp.swift` (Z. 241 ff.) | DEBUG-Seed `-seedReceiptReviewForUITests` — der einzige OCR-freie Testeinstieg in diesen Screen. |

## Existing Specs

- `docs/specs/views/receipt-review-card.md` — die geltende Spec der Karte (Issue #23, erweitert um #37). Status `implemented`.
- `docs/specs/testing/receipt-review-test-entry.md` — der Testeinstieg (Issue #28) samt „Invariante 1 — Fixture-Determinismus".
- `docs/context/feat-23-receipt-review-screen.md` — freigegebener Entwurf „Variante B · Auswahl statt Tippen", inkl. `docs/artifacts/feat-23-receipt-review-screen/entwurf-zeile.html`.
- `docs/context/fix-37-receipt-name-preselect.md` — Vorgeschichte zu „Name ist nicht vorausgewählt" (Regel 5).

## Existing Patterns

- **Reine Regeln getrennt von der View.** `selectionOptions`, `priceSummary`, `sectionHeaderText`, `applySelection` sind `static` und ohne SwiftUI testbar. Neue Regeln (Normalisierung, Vorauswahl) gehören in dieselbe Schicht, nicht in den View-Body.
- **Optionen werden bewusst eingefroren.** `@State options` wird einmal in `onAppear` berechnet, damit die angetippte Zeile nicht unter dem Finger nach vorn springt (Kommentar Z. 78–83). Jede Korrektur an Punkt 2/4 muss diese Absicht erhalten.
- **Schriftgrößen hart, Farben über Tokens.** Die Karte benutzt `Color.ink`/`.textSecondary` usw., aber feste Punktgrößen (13 für den Bontext, 15 für die Optionen, 14 für den Preis).
- **Großschreibungs-Normalisierung existiert schon** (`smartCapitalize`) und läuft beim Parsen — allerdings nur, wenn der GESAMTE String Großbuchstaben ist, und sie setzt nur das erste Wort groß („SKYR NATUR 500G" → „Skyr natur 500g").
- **Alle Strings des Screens sind hart auf Deutsch** (bewusst, siehe Spec „Out of Scope").

## Dependencies

- **Upstream:** `ReceiptParserService` (Bontext + `smartCapitalize`), `ReceiptResolutionService` (Vorschläge, KI-Name), `ReceiptAliasService` (gelernte Kürzel), `ReceiptShareHandoff` (Übergabe aus der Teilen-Erweiterung).
- **Downstream:** `ReceiptScannerView.save()` — lernt `ReceiptAliasService.learn(receiptText: line.originalName, itemName: line.name)` und schreibt Preise auf `matchedItemID`. Die Bedeutung von `name`/`matchedItemID`/`resolvedByAI` darf sich nicht verschieben.

## Befund: Punkte 2 und 4 haben vermutlich dieselbe Ursache

**Hypothese, in Phase 2 zu reproduzieren — noch NICHT bewiesen.**

Die Auswahlliste einer Karte wird einmalig in `onAppear` berechnet. Beim Weg über die
Teilen-Erweiterung läuft danach `.task { await reResolveAIIfNeeded() }` und überschreibt
`line.name` für genau die Zeilen, die noch unaufgelöst sind (`name == originalName &&
!resolvedByAI`). Die eingefrorene Liste kennt diesen neuen Namen nicht:

- Keine Zeile trägt mehr den geltenden Namen → **keine Option ist markiert** (Punkt 4). Genau so
  sieht die erste Karte im Screenshot des Issues aus: Haken gesetzt, alle vier Kreise leer.
- Der neue (oft gute) Name taucht erst auf, wenn man „Anderer Name …" antippt, weil `select(.custom)`
  das Textfeld mit `line.name` vorbelegt (Z. 361) → **Punkt 2**.

Wirkung beim Speichern: `save()` benutzt `line.name`, also einen Namen, den der Nutzer nie zu
sehen bekam — und `ReceiptAliasService.learn` merkt sich genau diese Zuordnung dauerhaft. Der
Fehler ist damit nicht nur kosmetisch.

**Der bestehende Testeinstieg deckt diesen Fall bewusst NICHT ab.** Die Fixture erfüllt
„Invariante 1 — Fixture-Determinismus" (`docs/specs/testing/receipt-review-test-entry.md`,
Z. 179 ff.): Jede Zeile ist entweder KI-aufgelöst oder trägt einen vom Bontext abweichenden Namen,
damit `reResolveAIIfNeeded()` gar nicht erst läuft. Für einen Nachweis von Punkt 4 braucht es
einen zweiten, ausdrücklich gegenläufigen Einstieg — ohne die Determinismus-Garantie der
bestehenden 17 Tests aufzugeben.

## Recherche: Bontext markierbar machen (Punkt 3, erster Teil)

`.textSelection(.enabled)` ist der SwiftUI-Weg für markierbaren, nicht editierbaren Text. Auf iOS
markiert ein langer Druck den GESAMTEN `Text` und öffnet das Systemmenü (Kopieren/Teilen) — eine
Teilmarkierung gibt es dort nicht. In `List` war die Modifier-Wirkung in iOS 18.0 defekt und ist
seit iOS 18.1 wieder funktionsfähig; die App setzt iOS 18+ voraus, 18.0 ist also ein realer
Zielzustand. Ein langer Druck ist zudem mit XCUITest kaum verlässlich prüfbar.

**Alternative, die ich in Phase 2 gegenüberstellen werde:** ein `.contextMenu` mit „Kopieren"
direkt am Bontext (`UIPasteboard.general.string = line.originalName`). Deterministisch, ohne
OS-Versionsabhängigkeit, automatisiert prüfbar — und deckt genau den vom PO genannten Zweck ab
(Bontext weiterverwenden), während `.textSelection` zusätzlich das Markieren von Teilen suggeriert,
das iOS hier gar nicht bietet.

Quellen: [Apple — textSelection(_:)](https://developer.apple.com/documentation/swiftui/view/textselection(_:)) · [Apple Developer Forums — .textSelection(.enabled) not working in List on iOS 18](https://developer.apple.com/forums/thread/763852) · [featherless software design — textSelection broken in List on iOS 18](https://jeffverkoeyen.com/blog/2024/09/19/iOS18-textSelection-broken/) · [Hacking with Swift — How to let users select text](https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-select-text)

## Risks & Considerations

1. **Bestehende UI-Tests hängen an Options-Indizes.** Eine zusätzliche Bontext-Option verschiebt
   `option.0`…`option.4` und bricht mindestens `testCardShowsAtMostFourSelectionOptions`,
   `testTappingListMatchSelectsThatOption`, `testCustomNameOptionOpensFocusedTextField`,
   `testTypingCustomNameIsAppliedWithEveryKeystroke`.
2. **Invariante 5 der geltenden Spec** erlaubt höchstens drei inhaltliche Optionen plus „Anderer
   Name …". Eine feste Bontext-Option ist eine Änderung dieser Invariante, nicht nur eine Ergänzung.
3. **Determinismus-Konflikt.** Der Nachweis für Punkt 4 braucht eine Zeile, die die Fixture heute
   ausdrücklich verbietet. Lösungsvorschlag gehört in Phase 2.
4. **Normalisierung kann Namen verschlechtern.** `smartCapitalize` macht aus „SKYR NATUR 500G" ein
   „Skyr natur 500g" — für einen anzeigefähigen Artikelnamen zu grob. Ob die Bontext-Option roh
   oder normalisiert angeboten wird, ist eine PO-Entscheidung mit Folgen fürs Alias-Lernen.
5. **Scoping.** Vier Punkte plus Testeinstieg-Erweiterung sprengen zusammen die ±250-LoC-Grenze
   voraussichtlich. In Phase 2 ist zu entscheiden, ob #50 geteilt wird (Darstellung vs. Auswahl-
   Korrektur).
6. **Das LoC-Gate zählt Testcode als Produktivcode** (Memory, Issue #36) — bei 17 betroffenen
   UI-Tests relevant für die Planung der Phasen 4–6.
7. **Der eingefrorene Options-Zustand hat einen guten Grund** (Zeile springt sonst unter dem
   Finger). Eine Korrektur darf ihn nicht einfach durch „jedes Mal neu berechnen" ersetzen.

## Offen für Phase 2

- Reproduktion von Punkt 4 auf dem Weg, den der PO fährt (Teilen-Erweiterung → Prüf-Screen).
- Entwurfs-Vorschau (heute / Entwurf / Alternative, hell und dunkel) vor der Spec — Pflicht laut
  globaler Regel „Entwurf vor Spec bei UI-Änderungen".
- Entscheidung Bontext: markierbar (`.textSelection`) vs. „Kopieren" im Kontextmenü vs. beides.
- Entscheidung Normalisierung: roh, `smartCapitalize` oder eine eigene, wortweise Regel.
