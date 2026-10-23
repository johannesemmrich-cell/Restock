# Adversary Dialog — feat-175-a2-berechtigungstexte
Spec: docs/specs/appstore/app-store-auftritt.md

## Checkliste
- [x] **AC-6:** InfoPlist.strings de/en, gleiche Schluessel, Inhalt wahr (PROVEN)
- [x] **AC-7:** CURRENT_PROJECT_VERSION 37 in project.yml und pbxproj, Strings in Ressourcen des App-Ziels (PROVEN)
- [x] **AC-8:** Unit-Suite gruen plus Simulator-Durchlauf (AMBIGUOUS, Nachweis unvollstaendig; PO-Entscheidung 2026-10-23, Nachweis folgt in /60-validate)

## Dialog

### Runde 1

Pruefung (Lesen, plutil, gebautes Bundle):
- pbxproj: plutil -lint OK. Variant-Group InfoPlist.strings (de, en) in Gruppe Resources, Build-File nur in der Ressourcen-Phase des Ziels Restock. Widget und Share Extension haben keine eigenen UsageDescription-Schluessel, nichts bleibt unlokalisiert.
- Gebautes Bundle Restock.app: de.lproj und en.lproj InfoPlist.strings kompiliert mit korrekten Texten; Info.plist enthaelt weiter den englischen Rueckfall; CFBundleVersion 37; CFBundleDevelopmentRegion en; knownRegions Base, de, en.
- Alle 6 CURRENT_PROJECT_VERSION im pbxproj (App 2, Widget 2, Share Extension 2) = 37, project.yml beide Ziele = 37. Extension-Info.plists nutzen $(CURRENT_PROJECT_VERSION), gleiche Nummer. MARKETING_VERSION 1.0 unveraendert.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Resources/de.lproj/InfoPlist.strings
  Description: Fototext nennt nur Bon- und Rezeptbilder; EditItemView/ItemPhotoPicker (UIImagePickerController camera/library) nutzt Kamera und Fotos auch fuer Artikelfotos.
  Spec requirement: AC-6 — Fototext nennt Bons und Rezeptfotos (Mindestanforderung erfuellt)
  Conflict: Text nicht falsch, aber unvollstaendig; App-Review koennte beanstanden.
  Remediation: Optional "und Artikelfotos" ergaenzen (de+en).

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: RestockTests/PrivacyManifestTests.swift
  Description: Die A2-Tests lesen Dateien aus dem Repo (Strings, project.yml, pbxproj) und pruefen Teilstrings bzw. Werte; sie beweisen nicht, dass das gebaute Bundle die Strings enthaelt.
  Spec requirement: AC-7 — Strings-Dateien in den Ressourcen des App-Ziels registriert
  Conflict: Registrierung nur durch Bundle-Inspektion (von mir geprueft, OK), nicht durch Test abgesichert.
  Remediation: Optional Test gegen das Test-Host-Bundle.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/artifacts/feat-175-a2-berechtigungstexte/test-green-output.txt
  Description: Beleg zeigt nur einen Auswahl-Lauf mit 12 Tests; kein Beleg der vollen Unit-Suite samt LocalizationKeyParityTests; keine Simulator-Screenshots des Durchlaufs.
  Spec requirement: AC-8 — Unit-Suite und LocalizationKeyParityTests gruen plus Simulator-Durchlauf mit Screenshots
  Conflict: AC-8 nach Aktenlage nicht bewiesen.
  Remediation: Volle Unit-Suite und Simulator-Durchlauf nachliefern.

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Resources/en.lproj/InfoPlist.strings
  Evidence: Beide Dateien, gleiche zwei Schluessel, nicht leer, Inhalt nennt Bons, Barcodes, Rezepte bzw. Bon-/Rezeptbilder; im Bundle kompiliert verifiziert.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: project.yml
  Evidence: 37 in beiden Zielen; pbxproj alle 6 Stellen 37; CFBundleVersion 37 im Bundle; Strings in Ressourcen-Phase von Restock; plutil -lint OK.
  Status: CONFIRMED

Code reference: Restock.xcodeproj/project.pbxproj
Code reference: docs/artifacts/feat-175-a2-berechtigungstexte/build-output.txt
Code reference: SmartCart/Resources/de.lproj/InfoPlist.strings

### Runde 2

Nachbohren: Erweiterungen brauchen keine Usage-Keys. Vorrang lproj vor Info.plist-Rueckfall im Bundle angelegt, im Simulator nicht sichtbar gemacht. Texte stimmen zum Code ausser Artikelfotos (F001). Umfang: pbxproj +22/-8, project.yml +2/-2, 2 neue Strings, Tests +66; unter 5 Dateien und 250 LoC.
F003 bleibt: AC-8 ohne Volllauf und Screenshots nicht belegt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**AMBIGUOUS**
AC-6 und AC-7 bewiesen. AC-8: nur Auswahl-Lauf (12 Tests), keine Screenshots, kein Volllauf. F001/F002 LOW, F003 MEDIUM.

## Geprüfte Dateien

- sha256:a6160c14741c1032f0adc3e0609fa236542d5953608f6992862ea7dc717206b2  Restock.xcodeproj/project.pbxproj
- sha256:78e214178438aa0ac5e19b6692c12474ad2860a36ea59633b7e235df63313adf  RestockTests/PrivacyManifestTests.swift
- sha256:4c32eca1393bbdc8c923a76deb99ca7ccd8ab86d4bc603a8adf65d5c30dbb179  SmartCart/Resources/de.lproj/InfoPlist.strings
- sha256:03be14515a4f676bb193775e4388b3789d131309e40454818195173f378fc244  SmartCart/Resources/en.lproj/InfoPlist.strings
- sha256:97b321fa2fea9a59df75f2d624afbd17524b22631919b03f3cd6356b59127013  docs/artifacts/feat-175-a2-berechtigungstexte/build-output.txt
- sha256:0daa2396b9972e50d3d3bcc439713cca04b24ce2fdba181978eb823e296f6a31  docs/artifacts/feat-175-a2-berechtigungstexte/test-green-output.txt
- sha256:b63299ba96a3fad59b32dccb0e333180e5c38297c2cab675f748a3643503c92a  project.yml

## Prüfbasis

- base: a58fd8d622fcd819bedb35fdee9d79fc8d893a74
- blob:847cb3f2f57c69402cca5f714c6eb1ca9df77f48  Restock.xcodeproj/project.pbxproj
- blob:6a137f0c252c6a059c51410b592351e561b1c312  RestockTests/PrivacyManifestTests.swift
- blob:a779246bc808e1d90738ea3d75fcc26d286566a1  SmartCart/Resources/de.lproj/InfoPlist.strings
- blob:4fa9c728312cf5f5bd273d3b13c099db7a302b5a  SmartCart/Resources/en.lproj/InfoPlist.strings
- blob:8edceea5aa753b3dffcb7fbeda2c2a28dd405b53  docs/artifacts/feat-175-a2-berechtigungstexte/build-output.txt
- blob:78857da66f6c663dc099fdd0bba33d38328d2ed6  docs/artifacts/feat-175-a2-berechtigungstexte/test-green-output.txt
- blob:65f18835bfea3eebfd3b719936a9484cae516fa7  project.yml

## Geprüfte Dateien

- sha256:a6160c14741c1032f0adc3e0609fa236542d5953608f6992862ea7dc717206b2  Restock.xcodeproj/project.pbxproj
- sha256:78e214178438aa0ac5e19b6692c12474ad2860a36ea59633b7e235df63313adf  RestockTests/PrivacyManifestTests.swift
- sha256:662ac62ee64dbc2ef62fb926935491ce15b9c3195894e2f5b96a854fcc7ddbd6  SmartCart/Resources/de.lproj/InfoPlist.strings
- sha256:f1a6de956a28d5311a8d4de2e64195a5fac0b37d1996a48aba46028bbbd1f786  SmartCart/Resources/en.lproj/InfoPlist.strings
- sha256:99408b94f10d7bc236a31b90db143e95de30f54c533442cfe3d9aae9a3f365fe  docs/artifacts/feat-175-a2-berechtigungstexte/build-output.txt
- sha256:dcd65ca1372dc314a5e087e88a6347c823bafac2fc4b68185712072709eddd2a  docs/artifacts/feat-175-a2-berechtigungstexte/test-green-output.txt
- sha256:b63299ba96a3fad59b32dccb0e333180e5c38297c2cab675f748a3643503c92a  project.yml

## Prüfbasis

- base: a58fd8d622fcd819bedb35fdee9d79fc8d893a74
- blob:847cb3f2f57c69402cca5f714c6eb1ca9df77f48  Restock.xcodeproj/project.pbxproj
- blob:6a137f0c252c6a059c51410b592351e561b1c312  RestockTests/PrivacyManifestTests.swift
- blob:0404aceaf2088f036178e6e39524a838cf4deebf  SmartCart/Resources/de.lproj/InfoPlist.strings
- blob:52a123b2fe6e07e507f5d06cd99a33cfcf875ae3  SmartCart/Resources/en.lproj/InfoPlist.strings
- blob:97b4733ce729870f4ab2a15dc1aaff1f749cccdb  docs/artifacts/feat-175-a2-berechtigungstexte/build-output.txt
- blob:ff5a9c233db79cd7be2516ae33cd208d4eb3817b  docs/artifacts/feat-175-a2-berechtigungstexte/test-green-output.txt
- blob:65f18835bfea3eebfd3b719936a9484cae516fa7  project.yml
