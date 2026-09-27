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

---

# Analysis (Phase 2, 2026-09-27)

## Type

**Bug** mit angehängter Erweiterung. Punkt 4 ist ein Datenfehler (falscher Name wird gespeichert
und dauerhaft gelernt), Punkt 2 dessen sichtbare Seite. Punkt 1 und der erste Teil von Punkt 3
sind Darstellung. Der zweite Teil von Punkt 3 (Bontext als wählbare Option) ist eine vom PO
freigegebene Erweiterung, kein Fehler.

## Reproduktion — erfolgt, ohne Code-Änderung

**Belege:** `docs/artifacts/fix-50-import-dialog-design/repro-punkt4.png` (voller Screen),
`repro-karte-btr.png` (Ausschnitt), Nutzlast `repro-payload.json`, Werkzeug `repro-inject.py`.

Der Fehler wurde am 2026-09-27 auf `Restock-Validate` ausgelöst. Kein Produktivcode und kein
Testcode wurde dafür geändert (`git diff --stat SmartCart/` war und blieb leer; ein Versuch, den
Seed zu erweitern, wurde vom `edit_gate` korrekt abgelehnt und nicht umgangen).

**Weg:** Die Bon-Übergabe (`ReceiptShareHandoff`, App-Group-`UserDefaults`,
Schlüssel `pendingShareExtensionReceipt`) wurde direkt in den App-Gruppen-Speicher des Simulators
gelegt — derselbe Kanal, den die Teilen-Erweiterung benutzt. Nutzlast: die vier Zeilen der
bestehenden Fixture plus eine fünfte mit `name == originalName == "BTR"`, `resolvedByAI == false`.

**Zwei Fallstricke, die den ersten Versuch scheitern ließen** (für Wiederholungen festhalten):
1. `cfprefsd` im Simulator cached die App-Group-Preferences. Wird die Plist bei laufendem Gerät
   geändert, liest die App den alten Stand. Richtige Reihenfolge: `simctl shutdown` →
   Nutzlast legen → `simctl boot` → `simctl launch`.
2. Die Bundle-ID ist `com.johannesemmrich.Restock` (nicht `com.henemm.…`, nicht
   `com.johannesemmrich.SmartCart` — Letzteres ist die App-Gruppe).

**Ergebnis:** Die Karte „BTR" zeigt das Häkchen gesetzt und **keinen** gefüllten Auswahlkreis,
während die vier unveränderten Karten daneben je genau eine Markierung tragen. Identisch zum
Screenshot in Issue #50.

## Root Cause — belegt

`ReceiptReviewCard.swift:85` hält die Auswahlzeilen als `@State options`, gefüllt einmalig in
`onAppear` (Z. 108–110). `isSelected` (Z. 352–366) vergleicht diese eingefrorene Liste bei jedem
Zeichnen gegen das **lebende** `line.name`. Ein `onChange(of: line.name)` existiert nirgends.

`ReceiptScannerView.swift:316` hängt `.task { await reResolveAIIfNeeded() }` an den
`NavigationStack`. Die Methode (Z. 326–336) löst genau die Zeilen neu auf, für die
`name == originalName && !resolvedByAI` gilt (`linesNeedingAIReresolution`, Z. 101–105), und
schreibt das Ergebnis über `mergeAIReresolution` (Z. 112–127) nach `line.name` — **nach** dem
ersten Zeichnen, weil dazwischen mindestens ein `await` plus `MainActor`-Hop liegt. Die Karten
sind zu dem Zeitpunkt strukturell längst erschienen; das ist kein knapper Wettlauf.

Folge: `line.name` trägt einen Wert, den keine eingefrorene Option kennt → jede Option liefert
`false` → kein Radio gefüllt (**Punkt 4**). Derselbe Wert erscheint erst, wenn „Anderer Name …"
angetippt wird, weil `select(.custom)` das Feld mit `line.name` vorbelegt (Z. 361) — **Punkt 2**.

**Zwei Einschränkungen, beide geprüft:**
- Nur über den Handoff-Pfad. `reResolveAIIfNeeded` bricht bei `cameFromShareHandoff == false` ab
  (Z. 327). Kamera/Foto/PDF lösen in `process()` (Z. 524–598) synchron vollständig auf und setzen
  `phase = .review` erst danach — dort entsteht die Karte schon mit dem Endnamen.
- **Unabhängig von Apple Intelligence.** Stufe 5 ist im Simulator nicht verfügbar, aber
  `ReceiptResolutionService.resolve()` hat vier deterministische Stufen davor; das statische
  Wörterbuch `abbreviationExpansions` (`ReceiptParserService.swift:1033–1048`) enthält
  `"btr": "Butter"`. Der Fehler tritt rein regelbasiert auf — und auf Henning's Gerät, wo Stufe 5
  läuft, entsprechend häufiger.

**Wirkung über die Optik hinaus:** `save()` schreibt `line.name`, und
`ReceiptAliasService.learn(receiptText: line.originalName, itemName: line.name)` merkt sich die
Zuordnung dauerhaft. Bestätigt wird also ein Name, den der Nutzer nie gesehen hat; liegt die
Auflösung daneben, wird der Fehler eingelernt.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | Nachführen der eingefrorenen Optionen bei externem Namenswechsel; Bontext-Darstellung (15 pt, `Color.ink`) und Kontextmenü „Kopieren"; ggf. neuer Options-Fall für die Bon-Zeile inkl. `selectionOptions`/`isSelected`/`applySelection`. |
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | Nur bei Paket 3: wortweise Normalisierungsregel neben `smartCapitalize` (Z. 1008–1019). |
| `SmartCart/SmartCartApp.swift` | MODIFY | Zusätzlicher DEBUG-Seed, der Invariante 1 bewusst verletzt (eine Zeile `name == originalName`), plus passendes Aufräum-Argument. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | 6 Tests mit festen `options.count`/Indizes; `testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` kehrt sich um. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | 4 Tests mit fest verdrahteten `option.<k>`-Indizes; neuer Test für „immer genau eine Markierung" am reproduzierten Fall. |
| `docs/specs/views/receipt-review-card.md` | MODIFY | Invariante 5 (höchstens 3 inhaltliche Optionen) und Regel 5/6; Status geht auf `draft` zurück. |
| `docs/specs/testing/receipt-review-test-entry.md` | MODIFY | Invariante 1 bekommt eine benannte Ausnahme für den neuen Seed. |

## Scope Assessment

- Dateien: **7** — über dem Limit von 4–5.
- Geschätzte LoC: Produktcode ≈ 50–70, Testcode ≈ 195–300 → **≈ 250–370 gesamt**, über ±250.
  Das LoC-Gate zählt Testcode als Produktivcode (Memory `loc-gate-zaehlt-testcode-als-produktiv`),
  die Grenze würde also mitten in Phase 6 zuschlagen.
- Risiko: **MITTEL**. Isoliert auf einen Screen, aber 10 bestehende Tests hängen an Options-Zählung
  und -Reihenfolge, und die geltende Spec ist `implemented`.

**→ Empfehlung: #50 in drei Lieferungen teilen.** Jede für sich unter den Grenzen.
**ÜBERHOLT durch die PO-Entscheidung vom 2026-09-27 (zweigeteilt) — siehe Abschnitt
„PO-Entscheidungen" am Ende dieser Datei. Die folgende Tabelle bleibt nur als Herleitung stehen.**

| Paket | Inhalt | Dateien | LoC (grob) |
|-------|--------|---------|-----------|
| **1 — Auswahl stimmt wieder** (Punkte 2 + 4) | Optionen bei externem Namenswechsel nachführen; immer genau eine Markierung | Card, SmartCartApp (Seed), Unit-Tests, UI-Tests, Test-Spec | ≈ 120 |
| **2 — Bontext wird lesbar** (Punkt 1 + Kopieren) | 15 pt, `Color.ink`, Kontextmenü „Kopieren" | Card, UI-Tests, Spec | ≈ 70 |
| **3 — Bontext wird wählbar** (Punkt 3, zweiter Teil) | Eigene Options-Zeile, normalisierte Schreibweise | Card, Parser, Unit-Tests, UI-Tests, Spec | ≈ 180 |

Reihenfolge begründet: Paket 1 ist das einzige, das heute falsche Daten schreibt. Paket 3 ist der
größte Eingriff und ändert eine zugesagte Invariante — es soll nicht die Fehlerkorrektur aufhalten.

## Technical Approach

**Paket 1 — die eingefrorene Liste nachführen, nicht aufgeben.**
Der Grund fürs Einfrieren bleibt gültig (Kommentar Z. 78–83: sonst springt die angetippte Zeile
unter dem Finger nach vorn, weil `selectionOptions` die gewählte Option nach vorn sortiert). Die
minimale Korrektur ist deshalb **nicht** „jedes Mal neu berechnen", sondern: bei einem Wechsel von
`line.name`, der zu **keiner** vorhandenen Option passt, die Liste einmal neu berechnen.

```
.onChange(of: line.name) { _, _ in
    guard !options.contains(where: { isSelected($0) }) else { return }
    options = Self.selectionOptions(for: line)
}
```

Nach einem Nutzer-Tap passt der Name immer zu einer vorhandenen Option, die Liste bleibt also
stehen — das Springen kehrt nicht zurück. Nur der Fall „von außen geändert" löst die Neuberechnung
aus. Zusätzlich greift dann Regel 5 und schiebt den neuen Namen als markierte Zeile an Position 0,
womit Punkt 2 im selben Zug erledigt ist.

**Alternative zu Paket 1, die ich verworfen habe:** den Prüf-Screen erst zeigen, wenn
`reResolveAIIfNeeded()` durch ist. Behebt die Ursache an der Wurzel, kostet aber sichtbare
Wartezeit beim Öffnen aus der Teilen-Erweiterung und ändert am Kern — eine Liste, die ihren
Zustand nicht nachführt — nichts. Bei jeder künftigen Quelle für Namensänderungen (iCloud-Nachzug,
Alias-Lernen) wäre der Fehler zurück.

**Paket 2 — Kontextmenü statt `.textSelection`.** Recherche in Phase 1 ergab: `.textSelection`
markiert auf iOS immer den gesamten `Text`, nicht Teile davon, war in `List` unter iOS 18.0 defekt
(seit 18.1 repariert, aber 18.0 ist ein realer Zielzustand) und ist per XCUITest kaum verlässlich
prüfbar. Ein `.contextMenu` mit „Kopieren" (`UIPasteboard.general.string = line.originalName`)
deckt den genannten Zweck vollständig ab, ist versionsunabhängig und automatisiert prüfbar.
**Alternative:** beides setzen — kostet nichts, verspricht aber eine Teilmarkierung, die iOS hier
nicht bietet.

**Paket 3 — Regel, kein Modell.** Die Normalisierung läuft über eine Wortliste/Regel, nicht über
Apple Intelligence: `smartCapitalize` existiert bereits, greift aber nur bei durchgehender
Großschreibung und setzt nur das erste Wort groß („SKYR NATUR 500G" → „Skyr natur 500g"). Für einen
anzeigefähigen Namen ist das zu grob; eine wortweise Regel („Skyr Natur 500g") ist deterministisch,
messbar und ohne Laufzeitkosten. Ein Sprachmodell ist hier nicht begründbar.

**Offene Designfrage in Paket 3:** Bei einem Kürzel wie „BTR" ergibt jede Normalisierung nur „Btr" —
die Bon-Zeile als Option ist dort wertlos bis irreführend. Zu klären in der Spec: Wird die Option
unterdrückt, wenn sie dem bereits gewählten Namen entspricht oder unter einer Mindestlänge liegt?

## Dependencies

- **Upstream:** `ReceiptResolutionService` (Stufen 1–5), `ReceiptParserService.smartCapitalize`,
  `ReceiptShareHandoff`, `ReceiptAliasService`.
- **Downstream:** `ReceiptScannerView.save()` — die Bedeutung von `name`/`matchedItemID`/
  `resolvedByAI` darf sich nicht verschieben, sonst bricht das Preis- und Alias-Lernen.
- **Spec-Kette:** `receipt-review-card.md` (Invariante 5) und `receipt-review-test-entry.md`
  (Invariante 1) müssen mitgeführt werden; beide sind `implemented` und gehen auf `draft` zurück.

## Entwurfs-Vorschau

`docs/artifacts/fix-50-import-dialog-design/entwurf-bonkarte.html` — veröffentlicht unter
https://claude.ai/artifact/LJSZx4d1ayg2wSacMEGL1r

Zeigt Heute / Entwurf A / Alternative B nebeneinander, in den echten Farbtoken der App, hell und
dunkel umschaltbar, plus die beiden Belegbilder und den Teilungsvorschlag.

## Open Questions

- [x] **Entwurf A oder Alternative B?** Empfehlung A (erfüllt alle vier Punkte; die wählbare
      Bon-Zeile hat der PO ausdrücklich freigegeben). B ist deutlich billiger, lässt aber Punkt 3
      zweiter Teil offen.
- [x] **Dreiteilung in der vorgeschlagenen Reihenfolge — oder alles in einem Zug?**
      Empfehlung war dreiteilen. **Entschieden: zweigeteilt** — die Dreiteilungs-Tabelle im
      Abschnitt „Scope Assessment" oben ist damit überholt, maßgeblich ist die Zwei-Pakete-Tabelle
      unter „PO-Entscheidungen".
- [x] **Normalisierung:** roh lassen, `smartCapitalize` („Skyr natur 500g") oder wortweise
      („Skyr Natur 500g")? Empfehlung: wortweise.

## PO-Entscheidungen (2026-09-27) — lösen die „Open Questions" oben auf

Vorlage war die Entwurfs-Vorschau
`docs/artifacts/fix-50-import-dialog-design/entwurf-bonkarte.html`
(veröffentlicht: https://claude.ai/artifact/LJSZx4d1ayg2wSacMEGL1r).

1. **Entwurf A ist freigegeben.** Der Bontext wird groß (15 pt, `Color.ink`), kopierbar **und**
   als eigene, antippbare Auswahlzeile mit der Beschriftung „wie auf dem Bon" angeboten.
   Alternative B (Bontext bleibt reine Beschriftung) ist damit verworfen.

2. **Zweigeteilt** — abweichend von meiner Dreiteilungs-Empfehlung:

   | Paket | Inhalt | LoC (grob) |
   |-------|--------|-----------|
   | **1 — Auswahl stimmt wieder** | Punkte 2 + 4: eingefrorene Optionen bei externem Namenswechsel nachführen; immer genau eine Markierung | ≈ 120 |
   | **2 — Bon-Zeile lesbar und wählbar** | Punkt 1 + Punkt 3 (beide Teile): 15 pt / `Color.ink`, Kontextmenü „Kopieren", eigene Options-Zeile mit normalisierter Schreibweise | ≈ 250 |

   **Risiko, offengelegt:** Paket 2 liegt bei etwa 250 LoC und damit genau auf der Grenze —
   und das LoC-Gate zählt Testcode als Produktivcode (Memory
   `loc-gate-zaehlt-testcode-als-produktiv`). In `/30-write-spec` ist deshalb ein Schnitt
   vorzusehen, an dem Paket 2 notfalls in „Darstellung" und „wählbare Zeile" zerfällt, ohne die
   Spec neu schreiben zu müssen. Das ist eine Umsetzungsvorsorge, keine erneute PO-Frage.

3. **Normalisierung: jedes Wort groß.** „SKYR NATUR 500G" → „Skyr Natur 500g".
   Als **feste Regel**, nicht über ein Sprachmodell — das Ergebnis muss bei gleicher Eingabe
   immer gleich ausfallen und ohne Laufzeitkosten messbar sein.
   Das bestehende `smartCapitalize` (`ReceiptParserService.swift:1008–1019`) bleibt unangetastet,
   weil es an vier Parser-Stellen mit anderer Absicht benutzt wird; die neue Regel tritt daneben.

   Offen für die Spec (Umsetzungsdetail, keine PO-Frage): Bei kurzen Kürzeln ergibt jede
   Normalisierung nur Unsinn („BTR" → „Btr"). Die Spec legt fest, wann die Bon-Zeile
   unterdrückt wird — Vorschlag: wenn sie dem bereits gewählten Namen entspricht (ohne Rücksicht
   auf Groß-/Kleinschreibung) oder unter einer Mindestlänge liegt.

## Nachtrag (2026-09-27): PO-Hinweis „Anderer Name übernimmt schon heute etwas"

Henning, während Phase 2: *„Schon heute wird, wenn man ‚anderer Name' auswählt, der Text (oder
irgendetwas) sinnvoll übernommen. Aber das ist in der UI nicht sichtbar, was unschön ist."*

**Geprüft — die Beobachtung stimmt, und sie ist präziser als vermutet.**

`ReceiptReviewCard.swift:358–362`:

```swift
if case .custom = option {
    customName = line.name      // ← Vorbelegung
    customActive = true
```

Übernommen wird nicht der Bontext, sondern **`line.name`** — der bereits aufgelöste Artikelname,
also exakt der Wert, den `save()` schreiben und `ReceiptAliasService.learn` dauerhaft merken würde.
Das Textfeld ist damit heute der **einzige Ort im ganzen Screen**, an dem dieser Name sichtbar
wird — hinter einem Tippen, das wie „ich will jetzt selbst etwas eintippen" aussieht.

Das stützt die Ursachenanalyse: Punkt 2 und Punkt 4 sind ein und derselbe Fehler. Die Karte
*kennt* den guten Namen die ganze Zeit; sie zeigt ihn nur nicht.

**Nicht visuell nachgestellt:** Diese Xcode-Installation enthält keine `Simulator.app`, ein
Antippen von Hand ist hier also nicht möglich; `cliclick`/`idb` fehlen ebenfalls. Der Nachweis
oben ist rein aus dem Code geführt (Zuweisung, Feld-Binding, Wirkungskette) — der sichtbare
Beleg kommt in Phase 4 als UI-Test, der genau diese Vorbelegung prüft.

### Dabei gefunden: ein zweiter Weg in „keine Option markiert" — ohne Teilen-Erweiterung

`applyCustomName` (`ReceiptReviewCard.swift:463–467`) hängt an `.onChange(of: customName)` und
schreibt **jeden** Zwischenstand durch:

```swift
line.name = name
line.matchedItemID = nil
line.resolvedByAI = false
```

Leert der Nutzer das vorbelegte Feld, steht `line.name == ""` und die Artikelzuordnung ist weg.
Die Karte zeigt weiter eine Markierung (`isSelected(.custom) == customActive`), aber sobald der
Zustand der Karte verlorengeht — `List` recycelt Zellen beim Scrollen, `@State customActive` fällt
dabei auf `false` zurück — bleibt eine Karte mit **leerem Namen und ohne Markierung**. Genau
diesen Zustand hält der bestehende Unit-Test
`testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches`
(`RestockTests/ReceiptReviewCardTests.swift:193–209`) heute ausdrücklich als gewolltes Verhalten
fest.

### Und die Folge beim Speichern ist schwerwiegender als gedacht

`ReceiptScannerView.save()` sucht den Artikel notfalls über eine Substring-Suche
(`looseMatch`, Z. 644–650):

```swift
record.itemName.lowercased().contains(lineLower) || lineLower.contains(record.itemName.lowercased())
```

Bei leerem `lineLower` ist der erste Vergleich **immer wahr** — nachgemessen, nicht vermutet:
`docs/artifacts/fix-50-import-dialog-design/probe-empty-name.swift` gibt
`record.itemName.contains(leer) = true`. Der Bon-Preis landet damit auf dem *erstbesten*
Kaufdatensatz dieses Ladens im 7-Tage-Fenster — auf einem beliebigen Artikel.

Das Kürzel-Lernen ist gegen diesen Fall geschützt (`ReceiptAliasService.learn` bricht bei leerem
Namen ab, Z. 35). Die Preiszuordnung ist es **nicht**.

### Auswirkung auf den Zuschnitt

Paket 1 („Auswahl stimmt wieder") bekommt damit eine dritte Zusage:

1. Der aufgelöste Name steht sichtbar als markierte Zeile — nicht erst im Eingabefeld.
2. Es ist immer genau eine Option markiert.
3. **Ein leerer Name ist kein speicherbarer Zustand.** Zu entscheiden in `/30-write-spec`:
   Rückfall auf die vorher gewählte Option beim Leeren, oder Sperre des Speicherns für diese
   Position. Empfehlung: Rückfall — er hält den Screen bedienbar, statt den Nutzer vor einer
   gesperrten Schaltfläche stehen zu lassen.

Das hebt Paket 1 von ≈ 120 auf ≈ 150 LoC. Beide Pakete bleiben damit im Rahmen; Paket 2 bleibt
der kritische Kandidat für einen weiteren Schnitt.
