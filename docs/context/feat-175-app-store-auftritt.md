# Context: feat-175-app-store-auftritt

Stand: 2026-10-23, `origin/main` @ 95724f1 (Build 36, Version 1.0).

## Request Summary
Issue #175 (Meilenstein „Öffentliches Release 1.0“): Alles, was Apple neben dem Build für die
Veröffentlichung verlangt, in App Store Connect ausfüllen — Produktseite (de, en), Datenschutzangaben
(App Privacy) samt Datenschutz-URL, iPhone-Screenshots, In-App-Kauf „Restock Pro“ anlegen und
einreichen. Definition of Done: ein Build ist ohne fehlende Pflichtangaben zur Prüfung einreichbar.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/PrivacyInfo.xcprivacy` | Erklärt `NSPrivacyCollectedDataTypes` = leer („collects no data“). Widerspricht seit Community-Preisen (#163) und geteilten Läden der Wirklichkeit; muss mit den App-Privacy-Angaben übereinstimmen. Nur Required-Reason-API `UserDefaults` (1C8F.1) deklariert. |
| `SmartCart/Views/Settings/LegalView.swift` | Datenschutzerklärung (Stand „Juni 2026“, **nur Deutsch, nur in der App**) und Impressum. Enthält schon: iCloud, Barcode/Open Food Facts, Geteilte Listen (Public DB), Community-Preise, StoreKit, kein Tracking. |
| `SmartCart/Services/CommunityPriceService.swift` | Schreibt `CommunityPrice` (itemKey, chain, price, unit, observedAt, clientID) in die öffentliche CloudKit-DB. `clientID` = zufällige Kennung je Installation → für Apple-Kategorie „Kennungen“ zu bewerten. |
| `SmartCart/Services/SharedStoreService.swift`, `SharedItemPhotoService.swift` | Geteilte Läden: Artikel, Preise, Anzeigenamen der Mitglieder, Fotos (`_ckAsset`) in der öffentlichen DB. |
| `SmartCart/Views/Settings/OnboardingView.swift` | Nutzt CloudKit (Onboarding-Wartezeit, #156). |
| `SmartCart/Services/PremiumService.swift` | Produkte im Code: `…premium.monthly`, `…premium.yearly`, `…premium.lifetime` (`knownIDs`). |
| `Restock.storekit` | Test-Konfiguration: zusätzlich `…sharedlists` (4,99) — im Code **nicht** in `knownIDs`. Preise: Lifetime 14,99, Monat 1,99, Jahr 8,99. |
| `project.yml` | `TARGETED_DEVICE_FAMILY: 1` (nur iPhone, bei App und Widget), `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 36`, Kamera-/Fotos-Texte nur auf Englisch (Zeilen 36–37), Bundle-ID `com.johannesemmrich.Restock`. |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | Zweisprachige App; Store-Texte müssen dazu passen. |
| `docs/testflight-setup.md` | ASC-API-Schlüssel (Rolle Admin) liegt als Repo-Secret für den TestFlight-Ablauf; lokal Schlüssel in Downloads (Inhalt nie lesen). Ablauf `.github/workflows/testflight.yml`. |
| `SmartCart/Views/Settings/SettingsView.swift` | Support-Mailadresse `support@emmrich-business.com`; Link `https://emmrich-business.com` im Impressum. |

## Existing Patterns
- Rechtstexte stehen als String in `LegalView`; es gibt keine öffentliche Webseite im Repo.
- Verantwortlicher/Anbieter ist **Johannes Emmrich**, Domain **emmrich-business.com** (nicht henemm.com;
  meine Annahme im Intake war falsch und wird in der Analyse korrigiert).
- Entscheidungen zu CloudKit-Schema laufen über `docs/testflight-setup.md` und cktool/Actions.
- Ergebnisse mit Beleg werden unter `docs/artifacts/<workflow>/` abgelegt.
- UI-Entwurf-vor-Spec gilt für sichtbare App-Änderungen; für Store-Seite sinngemäß: Texte und Screenshots vorab zeigen.

## Dependencies
- Upstream: #99 (nur iPhone, geschlossen), #145 D4 (Kauf per StoreKit, geschlossen), #186/#163 (Community-Preise mit Opt-in-Hinweis), #187 (Gerätetest Build 33 — offen, liefert reale Screenshots).
- Downstream: Release 1.0 selbst; jede Änderung an `PrivacyInfo.xcprivacy` oder `project.yml` braucht einen neuen Build (Build-Nummer > 36) und Upload.

## Existing Specs
- `docs/specs/` enthält Unterordner `ci`, `fast`, `models`, `services`, `testing`, `ui-tests`, `views`; keine Spec zu App-Store-Inhalten.
- Kontext-Dokumente zu Nachbarthemen: `feat-186-preisteilen-hinweis.md`, `feat-208-community-nacharbeiten.md`, `test-145-d4-kauf-wiederherstellen.md`.

## Risks & Considerations
- **Ehrliche Datenschutzangaben:** Public-DB-Schreibzugriffe (Community-Preise mit Zufalls-ID, geteilte Läden mit Anzeigenamen/Fotos) müssen in App Privacy als erhobene Daten erscheinen oder begründet als nicht erhoben gelten. Falsche Angabe = Ablehnung/Rechtsrisiko. Einordnung der Apple-Kategorien (Kennungen, Nutzerinhalte, Käufe) braucht Recherche in Apples eigener Doku (Analyse-Schritt 1).
- **Manifest und App-Privacy müssen übereinstimmen**; Manifest ändern = neuer Build.
- **Datenschutz-URL fehlt:** Apple verlangt eine öffentliche Adresse; der Text liegt nur in der App und nur auf Deutsch (Store-Seite hat auch Englisch).
- **Wo liegt die URL?** Hosting auf emmrich-business.com gehört dem Sohn/Anbieter; Zugang ungeklärt.
- **Kauf-Produkte uneins:** Ticket sagt „Restock Pro“; Code kennt Monat/Jahr/Lifetime; `sharedlists` nur in der Test-Datei. Welche Produkte in ASC angelegt werden, muss vor der Spec feststehen (PO-Thema: Preise, Angebot).
- **Kamera-/Fotos-Texte nur englisch** in `project.yml` — App Review liest sie; Lokalisierung prüfen.
- **ASC-Zugriff:** Was per API-Schlüssel automatisierbar ist (Metadaten, Preise, Kauf), ist ungeprüft; Screenshots und Altersfreigabe gehen ggf. nur im Browser. Fehlender Zugriff wird repariert, nicht an Henning weitergereicht.
- **Screenshots** brauchen realistische Daten und sollten nach dem Gerätetest #187 oder im Simulator mit Seed entstehen; nur iPhone (6,9" und 6,5"-Größen prüfen).
- **Keine Gerätezugriffe** ohne Hennings Wort „jetzt ist ein Test möglich“ (Simulator ist frei).
- **Scope-Limits:** Code-Anteil klein (Manifest, Rechtstext, evtl. Lokalisierung); Hauptarbeit ist Eintragen in ASC. Texte/Artefakte im Repo ablegen, damit nach `/clear` auffindbar.

## Analysis

### Type
Feature (überwiegend Konfiguration in App Store Connect, kleiner Code-Anteil).

### Recherche (2026-10-23, vor allem anderen)
- Apple, App Privacy Details (developer.apple.com/app-store/app-privacy-details): „Collect“ = Daten verlassen das Gerät und sind für den Entwickler länger zugänglich, als die Anfrage dauert. Nur auf dem Gerät Verarbeitetes zählt nicht. Auch Erhebung „nur für die App-Funktion“ ist anzugeben. Die „optionale Offenlegung“ braucht alle fünf Kriterien (u. a. nur seltene Fälle, jedes Mal ausdrückliche Wahl) — Community-Preise (voreingestellt an, laufend) erfüllen sie nicht. Eigene CloudKit-Daten sind in der Seite nicht ausdrücklich geregelt; nach der Definition gelten sie als erhoben (Schlussfolgerung, nicht wörtlich belegt). Die private iCloud-Spiegelung zählt nicht (Zugriff nur der Nutzer).
- Apple, App Store Connect Help „Manage app privacy“: Privacy-Policy-URL ist Pflicht; Angaben werden erst mit „Publish“ wirksam; Rolle Account Holder/Admin/App Manager. Ob die Datenschutz-Fragebögen per API setzbar sind, ist nicht belegt (Privacy-URL per `appInfoLocalizations.privacyPolicyUrl` wahrscheinlich ja).
- Screenshots: nur ein Satz iPhone 6,9" (1320×2868, auch 1290×2796/1260×2736) nötig, kleinere werden abgeleitet; 1–10 Bilder je Sprache, PNG/JPEG (Drittquellen, in ASC gegenprüfen).
- In-App-Kauf: Review-Screenshot ist Pflicht, bevor er eingereicht werden kann; erstes Abo muss mit einer App-Version eingereicht werden (Foren-Berichte).

### Ist-Stand in App Store Connect (per API gelesen, nur GET, 2026-10-23)
App `6790839680` (Name „Restock“, Hauptsprache de-DE), Version 1.0 `PREPARE_FOR_SUBMISSION`.
Alles leer: Beschreibung, Schlüsselwörter, Support-URL, Untertitel, Datenschutz-URL, Kategorie, Altersfreigabe; nur Sprache de-DE angelegt (en fehlt). Keine In-App-Käufe, keine Abo-Gruppe. Der API-Schlüssel (Key K928C9Z9P2) kann lesen; Schreibzugriff ist für Metadaten wahrscheinlich, nicht belegt.

### Befunde
1. **Datenschutz-URL existiert, ist aber falsch.** `emmrich-business.com/datenschutz` (Stand September 2026) sagt, geteilte Listen liefen über die *private* CloudKit-Datenbank, „wir haben keinen Zugriff“. Tatsächlich: Eigenbau auf der **öffentlichen** DB (#121), dazu Community-Preise (#163) und Fotos. Kein Wort zu Bon-Scan, Kamera, Community-Preisen. Englische Datenschutzseite fehlt (`/en/datenschutz` liefert die Startseite). Die In-App-Erklärung (`LegalView`, Stand Juni 2026) ist inhaltlich richtig, nur Deutsch.
2. **`PrivacyInfo.xcprivacy` sagt „collects no data“** und widerspricht dem Code. Zu erklären (Entwurf, vom PO nicht zu entscheiden, aber in der Spec zu belegen): Verknüpft mit Nutzer — Name (Anzeigename in geteilten Läden), Sonstige Nutzerinhalte (Listen, Artikel), Fotos (Artikelfotos geteilter Läden); nicht verknüpft — Kaufverlauf (Community-Preise je Artikel/Kette), Kennungen (Installationskennung `clientID`). Zweck jeweils App-Funktionalität, Tracking nein. Offene Einordnung: EAN an Open Food Facts (Produktnummer, keine Nutzerdaten; Entwurf: nicht deklarieren, in der Spec begründen).
3. **Kamera-/Fotos-Texte nur Englisch** (`project.yml` 36–37, keine `InfoPlist.strings`) und nennen nur „recipe photos“, obwohl die Kamera auch für Bons und Barcodes dient. App Review liest sie; deutsche Nutzer sehen englischen Text.
4. **Kauf-Produkte:** Code kennt Monat/Jahr/Lifetime (1,99 / 8,99 / 14,99 laut `Restock.storekit`); `sharedlists` (4,99) steht nur in der Testdatei. In ASC ist nichts angelegt.
5. **Manifest- und Textänderung = neuer Build (37)** und Upload; Production-Schema ist von #175 nicht berührt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/PrivacyInfo.xcprivacy` | MODIFY | `NSPrivacyCollectedDataTypes` an Befund 2 anpassen |
| `project.yml` + `Restock.xcodeproj/project.pbxproj` | MODIFY | Kamera-/Fotos-Texte vollständig; Build-Nummer 37 |
| `SmartCart/Resources/{de,en}.lproj/InfoPlist.strings` | CREATE | Lokalisierte Berechtigungstexte (in pbxproj eintragen) |
| `SmartCart/Views/Settings/LegalView.swift` | MODIFY (klein) | Fotos geteilter Artikel und Stand ergänzen |
| `RestockTests/PrivacyManifestTests.swift` | CREATE | Manifest ↔ dokumentierte Datentypen, Texte in beiden Sprachen |
| `docs/appstore/{de,en}/…` | CREATE | Texte (Name, Untertitel, Beschreibung, Schlüsselwörter, Datenschutzseite) im Repo |
| `scripts/asc_*.py` | CREATE | Schreibender ASC-Ablauf (Metadaten, Screenshots, Kauf) mit Gegenlesen |
| ASC (extern) | CONFIGURE | Produktseite de/en, Kategorie, Altersfreigabe, Datenschutz-URL, Privacy-Fragebogen, Screenshots, In-App-Käufe |

### Scope Assessment
- Repo-Dateien: ~5 Code + Dokumente/Skripte; Code ca. +80/-5, Skripte/Texte getrennt zu zählen (LoC-Gate zählt Skripte als Produktivcode → ggf. in zwei Durchgänge teilen: A = Code/Manifest, B = ASC-Ablauf).
- Risk Level: MEDIUM (falsche Privacy-Angabe = Ablehnung/Rechtsrisiko; Einreichung selbst ist outward-facing und braucht Hennings Wort).

### Technical Approach
Regeln vor Modell/Automatisierung: Texte und Manifest als Dateien im Repo, ASC-Befüllung per API-Skript mit Gegenlesen (Muster wie TestFlight-„Was testen?“); was die API nicht kann (vermutlich Privacy-Fragebogen, ggf. Altersfreigabe-Rest), per Browser (Chrome-Werkzeug) mit Beleg-Screenshots. Screenshots aus dem Simulator (iPhone 18 Pro Max, `-premiumForScreenshots`, Seed-Daten), nicht vom Gerät. Kein Einreichen (Submit) ohne ausdrückliches Wort.
Alternative zum Plan: Datenschutz-Seite statt auf emmrich-business.com in ein eigenes, vom Repo gehostetes Dokument zu legen (kippt: Repo-Besitz beim Sohn, keine Admin-Rechte). Alternative zum Datenerheben: Community-Preise-Standard auf „aus“ → „optionale Offenlegung“ wäre dennoch nicht erfüllt, spart nichts.

### Dependencies
#99, #145 D4, #163/#186, #187 (Gerätetest, nicht nötig für Simulator-Screenshots); #175 blockiert Release 1.0.

### Open Questions
- [ ] (PO 2026-10-23: „Unklar“ — Tech Lead klärt; Spec hält die URL bis dahin offen) Wer kann `emmrich-business.com` ändern (Datenschutzseite berichtigen, englische Fassung, Support-URL)? Ohne das ist die Datenschutz-URL falsch.
- [x] (PO 2026-10-23: ja, drei Produkte) Angebot in 1.0: drei Produkte aus dem Code (1,99/8,99/14,99) so anlegen? `sharedlists` entfällt.
- [ ] Texte der Produktseite: Entwurf wird vor der Spec gezeigt (Regel „Vorschau“).
