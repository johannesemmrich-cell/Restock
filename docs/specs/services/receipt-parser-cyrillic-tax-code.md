---
entity_id: receipt-parser-cyrillic-tax-code
type: bugfix
created: 2026-10-21
updated: 2026-10-21
status: draft
workflow: fix-195-ocr-kyrillisches-a
tags: [receipt, ocr, vision, parser, homoglyph, ios27, issue-195]
---

# Bon-Parser: kyrillisches MwSt-Kürzel hinter dem Preis zurückwandeln (Issue #195)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Auf iOS 27.0 liefert Vision das MwSt-Kürzel „A“ hinter dem Preis als kyrillisches А (U+0410), z. B. „Haferflocken  0,85 А“.
Die Zeilenmuster des Parsers erlauben am Zeilenende nur lateinische Kürzel (`[ABM12E\*]`), die Zeile gilt nicht als Position,
und der Streifen-Test T1 (`ReceiptTextRecognizerTests`) findet 15 statt 18 Positionen (Nutzer verlieren Artikel).

Analyse, Reproduktion (Restock-Validate-27, iOS 27.0, Stand `d8e0479`) und Alternativen stehen in
`docs/context/fix-195-ocr-kyrillisches-a.md`; Beleg der Rohblöcke in `docs/artifacts/fix-195-ocr-kyrillisches-a/`.
Dasselbe Zeichen trat schon auf iOS 26 im Einzelzug auf (`docs/artifacts/fix-120-bon-lange-bilder/ist-zustand-erzeugtes-bild.txt`),
ist also kein reines iOS-27-Phänomen, nur häufiger.

**Lösung (Regel, kein Modell):** Eine neue reine Funktion `normalizeTaxCodeHomoglyph` wandelt NUR ein alleinstehendes
kyrillisches А/В/Е/М (U+0410, U+0412, U+0415, U+041C) direkt hinter einem Preis (`\d[,\.]\d{2}`, optionale Leerzeichen)
am Zeilenende in den lateinischen Buchstaben A/B/E/M. Sie läuft in `parse` und `detectedTotal` gemeinsam mit
`repairSplitDecimals` (eine Normalisierung für beide Wege). Weil App-Scanner (`ReceiptScannerView.process`) und
Teilen-Erweiterung (`ShareViewController`) beide `parse`/`detectedTotal` rufen, wirkt die Änderung auf beide.
Kyrillische Zeichen in Namen werden nie angefasst.

## Source

- **File:** `SmartCart/Services/ReceiptParserService.swift` (`parse` :176, `detectedTotal(from:)` :214,
  `repairSplitDecimals` :243, `containsCyrillic` :679 unberührt, `extractTrailingPrice` :983)
- **File (Test):** `RestockTests/ReceiptParserPriceTests.swift`
- **Wächter, unverändert:** `RestockTests/ReceiptTextRecognizerTests.swift` (T1)

Zeilennummern verschieben sich; maßgeblich sind die Funktionen.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ReceiptParserService.parse` | function | Ruft künftig die Normalisierung vor der Formaterkennung. |
| `ReceiptParserService.detectedTotal(from:)` | function | Ruft dieselbe Normalisierung; `extractTrailingPrice` erlaubt nur `[ABM12E\*]?` und fände „68,69 А“ sonst nicht. |
| `ReceiptParserService.repairSplitDecimals` | function | Bleibt unverändert; Normalisierung als gemeinsamer Helfer (z. B. `normalizeLine`) beider Schritte. |
| `ReceiptParserService.containsCyrillic` | function | Euro-Suffix-Pfad verwirft Namens-Chunks mit kyrillischen Zeichen; bleibt unverändert und wirksam. |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/ReceiptParserService.swift` | MODIFY | `normalizeTaxCodeHomoglyph` (ca. 15 Zeilen) plus Aufruf in `parse` und `detectedTotal` |
| `RestockTests/ReceiptParserPriceTests.swift` | MODIFY | Neue reine Parser-Tests (ohne Vision) |

### Estimated Changes
- Dateien: 2, keine neuen Dateien (kein `project.pbxproj`).
- LoC: ca. +60 / −0 (Regel ca. 15, Tests ca. 45).
- Risiko: niedrig; enge Regel, ein Parser-Eintrittspunkt.
- Seiteneffekte: keine neuen Permissions, kein `Info.plist`-Eintrag, kein `@AppStorage`-Schlüssel, keine Schema-Änderung,
  keine neuen Dependencies, keine Audio-Dateien. Die Anfrage-Einstellungen in `ReceiptTextRecognizer` bleiben unberührt.

## Definition of Done

- [ ] Reine Parser-Tests RED belegt (kyrillisches Kürzel → keine Position), danach grün (AC-1, AC-2, AC-6)
- [ ] Abgrenzungstests grün: Namen, Zeilenmitte, Euro-Suffix-Pfad (AC-3, AC-4, AC-5)
- [ ] Bestands-Parsertests unverändert grün (AC-7)
- [ ] T1 liefert auf iOS 27.0 (`Restock-Validate-27`) wieder 18 Positionen, Anfrage-Einstellungen unverändert (AC-8)
- [ ] Unit-Suite grün, Testzahl > 0; Release-Build kompiliert; Diff genau 2 Dateien (AC-9)
- [ ] Offene Grenzen in Ticket und Bericht (AC-10)

## Implementation Details

### `normalizeTaxCodeHomoglyph` (rein, testbar ohne Vision)

```swift
/// Wandelt ein alleinstehendes kyrillisches Steuerkürzel (А В Е М) direkt hinter einem Preis am
/// Zeilenende in den lateinischen Buchstaben. Berührt sonst nichts.
static func normalizeTaxCodeHomoglyph(_ line: String) -> String
```

- Muster: `(\d[,\.]\d{2})(\s*)([АВЕМ])\s*$`, Ersatz: Preis + Leerraum + lateinischer Buchstabe
  (А→A, В→B, Е→E, М→M). Der Leerraum zwischen Preis und Kürzel bleibt erhalten.
- Nur das Zeilenende zählt. Ein kyrillisches А/В/Е/М davor, danach oder im Namen bleibt unverändert; ebenso jedes
  andere kyrillische Zeichen (z. B. „х“ im Euro-Suffix-Pfad, dort bestehende eigene Behandlung).
- Die Ziffern 1 und 2 der Kürzelmenge sind schon ASCII und brauchen keine Wandlung.
- Gemeinsame Zeilenvorverarbeitung: `rawLines.map { normalizeTaxCodeHomoglyph(repairSplitDecimals($0)) }` in `parse`
  und `detectedTotal`. Reihenfolge: erst `repairSplitDecimals` (es fügt gesplittete Preise zusammen), dann die
  Kürzel-Wandlung.
- Wirkung auf `detectedTotal`: „zu zahlen  68,69 А“ wird zu „zu zahlen  68,69 A“, `extractTrailingPrice` findet 68,69.
  Ohne Wandlung lieferte es `nil`.

## Test Plan

### Automated Tests (TDD RED)

Alle in `RestockTests/ReceiptParserPriceTests.swift`, ohne Vision, kyrillische Zeichen als `\u{0410}` usw. geschrieben:

- [ ] `testCyrillicTaxCodeAAfterPriceYieldsPositionLikeLatin` (AC-1): „Haferflocken  0,85 \u{0410}“ ergibt dieselbe
  Position (Name „Haferflocken“, Preis 0,85) wie mit lateinischem „A“.
- [ ] `testCyrillicTaxCodesBEMAfterPriceYieldPositions` (AC-2): je eine Zeile mit В, Е, М (U+0412, U+0415, U+041C) ergibt
  eine Position wie die lateinische Entsprechung.
- [ ] `testCyrillicLettersInNameAreUnchangedByNormalization` (AC-3): `normalizeTaxCodeHomoglyph` auf „Mол\u{0410}ко  1,29 A“
  (kyrillische Zeichen im Namen, lateinisches Kürzel) liefert die Zeile unverändert; ebenso „\u{0410}pfel  1,29 \u{0410}“
  ändert nur das Kürzel am Ende, nicht das А im Namen.
- [ ] `testCyrillicAOutsideLineEndAfterPriceIsUnchanged` (AC-4): „Tee \u{0410} Sorte  1,29 A“ und „1,29 \u{0410} Rest“
  bleiben unverändert (kyrillisches А nicht direkt hinter Preis am Zeilenende).
- [ ] `testEuroSuffixStillRejectsCyrillicNames` (AC-5): ein Euro-Suffix-Bon (mindestens zwei Zeilen „…  2.50€“, eine
  davon mit kyrillischem Zeichen im Namen) verwirft die Zeile mit kyrillischem Namen weiterhin; die übrigen bleiben.
- [ ] `testDetectedTotalFindsTotalWithCyrillicTaxCode` (AC-6): „zu zahlen  68,69 \u{0410}“ liefert 68,69 (Gegenprobe
  mit lateinischem „A“ gleich). `extractTrailingPrice` erlaubt das Kürzel-Zeichen nur lateinisch, deshalb Wandlung nötig.
- [ ] AC-7: gesamte Bestands-Parsersuite (u. a. `ReceiptParserLidlFullReceiptTests`, `ReceiptParserPriceTests`) unverändert grün.
- [ ] AC-8 (Wächter, braucht Vision): T1 in `ReceiptTextRecognizerTests` auf `Restock-Validate-27` (iOS 27.0) grün, 18 Positionen.
- [ ] AC-9: Unit-Suite lokal grün (Testzahl > 0, kein Abbruch), Release-Build kompiliert, `git diff --stat` zeigt genau die zwei Dateien.
- [ ] AC-10 (Review-Schritt, nicht automatisiert): Ticket-Kommentar und Abschlussbericht enthalten die drei Grenzen
  (andere Fehllesungen nicht Teil; nur А/В/Е/М hinter Preis am Zeilenende; nichts auf echtem Gerät geprüft);
  Prüfung per Textsuche im Ticket (`gh issue view 195 --comments`) in Phase 6.

## Acceptance Criteria

- **AC-1:** GIVEN die Zeile „Haferflocken  0,85 А“ (А = U+0410), WHEN `parse` läuft, THEN entsteht dieselbe Position
  (Name, Preis 0,85) wie mit lateinischem „A“.
- **AC-2:** GIVEN Zeilen mit kyrillischem В, Е oder М (U+0412, U+0415, U+041C) als Kürzel direkt hinter dem Preis am
  Zeilenende, WHEN `parse` läuft, THEN entsteht je eine Position wie mit dem lateinischen Buchstaben.
- **AC-3:** GIVEN eine Zeile mit kyrillischen Zeichen im Namen, WHEN `normalizeTaxCodeHomoglyph` läuft, THEN bleibt der
  Name Zeichen für Zeichen unverändert (nur das Kürzel am Zeilenende kann gewandelt werden); eine Zeile mit
  kyrillischem Namen und lateinischem Kürzel bleibt insgesamt unverändert.
- **AC-4:** GIVEN ein kyrillisches А/В/Е/М, das nicht direkt hinter einem Preis am Zeilenende steht (z. B. mitten in
  der Zeile), WHEN `normalizeTaxCodeHomoglyph` läuft, THEN bleibt die Zeile unverändert.
- **AC-5:** GIVEN einen Euro-Suffix-Bon mit einer Zeile, deren Name kyrillische Zeichen enthält, WHEN `parse` läuft,
  THEN wird diese Zeile weiterhin verworfen (`containsCyrillic` unberührt und wirksam).
- **AC-6:** GIVEN die Zeile „zu zahlen  68,69 А“ (kyrillisch), WHEN `detectedTotal(from:)` läuft, THEN ist das
  Ergebnis 68,69 (ohne die Änderung `nil`, weil `extractTrailingPrice` nur lateinische Kürzel erlaubt).
- **AC-7:** GIVEN die Änderung, WHEN die Bestands-Parsertests laufen, THEN sind sie unverändert grün (kein Test
  angepasst, keiner übersprungen).
- **AC-8:** GIVEN `ReceiptTextRecognizerTests` T1 auf `Restock-Validate-27` (iOS 27.0), WHEN er läuft, THEN findet er
  18 Positionen samt Endsumme 68,69 (vorher 15), und die Vision-Anfrage-Einstellungen in `ReceiptTextRecognizer`
  (`.accurate`, `["de-DE","fr-FR","en-US"]`, `usesLanguageCorrection == false`, Ausrichtung) sind unverändert
  (AC-9 aus #120 bleibt gültig); `ReceiptTextRecognizer.swift` erscheint nicht im Diff.
- **AC-9:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau
  `SmartCart/Services/ReceiptParserService.swift` und `RestockTests/ReceiptParserPriceTests.swift` (ca. +60 LoC),
  ohne neue Datei, `project.pbxproj`-, `Info.plist`-, `@AppStorage`- oder Schema-Änderung; Unit-Suite grün
  (Testzahl > 0), Release-Build kompiliert.
- **AC-10:** GIVEN Ticket und Bericht, WHEN sie formuliert werden, THEN nennen sie die offenen Grenzen: andere
  Vision-Fehllesungen (z. B. „ął“ statt „B“, beobachtet in #120) sind nicht Teil; nur А/В/Е/М hinter einem Preis am
  Zeilenende; nichts auf einem echten Gerät geprüft (nur Simulator iOS 27.0 und Unit-Tests).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der Fehler ist ein deterministischer Zeichentausch, kein Sprachverstehen. Ohne Modell geht es nicht
  nur, sondern besser: Eine Regel mit engem Muster ist exakt testbar. Kein früherer Beschluss wird gekippt; der
  Beschluss AC-9 aus #120 (Anfrage-Einstellungen, keine Sprachkorrektur) bleibt bestehen.

## Folge-Durchgänge/Abgrenzung

- **Ausdrücklich nicht Teil:** weitere Vision-Fehllesungen (z. B. „ął“ statt „B“), kyrillische Zeichen in Namen
  (bleiben unverändert; im Euro-Suffix-Pfad ein Verwerfungs-Signal), Änderung der Vision-Anfrage.
- **Offene Grenze:** Apple hat die Texterkennungsmodelle in iOS 27 still getauscht (Entwicklerberichte:
  forums/thread/845452, forums/thread/851862, macshot#439, keine Apple-Antwort). Weitere Doppelgänger können
  auftreten und werden erst im Gebrauch bzw. im Wächter T1 sichtbar.

## Alternativen

| | Weg | Urteil |
|---|---|---|
| **A (gewählt)** | Regel im Parser: kyrillisches А/В/Е/М nur als Kürzel hinter Preis am Zeilenende zurückwandeln | Deterministisch, ohne Modell, wirkt auf App-Scanner und Teilen-Erweiterung, Namen unberührt, Ursache selbst behoben |
| B | `usesLanguageCorrection = true` | Gemessen: 18 Positionen. Modellweg, kippt AC-9 aus #120, verfälscht Namen zu Wörterbuch-Wörtern; verworfen |
| C | Schnellmodus (`.fast`) | Gemessen: 18 Positionen, aber ungenauere Erkennung insgesamt; verworfen |
| D | Test T1 auf 15 Positionen senken | Verdeckt den echten Nutzerverlust von drei Artikeln; verworfen |
| E | Kyrillische Kürzel im Regex zulassen (`[ABM12EАВЕМ\*]` an allen sechs Stellen) | Streut die Ausnahme über sechs Muster (:140, :255, :296, :300, :304, :984), Name und Kürzel bleiben unterschiedlich behandelt, das Zeichen bliebe im Datenstrom; Normalisierung an einer Stelle ist einfacher; verworfen |

Gekippte frühere Entscheidung: keine. Regelweg zuerst gebaut; die Modellwege B und C sind die Alternativen.

**Entscheidung:** Weg A.

## Risiken

- **Zu weites Muster:** würde kyrillische Namensteile ändern. Begrenzt durch den Anker am Zeilenende, den Preis davor
  und die vier Buchstaben; AC-3 und AC-4 prüfen es.
- **Euro-Suffix-Pfad ausgehebelt:** Die Wandlung greift nur hinter einem Preis ohne Währungssymbol am Ende; die
  `containsCyrillic`-Filterung der Namens-Chunks bleibt (AC-5).
- **Wirkt auf zwei Verbraucher gleichzeitig** (App-Scanner und Teilen-Erweiterung): gewollt, über die gemeinsame
  Parser-Funktion; Wächter T1 und Bestandstests decken es.
- **Weitere Vision-Fehllesungen** bleiben (siehe Offene Grenzen).
- **Simulator nie parallel** (eigenes Testgerät `Restock-Validate-27`); „Executed 0 tests“ ist kein Grün.

## Changelog

- 2026-10-21: Initial spec created (Issue #195; Regel im Parser statt Anfrage-Umbau, PO-Entscheidung 2026-10-21)
