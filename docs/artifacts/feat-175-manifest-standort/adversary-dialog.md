# Adversary Dialog — feat-175-manifest-standort
Spec: docs/specs/appstore/manifest-standort.md
Datum: 2026-10-28 14:40

## Checkliste
- [x] **Input:** Release-Build mit dem neuen Manifest.
- [x] **Output:** Das Manifest nennt sieben Datenarten, die Erklärung in App und auf der Seite nennt den Standortbezug der
- [x] **Side effects:** keine; kein neuer Berechtigungsdialog, keine Änderung an Speicher, Schlüsseln oder Netzverkehr.
- [x] **AC-1:** Vorbedingung: Manifest `SmartCart/PrivacyInfo.xcprivacy` im Bundle. Aktion: Plist parsen. Ergebnis: genau sieben Datentypen, die bisherigen sechs unverändert plus `NSPrivacyCollectedDataTypeCoarseLocation` (verknüpft true), je Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`, `NSPrivacyCollectedDataTypeTracking` false.
- [x] **AC-2:** `NSPrivacyTracking` false, Tracking-Domains leer, UserDefaults-Reason `1C8F.1` und die Aussage „EAN nicht deklariert“ bleiben; die Typmenge entspricht der Soll-Liste (sieben).
- [x] **AC-3:** Der Open-Prices-Absatz in `LegalView` enthält den Standort-Satz („ungefähren Aufenthaltsort“); der Absatz „Community-Preise“ enthält weiter „ohne Filiale oder Standort“; „Stand: Oktober 2026“ bleibt.
- [x] **AC-4:** `docs/appstore/datenschutz.md` enthält den deutschen Satz wortgleich in `## Deutsch` (Drift gegen `LegalView`) und die englische Übersetzung („approximate whereabouts“) in `## English`. `RestockTests/PrivacyManifestTests.swift::testOpenPricesParagraphNamesApproximateLocation` (EN, neu anzulegen in RED)
- [x] **AC-5:** Das Manifest im Release-Bundle (Release-Übersetzung für den Simulator) stimmt mit der Quelle überein und enthält die sieben Typen. `docs/artifacts/feat-175-manifest-standort/release-manifest-check.txt`
- [x] **AC-6:** Doku gleichgezogen: Tabelle „Deklarierte Datentypen“ der Haupt-Spec hat sieben Zeilen (neu Standort › Ungefährer Standort, `NSPrivacyCollectedDataTypeCoarseLocation`, verknüpft ja), der Absatz „Standort“ unter „Nicht deklariert“ ist durch die Entscheidung ersetzt, `CLAUDE.md` nennt sieben Datenarten. (Abweichung F001, vom PO akzeptiert)
- [x] **AC-7:** Unit-Suite grün, `scripts/test_asc_texts.py` grün.

## Dialog

### Runde 1
**Adversary:** Alle Punkte einzeln mit eigenem Beweis aus dem echten Stand geprüft.
- Input: `plutil -lint SmartCart/PrivacyInfo.xcprivacy` gibt OK. AKZEPTIERT.
- Output: 7 Typen (`grep -c` gibt 7), Diff gegen HEAD ohne entfernte Zeilen, Eintrag CoarseLocation Linked true, Tracking false, Zweck AppFunctionality.
  Code reference: SmartCart/PrivacyInfo.xcprivacy:98
  AKZEPTIERT.
- Side effects: nur CLAUDE.md, Manifest, LegalView, datenschutz.md, zwei Specs, Artefakte geändert; keine Info.plist, keine Projektdateien. AKZEPTIERT.
- AC-1, AC-2: Tests grün (testCollectedDataTypesEqualDocumentedList, testTrackingFalseAndUserDefaultsReasonKept, testNoBarcodeDataTypeDeclared). AKZEPTIERT.
- AC-3: ein Satz im Open-Prices-Absatz, Community-Absatz und Stand unverändert.
  Code reference: SmartCart/Views/Settings/LegalView.swift:86
  AKZEPTIERT.
- AC-4: `python3 -m unittest scripts.test_asc_texts` 10 Tests OK; DE-Satz in docs/appstore/datenschutz.md:39, EN-Satz nach „(ODbL license).“.
  Code reference: docs/appstore/datenschutz.md:39
  AKZEPTIERT.
- AC-5: plutil am Release-Bundle zeigt 7 Typen. AKZEPTIERT mit Vorbehalt F002.
- AC-6: NACHFRAGE, F001.
- AC-7: 750 Tests, 0 Fehlschläge, TEST SUCCEEDED; PrivacyManifestTests 9/9. AKZEPTIERT.
**Implementierer:** F002 behoben: release-manifest-check.txt trägt jetzt Kopfzeilen mit Befehl, Bauweise und Stand. F001: Haupt-Spec ist durch die Freigabe-Sperre von feat-175-a2-berechtigungstexte geschützt; nur Changelog-Zeile möglich, ehrlich in manifest-standort.md:139 dokumentiert.
  Code reference: docs/specs/appstore/manifest-standort.md:139
  Code reference: docs/specs/appstore/app-store-auftritt.md:1028
  Code reference: CLAUDE.md:167

### Runde 2
**Adversary:** Nachgebohrt: Veraltete Texte („sechs“, „kein Standort“) in LegalView, docs/appstore, Test, scripts/test_asc_texts.py gesucht: nur die Haupt-Spec ist veraltet (F001). EN-Test sucht „approximate whereabouts“ im ganzen EN-Teil, nicht im Open-Prices-Absatz (F003, LOW). Schlüsselname ohne Apple-Beleg, Spec vermerkt das unter Known Limitations.
  Code reference: RestockTests/PrivacyManifestTests.swift:105
  Befunde: F001 MEDIUM (AC-6 ersetzt statt erfüllt), F002 LOW, F003 LOW.
**Implementierer:** Schlüsselname ist in zwei Herstellerdokus (Unity, Fingerprint) in identischer Form belegt, Apples Seite war nicht abrufbar; Folge eines falschen Namens wäre Meldung beim Upload-Scan, kein Absturz. F003 bleibt als bekannte kleine Lücke (Stelle des EN-Satzes von Hand per Diff belegt). F001: PO hat am 2026-10-28 „So lassen“ gewählt (Changelog-Zeile reicht, neue Spec maßgeblich).

## Herkunft der Vorbedingungen

Keine neue Schreibstelle im Produktivcode. Das Manifest ist statische Konfiguration und wird zur Laufzeit nirgends geschrieben. Bedingung davor: keine. Test für diesen Weg: `testCollectedDataTypesEqualDocumentedList` (liest die Plist selbst).

## Verdict

VERDICT: AMBIGUOUS
Ambiguous findings (vom PO akzeptiert): F001 AC-6 nur als Changelog-Zeile umgesetzt (Haupt-Spec gesperrt), PO-Wahl „So lassen“ am 2026-10-28.
Nicht blockierend: F002 (behoben), F003 (EN-Test unscharf, LOW).
Proven points: 8/9, AC-6 ersetzt statt erfüllt.
Tests: 750 bestanden (volle Unit-Suite), 9 bestanden (PrivacyManifestTests), 10 Python-Tests bestanden, 0 fehlgeschlagen.

## Geprüfte Dateien

- sha256:87f857d99bc29f8274a2da70658aa89e6d598723c05a62517fcd620a978a3fb7  CLAUDE.md
- sha256:4e88c3e08f57ef57dc6e099acbcb683ab3407a963441aba9e09ce0f0c9ce4e03  RestockTests/PrivacyManifestTests.swift
- sha256:d32f80de941b76646667e8f65efe9d598b7965986cd34707fd21bb4e45a03b4b  SmartCart/PrivacyInfo.xcprivacy
- sha256:bc07ff99989409017b6bc04d5a35d8692abb8e64abaafd82b24ccb0a77f1efd7  SmartCart/Views/Settings/LegalView.swift
- sha256:326b27d0601df7a3fafd98b087b0173953fb3d234b32830da9b4690a5b7e6f19  docs/appstore/datenschutz.md
- sha256:1724934582cb18da94848e9da0b3de289d3b2c992b9e9ef340a05b36a5fb515c  docs/specs/appstore/app-store-auftritt.md
- sha256:2e790f5d280dc6955f0509a56a2b3955d42664c9118f51d3605ccc952fb2fe81  docs/specs/appstore/manifest-standort.md

## Prüfbasis

- base: cd9b5f72657e3440e4de8b6f9ac2c67ec197dd37
- blob:c06d4b59a89aa1b92ae31f961d90ce38bd4062b1  CLAUDE.md
- blob:f75492987b5155aba1c6edf4434a452432a1060b  RestockTests/PrivacyManifestTests.swift
- blob:4c180cabb1733ea1bb1f977ec64312914b1aa194  SmartCart/PrivacyInfo.xcprivacy
- blob:58770762d0c87cb5b9c726273746d8bfe1f5af8a  SmartCart/Views/Settings/LegalView.swift
- blob:9c9a75a09e4be04abd09d98e5bb468ebab1a56fa  docs/appstore/datenschutz.md
- blob:84192768b04910e480024e4bfb50350afb7268c4  docs/specs/appstore/app-store-auftritt.md
- blob:1c9ac87a7ea26d509742fb2b84d7c7167db120de  docs/specs/appstore/manifest-standort.md
