---
entity_id: receipt-review-card
type: feature
created: 2026-09-22
updated: 2026-09-28
status: draft
workflow: fix-50-import-dialog-design
workflow_history: [feat-23-receipt-review-screen, fix-37-receipt-name-preselect, fix-50-import-dialog-design-paket2]
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
Erweiterung) behebt Punkt 2 und Punkt 4 (Letzteres bis auf den als F001/#66 beschriebenen
Eingang) sowie den PO-Fund; **Paket 2 (Issue #65, NICHT Teil
dieser Erweiterung)** macht den Bontext lesbar (15 pt, `Color.ink`), kopierbar
(`.contextMenu`) und als eigene, antippbare Auswahlzeile „wie auf dem Bon" verfügbar — dafür ändert
sich Invariante 5 (max. 3 inhaltliche Optionen), was Paket 1 ausdrücklich NICHT tut: es fügt
keine neue Options-Zeile hinzu und verschiebt daher keinen `option.<k>`-Index. Details, Regeln
9-11 und der erweiterte Test Plan: Abschnitt „Nachtrag Issue #50, Paket 1" unten.

**Nachtrag Issue #65, Paket 2 (2026-09-28):** Setzt die oben vertagte Scope-Erweiterung um.
Vollständiger Auftrag und die gegen den Live-Code verifizierten Fakten stehen in
`docs/context/fix-50-import-dialog-design-paket2.md`. Drei Zusagen: Bontext von 13pt/
`Color.textSecondary` auf 15pt/`Color.ink` (lesbar), ein `.contextMenu` „Kopieren" am Bontext
(kopierbar), und der Bontext — wortweise großgeschrieben — als eigene, antippbare Auswahlzeile
„wie auf dem Bon", die nur erscheint, wenn sie sich vom aktuell gewählten Namen unterscheidet und
mindestens vier Zeichen lang ist. Dafür ändert sich Invariante 5 wie oben bereits angekündigt: aus
„höchstens 3 inhaltliche Optionen" wird „höchstens 3 andere Kandidaten plus optional die
Bon-Zeile" (max. 5 Optionen insgesamt inkl. „Anderer Name …"). Details, neue Regel 7 (Renumerierung
der bisherigen Regel 7 auf 8), der erweiterte Test Plan und eine Korrektur einer falschen
Testannahme aus Issue #65 selbst: Abschnitt „Nachtrag Issue #65 (Paket 2)" unten.

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
- **Issue #50, Paket 2 (Issue #65) — zum Zeitpunkt der Paket-1-Erweiterung (2026-09-27) noch nicht
  Teil dieser Spec; seit 2026-09-28 umgesetzt.** Bontext-Lesbarkeit (15pt/`Color.ink`), das
  Kontextmenü „Kopieren" und die Bon-Zeile als eigene Auswahl mit wortweiser Großschreibung sind
  jetzt Teil dieser Spec — siehe „Scope-Erweiterung (Issue #65 — 2026-09-28)" und „Nachtrag
  Issue #65 (Paket 2)" unten. Paket 1 selbst fügte bewusst keine neue Options-Zeile hinzu und
  verschob daher keinen `option.<k>`-Index; Paket 2 fügt jetzt genau eine hinzu (die Bon-Zeile,
  immer unmittelbar vor „Anderer Name …") und ändert dafür Invariante 5.
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
  oder Formaterkennung — auch die neue Normalisierungsfunktion für die Bon-Zeile (Issue #65,
  Paket 2) lebt bewusst als eigene, private/statische Funktion in `ReceiptReviewCard.swift`, nicht
  in `ReceiptParserService` (siehe „Nachtrag Issue #65 (Paket 2)", Begründung dort).

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

Behebt Punkt 2 und Punkt 4 aus Issue #50 (Punkt 4 bis auf den als F001/#66 beschriebenen Eingang) sowie den während der Analyse gefundenen dritten Fall
(leerer Name über „Anderer Name …"). Siehe „Nachtrag Issue #50, Paket 1" unten für die volle
Herleitung, Regeln 9-11, Invarianten und den Test Plan.

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | `.onChange(of: line.name)` führt die eingefrorenen `options` nach, wenn keine Option mehr zu `line.name` passt (Regel 9); neuer `@State private var previousSelectionBeforeCustom`, in `select(_:)` beim Betreten von `.custom` gesetzt (Regel 10); neue reine Funktion `applyCustomNameOrFallback(_:name:previousSelection:)` neben dem bestehenden `applyCustomName` (Regel 10); `customNameRow()`s `.onChange(of: customName)` ruft die neue Funktion statt `applyCustomName` direkt. |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | Neue reine Regel `EditableReceiptLine.isSavable(_:)` direkt neben `learningQuantity`/`learningUnit`; `save()`s Eingangsfilter (`parsedLines.filter { $0.isIncluded && $0.price > 0 }`, Z. 601) ruft sie statt der inline-Bedingung (Regel 11). |
| `SmartCart/SmartCartApp.swift` | MODIFY | Neuer, eigenständiger DEBUG-Seed `seedReceiptReviewUnresolvedLineForUITestsIfNeeded(context:)` — Testeinstieg für den reproduzierten Fall. Vollständig beschrieben in `docs/specs/testing/receipt-review-test-entry.md`, „Nachtrag Issue #50, Paket 1"; hier nur referenziert, weil diese Spec keine Testinfrastruktur-Entscheidungen trifft. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Drei neue Tests für `applyCustomNameOrFallback`: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName` (leerer Name fällt zurück), `testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName` (KI-Zustand — `matchedItemID` UND `resolvedByAI` — wird mit zurückgeholt), `testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged` (nicht-leerer Name verhält sich wie bisher). |
| `RestockTests/ReceiptScannerReResolutionTests.swift` | MODIFY | Zwei neue Tests für `isSavable`: `testIsSavableRejectsLineWithEmptyName` (leerer oder nur aus Leerzeichen bestehender Name → `false`) und `testIsSavableKeepsIncludedNamedLineAndRejectsOldCases` (nicht-leerer Name mit Preis → `true`; abgewählt oder Preis 0 → weiterhin `false`). |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Zwei neue Tests, `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution` (derselbe Testname wie „Test 3" in `docs/specs/testing/receipt-review-test-entry.md` — es entsteht nur EIN Test) und `testClearingCustomNameFieldKeepsPreviousItemName`. Erster Test am reproduzierten Fall (BTR-Zeile über den neuen Seed, **Wörterbuch-Zweig** — Apple Intelligence ist im Simulator nicht verfügbar): nach `reResolveAIIfNeeded()` ist genau eine Auswahlzeile markiert, und ihr Label zeigt den aufgelösten Namen. Der strukturgleiche KI-Zweig ist damit NICHT mitbewiesen; für den namensgleichen Fall bleibt er offen (F001, Issue #66). Neuer Test für den PO-Fund: vollständiges Leeren von „Anderer Name …" lässt das Häkchen-Label nie mit einem leeren Namen enden. |

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

### Scope-Erweiterung (Issue #50, Paket 1b — 2026-09-27)

Behebt **ausschließlich** Befund F002 aus dem Adversary-Prüfdialog zu Paket 1
(`docs/artifacts/fix-50-import-dialog-design/adversary-dialog.md`, Urteil AMBIGUOUS): Ein Name aus
reinen Leerzeichen im Feld „Anderer Name …" umgeht den Rückfall aus Regel 10, weil Regel 10 auf
`isEmpty` guardete, Regel 11 aber auf den getrimmten Namen — die Position bleibt sichtbar angehakt,
zählt in Kopfzeile und Summe mit und wird beim Speichern still verworfen.

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | In `applyCustomNameOrFallback` beide Leer-Tests auf `trimmingCharacters(in: .whitespaces).isEmpty` umgestellt (Eingangs-Guard und `previousSelection.name`), plus erklärender Kommentar. Keine andere Funktion, kein anderer View-Zustand. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Zwei neue Unit-Tests: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName` und `testApplyCustomNameOrFallbackFallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly`. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Ein neuer UI-Test für AC-18 (`testWhitespaceOnlyCustomNameKeepsPreviousItemName`), Einstieg über den BESTEHENDEN Seed — kein neuer Seed, keine Änderung an `SmartCartApp.swift`. |

- Files: **3** — innerhalb des Ziels „max. 4-5 Dateien".
- LoC: ≈ **+45 / −4** — weit unter dem Standard-Limit von ±250 LoC
  (`ReceiptReviewCard.swift` ≈ +4/−2 inkl. Kommentar, `ReceiptReviewCardTests.swift` ≈ +28,
  `ReceiptReviewUITests.swift` ≈ +15).
- Risk Level: **NIEDRIG.** Die Änderung liegt in einer reinen, ohne SwiftUI testbaren Funktion
  einer Datei; `save()`, `isSavable`, die Wire-Formate und alle Services bleiben unberührt. Der
  getrimmte Leer-Begriff ist derselbe, den `EditableReceiptLine.isSavable` schon benutzt.
- **Ausdrücklich NICHT geändert:** `ReceiptScannerView.swift` (auch nicht `isSavable`/`save()`),
  `SmartCartApp.swift` (kein neuer Seed), `ReceiptResolutionService.swift`, `project.pbxproj`.
- **F001 ist NICHT Teil von Paket 1b.** Der zweite Befund des Prüfdialogs (HIGH: nach der
  KI-Auflösung kann eine Karte ohne markierte Zeile stehen; Lösung wäre eine neue Regel 12
  `isSelectedIgnoringCustom` mit Dedup-/Einfüge-Regeln auf Markierungsbasis) verändert die
  Zusammensetzung der sichtbaren Auswahlliste und ist deshalb per PO-Entscheidung vom 2026-09-27
  einem eigenen Folge-Issue (**#66**) mit **vorgeschaltetem Design-Entwurf** zugewiesen. Die fertige Vorarbeit
  dafür — Regel 12, Regel 2/5 auf Markierungsbasis, Invarianten 3/5/6 neu gefasst, AC-4/AC-14
  präzisiert, AC-17, vollständiger Test Plan — liegt in
  `docs/specs/views/receipt-review-card-nachtrag-1b.md`; von diesem Nachtrag sind in die Hauptspec
  bewusst NUR die F002-Teile ((H), (I), (J), (P) und AC-18 aus (Q)) übernommen worden.

### Scope-Erweiterung (Issue #65 — 2026-09-28)

Setzt Paket 2 aus Issue #50 um (Bontext lesbar, kopierbar, als eigene Auswahlzeile „wie auf dem
Bon"), vertagt am 2026-09-27 explizit auf ein eigenes Ticket (siehe „Nachtrag Issue #50, Paket 1"
oben). Volle Herleitung, Regeln 7-8, Design-Entscheidungen und Test Plan in „Nachtrag Issue #65
(Paket 2)" unten.

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | Neuer Fall `ReceiptNameOption.receiptText(name:)`; neue reine Funktionen `normalizedReceiptText(_:)` und `shouldOfferReceiptTextOption(originalName:selectedName:)`; neue Regel 7 in `selectionOptions(for:)` (bisherige Regel 7 „`.custom` anhängen" wird Regel 8); neuer Zweig in `isSelected(_:)` und `applySelection(_:option:)`; `nameSection`s Bontext-`Text` auf 15pt/`Color.ink` mit `.contextMenu("Kopieren")`; neuer `if case .receiptText`-Zweig in `optionRow` mit Marke „wie auf dem Bon" (gleiches Muster wie die bestehende „auf deiner Liste"-Marke, `ReceiptReviewCard.swift:208-213`). |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Vier bestehende Tests korrigiert (Index-Verschiebung durch die neue Options-Zeile, siehe Test Plan); neue Tests für `normalizedReceiptText`, `shouldOfferReceiptTextOption` (inkl. Mindestlänge und leerer `selectedName`) und den neuen `.receiptText`-Zweig in `selectionOptions`/`applySelection`. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Vier bestehende Tests korrigiert (`option.1` → `option.2` an `Seed.aiLine`, siehe Test Plan); zwei neue Tests: Kopieren über das Kontextmenü (`UIPasteboard.general.string`), Antippen der Bon-Zeilen-Option — beide am bestehenden `Seed.aiLine`, kein neuer Seed. |

- Files: **3** — innerhalb des Ziels „max. 4-5 Dateien".
- LoC: ≈ **+175 gesamt** (`ReceiptReviewCard.swift` ≈ +56, `ReceiptReviewCardTests.swift` ≈ +85,
  `ReceiptReviewUITests.swift` ≈ +34) — innerhalb des Standard-Limits von ±250 LoC, mit deutlicher
  Reserve. Diese Schätzung ersetzt sowohl die ≈250-LoC-Schätzung aus Issue #65 als auch die
  ≈210-LoC-Schätzung aus `docs/context/fix-50-import-dialog-design-paket2.md` — beide kannten die
  unten dokumentierte Testkorrektur (vier andere Tests betroffen als von Issue #65 behauptet, siehe
  „Nachtrag Issue #65 (Paket 2)") noch nicht.
- Risk Level: **NIEDRIG.** Reine, unit-testbare Funktionen (`normalizedReceiptText`,
  `shouldOfferReceiptTextOption`) neben bereits bestehenden reinen Funktionen derselben Datei; kein
  Eingriff in `save()`, `ReceiptResolutionService` oder `ReceiptParserService`; keine neue
  Wire-Format-Änderung.

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
7. **(Issue #65, Paket 2, 2026-09-28)** Bontext als eigene Auswahlzeile anbieten, sofern
   `shouldOfferReceiptTextOption(originalName: line.originalName, selectedName: line.name)` `true`
   liefert (Mindestlänge 4 UND normalisierter Bontext ≠ `line.name`, case-insensitiv — siehe
   „Nachtrag Issue #65 (Paket 2)" unten): `.receiptText(name: normalizedReceiptText(...))` wird
   angehängt. Zählt NICHT zu den „max. 3 inhaltlichen Kandidaten" aus Regel 4 — sie kommt add-on
   obendrauf, immer unmittelbar vor `.custom` (Invariante 5 geändert, siehe unten).
8. `.custom` wird immer als letztes Element angehängt → **max. 5 Optionen insgesamt** (bisher 4;
   Issue #65, Paket 2, erhöht das Maximum um die optionale Bon-Zeile aus Regel 7).
   *(Vormals Regel 6 der Ursprungsfassung dieser Spec, dann Regel 7 nach Issue #50, Paket 1 —
   inhaltlich unverändert außer der neuen Obergrenze.)*

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
`TextField`-Binding-Closure in `ReceiptLineRow.swift:695-702`). **Seit Issue #65, Paket 2
(2026-09-28)** trägt der Bontext dieser Kopfzeile 15pt/`Color.ink` statt 13pt/`Color.textSecondary`
und ein `.contextMenu` „Kopieren"; unter den Optionszeilen kann zusätzlich eine Bon-Zeile „wie auf
dem Bon" erscheinen — siehe „Nachtrag Issue #65 (Paket 2)" unten für beide Details.

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

1. Der aufgelöste Name steht sichtbar in der Auswahlliste (im Regelfall als markierte Zeile;
   Ausnahme F001, siehe Zusage 2) — nicht erst im Feld „Anderer Name …".
2. Es ist immer genau eine Option markiert (für eine Zeile mit nicht-leerem `line.name`) — mit
   den in Invariante 6 benannten Ausnahmen, insbesondere F001 (offen, Issue #66).
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
nicht-leerem `line.name`, mit **zwei** ausdrücklich benannten Ausnahmen — siehe Invariante 6 unten
und „Known Limitations":
1. bei leerem `line.name` (Regel 6, bewusst unverändert seit Issue #37);
2. wenn der aufgelöste Name wörtlich einem eigenen `suggestions`-Eintrag entspricht und die
   Auflösung dabei `resolvedByAI = true` mit `matchedItemID = nil` setzt — **F001, offen, Issue
   #66**. Regel 9 führt die Liste in diesem Fall zwar nach, aber die Neuberechnung liefert
   dasselbe Ergebnis: Dedup-Regel 2 entfernt die KI-Zeile zugunsten des namensgleichen
   Listen-Treffers, Regel 5 greift mangels Namens-Mismatch nicht, und `isSelected(.listMatch)`
   verweigert die Markierung wegen `!line.resolvedByAI` (`ReceiptReviewCard.swift:369`). Der Fix
   ist eine sichtbare Gestaltungsentscheidung (zwei Zeilen mit demselben Namen) und deshalb #66 mit
   vorgeschaltetem Design-Entwurf zugewiesen; ausformulierte Vorarbeit in
   `docs/specs/views/receipt-review-card-nachtrag-1b.md`.

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
  des Feldes. „Leer" heißt seit Paket 1b **nach `trimmingCharacters(in: .whitespaces)`
  leer**, also auch ein Feld aus reinen Leerzeichen (F002). Regel 10 und Regel 11 benutzen damit
  denselben Leer-Begriff; vorher guardete Regel 10 auf `isEmpty` und Regel 11 getrimmt, sodass
  ein einzelnes Leerzeichen zwischen beiden durchfiel. Konsistent mit dem bestehenden Muster
  dieser Karte, dass jeder Tastendruck sofort wirkt; ein Verlassen-des-Feldes-Hook existiert hier
  nicht.
- **Was NICHT zurückgesetzt wird:** das sichtbare Textfeld (`customName`) bleibt unangetastet —
  leer bzw. mit den eingetippten Leerzeichen. Nur `line.name`/`matchedItemID`/`resolvedByAI`
  fallen zurück. Würde auch `customName` befüllt, könnte der Nutzer ab einem leeren Feld nie
  mehr einen neuen Namen eintippen, ohne dass das Feld sich unter dem Finger sofort wieder mit
  dem alten Namen füllt.
- **Es gibt keine vorher gewählte Option, wenn …:** In der Praxis nicht erreichbar — `.custom`
  wird ausschließlich durch Tippen auf eine bestehende, bereits benannte Auswahlzeile betreten,
  und ein zuvor über diese Regel zurückgefallener Zustand ist selbst wieder nicht-leer. Als reine
  Verteidigungsmaßnahme: Ist der festgehaltene Name **getrimmt** leer, fällt
  `applyCustomNameOrFallback` auf `line.originalName` zurück (`matchedItemID = nil`,
  `resolvedByAI = false`) — der Bontext ist nie leer, sobald eine Karte überhaupt existiert. Der
  getrimmte Test gilt seit Paket 1b auch hier, damit ein festgehaltenes Leerzeichen nicht als
  gültiger Rückfall durchgeht.

**Wirkung von Paket 1b auf die Datenlage:** Über die Karte entsteht ein Name aus reinen
Leerzeichen nirgends mehr — weder in `line.name` noch in Kopfzeile, Summe oder `canSave`. Regel 11
wird dadurch für den Karten-Weg von einer **erreichbaren Bedingung** zur **Verteidigung in der
Tiefe**.

**Eine Quelle bleibt offen (2026-09-27, im zweiten Prüfdialog gemessen):**
`ReceiptNameAIResolver.sanitize` (`ReceiptParserService.swift:1327`) trimmt Leerraum **vor** dem
Entfernen der Anführungszeichen. Antwortet das Sprachmodell mit `" "` (ein Leerzeichen in
Anführungszeichen), passiert dieser Name die Bereinigung und landet über
`ReceiptResolutionService.swift:175` und `mergeAIReresolution` in `line.name`. Regel 11 verwirft die
Position dann beim Speichern — still, wie vor Paket 1b, nur ohne Datenschaden. Auslösung
pathologisch, aber nicht ausgeschlossen; eigenes Folge-Issue (#69). Regel 11 ist für diesen Weg deshalb
weiterhin eine erreichbare Bedingung, nicht bloß Verteidigung.

Neue reine Funktion, NEBEN dem bestehenden `applyCustomName` (das für nicht-leere Namen
unverändert bleibt und von der neuen Funktion aufgerufen wird — kein bestehender Aufrufer/Test
von `applyCustomName` selbst ändert sich):

```swift
static func applyCustomNameOrFallback(
    _ line: inout EditableReceiptLine,
    name: String,
    previousSelection: (name: String, matchedItemID: UUID?, resolvedByAI: Bool)
) {
    // Paket 1b (F002): derselbe getrimmte Leer-Begriff wie in `EditableReceiptLine.isSavable` —
    // ein Feld mit reinen Leerzeichen ist für den Nutzer leer und muss es auch hier sein.
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
        let fallback = previousSelection.name.trimmingCharacters(in: .whitespaces).isEmpty
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

**Stand seit Paket 1b (2026-09-27):** Regel 11 ist für den Karten-Weg Verteidigung in der Tiefe:
der einzige **über die Karte** erreichbare Weg zu einem leeren oder nur aus Leerzeichen bestehenden
`line.name` — das Feld „Anderer Name …" — ist seit dem getrimmten Guard aus Regel 10 geschlossen
(F002). **Für den KI-Weg bleibt sie eine erreichbare Bedingung**: `ReceiptNameAIResolver.sanitize`
kann `" "` durchlassen (siehe Regel 10, „Eine Quelle bleibt offen"; Folge-Issue #69). Der Filter bleibt
trotzdem: `@State customActive` fällt beim Zellen-Recycling zurück, und eine künftige, andere
Quelle für einen leeren Namen (Änderung an `ReceiptResolutionService`/`ReceiptParserService`)
würde den Datenschaden sonst kommentarlos zurückbringen. Der zugehörige Test
(`testIsSavableRejectsLineWithEmptyName`) bleibt unverändert gültig und wird damit zum
Regressionswächter statt zum Nachweis einer erreichbaren Bedingung.

**Alternative, verworfen: Guard weglassen, weil Zusage 3 die Ursache in der Karte schon
schließt.** Verworfen aus zwei Gründen: (1) `@State customActive` fällt beim Zellen-Recycling
der `List` auf `false` zurück (bestehendes, dokumentiertes Risiko dieser Karte, siehe Kontext-
Dokument) — ein Zwischenzustand könnte dadurch theoretisch überleben, ohne dass die Karte selbst
ihn noch zeigt. (2) Sunk-Cost-unabhängig: eine künftige, andere Quelle für einen leeren Namen
(z. B. eine Änderung an `ReceiptResolutionService`/`ReceiptParserService`, außerhalb dieses
Tickets) würde den Datenschaden sonst kommentarlos zurückbringen. Der Guard kostet vier Zeilen
und macht `save()` robust gegen eine Annahme, die die Karte nur GERADE JETZT erfüllt.

### Nachtrag Issue #65 (Paket 2, 2026-09-28): Bontext lesbar, kopierbar, wählbar

Vollständiger Auftrag, gegen den Live-Code verifizierte Fakten und die berechnete Testkorrektur
stehen in `docs/context/fix-50-import-dialog-design-paket2.md`. Drei Zusagen aus Issue #65
(Punkte 1-3, siehe Nachtrag-Absatz oben), in dieser Erweiterung umgesetzt.

#### Ein fünfter Fall: `ReceiptNameOption.receiptText`

```swift
/// Der gedruckte Bontext, wortweise großgeschrieben — Marke „wie auf dem Bon" (Issue #65).
/// Erscheint erst NACH den inhaltlichen Kandidaten (Regeln 1-6) und zählt nicht zu deren
/// Kappung auf max. 3 (Regel 4) — sie ist ein Add-on, immer unmittelbar vor „Anderer Name …".
case receiptText(name: String)
```

- `id`: `"bon-\(name)"`
- `displayName`: `name`
- `matchableName`: `name` — für die Dedup-/Vorauswahl-Regeln 1-6 inert, weil der Fall dort noch
  nicht existiert (er wird erst danach eingefügt, siehe Regel 7 unten); wird ausschließlich für
  `isSelected(_:)` gebraucht.

#### Normalisierung — eigene, wortweise Funktion (kein Sprachmodell, keine Wiederverwendung von `ReceiptParserService.smartCapitalize`)

```swift
/// Wortweise Großschreibung des gedruckten Bontexts für die Auswahlzeile „wie auf dem Bon"
/// (Issue #65). Bewusst NICHT `ReceiptParserService.smartCapitalize` (`ReceiptParserService.swift:
/// 1008`) — die kapitalisiert nur das erste Wort und wirkt nur bei durchgehender Großschreibung;
/// ihre vier bestehenden Aufrufstellen dort verfolgen eine andere Absicht (Normalform für Aliase/
/// Matching, nicht Anzeige). Feste Regel, kein Sprachmodell.
static func normalizedReceiptText(_ raw: String) -> String {
    raw.split(separator: " ").map { word -> String in
        guard let first = word.first else { return "" }
        return String(first).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
```

**Alternative (verworfen): `ReceiptParserService.smartCapitalize` wiederverwenden.** Verworfen,
weil diese bereits bestehende Funktion eine andere Absicht verfolgt: sie kapitalisiert nur das
erste Wort eines mehrteiligen Namens und wirkt nur, wenn der gesamte String durchgehend
großgeschrieben ist — beides passt nicht zur Anzeige-Absicht „jedes Wort einzeln großschreiben,
unabhängig vom Ausgangszustand". Eine Verhaltensänderung an `smartCapitalize` selbst hätte ihre
vier bestehenden, produktiv genutzten Aufrufstellen riskiert (Scope-Verstoß: keine Seiteneffekte
außerhalb des Tickets).

#### Unterdrückungs-Regel

```swift
private static let receiptTextMinLength = 4

static func shouldOfferReceiptTextOption(originalName: String, selectedName: String) -> Bool {
    let trimmed = originalName.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= receiptTextMinLength else { return false }
    return normalizedReceiptText(trimmed).caseInsensitiveCompare(selectedName) != .orderedSame
}
```

Zwei Bedingungen, wie vom PO vorgeschlagen (Issue #65): Mindestlänge **4** UND Namensungleichheit
zum **aktuell gewählten** Namen (`line.name`), nicht zu allen angezeigten Kandidaten-Namen.

**Alternative (verworfen): Schwelle 3 statt 4.** Der PO nannte „BTR" (3 Zeichen) selbst als
Unsinns-Beispiel, das unterdrückt gehört. Bei Schwelle 3 würde „BTR" genau NICHT unterdrückt
(`count >= 3` ist erfüllt) — das widerspräche dem genannten Beispiel unmittelbar. Schwelle 4
unterdrückt „BTR" (Länge 3 < 4) und lässt gleichzeitig die kürzeste im Seed vorkommende sinnvolle
Bon-Zeile („MILCH", 5 Zeichen, normalisiert „Milch") unangetastet durch.

**Design-Entscheidung — Verhalten bei leerem `line.name` (bisher nirgends explizit entschieden):**
Ist `selectedName` (`line.name`) leer, bietet die Funktion die Bon-Zeile trotzdem an — implizit,
weil `trimmed` (der Bontext) durch den `receiptTextMinLength`-Guard nie leer ist und der Vergleich
`normalizedReceiptText(trimmed) != ""` praktisch immer `true` ist. **Entschieden: so belassen,
nicht zusätzlich unterdrücken.** Begründung: Gerade wenn nichts sonst passt (leerer Name trotz
vorhandener Vorschläge, siehe Testfall
`testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` in „Test Plan" unten), ist der
rohe Bontext eine zusätzliche, nützliche Wahlmöglichkeit — und Regel 11/`isSavable` (Issue #50,
Paket 1) verhindert ohnehin jedes Speichern mit leerem Namen; das Risiko aus Issue #50 wird dadurch
nicht wieder geöffnet.

**Alternative (verworfen): Bon-Zeile bei leerem `line.name` zusätzlich unterdrücken** (analog zum
Guard in Regel 5). Verworfen, weil das dem Nutzer ausgerechnet in der Situation, in der ihm am
wenigsten geholfen ist (nichts vorausgewählt), eine zusätzliche Option vorenthielte — ohne dass
Issue #65 das verlangt oder ein Sicherheitsrisiko dagegen spricht (siehe `isSavable`).

#### Einordnung in `selectionOptions(for:)` — neue Regel 7, Renumerierung der bisherigen Regel 7 auf 8

Nach dem bestehenden Schritt 6 (Leer-Fallback) und VOR dem bisherigen Schritt 7 (`.custom`
anhängen, jetzt Regel 8):

```swift
// 7. (Issue #65) Bontext als eigene Auswahlzeile anbieten, sofern nicht unterdrückt.
if shouldOfferReceiptTextOption(originalName: line.originalName, selectedName: line.name) {
    candidates.append(.receiptText(name: normalizedReceiptText(
        line.originalName.trimmingCharacters(in: .whitespaces))))
}

// 8. „Anderer Name …" immer als letzte Zeile.
return candidates + [.custom]
```

Die Bon-Zeile zählt NICHT zu den „max. 3 inhaltlichen Kandidaten" aus Regel 4 — sie kommt add-on
obendrauf, immer unmittelbar vor `.custom`. **Invariante 5 ändert sich** von „höchstens 3
inhaltliche Optionen" zu „höchstens 3 andere Kandidaten plus optional die Bon-Zeile" (= max. 4
inhaltliche + `.custom` = **max. 5 Optionen insgesamt**, bisher 4). Beleg am freigegebenen Entwurf A
(`docs/artifacts/fix-50-import-dialog-design/entwurf-bonkarte.html`, Zeilen 292-329): beide
Beispiele zeigen `[bisherige Kandidaten] [Bon-Zeile] [Anderer Name …]` — die Bon-Zeile konkurriert
nicht um einen der drei Plätze.

#### `isSelected(_:)` — neuer Zweig (`ReceiptReviewCard.swift:366-380`)

```swift
case .receiptText(let name):
    return !customActive && line.name.caseInsensitiveCompare(name) == .orderedSame
```

#### `applySelection(_:option:)` — neuer Zweig (`ReceiptReviewCard.swift:458-475`)

```swift
case .receiptText(let name):
    line.name = name
    line.matchedItemID = nil
    line.resolvedByAI = false
```

Gleiche Form wie `.currentName` — die Bon-Zeile trägt weder einen Listen- noch einen KI-Treffer.

#### Darstellung: lesbar (Punkt 1) und kopierbar (Punkt 2)

In `nameSection` (`ReceiptReviewCard.swift:134-136`, die Bontext-Kopfzeile der Karte): Font
`.system(size: 13)` → `.system(size: 15)`, `Color.textSecondary` → `Color.ink`. Neues
`.contextMenu { Button("Kopieren") { UIPasteboard.general.string = line.originalName } }` am
Bontext-`Text`. In `optionRow` (`ReceiptReviewCard.swift:191-…`): neuer `if case .receiptText`-Zweig
mit Marke „wie auf dem Bon" — exakt dasselbe visuelle Muster wie die bestehende „auf deiner
Liste"-Marke (`ReceiptReviewCard.swift:208-213`, `Text`, 11pt, `Color.textSecondary`,
`.fixedSize()`), nur anderer Text, gleiche Stelle rechts an der Optionszeile.

`originalName` bleibt durch keinen dieser Pfade verändert (Invariante 2 — auch dieser Weg ändert
es nicht).

#### Korrektur einer Falschannahme aus Issue #65 und dem Kontext-Dokument

Beide behaupteten, folgende vier UI-Tests hingen an den verschobenen `option.<k>`-Indizes:
`testCardShowsAtMostFourSelectionOptions`, `testTappingListMatchSelectsThatOption`,
`testCustomNameOptionOpensFocusedTextField`, `testTypingCustomNameIsAppliedWithEveryKeystroke`. Am
tatsächlichen Seed (`RestockUITests/ReceiptReviewUITests.swift:32-76`) berechnet, ist das für die
ersten beiden **falsch**: Beide benutzen `Seed.suggestionLine` (Index 2, `originalName == "MILCH"`,
`name == "Milch"`) — dort ist die Bon-Zeile wegen Namensgleichheit (case-insensitiv) unterdrückt,
die Karte bleibt bei genau 4 Optionen. Betroffen sind stattdessen die zwei genannten UND zwei
weitere, von Issue #65 gar nicht erwähnte Tests — alle vier an `Seed.aiLine` (Index 0,
`originalName == "MILCH 3,5% FRISCH"`, `name == "Frische Vollmilch 3,5 %"`, normalisiert „Milch
3,5% Frisch" ≠ „Frische Vollmilch 3,5 %" → Bon-Zeile erscheint):

| Test | Datei:Zeile (vor Korrektur) | Änderung |
|---|---|---|
| `testCustomNameOptionOpensFocusedTextField` | `ReceiptReviewUITests.swift:440` | `Seed.aiLine.option.1` → `option.2` |
| `testTypingCustomNameIsAppliedWithEveryKeystroke` | `ReceiptReviewUITests.swift:468` | `Seed.aiLine.option.1` → `option.2` |
| `testClearingCustomNameFieldKeepsPreviousItemName` | `ReceiptReviewUITests.swift:870` | `Seed.aiLine.option.1` → `option.2` |
| `testWhitespaceOnlyCustomNameKeepsPreviousItemName` | `ReceiptReviewUITests.swift:919` | `Seed.aiLine.option.1` → `option.2` |

**Nicht betroffen, entgegen Issue #65:** `testCardShowsAtMostFourSelectionOptions`
(`ReceiptReviewUITests.swift:392`) und `testTappingListMatchSelectsThatOption`
(`ReceiptReviewUITests.swift:413`) — beide nutzen `Seed.suggestionLine`, bleiben unverändert
korrekt. `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution`
(`ReceiptReviewUITests.swift:816`) nutzt `Seed.unresolvedLine` (`originalName == "BTR"`, Länge 3 <
4) — die Mindestlängen-Schwelle greift, ebenfalls unverändert korrekt.

Bestehende Unit-Tests in `RestockTests/ReceiptReviewCardTests.swift` — von Issue #65 GAR NICHT
genannt, hier vollständig gegen `originalName`/`name` je Fixture berechnet:

| Test | Zeile (Aufruf `selectionOptions`) | Auswirkung |
|---|---|---|
| `testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst` | 98 | `originalName: "MILCH 3,5% FRISCH"`, `name: "Frische Vollmilch"` → normalisiert „Milch 3,5% Frisch" ≠ „Frische Vollmilch" → Bon-Zeile erscheint. `options.count` 4→5, `options[3]`-Assertion („eigener") → `options[4]`, neue Assertion für `options[3]` (Bon-Zeile). |
| `testPreselectedListMatchIsSortedFirstRegardlessOfCase` | 128 | Gleiche `originalName`, `name: "vollmilch"` → Bon-Zeile erscheint. `options.count` 4→5, `options[3]` („eigener") → `options[4]`. |
| `testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` | 201 | `name: ""`, `originalName: "UNLESBARER BONTEXT"` → Bon-Zeile erscheint (siehe Design-Entscheidung oben). `options.count` 4→5. |
| `testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName` | 241 | `name: "Bio-Hackfleisch"`, `originalName: "BIO-HACKFLEISCH 400G"` → normalisiert „Bio-hackfleisch 400g" ≠ „Bio-Hackfleisch" → Bon-Zeile erscheint. `options.count` 2→3, `options[1]` („eigener") → `options[2]`. |

**Unverändert korrekt** (Bon-Zeile unterdrückt wegen Namensgleichheit mit `line.name`):
`testFiveSuggestionsAreCappedToThreeListMatches` (Zeile 156, `name: "Milch"`, `originalName:
"MILCH"`), `testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches` (Zeile 179, gleiche
Werte).

**Bekommt eine neue, bisher ungeprüfte Zeile, bleibt aber grün** (optional, keine
Pflichtkorrektur): `testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName` (Zeile 227) —
filtert nur auf `.aiSuggestion`/Namenssuffix, deckt die neue Bon-Zeile nicht ab, prüft aber auch
nichts Falsches.

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
auf die dort bereits gemergten Strings angeglichen (keine zwei parallelen Schemata). Die
Bon-Zeile aus Issue #65 (Paket 2) bekommt bewusst KEINEN eigenen Identifier-Eintrag: sie ist eine
gewöhnliche Auswahlzeile und läuft über das bestehende `option.<k>`-Schema, wie die „auf deiner
Liste"-Zeile auch keinen eigenen Marken-Identifier hat (nur die KI-Marke, weil AC-3 explizit ihr
Umbruchverhalten prüft).

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
5. **(Geändert durch Issue #65, Paket 2, 2026-09-28) Die Karte zeigt höchstens 3 andere
   Auswahl-Optionen plus optional die Bon-Zeile „wie auf dem Bon"**, unabhängig davon, wie viele
   `suggestions` `ReceiptResolutionService` liefert (heute bis zu 5) — Regel 4 aus
   `selectionOptions` kappt weiterhin auf max. 3 inhaltliche Kandidaten (Listen-Treffer/
   KI-Vorschlag/geltender Name); Regel 7 (Issue #65) fügt die Bon-Zeile add-on hinzu, sofern
   `shouldOfferReceiptTextOption` greift — sie zählt NICHT zu den drei gekappten Kandidaten.
   Zusammen mit `.custom` ergibt das **max. 5 Optionen insgesamt** (bisher max. 4). Bleibt durch
   die Issue-#37-Erweiterung (Regel 5) unverändert gültig: die neue Regel fügt maximal eine Zeile
   ein und entfernt dafür eine bestehende. Paket 1 (Issue #50) fügte KEINE neue Options-Zeile hinzu
   — `option.<k>`-Indizes blieben unverändert; Paket 2 (Issue #65) fügt jetzt genau eine hinzu
   (siehe „Nachtrag Issue #65 (Paket 2)" für die betroffenen `option.<k>`-Verschiebungen an
   bestehenden Tests).
6. **(Issue #50, Paket 1) Genau eine Option ist markiert, sofern `line.name` nicht leer ist —
   mit den unten benannten Ausnahmen.** Gilt für jede Zeile, deren `matchedItemID`/`resolvedByAI`
   aus einem der bekannten Zuweisungswege stammen (`applySelection`,
   `applyCustomName`/`applyCustomNameOrFallback` oder `mergeAIReresolution`) — sichergestellt
   durch Regel 9 (Nachführen) zusammen mit den unveränderten Regeln 3/5/6. `mergeAIReresolution`
   ist ausdrücklich eingeschlossen: der reproduzierte Fall aus Issue #50 läuft über genau diesen
   Weg (`linesNeedingAIReresolution` wählt die BTR-Zeile, `resolve` löst sie über
   `expandAbbreviations` auf, `resolvedByAI` bleibt dabei false —
   `ReceiptResolutionService.swift:104`, `ReceiptScannerView.swift:126`) und ist durch
   `RestockUITests/ReceiptReviewUITests.swift:842` belegt. Ausgenommen ist allein die Konjunktion
   aus diesem Weg UND Namensgleichheit, siehe unten.

   **Ausdrücklich NICHT abgedeckt (F001, offen, Issue #66):** eine Zeile, deren Zustand direkt aus
   `ReceiptResolutionService.resolve` über `mergeAIReresolution` stammt UND deren aufgelöster Name
   wörtlich einem eigenen `suggestions`-Eintrag entspricht. `mergeAIReresolution` setzt
   `resolvedByAI = true` mit `matchedItemID = nil` (`ReceiptScannerView.swift:130`); Dedup-Regel 2
   entfernt dann die KI-Zeile zugunsten des namensgleichen Listen-Treffers, Regel 5 greift mangels
   Namens-Mismatch nicht, und `isSelected(.listMatch)` verweigert die Markierung wegen
   `!line.resolvedByAI` (`ReceiptReviewCard.swift:369`). Ergebnis: keine markierte Zeile trotz
   nicht-leerem Namen — Punkt 4 aus Issue #50, für diesen einen Eingang unbehoben. Frühere
   Fassungen dieser Invariante zählten `mergeAIReresolution` als abgedeckt auf und widersprachen
   damit „Known Limitations"; dieser Selbstwiderspruch war der Grund, warum der erste Prüfdialog
   kein Urteil fassen konnte (behoben 2026-09-27).

   **Zweite Restlücke (offen, Teil von Issue #66):** Regel 9 hängt allein an `line.name`. Ändert
   eine externe Auflösung `matchedItemID`/`resolvedByAI` und lässt den Namen byte-gleich, führt
   sich nichts nach.

   Ist `line.name` leer,
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

**Issue #37 — Regel 5 (`selectionOptions`); geschrieben und grün:**

- [x] **AC-4 (Issue #37):** GIVEN eine Zeile `name: "Milch"` mit 3 `.listMatch`-Kandidaten
  ("Hafermilch", "Buttermilch", "Vollmilch"), von denen keiner case-insensitiv `"Milch"` entspricht,
  und keinem `aiSuggestedName` WHEN `selectionOptions(for:)` aufgerufen wird THEN ist `options[0]`
  `.currentName("Milch")`, die drei ursprünglichen Treffer sind auf zwei reduziert (der zuletzt
  gereihte, "Vollmilch", entfällt), und die Gesamtzahl bleibt bei 4 Optionen (3 inhaltliche
  Kandidaten + `.custom`).
- [x] **Regression (Issue #37):** GIVEN eine Zeile mit leerem `name` (`""`) und denselben 3
  `.listMatch`-Kandidaten wie oben, von denen keiner (naturgemäß) `line.name` entspricht WHEN
  `selectionOptions(for:)` aufgerufen wird THEN bleibt die Kandidatenliste unverändert bei den 3
  Treffern + `.custom` (4 Optionen) — keine zusätzliche `.currentName`-Zeile, heutiges Verhalten
  (Regel 6, vormals Regel 5) bleibt unberührt.
- [x] **AC-4 (Issue #37, Ergänzung zu bestehendem Test):** Der bestehende Test
  `testFiveSuggestionsAreCappedToThreeListMatches` (`name: "Milch"`, Treffer "Hafermilch/
  Buttermilch/Vollmilch/Kondensmilch/Reismilch" — keiner entspricht `"Milch"`) wurde um die
  Vorauswahl-Assertion ergänzt: THEN ist `options[0]` `.currentName("Milch")`
  (`RestockTests/ReceiptReviewCardTests.swift:165`). Dieser Test konstruierte das Symptom-Szenario
  aus Issue #37 bereits vor dieser Erweiterung, prüfte die Vorauswahl bisher aber nicht.
- [ ] **AC-4 (Rest, verschoben nach Issue #66):** Die zweite, ursprünglich mitgeforderte Assertion
  („für `options[0]` liefert die Auswahl-Logik der Karte `true`") ist in der Unit-Suite **nicht
  schreibbar**: `isSelected(_:)` ist eine `private func` der View und hat keinen von außen
  erreichbaren Einstieg — `grep -n "isSelected" RestockTests/ReceiptReviewCardTests.swift` liefert
  keinen Treffer, die Markierungs-Logik wird heute ausschließlich über UI-Tests belegt
  (`firstOption.isSelected`). Prüfbar wird sie erst, wenn Issue #66 die Markierungs-Regel als reine
  Funktion `isSelectedIgnoringCustom(_:for:)` herauszieht (siehe Regel 12 der Vorarbeit in
  `docs/specs/views/receipt-review-card-nachtrag-1b.md`). Bis dahin bewusst offen — der Punkt wird
  NICHT als erfüllt geführt.

**Issue #50, Paket 1; geschrieben und grün:**

- [x] **AC-15 (`applyCustomNameOrFallback`):** GIVEN eine Zeile mit `matchedItemID` gesetzt und
  `previousSelection = (name: "Vollmilch", matchedItemID: <id>, resolvedByAI: false)` WHEN
  `applyCustomNameOrFallback(&line, name: "", previousSelection:)` aufgerufen wird THEN gilt
  `line.name == "Vollmilch"`, `line.matchedItemID == <id>`, `line.resolvedByAI == false` — der
  leere Zwischenstand wird nie in `line` geschrieben.
  Test: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnEmptyName`.
- [x] **AC-15 (KI-Zustand):** GIVEN `previousSelection = (name: "Frische Vollmilch", matchedItemID:
  <aiID>, resolvedByAI: true)` WHEN mit leerem Namen aufgerufen wird THEN gilt `resolvedByAI ==
  true` UND `matchedItemID == <aiID>` — beweist, dass alle drei Felder zurückgeholt werden, nicht
  nur der Name. Test: `testApplyCustomNameOrFallbackRestoresAIStateOnEmptyName`.
- [x] **AC-15 (Regression, nicht-leerer Name):** GIVEN ein beliebiges `previousSelection` WHEN mit
  einem nicht-leeren Namen aufgerufen wird THEN verhält sich die Funktion exakt wie das bestehende
  `applyCustomName` (`matchedItemID == nil`, `resolvedByAI == false`, `originalName` unverändert)
  — der Rückfall greift ausschließlich beim leeren Zwischenstand.
  Test: `testApplyCustomNameOrFallbackAppliesNonEmptyNameUnchanged`.
- [x] **AC-16 (`isSavable`, in `RestockTests/ReceiptScannerReResolutionTests.swift`):** GIVEN
  eine angehakte Zeile mit `price == 1.99` und `name == ""` (und ebenso eine mit `name == "   "`)
  WHEN `EditableReceiptLine.isSavable(_:)` aufgerufen wird THEN liefert es `false` — `save()`
  überspringt diese Position und legt weder einen namenlosen Kaufdatensatz noch einen Lern-Eintrag
  unter dem leeren Schlüssel an. Test: `testIsSavableRejectsLineWithEmptyName`.
- [x] **AC-16 (Regression, bisherige Bedingungen):** GIVEN eine angehakte Zeile mit
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

- [x] **AC-13/AC-14 (der reproduzierte Fall):** GIVEN die fünfte Bon-Zeile des neuen Seeds
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
- [x] **AC-15 (PO-Fund, UI-Nachweis):** GIVEN die KI-Zeile des BESTEHENDEN Seeds
  (`receiptReview.line.0`, Name „Frische Vollmilch 3,5 %") WHEN „Anderer Name …" angetippt, das
  vorbelegte Feld vollständig geleert (nicht neu befüllt) wird THEN zeigt
  `receiptReview.line.0.checkbox` weiterhin „Position übernehmen: Frische Vollmilch 3,5 %" — nie
  einen leeren Namen. Vor Regel 10 hätte jeder gelöschte Buchstabe den Namen live überschrieben,
  bis er bei vollständigem Leeren leer gewesen wäre.
  Test: `testClearingCustomNameFieldKeepsPreviousItemName`.

#### Issue #50, Paket 1b (F002) — geschrieben und grün

- [x] **AC-18 (`applyCustomNameOrFallback`, Name aus reinen Leerzeichen):** GIVEN eine Zeile mitten
  in der Eingabe eines eigenen Namens (`name: "Vollm"`, `matchedItemID == nil`,
  `resolvedByAI == false`) und `previousSelection = (name: "Frische Vollmilch",
  matchedItemID: <aiID>, resolvedByAI: true)` WHEN
  `applyCustomNameOrFallback(&line, name: "   ", previousSelection:)` aufgerufen wird THEN löst der
  Name aus reinen Leerzeichen denselben Rückfall aus wie ein leerer: `line.name == "Frische
  Vollmilch"`, `line.matchedItemID == <aiID>`, `line.resolvedByAI == true` — alle drei Felder
  kommen zurück, nicht nur der Name.
  Test: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName`
  (`RestockTests/ReceiptReviewCardTests.swift`). Grün belegt in
  `docs/artifacts/fix-50-import-dialog-design/green-run1-unit.txt` und `green-run3b-suite.txt`
  (`Test Case '-[RestockTests.ReceiptReviewCardTests
  testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName]' passed`).
- [x] **AC-18 (Verteidigungs-Rückfall auf den Bontext):** GIVEN ein festgehaltenes
  `previousSelection`, dessen `name` selbst reine Leerzeichen ist (`"  "`, mit gesetzter
  `matchedItemID` und `resolvedByAI: true`) WHEN mit `name: " "` aufgerufen wird THEN gilt dieser
  Rückfall nicht als gültig: `line.name == line.originalName` (`"BTR"`),
  `line.matchedItemID == nil`, `line.resolvedByAI == false` — die Zeile bleibt nie ohne Namen
  stehen.
  Test: `testApplyCustomNameOrFallbackFallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly`
  (`RestockTests/ReceiptReviewCardTests.swift`). Grün belegt in `green-run1-unit.txt` und
  `green-run3b-suite.txt`.
- [x] **AC-18 (Bildschirm-Nachweis):** GIVEN die KI-Zeile des BESTEHENDEN Seeds
  (`receiptReview.line.0`, Name „Frische Vollmilch 3,5 %") WHEN „Anderer Name …" angetippt, das
  vorbelegte Feld vollständig geleert und anschließend durch ein einzelnes Leerzeichen ersetzt wird
  THEN endet das Label von `receiptReview.line.0.checkbox` nie mit einem Namen aus reinen
  Leerzeichen, sondern nennt weiterhin „Frische Vollmilch 3,5 %".
  Test: `testWhitespaceOnlyCustomNameKeepsPreviousItemName`
  (`RestockUITests/ReceiptReviewUITests.swift`). RED-Nachweis: im RED-Lauf trug das Label
  tatsächlich `"Position übernehmen:  "` (`test-red-ui-1b.txt`,
  `RestockUITests/ReceiptReviewUITests.swift:947`). Grün belegt in `green-run2-ui.txt` und
  `green-run3b-suite.txt`.

#### Issue #65, Paket 2 — neue und korrigierte Tests

**Unit — `RestockTests/ReceiptReviewCardTests.swift`, neu:**

- [ ] **AC-21 (`normalizedReceiptText`):** GIVEN `"MILCH 3,5% FRISCH"` WHEN
  `normalizedReceiptText(_:)` aufgerufen wird THEN liefert es `"Milch 3,5% Frisch"` (wortweise
  Großschreibung, Ziffern/Sonderzeichen bleiben unverändert).
  Test: `testNormalizedReceiptTextCapitalizesEachWord`.
- [ ] **AC-21 (`normalizedReceiptText`, Bindestrich-Wort):** GIVEN `"BIO-HACKFLEISCH 400G"` WHEN
  `normalizedReceiptText(_:)` aufgerufen wird THEN liefert es `"Bio-hackfleisch 400g"` — nur der
  erste Buchstabe des gesamten (bindestrich-verbundenen) Worts wird groß, nicht jeder Wortteil.
  Test: `testNormalizedReceiptTextKeepsHyphenatedWordAsOneUnit`.
- [ ] **AC-22 (`shouldOfferReceiptTextOption`, Mindestlänge):** GIVEN `originalName: "BTR"`
  (3 Zeichen) und ein beliebiger abweichender `selectedName` WHEN
  `shouldOfferReceiptTextOption(originalName:selectedName:)` aufgerufen wird THEN liefert es
  `false` — genau das vom PO genannte Unsinns-Beispiel wird unterdrückt.
  Test: `testShouldOfferReceiptTextOptionRejectsNamesBelowMinLength`.
- [ ] **AC-22 (Namensgleichheit):** GIVEN `originalName: "MILCH"`, `selectedName: "Milch"` WHEN
  `shouldOfferReceiptTextOption(originalName:selectedName:)` aufgerufen wird THEN liefert es
  `false` (case-insensitiv gleich nach Normalisierung).
  Test: `testShouldOfferReceiptTextOptionRejectsNameEqualToSelection`.
- [ ] **AC-22 (Regelfall):** GIVEN `originalName: "MILCH 3,5% FRISCH"`, `selectedName: "Frische
  Vollmilch"` WHEN `shouldOfferReceiptTextOption(originalName:selectedName:)` aufgerufen wird THEN
  liefert es `true`.
  Test: `testShouldOfferReceiptTextOptionAcceptsDifferingName`.
- [ ] **AC-22 (leerer `selectedName`, Design-Entscheidung):** GIVEN `originalName: "UNLESBARER
  BONTEXT"`, `selectedName: ""` WHEN `shouldOfferReceiptTextOption(originalName:selectedName:)`
  aufgerufen wird THEN liefert es `true` — die Bon-Zeile bleibt bei leerem Namen ein Angebot (siehe
  „Nachtrag Issue #65 (Paket 2)", Design-Entscheidung).
  Test: `testShouldOfferReceiptTextOptionAcceptsEmptySelection`.
- [ ] **AC-21 (`selectionOptions`-Integration, Regel 7/8):** GIVEN eine Zeile mit `originalName:
  "MILCH 3,5% FRISCH"`, `name: "Frische Vollmilch"`, zwei `suggestions`, `aiSuggestedName:
  "Frische Vollmilch"` WHEN `selectionOptions(for:)` aufgerufen wird THEN liefert es 5 Optionen:
  KI-Zeile + 2 Treffer + Bon-Zeile (`options[3]`, `.receiptText("Milch 3,5% Frisch")`) +
  `.custom` (`options[4]`) — Korrektur/Erweiterung von
  `testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst`.
- [ ] **AC-21 (`selectionOptions`-Integration, Unterdrückung):** GIVEN eine Zeile mit
  `originalName: "MILCH"`, `name: "Milch"` und drei `suggestions` (keiner davon `"Milch"`) WHEN
  `selectionOptions(for:)` aufgerufen wird THEN bleibt die Optionsliste bei 4 Einträgen — keine
  Bon-Zeile, weil `originalName` normalisiert `line.name` entspricht (Regressionsschutz für
  `testFiveSuggestionsAreCappedToThreeListMatches`/
  `testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches`, bleiben unverändert grün).
- [ ] **AC-21 (`applySelection`, `.receiptText`):** GIVEN eine Zeile mit gesetztem `matchedItemID`
  und `resolvedByAI == true` WHEN der `.receiptText`-Callback mit einem Namen aufgerufen wird THEN
  gilt `name == <der Name>`, `matchedItemID == nil`, `resolvedByAI == false`, `originalName`
  unverändert — dieselbe Form wie `.currentName`.
  Test: `testChoosingReceiptTextSetsNameAndClearsMatchAndAiFlag`.

**Vier bestehende Unit-Tests korrigiert** (Index-Verschiebung durch die neue Bon-Zeile — siehe
Tabelle „Korrektur einer Falschannahme" oben für die vollständige Herleitung):
`testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst` (Zeile 98),
`testPreselectedListMatchIsSortedFirstRegardlessOfCase` (Zeile 128),
`testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` (Zeile 201),
`testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName` (Zeile 241) — jeweils `options.count`
und die Index-Assertion für `.custom`/`.currentName` angepasst, siehe Tabelle oben.

**UI — `RestockUITests/ReceiptReviewUITests.swift`, neu** (Einstieg über den bestehenden
`Seed.aiLine`, kein neuer Seed nötig — die Bon-Zeile erscheint dort bereits deterministisch):

- [ ] **AC-20 (Kopieren via Kontextmenü, Verdrahtung):** GIVEN die Bontext-Zeile von
  `receiptReview.line.0` (`Seed.aiLine`, Text „MILCH 3,5% FRISCH") WHEN lange auf sie gedrückt wird
  THEN öffnet sich ein Kontextmenü mit einem antippbaren Eintrag „Kopieren"
  (`app.buttons["Kopieren"]` — SwiftUIs `.contextMenu` rendert seine Einträge auf iOS als `Button`
  in einer `CollectionView`-Zelle, NICHT als `.menuItem`). Der tatsächliche Pasteboard-Inhalt nach
  dem Antippen wird NICHT über diesen Test geprüft — siehe „Nicht UI-testbar (AC-20)" unten.
  Test: `testCopyingReceiptTextViaContextMenuPutsOriginalNameOnPasteboard`.
- [ ] **AC-21 (Bon-Zeile als Auswahl, UI):** GIVEN `receiptReview.line.0.option.1` (die neue
  Bon-Zeile an `Seed.aiLine` — sie steht zwischen der KI-Zeile an `option.0` und „Anderer Name …",
  das dadurch von `option.1` auf `option.2` rutscht, siehe Tabelle oben) WHEN sie angetippt wird
  THEN zeigt `receiptReview.line.0.checkbox` das Label „Position übernehmen: Milch 3,5% Frisch" und
  `receiptReview.line.0.option.1` trägt danach `isSelected == true`.
  Test: `testTappingReceiptTextOptionSelectsNormalizedBonText`.

**Vier bestehende UI-Tests korrigiert** (`Seed.aiLine.option.1` → `option.2`, siehe Tabelle
„Korrektur einer Falschannahme" oben): `testCustomNameOptionOpensFocusedTextField` (Zeile 440),
`testTypingCustomNameIsAppliedWithEveryKeystroke` (Zeile 468),
`testClearingCustomNameFieldKeepsPreviousItemName` (Zeile 870),
`testWhitespaceOnlyCustomNameKeepsPreviousItemName` (Zeile 919).

**Nicht UI-testbar (AC-19, Font/Farbe):** Die Erhöhung von 13pt auf 15pt und der Farbwechsel
`Color.textSecondary` → `Color.ink` am Bontext sind reine Rendering-Attribute — `XCUITest` prüft
den Bedienhilfen-Baum (Label, Existenz, Traits), nicht Schriftgröße oder Farbwerte. Geprüft über
Code-Review am `.font`/`.foregroundStyle`-Modifier in `ReceiptReviewCard.swift:134-136`, kein
eigener UI-Test für Pixelwerte — dieselbe Prüftiefe, mit der diese Spec an anderer Stelle bereits
reine Farb-/Token-Entscheidungen behandelt (siehe „Risiken", Dark Mode).

**Nicht UI-testbar (AC-20, tatsächlicher Pasteboard-Inhalt):** Ein UI-Test kann `UIPasteboard.general`
nach dem Antippen von „Kopieren" nicht zuverlässig automatisiert lesen. Grund: `<App>UITests-Runner`
und `Restock` sind auf iOS unterschiedliche Prozesse (unterschiedliche Bundle-IDs); ein Lesezugriff
des Runner-Prozesses auf einen vom App-Prozess geschriebenen Pasteboard-Inhalt ist seit iOS 16 ein
dokumentierter Cross-App-Zugriff, den das System per Bestätigungsdialog „<Runner> möchte von <App>
einsetzen" abfängt (Apple, WWDC 2022 Session 10096 „What's new in privacy", ab ca. 9:24). Der Dialog
erscheint in einem automatisierten `xcodebuild test`-Lauf deterministisch bei jedem Durchlauf und
wird nie bestätigt — der Testlauf hängt dadurch unbegrenzt (real reproduziert: >40 min ohne
Fortschritt, kein bekannter ~10-min-Diagnose-Hänger). `addUIInterruptionMonitor(withDescription:
handler:)`, der naheliegende Standardweg für Systemdialoge, ist für genau diesen SpringBoard-
generierten Alert auf iOS 17+ nachweislich unzuverlässig — mehrere offene, ungelöste Apple-Forum-
Threads (737880, 806849, 717322) bestätigen dasselbe Hängen ohne funktionierenden Workaround; kein
Entitlement/Launch-Argument unterdrückt die Abfrage für Testläufe. **Entschieden:** Der UI-Test prüft
nur die Verdrahtung (Menüeintrag existiert, ist antippbar); der eine, unverzweigte Zuweisungs-Ausdruck
`UIPasteboard.general.string = line.originalName` selbst wird per Code-Review verifiziert — dieselbe
Prüftiefe wie AC-19, aus demselben Grund (eine Plattform-Grenze macht die Automatisierung
unzuverlässig, nicht ein fehlender Testwille). **Alternativen (verworfen):** (b)
`addUIInterruptionMonitor` + SpringBoard-Fallback — verworfen, siehe oben, nachweislich
unzuverlässig für diesen Dialogtyp, Risiko exakt desselben Hängens. (a) In-App-Bestätigungsbrücke
(DEBUG-only Spiegel-Label, das den kopierten Text im Accessibility-Baum der App selbst zeigt) —
verworfen als Scope-Erweiterung für eine einzeilige, durch Inspektion offensichtlich korrekte
Zuweisung; keine neue Produktoberfläche nur für einen Testnachweis.

**Bestehende Tests, unverändert (bestätigt für Paket 1):**
`testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches`
(`RestockTests/ReceiptReviewCardTests.swift`) bleibt unverändert — er prüft die reine Funktion
`selectionOptions` bei bereits leerem `line.name`, eine Eingangsbedingung, die Paket 1 nicht
ändert. Regel 10 (Rückfall) verhindert nur, dass die VIEW `line.name` überhaupt erst leer setzt —
sobald ein Aufrufer (wie dieser Test) direkt eine Zeile mit `name: ""` konstruiert, bleibt das
Verhalten von `selectionOptions` exakt das aus Issue #37 (Regel 6). **Hinweis: Der Test selbst
gewinnt seit Issue #65, Paket 2 eine neue Bon-Zeile (`options.count` 4→5, siehe Tabelle oben) —
„unverändert" bezieht sich hier ausschließlich auf sein Leer-Namen-Verhalten, nicht auf die
Anzahl der Optionen.** Alle vier Options-Index-Tests aus der Analyse-Risikoliste
(`testCardShowsAtMostFourSelectionOptions`, `testTappingListMatchSelectsThatOption`,
`testCustomNameOptionOpensFocusedTextField`, `testTypingCustomNameIsAppliedWithEveryKeystroke`)
blieben für Paket 1 unverändert: Paket 1 fügte keine neue Options-Zeile hinzu, also verschob sich
kein `option.<k>`-Index. **Seit Issue #65, Paket 2 (2026-09-28) gilt das nur noch für die ersten
zwei** (`testCardShowsAtMostFourSelectionOptions`, `testTappingListMatchSelectsThatOption`, beide
an `Seed.suggestionLine`, wo die neue Bon-Zeile wegen Namensgleichheit unterdrückt bleibt) — die
anderen zwei sowie zwei zusätzliche, hier nicht genannte Tests sind jetzt betroffen, siehe
„Nachtrag Issue #65 (Paket 2)" und den Unterabschnitt „Issue #65, Paket 2 — neue und korrigierte
Tests" oben.

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
- **AC-2:** Jede Karte zeigt max. 5 Auswahlzeilen (max. 3 inhaltliche + optional die Bon-Zeile
  „wie auf dem Bon" + „Anderer Name …") — Obergrenze seit Issue #65, Paket 2 (2026-09-28) von 4
  auf 5 erhöht, siehe AC-21/Invariante 5.
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
  Name …". **Ausgenommen der Fall F001 (Issue #66):** Trägt ein verbliebener Kandidat denselben
  Namen, verhindert Regel 5 die Einfügung (`ReceiptReviewCard.swift:443-447`), Regel 3 sortiert
  den Listen-Treffer nur nach vorn, und `isSelected` verweigert die Markierung wegen
  `!line.resolvedByAI` (`:369`) — die Karte bleibt dann ohne markierte Zeile. Passt eine bestehende Zeile weiterhin (z. B. nach einem Nutzer-Tap), bleibt die Liste
  unverändert stehen — das bewusste Einfrieren aus Abschnitt 5 bleibt für diesen Fall erhalten.
- **AC-14 (Issue #50, Zusage 2):** Für jede Zeile mit nicht-leerem `line.name`, deren
  `matchedItemID`/`resolvedByAI` aus einem der bekannten Zuweisungswege stammen (`applySelection`,
  `applyCustomName`/`applyCustomNameOrFallback` oder `mergeAIReresolution`), ist immer genau eine
  Auswahlzeile markiert — beweisbar am reproduzierten Fall: „Karte zeigt genau einen gefüllten Auswahlkreis,
  nie null und nie zwei." **Nicht abgedeckt:** eine Zeile aus `mergeAIReresolution`, deren
  aufgelöster Name wörtlich einem eigenen `suggestions`-Eintrag entspricht (F001, offen, Issue
  #66), und eine externe Änderung von `matchedItemID`/`resolvedByAI` bei byte-gleichem Namen.
  Beide Ausnahmen sind in Invariante 6 und „Known Limitations" begründet.
- **AC-15 (Issue #50, Zusage 3):** Leert der Nutzer das vorbelegte Feld „Anderer Name …"
  vollständig **oder reduziert es auf reine Leerzeichen** (Paket 1b, F002), fällt die Karte auf
  die Auswahl zurück, die unmittelbar zuvor galt (Name, `matchedItemID` UND `resolvedByAI`
  gemeinsam) — `line.name` trägt danach nie einen leeren oder nur aus Leerzeichen bestehenden
  Namen. Das sichtbare Textfeld selbst bleibt unangetastet, der Nutzer kann sofort weitertippen.
- **AC-16 (Issue #50, Verteidigung in der Tiefe):** Eine Position mit leerem Namen wird beim
  Speichern vollständig übersprungen — es entsteht kein Kaufdatensatz ohne Namen in der
  Ausgabenhistorie und kein gelernter Preis unter dem leeren Schlüssel; unabhängig davon, ob ein
  leerer Name die Karte je erreicht (AC-15 schließt das für den bekannten Weg aus).
- **AC-18 (Issue #50, Paket 1b, F002):** Ein Name aus reinen Leerzeichen löst denselben Rückfall
  aus wie ein vollständig geleertes Feld. Es entsteht keine angehakte Position, die in Kopfzeile
  und Summe mitzählt, beim Speichern aber still verworfen wird; Regel 11 bleibt als Verteidigung
  in der Tiefe unverändert bestehen.
- **AC-19 (Issue #65, Paket 2 — Bontext lesbar):** Der Bontext in der Kopfzeile jeder Karte wird
  in 15pt und `Color.ink` dargestellt (bisher 13pt/`Color.textSecondary`) — nicht eigenständig per
  UI-Test geprüft (Rendering-Attribut, siehe Test Plan), verifiziert per Code-Review.
- **AC-20 (Issue #65, Paket 2 — kopierbar):** Ein langer Druck auf den Bontext öffnet ein
  Kontextmenü mit „Kopieren" — per UI-Test geprüft (Verdrahtung: Menüeintrag existiert, ist
  antippbar). Dass danach `UIPasteboard.general.string = line.originalName` (unverändert,
  ungetrimmt) gilt, ist NICHT automatisiert testbar (siehe „Nicht UI-testbar" im Test Plan) und
  wird per Code-Review verifiziert — dieselbe Prüftiefe wie AC-19.
- **AC-21 (Issue #65, Paket 2 — Bon-Zeile als Auswahl):** Ist der wortweise großgeschriebene
  Bontext nicht case-insensitiv identisch mit dem aktuell geltenden Namen (`line.name`), erscheint
  er als eigene, antippbare Auswahlzeile „wie auf dem Bon" unmittelbar vor „Anderer Name …";
  Antippen setzt `name` auf den normalisierten Bontext, `matchedItemID = nil`,
  `resolvedByAI = false`.
- **AC-22 (Issue #65, Paket 2 — Unterdrückung):** Die Bon-Zeile erscheint NICHT, wenn der
  getrimmte Bontext kürzer als 4 Zeichen ist ODER der normalisierte Bontext case-insensitiv dem
  aktuell geltenden Namen entspricht.

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
- **Issue #65, Paket 2 — Alternative: `ReceiptParserService.smartCapitalize` für die
  Bon-Zeilen-Normalisierung wiederverwenden** statt einer eigenen Funktion: Verworfen — passt nicht
  zur Absicht (kapitalisiert nur das erste Wort, wirkt nur bei durchgehender Großschreibung) und
  hätte vier bestehende, produktiv genutzte Aufrufstellen mit einer anderen Absicht riskiert.
- **Issue #65, Paket 2 — Alternative: Mindestlänge 3 statt 4** für
  `shouldOfferReceiptTextOption`: Verworfen — das vom PO selbst genannte Unsinns-Beispiel „BTR" (3
  Zeichen) würde bei Schwelle 3 gerade NICHT unterdrückt.
- **Issue #65, Paket 2 — Alternative: Bon-Zeile bei leerem `line.name` zusätzlich unterdrücken**
  (analog zum Guard in Regel 5): Verworfen — verwehrt dem Nutzer ausgerechnet in der Situation, in
  der ihm am wenigsten geholfen ist, eine zusätzliche, nützliche Option, ohne dass Issue #65 das
  verlangt oder ein Sicherheitsrisiko dagegen spricht (`isSavable`/Regel 11 verhindert ohnehin
  jedes Speichern mit leerem Namen).

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
- **Issue #65, Paket 2 — Rendering-Attribute nicht UI-testbar.** Die Erhöhung von 13pt auf 15pt
  und der Farbwechsel am Bontext (AC-19) sind über `XCUITest` nicht prüfbar (Bedienhilfen-Baum,
  keine Rendering-Werte) — abgesichert über Code-Review, nicht über einen automatisierten Test.
  Bricht keine bestehende Testing-Strategie, weil auch die bestehenden Design-Token-Entscheidungen
  dieser Spec (z. B. Dark/Light-Farbwerte) nicht pixelgenau, sondern nur strukturell (Existenz,
  Umbruchverhalten) geprüft werden.

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
  abgewogen (siehe „Alternativen"). Die Issue-#65-Erweiterung, Paket 2 (2026-09-28), ist ebenfalls
  kein eigenes ADR wert: sie fügt einen fünften, strukturgleichen Fall zu einem bereits
  bestehenden Enum hinzu und zwei reine Funktionen neben bereits bestehende reine Funktionen
  derselben Datei — kein neues Architekturmuster. Die einzige Invarianten-Änderung dieser
  Erweiterung (Nr. 5) ist im Text selbst begründet und gegen zwei Alternativen abgewogen (siehe
  „Alternativen").

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
  versteckt im Feld „Anderer Name …". **Eine Ausnahme bleibt offen (F001, Issue #66):** Trifft der
  neue Name wörtlich einen Artikel, der bereits als Vorschlag dieser Position angeboten wird, steht
  die Karte weiterhin ohne markierten Kreis. Alltagsfall: der Artikel steht unabgehakt auf der
  Liste. Der Fix ist eine sichtbare Gestaltungsentscheidung und braucht zuerst einen Entwurf.
- **(Issue #50, Paket 1 + 1b)** Leert man das Feld „Anderer Name …" versehentlich vollständig oder
  reduziert es auf reine Leerzeichen, bleibt die Position unter ihrem vorherigen Namen gespeichert,
  statt kommentarlos ohne Namen dazustehen.
- **(Issue #65, Paket 2)** Der gedruckte Bontext jeder Karte ist besser lesbar (größere, dunklere
  Schrift), lässt sich per langem Druck kopieren, und steht — wenn er vom gewählten Namen abweicht
  — als eigene, antippbare Zeile „wie auf dem Bon" zur Auswahl.
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
- Ein langer Druck auf den Bontext einer Karte öffnet ein Kontextmenü mit „Kopieren" (Issue #65,
  Paket 2); tippt der Nutzer stattdessen auf die Bon-Zeile „wie auf dem Bon" (sofern sie
  erscheint), wechselt der Name der Karte sofort auf den wortweise großgeschriebenen Bontext.
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
- **F104 (LOW, Issue #69): `.whitespaces` deckt Zeilenumbrüche nicht ab.** Regel 10
  (`applyCustomNameOrFallback`) und Regel 11 (`isSavable`) trimmen beide mit
  `trimmingCharacters(in: .whitespaces)` — gemessen erfasst das Tabulator, U+00A0, alle
  Zs-Leerzeichen und U+200B, **nicht** aber U+000A/U+000B. Ein Name, der nur aus einem
  Zeilenumbruch besteht, passiert deshalb beide Regeln **symmetrisch**: AC-18 ist unverletzt (die
  beiden Regeln fallen nicht auseinander, es entsteht keine still verschwindende Position), aber
  AC-16 ist nur dem Buchstaben nach erfüllt — eine optisch leere Position würde gespeichert.
  Erreichbarkeit über das einzeilige Textfeld der Karte ist unbewiesen; über den KI-Weg aus #69
  nicht ausgeschlossen. Beim Umstellen auf `.whitespacesAndNewlines` muss die Symmetrie zwischen
  `ReceiptScannerView.swift:106` und `ReceiptReviewCard.swift:499-500` erhalten bleiben.
- **F001 (Issue #50, Paket 1b bewusst NICHT behoben — Folge-Issue #66 mit vorgeschaltetem
  Design-Entwurf):** Löst die Namensauflösung eine Position nachträglich auf einen Namen auf, der
  wörtlich einem ihrer eigenen Vorschläge entspricht (`resolvedByAI == true`,
  `matchedItemID == nil`), entfernt Dedup-Regel 2 die KI-Zeile, und der namensgleiche
  Listen-Treffer kann die Markierung nicht tragen — die Karte steht dann ganz OHNE markierte Zeile,
  obwohl `line.name` nicht leer ist (Punkt 4 aus Issue #50). Paket 1b behebt nur F002; der PO hat
  am 2026-09-27 entschieden, F001 einem eigenen Ticket mit vorgeschaltetem Design-Entwurf
  zuzuweisen, weil die Lösung die Zusammensetzung der Auswahlliste sichtbar verändert (erhaltene
  KI-Zeile, Doppelnennung eines Namens). Die vollständige Vorarbeit — Regel 12
  (`isSelectedIgnoringCustom`), Regel 2/5 auf Markierungsbasis, AC-17, Test Plan — liegt fertig
  formuliert in `docs/specs/views/receipt-review-card-nachtrag-1b.md` und ist bis zur Freigabe
  dieses Folge-Issues (#66) NICHT Bestandteil dieser Spec. Solange gilt die Einschränkung von
  Invariante 6 und AC-14 auf die bekannten Zuweisungswege unverändert weiter.
- **F003 (LOW, vorbestehend seit Issue #37, Folge-Issue #67):** `applySelection` setzt im
  `.currentName`-Zweig NUR `line.name` (`ReceiptReviewCard.swift:470-471`) und lässt eine zuvor
  gesetzte, fremde `matchedItemID` stehen. Wer zuerst einen Listen-Treffer und danach die
  `.currentName`-Zeile antippt, behält dessen Artikel-Identität; `save()` schreibt den Preis dann
  über `matchedItem` auf den falschen Artikel (`ReceiptScannerView.swift:642-645`, `:709`). Von
  Paket 1b nicht berührt.
- **F004 (LOW, vorbestehend, Folge-Issue #68):** Solange `customActive` gilt, ersetzt `optionRow` die
  `.custom`-Zeile durch das Textfeld; der `.isSelected`-Trait und der gefüllte Radiopunkt hängen
  nur an den Nicht-Custom-Zeilen. Während der Eingabe eines eigenen Namens trägt deshalb KEINE
  Zeile den `.isSelected`-Trait, obwohl die Eingabe inhaltlich die geltende Auswahl ist
  (`isSelected(.custom) == true`). Von Paket 1b nicht berührt.

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
- 2026-09-27: Issue #50, Paket 1b — nur Befund F002 aus dem Adversary-Prüfdialog behoben: Regel 10
  benutzt denselben getrimmten Leer-Begriff wie `isSavable`, ein Feld aus reinen Leerzeichen löst
  damit denselben Rückfall aus wie ein vollständig geleertes Feld (Eingangs-Guard UND
  Verteidigungs-Rückfall auf `line.originalName`). AC-15 entsprechend präzisiert, AC-18 neu, Regel
  11 ausdrücklich zur Verteidigung in der Tiefe erklärt, Scope-Erweiterung Paket 1b ergänzt. Befund
  F001 (Regel 12, Dedup/Markierung) ist per PO-Entscheidung NICHT Teil von Paket 1b, sondern einem
  Folge-Issue #66 mit vorgeschaltetem Design-Entwurf zugewiesen; die Vorarbeit liegt in
  `docs/specs/views/receipt-review-card-nachtrag-1b.md`. F003/F004 als bekannte, offene Lücken in
  „Known Limitations" aufgenommen.

### 2026-09-27 — Nachtrag Paket 1b, Nachzug (Issue #50)

Folge-Issue-Nummern eingetragen (#66 für F001, #67 für F003, #68 für F004), nachdem die Tickets
angelegt waren. Test Plan nachgezogen: neun Punkte aus Issue #37 und Issue #50, Paket 1, von offen
auf erfüllt gesetzt — jeder gegen einen `passed`-Fund in den Nachweisprotokollen belegt, nicht aus
dem Gedächtnis. Neuer Unterabschnitt „Issue #50, Paket 1b (F002) — geschrieben und grün" mit den
drei neuen Tests. Zwei Abschnittsüberschriften, die noch „wird in `/40-tdd-red` geschrieben" sagten,
auf „geschrieben und grün" korrigiert. Der Punkt „AC-4, Ergänzung zu bestehendem Test" wurde
aufgeteilt: die umgesetzte Hälfte (`options[0]` ist `.currentName`) ist erfüllt, die nie geschriebene
`isSelected`-Assertion bleibt ausdrücklich offen und geht nach #66 — sie ist in der Unit-Suite erst
schreibbar, wenn die Markierungs-Regel dort als reine Funktion vorliegt. Eine versehentlich
mitkopierte Fremdzeile (`</content>`) am Dateiende entfernt; sie stammte aus einer früheren Sitzung.
Keine Änderung an Produktivcode oder Tests durch diesen Nachzug.

### 2026-09-28 — Korrekturgang nach dem zweiten und dritten Prüfdialog (Issue #50)

Der zweite Prüfdialog urteilte BROKEN — nicht am Code, der vollständig bewiesen ist, sondern an
dieser Spec und am PO-Briefing. Drei Runden, neun Dokumenten-Befunde, alle geschlossen:

- **F101/F106/F107 (Selbstwiderspruch):** Invariante 6, AC-13, AC-14, der Reichweiten-Satz zu
  Regel 9, die Zusagen 1 und 2 im Nachtrag Paket 1, „Expected Behavior", die Scope-Tabelle und die
  beiden „behebt Punkt 4"-Stellen versprachen „genau eine Option markiert", ohne die Ausnahme F001
  zu nennen. Alle tragen sie jetzt, mit Verweis auf Issue #66.
- **F105 (Gegenrichtung, im dritten Durchgang gefunden):** Der erste Korrekturversuch strich
  `mergeAIReresolution` KOMPLETT aus der positiven Aufzählung der abgedeckten Zuweisungswege —
  und schoss damit über das Ziel hinaus: der reproduzierte Fall aus Issue #50 läuft über genau
  diesen Weg, mit `resolvedByAI == false` (`expandAbbreviations`), und ist durch
  `RestockUITests/ReceiptReviewUITests.swift:842` belegt. AC-14 widersprach sich dadurch selbst.
  `mergeAIReresolution` steht wieder in der Aufzählung; ausgenommen ist allein die Konjunktion aus
  diesem Weg UND Namensgleichheit.
- **F103 (widerlegte Aussage):** „Ein Name aus reinen Leerzeichen entsteht nirgends mehr" gilt nur
  über die Karte. `ReceiptNameAIResolver.sanitize` trimmt vor dem Entfernen der Anführungszeichen
  und lässt `" "` durch (Issue #69). Regel 11 bleibt für den KI-Weg eine erreichbare Bedingung.
- **F104** als Known Limitation aufgenommen (Issue #69).
- **F102:** Das Briefing versprach in „Was gebaut wird" und in der Definition of Done „auch nach
  nachträglicher Namensauflösung" — genau den offenen Fall. Beide Sätze tragen die Ausnahme jetzt
  im Satz selbst, mit Ticketnummer.

Kein Produktivcode und keine Testdatei wurde in diesem Korrekturgang berührt.

### 2026-09-28 — Issue #65, Paket 2: Bontext lesbar, kopierbar, wählbar

Setzt die in Paket 1 vertagte Scope-Erweiterung um (siehe „Nachtrag Issue #50, Paket 1", Absatz
zu Issue #65). Bontext von 13pt/`Color.textSecondary` auf 15pt/`Color.ink`; `.contextMenu`
„Kopieren" am Bontext; neuer Fall `ReceiptNameOption.receiptText`, neue reine Funktionen
`normalizedReceiptText`/`shouldOfferReceiptTextOption`, neue Regel 7 in `selectionOptions`
(bisherige Regel 7 wird Regel 8). Invariante 5 geändert (max. 5 statt 4 Optionen insgesamt);
AC-2 angepasst, AC-19 bis AC-22 neu. Test Plan um „Issue #65, Paket 2" erweitert — inklusive
Korrektur einer Falschannahme aus Issue #65 und `docs/context/fix-50-import-dialog-design-paket2.md`:
tatsächlich betroffen sind vier andere bestehende UI-Tests als von Issue #65 behauptet (alle an
`Seed.aiLine`, nicht an `Seed.suggestionLine`/`Seed.unresolvedLine`), plus vier bestehende
Unit-Tests, die Issue #65 gar nicht nannte. Umfang neu geschätzt: 3 Dateien, ≈ +175 LoC (ersetzt die
Schätzungen aus Issue #65 und dem Kontext-Dokument). Status auf `draft` gesetzt, Approval erneut
zurückgesetzt.

### 2026-09-28 — Korrektur beim Einstieg in `/40-tdd-red`: falscher Options-Index

Beim Vorbereiten der RED-Tests am tatsächlichen `selectionOptions`-Ablauf nachgerechnet: Der neue
UI-Test für AC-21 („Bon-Zeile als Auswahl") verwies auf `receiptReview.line.0.option.2` — das
widersprach der eigenen Korrektur-Tabelle im selben Nachtrag, die „Anderer Name …" bereits von
`option.1` auf `option.2` verschiebt (also muss die Bon-Zeile selbst `option.1` sein, nicht noch
einmal `option.2`). Für `Seed.aiLine` (1 Kandidat: KI-Vorschlag, keine Kappung, keine Regel-5/6-
Einfügung) ergibt der Ablauf `[aiSuggestion, receiptText, custom]` — `option.0`/`option.1`/`option.2`.
Beide Stellen (GIVEN und die `isSelected`-Prüfung) auf `option.1` korrigiert. Kein weiterer Fund bei
dieser Prüfung; die vier bereits korrigierten bestehenden UI-Tests (`option.1`→`option.2`) und alle
übrigen Zeilenangaben blieben beim erneuten Nachrechnen bestätigt.

### 2026-09-28 — Korrektur in `/50-implement`: AC-20 nicht automatisiert bis zum Pasteboard-Inhalt prüfbar

GREEN-Lauf fand zwei echte, im RED-Test selbst liegende Fehler (nicht im Produktcode):

1. `app.menuItems["Kopieren"]` traf nie — SwiftUIs `.contextMenu` rendert seine Einträge auf iOS als
   `Button` in einer `CollectionView`-Zelle, nicht als `.menuItem` (per aufgezeichneter
   Bedienhilfen-Hierarchie belegt). Zu `app.buttons["Kopieren"]` korrigiert.
2. Nach dieser Korrektur hing der Testlauf reproduzierbar (>40 min, kein Fortschritt) an einem
   iOS-Systemdialog „RestockUITests-Runner möchte von Restock einsetzen" — Recherche (WWDC 2022
   Session 10096; Apple-Forum-Threads 737880, 806849, 717322, 684548) bestätigt: seit iOS 16
   verlangt ein Cross-Process-Lesezugriff auf `UIPasteboard.general` eine Nutzerbestätigung, die in
   `xcodebuild test` nie kommt; `addUIInterruptionMonitor` ist für diesen SpringBoard-Alert auf
   iOS 17+ laut mehreren offenen, ungelösten Apple-Forum-Threads nachweislich unzuverlässig, kein
   Entitlement/Launch-Argument unterdrückt die Abfrage. AC-20 und der zugehörige Test Plan-Eintrag
   auf „Verdrahtung UI-testbar, Pasteboard-Inhalt per Code-Review" umgestellt — neuer Abschnitt
   „Nicht UI-testbar (AC-20, tatsächlicher Pasteboard-Inhalt)" mit Quellen und zwei geprüften,
   verworfenen Alternativen. Gleiche Prüftiefe wie AC-19, aus vergleichbarem Grund
   (Plattform-Grenze statt fehlender Testwille). Kein Produktcode geändert.
