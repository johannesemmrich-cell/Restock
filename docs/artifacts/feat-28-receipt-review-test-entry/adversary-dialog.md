# Adversary-Dialog — feat-28-receipt-review-test-entry (Issue #28)

- **Workflow:** `feat-28-receipt-review-test-entry`
- **Spec:** `docs/specs/testing/receipt-review-test-entry.md`
- **Datum:** 2026-09-22
- **Prüfer:** `implementation-validator` (liest nur Spec und Beweismittel, nicht den Entwicklerbericht)
- **Runden:** 2
- **Finales Verdict:** **VERIFIED**

---

## Checkliste (aus `adversary_dialog.py parse`)

- [x] **Punkt 1 — Input:** Startargumente `-hasCompletedOnboarding YES -seedReceiptReviewForUITests`.
  Status: CONFIRMED — `ReceiptReviewUITests.swift:31` trifft den Guard-String in
  `SmartCartApp.swift:194` exakt.
- [x] **Punkt 2 — Output:** App startet direkt, Seed legt Laden und Bon-Nutzlast zur
  `ModelContainer`-Zeit an. Status: CONFIRMED — Aufruf im `init`-`defer` (`SmartCartApp.swift:29-30`),
  also vor dem ersten Rendern; zur Laufzeit durch die erscheinende Navigationsleiste belegt.
- [x] **Punkt 3 — Side effect:** vorhandene `Store`s werden gelöscht. Status: CONFIRMED per
  Code-Lesung (`SmartCartApp.swift:200-202`, Cascade-Regel `Store.swift:42`); kein Test belegt es —
  Restlücke offen dokumentiert als Issue #33.
- [x] **AC-1:** Bon-Prüf-Screen öffnet sich selbsttätig mit Titel „Bon scannen — Lidl".
  Status: CONFIRMED — Code plus grüner Testlauf.
- [x] **AC-2:** alle vier Zeilen über `receiptReview.line.<i>.nameField` und `.priceField`
  auffindbar. Status: CONFIRMED — acht Feldprüfungen grün.
- [x] **AC-3:** `receiptReview.line.0.aiMark` sichtbar. Status: CONFIRMED —
  `ReceiptScannerView.swift:721` gated auf `resolvedByAI`, Zeile 0 nachweislich stabil `true`.
- [x] **AC-4:** `receiptReview.saveButton` ist `isHittable`. Status: CONFIRMED —
  `storeConfidentlyDetected: true` → `storeNeedsConfirmation == false` → `canSave` erfüllt.
- [x] **AC-5:** Fixture bleibt bei `reResolveAIIfNeeded()` unverändert. Status: CONFIRMED per
  Code-Lesung — `linesNeedingAIReresolution` liefert für alle vier Zeilen leer, `guard` greift.
- [x] **AC-6:** bestehende Suite ohne Startargument grün. Status: CONFIRMED im engeren,
  gemeinten Sinn — der Seed wirkt ohne Argument nicht; die Alt-Flakiness besteht mit und ohne #28
  identisch und ist als Issue #32 ausgelagert.
- [x] **AC-7:** `XCTExpectFailure(strict: true)` greift tatsächlich. Status: CONFIRMED — in allen
  fünf gehärteten Läufen ausgelöst, Test bestanden (kein Leerlauf-Pass).

---

### Runde 1 — Befunde

Der Prüfer hat den gespeicherten Belegen **nicht** vertraut und drei eigene Läufe gefahren
(`id=C809766B-5B9C-41A9-B1B7-F66B1C3EB162`, nie parallel, Issue #21):

| Lauf | Ziel | Ergebnis | Artefakt |
|------|------|----------|----------|
| 1 | `ReceiptReviewUITests` | **1 von 2 FEHLGESCHLAGEN** | `adversary-verify-run.txt` |
| 2 | `ReceiptReviewUITests` (Wiederholung) | 2/2 grün | `adversary-verify-run2.txt` |
| 3 | `RestockUITests` (Negativkontrolle) | **3 von 4 FEHLGESCHLAGEN** | `adversary-negative-control-run.txt` |

Damit war belegt, was ein Einzellauf verdeckt hatte.

### F001 — MEDIUM — Flake im neuen Test

`waitForExistence(timeout: 10)` auf die Navigationsleiste reicht nach kaltem App-Install nicht.
Im Fehlschlag brauchte „Set Up" bis App-Idle allein ~9,5 s; die 10-s-Frist lief bei t=19,98 s ab,
Sheet nicht da. Betroffen: `ReceiptReviewUITests.swift:44` und `:78`.

**Gewicht:** Trifft den Kern der Spec. Ein Testeinstieg, der 1 von 3 Mal versagt, ist nicht der
geforderte deterministische Einstieg.

### F002 — MEDIUM — Alt-Flake in der Bestandssuite (nicht von #28)

`RestockUITests.swift:73` und `:111` rufen `codeField.tap()` und direkt danach `typeText(...)`,
ohne auf `hasKeyboardFocus == true` zu warten — obwohl dieselbe Datei das Muster an Z. 183–185
bereits defensiv anwendet. Fehlerbilder: „Neither element nor any descendant has keyboard focus"
sowie ein `isHittable`-Timeout.

### F003 — LOW — AC-5-Belegangabe überzogen

Die Spec nannte `testReviewSheetOpensFromShareHandoff` als Beleg „implizit über die stabilen, per
Namen erwarteten Werte". Der Test liest jedoch nie `XCUIElement.value`, nur `exists` /
`waitForExistence` — er könnte eine Wertänderung gar nicht bemerken.

### F004 — MEDIUM — Aufräumen der Bestands-Stores ungeprüft

`SmartCartApp.swift:198-202` löscht alle `Store`s, aber kein Test belegt das, und `try?`
verschluckt einen Fehlschlag still.

**Verdict Runde 1: AMBIGUOUS**

---

## Reaktion des Orchestrators

Statt das AMBIGUOUS mit `override-ambiguous` durchzuwinken, wurden die Befunde bearbeitet:

| Befund | Maßnahme |
|--------|----------|
| F001 | Behoben — Developer Agent beauftragt (Orchestrator schreibt keinen Code) |
| F002 | GitHub-Issue **#32** angelegt, mit allen drei Prüfer-Artefakten als Beleg |
| F003 | Spec-Belegangabe wahrheitsgemäß gefasst |
| F004 | GitHub-Issue **#33** angelegt |

### Behebung von F001

`RestockUITests/ReceiptReviewUITests.swift` (+21 / −2):
- Neue Hilfsfunktion `waitUntilSettled(_:)` — `expectation(for:evaluatedWith:)` auf
  `state == runningForeground`, `waitForExpectations(timeout: 20)`, nach dem Vorbild der
  `hasKeyboardFocus`-Wartestelle in `RestockUITests.swift:183-185`
- Aufruf nach `launchedApp()` an Z. 60 und Z. 95
- Navigationsleisten-Timeout an Z. 62 und Z. 97 von 10 auf 20 s
- **Keine Semantikänderung** — `XCTExpectFailure(..., strict: true)` unangetastet

Nachweis: drei aufeinanderfolgende Läufe, jeder nach `simctl erase`, immer nur einer gleichzeitig.

| Lauf | Ergebnis | Dauer | Artefakt |
|------|----------|-------|----------|
| 1 (kalter Install) | 2/2, TEST SUCCEEDED | 38,2 s | `test-green-hardened-run1.txt` |
| 2 | 2/2, TEST SUCCEEDED | 36,2 s | `test-green-hardened-run2.txt` |
| 3 | 2/2, TEST SUCCEEDED | 31,7 s | `test-green-hardened-run3.txt` |

In Lauf 1 brauchte Start bis App-Idle 14,9 s — genau das Fenster, das vorher die 10-s-Frist
aufzehrte.

---

### Runde 2 — Nachprüfung

Der Prüfer erhielt fünf gezielte Fragen, darunter die kritischste: ob die Härtung nicht heimlich
eine echte Prüfung verwässert hat.

**1. Wurde nur Robustheit geändert?** Diff Zeile für Zeile geprüft. Gleiche vier Feld-Identifier,
gleiche `aiMark`-Disjunktion, gleiches `saveButton.isHittable`, gleiches `XCTExpectFailure(...,
strict: true)`. Keine Assertion abgeschwächt, kein Element ausgetauscht, keine Prüfung stillgelegt.

**2. Misst `waitUntilSettled` das Richtige?** Teilweise. `state == runningForeground` ist ein
Prozess-Lifecycle-Flag, nicht „UI fertig gezeichnet". Der tragende Teil der Reparatur ist die
Verdopplung des Timeouts; die Hilfsfunktion ist Zugabe, keine Verwässerung. Der Doc-Kommentar
überzeichnet ihre Wirkung leicht — LOW, nicht blockierend.

**3. Reichen 3/3?** Dem Prüfer nicht als Vertrauensvorschuss. Er fuhr zwei weitere eigene Läufe:

| Lauf | Bedingung | Vorlaufzeit | Ergebnis | Artefakt |
|------|-----------|-------------|----------|----------|
| 4 | nach eigenem `simctl erase` | 11,43 s / 8,50 s | 2/2 grün | `adversary-round2-erased-run1.txt` |
| 5 | warmer Simulator | **20,42 s** / 8,38 s | 2/2 grün | `adversary-round2-warm-run2.txt` |

Lauf 5 ist der aussagekräftigste: 20,42 s Vorlauf hätte mit der alten 10-s-Frist **sicher** erneut
zum Fehlschlag geführt.

**Gesamtbilanz:** 5 unabhängige gehärtete Läufe, **10/10 Einzeltests grün**, beobachtete
Vorlaufzeiten 8,4 s bis 20,4 s — die volle Bandbreite, die vorher zum Fehlschlag führte, ist
abgedeckt.

**4. Ist die AC-5-Belegangabe jetzt wahrheitsgemäß?** Ja. Der Given/When/Then-Kern ist unverändert;
neu ist allein der Nachweis-Satz, der offen festhält, dass die UI-Tests AC-5 **nicht** belegen.
Die Schwäche wurde benannt, nicht umformuliert.

**5. Drückt sich #28 bei F002?** Nein. `RestockUITests.swift` ist im Diff nicht enthalten, die
Ursache bestand vorher, und eine Reparatur hätte die Scoping-Grenzen aus CLAUDE.md verletzt.
Saubere Scope-Disziplin, sauber ausgelagert.

### AC-6 neu bewertet

Die Flakiness der Altsuite besteht mit und ohne #28 identisch. AC-6 behauptet, der Seed habe ohne
Startargument keine Wirkung — das ist erfüllt. Die allgemeine Robustheit der Altsuite ist als
Issue #32 ausgelagert.

---

## Verdict: VERIFIED

VERDICT: VERIFIED

- 10/10 Checklistenpunkte bewiesen
- Keine Regression, kein abgeschwächter Test, kein verstecktes Scope-Creep
- Zwei Restlücken offen dokumentiert und als Issues #32 und #33 erfasst

## Beweismittel

| Datei | Inhalt |
|-------|--------|
| `test-red-output.txt` | RED-Lauf vor der Implementierung, 2 Fehlschläge |
| `test-green-output.txt` | erster GREEN-Lauf, 2/2 |
| `test-green-negative-control.txt` | Negativkontrolle AC-6, 4/4 |
| `test-green-negative-control-retry.txt` | isolierter Nachlauf des wackeligen Alttests |
| `adversary-verify-run.txt` | Prüferlauf 1 — **1/2 fehlgeschlagen**, deckte F001 auf |
| `adversary-verify-run2.txt` | Prüferlauf 2 — 2/2 |
| `adversary-negative-control-run.txt` | Prüferlauf 3 — **3/4 fehlgeschlagen**, deckte F002 auf |
| `test-green-hardened-run1.txt` … `run3.txt` | drei Läufe nach Härtung, je 2/2 |
| `adversary-round2-erased-run1.txt` | Prüfer-Nachlauf nach `simctl erase`, 2/2 |
| `adversary-round2-warm-run2.txt` | Prüfer-Nachlauf warm, 20,4 s Vorlauf, 2/2 |
