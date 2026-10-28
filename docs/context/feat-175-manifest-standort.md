# Context: feat-175-manifest-standort

## Request Summary
Der App-Privacy-Fragebogen in App Store Connect wurde am 2026-10-28 mit sieben Datentypen veröffentlicht, darunter
„Ungefährer Standort“ (verknüpft, App-Funktionalität, kein Tracking; Beleg `docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg`,
PO-Wahl per Auswahl am 2026-10-27). Das Manifest der App kennt den Standort noch nicht (sechs Typen). Es muss vor Build 37 gleichziehen.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/PrivacyInfo.xcprivacy` | sechs `NSPrivacyCollectedDataType`-Einträge; neu `NSPrivacyCollectedDataTypeCoarseLocation`, Linked true, Tracking false, Zweck AppFunctionality |
| `RestockTests/PrivacyManifestTests.swift` | `documented` (Zeile 9–16) ist die Soll-Liste; AC-1 vergleicht Manifest gegen Liste, AC-4 prüft den Open-Prices-Absatz in `LegalView` (Begriffe Bonfoto, Filiale, Preis, Nutzername) |
| `SmartCart/Views/Settings/LegalView.swift` | Datenschutztext (de), Abschnitt „Open Prices“ (Z. 85–86) nennt die Filiale als OpenStreetMap-Ort; Stand „Oktober 2026“ |
| `docs/appstore/datenschutz.md` | `## Deutsch` wortgleich mit `LegalView`, `## English` Übersetzung (Z. 38–39 DE, 122–123 EN); wer `LegalView` ändert, ändert die Seite mit (CLAUDE.md B1) |
| `docs/specs/appstore/app-store-auftritt.md` | Tabelle „Deklarierte Datentypen“ (Z. ~105), Abschnitt „Nicht deklariert, begründet“ (Standort-Absatz, Gegenmeinung) – Entscheidung nachtragen |
| `CLAUDE.md` (Projekt) | Abschnitt „Datenschutz-Manifest …“ nennt sechs Datenarten, muss auf sieben |

## Existing Patterns
- Eine Datenart ändern heißt Manifest, Test, `LegalView`, Spec und App-Privacy-Fragebogen gemeinsam (CLAUDE.md, #175 A1). Der Fragebogen ist jetzt schon erledigt.
- `PrivacyManifestTests` liest das Manifest aus dem Bundle, `LegalView` als Quelltext; Tests laufen als Unit-Test ohne Simulator-UI.
- Release-Nachweis des Manifests per `docs/artifacts/feat-175-app-store-auftritt/release-manifest-check.txt` (Strings/Bundle des Release-Builds).

## Dependencies
- Upstream: Open-Prices-Beitrag (`OpenPricesContributionService`, Filiale aus Nominatim); die App liest keinen Gerätestandort (keine Standort-Berechtigung in Info.plist).
- Downstream: Build 37 (Manifest geht ins Bundle), Datenschutzseite des Dritten (Text aus `datenschutz.md`), App-Store-Fragebogen (bereits stimmig).

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (Durchgang A1: Manifest-Tabelle; Fragebogen-Entscheidung zum Standort steht dort als offen mit Gegenmeinung)

## Risks & Considerations
- Text der Datenschutzerklärung darf nicht behaupten, es werde „kein Standort“ verarbeitet: Z. 83 sagt für Community-Preise „ohne Filiale oder Standort“ (bleibt richtig, betrifft nur Community), der Open-Prices-Absatz braucht einen Satz, dass die gewählte Filiale den ungefähren Aufenthaltsort erkennen lässt (öffentlich sichtbar).
- Der Standort-Typ im Manifest (CoarseLocation) und im Fragebogen (Ungefährer Standort) müssen deckungsgleich bleiben.
- `datenschutz.md` DE-Abschnitt muss wortgleich zu `LegalView` bleiben (Drift-Prüfung existiert in `scripts/test_asc_texts.py`/PrivacyManifestTests – in der Analyse zu bestätigen).
- Stand „Oktober 2026“ bleibt (Monat unverändert).
- Umfang schätzungsweise 5 Dateien, ~25 Zeilen; unter den Limits.

## Analysis

### Type
Feature (Angleichung Manifest/Texte an den bereits veröffentlichten App-Privacy-Fragebogen; kein Fehler, nichts Sichtbares im UI → keine Entwurfsvorschau nötig, nur Text in der Datenschutzansicht).

### Recherche
Der Schlüssel `NSPrivacyCollectedDataTypeCoarseLocation` ist laut Fremddokus (Unity, Fingerprint) der Manifest-Typ für „Ungefährer Standort“ (gröber als Breite/Länge mit 3 Nachkommastellen). Apples eigene Seite „Describing data use in privacy manifests“ kam in der Suche nicht; vor der Umsetzung gegen sie bzw. gegen den Xcode-Manifest-Editor gegenprüfen (Schlüssel-Schreibweise).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/PrivacyInfo.xcprivacy | MODIFY | siebter Eintrag CoarseLocation (Linked true, Tracking false, AppFunctionality) |
| RestockTests/PrivacyManifestTests.swift | MODIFY | `documented` um CoarseLocation (linked true); AC-4 um Standort-Satz |
| SmartCart/Views/Settings/LegalView.swift | MODIFY | Open-Prices-Absatz: ein Satz, dass die öffentlich sichtbare Filiale den ungefähren Aufenthaltsort erkennen lässt |
| docs/appstore/datenschutz.md | MODIFY | DE wortgleich zu LegalView (Drift-Test `test_asc_texts.py` AC-9d erzwingt es), EN-Übersetzung |
| docs/specs/appstore/app-store-auftritt.md | MODIFY | Tabelle +1 Zeile, Standort-Absatz „Nicht deklariert“ → Entscheidung (PO 2026-10-27: Ungefährer Standort) |
| CLAUDE.md | MODIFY | „sechs“ → „sieben“ Datenarten |

### Scope Assessment
- Files: 6 (davon 3 reine Doku/Spec) — knapp über „4–5“, ~+30/−5 LoC
- Risk Level: LOW (Manifest additiv; Tests prüfen Manifest im Bundle)

### Technical Approach (Regelweg, kein Modell)
Reine Konfigurations-/Textänderung. Reihenfolge: Test-Soll (RED: Anzahl 7 / CoarseLocation fehlt) → Manifest → LegalView + datenschutz.md DE/EN → Spec/CLAUDE.md. Release-Nachweis des Manifests im Bundle wie in A1 wiederholen.

### Alternativen
1. Nur Manifest + Test, Datenschutztext unverändert: weniger Aufwand, aber die Erklärung sagt dann nichts über den Standortbezug, obwohl der Fragebogen ihn deklariert → Inkonsistenz, nicht empfohlen.
2. Standort nicht deklarieren (Spec-Gegenmeinung kippen): widerspricht dem veröffentlichten Fragebogen; würde bedeuten, den Fragebogen erneut zu ändern. Kippt die PO-Wahl vom 2026-10-27.
3. Empfehlung: Manifest + Test + Satz in Text (DE/EN) + Spec.

### Dependencies
Build 37 (Manifest geht ins Bundle, Upload bei Henning); Datenschutzseite des Dritten braucht den neuen Absatz (Text aus `datenschutz.md`). Parallel liegt Workflow `feat-175-b3-eintragen` in Phase 6 – nicht angefasst, getrennte Dateien.

### Open Questions
- [ ] Wortlaut des Zusatzsatzes (Vorschlag: „Die gewählte Filiale ist öffentlich sichtbar und lässt deinen ungefähren Aufenthaltsort erkennen.“) – technisch, Claude entscheidet.
- [ ] Gegenprüfung Schlüsselname gegen Apple/Xcode in Phase RED.
