# TestFlight-Upload per GitHub Actions: Läufe 10 und 11, Builds 34 und 35

Start beider Läufe durch Claude (Sitzung session_01WVW4wUQZKzHmYSdb4s6CXR), Freigabe der Umgebung `testflight` durch Henning.

| Lauf | Datum | Zweig `main` | Eingaben | Ergebnis | Build in TestFlight |
|---|---|---|---|---|---|
| 9 ([run 39621597817](https://github.com/johannesemmrich-cell/Restock/actions/runs/39621597817)) | 2026-10-21 | 6c7fb49 | `dry_run=false`, `build_number=34` | vor der Freigabe abgebrochen, weil Lauf 10 einen neueren Stand mit #199 baut | – |
| 10 ([run 39656806436](https://github.com/johannesemmrich-cell/Restock/actions/runs/39656806436)) | 2026-10-21 | a49466f (#199) | `dry_run=false`, ohne `build_number` | `Upload succeeded.`, Archiv 2:56 min, Upload 2:29 min | **34** (Archiv mit 33 gebaut, Nummer von Xcode beim Export erhöht) |
| 11 ([run 39764633766](https://github.com/johannesemmrich-cell/Restock/actions/runs/39764633766)) | 2026-10-22 | 9bc25d3 (#204, #205) | `dry_run=false`, `build_number=35` | `Upload succeeded.`, Archiv 2:54 min, Upload 1:29 min | **35** |

## Was damit belegt ist

- Ohne `build_number` vergibt Xcode beim Export die nächste freie Nummer (`manageAppVersionAndBuildNumber` nicht gesetzt, Standard `true`). Lauf 10 baute mit 33 aus dem Projekt; Henning sah in TestFlight Build 34. Das Protokoll nennt die vergebene Nummer nicht, deshalb ist die Bestätigung aus TestFlight nötig.
- Ab jetzt wird die Nummer ausdrücklich gesetzt: `build_number` beim Start und `CURRENT_PROJECT_VERSION` im Projekt (`project.pbxproj` an allen 6 Stellen und `project.yml`, das noch 32 hatte) stehen auf 35.

## Inhalt

- Build 34: u. a. Decathlon-Bon (#199), Bon-Prüf-Screen nach Neuinstallation (#35), Amber-Kontrast (#75), Community-Preise als Opt-out (#163), Pakete 1–4 aus #99.
- Build 35: Live Activity erst ab dem ersten Haken (#204), Preiskatalog für Drogerie, Haushalt und Sport sowie Community-Preise über alle Ketten (#205), kyrillisches Steuerkürzel (#203).

## Offen

- Installation und Verhalten auf Hennings Gerät bestätigt nur Henning.
