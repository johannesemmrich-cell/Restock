---
entity_id: manifest-standort
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
version: "1.0"
workflow: feat-175-manifest-standort
tags: [feature, appstore, datenschutz, privacy-manifest, release-1-0, issue-175]
---

# Datenschutz-Manifest: „Ungefährer Standort“ nachziehen (Issue #175)

## Approval

- [ ] Approved

Fortschreibung von `docs/specs/appstore/app-store-auftritt.md` (Durchgang A1, Tabelle „Deklarierte Datentypen“).
Beschluss des PO, hier übernommen und nicht neu verhandelt: Im App-Privacy-Fragebogen steht „Ungefährer Standort“
(verknüpft, App-Funktionalität, kein Tracking), gewählt am 2026-10-27, veröffentlicht am 2026-10-28
(Beleg `docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg`).
Quelle: `docs/context/feat-175-manifest-standort.md`.

## Purpose

Der veröffentlichte Fragebogen in App Store Connect nennt sieben Datenarten, das Manifest der App nur sechs. Apple
gleicht beides nicht automatisch ab, aber Manifest, Fragebogen und Datenschutzerklärung müssen dasselbe sagen. Diese Spec
zieht Manifest, Test, Erklärung (in der App und auf der Datenschutzseite) und die Dokumentation auf den Stand des
Fragebogens, **vor Build 37**.

Warum Standort: Wer Bons an Open Prices beiträgt, veröffentlicht die gewählte Filiale unter seinem Benutzernamen. Eine
Filiale lässt den ungefähren Aufenthaltsort erkennen. Die App liest keinen Gerätestandort und braucht keine
Standort-Berechtigung; es ändert sich nichts am Verhalten der App.

Hat es bisher funktioniert? Es ist keine Verschlechterung, sondern eine Angleichung an eine Entscheidung vom Vortag.

## Source

- `SmartCart/PrivacyInfo.xcprivacy`
- `RestockTests/PrivacyManifestTests.swift`
- `SmartCart/Views/Settings/LegalView.swift`
- `docs/appstore/datenschutz.md`
- `docs/specs/appstore/app-store-auftritt.md`, `CLAUDE.md`

## Dependencies

- Upstream: Open-Prices-Beitrag (`OpenPricesContributionService`, Filiale aus Nominatim, Opt-in, Standard aus).
- Downstream: Build 37 (Manifest geht ins Bundle, Upload bei Henning); die Datenschutzseite pflegt ein Dritter, sie braucht
  den neuen Satz aus `docs/appstore/datenschutz.md` (nicht Teil dieser Spec).
- Parallel offen: Workflow `feat-175-b3-eintragen` (Phase 6), getrennte Dateien.

## Scope

Sechs Dateien, geschätzt +30/−5 Zeilen, davon drei reine Doku (über dem Richtwert 4–5 Dateien; die Überschreitung ist mit dieser Spec zur Freigabe vorgelegt, weil CLAUDE.md und die
Haupt-Spec eine Zeile nachtragen; Risiko niedrig, Manifest additiv).

| Datei | Änderung |
|-------|----------|
| `SmartCart/PrivacyInfo.xcprivacy` | siebter Eintrag `NSPrivacyCollectedDataTypeCoarseLocation`: Linked true, Tracking false, Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality` |
| `RestockTests/PrivacyManifestTests.swift` | `documented` um CoarseLocation (verknüpft); Test für den Standort-Satz in DE und EN |
| `SmartCart/Views/Settings/LegalView.swift` | Abschnitt „Open Prices“: ein Satz zum ungefähren Aufenthaltsort |
| `docs/appstore/datenschutz.md` | `## Deutsch` wortgleich zu `LegalView`, `## English` übersetzt |
| `docs/specs/appstore/app-store-auftritt.md` | Tabelle +1 Zeile; Absatz „Standort“ unter „Nicht deklariert“ durch die Entscheidung ersetzt |
| `CLAUDE.md` | „sechs“ → „sieben“ Datenarten |

Nicht im Umfang: Info.plist-Berechtigungen (es gibt keinen Gerätestandort), Verhalten der App, Fragebogen in App Store
Connect (bereits veröffentlicht), Datenschutzseite des Dritten, Stand „Oktober 2026“ (bleibt).

## Implementation Details

**Manifest.** Neuer Eintrag in `NSPrivacyCollectedDataTypes`, gleiche Form wie die sechs vorhandenen:
`NSPrivacyCollectedDataType` = `NSPrivacyCollectedDataTypeCoarseLocation`, `NSPrivacyCollectedDataTypeLinked` = true,
`NSPrivacyCollectedDataTypeTracking` = false, `NSPrivacyCollectedDataTypePurposes` =
`[NSPrivacyCollectedDataTypePurposeAppFunctionality]`. Die Schreibweise des Schlüssels wird vor dem Eintragen gegen Apples
Dokumentation bzw. den Xcode-Manifest-Editor geprüft (Fremdquellen nennen sie so, Apples eigene Seite war nicht auffindbar).

**Text.** Im Absatz „Open Prices“ folgt auf „… Preis (Lizenz ODbL).“ der Satz: „Die Filiale ist dort öffentlich sichtbar
und lässt deinen ungefähren Aufenthaltsort erkennen.“ Englisch: „The branch is publicly visible there and reveals your
approximate whereabouts.“ Der Absatz „Community-Preise“ bleibt unverändert („ohne Filiale oder Standort“ stimmt dort weiter).

## Expected Behavior

- **Input:** Release-Build mit dem neuen Manifest.
- **Output:** Das Manifest nennt sieben Datenarten, die Erklärung in App und auf der Seite nennt den Standortbezug der
  Open-Prices-Filiale, Fragebogen und Manifest sind deckungsgleich.
- **Side effects:** keine; kein neuer Berechtigungsdialog, keine Änderung an Speicher, Schlüsseln oder Netzverkehr.

## Alternativen (zum bisherigen Weg)

1. **Nur Manifest und Test, Erklärung unverändert:** weniger Aufwand, aber die Erklärung schwiege zu einer Angabe, die der
   Fragebogen macht. Nicht empfohlen.
2. **Standort nicht deklarieren** (Gegenmeinung der Haupt-Spec): würde den veröffentlichten Fragebogen erneut ändern und die
   Wahl des PO vom 2026-10-27 kippen. Nicht empfohlen.
3. **Empfehlung (diese Spec):** Manifest, Test, Satz in der Erklärung (de/en), Doku.

Kein Sprachmodell im Spiel; alles ist feste Konfiguration und Text.

## Acceptance Criteria

- **AC-1:** Vorbedingung: Manifest `SmartCart/PrivacyInfo.xcprivacy` im Bundle. Aktion: Plist parsen. Ergebnis: genau sieben
  Datentypen, die bisherigen sechs unverändert plus `NSPrivacyCollectedDataTypeCoarseLocation` (verknüpft true), je Zweck
  `NSPrivacyCollectedDataTypePurposeAppFunctionality`, `NSPrivacyCollectedDataTypeTracking` false.
  - Test: `RestockTests/PrivacyManifestTests.swift::testCollectedDataTypesEqualDocumentedList`
- **AC-2:** `NSPrivacyTracking` false, Tracking-Domains leer, UserDefaults-Reason `1C8F.1` und die Aussage „EAN nicht deklariert“
  bleiben; die Typmenge entspricht der Soll-Liste (sieben).
  - Test: `RestockTests/PrivacyManifestTests.swift::testTrackingFalseAndUserDefaultsReasonKept`, `::testNoBarcodeDataTypeDeclared`
- **AC-3:** Der Open-Prices-Absatz in `LegalView` enthält den Standort-Satz („ungefähren Aufenthaltsort“); der Absatz
  „Community-Preise“ enthält weiter „ohne Filiale oder Standort“; „Stand: Oktober 2026“ bleibt.
  - Test: `RestockTests/PrivacyManifestTests.swift::testOpenPricesParagraphNamesApproximateLocation` (neu anzulegen in RED, existiert noch nicht)
- **AC-4:** `docs/appstore/datenschutz.md` enthält den deutschen Satz wortgleich in `## Deutsch` (Drift gegen `LegalView`) und die
  englische Übersetzung („approximate whereabouts“) in `## English`.
  - Test: `scripts/test_asc_texts.py::test_privacy_page_equals_legalview` (Drift DE),
    `RestockTests/PrivacyManifestTests.swift::testOpenPricesParagraphNamesApproximateLocation` (EN, neu anzulegen in RED)
- **AC-5:** Das Manifest im Release-Bundle (Release-Übersetzung für den Simulator) stimmt mit der Quelle überein und enthält die
  sieben Typen.
  - Test: `RestockTests/PrivacyManifestTests.swift::testManifestIsPartOfBundle`
  - Nachweis: `plutil -p Restock.app/PrivacyInfo.xcprivacy` am Release-Bundle (Release-Übersetzung für den Simulator, `xcodebuild build -configuration Release`, Ort unter dem Derived-Data-Pfad des Laufs), Ausgabe in
    `docs/artifacts/feat-175-manifest-standort/release-manifest-check.txt`
- **AC-6:** Doku gleichgezogen: Tabelle „Deklarierte Datentypen“ der Haupt-Spec hat sieben Zeilen (neu Standort › Ungefährer
  Standort, `NSPrivacyCollectedDataTypeCoarseLocation`, verknüpft ja), der Absatz „Standort“ unter „Nicht deklariert“ ist durch
  die Entscheidung ersetzt, `CLAUDE.md` nennt sieben Datenarten.
  - Nachweis (Befehl, kein Test): `grep -c CoarseLocation docs/specs/appstore/app-store-auftritt.md` ≥ 1 und `grep "sieben Datenarten" CLAUDE.md`
- **AC-7:** Unit-Suite grün, `scripts/test_asc_texts.py` grün.
  - Nachweis: `xcodebuild test` auf `Restock-Validate`, erwartet Testzahl > 0, 0 Fehlschläge, kein Runner-Abbruch; Python-Test grün

## Test Plan

RED zuerst: `documented` auf sieben erweitern und den neuen Test schreiben, beide schlagen fehl, solange Manifest und Text
fehlen. Dann Manifest und Text, danach grün. Release-Nachweis wie in A1.

## Known Limitations

- Die Datenschutzseite bei `emmrich-business.com` pflegt ein Dritter; sie zeigt den neuen Satz erst, wenn er ihn übernimmt.
- Der Schlüsselname stützt sich bis zur Gegenprüfung auf Fremddokumentation.
- Nichts auf Hennings Geräten geprüft; der Fragebogen selbst wird hier nicht erneut gelesen (Beleg vom 2026-10-28).

## Changelog

- 2026-10-28 (Umsetzung): AC-6 gilt für die Haupt-Spec nur als Changelog-Zeile. Deren Freigabe-Sperre (`edit_gate`, Workflow feat-175-a2-berechtigungstexte, phase8_complete) lässt Tabelle, Absatz „Standort“ und die „sechs“ in AC-1/AC-3/AC-14 nur mit neuer Freigabe ändern. Der Changelog-Eintrag in `app-store-auftritt.md` nennt die Entscheidung; maßgeblich für die sieben Datentypen ist diese Spec. Die Grep-Probe für `CLAUDE.md` lautet „sieben erhobene Datenarten“.

- 2026-10-28: Erstfassung, Fortschreibung von #175 Durchgang A1.
