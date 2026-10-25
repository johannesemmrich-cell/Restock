# Context: feat-175-b3-asc-eintragen

## Request Summary
Issue #175, Durchgang B3: Version 1.0 in App Store Connect so ausfüllen und gegenlesen, dass ein Build ohne fehlende
Pflichtangaben einreichbar ist (Produktseite de/en, Kategorie, Altersfreigabe, App Privacy, Screenshots, drei Käufe,
Build ≥ 37, Review-Kontakt). Erster echter Lauf der Skripte aus B2a/B2b gegen Apple; alles Außenwirksame nur auf Hennings Wort.

## Recherche (2026-10-25, vor jeder Analyse)
Quelle: Apples offizielle OpenAPI-Beschreibung der App Store Connect API, Version **4.5.1**
(`https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip`), jeder Pfad
und jedes Feld von `asc_check.py`/`asc_publish.py` maschinell abgeglichen (Prüfskripte im Scratchpad der Sitzung).

| Pfad im Skript | Apple 4.5.1 | Folge |
|---|---|---|
| `GET /v1/inAppPurchases/{id}/inAppPurchaseLocalizations` | **fehlt**; vorhanden: `/v2/inAppPurchases/{id}/inAppPurchaseLocalizations` | Pfad auf v2 umstellen (sonst „Fehler iap“, HTTP 404) |
| `GET /v1/inAppPurchases/{id}/appStoreReviewScreenshot` | **fehlt**; vorhanden: `/v2/inAppPurchases/{id}/appStoreReviewScreenshot` | Pfad auf v2 umstellen |
| `GET /v1/inAppPurchasePriceSchedules/{id}/manualPrices` mit Kauf-ID als Plan-ID | Pfad vorhanden (`filter[territory]`, `include`), Plan-ID nicht zwingend = Kauf-ID | erst `GET /v2/inAppPurchases/{id}/iapPriceSchedule`, Plan-ID aus der Antwort |
| `GET /v1/subscriptions/{id}/prices` | vorhanden (`filter[territory]`, `include`, neu `filter[planType]`) | bleibt; Apple-Beispiel nutzt `include=subscriptionPricePoint,territory` |
| alle übrigen GET-Pfade (apps, appStoreVersions, appInfos, Kategorien, Altersfreigabe, appPriceSchedule, appAvailabilityV2, inAppPurchasesV2, subscriptionGroups, Lokalisierungen, Screenshot-Sets, build, appStoreReviewDetail) | vorhanden, nicht veraltet | unverändert |
| PATCH/POST `appStoreVersionLocalizations`, `appInfoLocalizations` (asc_publish) | vorhanden | unverändert |

Felder und Zustandswerte, die das Skript erwartet, sind alle im Schema: `InAppPurchaseV2.state` kennt `READY_TO_SUBMIT`,
`inAppPurchaseType` `NON_CONSUMABLE`; `Subscription.state` `READY_TO_SUBMIT`; `Build.processingState` `VALID`,
`usesNonExemptEncryption`; `AppScreenshot.imageAsset` mit `width`/`height`; `AppStoreReviewDetail.contact*`,
`demoAccountRequired`; `AppStoreVersion.appVersionState` `PREPARE_FOR_SUBMISSION`; `App.contentRightsDeclaration`.

Aktueller Preis: `manualPrices` kann geplante künftige Preise mitliefern; der gültige ist der Eintrag mit `startDate`
null, Apple bietet keinen Filter dafür ([Forum 728685](https://developer.apple.com/forums/thread/728685)). Das Skript nimmt
heute den ersten `customerPrice` aus `included` – bei mehreren Einträgen nicht eindeutig. Preisplan und Kennung:
[Forum 732527](https://developer.apple.com/forums/thread/732527), [Forum 711031](https://developer.apple.com/forums/thread/711031).

## Ist-Stand außerhalb des Repos
- Build 37: noch **nicht** hochgeladen (letzter TestFlight-Lauf 2026-10-22 = Build 36). `CURRENT_PROJECT_VERSION` = 37 im Repo.
  Upload über `testflight.yml` mit `build_number=37`, außenwirksam, nur auf Hennings Wort. Ohne ihn bleibt AC-17 offen.
- Datenschutzseite `https://emmrich-business.com/datenschutz`: HTTP 200, aber alter Text (keine Community-Preise, kein
  Open Prices, keine englische Fassung; geprüft 2026-10-25). AC-12 blockiert, bis der Inhalt aus `docs/appstore/datenschutz.md`
  dort steht. Wer die Seite pflegt, ist ein PO-Thema (nicht im Repo).
- ASC-Schlüssel liegt lokal (Downloads, Inhalt nie lesen), Umgebung `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
- Zustand des Entwurfs in ASC (Version 1.0, appInfo, Käufe) ist unbekannt; erst der Lesetrockenlauf zeigt ihn.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_check.py` | Lesepfade `PRODUCT_PATHS`/`PRICE_PATHS`, `check_product` (Preis aus `included`), Zaun `FENCE` – hier die Pfadkorrektur |
| `scripts/test_asc_check.py` | `FakeASC` mit den alten v1-Pfaden; muss die neuen Pfade und den Preisplan-Schritt abbilden |
| `scripts/asc_lib.py` | Token, `urllib_send`, Schreibzaun von `asc_publish` (unverändert) |
| `scripts/asc_publish.py` | Schreibt Texte de-DE/en-US in Version 1.0 und appInfo, Trockenlauf Standard |
| `docs/appstore/{de,en}.md`, `docs/appstore/datenschutz.md` | Sollwerte |
| `docs/specs/appstore/app-store-auftritt.md` | Spec, Abschnitt „Durchgang B3“, AC-11 bis AC-19, Leseliste (Zeilen ~200–232), Offene Grenzen |
| `SmartCart/Services/PremiumService.swift:124-126` | Produktkennungen `com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}` = Soll in `asc_check` |
| `SmartCart/SmartCartApp.swift:38,237ff` | Screenshot-Seed `-seedSharedAssignmentForScreenshots`; `-premiumForScreenshots` in `PremiumService` |
| `docs/artifacts/feat-175-app-store-auftritt/` | Belegordner (A1/A2 vorhanden; B3: `asc-readback.txt`, `screenshots/{de,en}/`) |
| `.github/workflows/testflight.yml` | Upload Build 37 |

## Existing Patterns
- Sicherheitszäune: jeder Pfad als Regex in einer Liste, IDs nur aus vorherigen Antworten, Fehler nur Status + Pfad.
- Trockenlauf zuerst, `--apply` nur ausdrücklich; Gegenlesen mit `asc_check` als Beleg (`asc-readback.txt` mit Zeitstempel/Commit).
- Belege unter `docs/artifacts/<workflow>/`, Screenshots per `simctl io … screenshot` auf eigenem/Wegwerf-Simulator,
  Sperren `/tmp/heavy-build.lock` + `/tmp/loose-ends-testlauf.lock`.
- Vorschau-Regel: Screenshots samt Bildunterschriften de/en als Artefakt-Seite vor dem Hochladen an Henning.
- Browserweg (Chrome-Werkzeug) für alles ohne API: App-Privacy-Fragebogen, ggf. Käufe/Kategorien/Altersfreigabe, mit Beleg-Screenshots.

## Dependencies
- Upstream: App Store Connect API 4.5.1, ASC-Schlüssel, öffentliche Datenschutzseite, Build 37 (TestFlight-Upload).
- Downstream: Einreichung von Version 1.0 (nicht Teil von B3, nur auf Hennings Wort), Release-1.0-Meilenstein.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` – Gesamtspezifikation #175 (A1–B3)
- `docs/specs/ci/testflight-upload-workflow.md` – Upload-Ablauf

## Risks & Considerations
- **Außenwirksam:** jedes Schreiben in ASC, der Upload von Build 37, das Veröffentlichen des Privacy-Fragebogens. Je Schritt
  ausdrückliches Wort; Einreichen gehört nicht zu B3.
- **Erster echter Lauf:** Strukturen der echten Antworten können von `FakeASC` abweichen; Korrekturen am Skript werden mit
  Test nachgezogen (gleiche Zäune, Abweichung nie als falsches „ok“).
- **Käufe anlegen:** Für drei Produkte + Abo-Gruppe gibt es POST-Endpunkte; `asc_lib` erlaubt sie nicht. Anlegen per Browser
  (Beleg-Screenshots) oder Schreibzaun erweitern – Entscheidung in der Analyse. Review-Screenshot je Kauf nötig.
- **Name/Untertitel** im vorhandenen appInfo möglicherweise nicht änderbar (unbelegt).
- **AC-12 blockiert** durch die nicht berichtigte Datenschutzseite.
- **Screenshots:** 6,9" (1320×2868), 3–10 je Sprache, ohne echte Namen/Fotos; Motive und Bildunterschriften vorher zeigen.
- **Umfang:** Pfadkorrektur ~30–60 Zeilen Skript + Test; Belege zählen das Gate ggf. als Dateien (Spec: dann nach Sprache teilen).
- **Nichts auf Hennings Geräten.**

## Analysis

### Type
Feature (Fortsetzung #175: Lesepfade korrigieren, danach echter Lauf gegen App Store Connect)

### Zusatzbefund aus OpenAPI 4.5.1 (2026-10-25, nach dem Kontext)
- Der Preis eines Einmalkaufs steht unter `manualPrices` **oder** `automaticPrices` des Preisplans (`GET /v2/inAppPurchases/{id}/iapPriceSchedule`
  → Plan-ID → `GET /v1/inAppPurchasePriceSchedules/{plan}/manualPrices|automaticPrices`, je `filter[territory]`, `include`).
  Ist das Basisland nicht DEU, liegt der deutsche Preis nur unter `automaticPrices`; das heutige Skript meldete dann „kein Preis“.
- `InAppPurchasePrice.attributes` = `startDate`, `endDate`, `manual`; `SubscriptionPrice.attributes` = `startDate`, `preserved`, `planType`.
  Gültig ist der Eintrag mit `startDate` null/≤ heute und `endDate` null/≥ heute; der Preis wird über die Beziehung zum Preispunkt
  im `included` zugeordnet, nicht „erster customerPrice“.
- Anlegen von Käufen per API gäbe es (`POST /v2/inAppPurchases`, `/v1/subscriptionGroups`, `/v1/subscriptions`, `/v1/subscriptionPrices`,
  `/v1/inAppPurchasePriceSchedules`, Lokalisierungen, Asset-Upload für Review-Screenshots); `asc_lib` erlaubt keinen davon.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_check.py` | MODIFY | IAP-Lokalisierung/Review-Screenshot auf v2; Preisplan-Schritt; manual + automatic; gültigen Preis über Preispunkt-Beziehung wählen; Abo-Preise mit derselben Gültigkeitsregel; Zaun um zwei Muster ergänzt |
| `scripts/test_asc_check.py` | MODIFY | `FakeASC`-Routen auf neue Pfade; Fälle: manual leer/automatic gefüllt, abgelaufenes `endDate`, mehrere Einträge, kein gültiger Preis = Abweichung; ID-Herkunft weiter geprüft |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | Leseliste auf 4.5.1, Durchgang B3a, Ablauf B3 |
| `docs/artifacts/feat-175-app-store-auftritt/` | CREATE (B3-Lauf) | `asc-readback.txt`, Screenshots de/en, Browser-Belege |

### Scope Assessment
- B3a (Code): 2 Dateien + Spec, ~+70/−20 Zeilen, innerhalb der Grenzen
- B3 (Lauf): ~0 Zeilen Quellcode, nur Belege; außenwirksam
- Risk Level: LOW für B3a (nur Lesen, ohne Netz getestet), HIGH für B3-Lauf (unumkehrbare Produktkennungen, Basisland des Preisplans)

### Technical Approach (Empfehlung)
1. **Dieser Workflow = B3a:** Pfadkorrektur in `asc_check.py` samt Tests, ohne Außenwirkung. Code mit Test-Gate gehört nicht in denselben
   Durchgang wie das Schreiben in ASC.
2. Danach **B3 als Betriebsdurchgang**, jeder außenwirksame Schritt einzeln auf Hennings Wort: Lesetrockenlauf `asc_check --all` (nur GET) →
   `asc_publish` Trockenlauf → `--apply` → Browser (Käufe mit kopierter Kennung aus `PremiumService.swift:124-126`, Basisland DEU,
   Abo-Gruppe, Kategorien, Altersfreigabe, Content Rights, Preise/Verfügbarkeit, Review-Kontakt, App Privacy, Screenshot-Upload) →
   Screenshots 1320×2868 aus dem Simulator mit Vorschau → Build 37 per `testflight.yml` → Zuordnung → Schlusslauf → `asc-readback.txt`.

### Alternativen
- **Käufe per API** (Schreibzaun erweitern, ~150–250 Zeilen, eigener Durchgang): wiederholbar, kippt aber AC-10a/AC-20f (Schreibzaun nur Texte);
  bei einmaligem, unumkehrbarem Anlegen kein Vorteil. Nicht empfohlen.
- **Alles im Browser, kein Skript-Gegenlesen:** Nachweis nur Screenshots, nicht wiederholbar; kippt Entscheidung 14 der Spec. Verworfen.
- **Version 1.0 ohne Käufe einreichen:** Produktentscheid, kippt AC-15/AC-19 und Release-1.0-Umfang; nur Rückfall, falls der Kauf-Teil hängt.

### Dependencies / Blocker (betreffen B3, nicht B3a)
- Datenschutzseite `emmrich-business.com/datenschutz` mit altem Text, nicht im Repo → AC-12, damit AC-19 offen (PO-Frage: wer pflegt sie).
- Build 37 nicht hochgeladen → AC-17 offen (Upload nur auf Wort).
- Paywall ohne Rechtslinks (#215) → Ablehnungsrisiko vor dem Einreichen, nicht Teil von B3.

### Open Questions
- [ ] Wer stellt den Text aus `docs/appstore/datenschutz.md` auf `emmrich-business.com/datenschutz`? (PO)
