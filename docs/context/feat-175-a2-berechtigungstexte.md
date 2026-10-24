# Context: feat-175-a2-berechtigungstexte

Stand: 2026-10-23, Branch `worktree-nifty-wandering-charm` @ f07b965 (A1 abgeschlossen), Build 36.

## Request Summary
Issue #175, Durchgang A2: Kamera- und Fototext der App lokalisieren (de/en) und `CURRENT_PROJECT_VERSION` auf 37 setzen.
Spec und ACs (AC-6 bis AC-8) stehen schon in `docs/specs/appstore/app-store-auftritt.md` (Abschnitt „Durchgang A2“).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` Z. 36/37 | `INFOPLIST_KEY_NSCameraUsageDescription` / `…PhotoLibrary…` nur englisch („…scan recipe photos“, „…import recipe photos“); Rückfall bleibt laut Spec |
| `project.yml` Z. 24, 75 | `CURRENT_PROJECT_VERSION: 36` (App, Widgets); Share-Extension steht NICHT in project.yml |
| `Restock.xcodeproj/project.pbxproj` | `CURRENT_PROJECT_VERSION = 36` an 6 Stellen (Widgets D/R, App D/R, Share-Extension D/R); Tests-Ziele ohne Nummer |
| `pbxproj` Z. 349/369/591/1055/1356 | Muster `Localizable.strings`: PBXFileReference je Sprache (`de`/`en`, `lastKnownFileType = text.plist.strings`), PBXVariantGroup, Eintrag in Gruppe `Resources` (42F6568E…) und in der Resources-Phase des App-Ziels; `knownRegions` Base/de/en, `developmentRegion = en` |
| `SmartCart/Resources/{de,en}.lproj/` | enthält nur `Localizable.strings`; `InfoPlist.strings` fehlt |
| `RestockTests/PrivacyManifestTests.swift` | Bundle-Zugriff über `Bundle.main`, Quelle über `#filePath`; ergänzen um InfoPlist-Tests und Build-Nummer-Test |
| `CLAUDE.md` (Projekt) | Absatz TestFlight nennt Build-Nummer-Historie; nach Upload fortzuschreiben (nicht Teil A2) |

## Existing Patterns
- Commit 290bd10 („Build-Nummer 36 festhalten“) änderte CLAUDE.md, pbxproj (12 Zeilen), project.yml, Protokoll: so wird die Nummer gesetzt.
- Neue Dateien müssen von Hand in pbxproj registriert werden (vier Stellen, siehe CLAUDE.md).
- Lokalisierung geprüft durch `LocalizationKeyParityTests` (kompilierte Tabellen `Localizable`); InfoPlist-Tabelle ist davon nicht erfasst.

## Dependencies
- Upstream: Xcode erzeugt die Info.plist (`GENERATE_INFOPLIST_FILE: true`); `InfoPlist.strings` im App-Bundle überschreibt die `INFOPLIST_KEY_…`-Werte je Sprache.
- Downstream: Systemdialoge Kamera/Fotos (Bon-Scan, Rezeptfoto, Barcode-Scanner `DataScannerViewController`); Datenschutzangaben in App Store Connect (Durchgang B); Upload Build 37 nur auf Hennings Wort.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (A2: Zeilen ~89–104, ACs ~354–368, Tests ~425–427)

## Risks & Considerations
- Fehlende pbxproj-Registrierung → Text fehlt still; deshalb Test gegen das gebaute Bundle (`Bundle.main`) und Nachweis per Simulator.
- Build-Nummer an 6 pbxproj-Stellen, aber nur 2 in project.yml: alle 6 ändern, Test prüft Übereinstimmung; `xcodegen` nicht laufen lassen (würde pbxproj neu erzeugen und die Share-Extension verlieren).
- Auf Hennings Geräten wird nichts gestartet; Nachweis nur im Simulator (Restock-Validate), schwere Läufe mit beiden Sperren.
- Kameratext muss Bons, Barcodes und Rezeptfotos nennen (AC-6), Fototext Bons und Rezeptfotos.

## Analysis

### Type
Feature (Durchgang A2 von #175; Spec-Abschnitt „Durchgang A2“ existiert, AC-6 bis AC-8).

### Recherche (vor der Analyse, 2026-10-23)
- Apple-Forum „Localizing Custom iOS Target Properties key string data“ (developer.apple.com/forums/thread/76633) und Anleitung medium.com/@guerrix „Info.plist localization“: je Sprache eine `InfoPlist.strings` mit denselben Schlüsseln wie in der Info.plist (Beispiel `NSCameraUsageDescription`); der Schlüssel muss in der Info.plist weiter stehen (bei uns: `INFOPLIST_KEY_…` als Rückfall).
- Apple-Forum „Disable automatic InfoPlist.xcstrings generation“ (developer.apple.com/forums/thread/760564): `InfoPlist.xcstrings` greift auch bei vollständig erzeugter Info.plist; das ist die Alternative zu `.strings`.
- Lücke: Wechselwirkung `INFOPLIST_KEY_…` ↔ `InfoPlist.strings` nicht ausdrücklich belegt → wird per Test gegen das gebaute Bundle und Simulator-Durchlauf bewiesen, nicht angenommen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Resources/de.lproj/InfoPlist.strings` | CREATE | Kamera- und Fototext deutsch |
| `SmartCart/Resources/en.lproj/InfoPlist.strings` | CREATE | Kamera- und Fototext englisch (Bons, Barcodes, Rezeptfotos) |
| `project.yml` | MODIFY | `CURRENT_PROJECT_VERSION` 36 → 37 (Z. 24, 75) |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | 6× Build-Nummer 37 (Z. 1436, 1464, 1555, 1587, 1612, 1637); Strings-Dateien registrieren (FileReference je Sprache, VariantGroup, Gruppe `Resources`, Resources-Phase App-Ziel) |
| `RestockTests/PrivacyManifestTests.swift` | MODIFY | InfoPlist-Schlüssel de/en, Textinhalt, Build-Nummer in beiden Projektdateien |

### Scope Assessment
- Files: 5 (Limit 4–5, am Rand)
- Estimated LoC: ca. +47/−2 (innerhalb ±250)
- Risk Level: LOW–MEDIUM. Produktlogik unberührt; Risiko ist die stille Nichtwirkung (Datei nicht im Ziel registriert) und die pbxproj-Handarbeit.

### Technical Approach
1. Regelweg, kein Modell: zwei statische `InfoPlist.strings`, Build-Nummer per Textersetzung.
2. Rückfall `INFOPLIST_KEY_…` in `project.yml` bleibt englisch; die englische Datei nennt zusätzlich Barcodes (heute nur „recipe photos“, AC-6).
3. Test gegen das gebaute Bundle (`Bundle.main` `de.lproj`/`en.lproj`) statt nur gegen die Quelldateien, damit fehlende Registrierung auffällt.
4. Nachweis als Nutzer: Build 37 im Simulator (Restock-Validate, Sperren), Kamera-Aufruf des Bon-Scans zeigt den deutschen Text; `CFBundleVersion` 37 per `plutil -p`.
5. `xcodegen` NICHT ausführen (würde die Share-Extension aus dem pbxproj verlieren).

### Alternative (zum bisherigen Weg)
`InfoPlist.xcstrings` (String Catalog) statt zweier `.strings`: eine Datei, passt zu erzeugter Info.plist. Dagegen: Projekt nutzt durchgehend `.strings` (`Localizable`), `LocalizationKeyParityTests` und Muster im pbxproj sind darauf ausgelegt; Xcode-27-Extraktion verändert Kataloge beim Bauen. Empfehlung bleibt `.strings`; kippt keine ADR. Kein-Modell-Alternative entfällt (reine Daten).

### Dependencies
Upstream: Xcode-erzeugte Info.plist. Downstream: Systemdialoge Kamera/Fotos (Bon-Scan, Rezeptfoto, Barcode-Scanner), Datenschutz-Fragebogen in ASC (Durchgang B), Upload Build 37 nur auf Hennings Wort. Nichts wird auf Hennings Geräten gestartet.

### Befunde gegen den Plan
Keine zwingenden; Einschränkung: Wirkung von `InfoPlist.strings` bei erzeugter Info.plist ist nicht aus Quellen belegt, sondern erst durch Bundle-Test und Simulatorlauf.

### Open Questions
- [ ] Keine PO-Frage nötig (Texte stehen in der Spec; technische Wahl bei Claude).
