---
entity_id: app-store-auftritt
type: feature
created: 2026-10-23
updated: 2026-10-24
status: draft
version: "1.0"
workflow: feat-175-app-store-auftritt
tags: [feature, appstore, datenschutz, privacy-manifest, release-1-0, issue-175]
---

# App-Store-Auftritt für Release 1.0 (Issue #175)

## Approval

- [ ] Approved

Beschlüsse des PO, hier übernommen und nicht neu verhandelt: Drei Kauf-Produkte (monatlich, jährlich, Lifetime zu
1,99 / 8,99 / 14,99 €), `sharedlists` entfällt; nur iPhone; **Einreichen („Submit for Review“) und alles
Außenwirksame nur auf ausdrückliches Wort von Henning**; keine Zugriffe auf Hennings Geräte (Simulator ist frei);
Verantwortlicher ist Johannes Emmrich, Domain `emmrich-business.com`.
Quelle: `docs/context/feat-175-app-store-auftritt.md` (Stand 2026-10-23, `origin/main` @ 95724f1, Build 36).

## Purpose

Apple verlangt neben dem Build Produktseite (de, en), Datenschutzangaben samt öffentlicher Datenschutz-URL, Screenshots,
Kategorie, Altersfreigabe und angelegte In-App-Käufe. Heute ist in App Store Connect (ASC) für Version 1.0 alles leer, und
die App sagt in ihrem Datenschutz-Manifest „erhebt keine Daten“, was seit Community-Preisen (#163) und geteilten Läden
(#121) nicht stimmt. Diese Spec macht ein Build **ohne fehlende Pflichtangaben einreichbar** (Definition of Done des
Tickets) und hält die Angaben im Repo fest, damit ASC, Manifest und In-App-Datenschutzerklärung übereinstimmen.

Hat es bisher funktioniert? Es ist keine Verschlechterung, sondern eine nie gemachte Pflichtarbeit; das Manifest stammt
aus der Zeit vor #121/#163.

## Befunde (belegt im Kontextdokument)

1. Die bestehende Seite `emmrich-business.com/datenschutz` (Stand September 2026) ist inhaltlich falsch: sie beschreibt
   geteilte Listen über die *private* CloudKit-Datenbank, tatsächlich laufen sie über die **öffentliche** (#121); kein Wort
   zu Bon-Scan, Kamera, Community-Preisen, Fotos. Eine englische Seite fehlt.
2. `SmartCart/PrivacyInfo.xcprivacy` enthält `NSPrivacyCollectedDataTypes` = leer; deklariert ist nur die Required-Reason-API
   `UserDefaults` (1C8F.1).
3. Kamera-/Fotos-Texte stehen nur englisch in `project.yml` (`INFOPLIST_KEY_NSCameraUsageDescription` /
   `…NSPhotoLibraryUsageDescription`) und nennen nur „recipe photos“, obwohl die Kamera auch Bons und Barcodes liest.
4. Code kennt drei Produkte (`PremiumService.knownIDs` = monthly, yearly, lifetime); `sharedlists` steht nur in
   `Restock.storekit`. In ASC ist nichts angelegt.
5. Die Nutzungsbedingungen in `LegalView` (Abschnitt 3) nennen noch ein „Geteilte Listen Add-on“ als Einmalkauf, das es nicht
   mehr gibt (Beschluss: `sharedlists` entfällt). Das ist ein Widerspruch zu den angelegten Produkten und wird in Durchgang A
   mit berichtigt.
6. Ein Manifest- oder Texteingriff verlangt einen neuen Build (37) samt Upload.

## Source

- **File:** `SmartCart/PrivacyInfo.xcprivacy`, `SmartCart/Views/Settings/LegalView.swift`, `project.yml`,
  `SmartCart/Resources/{de,en}.lproj/InfoPlist.strings` (neu), `docs/appstore/{de,en,datenschutz}.md` (neu), `scripts/asc_*.py` (neu)
- **Identifier:** `NSPrivacyCollectedDataTypes`, `LegalView.privacyPolicy`/`termsOfUse`, `CURRENT_PROJECT_VERSION`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PremiumService.knownIDs` | Code | Produkt-IDs der drei Käufe in ASC (monthly, yearly, lifetime) |
| `CommunityPriceService`, `SharedStoreService`, `SharedItemPhotoService` | Code | Quelle der zu deklarierenden Datentypen |
| `LocalizationKeyParityTests` | Test | muss grün bleiben |
| App Store Connect API (Schlüssel Admin, Inhalt nie gelesen) | Extern | Setzen und Gegenlesen der Angaben |
| `emmrich-business.com` | Extern | öffentliche Datenschutz- und Support-URL (Zugang offen) |
| #99, #145 D4, #163/#186, #187 | Tickets | siehe Abschnitt „Abhängigkeiten (Tickets)“ am Ende |

## Scope

Drei Durchgänge, jeder mit höchstens 5 Dateien und ±250 LoC (Texte und Skripte zählt das LoC-Gate als Produktivcode, daher
die Trennung). Reihenfolge A1, A2, B. Der Upload von Build 37 ist außenwirksam und folgt nur Hennings ausdrücklichem Wort.

- **Affected Files:** Vereinigung aller Durchgänge A1, A2, B1, B2a, B2b, B3 (Einzellisten in den Unterabschnitten).
- **Estimated Changes:** ~90 (A1) + ~47 (A2) + ~220 (B1) + ~330 (B2a, über dem Limit, vom PO am 2026-10-24 angenommen) + ~190 (B2b) + ~0 (B3) = ca. 877 LoC gesamt.

### Durchgang A1: Manifest und Rechtstext (4 Dateien, geschätzt +85/−6 Zeilen)

- **Affected Files:** `SmartCart/PrivacyInfo.xcprivacy`, `SmartCart/Views/Settings/LegalView.swift`,
  `RestockTests/PrivacyManifestTests.swift`, `Restock.xcodeproj/project.pbxproj`
- **Estimated Changes:** ~90 LoC

| Datei | Änderung |
|-------|----------|
| `SmartCart/PrivacyInfo.xcprivacy` | `NSPrivacyCollectedDataTypes` mit sechs Einträgen (Tabelle unten) |
| `SmartCart/Views/Settings/LegalView.swift` | Datenschutz: Fotos geteilter Artikel, Stand neu; Nutzungsbedingungen: Zeile „Geteilte Listen Add-on“ entfernen |
| `RestockTests/PrivacyManifestTests.swift` | NEU: Manifest, Tracking, Bundle, LegalView |
| `Restock.xcodeproj/project.pbxproj` | Testdatei registrieren (PBXBuildFile, PBXFileReference, Gruppe, Sources-Phase) |

### Durchgang A2: Lokalisierte Berechtigungstexte und Build 37 (5 Dateien, geschätzt +45/−2 Zeilen)

- **Affected Files:** `SmartCart/Resources/de.lproj/InfoPlist.strings`, `SmartCart/Resources/en.lproj/InfoPlist.strings`,
  `project.yml`, `Restock.xcodeproj/project.pbxproj`, `RestockTests/PrivacyManifestTests.swift`
- **Estimated Changes:** ~47 LoC

| Datei | Änderung |
|-------|----------|
| `SmartCart/Resources/de.lproj/InfoPlist.strings`, `…/en.lproj/InfoPlist.strings` | NEU: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` |
| `project.yml` | `CURRENT_PROJECT_VERSION` 36 → 37; englische `INFOPLIST_KEY_…` bleiben als Rückfall |
| `Restock.xcodeproj/project.pbxproj` | Strings-Dateien (Variant-Group, Ressourcen-Phase), Build-Nummer 37 |
| `RestockTests/PrivacyManifestTests.swift` | ergänzt: InfoPlist-Schlüssel, Build-Nummer |

Deklarierte Datentypen (Entwurf; Zweck jeweils App-Funktionalität, Tracking nein):

| Apple-Kategorie | Manifest-Schlüssel | Verknüpft | Woher im Code |
|-----------------|--------------------|-----------|---------------|
| Kontaktdaten › Name | `NSPrivacyCollectedDataTypeName` | ja | Anzeigename der Mitglieder in geteilten Läden (`SharedStoreService`) |
| Nutzerinhalte › Sonstige Nutzerinhalte | `NSPrivacyCollectedDataTypeOtherUserContent` | ja | Artikel, Listen, Zuweisungen, Preise geteilter Läden |
| Nutzerinhalte › Fotos oder Videos | `NSPrivacyCollectedDataTypePhotosorVideos` | ja | Artikelfotos geteilter Läden (`SharedItemPhotoService`, `_ckAsset`); Bonfoto beim Open-Prices-Beitrag (`OpenPricesContributionService`) |
| Käufe › Kaufverlauf | `NSPrivacyCollectedDataTypePurchaseHistory` | ja | Community-Preise je Artikel/Kette (`CommunityPriceService`); Preise und Filiale der Open-Prices-Beiträge, öffentlich unter dem Benutzernamen sichtbar |
| Kennungen › Nutzer-ID | `NSPrivacyCollectedDataTypeUserID` | ja | Open-Food-Facts-Benutzername der Open-Prices-Beiträge (Opt-in „Bons an Open Prices beitragen“, `SettingsView`, Standard aus, für alle Nutzer sichtbar) |
| Kennungen › Geräte-ID | `NSPrivacyCollectedDataTypeDeviceID` | nein | zufällige Installationskennung `clientID` der Community-Preise |

Nicht deklariert, begründet:

- **EAN an Open Food Facts:** eine Produktnummer, keine Angabe über den Nutzer; es wird keine Kennung mitgesendet.
- **Private iCloud-Spiegelung:** zählt nicht, weil nur der Nutzer selbst Zugriff hat (Apple: „Collect“ = Daten verlassen das
  Gerät und sind für den Entwickler zugänglich).
- **Standort:** Die Filiale beim Open-Prices-Beitrag ist ein vom Nutzer gewählter Laden (OpenStreetMap-Ort), kein Gerätestandort;
  die App liest keinen Gerätestandort. Deshalb wird kein Standort-Typ deklariert. Gegenmeinung: Konservativ ließe sich
  „Grober Standort“ deklarieren, weil ein Laden den Aufenthaltsort des Nutzers andeutet. Die Entscheidung fällt beim Fragebogen
  und wird im Test festgehalten.

Open Prices ist **nicht** unter „nicht deklariert“ geführt, sondern deklariert (Fotos, Kaufverlauf, Nutzer-ID): Apple zählt auch
Daten, die an Drittpartner gehen. Die Ausnahme „optionale Offenlegung“ greift nicht, weil sie voraussetzt, dass der Nutzer die
Weitergabe jedes Mal ausdrücklich wählt; der Opt-in ist ein dauerhafter Schalter. `NSPrivacyTracking` bleibt `false`, die
Tracking-Domains leer, die UserDefaults-Angabe unverändert.

### Durchgang B1: Store-Texte (3 Dateien, geschätzt +220 Zeilen)

- **Affected Files:** `docs/appstore/de.md`, `docs/appstore/en.md`, `docs/appstore/datenschutz.md`
- **Estimated Changes:** ~220 LoC (de.md ~55, en.md ~55, datenschutz.md zweisprachig ~110); kein App-Code, kein Build. Belegartefakt: `docs/artifacts/feat-175-b1-store-texte/laengen.txt`

| Datei | Änderung |
|-------|----------|
| `docs/appstore/de.md`, `docs/appstore/en.md` | NEU: je Sprache `name`, `subtitle`, `keywords`, `promotional_text`, `description`, `support_url`, `privacy_url` (feste, sprachneutrale Überschriften, damit B2a/B2b beide mit einem Parser lesen; kein „Was ist neu“, Apple bietet es für die erste Version nicht an) |
| `docs/appstore/datenschutz.md` | NEU: eine zweisprachige Seite, `## Deutsch` wortgleich mit `LegalView.privacyPolicy`, `## English` als Übersetzung (deutsche Fassung maßgeblich) |

### Durchgang B2a: Schreibskript und Sicherheitstest (3 Dateien, geschätzt +330 Zeilen)

PO-Schnitt vom 2026-10-24: B2 (vorher 5 Dateien, ~520 Zeilen) wird in B2a und B2b geteilt. B2a enthält alles, was außen
schreiben kann, samt dem Test, der das Schreiben einhegt (AC-10).

- **Affected Files:** `scripts/asc_lib.py`, `scripts/asc_publish.py`, `scripts/test_asc_scripts.py`
- **Estimated Changes:** ~330 LoC (asc_lib ~100, asc_publish ~120, Test ~110). Das liegt über ±250; der PO hat den Umfang am
  2026-10-24 ausdrücklich angenommen (ein Durchgang, Skript schreibt, Trockenlauf Standard). Offen vermerkt: Das
  LoC-Gate zählt Skripte als Produktivcode, die Schätzung kann abweichen.

| Datei | Änderung |
|-------|----------|
| `scripts/asc_lib.py` | NEU: `parse_texts(path)` (Abschnitte `## <name>` aus `docs/appstore/{de,en}.md`, von B2b wiederverwendet); `make_token(env, sign=…)` (ES256-JWT; Schlüsselpfad nur aus `ASC_KEY_PATH`, Key-ID und Issuer aus `ASC_KEY_ID`/`ASC_ISSUER_ID`; `aud` `appstoreconnect-v1`, `exp` ≤ `iat` + 1200 s; Signatur über `openssl dgst -sha256 -sign` als Argumentliste, DER nach R‖S (64 Byte) umgewandelt; `sign` injizierbar); `api(method, path, body, send=…)` (nur Host `api.appstoreconnect.apple.com`, nur GET/POST/PATCH, Pfad-Erlaubnisliste, Fehlermeldungen nur mit Status und Pfad, `send` injizierbar) |
| `scripts/asc_publish.py` | NEU: Ablauf siehe unten; Trockenlauf ist Standard, Schreiben nur mit `--apply` |
| `scripts/test_asc_scripts.py` | NEU: AC-10 und AC-10a bis AC-10h; `unittest`, nur Standardbibliothek, ohne Netz, ohne Schlüssel (Schein-`send`, Schein-`sign`) |

Ablauf von `asc_publish.py`:

1. Lesen und prüfen, noch ohne Schreiben: `GET /v1/apps?filter[bundleId]=com.johannesemmrich.Restock` (genau 1 Treffer);
   `GET /v1/apps/{id}/appStoreVersions?filter[versionString]=1.0&filter[platform]=IOS` (genau 1 Treffer mit
   `appVersionState` = `PREPARE_FOR_SUBMISSION`); `GET /v1/apps/{id}/appInfos` (genau 1 Eintrag mit `state` =
   `PREPARE_FOR_SUBMISSION`); dann `GET …/appStoreVersionLocalizations` und `GET …/appInfoLocalizations` dieser beiden Einträge.
   Jede Abweichung (0 oder mehr als 1 Treffer, anderer oder unbekannter Zustand) beendet das Skript mit Fehler, bevor es
   irgendetwas schreibt.
2. Feldzuordnung je Sprache (de-DE aus `de.md`, en-US aus `en.md`): `appStoreVersionLocalizations` ← `description`,
   `keywords`, `promotionalText` (`promotional_text`), `supportUrl` (`support_url`), **kein** `whatsNew`;
   `appInfoLocalizations` ← `name`, `subtitle`, `privacyPolicyUrl` (`privacy_url`).
3. Plan: je Sprache und Ressource `PATCH /v1/appStoreVersionLocalizations/{id}` bzw. `/v1/appInfoLocalizations/{id}` nur mit den
   abweichenden Feldern; fehlt die Sprache ganz, `POST` auf die jeweilige Sammlung mit Relationship auf die gelesene Version
   bzw. das gelesene appInfo; eine vorhandene Sprache bekommt nie ein `POST` (sonst 409). Gleiche Werte erzeugen keinen Aufruf.
4. Ausgabe: der Plan (Feld, alt, neu, Aktion). Ohne `--apply` endet das Skript hier (Trockenlauf, Exit 0). Mit `--apply` werden
   die Aufrufe des Plans nacheinander ausgeführt; der erste Fehler bricht ab.

Offene Grenzen von B2a: Es gibt in B2a keinen echten API-Lauf; der erste folgt in B3 auf Hennings Wort (zuerst Trockenlauf,
dann `--apply`). Ob Name und Untertitel im Zustand des vorhandenen appInfo änderbar sind, zeigt erst B3. Bricht `--apply`
mitten im Schreiben ab (z. B. de geschrieben, en gescheitert), wird das nicht verhindert, sondern durch Idempotenz (zweiter
Lauf schreibt nur den Rest) und das Gegenlesen in B2b abgefangen.

### Durchgang B2b: Gegenlesen und Texttest (2 Dateien, geschätzt +190 Zeilen)

- **Affected Files:** `scripts/asc_check.py`, `scripts/test_asc_texts.py`
- **Estimated Changes:** ~190 LoC (asc_check ~130, Texttest ~60). B2a und B2b zusammen bleiben bei ~520 Zeilen. B2b folgt
  getrennt nach B2a und nutzt `parse_texts` und `api` aus `asc_lib`, ohne `asc_lib` zu ändern. Wird dabei ±250 überschritten,
  wird B2b vor Beginn vorgelegt.

| Datei | Änderung |
|-------|----------|
| `scripts/asc_check.py` | NEU: nur GET, Abschnitte `metadata`, `privacy-url`, `appinfo`, `iap`, `screenshots`, `build`, `status`, `--all` (AC-11 bis AC-19) |
| `scripts/test_asc_texts.py` | NEU: dauerhafte Längen-, Begriffs- und URL-Tests über `docs/appstore/{de,en}.md` (AC-9 bis AC-9c) und Wortgleichheit `datenschutz.md` ↔ `LegalView.privacyPolicy` (AC-9d) |

### Durchgang B3: Ablauf und Belege (keine Quelldatei, Belege unter `docs/artifacts/`)

- **Affected Files:** `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt`,
  `…/release-manifest-check.txt` (aus A1), `…/screenshots/de/*.png`, `…/screenshots/en/*.png` (je 3 bis 10 Bilder),
  Beleg-Screenshots des Browserwegs
- **Estimated Changes:** ~0 LoC (nur Protokolle und Binärbilder; werden als Belegverzeichnis gezählt, nicht als Quelldateien,
  siehe Offene Grenzen). Außerhalb des Repos: ASC (Produktseite de/en, Kategorie, Altersfreigabe, Datenschutz-URL,
  Privacy-Fragebogen, Screenshots, drei In-App-Käufe samt Abo-Gruppe).

Die Durchgänge folgen A1, A2, B1, B2a, B2b, B3. Texte für die Datenschutzseite und der Privacy-Fragebogen folgen der Tabelle oben;
der Upload von Build 37 (außenwirksam, nur auf Wort) liegt zwischen A2 und dem Einreichen.

## Implementation Details

```
A1: Manifest-Plist um sechs Dicts erweitern (Name, Linked, Tracking=false, Purposes=[AppFunctionality]);
    LegalView-Strings ergänzen; PrivacyManifestTests liest Repo-Dateien per #filePath.
A2: InfoPlist.strings de/en; project.yml + pbxproj Build 37; Tests ergänzen.
B1: Texte als Dateien.
B2a: asc_lib (Parser, JWT, api), asc_publish (erst lesen und prüfen, dann PATCH/POST auf die eigene App-ID,
    Trockenlauf Standard), test_asc_scripts (AC-10).
B2b: asc_check (nur GET, Vergleich mit den Dateien), test_asc_texts.
B3: echter Lauf auf Hennings Wort; Screenshots per simctl aus dem Simulator.
```

## Expected Behavior

- **Input:** Repo-Texte und Manifest, ASC-Schlüssel aus der Umgebung (Pfad), Simulator mit Seed.
- **Output:** Build 37 mit wahrem Manifest (sechs Datentypen, einschließlich Open Prices) und lokalisierten Texten; ASC-Eintrag, dessen gelesene Werte den Repo-Dateien
  gleichen; Gegenlese-Protokoll im Repo.
- **Side effects:** Außenwirksam sind nur Upload von Build 37 und Einreichen, beide nur auf Hennings Wort. Das Setzen der
  Metadaten in ASC verändert nur den Entwurf (Status bleibt `PREPARE_FOR_SUBMISSION`). Keine Gerätezugriffe.

## Datenschutz-URL: harte Abhängigkeit

Apple verlangt eine öffentliche Datenschutz-URL (Pflicht, belegt in der ASC-Hilfe „Manage app privacy“). Die einzige
vorhandene Adresse ist falsch (Befund 1). **Einreichbarkeit hängt davon ab, dass diese Seite berichtigt wird**, deutsch und
englisch, mit dem Inhalt von `docs/appstore/datenschutz.md`. Wer `emmrich-business.com` ändern kann, ist offen
(PO 2026-10-24: wird nach B1 geklärt). Die Spec trifft diese Entscheidung nicht; mögliche Wege, die Seite
bereitzustellen, falls der Zugang auf die Domain nicht zu bekommen ist:

- (a) Berichtigung der bestehenden Seite durch den Domaininhaber (bevorzugt, URL bleibt);
- (b) statische Seite aus dem Repo über GitHub Pages (kippt die Annahme „Repo gehört dem Sohn, henemm hat nur Push“, siehe
  Memory; Pages-Einstellung braucht Admin-Rechte);
- (c) Seite auf einer Domain, die Henning selbst steuert (Verantwortlicher im Text bliebe Johannes Emmrich; ob das für
  Apple und rechtlich passt, ist nicht geprüft).

Die Support-URL hängt an derselben Domain und teilt die Abhängigkeit.

## Texte (Entwurf zur Freigabe)

Nur Funktionen, die in 1.0 für jeden Nutzer existieren (Code und CLAUDE.md geprüft): Artikel per Freitext hinzufügen
(„500 gramm Hackfleisch“), automatische Ladenzuordnung aus der Kaufhistorie, Läden mit gelerntem Einkaufsweg, Bon-Scan
(Vision-Texterkennung, auch aus der Teilen-Funktion der Fotos-App) mit Preislernen, Barcode-Scan (Open Food Facts), geteilte
Läden, Community-Preise (voreingestellt an, abschaltbar), Siri, Widget, Live Activity, Schnell-hinzufügen-Knopf, saisonale
Vorschläge, iCloud-Abgleich; **Pro:** Rezeptplan und Ausgaben-Analyse (`HomeView`: `PaywallRequest` nur für diese beiden).
**Nicht genannt:** Nachkauf-Vorschläge und Tagesmitteilung (im Normalbetrieb erst 1.1, nur im Entwicklermodus sichtbar).
Zeichenlimits sind mit Python gezählt. Korrekturen für B1 (Recherche 2026-10-24): kein „Was ist neu“ (Apple: nicht verfügbar
für die erste Version, developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information);
Schlüsselwörter zählen in **Bytes** (UTF-8), ohne Wörter aus Untertitel, Name, Firma oder fremden Marken; Beschreibung endet
mit ausgeschriebener Datenschutz-URL und Link zu Apples Standard-EULA (Abo-Richtlinie 3.1.2). **Nicht genannt:** Nachkauf und
Erinnerungen (erst 1.1), Open Prices (läuft gegen Testserver), KI-Preisschätzung (nur Entwicklermodus). Keine Preise, keine
Superlative, kein Bezug auf andere Apps (Richtlinie 2.3.7). Pro = Rezeptplan und Ausgaben-Analyse.

### Deutsch

- **Name (≤ 30):** `Restock` (7)
- **Untertitel (≤ 30):** `Einkaufsliste mit Ladenwahl` (27)
- **Schlüsselwörter (≤ 100 Bytes):** `Einkaufszettel,Kassenbon,Preise,Supermarkt,Läden,Menüplan,Barcode,Ausgaben,Haushalt,Rezepte` (91 Zeichen, 93 Bytes)
- **Werbetext (≤ 170):** `Schreib auf, was fehlt. Restock sortiert es in den passenden Laden und lernt deinen Weg durch den Markt.`
- **Beschreibung (≤ 4000):**

```
Restock ist deine Einkaufsliste, die weiß, wo etwas hingehört.

SCHNELL NOTIERT
Tippe „500 g Hackfleisch“ oder „Milch“ ein, Menge und Einheit erkennt Restock selbst. Der Artikel landet automatisch im passenden Laden – nach dem, was du dort sonst kaufst. Passt die Wahl nicht, ändere sie mit einem Tipp; Restock merkt sich das.

LÄDEN UND EINKAUFSWEG
Lege deine Läden an und hake ab, was im Korb liegt. Restock lernt aus der Reihenfolge, in der du abhakst, und sortiert die Liste dann in deinem Weg durch den Markt.

KASSENBON SCANNEN
Fotografiere den Bon oder teile ihn aus der Fotos-App. Restock liest die Positionen, du prüfst sie, und die Preise helfen künftig bei der Schätzung deiner Einkäufe. Auch lange digitale Bons werden gelesen.

BARCODE
Scanne einen Strichcode, Restock fragt den Produktnamen bei Open Food Facts ab. Dabei wird nur die Nummer übertragen.

PREISE
Du siehst, was dein Einkauf voraussichtlich kostet, und wo ein Preis geschätzt ist, steht das dabei. Optional vergleichst du mit Preisen anderer Nutzer („Community“). Dafür teilt Restock anonym nur Artikel, Ladenkette, Preis und Datum – ohne Namen, Foto oder Filiale. Das lässt sich in den Einstellungen jederzeit abschalten.

GETEILTE LÄDEN
Teile einen Laden mit Familie oder Mitbewohnern; alle sehen dieselbe Liste.

IMMER ZUR HAND
Per Siri hinzufügen, vom Widget aus abhaken, die Live Activity zeigt dir im Laden den Fortschritt. Der iCloud-Abgleich hält deine eigenen Geräte auf demselben Stand.

RESTOCK PRO
Rezeptplan und Ausgaben-Analyse gibt es mit Restock Pro: monatlich, jährlich oder einmalig als Lifetime-Kauf. Abos verlängern sich automatisch, wenn sie nicht mindestens 24 Stunden vor Ablauf in den Apple-ID-Einstellungen gekündigt werden. Käufe lassen sich dort verwalten und wiederherstellen.

Restock ist werbefrei und nutzt kein Tracking.
Datenschutz: https://emmrich-business.com/datenschutz
Nutzungsbedingungen (Apples Standard-Lizenzvereinbarung): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

### English

- **Name (≤ 30):** `Restock` (7)
- **Subtitle (≤ 30):** `Smart shopping list by store` (28)
- **Keywords (≤ 100 Bytes):** `grocery,receipt,scanner,prices,supermarket,meal plan,barcode,spending,household,recipes` (87 Zeichen, 87 Bytes; „stores“ entfällt, weil „store“ im Untertitel steht)
- **Promotional text (≤ 170):** `Jot down what's missing. Restock files it under the right store and learns your path through the supermarket.`
- **Description (≤ 4000):**

```
Restock is a shopping list that knows where things belong.

QUICK TO WRITE
Type "500 g mince" or "milk" and Restock recognizes quantity and unit on its own. The item lands in the right store automatically, based on what you usually buy there. If it's wrong, change it with one tap and Restock remembers.

STORES AND YOUR ROUTE
Set up your stores and tick off what's in the basket. Restock learns from the order you tick things off and then sorts the list along your path through the store.

SCAN RECEIPTS
Photograph a receipt or share it from the Photos app. Restock reads the lines, you review them, and the prices help estimate your future shopping. Long digital receipts are read too.

BARCODE
Scan a barcode and Restock looks up the product name at Open Food Facts. Only the number is sent.

PRICES
See what your shop will probably cost; where a price is an estimate, it says so. Optionally compare with prices from other users ("Community"). For that, Restock shares only item, store chain, price and date anonymously, without your name, photo or branch. You can switch this off in Settings at any time.

SHARED STORES
Share a store with family or flatmates; everyone sees the same list.

ALWAYS AT HAND
Add by Siri, tick off from the widget, follow your progress in the store with the Live Activity. iCloud keeps your own devices in sync.

RESTOCK PRO
Meal plan and spending analysis come with Restock Pro: monthly, yearly or as a one-time lifetime purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period in your Apple ID settings. You can manage and restore purchases there.

Restock has no ads and no tracking.
Privacy policy: https://emmrich-business.com/datenschutz
Terms of Use (Apple's standard license agreement): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

Die Bildunterschriften der Screenshots (de/en) werden in Durchgang B3 mit den Bildern vorgelegt (Vorschau-Regel).
Die Texte gehen vor dem Eintragen an Henning (Freigabe), danach in `docs/appstore/de.md` und `en.md`.

### Felder und gezählte Längen (B1)

Gezählt mit `python3` (`len(s)`, `len(s.encode('utf-8'))`); Beschreibung ist der Text im Codeblock oben.

| Feld | Grenze | Deutsch | English |
|------|--------|---------|---------|
| `name` | 2–30 Zeichen | 7 | 7 |
| `subtitle` | ≤ 30 Zeichen | 27 | 28 |
| `keywords` | ≤ 100 **Bytes** | 93 Bytes (91 Zeichen) | 87 Bytes (87 Zeichen) |
| `promotional_text` | ≤ 170 Zeichen | 104 | 109 |
| `description` | ≤ 4000 Zeichen | 2008 | 1844 |
| `support_url` | – | `https://emmrich-business.com/support.html` | gleich |
| `privacy_url` | – | `https://emmrich-business.com/datenschutz` | gleich (eine zweisprachige Seite) |

Schlüsselwörter: Untertitelwörter („Einkaufsliste“, „shopping list“) fehlen mit Absicht (Apple indiziert den Untertitel
ohnehin). Jedes Wort hat mehr als 2 Zeichen; Name, Firma und fremde Marken kommen nicht vor.

### Dateiformat `docs/appstore/{de,en}.md` (B1)

Sprachneutrale, feste Überschriften der Ebene 2, in dieser Reihenfolge: `## name`, `## subtitle`, `## keywords`,
`## promotional_text`, `## description`, `## support_url`, `## privacy_url`. Unter jeder Überschrift steht der Feldwert ohne
Codezaun und ohne Anführungszeichen (Beschreibung mit Leerzeilen und Absätzen wie oben); **kein** `whats_new`. B2a und B2b lesen beide
Dateien mit demselben Parser (`asc_lib.parse_texts`).

### Datei `docs/appstore/datenschutz.md` (B1)

Eine zweisprachige Seite: `## Deutsch` wortgleich mit `LegalView.privacyPolicy` (Stand Oktober 2026), danach `## English` als
Übersetzung mit dem Hinweis am Anfang, dass die deutsche Fassung maßgeblich ist. Die Übersetzung ist nicht juristisch geprüft.
Dieselbe Seite wird später unter `https://emmrich-business.com/datenschutz` veröffentlicht.

### Kategorie

Vorschlag: **primär Einkaufen (Shopping), sekundär Produktivität.** Begründung: Kernnutzen ist die Einkaufsliste samt
Bon- und Preisfunktion; Produktivität ist die übliche Kategorie reiner Listen-Apps. Ob Apple Shopping nur für
Händler-Apps erwartet, ist nicht belegt; Rückfall: primär Produktivität, sekundär Einkaufen (Entscheidung beim Eintragen,
Ablehnung wäre kein Blocker, die Kategorie ist änderbar).

## Alternativen (zum bisherigen Weg)

1. **Community-Preise standardmäßig aus (Opt-in)** statt voreingestellt an. Dann entfielen Kaufverlauf und Kennung aus der
   Datenerhebung nicht ganz (der Hinweis #186 schaltet sie ein), die Angabe bliebe nötig, aber der Eintrag im Fragebogen
   würde weniger Nutzer betreffen. Kippt: den PO-Beschluss vom 2026-10-20 (Opt-out, #183) und das Kapitel „optionale
   Offenlegung reicht nicht“. Spart wegen der Definition (Daten verlassen das Gerät) keine Angabe, ist daher keine Lösung für
   dieses Ticket.
2. **Manifest unverändert lassen und nur den ASC-Fragebogen ausfüllen.** Weniger Dateien, kein Build 37 nur wegen des
   Manifests. Kippt die Annahme, dass Apple Manifest und Fragebogen abgleicht (bei Widerspruch droht Ablehnung oder ein
   Hinweis; im Manifest `collects no data` bleibt die Aussage objektiv falsch). Nicht empfohlen.
3. **Datenschutzseite andernorts statt auf `emmrich-business.com`** (siehe Abschnitt Datenschutz-URL, Wege b und c). Kippt
   die Annahme, dass die Seite beim Verantwortlichen auf dessen Domain liegen muss.
4. **Nutzerdaten konservativer einordnen:** Kaufverlauf und Kennung als „mit dem Nutzer verknüpft“ deklarieren, weil die
   `clientID` Einträge einer Installation verbindet. **Teilweise umgesetzt:** Kaufverlauf ist wegen der Open-Prices-Beiträge
   (öffentlich unter dem Benutzernamen) jetzt verknüpft und die Nutzer-ID deklariert; offen ist nur noch die Geräte-ID der
   Community-Preise. Sicherer gegen Ablehnung, kostet nur einen Haken je Typ. Kippt die
   Annahme „zufällige, nicht an Apple-ID gebundene Kennung = nicht verknüpft“. Entscheidung beim Fragebogen; der Test
   (`PrivacyManifestTests`) hält die gewählte Fassung fest.
5. **Screenshots vom Gerät statt aus dem Simulator.** Echter Datenbestand, aber Gerätezugriff nur auf Hennings Wort (#187).
   Kippt die Annahme, dass Simulator-Bilder mit Seed reichen.

6. **(B1) Zwei getrennte Datenschutzseiten** (`/datenschutz`, `/en/privacy`) statt einer zweisprachigen: sauberer je Sprache,
   aber doppelte Pflege auf einer Domain mit offenem Zugang. Nicht empfohlen.
7. **(B1) Nur deutsche Datenschutzseite:** Apple verlangt keine Übersetzung, englische Nutzer läsen aber einen Text, den sie
   nicht verstehen. Kippt nichts Beschlossenes, kostet Vertrauen.
8. **(B1) Datenschutztext aus einer Repo-Datei in die App erzeugen** (eine Quelle für App und Web): würde `LegalView` umbauen,
   sprengt B1, gehört zu #214.
9. **(B1) Englische Store-Seite erst mit 1.1:** weniger Arbeit, kippt den Beschluss „de und en“; en-US ist Standardsprache vieler Länder.
10. **(B2a) Nur Gegenlesen automatisieren, Texte in B3 per Hand im Browser eintragen:** kleinster und sicherster Weg (kein
    Schreibrecht im Skript), spart rund 150 Zeilen. Verliert die Wiederholbarkeit (1.1, weitere Sprachen) und fängt Tippfehler
    erst beim Gegenlesen. Vom PO am 2026-10-24 verworfen; hätte die Entscheidung „Skript schreibt“ gekippt.
11. **(B2a) fastlane `deliver`:** fertig, aber neue Ruby-Abhängigkeit (Projektregel: keine neuen Dependencies) und ein
    Einreichen per Schalter, was AC-10/AC-18 schwerer garantierbar macht. Verworfen.
12. **(B2a) B2a weiter teilen** (`asc_lib` mit Test, dann `asc_publish`): hält die Limits, aber der erste Teil hat allein keinen
    Nutzen. Nicht gewählt; der PO nahm ~330 Zeilen in einem Durchgang an.

## Definition of Done

Fertig ist das Ticket, wenn:

- [ ] Jede Acceptance Criterion unten durch einen automatischen Test belegt ist. **Ausnahme: Nachweis-ACs, weil die Prüfung
  außerhalb der App in App Store Connect liegt:** AC-11 (Texte in ASC), AC-12 (Datenschutz-URL), AC-13 (Kategorie,
  Altersfreigabe), AC-14 (Privacy-Fragebogen), AC-15 (Käufe), AC-16 (Screenshots), AC-17 (Build), AC-18 (Status),
  AC-19 (Gesamtcheckliste). Sie sind durch das Gegenlese-Skript `scripts/asc_check.py` bzw. Beleg-Screenshots belegt.
  AC-3, AC-7 und AC-8 sind zusätzlich durch Befehle am Release-Bundle bzw. den Simulator-Durchlauf belegt
- [ ] `python3 scripts/asc_check.py --all` meldet für Version 1.0 keine fehlende Pflichtangabe (AC-19): ein Build ist
  einreichbar; das Einreichen selbst bleibt Hennings ausdrückliches Wort
- [ ] Die Datenschutz-URL zeigt die berichtigte Seite in Deutsch und Englisch (AC-12)
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün, AC-5 und AC-8)

## Acceptance Criteria

Durchgang A1

- **AC-1:** Vorbedingung: Manifest `SmartCart/PrivacyInfo.xcprivacy`. Aktion: Plist parsen. Ergebnis: genau die sechs
  Datentypen der Tabelle (verknüpft: Name, OtherUserContent, PhotosorVideos, PurchaseHistory, UserID; nicht verknüpft: DeviceID), je
  Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`, `NSPrivacyCollectedDataTypeTracking` false.
  - Test: `RestockTests/PrivacyManifestTests.swift::testCollectedDataTypesEqualDocumentedList`
- **AC-2:** `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` leer, Required-Reason `UserDefaults`/`1C8F.1` unverändert,
  Open-Food-Facts-Abfrage nicht als Datentyp deklariert.
  - Test: `RestockTests/PrivacyManifestTests.swift::testTrackingFalseAndUserDefaultsReasonKept`, `::testNoBarcodeDataTypeDeclared`
- **AC-3:** Das Manifest liegt im Release-Bundle (Release-Übersetzung für den Simulator) und stimmt mit der Quelle überein.
  - Test: `RestockTests/PrivacyManifestTests.swift::testManifestIsPartOfBundle`
  - Nachweis: `plutil -p <App>.app/PrivacyInfo.xcprivacy` am Release-Bundle, erwartet die sechs Typen; Ausgabe in
    `docs/artifacts/feat-175-app-store-auftritt/release-manifest-check.txt`
- **AC-4:** `LegalView` nennt in der Datenschutzerklärung Fotos geteilter Artikel und den Open-Prices-Beitrag (Bonfoto, Filiale,
  Preise, Benutzername) und trägt „Stand: Oktober 2026“; die Nutzungsbedingungen tragen ebenfalls „Stand: Oktober 2026“ und
  enthalten keine Zeile „Geteilte Listen Add-on“ mehr.
  - Test: `RestockTests/PrivacyManifestTests.swift::testLegalTextMentionsPhotosAndNoLongerAddOn`
- **AC-5:** Nach A1 sind Unit-Suite und `LocalizationKeyParityTests` grün.
  - Nachweis: `xcodebuild test` auf `Restock-Validate`, erwartet Testzahl > 0, 0 Fehlschläge, kein Runner-Abbruch

Durchgang A2

- **AC-6:** `InfoPlist.strings` in `de.lproj` und `en.lproj` mit `NSCameraUsageDescription` und
  `NSPhotoLibraryUsageDescription`, nicht leer, gleiche Schlüssel; Kameratext nennt Bons, Barcodes und Rezeptfotos, Fototext
  Bons und Rezeptfotos.
  - Test: `RestockTests/PrivacyManifestTests.swift::testInfoPlistStringsExistInGermanAndEnglish`,
    `::testCameraTextNamesReceiptsBarcodesAndRecipes`
- **AC-7:** `project.yml` und `project.pbxproj` führen `CURRENT_PROJECT_VERSION` 37, übereinstimmend; Strings-Dateien sind
  in den Ressourcen des App-Ziels registriert.
  - Test: `RestockTests/PrivacyManifestTests.swift::testBuildNumberIs37InBothProjectFiles`
  - Nachweis: `CFBundleVersion` 37 im Release-Bundle (`plutil -p`, Ausgabe wie bei AC-3)
- **AC-8:** Nach A2 sind Unit-Suite und `LocalizationKeyParityTests` grün; Durchlauf als Nutzer: Build 37 im Simulator,
  Einstellungen → Datenschutzerklärung zeigt den Fotos-Satz, der Kamera-Aufruf des Bon-Scans zeigt den lokalisierten Text.
  - Nachweis: `xcodebuild test` wie AC-5 (erwartet 0 Fehlschläge) plus Simulator-Screenshots unter
    `docs/artifacts/feat-175-app-store-auftritt/`

Durchgang B (AC-9, AC-9a bis AC-9d in B1 per Python-Einzeiler und dauerhaft in B2b, AC-10 mit AC-10a bis AC-10h in B2a, AC-11 bis AC-19 in B3 gegen ASC)

- **AC-9 (B1, korrigiert):** `docs/appstore/de.md` und `en.md` enthalten genau die Überschriften `## name`, `## subtitle`,
  `## keywords`, `## promotional_text`, `## description`, `## support_url`, `## privacy_url` (kein `whats_new`), jede mit
  nicht leerem Wert.
  - Nachweis B1: Python-Einzeiler über beide Dateien, Ausgabe in `docs/artifacts/feat-175-b1-store-texte/laengen.txt`
- **AC-9a (B1):** Grenzen eingehalten: Name 2–30 Zeichen, Untertitel ≤ 30, Werbetext ≤ 170, Beschreibung ≤ 4000,
  Schlüsselwörter ≤ 100 **Bytes** (UTF-8) und kein Wort ≤ 2 Zeichen; Werte entsprechen der Tabelle „Felder und gezählte Längen“.
  - Nachweis B1: wie AC-9 (Zeichen- und Byte-Zahl je Feld im Artefakt); dauerhafter Test erst in B2b: `python3 scripts/test_asc_texts.py`
- **AC-9b (B1):** Verbotene Begriffe fehlen in beiden Dateien (ohne Groß-/Kleinschreibung): „Nachkauf“, „Erinnerung“,
  „replenish“, „reminder“, „Open Prices“, „KI-Preis“/„AI price“, „Was ist neu“/„What's new“; die Schlüsselwörter enthalten weder
  „Einkaufsliste“ noch „shopping list“ noch „Restock“.
  - Nachweis B1: Python-Einzeiler, Ausgabe im Artefakt; dauerhaft in B2b
- **AC-9c (B1):** Beide Beschreibungen enthalten ausgeschrieben `https://emmrich-business.com/datenschutz` und
  `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`; `privacy_url` ist in beiden Dateien gleich,
  `support_url` ist `https://emmrich-business.com/support.html`.
  - Nachweis B1: Python-Einzeiler, Ausgabe im Artefakt; dauerhaft in B2b
- **AC-9d (B1):** `docs/appstore/datenschutz.md` hat `## Deutsch` und `## English`; der Abschnitt Deutsch ist wortgleich mit
  `LegalView.privacyPolicy`; der englische Abschnitt nennt, dass die deutsche Fassung maßgeblich ist.
  - Nachweis B1: Skript-Vergleich (Python liest die Strings aus `LegalView.swift`, vergleicht normalisierte Absätze),
    Ausgabe im Artefakt
- **AC-10 (B2a):** Die ASC-Skripte (`asc_lib.py`, `asc_publish.py`) rufen nur `https://api.appstoreconnect.apple.com/` auf, nur
  GET/POST/PATCH, nur Pfade der eigenen App-ID (bzw. IDs aus deren Antworten), geben Token und Schlüsselinhalt nie aus und
  kennen keinen Einreichungs-Endpunkt (`reviewSubmissions`, `appStoreVersionSubmissions`). Die Unterpunkte AC-10a bis AC-10h
  machen das prüfbar; AC-10 gilt als erfüllt, wenn alle gelten.
  - Nachweis: `python3 scripts/test_asc_scripts.py` (statische Quelltextprüfung plus Aufruf mit Schein-Antworten), erwartet Exit 0
- **AC-10a (Host, Methoden, Pfade):** `api` lehnt jeden anderen Host als `api.appstoreconnect.apple.com`, jede andere Methode
  als GET/POST/PATCH und jeden Pfad außerhalb der Erlaubnisliste ab, bevor `send` aufgerufen wird. Erlaubt sind nur
  `/v1/apps` mit Filter, `/v1/apps/{id}/appStoreVersions`, `/v1/apps/{id}/appInfos`,
  `/v1/appStoreVersions/{id}/appStoreVersionLocalizations`, `/v1/appInfos/{id}/appInfoLocalizations`,
  `/v1/appStoreVersionLocalizations[/{id}]`, `/v1/appInfoLocalizations[/{id}]`.
  - Nachweis: Test ruft `api` mit Fremdhost, `DELETE`, `PUT`, `/v1/reviewSubmissions`, `/v1/appStoreVersionSubmissions` und `/v2/…`; erwartet Ausnahme und null Aufrufe von `send`
- **AC-10b (nur eigene App):** In einem Durchlauf mit Schein-`send` liegen alle Pfade unter der App-ID aus der Antwort auf
  `filter[bundleId]=com.johannesemmrich.Restock` bzw. unter IDs, die aus den Antworten auf diese Pfade stammen; kein Pfad enthält
  eine andere ID.
  - Nachweis: Test zeichnet alle Pfade des Schein-`send` auf und prüft sie gegen die Menge der aus Antworten stammenden IDs
- **AC-10c (Trockenlauf schreibt nie):** Ohne `--apply` ruft `asc_publish` `send` nie mit POST oder PATCH auf und gibt den
  geplanten Unterschied aus; Exit 0.
  - Nachweis: Test mit abweichenden Schein-Daten, erwartet 0 Schreibaufrufe, Plan in der Ausgabe
- **AC-10d (Zustandsprüfung vor jedem Schreiben):** Bei 0 oder mehr als 1 App, Version oder appInfo im Zustand
  `PREPARE_FOR_SUBMISSION` sowie bei jedem anderen oder unbekannten Zustandswert bricht `asc_publish` mit Fehler (Exit ≠ 0)
  ab, auch mit `--apply`; bis dahin gab es nur GETs.
  - Nachweis: Test mit Schein-Antworten je Fall (z. B. `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, zwei Versionen, leere App-Liste), erwartet Exit ≠ 0 und 0 Schreibaufrufe
- **AC-10e (409-Vermeidung, Feldzuordnung):** Für eine vorhandene Sprache gibt es nie ein POST, sondern ein PATCH mit nur den
  abweichenden Feldern; nur für eine fehlende Sprache ein POST (mit Relationship auf Version bzw. appInfo). Gesendet werden
  nur `description`, `keywords`, `promotionalText`, `supportUrl` (Version) und `name`, `subtitle`, `privacyPolicyUrl`
  (appInfo); `whatsNew` kommt nie vor.
  - Nachweis: Test mit Schein-Daten (de vorhanden, en fehlt), erwartet je ein PATCH für de und ein POST für en, Feldnamen wie angegeben
- **AC-10f (Idempotenz):** Ein Lauf mit `--apply` gegen Schein-Daten, die den Dateien schon gleichen, ruft weder POST noch
  PATCH auf; ein zweiter Lauf nach einem ersten, dessen Schreibaufrufe der Schein-Zustand übernimmt, ebenso.
  - Nachweis: Test, erwartet 0 Schreibaufrufe
- **AC-10g (keine Geheimnisse in Ausgabe und Fehlern):** Weder Token noch Schlüsselinhalt noch der Wert von `ASC_KEY_PATH`
  erscheinen in Ausgabe, Fehlermeldungen oder Ausnahmen; Fehlermeldungen von `api` enthalten nur Status und Pfad. Der Schlüssel
  wird von den Skripten nie gelesen, der Pfad geht nur als Argument an `openssl`; `exp` ≤ `iat` + 1200 s, `aud`
  `appstoreconnect-v1`; eine DER-Signatur wird mit fester Probe korrekt nach R‖S (64 Byte) umgewandelt.
  - Nachweis: Test mit Schein-`sign` und Schein-`send`, der einen Fehler mit Token im Antworttext liefert, erwartet Meldung nur mit Status und Pfad, Ausgabe ohne Token; Test von `make_token` (Kopf, Nutzlast, Länge 64) und der Umwandlung mit fester DER-Probe
- **AC-10h (Quelltextverbote):** Im Quelltext von `asc_lib.py` und `asc_publish.py` kommen nicht vor: `shell=True`,
  `DELETE`, `reviewSubmissions`, `appStoreVersionSubmissions`, `whatsNew`, fremde Hosts (jede URL außer
  `https://api.appstoreconnect.apple.com`), das Öffnen oder Lesen der Schlüsseldatei (`open(` auf `ASC_KEY_PATH`) und jede
  Drittbibliothek (nur Standardbibliothek); `openssl` wird als Argumentliste aufgerufen.
  - Nachweis: statische Prüfung in `scripts/test_asc_scripts.py` über den Quelltext beider Dateien
- **AC-11:** Version 1.0 hat in de-DE und en-US Beschreibung, Schlüsselwörter, Werbetext, Support-URL (kein „Was ist neu“, für die erste Version nicht verfügbar);
  `appInfoLocalizations` haben Name, Untertitel, Datenschutz-URL; gelesene Werte sind wortgleich mit den Dateien.
  - Nachweis: `python3 scripts/asc_check.py --section metadata`, erwartet „ok“ je Feld; Protokoll
    `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt`
- **AC-12:** Die Datenschutz-URL liefert HTTP 200, enthält die Aussagen zu öffentlicher Datenbank (geteilte Läden,
  Community-Preise, Fotos), Kamera/Bon-Scan und Open Food Facts, auf Deutsch und Englisch. **Blockiert, solange die Seite
  nicht berichtigt ist.**
  - Nachweis: `python3 scripts/asc_check.py --section privacy-url`, erwartet „ok“ für beide Sprachen
- **AC-13:** Kategorie (primär, sekundär), Altersfreigabe, Content Rights, Preise/Verfügbarkeit der App sind gesetzt.
  - Nachweis: `python3 scripts/asc_check.py --section appinfo` (GET `appInfos`, `ageRatingDeclarations`,
    `appPriceSchedule`), erwartet „ok“; was die API nicht kann, per Browser mit Beleg-Screenshot
- **AC-14:** Der App-Privacy-Fragebogen ist ausgefüllt und veröffentlicht mit genau den sechs Datentypen der Tabelle (Name, Sonstige Nutzerinhalte, Fotos oder Videos, Kaufverlauf, Nutzer-ID verknüpft; Geräte-ID nicht verknüpft), Tracking nein.
  - Nachweis: API-Gegenlesen, falls möglich; sonst Beleg-Screenshots der ASC-Seite „App Privacy“ im Zustand
    „Veröffentlicht“ unter `docs/artifacts/feat-175-app-store-auftritt/`, zeilenweise gegen die Tabelle abgeglichen
- **AC-15:** Abo-Gruppe „Restock Pro“ mit monthly und yearly sowie das nicht verbrauchbare lifetime
  (`com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}`), Preise 1,99 / 8,99 / 14,99 € (Basisland
  Deutschland), Anzeigename und Beschreibung de und en, je ein Review-Screenshot; kein Produkt `sharedlists`.
  - Nachweis: `python3 scripts/asc_check.py --section iap`, erwartet „ok“ je Produkt, Status bereit zum Einreichen (nicht eingereicht)
- **AC-16:** Ein Satz iPhone-Screenshots 6,9" (1320×2868) je Sprache in ASC, 3 bis 10 Bilder, aus dem Simulator mit
  `-premiumForScreenshots` und gesäten Daten, ohne echte Namen oder Fotos; die Bilder gehen vor dem Hochladen an Henning.
  - Nachweis: `sips -g pixelWidth -g pixelHeight` an den Dateien unter
    `docs/artifacts/feat-175-app-store-auftritt/screenshots/{de,en}/`, erwartet 1320×2868;
    `python3 scripts/asc_check.py --section screenshots`, erwartet „ok“ mit 3 bis 10 Bildern je Sprache
- **AC-17:** Build 37 oder höher (Verarbeitung abgeschlossen) ist Version 1.0 zugeordnet; Export-Compliance beantwortet
  (`ITSAppUsesNonExemptEncryption` false).
  - Nachweis: `python3 scripts/asc_check.py --section build`, erwartet „ok“
- **AC-18:** Es wurde nichts eingereicht und nichts außenwirksam veröffentlicht ohne Hennings ausdrückliches Wort; der Status
  der Version ist `PREPARE_FOR_SUBMISSION`.
  - Nachweis: `python3 scripts/asc_check.py --section status`, erwartet `PREPARE_FOR_SUBMISSION`; AC-10 verbietet die
    Einreichungs-Endpunkte im Skript
- **AC-19 (Definition of Done des Tickets):** Alle Abschnitte von `asc_check.py` in einem Lauf „ok“: Name, Untertitel,
  Beschreibung, Schlüsselwörter, Support-URL, Datenschutz-URL, Kategorie, Altersfreigabe, Content Rights, App-Privacy
  veröffentlicht, Preise/Verfügbarkeit, Build, Screenshots je Sprache, drei Käufe vollständig, Review-Kontakt/-Hinweise.
  - Nachweis: `python3 scripts/asc_check.py --all`, erwartet Exit 0 und Protokoll `asc-readback.txt` mit Zeitstempel und
    Commit-Kennung

## Test Plan

Automatisch, an die ACs oben gebunden (jedes AC erscheint):

- AC-1, AC-2, AC-3, AC-4 (A1): `RestockTests/PrivacyManifestTests.swift` (Manifest-Plist parsen, Datentypen gleich der
  dokumentierten Liste, Tracking/UserDefaults, Bundle-Teil über `Bundle(for:)`, LegalView-Quelltext über `#filePath`).
  Keine In-Memory-Container darin.
- AC-3 zusätzlich: Release-Nachweis der Manifest-Datei im Bundle, Release-Übersetzung auf dem Simulator mit denselben
  Einstellungen wie der CI-Job `release-build`, `plutil -p`.
- AC-5 (A1) und AC-8 (A2): Unit-Suite und `RestockTests/LocalizationKeyParityTests.swift` bleiben grün
  (`xcodebuild test` auf `Restock-Validate`).
- AC-6, AC-7 (A2): `PrivacyManifestTests` (InfoPlist de/en, gleiche Schlüssel, Textinhalt; Build-Nummer in `project.yml` und
  `project.pbxproj`).
- AC-8 zusätzlich: Durchlauf als Nutzer im Simulator (Datenschutzerklärung, Kamera-Text).
- AC-9, AC-9a bis AC-9d: in B1 per Python-Einzeiler (Artefakt `docs/artifacts/feat-175-b1-store-texte/laengen.txt`); dauerhaft in B2b: `python3 scripts/test_asc_texts.py` (Python, ohne Netz).
- AC-10, AC-10a bis AC-10h (B2a): `python3 scripts/test_asc_scripts.py` (ohne Netz, ohne Schlüssel, Schein-`send` und Schein-`sign`; kein echter API-Lauf).
- AC-11 bis AC-19 (B3): Gegenlese-Lauf `python3 scripts/asc_check.py` (in B2b gebaut, in B3 gefahren) gegen ASC (`--section metadata|privacy-url|appinfo|iap|
  screenshots|build|status`, `--all`), lesend (GET); AC-14 bei Bedarf mit Beleg-Screenshots; AC-16 zusätzlich `sips`.
  Der Lauf darf mit Hennings Wort nach jedem Setzen erneut laufen.

Keine manuellen Tests und keine Geräteprüfung; Simulator nur über Wegwerf-Geräte beziehungsweise `Restock-Validate`, mit den
Sperren aus den Projektregeln (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock`).

Durchlauf als Nutzer (Projektregel „Die App wird benutzt“): Vor Übergabe wird Build 37 im Simulator gestartet, die
Einstellungen → Datenschutzerklärung geöffnet (Fotos geteilter Artikel sichtbar), und der Kameraaufruf des Bon-Scans zeigt den
lokalisierten Text.

## Known Limitations

Offene Grenzen:

- **Datenschutz-URL:** Berichtigung der Seite hängt an jemandem mit Zugriff auf `emmrich-business.com`; wird nach B1 geklärt (PO 2026-10-24). Ohne sie
  ist das Ticket nicht abschließbar (AC-12).
- **Privacy-Fragebogen per API:** nicht belegt, dass er setzbar ist; Rückfall Browser mit Beleg-Screenshots (Chrome-Werkzeug).
  Veröffentlichung („Publish“) braucht die Rolle Account Holder/Admin/App Manager, der Schlüssel hat Admin.
- **Einordnung der Datentypen:** Die Zuordnung der eigenen CloudKit-Daten zu „erhoben“ folgt aus Apples Definition, ist dort
  nicht wörtlich geregelt. Die Wahl „nicht verknüpft“ für die Geräte-ID und die Einordnung der Open-Prices-Daten sind Schlussfolgerungen (siehe Alternative 4).
  Open Prices läuft derzeit nur gegen Pre-Production; ein Beitrag in der Produktion ist nicht erprobt, die Einordnung bleibt Schlussfolgerung.
  Ob Apple die Einordnung akzeptiert, wissen wir erst im Review.
- **Manifest-Schlüsselnamen** stammen aus Apples Dokumentation zu Privacy-Manifesten; der Build prüft sie nicht. Eine falsche
  Schreibweise zeigt sich erst bei Upload-Validierung oder im Datenschutzbericht von Xcode.
- **Echter Review-Ausgang unbekannt.** Kategorie Shopping vs. Produktivität ungeprüft. Die Beschreibung ist nicht gegen
  Apples Richtlinien im Review erprobt.
- **Kauf-Review:** Apple verlangt je Produkt einen Review-Screenshot (Paywall aus dem Simulator mit Fake-Szenario); das erste
  Abo muss gemeinsam mit einer App-Version eingereicht werden (Forenberichte, nicht amtlich belegt). Echter Kauf ist weiterhin
  nicht automatisiert geprüft (#178), Produkte in ASC wären hier erstmals angelegt (#175 deckt das ab).
- **Screenshots** zeigen gesäte Daten aus dem Simulator, nicht Hennings Alltag; Gerätebild erst nach #187 und nur auf sein Wort.
  Dass nur der 6,9"-Satz nötig ist (Apple leitet kleinere ab), stammt aus Drittquellen und wird in ASC gegengeprüft.
- **B1, Paywall ohne Links:** `PaywallView` zeigt keine Links zu Datenschutz und Nutzungsbedingungen; Ablehnungsrisiko nach
  Abo-Richtlinie 3.1.2. Produktänderung, nicht B1: Issue #215. Die Belege für 3.1.2 sind Entwicklerberichte (Apple-Foren), Schedule 2 selbst ist nicht gelesen.
- **B1, Support-Seite ohne Anschrift:** `emmrich-business.com/support.html` hat Kontaktformular und verschleierte E-Mail, keine
  Anschrift; möglicher Review-Einwand, gleiche Domain-Frage wie die Datenschutzseite.
- **B1, Datenschutzseite noch nicht online:** Wer sie auf `emmrich-business.com` stellt, wird nach B1 geklärt (PO 2026-10-24).
  Bis dahin zeigt die Datenschutz-URL in den Texten auf die alte, falsche Seite (AC-12 bleibt blockiert).
- **B1, `restock.html` veraltet** (Nachkauf, Rezeptfoto, „Geteilte Listen“-Add-on); gleiche Domain, nicht B1.
- **B1, Open Prices in 1.0 sichtbar gegen den Testserver:** Einstellungen zeigen den Eintrag ohne Entwicklermodus, `environment`
  steht auf `.preProduction`; Hinweis an #184. Die Store-Beschreibung nennt Open Prices nicht, die Datenschutzseite beschreibt es.
- **B1, englische Datenschutzübersetzung** ohne juristische Prüfung; die deutsche Fassung ist maßgeblich.
- **B1, Schlüsselwörter** liegen mit 93 (de) und 87 Bytes (en) unter der Grenze; jede Änderung muss neu in Bytes gezählt werden.
- **B2a, kein echter API-Lauf:** Die Tests laufen nur mit Schein-Antworten. Ob Apple Feldnamen, den Zustandswert
  `PREPARE_FOR_SUBMISSION` (Version `appVersionState`, appInfo `state`) und die Pfade so annimmt, zeigt erst B3 auf Hennings Wort
  (zuerst Trockenlauf, dann `--apply`). Die Zustandswerte stammen aus einer Abschrift von Apples OpenAPI-Dokument und
  fastlane-Berichten, nicht aus einem eigenen Lauf.
- **B2a, Name und Untertitel:** Ob sie im Zustand des vorhandenen appInfo änderbar sind, zeigt erst B3.
- **B2a, Teil-Schreiben:** Bricht `--apply` mitten im Schreiben ab, bleibt ein Teilstand im Entwurf. Das Skript verhindert es
  nicht; Idempotenz (erneuter Lauf schreibt nur den Rest) und das Gegenlesen in B2b fangen es ab. Der Entwurf ist nie eingereicht.
- **B2a, Umfang:** ~330 statt ±250 Zeilen, vom PO am 2026-10-24 angenommen; die Schätzung kann abweichen.
- **Nichts auf Hennings Geräten geprüft.**
- **Dateizählung B3:** Screenshots und Protokolle unter `docs/artifacts/` sind Belege, keine Quelldateien; zählt das Gate sie
  einzeln, wird B3 nach Sprache geteilt.
- **Unterschied Download und Upload:** Build 37 muss hochgeladen werden (Workflow `testflight.yml`, `build_number=37`); das ist
  außenwirksam und folgt Hennings Wort. Ohne Build 37 bleibt AC-17 offen und Version 1.0 hängt am alten Manifest.
- **Kosten der Berichtigung der Nutzungsbedingungen:** Es ist die einzige inhaltliche Änderung an `termsOfUse`; weitere
  juristische Prüfung der Texte findet nicht statt.

## Abhängigkeiten (Tickets)

#99 (nur iPhone), #145 D4 (Kauf), #163/#186 (Community-Preise mit Hinweis), #187 (Gerätetest, nicht nötig für
Simulator-Screenshots). #175 blockiert Release 1.0.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Konfigurations- und Dokumentationsarbeit mit kleinem Codeanteil; die Wahl der Datentypen steht in dieser Spec.

## Changelog

- 2026-10-23: Initial spec created (Entwurf, wartet auf Freigabe und die Antwort zur Datenschutz-URL).
- 2026-10-23: Nachbesserung per PO-`override`: Der Adversary fand den Opt-in „Bons an Open Prices beitragen“ (Bonfoto, Filiale, Preise, Open-Food-Facts-Benutzername an einen Dritten), im Manifest nicht genannt. Sechs statt fünf Datentypen (neu UserID, PurchaseHistory verknüpft), Standort-Begründung, AC-1, AC-4, Alternative 4 und Offene Grenzen angepasst.
- 2026-10-24: Durchgang B1 korrigiert und vervollständigt: kein „Was ist neu“ für 1.0, Schlüsselwörter in Bytes ohne Untertitelwörter, Beschreibung endet mit Datenschutz-URL und Standard-EULA-Link, Dateiformat mit festen Überschriften, finale Texte und Längentabelle, AC-9 bis AC-9d, Alternativen 6–9, Offene Grenzen.
- 2026-10-24: Durchgang B2 in B2a (`asc_lib`, `asc_publish`, `test_asc_scripts`, ~330 Zeilen, PO-angenommen) und B2b (`asc_check`, `test_asc_texts`) geteilt; AC-10 in AC-10a bis AC-10h präzisiert (Trockenlauf, Zustandsprüfung, 409-Vermeidung, Idempotenz, Geheimnisse, Quelltextverbote); dauerhafte Tests AC-9 bis AC-9d in B2b; Alternativen 10–12 und Offene Grenzen zu B2a.
