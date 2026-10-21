# Mini-Spec: Produkt-Test zur Gerätefamilie „nur iPhone" und `project.yml` (#99, Nachtrag zu PR #193)

PO-Entscheidung 2026-10-21: PR #193 (andere Sitzung) gilt als Durchgang 1 von #99; dieses Paket ist der kleine
Nachtrag daraus (Fast Track).

## Was ändert sich
- Neue Testdatei `RestockTests/DeviceFamilyTests.swift`: liest `UIDeviceFamily` aus der `Info.plist` des gebauten
  Test-Hosts `Restock.app` sowie aus `PlugIns/SmartCartWidgets.appex` und `PlugIns/RestockShareExtension.appex` und
  erwartet jeweils genau `[1]`. Fehlende Datei oder fehlender Schlüssel ist ein Fehler, nie ein Skip. Muster:
  `RestockTests/CheckOffIntentVisibilityTests.swift`.
- `Restock.xcodeproj/project.pbxproj`: Registrierung der neuen Datei an den vier üblichen Stellen (PBXBuildFile,
  PBXFileReference, Gruppe `RestockTests`, Sources-Phase), UUIDs `A199DF010000000000000001/…02`.
- `project.yml` Zeilen 22 und 74: `TARGETED_DEVICE_FAMILY: 1,2` → `1` (Datei wird laut CI-Kommentar nicht
  ausgeführt; nur Konsistenz zur Projektdatei).

## Was darf sich nicht ändern
- Kein Produktcode (`SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`), keine UI-Tests, kein `ci.yml`,
  keine Änderung an `TARGETED_DEVICE_FAMILY` in der Projektdatei (bleibt `1`, aus PR #193).
- Der Strukturtest `scripts/test_ci_release_build.py` aus PR #193 bleibt unverändert und grün.

## Offene Grenze
- Der Test läuft im Debug-Bau des Test-Hosts; er prüft die Einstellung am gebauten Produkt, nicht den
  Release-Bau (beide Konfigurationen tragen laut Projektdatei denselben Wert).
- Nichts auf Hennings Geräten; Nachweis im Simulator `Restock-Validate-27` (iOS 27.0). In der Unit-Suite bleibt
  `ReceiptTextRecognizerTests` T1 rot (#195, anderes Ticket).

## Manuelle Test-Schritte
Keine. Nachweis automatisiert:
1. `DeviceFamilyTests` im Simulator: 3/3 grün (`xcodebuild test -only-testing:RestockTests/DeviceFamilyTests`).
2. RED-Beleg: derselbe Test war am 2026-10-21 08:04 auf dem Stand mit `"1,2"` 3/3 rot (`UIDeviceFamily` = `[1, 2]`),
   Protokoll `docs/artifacts/test-99-devicefamily-bundle-test/test-red-devicefamily-2026-10-21-0804.txt`.
3. Gesamte Unit-Suite im Simulator ohne Host-Absturz, rot nur #195.
4. Durchlauf: App im Simulator starten, Startseite sichtbar (Bildschirmfoto).

## Inline-Test (wird während Implementierung geschrieben)
- [x] Test für `UIDeviceFamily == [1]` in App, Widget- und Teilen-Erweiterung (die neue Datei selbst)
