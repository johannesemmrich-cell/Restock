# Adversary Dialog

Workflow: fix-269-asc-check-appinfo-rejected. Tests: `python3 scripts/test_asc_check.py` -> Ran 71 tests, OK (0 failed, 0 skipped).

## Checkliste
- [x] **AC-1:** Version REJECTED, appInfos READY_FOR_DISTRIBUTION + REJECTED -> metadata/appinfo laufen, lesen Unterpfade der REJECTED-appInfo.
- [x] **AC-2:** Version REJECTED, zwei REJECTED-appInfos -> Abbruch mit allen Zustaenden.
- [x] **AC-3:** Version REJECTED, appInfos LIVE + WAITING -> Abbruch.
- [x] **AC-4:** Version nicht REJECTED, appInfos READY_FOR_DISTRIBUTION + REJECTED -> Abbruch.
- [x] **AC-5:** Entwurf-appInfo (b) hat Vorrang vor (c).

## Dialog

### Runde 1
**Adversary:** Testsuite laufen lassen; Regel c lesen. Ist Regel c nur bei Version REJECTED aktiv? Aendern sich (a)/(b)/Abbruchmeldung?
**Implementierer:** Beweis: 71 Tests gruen. Diff zeigt nur eine neue Liste `rejected` und eine dritte Alternative in `pick`, hinter (a) und (b); Abbruchmeldung unveraendert.
Code reference: scripts/asc_check.py:175

**Adversary:** Testabdeckung je AC? Der Testaufbau (MultiASC) hat Kategorie-/Altersrouten ergaenzt, damit `appinfo` laeuft - faelscht das etwas?
**Implementierer:** AC-1 Test prueft Pfade INFO-2 gelesen, INFO-1 nicht (primaryCategory/appInfoLocalizations); AC-2..AC-5 haben eigene Tests, AC-4 ist der umgestellte Bestandstest. Zusaetzliche Routen betreffen nur den Fake.
Code reference: scripts/test_asc_check.py:807

### Runde 2
**Adversary:** Ad-hoc-Randfaelle (Probe-Skript, nur GET): Version "rejected" klein -> Abbruch (strikt, fail-safe). Version " REJECTED " -> clean() trimmt, laeuft. appInfo-state "rejected" klein -> Abbruch. appInfo ohne state (A) + REJECTED (B) -> B gewaehlt (korrekt, "unbekannt" != REJECTED). Beide ohne state -> Abbruch. Version ohne state -> Abbruch. Fallback appStoreState -> funktioniert. Drei appInfos mit genau einem REJECTED -> gewaehlt; mit zwei REJECTED -> Abbruch; REJECTED+REJECTED+PREPARE -> Entwurf gewaehlt (b vor c). Nur GET-Aufrufe in allen Faellen.
**Implementierer:** Alle Ergebnisse stimmen mit Spec ("nie raten"); die Gross-/Kleinschreibung ist strikt wie bei DRAFT, kein Regress. Andere Abschnitte nutzen info_id nicht (nur Zeilen 202 und 240: metadata, appinfo).
Code reference: scripts/asc_check.py:185

**Adversary:** Spec-Changelog vorhanden?
**Implementierer:** Ja, Abschnitt "## Changelog" mit Verweis auf die Fortschreibung, Haupttext unveraendert.
Code reference: docs/specs/appstore/asc-check-version.md:111

## Findings
Keine.

## Confirmations
Confirmation: AC-1, Code reference: scripts/asc_check.py:185, Evidence: rejected-Zweig mit version_state == REJECTED, Test AC-1 gruen. Status: CONFIRMED
Confirmation: AC-2, Code reference: scripts/test_asc_check.py:816, Evidence: len(rejected) == 1 erforderlich, Abbruch mit Zustaenden. Status: CONFIRMED
Confirmation: AC-3, Code reference: scripts/test_asc_check.py:824, Evidence: ohne REJECTED pick=None, Abbruch. Status: CONFIRMED
Confirmation: AC-4, Code reference: scripts/test_asc_check.py:799, Evidence: Version READY_FOR_SALE -> Regel c inaktiv, Abbruch. Status: CONFIRMED
Confirmation: AC-5, Code reference: scripts/test_asc_check.py:831, Evidence: (b) steht vor (c) in der Konditionalkette; Probe mit 3 appInfos bestaetigt. Status: CONFIRMED

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED

Tests: 71 passed, 0 failed, 0 uebersprungen. Edge cases: alle geprueft, keine gebrochen. Regressions: keine. Checklist: 5/5.

## Geprüfte Dateien

- sha256:dfdcce7d2a2898e1ab084bb8ae1cd1dc146b28f9b4c6cce8033bb7acd1f41091  docs/specs/appstore/asc-check-version.md
- sha256:579effe1282885462428ee4e44c2429ec927f55e337a97ad9c045f49817d46d3  scripts/asc_check.py
- sha256:f4ca9f50bd47a84c5b2fe77f9ea0f02107a7781e217f005c53f7781d287c835a  scripts/test_asc_check.py

## Prüfbasis

- base: 5b9c62efea8241d883cd19a2f4c27036757aba77
- blob:ae8bb38d44b5af0ed7730ec0b0d1add3edf9b621  docs/specs/appstore/asc-check-version.md
- blob:6dae4350a8f26dfed854be3cc731637967f26ae7  scripts/asc_check.py
- blob:7b11219d7d9392c789af3ae4db8106c7d4691432  scripts/test_asc_check.py
