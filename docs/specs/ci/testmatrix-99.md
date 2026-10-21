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
| 2 Englisch | kein UI-Lauf; Unit-Test Schlüsselgleichheit `de.lproj`/`en.lproj` | P2 | umgesetzt |
| 3 iPad | entfällt für 1.0; `TARGETED_DEVICE_FAMILY = 1` in allen Konfigurationen | P1 | umgesetzt |
| 4 Schrift/Dunkelmodus | gezielt: zwei UI-Tests mit `UICTContentSizeCategoryAccessibilityXXXL` auf Spaltenkopf „Gesamt“ (#93), Bon-Prüf-Screen, Ladenliste; Dunkelmodus bleibt (zwei Tests, Amber-Kontrast #75) | P3 | in Arbeit (PR offen) |
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
- Nachweis (PR #193, run 39551841477, 2026-10-21): alle vier Jobs grün. `release-build` 3 min 47 s (Schritt
  „Build Release for simulator“ 3 min 35 s), deutlich unter der Schätzung. Unit-Job 11 min, ui-test A 30 min,
  ui-test B 53 min, unverändert mit `TARGETED_DEVICE_FAMILY = 1`. Squash-Merge 13f8e14.

## P2: Schlüsselgleichheit Deutsch/Englisch

`RestockTests/LocalizationKeyParityTests.swift` liest die kompilierten Tabellen `de.lproj`/`en.lproj` aus dem
App-Bundle (nicht die Quelldateien) und prüft: beide vorhanden und > 300 Schlüssel, keine leeren Texte, gleiche
Schlüsselmengen (fehlende je Seite werden genannt), gleiche Platzhalter je Schlüssel (`%@`, `%d`, `%1$@`, `%.1f`,
`%lld`; `%%` ausgenommen). Stand beim Anlegen: 378 Schlüssel je Sprache, keine Abweichung, 41 Texte mit
Platzhaltern. Kein englischer UI-Lauf; die englische Oberfläche selbst bleibt beim Gerätetest (#187).

## P3: Dynamic Type XXXL, zwei gezielte UI-Tests

`RestockUITests/DynamicTypeUITests.swift` startet die App mit dem UIKit-Launch-Argument
`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` (Argument-Domain nur dieses
Prozesses, kein Zustand in der App-Gruppe, daher kein eigenes Aufräum-Argument; `tearDown` räumt nur den
Bon-Seed und den Bon-Auflösungs-Zähler weg, die T2 beim Speichern erzeugt).

- **T1 `testResolutionStatsHeaderGesamtFitsAtLargestAccessibilitySize`:** Dev-Modus → Einstellungen →
  „Bon-Auflösung“. Der Spaltenkopf „Gesamt“ (#93) muss waagerecht im Fenster liegen und mindestens so breit
  sein, wie der Text in `.caption` bei AX5 mit `minimumScaleFactor(0.7)` braucht (gemessen im Testläufer mit
  `UIFont.preferredFont(forTextStyle:compatibleWith:)`, Kleinschreibung als Untergrenze). Dazu Summenzeile
  „Alle Stufen“ im Fenster und mit Zahl am Anfang.
- **T2 `testReceiptReviewAndStoreListStayUsableAtLargestAccessibilitySize`:** Bon-Seed → Prüf-Screen
  (Kopfzeile, Bon-Text und Häkchen der ersten Zeile, „Speichern“-Chip im Fenster und antippbar) → Speichern →
  Kachel „Lidl“ → Ladenliste (Schnelleingabe, Artikelzeile „Milch“, ···-Menü im Fenster, Zeile antippbar).
- Warum Breitenmessung: XCUITest liefert immer das volle Label, ein „Gesa…“ ist von außen nur an der
  gerenderten Breite erkennbar (wie P11 in `PurchaseUITests`).
- CI: Die Klasse steht in `HEAVY_CLASSES` (Hälfte A, 30 min), weil Hälfte B mit 53 min nahe am Limit von
  60 min lag; Ausnahme von „neue Klassen landen in B“, in `ui-test-job-in-zwei-haelften.md` nachgetragen.
- Erster Lauf (39563379941): T2 grün (72 s, Prüf-Screen und Ladenliste in XXXL bedienbar). T1 rot aus einem
  Testfehler: Der Link „Bon-Auflösung“ lag in XXXL unter dem Rand und ist dort nicht im Bedienhilfen-Baum, der
  Helfer wartete auf Existenz, bevor er wischte; behoben (wischen, solange das Element fehlt). Die Breitenmessung
  selbst kam noch nicht zum Zug. Nebenbefund: Die #173-Wiederholung lief die ganze Auswahl erneut, beide Hälften
  brachen am 60-min-Limit ab; behoben in diesem PR (Fassung 2, `ui-test-job-in-zwei-haelften.md`).
- Zweiter Lauf (39573224713): T1 misst und meldet den Fehler: Spaltenkopf „Gesamt“ 40,0 pt breit, nötig 100,0 pt
  (caption bei AX5 × 0,7), also „Gesa…“ wie in #93, nur in großer Schrift. T2 grün. Produktfix im selben PR
  (Entwickler-Bildschirm, keine Farbänderung): `ReceiptResolutionStatsView` stapelt ab
  `dynamicTypeSize.isAccessibilitySize` je Stufe beschriftete Werte ohne feste Breiten, Kopfzeile nur „Stufe“,
  Kennungen unverändert; Normalgröße unverändert. Zweiter Testfehler im Helfer behoben (Wischen bis zur Existenz,
  dann kurze Züge; die Wiederholung wischte an der halb verdeckten Zeile vorbei bis zum Listenende).
- Nachweis: nächster CI-Lauf des PRs (T1 grün erwartet); Dauer von Hälfte A wird hier nachgetragen.

## P4

Wird als eigener PR umgesetzt und hier nachgetragen.

## Offene Grenzen

- Der Release-Job baut, signiert und lädt nicht; Signatur und Upload prüft weiter nur `testflight.yml`.
- Der Simulator-Release-Build deckt keine gerätespezifischen Pfade (Kamera, Live Activity) ab.
