# Adversary Dialog — fix-214-181-legal-pfeil
Spec: docs/specs/views/legal-text-darstellung.md
Datum: 2026-11-05 11:25

## Checkliste
- [x] AC-1: Absätze an Leerzeilen; Leerzeilen mit Leerraum, führende und abschließende Leerzeilen ohne leeren Block.
- [x] AC-2: Adresse bleibt ein Absatz mit Umbrüchen.
- [x] AC-3: `---` als eigenes Stück wird `.divider`, kein Block enthält `---`.
- [x] AC-4: Punkte ohne Präfix „- “, gemischter Fall, „-5 %“ bleibt Absatz.
- [x] AC-5: Alle drei Dokumente ohne Rest-Markdown, Trennlinien 7/9/7, 18 Punkte (6 + 6 + 3 + 3), kein leerer Block.
- [x] AC-6: Verlustfreiheit auf allen drei Dokumenten, unabhängig nachgerechnet.
- [x] AC-7: Fettdruck bleibt, kein `**` im Anzeigetext.
- [x] AC-8: Literale unverändert, nur drei Deklarationszeilen `private let` → `static let` und die Zuordnung `text(for:)`.
- [x] AC-9: Keine `\u{` in `.strings`, Gegenprobe vorhanden.
- [x] AC-10: Pfeil in de und en, sonst unveränderter Wert.
- [x] AC-11: UI-Test Rechtstexte (Datenschutz) grün, hell und dunkel.
- [x] AC-12: UI-Test Nutzungsbedingungen und Impressum grün, hell und dunkel.
- [x] AC-13: UI-Test Rezeptplan-Hinweis mit „→“ grün, hell und dunkel.
- [x] AC-14: Nichts nach rechts abgeschnitten bei AccessibilityXXXL.
- [x] AC-15: Unit 22 Tests (PrivacyManifestTests 18, LocalizationKeyParityTests 4), UI 4 Tests hell und dunkel, `test_asc_texts.py` 10 Tests, 0 Fehlschläge.
- [x] AC-16: Aufnahmen hell und dunkel aus echten Läufen, `benutzen-befund.md` geschrieben; Orchestrator und Prüfer haben mehrere Aufnahmen angesehen, übrige vom Developer-Agenten beschrieben (im Befund so gekennzeichnet).
- [x] AC-17: Fünf Code-Dateien, keine Fremddatei (`ci.yml`, `project.pbxproj`, `docs/appstore/`, `InfoPlist.strings`, `PrivacyInfo.xcprivacy`, `docs/cloudkit/` unberührt).

## Dialog

### Runde 1
**Adversary:** Eigene Nachrechnung von `LegalTextBlocks` mit den drei echten Literalen (Skript): AC-1 bis AC-7 bestätigt, Trennlinien 7/7, 9/9, 7/7, 18 Punkte, verlustfrei. `git diff 78f5756 -- RestockTests RestockUITests` leer. `plutil -lint` beider `.strings` OK, Diff nur Zeile 357. Findings, alle LOW: F-1 leerer Punkt „- “ ergibt `.bullet("")`; F-2 `---` nur als eigenes Stück erkannt; F-3 CRLF wird nicht getrennt; F-4 „•“ als eigenes Element für VoiceOver; F-5 Testschwäche (Vergleich ohne Leerraum). Offen: AC-16 (dunkle Aufnahmen, sichtbarer Pfeil, Befund).
Code reference: SmartCart/Views/Settings/LegalView.swift:23
Code reference: SmartCart/Resources/de.lproj/Localizable.strings:357
Code reference: SmartCart/Resources/en.lproj/Localizable.strings:357
**Implementierer:** F-1, F-3 und F-4 behoben (leere Punkte verworfen, CRLF/CR zu LF, „•“ verborgen und Punkt als ein Element). F-2 bleibt als bekannte Grenze (entspricht Spec-Regel 2). Zwei Zeilen in bestehenden Unit-Tests ergänzt, im Rezeptplan-Test Nachwischen bis der Hinweis ganz im Fenster liegt. Läufe hell und dunkel mit gesetztem Erscheinungsbild, acht Aufnahmen aus den Anhängen exportiert.
Code reference: RestockTests/PrivacyManifestTests.swift:201
Code reference: RestockUITests/DynamicTypeUITests.swift:262

### Runde 2
**Adversary:** Korrekturen im Code geprüft (LegalView.swift:32 Normalisierung, :48 leere Punkte, :110–113 Barrierefreiheit), Randfälle erneut gerechnet (CRLF, CR, NBSP-Punkt, eingerückter Punkt, Trennlinie ohne Leerzeilen): kein Defekt. Neue Testzeilen nur Ergänzungen, RED-Assertions unverändert. Belege jünger als die Quelländerung (Quellen 11:30, Unit 11:31, UI 11:37). Vier Aufnahmen angesehen und gegen den Befund gehalten: eine Zahlenungenauigkeit (F-7: 8 statt 6 Punkte), sonst stimmig. Findings LOW: F-5 keine verschachtelten Listen, F-6 VoiceOver und Link unter `.combine` ungeprüft, F-7 Zahl im Befund, F-8 Hinweisschrift wächst nicht mit Dynamic Type (Bestand). Verdict VERIFIED.
Code reference: SmartCart/Views/Settings/LegalView.swift:32
Code reference: SmartCart/Views/Settings/LegalView.swift:113
**Implementierer:** F-7 im Befund korrigiert. Die offenen Grenzen stehen im Changelog der Spec (Abschnitt „Offene Grenzen“ ist eingefroren). Umfang rund 345 statt 250 Zeilen, vom PO am 2026-11-05 akzeptiert.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:767e26bd20b7236c93876ad6c5547b605c473f396b72ee01122f012c7e756f43  RestockTests/PrivacyManifestTests.swift
- sha256:b3182861018382652dc14bd580d26cfcd23d8e1214e660fef89e1896fc07164d  RestockUITests/DynamicTypeUITests.swift
- sha256:b73394b6265025f6264f4a7052c2c9bf44193045e308c6754b30d7d4ade8abfb  SmartCart/Resources/de.lproj/Localizable.strings
- sha256:df70da8657e9839eb950e75dbfac6d43962d2bf580a9bafa4ff090181a911168  SmartCart/Resources/en.lproj/Localizable.strings
- sha256:67a3b5c361ff5e5b110065e3eb5e41f2bef63d82ca7a2ba8bc11811b5420dbe7  SmartCart/Views/Settings/LegalView.swift

## Prüfbasis

- base: 552802a5e80e95ee9665aa0e3c9ead7a96e76df9
- blob:c51c51f4e76a9b2b9727d4f50ae72acf91a50996  RestockTests/PrivacyManifestTests.swift
- blob:5a37d859a9a2986cd3cdbdc4df9203ba5b868892  RestockUITests/DynamicTypeUITests.swift
- blob:b72fdffa83961e7fad7237ee2d5fc561966720af  SmartCart/Resources/de.lproj/Localizable.strings
- blob:3750716ee3cab9472f225691bd3686e5af4ed1c1  SmartCart/Resources/en.lproj/Localizable.strings
- blob:c139a1b8556f8ee3411aa717563ae73ddd466786  SmartCart/Views/Settings/LegalView.swift

## Geprüfte Dateien

- sha256:767e26bd20b7236c93876ad6c5547b605c473f396b72ee01122f012c7e756f43  RestockTests/PrivacyManifestTests.swift
- sha256:b3182861018382652dc14bd580d26cfcd23d8e1214e660fef89e1896fc07164d  RestockUITests/DynamicTypeUITests.swift
- sha256:b73394b6265025f6264f4a7052c2c9bf44193045e308c6754b30d7d4ade8abfb  SmartCart/Resources/de.lproj/Localizable.strings
- sha256:df70da8657e9839eb950e75dbfac6d43962d2bf580a9bafa4ff090181a911168  SmartCart/Resources/en.lproj/Localizable.strings
- sha256:67a3b5c361ff5e5b110065e3eb5e41f2bef63d82ca7a2ba8bc11811b5420dbe7  SmartCart/Views/Settings/LegalView.swift

## Prüfbasis

- base: 552802a5e80e95ee9665aa0e3c9ead7a96e76df9
- blob:c51c51f4e76a9b2b9727d4f50ae72acf91a50996  RestockTests/PrivacyManifestTests.swift
- blob:5a37d859a9a2986cd3cdbdc4df9203ba5b868892  RestockUITests/DynamicTypeUITests.swift
- blob:b72fdffa83961e7fad7237ee2d5fc561966720af  SmartCart/Resources/de.lproj/Localizable.strings
- blob:3750716ee3cab9472f225691bd3686e5af4ed1c1  SmartCart/Resources/en.lproj/Localizable.strings
- blob:c139a1b8556f8ee3411aa717563ae73ddd466786  SmartCart/Views/Settings/LegalView.swift
