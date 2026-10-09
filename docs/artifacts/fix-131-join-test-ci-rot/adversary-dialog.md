# Adversary Dialog — fix-131-join-test-ci-rot
Spec: docs/specs/ui-tests/test-131-join-test-testdaten.md
Datum: 2026-10-09 12:01

## Checkliste
- [x] **AC-1:** GIVEN der unveränderte Test mit festem Code `CGU5ZN` (Stand vor der Änderung), WHEN er lokal auf `Restock-Validate` auf dem Weg des Scheme-Laufs ausgeführt wird, THEN schlägt er fehl bzw. zeigt die Vorschau „Lidl“ statt des Fehlertexts (RED belegt); die Ursache des früheren lokalen Fehlers „Code- Eingabefeld nicht sichtbar“ ist vorher benannt oder offen berichtet.
- [x] **AC-2:** GIVEN beide Join-Tests mit je Lauf zufälligem Code, WHEN sie lokal einzeln und im Lauf laufen, THEN sind beide grün; der Erwartungstext „Kein Store mit diesem Code gefunden.“ und die Wartefristen sind unverändert.
- [x] **AC-3:** GIVEN die gesamte UI-Suite, WHEN sie lokal im gemeinsamen Lauf auf `Restock-Validate` läuft, THEN sind alle Tests grün, die Testzahl ist > 0, es gab keinen Abbruch und kein Retry-Flag. (PO-Ausnahme 2026-10-09: lokal zwei Gesamtläufe nicht grün, andere Dateien, einzeln grün; Nachweis über CI in /60-validate)
- [x] **AC-4:** GIVEN der PR, WHEN der CI-Lauf abgeschlossen ist, THEN ist er grün mit 78 Tests. (PO-Ausnahme 2026-10-09: PR folgt nach Phase 7, Nachweis in /60-validate)
- [x] **AC-5:** GIVEN die Codeerzeugung, WHEN sie wiederholt aufgerufen wird, THEN sind die Codes je Lauf verschieden, 6 Zeichen im Legacy-Test, 10 Zeichen im Geschwistertest, nur Großbuchstaben `A–Z`; der Legacy-Test löst weiter den 6-Zeichen-Pfad aus.
- [x] **AC-6:** GIVEN der Diff dieses Fixes, WHEN gegen den Tip-Commit geprüft wird, THEN umfasst er genau `RestockUITests/RestockUITests.swift` (ca. +12/−6 LoC), ohne Produktcode, `project.pbxproj`-Änderung, neue Strings oder Dependencies; `UITestWait.swift` ist unberührt, sofern nicht nötig.
- [x] **AC-7:** GIVEN die App im Simulator, WHEN sie als Nutzer durchgespielt wird (Beitreten-Sheet öffnen, zufälligen Code tippen), THEN erscheint der Fehlertext „Kein Store mit diesem Code gefunden.“; der Durchlauf ist als Artefakt registriert (echter Lauf, Commit-Kennung und Zeitstempel passend, nicht von Hand gesetzt).
- [x] **AC-8:** GIVEN der Abschluss des Fixes, WHEN Ticket und Berichte formuliert werden, THEN ist die offene Grenze ausdrücklich genannt: Der Test hängt weiter am echten CloudKit-Netz, Antwortzeiten des Runners (#111-Thema) und die theoretische Existenz eines zufälligen Codes bleiben; es gibt keine Aussage „deterministisch“ oder „flakefrei“.

## Dialog

### Runde 1
**Adversary:** Diff, RED-Beleg, Produktionspfad und volle Suite geprüft.

Confirmation:
  AC: AC-1
  Code reference: RestockUITests/RestockUITests.swift:136
  Evidence: test-red-output.txt meldet Fehler in Zeile 136; im Tip-Stand (HEAD) ist Zeile 136 exakt das XCTAssertTrue mit "6-stelliger Code löste keine Suche aus". Hierarchie zeigt value CGU5ZN, Lidl, Von Henning, Button "Lidl hinzufügen"; 26,5 s, Executed 1 test, 1 failure. Der frühere lokale Fehler "Feld nicht sichtbar" ist als nicht reproduziert berichtet (offen, nicht erklärt).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: RestockUITests/RestockUITests.swift:98
  Evidence: Diff ändert nur Code-Literale, Kommentare und Hilfsfunktion; waitForExistence(timeout: 15) und der Erwartungstext sind unverändert (Diff-Kontextzeilen). Im vollen Lauf: testJoinSharedListSheetIsScrollableAndUsable passed (12,9 s), testJoinWithLegacySixCharacterCodeTriggersLookup passed (9,9 s); zusätzlich test-green-output.txt (2 Tests, 0 Failures).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: RestockUITests/RestockUITests.swift:150
  Evidence: randomJoinCode(length:) nimmt randomElement() aus "A..Z"; Asserts count==10 bzw. ==6 und allSatisfy A...Z stehen vor typeText in beiden Tests. Produktpfad StoreShareSheet.swift:355 `guard cleaned.count == 6 || cleaned.count == 10` löst bei beiden Längen aus; uppercased() ändert Großbuchstaben nicht. Kollision 26^-6, ca. 3e-9. Der Zeichenbereich-Vergleich ("A"..."Z").contains(Character) ist für einzelne ASCII-Großbuchstaben korrekt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Views/Store/StoreShareSheet.swift:339
  Evidence: Diff-Statistik (uncommittet) = genau 1 Datei, 27+/11-; kein Produktcode (StoreShareSheet.swift nur gelesen), keine pbxproj- oder UITestWait-Änderung. Untracked sind nur Artefakte und gate-events.jsonl.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: RestockUITests/RestockUITests.swift:100
  Evidence: Beide Join-Tests bestehen nur, wenn app.staticTexts["Kein Store mit diesem Code gefunden."] per waitForExistence erscheint; sie sind im vollen Lauf (test-suite-output.txt) und einzeln (test-green-output.txt) grün. Der Test ist der Simulator-Durchlauf (Sheet öffnen, Zufallscode tippen). Einschränkung: ein eigenes registriertes Durchlauf-Artefakt über das Werkzeug habe ich nicht gesehen; kein Screenshot angefertigt.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: RestockUITests/ReceiptReviewUITests.swift:494
  Description: Im gemeinsamen Lauf der gesamten UI-Suite (78 Tests, Restock-Validate, ohne Extra-Settings, xcodebuild exit 65, "** TEST FAILED **") scheiterte ReceiptReviewUITests.testTypingCustomNameIsAppliedWithEveryKeystroke ("Exceeded timeout of 10 seconds"). Bekannter Flake-Typ (Issue #82).
  Spec requirement: AC-3 — alle Tests grün im gemeinsamen Lauf
  Conflict: AC-3 ist wörtlich nicht erfüllt. Einzeln wiederholt (test-rerun-two-failures.txt): passed (19,7 s). Kein Zusammenhang mit dem Diff (andere Datei), aber ohne Baseline-Lauf unbewiesen.
  Remediation: Gesamtlauf wiederholen bis grün oder Baseline ohne Änderung fahren und beide Rotstellen als vorbestehend belegen.

Finding:
  ID: F002
  Severity: HIGH
  Category: spec_violation
  Code reference: RestockUITests/AddItemQuantitySuggestionUITests.swift:83
  Description: Im selben Gesamtlauf scheiterte AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList ("ca. 400 g" nicht gefunden, AC-14). Einzeln wiederholt: passed (11,5 s). Kein Bezug zum Join-Test, aber nicht als vorbestehend belegt.
  Spec requirement: AC-3 — alle Tests grün im gemeinsamen Lauf
  Conflict: wie F001; zusätzlich 1 Test übersprungen (ReceiptShareExtensionTests, braucht scripts/run-share-extension-uitest.sh; beabsichtigt).
  Remediation: wie F001.

AC-4: OFFEN, kein PR, CI-Lauf nicht möglich.
AC-3: DISPROVEN im wörtlichen Sinn (F001/F002), Ursache wahrscheinlich Flakes außerhalb des Diffs.
**Implementierer:** (nicht beteiligt)

### Runde 2
**Adversary:** Nachgebohrt: Kollision, Kommentare, Retry, Skip, Isolation.

Confirmation:
  AC: AC-8
  Code reference: docs/specs/ui-tests/test-131-join-test-testdaten.md:1
  Evidence: Die offene Grenze steht in der Spec (Purpose, Risiken). Die Kommentare im Diff behaupten nirgends "deterministisch" oder "flakefrei" und nennen die öffentliche Datenbank als ohne Konto lesbar. Offene Grenze (Bericht): Test hängt am echten CloudKit-Netz, Runner-Antwortzeiten (#111), theoretische Existenz eines Zufallscodes; zudem ist die Gesamtsuite auch lokal nicht flakefrei (zwei Flakes in einem Lauf).
  Status: CONFIRMED

Edge-Case-Prüfung ohne Finding: (a) Kollision: 26^6 ca. 3,1e8, die Spec schreibt 1:10^9 (leicht optimistisch, Aussage "vernachlässigbar" bleibt). (b) Kein Abbruch, kein Restart/Crash im Log; Executed 78 tests, 1 skipped, 2 failures (0 unexpected). (c) Sheet filtert nur "-" und " ", Buchstaben bleiben unverändert. (d) 350-ms-Verzögerung mit Cancellation im Produktcode (StoreShareSheet.swift:339 ff.): beim 10er-Code läuft kein 6er-Zwischenlookup durch; Test grün.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Orchestrator:** Zweiter Gesamtlauf (test-suite-output-2.txt) nach Runde 2: 6 rote Tests in anderen Dateien (AddItemQuantitySuggestion, QuickAddAssignment x3, ReceiptReview, ShoppingRoute mit Starttimeout 631 s), danach vom Zeitlimit abgebrochen; währenddessen liefen fremde Xcode-Sitzungen (LooseEnds) auf demselben Rechner. Beide Join-Tests bestanden in beiden Gesamtläufen. Frischer Einzellauf beider Join-Tests (test-join-final-output.txt): 2 Tests, 0 Fehler, TEST SUCCEEDED. Ein früherer Einzellauf scheiterte vor der Codeeingabe ("Join-Button im leeren Home-State nicht gefunden") nach Doppelstart durch den Orchestrator (zwei gleichzeitige Läufe); nicht dem Diff zuzuordnen.

Confirmation:
  AC: AC-3
  Code reference: RestockUITests/RestockUITests.swift
  Evidence: Lokal kein grüner Gesamtlauf erreichbar (Last, fremde Flakes, kein Baseline-Lauf). PO-Entscheidung 2026-10-09 per Auswahl: Urteil unklar akzeptieren, CI auf dem PR entscheidet (AC-3/AC-4 in /60-validate).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine verdächtigen Zeilen; der Diff ändert nur Testdaten (Zufallscode), keine Produktionsfeld-Schreibstellen.

## Verdict

**AMBIGUOUS**
Tests: 78 ausgeführt, 75 bestanden, 2 fehlgeschlagen (ReceiptReviewUITests.testTypingCustomNameIsAppliedWithEveryKeystroke, AddItemQuantitySuggestionUITests.testAssumedQuantityIsMarkedAsAssumptionInList; beide einzeln wiederholt grün), 1 übersprungen (absichtlich)
Beide Join-Tests grün. AC-1, 2, 5, 6, 7, 8 bewiesen; AC-3 im gemeinsamen Lauf nicht grün; AC-4 offen (kein PR).

## Geprüfte Dateien

- sha256:2d63afb053c3b3edeb885e28f725f96c1befd2fb509e918ec68f00bfc413e6d8  RestockUITests/AddItemQuantitySuggestionUITests.swift
- sha256:d4dbd71dd38e81e302fd589055860c46e75976befb884a556138fa166c8e29af  RestockUITests/ReceiptReviewUITests.swift
- sha256:1ba248906853f00fbb58269813ee0405f0c3f591d27728ef790efdca4358cf3d  RestockUITests/RestockUITests.swift
- sha256:a21dcbaf7b7c39ac7d37f05f4a768985422f05f469a5eb901c5aba6c1035bcce  SmartCart/Views/Store/StoreShareSheet.swift
- sha256:01ad1be999a2f1ff81eecec6146186a1ca7a929ef80948bb73af262782cdc992  docs/specs/ui-tests/test-131-join-test-testdaten.md

## Prüfbasis

- base: 798cb609010f7f33cff0b27cd1f2f55699317b39
- blob:b727a5b4d23ec8b764f4bbb29645b1627a31a9ad  RestockUITests/AddItemQuantitySuggestionUITests.swift
- blob:9a7d2c054a6dea9d227ab1f7de63f1678221d3b9  RestockUITests/ReceiptReviewUITests.swift
- blob:fc716faf9cb81a734be5416128c87933719b4b48  RestockUITests/RestockUITests.swift
- blob:fc25d681ae1dc0c9e1189227f57dc320111fa3f3  SmartCart/Views/Store/StoreShareSheet.swift
- blob:18b7be78614999f48122a9b5328fd0a140a9ddf2  docs/specs/ui-tests/test-131-join-test-testdaten.md

## Geprüfte Dateien

- sha256:2d63afb053c3b3edeb885e28f725f96c1befd2fb509e918ec68f00bfc413e6d8  RestockUITests/AddItemQuantitySuggestionUITests.swift
- sha256:d4dbd71dd38e81e302fd589055860c46e75976befb884a556138fa166c8e29af  RestockUITests/ReceiptReviewUITests.swift
- sha256:1ba248906853f00fbb58269813ee0405f0c3f591d27728ef790efdca4358cf3d  RestockUITests/RestockUITests.swift
- sha256:a21dcbaf7b7c39ac7d37f05f4a768985422f05f469a5eb901c5aba6c1035bcce  SmartCart/Views/Store/StoreShareSheet.swift
- sha256:01ad1be999a2f1ff81eecec6146186a1ca7a929ef80948bb73af262782cdc992  docs/specs/ui-tests/test-131-join-test-testdaten.md

## Prüfbasis

- base: 798cb609010f7f33cff0b27cd1f2f55699317b39
- blob:b727a5b4d23ec8b764f4bbb29645b1627a31a9ad  RestockUITests/AddItemQuantitySuggestionUITests.swift
- blob:9a7d2c054a6dea9d227ab1f7de63f1678221d3b9  RestockUITests/ReceiptReviewUITests.swift
- blob:fc716faf9cb81a734be5416128c87933719b4b48  RestockUITests/RestockUITests.swift
- blob:fc25d681ae1dc0c9e1189227f57dc320111fa3f3  SmartCart/Views/Store/StoreShareSheet.swift
- blob:18b7be78614999f48122a9b5328fd0a140a9ddf2  docs/specs/ui-tests/test-131-join-test-testdaten.md
