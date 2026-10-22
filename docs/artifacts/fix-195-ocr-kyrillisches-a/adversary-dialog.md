# Adversary Dialog — fix-195-ocr-kyrillisches-a
Spec: docs/specs/services/receipt-parser-cyrillic-tax-code.md
Datum: 2026-10-22 07:40

## Checkliste
- [x] **AC-1:** GIVEN die Zeile „Haferflocken  0,85 А“ (А = U+0410), WHEN `parse` läuft, THEN entsteht dieselbe Position (Name, Preis 0,85) wie mit lateinischem „A“.
- [x] **AC-2:** GIVEN Zeilen mit kyrillischem В, Е oder М (U+0412, U+0415, U+041C) als Kürzel direkt hinter dem Preis am Zeilenende, WHEN `parse` läuft, THEN entsteht je eine Position wie mit dem lateinischen Buchstaben.
- [x] **AC-3:** GIVEN eine Zeile mit kyrillischen Zeichen im Namen, WHEN `normalizeTaxCodeHomoglyph` läuft, THEN bleibt der Name Zeichen für Zeichen unverändert (nur das Kürzel am Zeilenende kann gewandelt werden); eine Zeile mit kyrillischem Namen und lateinischem Kürzel bleibt insgesamt unverändert.
- [x] **AC-4:** GIVEN ein kyrillisches А/В/Е/М, das nicht direkt hinter einem Preis am Zeilenende steht (z. B. mitten in der Zeile), WHEN `normalizeTaxCodeHomoglyph` läuft, THEN bleibt die Zeile unverändert.
- [x] **AC-5:** GIVEN einen Euro-Suffix-Bon mit einer Zeile, deren Name kyrillische Zeichen enthält, WHEN `parse` läuft, THEN wird diese Zeile weiterhin verworfen (`containsCyrillic` unberührt und wirksam).
- [x] **AC-6:** GIVEN die Zeile „zu zahlen  68,69 А“ (kyrillisch), WHEN `detectedTotal(from:)` läuft, THEN ist das Ergebnis 68,69 (ohne die Änderung `nil`, weil `extractTrailingPrice` nur lateinische Kürzel erlaubt).
- [x] **AC-7:** GIVEN die Änderung, WHEN die Bestands-Parsertests laufen, THEN sind sie unverändert grün (kein Test angepasst, keiner übersprungen).
- [x] **AC-8:** GIVEN `ReceiptTextRecognizerTests` T1 auf `Restock-Validate-27` (iOS 27.0), WHEN er läuft, THEN findet er 18 Positionen samt Endsumme 68,69 (vorher 15), und die Vision-Anfrage-Einstellungen in `ReceiptTextRecognizer` (`.accurate`, `["de-DE","fr-FR","en-US"]`, `usesLanguageCorrection == false`, Ausrichtung) sind unverändert (AC-9 aus #120 bleibt gültig); `ReceiptTextRecognizer.swift` erscheint nicht im Diff.
- [x] **AC-9:** GIVEN der Diff dieses Durchgangs, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `SmartCart/Services/ReceiptParserService.swift` und `RestockTests/ReceiptParserPriceTests.swift` (ca. +60 LoC), ohne neue Datei, `project.pbxproj`-, `Info.plist`-, `@AppStorage`- oder Schema-Änderung; Unit-Suite grün (Testzahl > 0), Release-Build kompiliert.
- [x] **AC-10:** GIVEN Ticket und Bericht, WHEN sie formuliert werden, THEN nennen sie die offenen Grenzen: andere Vision-Fehllesungen (z. B. „ął“ statt „B“, beobachtet in #120) sind nicht Teil; nur А/В/Е/М hinter einem Preis am Zeilenende; nichts auf einem echten Gerät geprüft (nur Simulator iOS 27.0 und Unit-Tests).

## Dialog

### Runde 1
**Adversary:** Diff gelesen: 17 Zeilen Produktivcode in `SmartCart/Services/ReceiptParserService.swift`, neue Funktion `normalizeTaxCodeHomoglyph` plus je ein Aufruf in `parse` und `detectedTotal`. Regex `\d[,\.]\d{2}\s*[АВЕМ]\s*$`. Angriffe:
- Kürzel ohne Leerraum direkt am Preis ("0,85А"): `\s*` erlaubt null Zeichen, wird gewandelt. Kein Defekt.
- Tab vor/nach dem Kürzel: `parse` ersetzt Tabs schon vorher durch zwei Leerzeichen (main-Änderung), `\s*` fängt beides. Kein Defekt.
- Drei Nachkommastellen ("12,345 А"): die dritte Ziffer bricht das Muster, Zeile bleibt unverändert. Gewollt.
- Mehrere Preise in der Zeile ("1,00 2,00 В"): Regex am Zeilenende verankert, nur das letzte Kürzel wird gewandelt. Kein Defekt.
- Negativpreis/Rabatt ("-0,85 А"): Minus liegt vor der Ziffer, Muster trifft; nur der Buchstabe ändert sich, Rabattbehandlung bleibt wie bei lateinischem "A". Kein Defekt.
- Zeile nur aus Preis+Kürzel ("0,85 А"): wird "0,85 A"; die Namensprüfung der Parser-Pfade entscheidet wie bisher. Kein neues Verhalten.
- Kürzel mit kombinierendem Zeichen oder Zero-Width-Space dahinter: `$` greift nicht, Zeile bleibt kyrillisch (Position geht wie vor dem Fix verloren). Von der Spec ausgeschlossen (AC-4, AC-10), nur Grenze (F001).
- Reihenfolge `repairSplitDecimals`, dann Normalisierung: keine Wechselwirkung, die Reparatur kennt keine Endbuchstaben.
- Euro-Suffix-Pfad: Wandlung wirkt nur bei Kürzel direkt hinter Preis, nicht hinter "€"; `containsCyrillic` (Zeile 730/801) unberührt, `testEuroSuffixStillRejectsCyrillicNames` grün. Restrisiko: Euro-Suffix-Bon mit kyrillischem Namen und "…1,00 М" am Ende würde gewandelt; nicht beobachtet, nicht Teil der Spec.
- Abweichung des Entwicklerberichts: `String(line[..<letterIndex]) + latin` schneidet Leerraum HINTER dem Buchstaben ab. Kein Schaden: `parse` trimmt Zeilen ohnehin, die Positions-Regexe erlauben `\s*$`, `detectedTotal` trimmt ebenfalls; die Spec ("Ersatz: Preis + Leerraum + Buchstabe") deckt es sogar wörtlich ab.
**Implementierer:** n/a (Prüfdurchlauf). Testnachweis `docs/artifacts/fix-195-ocr-kyrillisches-a/test-green-output.txt`: 6 neue Cyrillic-Tests passed, 72 Tests, 0 Failures, `test_T1_erzeugtesHohesBild…` passed auf Restock-Validate 27.

### Runde 2
**Adversary:** Zweite Runde gegen Regressionen und Scope. Diffstat über SmartCart/RestockTests/Restock.xcodeproj: nur `ReceiptParserService.swift` (+17/-2); `ReceiptTextRecognizer.swift` nicht im Diff; `required-files` listet nur `ReceiptParserService.swift`. Testdatei liegt im RED-Commit c37ca6c (nach Rebase; Spec nennt dc9086f). Keine neue Datei, kein pbxproj, keine Info.plist, kein Schema. Aufrufer der geänderten Funktionen: `parse` und `detectedTotal(from:)` (App-Scanner und Teilen-Erweiterung), Signaturen unverändert. Kein `#if` in der Änderung, Release-Kompilierung unkritisch; ein eigener Release-Build wurde von mir NICHT gefahren (CI-Job `release-build` ist der Beleg, offen bis PR-CI). Bestandstests: 31 Tests der Parser-Klasse, 0 Fehler. Ein Wegwerf-Skript zur Regex-Ausführung scheiterte am Bash-Guard des Worktrees; die Randfälle sind daher aus Code und Regexsemantik abgeleitet, nicht ausgeführt. AC-10 ist laut Auftrag vom Orchestrator zu liefern (Ticket/Bericht), kein Code-Defekt.
**Implementierer:** n/a

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Services/ReceiptParserService.swift:188
  Evidence: `parse` ruft nach `repairSplitDecimals` die Normalisierung; Test `testCyrillicTaxCodeAAfterPriceYieldsPositionLikeLatin` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Services/ReceiptParserService.swift:269
  Evidence: Zeichenklasse enthält U+0410/0412/0415/041C, Map auf A/B/E/M; `testCyrillicTaxCodesBEMAfterPriceYieldPositions` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Services/ReceiptParserService.swift:270
  Evidence: Nur der Treffer am Zeilenende wird ersetzt; Namensanteil bleibt; Test passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Services/ReceiptParserService.swift:271
  Evidence: Regex mit `$` am Zeilenende verankert, Preis davor Pflicht; ohne Treffer `return line`. Test passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Services/ReceiptParserService.swift:801
  Evidence: `.filter { ... !containsCyrillic($0) }` unverändert; Euro-Suffix-Zeilen enden auf "€", Regex greift nicht. Test passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Services/ReceiptParserService.swift:226
  Evidence: `detectedTotal` normalisiert wie `parse`; `testDetectedTotalFindsTotalWithCyrillicTaxCode` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Services/ReceiptParserService.swift:188
  Evidence: Lauf 72 Tests, 0 Failures; Bestandstests nicht verändert (Test-Diff nur Ergänzung).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Services/ReceiptParserService.swift:226
  Evidence: `test_T1_erzeugtesHohesBild_streifenErkennenAlleArtikelUndEndsumme` passed (3,967 s) im Nachweis; `ReceiptTextRecognizer.swift` nicht im Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Services/ReceiptParserService.swift:260
  Evidence: Diff umfasst nur diese Datei (Tests im RED-Commit), keine Projektdatei. Release-Build von mir nicht gefahren (CI-Job release-build steht aus).
  Status: CONFIRMED

AC-10: vom Orchestrator zu liefern (Ticket/Bericht), kein Defekt im Code; offen vermerkt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Services/ReceiptParserService.swift:271
  Description: Kürzel mit angehängtem kombinierendem Zeichen oder Zero-Width-Space wird nicht gewandelt, die Position geht dann weiter verloren.
  Spec requirement: AC-10 — Grenze "nur А/В/Е/М hinter einem Preis am Zeilenende"
  Conflict: Keiner, von der Spec ausgeschlossen; nur als Grenze zu nennen.
  Remediation: Keine nötig; in der Grenzenliste erwähnen.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 72 passed, 0 failed, 0 übersprungen (Nachweis test-green-output.txt, eigener Lauf nicht nötig)
Edge cases: Regexrandfälle aus Code abgeleitet (nicht ausgeführt), keine Defekte
Regressions: None found
Checklist: 9/9 Code-Punkte bewiesen; AC-10 vom Orchestrator zu liefern; Release-Build durch CI-Job offen

## Geprüfte Dateien

- sha256:8e265f9c96d83ede45a7a059048cac7d8ee8f2033d464a298b99c2e0fbfa4be7  SmartCart/Services/ReceiptParserService.swift

## Prüfbasis

- base: a49466f03c32d42b4e8548e4563b7c1fa97045ef
- blob:d2d7f1be7f4e12dba398752c44e18dfbbda8c1d3  SmartCart/Services/ReceiptParserService.swift

## Geprüfte Dateien

- sha256:8e265f9c96d83ede45a7a059048cac7d8ee8f2033d464a298b99c2e0fbfa4be7  SmartCart/Services/ReceiptParserService.swift

## Prüfbasis

- base: a49466f03c32d42b4e8548e4563b7c1fa97045ef
- blob:d2d7f1be7f4e12dba398752c44e18dfbbda8c1d3  SmartCart/Services/ReceiptParserService.swift
