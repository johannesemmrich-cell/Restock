# Adversary-Dialog: feat-175-b3-betrieb (Teil Screenshots)

Umfang: AC-1, AC-2, AC-3 (= AC-16 der Haupt-Spec), AC-7 nur für den Screenshot-Upload, Aufnahme-Test. Nicht Teil dieser Runde, weil spätere Schritte von B3 und noch nicht erledigt: AC-4 (Käufe), AC-5 (Build 37), AC-6 (Datenschutzseite), AC-8 (Abschlusslauf).

### Runde 1

Confirmation (AC-1, Maße):
Code reference: docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
Evidence: `sips` meldet de 01–05 und en 01–07 mit 1320×2868; screenshots-6-3 (de 5, en 3) mit 1206×2622. Hochgeladen: de 01–05, en 01-start, 03-schnell-hinzufuegen, 06-artikel-hinzufuegen.
Status: CONFIRMED

Confirmation (AC-1, Aufnahme-Test):
Code reference: RestockUITests/StoreScreenshotCaptureUITests.swift
Evidence: Der Test überspringt sich ohne `RESTOCK_STORE_SHOTS_DIR` (läuft nie in CI), räumt im tearDown mit allen passenden Clear-Argumenten auf und benutzt nie `-developerMode`.
Status: CONFIRMED

Confirmation (project.pbxproj):
Code reference: Restock.xcodeproj/project.pbxproj
Evidence: Die Datei steht in genau 4 Zeilen (PBXBuildFile, PBXFileReference, Gruppe RestockUITests, Sources-Phase), UUIDs eindeutig.
Status: CONFIRMED

Confirmation (AC-3/AC-16, GET-only-Zaun):
Code reference: scripts/asc_check.py
Evidence: `sec_screenshots` und `check_shot_set` benutzen nur lesende GETs, `scripts/asc_lib.py` ist unverändert, der Display-Typ ist nur Anzeige, ein leeres Set ist eine Abweichung.
Status: CONFIRMED

Confirmation (AC-3/AC-16, Beleg):
Code reference: docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
Evidence: Lauf 2026-10-29T16:45:02Z: de 5 Bilder 1206×2622 und 5 Bilder 1320×2868, en je 3 Bilder, alle COMPLETE, Exit 0.
Status: CONFIRMED

### Runde 2

Finding F001:
Severity: MEDIUM
Category: edge_case
Code reference: scripts/asc_check.py
Description: Der Prüfer wertete `assetDeliveryState` nicht aus; ein Bild mit gültigem Maß, aber Zustand FAILED galt als ok.
Spec requirement: AC-3/AC-16.
Remediation: Set nur ok, wenn alle Bilder COMPLETE sind. Behoben, siehe Runde 3.

Finding F002:
Severity: LOW
Category: spec_violation
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md
Description: Herkunft der 1206×2622-Bilder (Skalierung mit `sips`, Abweichung 0,1 %) stand nirgends.
Remediation: Changelog und Aufnahmeprotokoll ergänzen. Behoben.

Finding F003:
Severity: LOW
Category: spec_violation
Code reference: docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
Description: Die Bildpfade der Vorschau zeigten auf einen nicht vorhandenen Ordner.
Remediation: Pfade auf `../feat-175-app-store-auftritt/screenshots/` ändern. Behoben. Die veröffentlichte Artefakt-Seite behält ihre eigenen Pfade und bleibt unverändert.

Finding F004:
Severity: MEDIUM
Category: edge_case
Code reference: docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
Description: Hennings getippte Freigabe und der Upload waren nur im Gesprächsverlauf belegt.
Remediation: Abschnitt „Freigabe und Upload (AC-7)“ ergänzt. Der Upload-Zeitpunkt ist nicht exakt belegt (Eingrenzung: vor der ersten Abfrage, die Bilder fand, 2026-10-29T15:07:16Z). Offene Grenze bleibt: die Wortzeile steht nur im Gesprächsverlauf und im Protokoll, nicht in einem maschinellen Beleg.

Finding F005:
Severity: LOW
Category: edge_case
Code reference: scripts/asc_check.py
Description: Der Prüfer erkennt weder Duplikate noch Reihenfolge noch falsche Bildsprache.
Remediation: In „Known Limitations“ der Spec aufgenommen. Behoben.

### Runde 3

Confirmation (F001):
Code reference: scripts/asc_check.py
Evidence: Neuer Test `test_screenshots_valid_size_needs_complete_state`: 1320×2868 mit FAILED oder UPLOAD_COMPLETE ergibt Abweichung, mit COMPLETE ok. Vor dem Code war der Test rot (1 Fehlschlag), danach grün. Eigener Lauf: test_asc_check 47 OK, test_asc_texts 10 OK, test_asc_scripts 28 OK.
Status: CONFIRMED

Confirmation (F002 bis F005):
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md
Evidence: Changelog 2026-10-29 und „Known Limitations“ ergänzt; Aufnahmeprotokoll hat den Abschnitt zu Freigabe und Upload; in `vorschau-bilder.html` kommt `src="bilder/` nicht mehr vor.
Status: CONFIRMED

Offene Grenzen: Der Prüfer ist bei einem leeren Set und bei unbekannten Zuständen nicht gegen echte Antworten geprüft. Wort und Upload für AC-7 sind nur im Protokoll und im Gesprächsverlauf belegt. Der Aufnahme-Test wurde vom Prüfer nur gelesen, nicht ausgeführt.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:5997f3487763ef4c8e2e72b119a12ff4b5ae48018c5b6d7a1cc98f7f2c3f43b6  Restock.xcodeproj/project.pbxproj
- sha256:16fb86de17f79b6bd9855f167ec72cb3dae0b063607b888538ec5332693cfd61  RestockUITests/StoreScreenshotCaptureUITests.swift
- sha256:d6cd3c7d0a42c8b81d4756235a802ed26b6b4272e2ae93e907f25d4060e15727  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- sha256:f0975313db8912f84db9d71dfd44606bfe5cd25ebf85c9642552691e84217778  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- sha256:3171632cd53cfb7e70ef9365c571f11a51ffd0973a38c0e99a73d120a642e7db  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- sha256:a13eb6312f9b31e081e1270de4bc7a746181546a733ae9357d687f3830f9c489  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- sha256:d273d8dea08972a8883ebee15a182345d8e2e46d23d9f1ce0c0f986b2a0c53d4  docs/specs/appstore/b3-betrieb-restschritte.md
- sha256:129cf1f9ad503143413cef4d4b22386c4946ef6e3f301a6a74eaba00d13d2dd3  scripts/asc_check.py

## Prüfbasis

- base: 1b190c854ee66d4bccebd4a98bb6ec6dc375ced3
- blob:6ac468fd87dfbaca711dadc385bfec95ff6ad3f9  Restock.xcodeproj/project.pbxproj
- blob:c4e8f7863b6583dd37d570fb92add140f0381404  RestockUITests/StoreScreenshotCaptureUITests.swift
- blob:cef4f2be6f4b6dcd7c0ebca7c1638c7781b642b2  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- blob:2fb598196b5f8f553d73d76287fa32fb0509ebfd  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- blob:7212b84b32b90e06d0961f1b97f25a1dd094abf1  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- blob:94d01eed4c2139f268882704c82db2026b19f7be  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- blob:e52c14cc7a0ba3e8357b78dca6a122f9857d693c  docs/specs/appstore/b3-betrieb-restschritte.md
- blob:e559230ba2e9dc0e3415ccc848ccf2efa2629db1  scripts/asc_check.py
