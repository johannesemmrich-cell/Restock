# Adversary-Dialog: fix-229-asc-reihenfolge

Spec: `docs/specs/appstore/asc-publish-reihenfolge.md` · Prüfer: implementation-validator · Orchestrator: Hauptkontext · Risiko: hoch (zwei Runden)

## Checkliste

- AC-1: `--apply` mit leeren Sprachlisten, App-Angaben vor Produktseiten
- AC-2: gemischter Fall (PATCH + POST), gleiche Reihenfolge
- AC-3: Trockenlauf nennt App-Angaben zuerst und schreibt nichts
- AC-4: 409 an der Produktseite, zweiter Lauf schreibt nur den Rest
- AC-5: Bestandstests grün

## Dialog

### Runde 1

Tests selbst ausgeführt: `test_asc_scripts.py` 28 Tests OK, `test_asc_check.py` 42 Tests OK. Diff gelesen: in `build_plan` sind nur die beiden `plan_for`-Aufrufe vertauscht. Mutation im Scratchpad (alte `asc_publish.py` aus HEAD): genau die drei neuen Tests schlagen fehl, die übrigen 25 bleiben grün. Die Tests prüfen also die Reihenfolge und sind nicht zufällig grün; `assertIn` für beide Arten verhindert ein leeres Bestehen. Scope: nur `build_plan`, Tests und eine Changelog-Zeile in der Haupt-Spec; kein Schreibaufruf gegen Apple.

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-5
  Code reference: scripts/asc_publish.py:55
  Code reference: scripts/test_asc_scripts.py:177
  Status: CONFIRMED

### Runde 2

Nachgebohrt mit Kurzskript über `FakeASC` in fünf Konstellationen, je zwei Läufe: nur Info-Liste leer, nur Version-Liste leer, nur Version veraltet, nur Info veraltet, eine Sprache mit leeren Listen. Überall Exit 0, App-Angaben vor Produktseiten, nichts verloren oder doppelt, zweiter Lauf 0 Aufrufe. `FailsOnVersion` (`test_asc_scripts.py:195`) antwortet am ersten Produktseiten-Schreibaufruf mit 409, vor jeder Zustandsänderung; der Zustand von Lauf 1 bleibt in Lauf 2 erhalten. Scope bestätigt: `asc_lib`, `asc_check`, `plan_for` unverändert.

Confirmation:
  AC: AC-1 bis AC-5 und Randfälle
  Code reference: scripts/asc_publish.py:94
  Code reference: scripts/test_asc_scripts.py:189
  Code reference: scripts/test_asc_scripts.py:195
  Status: CONFIRMED

Restrisiko, keine Spec-Verletzung: Ob die Reihenfolge den echten DUPLICATE_NAME-Fehler bei Apple behebt, ist eine Hypothese und erst im Eintragungslauf auf Hennings Wort belegbar.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Verdachtszeilen: Die Änderung schreibt keine Feldwerte, sie ändert nur die Reihenfolge der Plan-Liste.

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:2baa9708c5319b3bc0848d9ce9d02b20e3fecbbf95a59d50ae4c7efbd37d4889  scripts/asc_publish.py
- sha256:d0519432db858d11483861c5b5537d2e31a1c995a85844b52d9ca999e9f6cca4  scripts/test_asc_scripts.py

## Prüfbasis

- base: 4403480f6f38fea8d81add90b62f62dafeeb0971
- blob:36c34ca44994cbbd962e96e2f1b55a3939f30b98  scripts/asc_publish.py
- blob:1a916016ef9c4f832a12b1e09ee685f6b7c8d358  scripts/test_asc_scripts.py
