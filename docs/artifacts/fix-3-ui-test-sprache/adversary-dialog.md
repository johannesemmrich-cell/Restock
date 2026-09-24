# Adversary-Dialog: fix-3-ui-test-sprache (Issue #3)

- **Spec:** docs/specs/testing/ui-test-language.md
- **Datum:** 2026-09-21
- **Prüfer:** implementation-validator (liest Spec + vorgelegte Belege, kein Gesprächskontext)
- **Orchestrator:** Hauptkontext (relayt Belege, schreibt keinen Code)
- **Beweismittel:** scripts/verify-ui-test-language.sh (unverändert seit RED), test-green-output.txt (EXIT=0),
  green-run-default-language.txt, green-run-negative-control-en.txt, RED-Belege verify-red.txt /
  run-default-language.txt / run-negative-control-en.txt, `git diff` der drei geänderten Dateien

## Checkliste (aus der Spec geparst, 8 Punkte)

- [x] 1. Input — CI-Aufruf `xcodebuild test -scheme Restock … -only-testing:RestockUITests` unverändert, ohne `-testLanguage`/`-testRegion`. Beleg: `.github/workflows/ci.yml:99-149`; `git diff -- .github/workflows/ci.yml scripts/run-share-extension-uitest.sh` leer.
- [x] 2. Output — Ergebnis wechselt von `… 3 failures` auf `… 0 failures`. Beleg: `test-green-output.txt:4-5` (`Gerätesprache: (en)`, `Executed 5 tests, with 1 test skipped and 0 failures`).
- [x] 3. Side effects — Scheme-Attribute `language="de"`/`region="DE"` nur im `<TestAction>`-Block (Restock.xcscheme Z. 68–109); `LaunchAction`/`ProfileAction`/`ArchiveAction` unverändert (grep). Cmd+U und `run-share-extension-uitest.sh` erben die Scheme-Einstellung — indirekter Beleg (Scheme-Diff + `xcodebuild -help` zu `-testLanguage`/`-testRegion`), kein Blocker.
- [x] 4. AC-1 — CI-Job `ui-test` meldet 0 Fehlschläge. Status: lokal maximal abgesichert (identischer xcodebuild-Aufruf wie ci.yml, englisch eingestellter Simulator, 0 Fehlschläge). Der echte CI-Lauf setzt Commit + Push voraus; der Commit-Hook blockiert Commits vor dem Adversary-Verdict. **Nachweispflicht in Phase 7 (/60-validate, PR): grüner CI-Lauf mit `Executed 5 tests, with 1 test skipped and 0 failures`.**
- [x] 5. AC-2 — Frisch geleerter Simulator, ohne Sprachschalter → 0 Fehlschläge. Beleg: `green-run-default-language.txt`, Summary-Zeile; Gerätesprache-Vorbedingung `(en)` im selben Lauf bestätigt.
- [x] 6. AC-3 — Mit `-testLanguage en -testRegion US` exakt die drei ursprünglichen Fehlschläge. Beleg: `green-run-negative-control-en.txt`, `Test Case … failed` für `testAddStoreAndQuickAddItemShowsPriceWithoutCrash`, `testJoinSharedListSheetIsScrollableAndUsable`, `testJoinWithLegacySixCharacterCodeTriggersLookup`; erster Test scheitert am ersten Schritt (`RestockUITests.swift:137`, `'Läden einrichten'-Button … nicht gefunden`).
- [x] 7. AC-4 — Warten auf Tastaturfokus vor `typeText`. Beleg: `RestockUITests.swift:180-186`; GREEN-Protokoll ohne `Neither element nor any descendant has keyboard focus`; Timing `green-run-default-language.txt:236` (t=72.64 s Prädikat geprüft) → `:238` (t=73.00 s `Type 'Testartikel'`), 0,36 s tatsächliche Wartezeit gegenüber 10 s Limit — Timeout ist Reserve.
- [x] 8. AC-5 — Teilen-Knopf über `identifier == 'person.2'`. Beleg: `RestockUITests.swift:199` (exaktes `==`, nicht `CONTAINS`); `SmartCart/…/StoreDetailView.swift:304` einzige Fundstelle mit reinem `"person.2"` (kollisionsfrei); GREEN-Lauf: Knopf gefunden, `Code generieren` erschien.

## Dialog

### Runde 1

**Prüfer:** Verifiziert alle vorgelegten Belege selbst per grep/git. 6 von 8 Punkten akzeptiert (Input, Output, AC-2, AC-3, AC-4, AC-5); Side effects teilweise (Launch/Archive unberührt belegt, Cmd+U/Share-Skript nur indirekt). Zwei offene Punkte:

1. **AC-1 — NACHFRAGE:** Kein CI-Lauf für den aktuellen Arbeitsstand vorhanden (`git log origin/… -1` zeigt älteren Commit; letzte `gh run list`-Einträge gehören zu anderen PRs). Fordert echten grünen CI-Lauf.
2. **F001 — FINDING (MEDIUM, spec_violation):** Der Diff enthält eine vierte, in der Spec nicht dokumentierte Änderung: `app.swipeDown()` ersetzt durch Warten auf „Bearbeiten"-Button + koordinatenbasiertes Drag von der Sheet-Titelzeile, plus `isHittable`-Wait vor `lidlTile.tap()` (RestockUITests.swift:155-164, 172-175). Spec listet nur (a) Fokus-Wait, (b) identifier-Suche, (c) Kopfkommentar; Estimated Changes +18/−4 vs. tatsächlich +30/−2 in der Swift-Datei. Remediation: Spec um (d) ergänzen inkl. Begründung und korrigierter LoC-Schätzung.

**Vorläufiges Verdict Runde 1:** AMBIGUOUS.

**Orchestrator:** Beauftragt den Developer Agent, die Spec um Punkt (d) zu ergänzen (Affected Files, Implementation Details 3d mit Ursache/Beleg/Begründung, Estimated Changes). PO-Briefing wird anschließend neu gebunden. Zu AC-1: Commit ist vor dem Verdict durch den Workflow-Hook blockiert; CI-Nachweis wird in Phase 7 erhoben.

### Runde 2

**Orchestrator legt vor:** Spec-Diff (`git diff docs/specs/testing/ui-test-language.md`) mit Punkt (d), Code-Block 3d, Absatz „Zu 3d — Ergänzung nach dem GREEN-Lauf", Estimated Changes +35/−5 über 3 Dateien. Erklärung zu AC-1 (Prozess-Reihenfolge). Zusatzfrage: Timeout 3→10 s — stimmen Spec und Code überein, und ist belegbar, dass der Fokus weit vor 10 s kam?

**Prüfer:**

- **F001 — RESOLVED.** Spec-Text 3d wortgleich mit Code (`RestockUITests.swift:161-164, 174-175`: editButton-Wait 5 s, `press(forDuration: 0.2, thenDragTo:)` von (0.5, 0.15) nach (0.5, 0.95), `isHittable == true` 5 s vor `lidlTile.tap()`). `git diff --numstat` bestätigt Scheme +3/−1, RestockUITests.swift +30/−2 — deckt sich mit der Spec-Angabe. Ursache, RED-Unsichtbarkeit und Beleg dokumentiert.
- **AC-1 — AMBIGUOUS-mit-Bedingung, nicht blockierend.** CI-Nachweis vor Commit technisch unmöglich, nicht unterlassen. Spec weist AC-1 der CI zu; Nachweis-Skript ruft denselben Befehl wie `ci.yml:99-149` auf. Nachweispflicht: grüner CI-Lauf in der Folgephase, bevor der Fix als endgültig gilt.
- **Timeout 3→10 s — geprüft.** Spec Z. 72 und Z. 111 stimmen mit `RestockUITests.swift:186` überein. `green-run-default-language.txt:236` (t=72.64 s) → `:238` (t=73.00 s): 0,36 s tatsächliche Wartezeit. Reserve, keine Verschleierung.

**Endstatus:** 8/8 Punkte geklärt — 7 AKZEPTIERT, AC-1 mit expliziter, prozessbedingter Nachweispflicht in Phase 7.

## Findings

- **F001** — spec_violation, MEDIUM — undokumentierte Änderung (d) in RestockUITests.swift. **RESOLVED in Runde 2** (Spec ergänzt, Code und Spec-Text stimmen überein).

Keine weiteren offenen Findings.

## Verdict
**VERIFIED**

Die Implementierung hält der Adversary-Prüfung stand. Tests: lokale Nachweis-Läufe ausgewertet (0 Fehlschläge im Standardlauf auf englisch eingestelltem Simulator; exakt 3 erwartete Fehlschläge in der Negativkontrolle). Edge cases: Timeout-Erhöhung als Reserve belegt, Scheme-Änderung auf TestAction begrenzt, identifier-Selektor kollisionsfrei. Regressions: keine Produktcode-Änderung, keine Dateien außerhalb des dokumentierten Scope.

**Auflage für Phase 7:** Der echte grüne CI-Lauf (`Executed 5 tests, with 1 test skipped and 0 failures`) ist als Beleg für AC-1 nachzureichen.
