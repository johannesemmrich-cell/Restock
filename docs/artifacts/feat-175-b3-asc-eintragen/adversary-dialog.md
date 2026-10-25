# Adversary Dialog — feat-175-b3-asc-eintragen
Spec: docs/specs/appstore/app-store-auftritt.md
Datum: 2026-10-25 11:56

## Checkliste
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **Input:** Repo-Texte und Manifest, ASC-Schlüssel aus der Umgebung (Pfad), Simulator mit Seed. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **Output:** Build 37 mit wahrem Manifest (sechs Datentypen, einschließlich Open Prices) und lokalisierten Texten; ASC-Eintrag, dessen gelesene Werte den Repo-Dateien — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **Side effects:** Außenwirksam sind nur Upload von Build 37 und Einreichen, beide nur auf Hennings Wort. Das Setzen der — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-1:** Vorbedingung: Manifest `SmartCart/PrivacyInfo.xcprivacy`. Aktion: Plist parsen. Ergebnis: genau die sechs Datentypen der Tabelle (verknüpft: Name, OtherUserContent, PhotosorVideos, PurchaseHistory, UserID; nicht verknüpft: DeviceID), je Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`, `NSPrivacyCollectedDataTypeTracking` false. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-2:** `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` leer, Required-Reason `UserDefaults`/`1C8F.1` unverändert, Open-Food-Facts-Abfrage nicht als Datentyp deklariert. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-3:** Das Manifest liegt im Release-Bundle (Release-Übersetzung für den Simulator) und stimmt mit der Quelle überein. `docs/artifacts/feat-175-app-store-auftritt/release-manifest-check.txt` — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-4:** `LegalView` nennt in der Datenschutzerklärung Fotos geteilter Artikel und den Open-Prices-Beitrag (Bonfoto, Filiale, Preise, Benutzername) und trägt „Stand: Oktober 2026“; die Nutzungsbedingungen tragen ebenfalls „Stand: Oktober 2026“ und enthalten keine Zeile „Geteilte Listen Add-on“ mehr. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-5:** Nach A1 sind Unit-Suite und `LocalizationKeyParityTests` grün. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-6:** `InfoPlist.strings` in `de.lproj` und `en.lproj` mit `NSCameraUsageDescription` und `NSPhotoLibraryUsageDescription`, nicht leer, gleiche Schlüssel; Kameratext nennt Bons, Barcodes und Rezeptfotos, Fototext Bons und Rezeptfotos. `::testCameraTextNamesReceiptsBarcodesAndRecipes` — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-7:** `project.yml` und `project.pbxproj` führen `CURRENT_PROJECT_VERSION` 37, übereinstimmend; Strings-Dateien sind in den Ressourcen des App-Ziels registriert. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-8:** Nach A2 sind Unit-Suite und `LocalizationKeyParityTests` grün; Durchlauf als Nutzer: Build 37 im Simulator, Einstellungen → Datenschutzerklärung zeigt den Fotos-Satz, der Kamera-Aufruf des Bon-Scans zeigt den lokalisierten Text. `docs/artifacts/feat-175-app-store-auftritt/` — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9 (B1, korrigiert):** `docs/appstore/de.md` und `en.md` enthalten genau die Überschriften `## name`, `## subtitle`, `## keywords`, `## promotional_text`, `## description`, `## support_url`, `## privacy_url` (kein `whats_new`), jede mit nicht leerem Wert. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9a (B1):** Grenzen eingehalten: Name 2–30 Zeichen, Untertitel ≤ 30, Werbetext ≤ 170, Beschreibung ≤ 4000, Schlüsselwörter ≤ 100 **Bytes** (UTF-8) und kein Wort ≤ 2 Zeichen; Werte entsprechen der Tabelle „Felder und gezählte Längen“. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9b (B1):** Verbotene Begriffe fehlen in beiden Dateien (ohne Groß-/Kleinschreibung): „Nachkauf“, „Erinnerung“, „replenish“, „reminder“, „Open Prices“, „KI-Preis“/„AI price“, „Was ist neu“/„What's new“; die Schlüsselwörter enthalten weder „Einkaufsliste“ noch „shopping list“ noch „Restock“. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9c (B1):** Beide Beschreibungen enthalten ausgeschrieben `https://emmrich-business.com/datenschutz` und `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`; `privacy_url` ist in beiden Dateien gleich, `support_url` ist `https://emmrich-business.com/support.html`. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9d (B1):** `docs/appstore/datenschutz.md` hat `## Deutsch` und `## English`; der Abschnitt Deutsch ist wortgleich mit `LegalView.privacyPolicy`; der englische Abschnitt nennt, dass die deutsche Fassung maßgeblich ist. Ausgabe im Artefakt — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-9e (B2b, Merkpunkt F001 der B1-Prüfung):** Die Werte in `docs/appstore/{de,en}.md` gleichen dem Spec-Wortlaut (Abschnitt „Texte“ und Tabelle „Felder und gezählte Längen“: Name, Untertitel, Schlüsselwörter, Werbetext, `support_url`, `privacy_url`; die Beschreibung gleicht dem Codeblock der Spec), und beide Dateien sowie `datenschutz.md` enthalten keine unsichtbaren Zeichen (U+200B, U+00A0, U+00AD, U+FEFF), kein CR (`\r`) und kein BOM am Dateianfang. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10 (B2a):** Die ASC-Skripte (`asc_lib.py`, `asc_publish.py`) rufen nur `https://api.appstoreconnect.apple.com/` auf, nur GET/POST/PATCH, nur Pfade der eigenen App-ID (bzw. IDs aus deren Antworten), geben Token und Schlüsselinhalt nie aus und kennen keinen Einreichungs-Endpunkt (`reviewSubmissions`, `appStoreVersionSubmissions`). Die Unterpunkte AC-10a bis AC-10h machen das prüfbar; AC-10 gilt als erfüllt, wenn alle gelten. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10a (Host, Methoden, Pfade):** `api` lehnt jeden anderen Host als `api.appstoreconnect.apple.com`, jede andere Methode als GET/POST/PATCH und jeden Pfad außerhalb der Erlaubnisliste ab, bevor `send` aufgerufen wird. Erlaubt sind nur `/v1/apps` mit Filter, `/v1/apps/{id}/appStoreVersions`, `/v1/apps/{id}/appInfos`, `/v1/appStoreVersions/{id}/appStoreVersionLocalizations`, `/v1/appInfos/{id}/appInfoLocalizations`, `/v1/appStoreVersionLocalizations[/{id}]`, `/v1/appInfoLocalizations[/{id}]`. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10b (nur eigene App):** In einem Durchlauf mit Schein-`send` liegen alle Pfade unter der App-ID aus der Antwort auf `filter[bundleId]=com.johannesemmrich.Restock` bzw. unter IDs, die aus den Antworten auf diese Pfade stammen; kein Pfad enthält eine andere ID. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10c (Trockenlauf schreibt nie):** Ohne `--apply` ruft `asc_publish` `send` nie mit POST oder PATCH auf und gibt den geplanten Unterschied aus; Exit 0. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10d (Zustandsprüfung vor jedem Schreiben):** Bei 0 oder mehr als 1 App, Version oder appInfo im Zustand `PREPARE_FOR_SUBMISSION` sowie bei jedem anderen oder unbekannten Zustandswert bricht `asc_publish` mit Fehler (Exit ≠ 0) ab, auch mit `--apply`; bis dahin gab es nur GETs. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10e (409-Vermeidung, Feldzuordnung):** Für eine vorhandene Sprache gibt es nie ein POST, sondern ein PATCH mit nur den abweichenden Feldern; nur für eine fehlende Sprache ein POST (mit Relationship auf Version bzw. appInfo). Gesendet werden nur `description`, `keywords`, `promotionalText`, `supportUrl` (Version) und `name`, `subtitle`, `privacyPolicyUrl` (appInfo); `whatsNew` kommt nie vor. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10f (Idempotenz):** Ein Lauf mit `--apply` gegen Schein-Daten, die den Dateien schon gleichen, ruft weder POST noch PATCH auf; ein zweiter Lauf nach einem ersten, dessen Schreibaufrufe der Schein-Zustand übernimmt, ebenso. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10g (keine Geheimnisse in Ausgabe und Fehlern):** Weder Token noch Schlüsselinhalt noch der Wert von `ASC_KEY_PATH` erscheinen in Ausgabe, Fehlermeldungen oder Ausnahmen; Fehlermeldungen von `api` enthalten nur Status und Pfad. Der Schlüssel wird von den Skripten nie gelesen, der Pfad geht nur als Argument an `openssl`; `exp` ≤ `iat` + 1200 s, `aud` `appstoreconnect-v1`; eine DER-Signatur wird mit fester Probe korrekt nach R‖S (64 Byte) umgewandelt. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-10h (Quelltextverbote):** Im Quelltext von `asc_lib.py` und `asc_publish.py` kommen nicht vor: `shell=True`, `DELETE`, `reviewSubmissions`, `appStoreVersionSubmissions`, `whatsNew`, fremde Hosts (jede URL außer `https://api.appstoreconnect.apple.com`), das Öffnen oder Lesen der Schlüsseldatei (`open(` auf `ASC_KEY_PATH`) und jede Drittbibliothek (nur Standardbibliothek); `openssl` wird als Argumentliste aufgerufen. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-11:** Version 1.0 hat in de-DE und en-US Beschreibung, Schlüsselwörter, Werbetext, Support-URL (kein „Was ist neu“, für die erste Version nicht verfügbar); `appInfoLocalizations` haben Name, Untertitel, Datenschutz-URL; gelesene Werte sind wortgleich mit den Dateien. `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt` — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-12:** Die Datenschutz-URL liefert HTTP 200, enthält die Aussagen zu öffentlicher Datenbank (geteilte Läden, Community-Preise, Fotos), Kamera/Bon-Scan und Open Food Facts, auf Deutsch und Englisch. **Blockiert, solange die Seite nicht berichtigt ist.** — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-13:** Kategorie (primär, sekundär), Altersfreigabe, Content Rights, Preise/Verfügbarkeit der App sind gesetzt. `primaryCategory`/`secondaryCategory`, `appPriceSchedule`, `appAvailabilityV2`, Attribut `contentRightsDeclaration` der App), erwartet „ok“; was die API nicht kann, per Browser mit Beleg-Screenshot — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-14:** Der App-Privacy-Fragebogen ist ausgefüllt und veröffentlicht mit genau den sechs Datentypen der Tabelle (Name, Sonstige Nutzerinhalte, Fotos oder Videos, Kaufverlauf, Nutzer-ID verknüpft; Geräte-ID nicht verknüpft), Tracking nein. Dafür gibt es keine öffentliche API; `asc_check` meldet „manuell belegen“ (nie „ok“). `docs/artifacts/feat-175-app-store-auftritt/`, zeilenweise gegen die Tabelle abgeglichen — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-15:** Abo-Gruppe „Restock Pro“ mit monthly und yearly sowie das nicht verbrauchbare lifetime (`com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}`), Preise 1,99 / 8,99 / 14,99 € (Basisland Deutschland), Anzeigename und Beschreibung de und en, je ein Review-Screenshot; kein Produkt `sharedlists`. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-16:** Ein Satz iPhone-Screenshots 6,9" (1320×2868) je Sprache in ASC, 3 bis 10 Bilder, aus dem Simulator mit `-premiumForScreenshots` und gesäten Daten, ohne echte Namen oder Fotos; die Bilder gehen vor dem Hochladen an Henning. `docs/artifacts/feat-175-app-store-auftritt/screenshots/{de,en}/`, erwartet 1320×2868; `python3 scripts/asc_check.py --section screenshots`, erwartet „ok“ mit 3 bis 10 Bildern je Sprache (Maße aus den Attributen, nicht aus dem Enum-Namen) — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-17:** Build 37 oder höher (Verarbeitung abgeschlossen) ist Version 1.0 zugeordnet; Export-Compliance beantwortet (`ITSAppUsesNonExemptEncryption` false). — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-17a (Review-Kontakt):** Version 1.0 hat ein `appStoreReviewDetail` mit nicht leerem Vor- und Nachnamen, E-Mail und Telefon des Kontakts und `demoAccountRequired` false; die Ausgabe zeigt je Feld nur „gesetzt“ oder „leer“, nie den Wert. — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-18:** Es wurde nichts eingereicht und nichts außenwirksam veröffentlicht ohne Hennings ausdrückliches Wort; der Status der Version ist `PREPARE_FOR_SUBMISSION`. verbieten die Einreichungs-Endpunkte in den Skripten — nicht Gegenstand von B3a
- (außerhalb B3a, kein Nachweis in diesem Durchgang) **AC-19 (Definition of Done des Tickets):** Alle Abschnitte von `asc_check.py` in einem Lauf „ok“: Name, Untertitel, Beschreibung, Schlüsselwörter, Support-URL, Datenschutz-URL, Kategorie, Altersfreigabe, Content Rights, Preise/Verfügbarkeit, Build, Screenshots je Sprache, drei Käufe vollständig, Review-Kontakt/-Hinweise. Der App-Privacy-Fragebogen (AC-14) ist per API nicht lesbar: `--all` weist ihn als „manuell belegen“ aus; AC-19 gilt als erfüllt, wenn alle API-Abschnitte „ok“ sind und der Beleg-Screenshot zu AC-14 vorliegt. Commit-Kennung — nicht Gegenstand von B3a
- [x] **AC-20 (B2b, Werkzeug selbst):** `scripts/asc_check.py` liest nur, hält Host, Methode und Leseliste ein, gibt keine Geheimnisse aus und meldet Abweichungen eindeutig. AC-20 gilt als erfüllt, wenn AC-20a bis AC-20g gelten; geprüft mit Schein-Antworten (Schein-`send`, Schein-`sign`, Schein-Opener), ohne Netz und ohne Schlüssel.
- [x] **AC-20a (Zaun):** `read` lehnt vor `send` ab: jeden anderen Host als `api.appstoreconnect.apple.com`, jede Methode außer GET (POST, PATCH, DELETE, PUT), jeden Pfad außerhalb der Leseliste (z. B. `/v1/apps/{id}/builds` mit fremder ID, `/v2/apps`) und die Einreichungs-Endpunkte `reviewSubmissions`, `appStoreVersionSubmissions`.
- [x] **AC-20b (Datenschutzseite, fremder Host):** Der Abruf von `https://emmrich-business.com/datenschutz` sendet keinen Authorization-Header, folgt keiner Weiterleitung (3xx = Fehler mit Status) und lässt keine andere URL zu; das Token erreicht den Fremdhost nie.
- [x] **AC-20c (Abschnitte ok und Abweichung):** Jeder Abschnitt (`metadata`, `privacy-url`, `appinfo`, `iap`, `screenshots`, `build`, `review`, `status`) meldet bei passenden Schein-Daten „ok“ (Exit 0) und bei abweichenden „Abweichung“ (Exit ≠ 0); die Ausgabe nennt Feld, Soll und Ist. `::test_section_appinfo_ok_and_deviation`, `::test_section_iap_ok_and_deviation`, `::test_section_screenshots_checks_pixel_size_not_enum`, `::test_section_build_ok_and_deviation`, `::test_section_review_ok_and_deviation`, `::test_section_status_ok_and_deviation`, `::test_deviation_names_field_expected_actual`
- [x] **AC-20d (`--all`, App Privacy):** `--all` endet mit Exit 0 nur, wenn alle API-Abschnitte „ok“ sind; der Fragebogen (AC-14) steht in der Ausgabe als „manuell belegen“, nie als „ok“. Genügt ein Abschnitt nicht, ist der Exit ≠ 0.
- [x] **AC-20e (keine Geheimnisse):** Weder Token noch Schlüsselinhalt noch der Wert von `ASC_KEY_PATH` erscheinen in Ausgabe, Fehlern oder Protokoll; Fehlermeldungen des Zauns enthalten nur Status und Pfad (wie AC-10g).
- [x] **AC-20f (Quelltextverbote):** Im Quelltext von `asc_check.py` kommen nicht vor: `shell=True`, die Zeichenfolgen `POST`, `PATCH`, `DELETE`, `PUT` als Methodenaufruf, `reviewSubmissions`, `appStoreVersionSubmissions`, fremde Hosts (jede URL außer `https://api.appstoreconnect.apple.com` und `https://emmrich-business.com/datenschutz`), das Öffnen oder Lesen der Schlüsseldatei (`open(` auf `ASC_KEY_PATH`) und jede Drittbibliothek (nur Standardbibliothek).
- [x] **AC-20g (Protokoll):** Die Ausgabe von `--all` beginnt mit Zeitstempel (UTC) und Commit-Kennung (`git rev-parse HEAD` als Argumentliste; ist sie nicht ermittelbar, steht `unbekannt`), damit B3 die Ausgabe unverändert als `asc-readback.txt` ablegen kann.
- [x] **AC-21 (B2b, CI):** `.github/workflows/ci.yml` führt im Schritt „Strukturtests (Python)“ `scripts/test_asc_texts.py`, `scripts/test_asc_scripts.py` und `scripts/test_asc_check.py` aus (ohne Netz, ohne Schlüssel).
- [x] **AC-22 (B3a, Werkzeug):** `asc_check` liest Einmalkauf-Lokalisierung, -Review-Screenshot und -Preis nur über die 4.5.1-Pfade und wertet Preise nur nach Gültigkeit und Preispunkt; ein falscher Preis wird nie „ok“. AC-22 gilt, wenn AC-22a bis AC-22g gelten.
- [x] **AC-22a (v2-Pfade, v1 verboten):** `section iap` ruft `/v2/inAppPurchases/{id}/inAppPurchaseLocalizations` und `…/appStoreReviewScreenshot` auf; `/v1/inAppPurchases/{id}/inAppPurchaseLocalizations` und `/v1/inAppPurchases/{id}/appStoreReviewScreenshot` werden vom Zaun vor `send` abgelehnt (Pfadmuster). Dass die Kauf-ID nie als Plan-ID benutzt wird, kann der Zaun nicht am Muster erkennen (beide IDs stammen aus Antworten); das belegt AC-22b über die tatsächlich aufgerufenen Pfade.
- [x] **AC-22b (Plan-ID aus der Antwort):** Der Fake liefert Plan-ID `PLAN-x` ≠ Kauf-ID `IAP-life`; die Preisabfragen gehen an `…/PLAN-x/manualPrices` und `…/PLAN-x/automaticPrices`, nie an die Kauf-ID. Antwortet `iapPriceSchedule` ohne Plan, ist das eine Abweichung.
- [x] **AC-22c (manual oder automatic):** Ist `manualPrices` leer und `automaticPrices` mit 14,99 € gefüllt, ist der Preis „ok“; mit falschem Betrag in `automaticPrices` ist es eine Abweichung.
- [x] **AC-22d (Gültigkeit):** Ein Eintrag mit `endDate` < heute und ein Eintrag mit `startDate` > heute werden ignoriert; gewertet wird nur der gültige (`startDate` null/≤ heute, `endDate` null/≥ heute). Der Test stellt „heute“ ein und liegt so, dass ein Fehler im Filter den Betrag ändern würde.
- [x] **AC-22e (Zuordnung über Preispunkt):** Bei mehreren Einträgen und Preispunkten in `included` zählt der Betrag des Preispunkts, auf den der gültige Eintrag zeigt, nicht der erste `customerPrice`; kein gültiger Eintrag, ein gültiger ohne auflösbaren Preispunkt oder mehrere gültige mit verschiedenem Betrag sind Abweichungen, nie „ok“.
- [x] **AC-22f (Abo, gleiche Regel):** `/v1/subscriptions/{id}/prices` mit `include=subscriptionPricePoint,territory` wird nach derselben Gültigkeits- und Zuordnungsregel gewertet (abgelaufener Eintrag ignoriert, Betrag über den Preispunkt, falscher Betrag = Abweichung).
- [x] **AC-22g (Bestand):** Alle AC-20-Tests und `test_section_iap_ok_and_deviation` bleiben grün; „heute“ ist injizierbar, kein Test hängt von der Systemuhr ab.

## Dialog

### Runde 1
**Adversary:** Behauptung: B3a liest Einmalkauf-Lokalisierung, -Screenshot und -Preis über die 4.5.1-Pfade, holt die Plan-ID aus `iapPriceSchedule`, wertet `manualPrices` und `automaticPrices` nur nach Gültigkeit (startDate/endDate) und über den Preispunkt in `included`, und lässt nie einen falschen Preis als „ok“ durch. Ich glaube das nicht und verlange Belege je Punkt.

Eigene Testläufe (Ausgabe vollständig in `docs/artifacts/feat-175-b3-asc-eintragen/adversary-test-output.txt`):
- `python3 -I scripts/test_asc_check.py -v`: Ran 28 tests, OK (Exit 0), 0 übersprungen.
- `python3 -I scripts/test_asc_scripts.py`: Ran 15 tests, OK (Exit 0).
- `python3 -I scripts/test_asc_texts.py`: Ran 10 tests, OK (Exit 0).
- Diff seit acef2e8 für `scripts/asc_lib.py`, `scripts/asc_publish.py`, `.github/workflows/ci.yml`: leer, also keine Rückwirkung auf Schreibweg und CI.

Mutationsproben (Kopie von `asc_check.py` im Scratchpad verändert, Testdatei unverändert dagegen laufen lassen):
- „erster customerPrice“ statt Preispunkt-Zuordnung: getötet (5 Tests rot, u. a. `test_price_mapped_via_price_point_not_first`).
- endDate ignoriert: getötet (4 rot). startDate ignoriert: getötet (3 rot).
- endDate exklusiv (endDate = heute ungültig): getötet. startDate exklusiv: getötet.
- Plan-ID = Kauf-ID (`pid = plan["id"]` entfernt): getötet (10 rot).
- nur `manualPrices` (automaticPrices weggelassen): getötet (4 rot).
- „Sollbetrag ist unter den gültigen“ statt „genau dieser eine Betrag“: getötet (`test_no_valid_price_is_deviation`).
- „heute“ fest auf Systemuhr: getötet (`test_today_is_injectable`).
- Abo-Abfrage ohne `,territory`: getötet (`test_subscription_price_same_validity_rule`).
- Gültiger Eintrag ohne auflösbaren Preispunkt wird still verworfen statt als „Preispunkt fehlt“ gezählt: ÜBERLEBT (F001).
- Preispunkt-Zuordnung nur über die ID, ohne Typ: ÜBERLEBT (F002).

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/test_asc_check.py:429
  Description: `test_no_valid_price_is_deviation` prüft „gültiger Eintrag ohne auflösbaren Preispunkt“ nur als einzigen Eintrag. Dort ist er von „kein gültiger Preis“ nicht zu unterscheiden. Die Mutation, die solche Einträge still verwirft (`amounts.extend([] if got is None else …)`), bleibt grün. Der Code selbst ist richtig: die Probe „gültig 14,99 + gültig ohne Preispunkt“ ergibt „Abweichung … Ist 14.99, Preispunkt fehlt“ mit Exit 1.
  Spec requirement: AC-22e: „ein gültiger ohne auflösbaren Preispunkt … sind Abweichungen, nie ‚ok‘“
  Conflict: Das Verhalten stimmt, aber kein Test hält es gegen einen Rückfall fest; ein späterer Umbau könnte einen falschen „ok“ (14,99 aus manual, unbekannter Preis aus automatic) wieder durchlassen.
  Remediation: In `test_no_valid_price_is_deviation` einen Fall `[("manual", None, None, "14.99"), ("automatic", None, None, None)]` ergänzen, erwartet Abweichung mit „Preispunkt fehlt“.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:215
  Description: `valid_amounts` schlüsselt die Preispunkte nach (type, id) und vergleicht den Typ der Beziehung. Das ist richtig (Probe: Preispunkt gleicher ID mit Typ `territories` ergibt „Preispunkt fehlt“, Abweichung). Die Mutation „nur nach ID“ bleibt aber grün, weil kein Test eine gleiche ID mit anderem Typ in `included` legt (z. B. Territorium „DEU“ neben einem Preispunkt „DEU“).
  Spec requirement: AC-22e: Betrag des Preispunkts, auf den der gültige Eintrag zeigt
  Conflict: Kein Verstoß, nur fehlende Absicherung.
  Remediation: Optional ein Testfall mit Ressource gleicher ID, aber anderem Typ in `included`.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:62
  Description: Der Stichtag ist `datetime.date.today()` (lokale Zeit des Rechners), der Protokollkopf trägt UTC. Zwischen Mitternacht und 1 bzw. 2 Uhr deutscher Zeit nennt das Protokoll den Vortag, gewertet wird aber der neue Tag. Welche Zeitzone Apple für startDate/endDate meint, ist nicht belegt.
  Spec requirement: AC-22d/AC-22g: „heute“ injizierbar, Standard `date.today()`
  Conflict: Kein Spec-Verstoß (die Spec nennt ausdrücklich `date.today()`), aber das Protokoll aus B3 zeigt den Stichtag nicht und kann am Tag eines Preiswechsels missverständlich sein.
  Remediation: Stichtag in den Protokollkopf schreiben (z. B. „Stichtag 2026-10-25“) oder `today` aus dem UTC-Zeitstempel ableiten.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:220
  Description: Leere Zeichenkette als startDate/endDate gilt wie null (Probe: `startDate ""` mit 14,99 ergibt „ok“). Kaputte Formate (`2026-10-01T00:00:00Z`, „morgen“, Zahl) werfen ValueError/TypeError; das endet als „Fehler iap“ mit Exit 1, nie als „ok“, bricht aber den ganzen Abschnitt ab (monthly/yearly werden dann nicht mehr geprüft, Probe mit `--all`).
  Spec requirement: AC-22d: gewertet wird nur `startDate` null/≤ heute, `endDate` null/≥ heute
  Conflict: Leere Zeichenkette ist nicht null; praktisch ohne Folge, weil Apple das Feld als Datum oder null liefert. Der Abbruch des Abschnitts ist sicher (Exit ≠ 0), nennt aber weder Produkt noch Feld.
  Remediation: Optional: nur `None` als offen behandeln, sonst `fromisoformat` erzwingen; Fehlermeldung mit Produktname versehen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:237
  Description: Preisantworten werden nur von der ersten Seite gelesen; `links.next` wird nicht verfolgt (Probe: Antwort mit `links.next` ergibt „ok“ aus Seite 1). Mit `filter[territory]=DEU` sind es nur wenige Einträge je Produkt, eine zweite Seite ist praktisch ausgeschlossen. Läge ein zweiter gültiger Betrag dennoch auf Seite 2, entginge er der Regel „mehrere gültige mit verschiedenem Betrag = Abweichung“.
  Spec requirement: AC-22e (mehrere gültige mit verschiedenem Betrag = Abweichung)
  Conflict: Theoretischer falscher „ok“ nur bei mehr als einer Seite DEU-Preise; Bestandsmuster aus B2b (auch andere Listen ohne Seitenwechsel).
  Remediation: Optional: ist `links.next` vorhanden, Abweichung „mehr als eine Seite“ melden statt weiterzublättern (hielte den Zaun eng).

Kantenproben ohne Befund (eigene Skripte im Scratchpad, `python3 -I`, Repo nur gelesen):
- `data` als Objekt statt Liste in der Preisantwort: AttributeError, „Fehler iap“, Exit 1, kein „ok“.
- Plan-Antwort ohne `id`: KeyError (schon in `Reader.get`), Fehler, Exit 1; Plan als Liste: TypeError, Fehler; Plan null: „Abweichung … kein Preisplan“ (Test vorhanden).
- `attributes` null / `included` null: Fehler, Exit 1. `relationships` null: „Preispunkt fehlt“, Abweichung.
- customerPrice „14,99“: InvalidOperation, Fehler; 14.99 als Zahl: ok; „14.990“: ok (Decimal gleich); null: „Preispunkt fehlt“.
- startDate nach endDate (verdreht): „kein gültiger Preis“, Abweichung.
- Kompaktformat „20261001“ nimmt `date.fromisoformat` (Python 3.15) an und wertet es richtig.
- Keine Ausgabe enthielt Token oder `ASC_KEY_PATH` (geprüft gegen `fake.tokens` und den Schein-Schlüsselpfad).

Zaun-Proben (`check_read` direkt): erlaubt nur `…/iapPriceSchedule` ohne Abfrage, `manualPrices`/`automaticPrices` nur mit exakt `include=inAppPurchasePricePoint` + `filter[territory]=DEU` in dieser Reihenfolge, Abo-Preise nur mit `include=subscriptionPricePoint,territory` + `filter[territory]=DEU`. Abgelehnt: vertauschte Parameter, `USA`, fehlende Abfrage, leeres `?`, Abo-Abfrage am IAP-Pfad, `/v2/inAppPurchases/IAP-life` ohne Unterpfad, `/v2/inAppPurchases`, `/v1/inAppPurchases/…/inAppPurchaseLocalizations`, `..`-Pfade, `//evil/…`, Plan-ID nicht aus einer Antwort (`PLAN-y`), jedes POST.

Confirmation:
  AC: AC-22a
  Code reference: scripts/asc_check.py:22
  Evidence: `PRODUCT_PATHS["IAP"]` nur `/v2/inAppPurchases/…/inAppPurchaseLocalizations` und `…/appStoreReviewScreenshot`; Zeile 39 baut den Zaun nur daraus, die v1-Muster sind weg. Zaun-Probe lehnt `/v1/inAppPurchases/IAP-life/inAppPurchaseLocalizations` vor `send` ab; `test_iap_uses_v2_paths_and_fence_rejects_v1` grün mit `send.assert_not_called()`.
  Status: CONFIRMED

Confirmation:
  AC: AC-22b
  Code reference: scripts/asc_check.py:232
  Evidence: `plan = rd.data(IAP_PLAN…)`, `pid = plan["id"]`; Abweichung „kein Preisplan“ bei leerer Antwort. Mutation „Kauf-ID weiterverwenden“ macht 10 Tests rot; `test_price_plan_id_taken_from_schedule_response` prüft, dass kein Pfad `/inAppPurchasePriceSchedules/IAP-life` aufgerufen wird.
  Status: CONFIRMED

Confirmation:
  AC: AC-22c
  Code reference: scripts/asc_check.py:25
  Evidence: `PRICE_PATHS["IAP"]` liest `manualPrices` und `automaticPrices` und vereinigt die gültigen Beträge (Zeile 237). Mutation „nur manual“ getötet; `test_price_found_under_automatic_prices` prüft ok mit 14.99 und Abweichung mit 19.99.
  Status: CONFIRMED

Confirmation:
  AC: AC-22d
  Code reference: scripts/asc_check.py:220
  Evidence: Der Filter überspringt startDate nach heute und endDate vor heute; startDate = heute und endDate = heute gelten. Alle vier Grenzmutationen (start/end ignoriert, start/end exklusiv) getötet von `test_price_ignores_expired_and_future_entries`.
  Status: CONFIRMED

Confirmation:
  AC: AC-22e
  Code reference: scripts/asc_check.py:223
  Evidence: Betrag über (type, id) der Beziehung aus `included`; fehlt er, zählt „Preispunkt fehlt“; Zeile 241 verlangt als Menge genau den Sollbetrag. Mutationen „erster customerPrice“ und „Soll unter den gültigen“ getötet; eigene Probe „gültig 14,99 + gültig ohne Preispunkt“ ergibt Abweichung (Testlücke dazu: F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-22f
  Code reference: scripts/asc_check.py:27
  Evidence: `PRICE_QUERY["SUB"]` = `include=subscriptionPricePoint,territory` + `filter[territory]=DEU`, dieselbe Funktion `valid_amounts` mit `PRICE_POINT["SUB"]`. `test_subscription_price_same_validity_rule` prüft abgelaufen/zukünftig/Köder und die exakte Abfrage; Mutation ohne `,territory` getötet.
  Status: CONFIRMED

Confirmation:
  AC: AC-22g
  Code reference: scripts/test_asc_check.py:159
  Evidence: `run()` reicht immer `today=TODAY` (Zeile 41) an `main` durch; `Reader(…, today=today)` in `asc_check.py:338`. Mutation „Systemuhr“ getötet von `test_today_is_injectable` (Zeile 451). Alle AC-20-Tests und `test_section_iap_ok_and_deviation` (Zeile 208) grün.
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt; Prüfung ohne Gegenrede, Belege aus eigenen Läufen und Proben)

### Runde 2
**Adversary:** Regression AC-20a bis AC-20g und AC-21, und Nachbohren an den Stellen, an denen Runde 1 grün war.

- Rückwirkung: `asc_lib.py`, `asc_publish.py`, `ci.yml` seit acef2e8 unverändert (leerer Diff); `test_asc_scripts.py` 15/15 grün.
- `Reader.ids` nimmt die Plan-ID aus `data` (Objekt) auf, damit lässt der Zaun `…/PLAN-x/manualPrices` zu; `PLAN-y` (nicht aus einer Antwort) wird abgelehnt (Probe). Die Abo-Antwort bringt das Territorium „DEU“ als ID in den Pool; das ist das Bestandsmuster (jede ID aus einer Antwort zählt) und öffnet keinen neuen Pfadtyp, weil die Muster fest sind.
- Ein falscher Pfad oder eine kaputte Antwort endet immer als „Fehler“ des Abschnitts mit Exit 1 (`main`, ab Zeile 344), nie als „ok“; bestätigt mit Proben für Datumsformat, Objekt statt Liste, Plan ohne ID.
- Mutationsergebnis bleibt: alle Kernregeln (Pfad, Plan-ID, manual+automatic, Gültigkeit, Zuordnung, genau ein Betrag, Stichtag, Abo-Abfrage) sind durch Tests abgesichert; offen nur die Absicherungslücken F001/F002.

Confirmation:
  AC: AC-20a
  Code reference: scripts/asc_check.py:43
  Evidence: `check_read` lehnt Nicht-GET, nicht relative Pfade, Pfade außerhalb `FENCE` und IDs nicht aus Antworten ab; neue Muster (Zeilen 39–40) nur mit exakter Abfrage. `test_fence_rejects_before_send` (test_asc_check.py:280) und `test_only_get_and_ids_from_answers` (Zeile 301, Host-Regex jetzt `v[12]`) grün; eigene Zaun-Proben siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-20b
  Code reference: scripts/asc_check.py:79
  Evidence: `fetch_privacy` unverändert (nur `PRIVACY_URL`, Header leer); `test_privacy_fetch_without_authorization_and_redirect` und `test_privacy_fetch_only_exact_url` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-20c
  Code reference: scripts/test_asc_check.py:208
  Evidence: Alle Abschnittstests ok/Abweichung grün, `test_section_iap_ok_and_deviation` jetzt gegen den Fake mit Preisplan; `test_deviation_names_field_expected_actual` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-20d
  Code reference: scripts/asc_check.py:349
  Evidence: `--all` druckt AC-14 als „manuell belegen“, Exit 0 nur ohne Abweichung und ohne Abschnittsfehler; `test_all_exit_zero_only_if_all_api_sections_ok` und `test_privacy_questionnaire_reports_manual` grün; Probe `--all` mit kaputtem Datum ergibt Exit 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-20e
  Code reference: scripts/asc_check.py:67
  Evidence: HTTP-Fehler nennen nur Status und Pfad ohne Abfrage; neue Fehlerwege (ValueError aus `fromisoformat`) nennen nur den Datumswert. `test_no_secrets_in_output_or_errors` grün; eigene Proben ohne Token/Schlüsselpfad in der Ausgabe.
  Status: CONFIRMED

Confirmation:
  AC: AC-20f
  Code reference: scripts/test_asc_check.py:342
  Evidence: `test_source_bans` grün; der neue Code fügt nur relative Pfade (`/v2/…`, `/v1/…`) hinzu, keine URL, kein `open(`, kein Schreibverb, keine Drittbibliothek (nur `datetime`, `decimal`).
  Status: CONFIRMED

Confirmation:
  AC: AC-20g
  Code reference: scripts/asc_check.py:334
  Evidence: Kopfzeile mit UTC-Zeitstempel und Commit (oder „unbekannt“) unverändert; `test_protocol_has_timestamp_and_commit` (test_asc_check.py:458) grün. Hinweis zur Zeitzone des Stichtags: F003.
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: scripts/asc_check.py:1
  Evidence: `.github/workflows/ci.yml` Zeilen 42–44 führen `test_asc_texts.py`, `test_asc_scripts.py`, `test_asc_check.py` in der Schleife „Strukturtests (Python)“, seit acef2e8 unverändert; `test_asc_texts.py::test_ci_runs_asc_tests` grün. Ein grüner CI-Lauf des PR ist noch nicht belegt (kommt nach dem Push).
  Status: CONFIRMED

Confirmation:
  AC: AC-22
  Code reference: scripts/asc_check.py:228
  Evidence: `check_price` erfüllt AC-22a bis AC-22g (siehe Runde 1); kein Weg ergibt „ok“ für einen falschen oder fehlenden Preis (Mutationen und Kantenproben), mit der theoretischen Ausnahme F005 (zweite Antwortseite).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachprüfung der Testergänzungen zu F001 und F002. Geändert ist nur `scripts/test_asc_check.py` (13 Zeilen); `scripts/asc_check.py` ist gegenüber Runde 1 und 2 unverändert (Diff seit acef2e8 weiter 48 hinzu / 14 weg, alle Mutationsanker gefunden).

Eigene Läufe neu (Ausgabe überschrieben in `docs/artifacts/feat-175-b3-asc-eintragen/adversary-test-output.txt`): `test_asc_check.py -v` 28 OK, `test_asc_scripts.py` 15 OK, `test_asc_texts.py` 10 OK, Exit je 0, 0 übersprungen.

Eigene Mutationsläufe neu (dieselben 12 Mutanten wie in Runde 1, nicht die Skripte des Developers): alle 12 getötet. Neu getötet:
- „None verwerfen“ (F001): rot in `test_no_valid_price_is_deviation`.
- „nur nach ID“ (F002): rot in `test_price_mapped_via_price_point_not_first`.

Gegenprobe der Testlogik: Im F002-Fall mit Betrag 4.99 steht der fremde Punkt vorn und der echte hinten; unter der Mutante „nur nach ID“ würde der echte überschreiben, daher tötet erst der zweite Fall (nur fremder Punkt 14.99, eigener fehlt) die Mutante; der Original-Code meldet dort „Preispunkt fehlt“. Das ist eine tragfähige Absicherung.

Confirmation:
  AC: AC-22e (F001 behoben)
  Code reference: scripts/test_asc_check.py:447
  Evidence: Fall „manual 14.99 gültig + automatic gültig ohne Preispunkt“ verlangt Abweichung und den Text „Preispunkt fehlt“ (Zeile 448); Mutante „None verwerfen“ wird rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-22e (F002 behoben)
  Code reference: scripts/test_asc_check.py:436
  Evidence: `FakeASC.foreign_type_points` (Zeile 77, eingefügt in `price_doc` Zeile 143–145) legt einen Preispunkt gleicher ID mit fremdem Typ vorn in `included`; Zeile 436–438 verlangt Abweichung, wenn nur dieser fremde Punkt den Sollbetrag trägt. Mutante „nur nach ID“ wird rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-22e
  Code reference: scripts/asc_check.py:215
  Evidence: Code unverändert; Schlüssel (type, id) jetzt durch Test abgesichert.
  Status: CONFIRMED

Stand der Findings:
- F001: behoben (Testfall ergänzt, Mutante getötet).
- F002: behoben (Testfall ergänzt, Mutante getötet).
- F003 (LOW, Stichtag Ortszeit gegen UTC-Protokoll), F004 (LOW, leeres Datum wie null; kaputtes Format bricht den Abschnitt ab, Exit ≠ 0), F005 (LOW, keine zweite Antwortseite): offene Grenzen, kein Spec-Verstoß, bleiben bestehen.

**Implementierer:** Testfälle zu F001/F002 ergänzt, `asc_check.py` unverändert.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Begründung: Alle Punkte von B3a (AC-22, AC-22a bis AC-22g) und die Regression (AC-20a bis AC-20g, AC-21) sind mit eigenen Testläufen, Mutationsproben und Kantenproben belegt. Nach Runde 3 werden alle 12 Mutanten der Preisregel getötet; F001 und F002 sind behoben. Keine Probe ergab ein falsches „ok“ für einen falschen oder fehlenden Preis. Offene Grenzen ohne Spec-Verstoß: F003, F004, F005 (alle LOW).
Tests: 53 bestanden (28 + 15 + 10), 0 fehlgeschlagen, 0 übersprungen
Edge cases: alle geprüft, keiner bricht die Spec
Regressions: keine (asc_check.py seit Runde 1 unverändert; asc_lib, asc_publish, ci.yml unverändert)
Checklist: 17/17 Punkte des Gegenstands belegt (AC-20 bis AC-22g); AC-1 bis AC-19 nicht Gegenstand von B3a

## Geprüfte Dateien

- sha256:7ec8225b78ea143f1165f28fce02425699a81b779f7f363f7330896c810f5aa0  scripts/asc_check.py
- sha256:a133b09c9e52cac951264d9de6c2ba91e5faf9f7beea17392830496de42e42e9  scripts/test_asc_check.py

## Prüfbasis

- base: acef2e847eb992c73426368fa573de855a15c1b9
- blob:dade5db28012488fe8f3b504f600eee8ab7aa38c  scripts/asc_check.py
- blob:7cd78d828ae97971668d8ce773fd18bd35d592e3  scripts/test_asc_check.py

## Geprüfte Dateien

- sha256:7ec8225b78ea143f1165f28fce02425699a81b779f7f363f7330896c810f5aa0  scripts/asc_check.py
- sha256:a133b09c9e52cac951264d9de6c2ba91e5faf9f7beea17392830496de42e42e9  scripts/test_asc_check.py

## Prüfbasis

- base: acef2e847eb992c73426368fa573de855a15c1b9
- blob:dade5db28012488fe8f3b504f600eee8ab7aa38c  scripts/asc_check.py
- blob:7cd78d828ae97971668d8ce773fd18bd35d592e3  scripts/test_asc_check.py
