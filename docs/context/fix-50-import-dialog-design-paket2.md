# Context: fix-50-import-dialog-design-paket2

Issue: **#65** „Bon-Karte: Bontext lesbar, kopierbar und als eigene Auswahlzeile (Paket 2 zu #50)"
· Track: Standard · Phase 1, 2026-09-28

Paket 1 (Punkte 2+4 aus #50) ist ausgeliefert (#70, `main`-Commit `654e692`). Dieser Workflow
deckt ausschließlich Paket 2 ab: Punkt 1 und Punkt 3 aus #50.

## Request Summary

Die Bon-Zeile jeder Karte im Bon-Prüf-Screen wird lesbar (15 pt / `Color.ink` statt 13 pt /
`Color.textSecondary`), über ein Kontextmenü „Kopieren" kopierbar, und zusätzlich als eigene,
antippbare Auswahlzeile „wie auf dem Bon" mit wortweise großgeschriebener Normalisierung
(„SKYR NATUR 500G" → „Skyr Natur 500g") angeboten — per fester Regel, ohne Sprachmodell.

**Der PO hat das bereits vollständig entschieden**, siehe Issue #65 und
`docs/context/fix-50-import-dialog-design.md` Abschnitt „PO-Entscheidungen (2026-09-27)":
Entwurf A ist freigegeben, Normalisierung ist wortweise Großschreibung als feste Regel. Offen ist
ausschließlich ein **Umsetzungsdetail** (keine PO-Frage): wann die Bon-Zeile unterdrückt wird
(Vorschlag des PO: wenn sie dem bereits gewählten Namen entspricht, ohne Rücksicht auf
Groß-/Kleinschreibung, oder unter einer Mindestlänge liegt).

## Related Files

| File | Relevance |
|------|-----------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | Enthält `ReceiptNameOption`, `selectionOptions(for:)`, `nameSection`/`optionRow` — hier entstehen Font/Farbe, Kontextmenü und der neue Options-Fall. |
| `SmartCart/Services/ReceiptParserService.swift:1008-1019` | `smartCapitalize` — bleibt unangetastet (vier andere Aufrufstellen, andere Absicht). Neue wortweise Normalisierungsregel tritt daneben. |
| `RestockTests/ReceiptReviewCardTests.swift` | Unit-Tests für `selectionOptions`, Auswahl-Semantik — bekommt neue Fälle für die Bon-Zeilen-Option und die Normalisierungsregel. |
| `RestockUITests/ReceiptReviewUITests.swift` (19 bestehende Tests) | Mindestens `testCardShowsAtMostFourSelectionOptions`, `testTappingListMatchSelectsThatOption`, `testCustomNameOptionOpensFocusedTextField`, `testTypingCustomNameIsAppliedWithEveryKeystroke` hängen an `option.<k>`-Indizes, die sich durch die neue Zeile verschieben. |
| `docs/specs/views/receipt-review-card.md` | Geltende Spec — Invariante 5 („höchstens 3 inhaltliche Optionen") wird durch diese Erweiterung geändert, nicht nur ergänzt (dort bereits im Abschnitt „Out of Scope" als Paket 2 vorgemerkt). |

## Existing Patterns

- `ReceiptNameOption` ist ein geschlossenes Enum mit vier Fällen (`listMatch`, `aiSuggestion`,
  `currentName`, `custom`) — ein fünfter Fall (Bon-Zeile) folgt demselben Muster: eigener Fall,
  eigene `displayName`, eigene `matchableName`-Semantik, Einordnung in `selectionOptions`,
  `isSelected`, `select(_:)`/`applySelection`.
- `smartCapitalize` (`ReceiptParserService.swift:1008-1019`) zeigt das bestehende Muster für
  Text-Normalisierung im Parser — bewusst NICHT wiederverwendet, weil andere Absicht (nur erstes
  Wort, greift nur bei durchgehender Großschreibung). Die neue Regel bekommt eine eigene,
  wortweise Funktion daneben.
- Kontextmenüs gibt es im Screen noch nicht — `.contextMenu` mit `Button` + `UIPasteboard.general.string`
  ist Standard-SwiftUI, kein bestehendes Vorbild im Projekt nötig.

## Dependencies

- **Upstream:** `ReceiptResolutionService` (unverändert), `ReceiptParserService.smartCapitalize`
  (unverändert, bleibt neben der neuen Regel bestehen).
- **Downstream:** `ReceiptScannerView.save()` — Bedeutung von `name`/`matchedItemID`/`resolvedByAI`
  darf sich durch die neue Auswahlzeile nicht ändern; sie liefert dieselben drei Zuweisungen wie
  `.currentName` (kein Listen-Treffer, keine KI-Kennzeichnung).
- **Spec-Kette:** `docs/specs/views/receipt-review-card.md`, Invariante 5, geht auf `draft`
  zurück; `receipt-review-test-entry.md` ist zu prüfen, falls ein neuer Seed für den
  UI-Testnachweis nötig wird (bisher: keiner erkennbar, die Normalisierung ist mit den
  bestehenden Bon-Fixtures reproduzierbar).

## Existing Specs

- `docs/specs/views/receipt-review-card.md` — führt Paket 2 bereits unter „Out of Scope" auf
  (Zeilen 113-121) und benennt exakt die drei Änderungen. Diese Spec wird in `/30-write-spec`
  erweitert, nicht neu geschrieben.
- `docs/specs/views/receipt-review-card-nachtrag-1b.md` — Vorarbeit zu #66 (F001, anderes Thema),
  nur als Muster relevant, wie eine Invarianten-Änderung an dieser Karte spec-technisch
  dokumentiert wird.

## Risks & Considerations

1. **LoC-Grenze genau getroffen.** Issue #65 schätzt ≈250 LoC über vier/fünf Dateien — exakt am
   Standard-Limit. Das LoC-Gate zählt Testcode als Produktivcode (Memory
   `loc-gate-zaehlt-testcode-als-produktiv`, Issue #36). Vorsorge aus der PO-Entscheidung: Paket 2
   kann in der Spec in „Darstellung" (Font/Farbe/Kontextmenü) und „wählbare Zeile" (neuer
   Options-Fall) geschnitten werden, falls die Umsetzung die Grenze reißt.
2. **UI-Test-Indizes verschieben sich.** Mindestens vier bestehende UI-Tests hängen an
   `receiptReview.line.<i>.option.<k>` und müssen mit angepasst werden.
3. **Invariante 5 ändert sich, nicht nur ergänzt.** „Höchstens 3 inhaltliche Optionen" muss neu
   gefasst werden — Reihenfolge/Dedup zwischen Bon-Zeile und den bestehenden drei Kandidaten ist
   in der Spec explizit zu regeln (Issue #65 nennt das offene Umsetzungsdetail: Unterdrückung bei
   Namensgleichheit oder Mindestlänge).
4. **Normalisierung kann bei kurzen Kürzeln unsinnig werden** („BTR" → „Btr") — Grund für Punkt 3
   des offenen Umsetzungsdetails; PO hat Unterdrückungs-Vorschlag bereits geliefert, Spec muss ihn
   konkretisieren (Schwelle für „Mindestlänge").
5. **Determinismus/Testbarkeit.** `.textSelection` wurde bereits recherchiert und bewusst verworfen
   (iOS-18.0-Bug in `List`, kaum XCUITest-prüfbar) — Kontextmenü „Kopieren" ist die entschiedene,
   automatisiert prüfbare Alternative. Keine erneute Recherche nötig.

## Was bereits entschieden ist (keine erneute PO-Frage in diesem Workflow)

Aus Issue #65 und `docs/context/fix-50-import-dialog-design.md` Abschnitt „PO-Entscheidungen
(2026-09-27)":

1. Entwurf A freigegeben (Bontext groß, kopierbar, als eigene Auswahlzeile) — Alternative B
   verworfen.
2. Normalisierung: wortweise Großschreibung als feste Regel, kein Sprachmodell; `smartCapitalize`
   bleibt unangetastet.
3. Kontextmenü „Kopieren" statt `.textSelection`.

**Einzige offene Umsetzungsfrage für `/20-analyse`:** die Unterdrückungs-Schwelle für die
Bon-Zeilen-Option (Namensgleichheit-Vergleich, Mindestlänge) sowie die genaue Einordnung in die
Kandidaten-Reihenfolge/-Kappung von `selectionOptions`.

## Analysis

### Type

Feature — Erweiterung einer bestehenden, produktiven View um eine zusätzliche Auswahlmöglichkeit
und Darstellungsänderung. Kein Bug: Punkt 1 (Lesbarkeit) und Punkt 3 (wählbare Zeile) sind
gewünschte neue Fähigkeiten, Punkt 2 (Kopieren) eine neue Interaktion.

### Grundlage dieser Analyse

Direkt am Code, an der geltenden Spec und am freigegebenen Entwurf geprüft (nicht per
Explore-Subagent neu gesucht — Phase 1 hatte die betroffenen Stellen bereits exakt benannt, eine
zweite Suche nach denselben Dateien hätte nur dieselben Treffer wiederholt):

- `SmartCart/Views/Prices/ReceiptReviewCard.swift` vollständig gelesen (573 Zeilen) — `enum
  ReceiptNameOption`, `selectionOptions(for:)` (Regeln 1-7), `optionRow`, `isSelected`,
  `applySelection`.
- `docs/specs/views/receipt-review-card.md` — Invariante 5, AC-2/AC-4, „Out of Scope"-Abschnitt zu
  Paket 2 (Zeilen 112-121).
- `docs/artifacts/fix-50-import-dialog-design/entwurf-bonkarte.html`, Spalte „Entwurf A ·
  Empfehlung" (Zeilen 292-329) — zeigt zwei Beispiele mit tatsächlicher Zeilen-Reihenfolge.
- `ReceiptParserService.swift:1008-1019` (`smartCapitalize`) und `:1327` (`sanitize`) zur
  Abgrenzung der neuen Normalisierungsregel.
- `RestockUITests/ReceiptReviewUITests.swift:392-448` — die vier vom Kontext-Dokument benannten
  Tests, die an `option.<k>`-Indizes hängen.

### Befund am Entwurf: Bon-Zeile ist ZUSÄTZLICH, nicht Ersatz für einen der drei Kandidaten

Beide Beispiele im freigegebenen Entwurf A zeigen dasselbe Muster:

```
[bisherige Kandidaten, wie heute, max. 3]
[Bon-Zeile „wie auf dem Bon", falls nicht unterdrückt]
[Anderer Name …]
```

„Butter" (1 Kandidat) + „Btr" (Bon-Zeile) + „Anderer Name …"; „Skyr" (1 Kandidat) + „Skyr Natur
500g" (Bon-Zeile) + „Anderer Name …". Die Bon-Zeile konkurriert also NICHT um einen der drei
Plätze aus Regel 1-4 — sie kommt obendrauf, immer unmittelbar vor „Anderer Name …". Das deckt sich
mit der Einschätzung im Kontext-Dokument: Invariante 5 wird **geändert** (aus „höchstens 3
inhaltliche Optionen" wird „höchstens 3 andere Kandidaten plus optional die Bon-Zeile" = max. 4
inhaltliche Optionen), nicht nur ergänzt.

### Technischer Ansatz

**1. Darstellung (Punkt 1+2 aus Issue #65).** In `nameSection` (Zeilen 134-140): Font
`.system(size: 13)` → `.system(size: 15)`, `Color.textSecondary` → `Color.ink`. `.contextMenu`
mit einem `Button("Kopieren") { UIPasteboard.general.string = line.originalName }` am `Text`.
Reine Zeilenänderung, keine neue Property, kein neuer State.

**2. Neuer Optionsfall (Punkt 3).** Fünfter Fall in `ReceiptNameOption`, gleiches Muster wie die
bestehenden vier:

```swift
case receiptText(name: String)   // normalisierter Bontext, Marke "wie auf dem Bon"
```

`id`/`displayName`/`matchableName` je einen neuen Zweig. `optionRow` bekommt einen vierten
`if case`-Zweig für die Marke „wie auf dem Bon" (`Text(...).font(.system(size: 11))
.foregroundStyle(Color.textSecondary)`) — exakt dasselbe visuelle Muster wie die bestehende „auf
deiner Liste"-Marke (Zeilen 208-213), nur anderer Text.

**3. Normalisierungsregel — eigene Funktion, `smartCapitalize` bleibt unangetastet** (Entscheidung
bereits in Phase 1 getroffen, hier nur umgesetzt):

```swift
/// Wortweise Großschreibung des gedruckten Bontexts für die Auswahlzeile „wie auf dem Bon"
/// (Issue #65). Bewusst NICHT `ReceiptParserService.smartCapitalize` — die kapitalisiert nur das
/// erste Wort und wirkt nur bei durchgehender Großschreibung; vier bestehende Aufrufstellen dort
/// haben eine andere Absicht. Feste Regel, kein Sprachmodell.
static func normalizedReceiptText(_ raw: String) -> String {
    raw.split(separator: " ").map { word -> String in
        guard let first = word.first else { return "" }
        return String(first).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
```

**4. Unterdrückungs-Regel (die offene Umsetzungsfrage) — Empfehlung:**

```swift
private static let receiptTextMinLength = 4

static func shouldOfferReceiptTextOption(originalName: String, selectedName: String) -> Bool {
    let trimmed = originalName.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= receiptTextMinLength else { return false }
    return normalizedReceiptText(trimmed).caseInsensitiveCompare(selectedName) != .orderedSame
}
```

Zwei Bedingungen, wie vom PO in Issue #65 vorgeschlagen: Mindestlänge UND Namensgleichheit zum
**aktuell gewählten** Namen (`line.name`) — nicht zu allen drei angezeigten Kandidaten. Ein Fall,
in dem die Bon-Zeile zufällig einem NICHT gewählten Kandidaten entspricht (z. B. dem KI-Vorschlag),
bleibt sichtbar — zwei optisch gleiche Zeilen, aber selten und harmlos; ein Abgleich gegen alle
Kandidaten wäre zusätzlicher Umfang, den weder Issue #65 noch der Entwurf verlangen.

**Schwelle 4 statt 3, mit einer sichtbaren Konsequenz:** Das einzige textliche Beispiel des PO für
„Unsinn durch Normalisierung" ist genau „BTR" → „Btr" (3 Zeichen) — bei Schwelle 3 (Vorbild:
`ReceiptAliasService.learn`s `key.count >= 3`, `ReceiptAliasService.swift:35`) bliebe „Btr" trotzdem
sichtbar, widerspräche also dem genannten Beispiel. Schwelle 4 unterdrückt „BTR" wie vom PO
benannt — weicht damit aber vom Entwurfsbild (Zeile 307-309 der Mockup-HTML zeigt „Btr" sichtbar)
pixelgenau ab. Bewertung: Der Entwurf war zum Zeitpunkt seiner Freigabe (2026-09-27) eine
Strukturentscheidung (Layout/Interaktion), die Unterdrückung war zu dem Zeitpunkt noch nicht
Thema — das Textbeispiel im Issue kam später und ausdrücklich als eigene, vom PO selbst als
„keine PO-Frage" eingestufte Umsetzungsfrage. Empfehlung: Schwelle 4, PO-Beispiel hat Vorrang vor
dem Mockup-Pixel. **Alternative (verworfen): Schwelle 3** — hielte sich exakt ans Mockup-Bild,
ließe aber genau den vom PO selbst genannten Unsinns-Fall ungefiltert durch.

**5. Einordnung in `selectionOptions`:** Bon-Zeile wird nach Regel 6 (Leer-Fallback) und vor Regel
7 (`.custom` anhängen) eingefügt, ungeachtet der Kappung auf 3 aus Regel 4 — sie zählt nicht zu den
„max. 3", sondern kommt add-on obendrauf. Neue Regel 5b (Name folgt der bestehenden Nummerierung
in Implementation Details der Spec).

**6. `applySelection(.receiptText(let name))`:** `line.name = name; matchedItemID = nil;
resolvedByAI = false` — gleiche Form wie `.currentName`, da die Bon-Zeile weder einen Listen- noch
einen KI-Treffer trägt.

### Scope-Schätzung — deutlich unter der PO-Rohschätzung

Issue #65 schätzt „≈250 LoC über vier/fünf Dateien". Am Code geprüft fällt das kleiner aus, weil
**kein neuer Swift-File entsteht** (anders als bei Paket 1/`ReceiptReviewCard.swift` selbst) — also
kein `project.pbxproj`-Eintrag nötig:

| File | Change Type | Geschätzte LoC |
|------|-------------|------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | ≈ +65 (Font/Farbe 2, Kontextmenü 12, neuer Options-Fall 8, `normalizedReceiptText` 10, Unterdrückungs-Regel 12, `optionRow`-Zweig 8, `applySelection`-Fall 3, `selectionOptions`-Einordnung 10) |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | ≈ +80 (Normalisierung 4-5 Fälle, Unterdrückung 3 Fälle, `selectionOptions`-Integration 3-4 Fälle, `applySelection`-Fall) |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | ≈ +50 (vier bestehende Tests mit verschobenen Indizes angepasst, neuer Test für Kopieren über Kontextmenü + `UIPasteboard.general.string`, neuer Test für Tap auf die Bon-Zeilen-Option) |

**Files: 3, LoC: ≈ +195/−15 (≈ 210 gesamt)** — innerhalb von „max. 4-5 Dateien" UND innerhalb von
±250 LoC. Der in Risiko 1 des Kontext-Dokuments vorgesorgte Not-Schnitt (Darstellung vs. wählbare
Zeile trennen) ist nach dieser genaueren Schätzung **nicht nötig** — bleibt als Ausweg vorgemerkt,
falls sich die Schätzung in `/50-implement` als zu knapp erweist.

### Risiko-Bewertung

**Risk Level: MITTEL** — kein Eingriff in `save()`/Services, aber eine echte Invarianten-Änderung
(Invariante 5) mit Auswirkung auf vier bestehende UI-Tests.

1. **UI-Test-Indizes verschieben sich** — bestätigt an vier Stellen (`ReceiptReviewUITests.swift:392,
   413, 437, 458`). `testCardShowsAtMostFourSelectionOptions` (Zeile 392) prüft aktuell explizit,
   dass **kein** `option.4` existiert — dieser Test muss auf „kein `option.5`" bzw. „genau vier bei
   drei Listen-Treffern OHNE Bon-Zeile" umbenannt/umgeschrieben werden, sobald eine Bon-Zeile
   möglich ist. Ob `Seed.suggestionLine`/`Seed.aiLine` (die beiden betroffenen Fixtures) eine
   Bon-Zeile auslösen, hängt von ihrem `originalName` ab — das muss `/30-write-spec` an den
   tatsächlichen Seed-Werten in `SmartCartApp.swift` prüfen, nicht raten.
2. **Font/Farbe sind nicht unabhängig UI-testbar** — XCUITest prüft den Bedienhilfen-Baum, nicht
   Rendering-Attribute wie Schriftgröße/-farbe. Gleiches Muster wie die bereits getroffene
   Entscheidung gegen `.textSelection` (Spec-Nachtrag, „Determinismus/Testbarkeit"): Punkt 1 aus
   Issue #65 wird über Code-Review und die bestehende `originalName`-Accessibility-Identifier
   geprüft, nicht über einen eigenen UI-Test für Pixelwerte — kein neuer Präzedenzfall, folgt
   einem bereits etablierten Muster dieser Codebase.
3. **Kopieren ist UI-testbar** — `UIPasteboard.general` ist auf demselben Simulator prozessübergreifend
   lesbar; ein UI-Test kann nach `.press(forDuration:)` + Tap auf „Kopieren" den Pasteboard-Inhalt
   direkt prüfen. Kein Sonderfall wie bei `.textSelection`.
4. **Normalisierung wortweise vs. `smartCapitalize`** — bewusst zwei getrennte Funktionen (Phase-1-
   Entscheidung, hier bestätigt): unterschiedliche Aufrufkontexte, keine Wiederverwendung sinnvoll.

### Alternativen (mindestens eine echte Alternative je Entscheidung)

- **Unterdrückungs-Schwelle 3 statt 4** — verworfen, siehe oben (ließe das PO-eigene Beispiel
  „BTR" ungefiltert durch).
- **Dedup gegen alle drei Kandidaten statt nur den gewählten Namen** — verworfen: mehr Umfang als
  von Issue #65 verlangt, betrifft einen seltenen Fall (zufällige Namensgleichheit mit einem NICHT
  gewählten Kandidaten), keine PO-Anfrage dafür vorhanden.
- **Bon-Zeile konkurriert um einen der drei Plätze** (ersetzt schwächsten Kandidaten statt
  add-on) — verworfen: widerspricht dem freigegebenen Entwurfsbild (zeigt in beiden Beispielen
  einen Kandidaten PLUS Bon-Zeile, nicht Kandidat ODER Bon-Zeile); würde die PO-Freigabe „Entwurf
  A" faktisch zurücknehmen.
- **Kein Not-Schnitt in zwei Pakete** (Darstellung vs. wählbare Zeile) — beibehalten als Ausweg,
  aber nach der genaueren Schätzung (≈210 statt ≈250 LoC, 3 statt 4-5 Dateien) nicht empfohlen;
  ein Schnitt hier würde nur zusätzlichen Koordinationsaufwand erzeugen, ohne dass das Scoping-Limit
  das verlangt.

### Dependencies

Keine neuen. Wie im Kontext-Dokument: `ReceiptResolutionService` unverändert,
`ReceiptParserService.smartCapitalize` unverändert, `ReceiptScannerView.save()` unverändert (die
neue Option liefert dieselben drei Zuweisungen wie `.currentName`).

### Open Questions

Keine offenen PO-Fragen. Die einzige in Phase 1 benannte offene Umsetzungsfrage (Unterdrückungs-
Schwelle) ist oben mit Empfehlung und Alternative entschieden.
