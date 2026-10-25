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
