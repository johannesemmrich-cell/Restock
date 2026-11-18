# Spec: Offer Codes in App Store Connect anlegen (Issue #273)

Folge aus #259 (Einlösen in der App, gemergt). Wort des PO am 2026-11-17: „Ja, Codes anlegen“ (Gratis-Codes für Presse und Tester); zugesagt ist, dass er den Plan sieht, bevor bei Apple etwas angelegt wird.

## Problem
Die App öffnet über „Code einlösen“ Apples Einlösefenster. In App Store Connect gibt es aber weder ein Angebot noch Codes, jede Eingabe endet mit „ungültiger Code“. Der ASC-Schlüssel liegt nur als Repo-Secret vor (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`), nicht in Cloud-Sitzungen. Das Repo ist öffentlich: Codes dürfen nie in Log, Repo oder Klartext-Artefakt landen.

## Fakten (Quellen)
- API 4.6 (`openapi.oas.json`, Dateidatum 2026-11-04): `POST /v1/inAppPurchaseOfferCodes` (Name, `customerEligibilities` aus `NON_SPENDER`/`ACTIVE_SPENDER`/`CHURNED_SPENDER`, Beziehung `inAppPurchase`, Preise als `included` `inAppPurchaseOfferPrices` mit `territory` und optionalem `pricePoint`), `POST /v1/inAppPurchaseOfferCodeOneTimeUseCodes` (`numberOfCodes`, `expirationDate`, `environment`), `GET /v1/inAppPurchaseOfferCodeOneTimeUseCodes/{id}/values` (CSV), `PATCH /v1/inAppPurchaseOfferCodes/{id}` (nur `active`).
- App-Store-Connect-Hilfe „Create offer codes for in-app purchases“ (gelesen 2026-11-17): Angebot „Paid Offer“ oder „Free Offer“; Einmalcodes je Ausgabe 500 bis 25.000; gültig höchstens sechs Monate; ein Code je Kunde und Angebot; höchstens 10 aktive Angebote; Angebote sind nach dem Anlegen nicht änderbar. Codes erzeugen nur, wenn die App „Ready for Distribution“ ist und der Kauf „Approved“; einlösbar bis zu eine Stunde nach dem Erzeugen.

## Lösung
Skript `scripts/asc_offer_codes.py plan|create <ordner>` mit eigenem Zaun (GET/POST/PATCH nur auf die nötigen Pfade, Abfragen exakt, IDs nur aus früheren Antworten; `asc_lib.ALLOWED` unverändert). Feste Werte im Skript:
- Produkt `com.johannesemmrich.smartcart.premium.lifetime` (dauerhaft Pro, kein Abo, das danach kostenpflichtig weiterläuft).
- Angebot „Restock Pro gratis Presse und Tester 2026-11“, alle drei Kundengruppen.
- Gratis in allen Ländern, in denen der Einmalkauf verfügbar ist: je Land ein Preis ohne `pricePoint`. Nach dem Anlegen liest das Skript die Preise zurück; ist auch nur ein Land nicht gratis, wird das Angebot sofort deaktiviert und es entstehen keine Codes.
- 500 Einmalcodes (Apples Mindestmenge), Umgebung PRODUCTION, gültig bis 2027-05-15.

`plan` liest nur und schreibt Plan, Ist-Stand und fehlende Vorbedingungen ins Log. `create` bricht vor jedem Schreiben ab, wenn eine Vorbedingung fehlt (veröffentlichte Version, Kauf `APPROVED`, mindestens ein Land, Ablaufdatum in höchstens 181 Tagen, Angebot nicht doppelt). Es legt nur an, was fehlt; ein erneuter Lauf verwendet Angebot und Ausgabe weiter. Schreibaufrufe werden nie blind wiederholt, Lesezugriffe bei 5xx/429/Netzfehler bis zu fünfmal. Die Codes holt es mit Wartezeit (bis 20 × 30 s) und legt sie nur als `codes.csv` (0600, Ordner 0700) ab; das Log nennt nur die Zeilenzahl.

Ablauf (im selben PR, Grenze von ±250 LoC bewusst überschritten, weil die Sitzung nur einen Zweig hat und der Ablauf ohne das Skript nicht lauffähig ist): manueller Ablauf `.github/workflows/asc-offer-codes.yml` (Eingabe `mode`, Standard `plan`; `create` nur von `main` und nur mit Bestätigungsfeld), Verschlüsselung der CSV mit `gpg` für `.github/crash-recipient.asc` (geheimer Schlüssel nur auf Hennings Mac), Artefakt nur als Chiffrat.

## Acceptance Criteria
- [ ] AC-1: Der Zaun lässt nur die gelisteten Methoden, Pfade und exakten Abfragen zu; DELETE, Abo-Angebote, fremde Abfragen und `//`-Pfade werfen `ValueError`. Test: `test_fence_allows_only_listed_paths_and_exact_queries`.
- [ ] AC-2: Eine ID im Pfad, die aus keiner Antwort stammt, wird abgelehnt. Test: `test_fence_rejects_id_not_from_response`.
- [ ] AC-3: `asc_lib.ALLOWED` bleibt unverändert. Test: `test_asc_lib_allowed_unchanged`.
- [ ] AC-4: `plan` schreibt nichts, nennt Menge, Länderzahl und „Trockenlauf“ und legt keinen Ordner an. Test: `test_plan_only_reads_and_prints_plan`.
- [ ] AC-5: Fehlt eine Vorbedingung (Kauf nicht `APPROVED`, keine veröffentlichte Version, Ablaufdatum zu weit), schreibt `create` nichts und endet mit Exit 1. Test: `test_create_aborts_before_any_write_when_preconditions_fail`.
- [ ] AC-6: `create` legt Angebot (alle Länder ohne Preispunkt, richtige Kundengruppen) und Ausgabe (500, PRODUCTION, Ablaufdatum) an, legt die Codes als `codes.csv` 0600 in einem 0700-Ordner ab und schreibt keinen Code ins Log. Test: `test_create_happy_path_writes_codes_privately`.
- [ ] AC-7: Ein erneuter Lauf mit vorhandenem Angebot und vorhandener Ausgabe schreibt nichts und holt die Codes. Test: `test_rerun_reuses_offer_and_batch`.
- [ ] AC-8: Ist das angelegte Angebot nicht überall gratis, wird es deaktiviert und es entstehen keine Codes. Test: `test_paid_offer_is_deactivated_without_codes`.
- [ ] AC-9: Sind die Codes noch nicht bereit (404 oder leer), wartet das Skript und versucht es erneut; bleiben sie aus, endet es mit Exit 1 und dem Hinweis, den Lauf zu wiederholen. Tests: `test_waits_until_codes_are_ready`, `test_codes_never_ready_fails_cleanly`.
- [ ] AC-10: Ein Fehler beim Schreiben wird nicht wiederholt; die Meldung nennt Status und Apples `code`/`title`, nie `detail`. Lesefehler 5xx werden fünfmal versucht. Tests: `test_post_error_is_not_retried_and_hides_detail`, `test_get_5xx_is_retried`.
- [ ] AC-11: Eine Antwort mit weiteren Seiten bricht ab statt still abzuschneiden. Test: `test_further_pages_are_an_error`.
- [ ] AC-13: Der Ablauf hat nur `workflow_dispatch` mit `mode` (Standard `plan`), `permissions: contents: read`, die drei Secrets nur im `env`-Block und keine `${{ }}`-Ausdrücke im Skripttext. Test: `test_workflow_dispatch_only_plan_default_secrets_in_env`.
- [ ] AC-14: Der erste Schritt bricht `create` ab, wenn nicht von `main` oder ohne `confirm=anlegen`. Test: `test_create_gate_runs_first_and_needs_main_and_confirm`.
- [ ] AC-15: Hochgeladen wird nur `offer-codes.csv.gpg` (7 Tage), verschlüsselt für `.github/crash-recipient.asc`; `umask 077` und ein `trap` löschen Schlüssel und Klartext; kein Befehl gibt `codes.csv` aus. Test: `test_only_encrypted_codes_are_uploaded_and_cleanup_trapped`.
- [ ] AC-16: `docs/testflight-setup.md` hat den Abschnitt „Offer Codes abholen“. Test: `test_docs_explain_fetching_codes`.
- [ ] AC-17 (Nachweis nach dem Zusammenführen): Trockenlauf auf `main` grün, Plan und Ist-Stand an den PO; `create` erst nach seiner Freigabe.
- [ ] AC-12: Der Test steht in der Liste „Strukturtests (Python)“ in `ci.yml`. Test: `test_ci_lists_offer_code_test`.

## Verlauf
- 2026-11-18 Trockenlauf (Lauf 44218004744): alle Vorbedingungen erfüllt, 175 Länder. PO-Freigabe des Plans am selben Tag.
- 2026-11-18 `create` (Lauf 44258432535): Angebot angelegt, Rücklesen „gratis in 175 Ländern“, Ausgabe mit 500 Codes angelegt; Abholen der Codes scheiterte mit HTTP 406 (`NOT_ACCEPTABLE`), weil `/values` nur `Accept: text/csv` annimmt. Behoben, der Schein-ASC antwortet seitdem ebenso mit 406 ohne CSV-Accept.

## Offene Grenzen
- Nur gegen Schein-Antworten getestet. Ob Apple „gratis“ als Preis ohne `pricePoint` annimmt, ist nicht belegt; der Trockenlauf meldet, ob es in DEU einen Preispunkt 0 gibt, und die Rückleseprüfung (AC-8) verhindert Codes für ein nicht kostenloses Angebot. Lehnt Apple ab, entsteht nichts.
- Ob der Einmalkauf derzeit `APPROVED` ist, zeigt erst der Trockenlauf (Stand 2026-10-30: `READY_TO_SUBMIT`; Version 1.0.1 wurde wegen nicht ladbarer Käufe abgelehnt, #265).
- Angebote sind nicht änderbar; Fehler im Angebot heißen deaktivieren und ein neues mit anderem Namen anlegen.
- Echte Einlösung nur auf Hennings Gerät und auf sein Wort.
