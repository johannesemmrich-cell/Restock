# Context: fix-136-ui-job-teilen

## Request Summary
Issue #136: Der UI-Job der CI (`ui-test` in `.github/workflows/ci.yml`, `timeout-minutes: 60`) liegt nahe am Limit. Ziel: zuverlässig bestehen mit Abstand zum Limit. DoD: Messung der Verteilung, Entscheidung mit Beleg, mehrere Läufe mit Abstand zum Limit. PO-Entscheidung (2026-10-11): UI-Suite in zwei parallele Jobs teilen.

## Messung (Läufe 7.–11.10.2026, Repo `johannesemmrich-cell/Restock`)

| Lauf | Schritte vor dem Test | Testschritt | Job gesamt | Ausgang |
|------|----------------------|-------------|-----------|---------|
| PR #135, Versuch 1 (38118833841/1) | 8 min (Sim-Wahl 68 s, Boot 5,4 min, Rechte 68 s) | 52,5 min (Tests selbst 2634 s, fertig nach ca. 44 min, danach 32 s `xcodebuild`-Abschluss) | 61 min | **abgebrochen durch Limit** |
| PR #135, Versuch 2 (…/2) | 3,3 min | 36,5 min (Tests 1824 s, Bau ca. 5 min) | 40 min | grün |
| main 10.10. (38070208517) | 3,5 min | 42,2 min | 45,8 min | grün |
| main 9.10. (37992232937) | 4 min | 45 min | 49 min | grün |
| main 11.10. (38124627966) | 2,5 min | 48,5 min | 52 min | **rot durch Testfehler** (`testChangeStoreMovesItemAndRemembersCorrection`, Toast), nicht durch Limit |

- Reine Testzeit schwankt 1824 s bis 2634 s (Faktor 1,44) bei gleichem Code. Boot schwankt 1,5 bis 5,4 min.
- Das Ticket nennt `testSwitchingSortModesReordersList` mit 134 s; im grünen Versuch 2 waren es 62 s. Es gibt keinen dominanten Einzeltest: die zwölf langsamsten liegen bei 36–62 s, Mittel ca. 30 s.

## Testzeit je Klasse (grüner Versuch 2, Sekunden / Tests)
ReceiptReviewUITests 445 / 22 · QuickAddAssignmentUITests 303 / 13 · ReplenishmentUITests 229 / 10 · ShoppingRouteUITests 229 / 6 · AddItemQuantitySuggestionUITests 172 / 6 · ReceiptResolutionStatsUITests 149 / 4 · RestockUITests 117 / 5 · ShoppingRouteLearningUITests 92 / 2 · DataResetUITests 66 / 2 · LegacyLearnedPriceResetUITests 16 / 1 (Summe ca. 1818 s von 1824 s; `ReceiptShareExtensionTests` ist übersprungen).

Möglicher Schnitt (grüner Lauf): Gruppe A = ReceiptReviewUITests + ShoppingRouteUITests + AddItemQuantitySuggestionUITests + ReceiptResolutionStatsUITests ≈ 995 s; Gruppe B = alles übrige ≈ 822 s. Proportional im langsamen Lauf: A ≈ 1440 s, B ≈ 1190 s, plus je 5 min Bau und 3–8 min Start.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/ci.yml` | Job `ui-test` (Zeilen 86 ff.), `-only-testing:RestockUITests`, `timeout-minutes: 60`; einzige zu ändernde Datei |
| `.github/workflows/testflight.yml` | enthält keinen Bezug auf `ui-test`/CI (`needs`, `workflow_run`: keine Treffer) |
| `CLAUDE.md` | Abschnitt Build/Tests; erwähnt `xcodebuild test`, ggf. Zusatz zur Aufteilung |
| `RestockUITests/*.swift` | 11 Dateien, werden nicht geändert |

## Existing Patterns
- Kommentar über dem Limit in `ci.yml` begründet den Wert mit der Testzeit (zuletzt 40 → 60 min).
- Jeder UI-Job läuft auf eigenem Runner mit eigenem Simulator: kein gemeinsamer App-Group-Container, die Aufräum-Regel für gesäte Tests (`tearDown`) bleibt je Job gültig.
- Das Schema `-only-testing:` / `-skip-testing:` ist `xcodebuild`-Standard. Variante, die Drift verhindert: Job A mit `-only-testing:RestockUITests/<Klasse>` je Klasse der Gruppe A, Job B mit `-only-testing:RestockUITests` plus `-skip-testing:RestockUITests/<Klasse>` für dieselben Klassen. Neue Klassen landen automatisch in B und gehen nie verloren.

## Dependencies / Dependents
- Upstream: `macos-26`-Runner, `xcodebuild`, Simulator-Wahl per `simctl`.
- Downstream: Die geschützte Prüfregel am Jobnamen fehlt: `branch protection` und `rulesets` der API liefern 404 bzw. `[]`. Der Name `ui-test` ist in keinem Skript und keiner Datei außer Artefakt-Doku (`docs/artifacts/fix-111-toast-dauer/messlauf-zusammenfassung.md`) referenziert. Bei Umbenennung ist nichts zu migrieren.
- PRs werden laut CLAUDE.md eigenständig nach grüner CI gemergt: Es zählt, dass beide Teile grün sind. Ein Ausfall eines Teils muss den PR rot halten (Standardverhalten bei zwei Jobs).

## Existing Specs
- `docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md`, `test-105-128-durchgang-1-start-helfer.md` (Muster für CI/UI-Testspecs).

## Risks & Considerations
- **Vollständigkeit der Aufteilung:** Beide Hälften zusammen müssen alle 84 Tests ausführen (Nachweis: Summe der `Executed … tests` beider Jobs = 84, davon 1 übersprungen).
- **Doppelte Startrisiken:** Zwei Jobs heißen zwei Boot-/Sim-Wahl-Phasen. Jede Hälfte hat dann ca. 20 Minuten Abstand zu 60; ein Einzelausreißer wie der 8-Minuten-Start passt hinein.
- **Mehr Runner-Minuten:** doppelter Bau (je ca. 5 min) und doppelter Start; Kosten und Warteschlange (Hinweis „capacity constraints, macOS arm64“ in den Annotations) steigen. Zwei Jobs warten ggf. getrennt in der Schlange.
- **Diagnosezeit nach Tests:** `xcodebuild` braucht nach dem letzten Test noch 30–60 s (siehe #21); das Limit wird nicht angetastet.
- **Messung:** Ein Einzellauf beweist keine Stabilität (siehe Memory „Ein Einzellauf beweist keine Stabilität“): mehrere Läufe vorlegen, mit Zeiten je Schritt.
- **Abgrenzung:** Der Testfehler `testChangeStoreMovesItemAndRemembersCorrection` aus dem main-Lauf gehört zu #118 und ist nicht Teil von #136.
- **Alternativen (zur Entscheidung in /20-analyse):** (a) nur Limit auf 90 anheben, (b) Aufteilung in drei Jobs, falls zwei nicht reichen, (c) einmal `build-for-testing`, danach `test-without-building` in zwei Jobs (spart Doppelbau, braucht Artefaktübergabe).

## Analysis

### Type
Bug (CI-Konfiguration): Job bricht trotz 84 grüner Tests am Zeitlimit ab. Hat es bisher funktioniert? Ja, bis die Suite mit den Schnell-Eingabe-Tests auf ca. 30–44 min Testzeit wuchs; Läufe 40–55 min, ein Ausreißer 61 min (8 min Start + 44 min Tests + Abschluss). Ursache belegt aus den Logs (Tabelle oben): Summe aus Start, Bau und Testzeit, nicht ein einzelner Test (die zwölf langsamsten 36–62 s).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/ci.yml` | MODIFY | Job `ui-test` als Matrix mit zwei Hälften (A: vier schwere Klassen per `-only-testing`; B: `-only-testing:RestockUITests` plus `-skip-testing` derselben Klassen); `fail-fast: false`; Artefaktname je Hälfte; Limit-Kommentar anpassen |
| `CLAUDE.md` | MODIFY | Ein Absatz im Testabschnitt: UI-Suite läuft in zwei Hälften, neue Klassen landen automatisch in B |

### Scope Assessment
- Files: 2
- Estimated LoC: +30/-8
- Risk Level: LOW (nur CI, kein Produktcode; Fehlerbild ist sichtbar rot)

### Technical Approach
Empfehlung: **eine Matrix-Definition mit zwei Einträgen** statt zwei kopierter Jobs. Gruppe A = ReceiptReviewUITests, ShoppingRouteUITests, AddItemQuantitySuggestionUITests, ReceiptResolutionStatsUITests (ca. 995 s im grünen, ca. 1440 s im langsamen Lauf). Gruppe B = alles übrige inkl. künftiger Klassen (ca. 822 s / 1190 s). Jede Hälfte kommt damit auf grob 25–40 min im schlechten Fall gegen 60 min Limit; Limit bleibt 60. Das `-skip-testing`-Muster verhindert Drift: eine neue Klasse geht nie verloren.

Nachweis (Definition of Done): mindestens drei volle CI-Läufe mit Zeiten je Schritt und Hälfte; Summe der `Executed … tests` beider Hälften = 84, davon 1 übersprungen; zusätzlich ein Lauf unter Last wie bei #105 (Memory).

### Alternativen (Tabelle)
| Alternative | Urteil | Welche Entscheidung kippt |
|-------------|--------|---------------------------|
| (a) Limit nur auf 90 anheben | Verworfen: Abstand wird nicht größer, die Suite wächst weiter, ein hängender Lauf blockiert 90 min | keine |
| (b) drei Jobs | Reserve: erst wenn zwei Hälften im Messlauf über ca. 45 min kommen; mehr Boot-/Bauanteil, längere Warteschlange | keine |
| (c) einmal `build-for-testing`, dann zwei Jobs mit `test-without-building` | Spart ca. 5 min Doppelbau, braucht Artefaktübergabe und eine Zusatzstufe; mehr Teile, die ausfallen können. Erst bauen, wenn die Matrix nicht reicht | keine |
| (d) Tests kürzen (Einzeltests mit ca. 60 s) | Kein dominanter Test, bringt wenig; eigenes Thema | keine |
Keine bestehende ADR wird gekippt.

### Dependencies
Keine Schutzregel am Jobnamen (Branch-Protection/Rulesets: 404 bzw. leer); `testflight.yml` ohne Bezug. Matrix-Jobs heißen `ui-test (A)`/`ui-test (B)`; nichts migriert. Beide Teile müssen grün sein, damit der PR grün ist (Standard bei Matrix).

### Open Questions
- [ ] Keine echte PO-Frage offen. Technisch zu belegen im Messlauf: Reichen zwei Hälften (Grenze 45 min je Hälfte, sonst Alternative b).
- Abgrenzung: Testfehler `testChangeStoreMovesItemAndRemembersCorrection` gehört zu #118, nicht zu #136.
