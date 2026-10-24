---
entity_id: app-store-auftritt
type: feature
created: 2026-10-23
updated: 2026-10-23
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

- **Affected Files:** Vereinigung aller Durchgänge A1, A2, B1, B2, B3 (Einzellisten in den Unterabschnitten).
- **Estimated Changes:** ~90 (A1) + ~47 (A2) + ~220 (B1) + ~520 (B2, über dem Limit, wird vor Beginn vorgelegt) + ~0 (B3) = ca. 877 LoC gesamt.

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
- **Estimated Changes:** ~220 LoC (de.md ~55, en.md ~55, datenschutz.md zweisprachig ~110)

| Datei | Änderung |
|-------|----------|
| `docs/appstore/de.md`, `docs/appstore/en.md` | NEU: je Sprache Name, Untertitel, Beschreibung, Schlüsselwörter, Werbetext, „Was ist neu“, Support-URL (Abschnitte mit festen Überschriften, damit Skripte sie lesen) |
| `docs/appstore/datenschutz.md` | NEU: Datenschutzseite als Text in Deutsch und Englisch, nach Durchgang A1 aus `LegalView` abgeleitet |

### Durchgang B2: Skripte und Strukturtests (5 Dateien, geschätzt +520 Zeilen)

- **Affected Files:** `scripts/asc_lib.py`, `scripts/asc_publish.py`, `scripts/asc_check.py`,
  `scripts/test_asc_texts.py`, `scripts/test_asc_scripts.py`
- **Estimated Changes:** ~520 LoC (asc_lib ~90, asc_publish ~130, asc_check ~170, Tests ~130). Das liegt über ±250; vor
  Beginn wird B2 mit dieser Schätzung vorgelegt und bei Bedarf in B2a (`asc_lib`, `asc_publish`, `test_asc_scripts`) und
  B2b (`asc_check`, `test_asc_texts`) geteilt.

| Datei | Änderung |
|-------|----------|
| `scripts/asc_lib.py`, `scripts/asc_publish.py`, `scripts/asc_check.py` | NEU: JWT aus dem Schlüssel (Inhalt nie gelesen oder ausgegeben), Schreiben nur auf dem eigenen App-Eintrag, Gegenlesen |
| `scripts/test_asc_texts.py`, `scripts/test_asc_scripts.py` | NEU: Strukturtests (Python, Muster wie `scripts/test_*.py`) |

### Durchgang B3: Ablauf und Belege (keine Quelldatei, Belege unter `docs/artifacts/`)

- **Affected Files:** `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt`,
  `…/release-manifest-check.txt` (aus A1), `…/screenshots/de/*.png`, `…/screenshots/en/*.png` (je 3 bis 10 Bilder),
  Beleg-Screenshots des Browserwegs
- **Estimated Changes:** ~0 LoC (nur Protokolle und Binärbilder; werden als Belegverzeichnis gezählt, nicht als Quelldateien,
  siehe Offene Grenzen). Außerhalb des Repos: ASC (Produktseite de/en, Kategorie, Altersfreigabe, Datenschutz-URL,
  Privacy-Fragebogen, Screenshots, drei In-App-Käufe samt Abo-Gruppe).

Die Durchgänge folgen A1, A2, B1, B2, B3. Texte für die Datenschutzseite und der Privacy-Fragebogen folgen der Tabelle oben;
der Upload von Build 37 (außenwirksam, nur auf Wort) liegt zwischen A2 und dem Einreichen.

## Implementation Details

```
A1: Manifest-Plist um sechs Dicts erweitern (Name, Linked, Tracking=false, Purposes=[AppFunctionality]);
    LegalView-Strings ergänzen; PrivacyManifestTests liest Repo-Dateien per #filePath.
A2: InfoPlist.strings de/en; project.yml + pbxproj Build 37; Tests ergänzen.
B:  Texte als Dateien; asc_lib/asc_publish/asc_check: JWT signieren, PATCH/POST auf die eigene App-ID,
    danach GET und Vergleich mit den Dateien; Screenshots per simctl aus dem Simulator.
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
(Open Question; PO: „Unklar“, Tech Lead klärt). Die Spec trifft diese Entscheidung nicht; mögliche Wege, die Seite
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
Zeichenlimits sind mit Python gezählt.

### Deutsch

- **Name (≤ 30):** `Restock` (7)
- **Untertitel (≤ 30):** `Einkaufsliste mit Ladenwahl` (27)
- **Schlüsselwörter (≤ 100):** `Einkaufsliste,Einkaufszettel,Kassenbon,Preise,Supermarkt,Läden,Menüplan,Barcode,Ausgaben,Haushalt` (97)
- **Werbetext (≤ 170):** `Schreib auf, was fehlt. Restock sortiert es in den passenden Laden und lernt deinen Weg durch den Markt.`
- **Was ist neu (1.0):** `Erste Version von Restock.`
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
Datenschutz: siehe Datenschutz-URL dieser Seite. Nutzungsbedingungen: Apples Standard-Lizenzvereinbarung.
```

### English

- **Name (≤ 30):** `Restock` (7)
- **Subtitle (≤ 30):** `Smart shopping list by store` (28)
- **Keywords (≤ 100):** `shopping list,grocery,receipt,scanner,prices,supermarket,stores,meal plan,barcode,spending,household` (100)
- **Promotional text (≤ 170):** `Jot down what's missing. Restock files it under the right store and learns your path through the supermarket.`
- **What's new (1.0):** `First release of Restock.`
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
Privacy: see the privacy policy URL on this page. Terms: Apple's standard license agreement.
```

Die Bildunterschriften der Screenshots (de/en) werden in Durchgang B3 mit den Bildern vorgelegt (Vorschau-Regel).
Die Texte gehen vor dem Eintragen an Henning (Freigabe), danach in `docs/appstore/de.md` und `en.md`.

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

Durchgang B (AC-9 und AC-10 in B2, AC-11 bis AC-19 in B3 gegen ASC)

- **AC-9:** Alle Texte in `docs/appstore/de.md` und `docs/appstore/en.md` vorhanden, Limits eingehalten (Name ≤ 30,
  Untertitel ≤ 30, Schlüsselwörter ≤ 100, Werbetext ≤ 170, Beschreibung ≤ 4000, „Was ist neu“ ≤ 4000); Beschreibung ohne
  „Nachkauf“ und „Erinnerung“.
  - Nachweis: `python3 scripts/test_asc_texts.py`, erwartet alle Tests OK, Exit 0
- **AC-10:** Die ASC-Skripte rufen nur `https://api.appstoreconnect.apple.com/` auf, nur GET/POST/PATCH, nur Pfade der eigenen
  App-ID, geben den Schlüsselinhalt nie aus und kennen keinen Einreichungs-Endpunkt (`reviewSubmissions`,
  `appStoreVersionSubmissions`).
  - Nachweis: `python3 scripts/test_asc_scripts.py` (statische Quelltextprüfung plus Aufruf mit Schein-Antworten), erwartet Exit 0
- **AC-11:** Version 1.0 hat in de-DE und en-US Beschreibung, Schlüsselwörter, Werbetext, „Was ist neu“, Support-URL;
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
- AC-9 (B2): `python3 scripts/test_asc_texts.py` (Python, ohne Netz).
- AC-10 (B2): `python3 scripts/test_asc_scripts.py` (ohne Netz).
- AC-11 bis AC-19 (B3): Gegenlese-Lauf `python3 scripts/asc_check.py` gegen ASC (`--section metadata|privacy-url|appinfo|iap|
  screenshots|build|status`, `--all`), lesend (GET); AC-14 bei Bedarf mit Beleg-Screenshots; AC-16 zusätzlich `sips`.
  Der Lauf darf mit Hennings Wort nach jedem Setzen erneut laufen.

Keine manuellen Tests und keine Geräteprüfung; Simulator nur über Wegwerf-Geräte beziehungsweise `Restock-Validate`, mit den
Sperren aus den Projektregeln (`/tmp/heavy-build.lock`, `/tmp/loose-ends-testlauf.lock`).

Durchlauf als Nutzer (Projektregel „Die App wird benutzt“): Vor Übergabe wird Build 37 im Simulator gestartet, die
Einstellungen → Datenschutzerklärung geöffnet (Fotos geteilter Artikel sichtbar), und der Kameraaufruf des Bon-Scans zeigt den
lokalisierten Text.

## Known Limitations

Offene Grenzen:

- **Datenschutz-URL:** Berichtigung der Seite hängt an jemandem mit Zugriff auf `emmrich-business.com`; ungeklärt. Ohne sie
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
