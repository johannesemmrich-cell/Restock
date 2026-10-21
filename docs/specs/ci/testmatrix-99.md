---
entity_id: testmatrix-99
type: ci
created: 2026-10-21
updated: 2026-10-21
status: in-progress
tags: [ci, testing, release-1-0, issue-99]
---

# Testmatrix für Release 1.0 (Issue #99)

## Approval

- [x] PO-Entscheidungen je Punkt am 2026-10-21 (Punkt 3 schon am 2026-10-12)

## Ausgangslage (gemessen 2026-10-02)

Die UI-Tests prüfen nur eine Ecke der Matrix: Teilen-Erweiterung nie in der CI, nur Deutsch, nur iPhone,
nur Standardschrift und kaum Dunkelmodus, nur Debug gebaut.

## Entscheidungen und Pakete

| Punkt | Entscheidung PO | Paket | Stand |
|---|---|---|---|
| 1 Teilen-Erweiterung | testen: dritter UI-Job mit `scripts/run-share-extension-uitest.sh`, blockierend | P4 | offen |
| 2 Englisch | kein UI-Lauf; Unit-Test Schlüsselgleichheit `de.lproj`/`en.lproj` | P2 | offen |
| 3 iPad | entfällt für 1.0; `TARGETED_DEVICE_FAMILY = 1` in allen Konfigurationen | P1 | umgesetzt |
| 4 Schrift/Dunkelmodus | gezielt: zwei UI-Tests mit `UICTContentSizeCategoryAccessibilityXXXL` auf Spaltenkopf „Gesamt“ (#93), Bon-Prüf-Screen, Ladenliste; Dunkelmodus bleibt (zwei Tests, Amber-Kontrast #75) | P3 | offen |
| 5 Release-Build | testen: Job `release-build` in `ci.yml`, Release für den Simulator bei jedem PR | P1 | umgesetzt |

## P1: Release-Build-Job und iPhone-only

- `ci.yml`, Job `release-build`: `xcodebuild build -configuration Release -destination 'generic/platform=iOS Simulator'`
  mit denselben Signatur-Einstellungen wie der Unit-Job (`CODE_SIGN_IDENTITY="-"`, kein echtes Zertifikat); keine
  Tests, kein `needs`, läuft parallel. Erwartete Dauer 5–8 min. Fängt Code, der nur unter `#if DEBUG` kompiliert
  (Launch-Argumente, `FakePurchaseStore`), bevor der TestFlight-Lauf ihn findet.
- `Restock.xcodeproj/project.pbxproj`: `TARGETED_DEVICE_FAMILY = 1` in allen zehn Konfigurationen (App, Widget,
  Teilen-Erweiterung, Unit- und UI-Tests). Folge: App Store Connect verlangt nur iPhone-Screenshots (#175); auf dem
  iPad läuft die App im iPhone-Kompatibilitätsmodus.
- Strukturtest `scripts/test_ci_release_build.py` (5 Prüfungen).
- Nachweis: erster CI-Lauf des PRs; Nachtrag folgt.

## P2–P4

Werden je als eigener PR umgesetzt und hier nachgetragen.

## Offene Grenzen

- Der Release-Job baut, signiert und lädt nicht; Signatur und Upload prüft weiter nur `testflight.yml`.
- Der Simulator-Release-Build deckt keine gerätespezifischen Pfade (Kamera, Live Activity) ab.
