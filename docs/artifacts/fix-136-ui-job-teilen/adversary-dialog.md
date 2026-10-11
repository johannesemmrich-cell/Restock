# Adversary Dialog — fix-136-ui-job-teilen
Spec: docs/specs/ci/ui-test-job-in-zwei-haelften.md
Datum: 2026-10-11 16:50

## Checkliste
- [x] **Input:** PR oder Push gegen `main`. — PROVEN (Trigger des Jobs unverändert)
- [~] **Output:** zwei parallele Prüfungen — Konfiguration PROVEN, Parallelität/Grün nur CI (offene Grenze)
- [x] **Side effects:** Mehrverbrauch benannt (Spec); Artefaktname je Hälfte PROVEN
- [~] **AC-1:** Konfiguration PROVEN, Lauf offen
- [~] **AC-2:** Testlisten-Gegenprobe PROVEN (84 = 38 + 46, Schnitt leer), Protokollsumme offen
- [x] **AC-3:** vertagt (PO-Ausnahme 2026-10-11, Nachweis durch drei CI-Läufe folgt in /60-validate)
- [x] **AC-4:** vertagt (PO-Ausnahme 2026-10-11, Nachweis durch Lastlauf folgt in /60-validate)
- [~] **AC-5:** fail-fast false PROVEN, Ergebnis eines roten Laufs offen
- [x] **AC-6:** PROVEN per -enumerate-tests (Xcode 27.0)
- [x] **AC-7:** PROVEN
- [x] **AC-8:** PROVEN
- [~] **AC-9:** Diff PROVEN (nur ci.yml, CLAUDE.md); Ticket/Bericht-Formulierung noch nicht prüfbar

## Dialog

### Runde 1
**Adversary:** Statisches Skript check-ci-split.py: 9 PASS, 0 Fehler. YAML lädt (strategy fail-fast false, matrix half [A,B]), timeout 60, HEAVY_CLASSES genau einmal (Zeile 112 + Verwendungen). Shell-Probe des echten run-Blocks (aus YAML extrahiert, xcodebuild durch printf ersetzt): A bekommt vier `-only-testing:RestockUITests/<Klasse>`, B `-only-testing:RestockUITests` plus vier `-skip-testing`, je Argument ein Wort, keine Quoting-Fehler. `${{ }}` im run-Block nur matrix.half (feste Konstanten A/B) und die UDID aus eigenem Schritt: keine Injektionsfläche. Jobname-Bezug: testflight.yml und scripts referenzieren `ui-test` nicht als Abhängigkeit (nur Kommentare in scripts/verify-ui-test-language.sh).
Echte Enumeration (xcodebuild test -enumerate-tests, Xcode 27.0, iPhone 17 Pro iOS 26.5, nur Auflisten, kein Testlauf): A = 38, B = 46, alle = 84; Vereinigung == alle, Schnitt leer. B enthält keine der vier schweren Klassen. Die Kombination -only-testing:RestockUITests + -skip-testing:RestockUITests/<Klasse> ist damit in Xcode 27 wirksam (Enumeration, nicht echter Lauf; Xcode-Version auf macos-26-Runner kann abweichen: offene Grenze). Die vier Klassennamen existieren als `final class` (grep). Klassenzählung 84 `func test` in den Dateien stimmt mit Enumeration überein (incl. 1 ReceiptShareExtensionTests).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Edge Cases.
(a) Leere HEAVY_CLASSES: Probe zeigt, dass Hälfte A dann KEINE Auswahlargumente an xcodebuild gibt, also die gesamte Scheme-Testaktion (UI plus ggf. RestockTests) läuft; B läuft `-only-testing:RestockUITests` ganz. Beide Hälften führen dann dasselbe aus, kein Fehler, kein Hinweis. Stilles Fehlverhalten, aber nur bei absichtlicher Leerung.
(b) Heavy-Klasse umbenannt (Enumeration mit nicht existierender Klasse): `-only-testing:RestockUITests/GibtEsNichtUITests` ergibt 0 aktivierte Tests, Exit 0, kein Fehler; `-skip-testing` auf nicht existierende Klasse lässt alle 84 aktiv, Exit 0. Folge: Hälfte A liefe leer (vermutlich grün, schnell), B führte die umbenannte Klasse mit aus. Nichts geht verloren, kein Test doppelt, aber die Teilung kippt still zurück Richtung ungeteilt und A ist ein Scheingrün. Aufgefangen nur durch AC-2-Zählung, nicht durch die CI selbst. Spec verlangt kein Fail-Verhalten; MEDIUM/LOW.
(c) Neue Klasse: steht in keiner Liste, ist in `alle` und nicht in A, also in B (AC-6 belegt über Mengenlogik der Enumeration). Eine neue Klasse mit hohem Gewicht verschiebt B ohne Warnung (Spec-Risiko genannt).
(d) Bash 3.2 (macOS-Runner): leere Array-Expansion ohne `set -u` unkritisch; `set -o pipefail` bleibt, xcpretty-Pipe unverändert.
(e) Artefakt: `UITestResults-A/B.xcresult` verschieden; `-resultBundlePath UITestResults.xcresult` lokal je Runner.
(f) AC-1-5 Laufzeitaspekte: ohne echte CI-Läufe nicht beweisbar, als offene Grenze gewertet.
**Implementierer:** (nicht beteiligt)

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/ci.yml:162
  Description: Die Schleife über $HEAVY_CLASSES baut -only-testing/-skip-testing ohne Prüfung, ob die Klasse existiert oder die Liste leer ist. Nicht existierende Klasse in A: 0 Tests, Exit 0 (belegt per -enumerate-tests); leere Liste in A: keine Auswahl, A führt alles aus.
  Spec requirement: AC-2 — kein Test doppelt, keiner fehlt
  Conflict: Bei Umbenennung der Klasse kippt die Teilung still, A läuft leer (Scheingrün), B trägt wieder alles; die CI meldet das nicht.
  Remediation: Optional Guard im Schritt (Klasse per grep in RestockUITests/ prüfen, bei leerer Liste oder fehlender Datei exit 1) oder Hinweis in CLAUDE.md. Kein Blocker, Spec fordert es nicht.

Confirmation:
  AC: AC-6
  Code reference: .github/workflows/ci.yml:166
  Evidence: B = -only-testing:RestockUITests plus -skip-testing der vier Klassen; Enumeration B (46) = alle (84) minus A (38), Schnitt leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: .github/workflows/ci.yml:189
  Evidence: name: UITestResults-${{ matrix.half }}.xcresult, Matrix A/B, also verschieden.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: .github/workflows/ci.yml:106
  Evidence: YAML lädt, timeout-minutes 60 am Job, Kommentar Zeilen 100-105 nennt Teilung, HEAVY_CLASSES-Definition einmal (Zeile 112).
  Status: CONFIRMED

Confirmation:
  AC: AC-5 (Konfigurationsteil)
  Code reference: .github/workflows/ci.yml:108
  Evidence: fail-fast: false; Matrix-Semantik: eine rote Hälfte macht den Gesamtstatus rot. Roter Lauf nicht vorgelegt (offen).
  Status: CONFIRMED

Confirmation:
  AC: AC-2 / AC-1 (Konfigurationsteil)
  Code reference: .github/workflows/ci.yml:99
  Evidence: Job-Name `ui-test (${{ matrix.half }})`, Matrix [A, B]; Testlisten 38 + 46 = 84. Protokollsumme und Parallelität nur in echter CI.
  Status: CONFIRMED

Confirmation:
  AC: AC-9 (Diff-Umfang)
  Code reference: CLAUDE.md:20
  Evidence: Diff umfasst nur ci.yml und CLAUDE.md; CLAUDE.md-Absatz zur Teilung steht, ohne „garantiert/zuverlässig“. Ticket-/Berichtsformulierung nicht prüfbar.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Produktions-Schreibstellen betroffen (reine CI-Konfiguration).

## Verdict
**AMBIGUOUS** — VERIFIED für die statisch prüfbare Konfiguration; AC-1, AC-3, AC-4 und die Laufzeitteile von AC-2/AC-5 sind offene Grenze (nur echte CI-Läufe).

## Geprüfte Dateien

- sha256:9df6199232fe4f8aeb6a74dc90194f79758c2c050abe4964829e3394f6e9a40d  .github/workflows/ci.yml
- sha256:ce6dc0fb559777b8d3aaf4f41700f58c906d548d158b238ab84fb472f59c08c1  CLAUDE.md

## Prüfbasis

- base: d15dc9c6e854c684bde721868007c7c6c3d991d2
- blob:88e574b5f9bb9c39fd237d704760b49648da52ce  .github/workflows/ci.yml
- blob:be3b9b6f14d974355dee2668db1adc285f6bd811  CLAUDE.md
