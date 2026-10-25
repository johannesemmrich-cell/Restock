# Context: feat-175-b2b-asc-check

## Request Summary
Durchgang B2b von #175: Ein Gegenlese-Skript `scripts/asc_check.py` liest App Store Connect nur (GET) und vergleicht mit den
Repo-Dateien (AC-11 bis AC-19, gefahren erst in B3 auf Hennings Wort). Dazu kommt der dauerhafte Texttest `scripts/test_asc_texts.py`
(AC-9 bis AC-9d, bisher nur Einzeiler in B1) plus Merkpunkt F001 aus der B1-Prüfung (Vergleich mit dem Spec-Wortlaut,
unsichtbare Zeichen, CR, BOM).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/specs/appstore/app-store-auftritt.md` | Spec; B2b-Abschnitt Z. 176–186, AC-9…AC-9d Z. 462–480, AC-11…AC-19 Z. 513–556, Test Plan Z. 571–575 |
| `scripts/asc_lib.py` (105 Z.) | `parse_texts`, `make_token`, `api` mit fester Erlaubnisliste `ALLOWED` (nur die Pfade von B2a), `urllib_send` ohne Proxy und ohne Weiterleitung |
| `scripts/asc_publish.py` (104 Z.) | Muster: `main(argv, env, send, sign, out)` mit injizierbarem `send`/`sign`, `check_state` (genau eine App/Version/appInfo), Fehler nur Status+Pfad |
| `scripts/test_asc_scripts.py` | AC-10-Test; Z. 110 verlangt ausdrücklich, dass `GET /v1/apps/{id}/builds` von `api` abgelehnt wird; Schein-Router `routes` (Z. 66) als Vorbild für Schein-Antworten |
| `docs/artifacts/feat-175-b1-store-texte/check_b1.py` (88 Z.) | B1-Prüfer: Abschnitte, Längen, Verbotsliste, URLs, Vergleich `datenschutz.md` ↔ `LegalView.privacyPolicy` (Regex auf `privacyPolicy = """…"""`) — Vorlage für `test_asc_texts.py` |
| `docs/appstore/de.md`, `en.md`, `datenschutz.md` | Prüfgegenstand des Texttests und Sollwerte des Gegenlesers |
| `SmartCart/Views/Settings/LegalView.swift` | Quelle `privacyPolicy` für AC-9d |
| `.github/workflows/ci.yml` | ob/wie Python-Strukturtests in CI laufen (zu klären in der Analyse) |

## Existing Patterns
- ASC-Skripte: nur Standardbibliothek, injizierbares `send`/`sign`, Fehlermeldungen nur Status + Pfad, Schlüssel nur als openssl-Argument.
- Python-Strukturtests unter `scripts/test_*.py` mit `unittest`, ohne Netz.
- Statische Quelltextverbote (AC-10h) im Test selbst.

## Dependencies
- Upstream: `asc_lib.parse_texts`, `make_token`, `urllib_send`; laut Spec soll B2b `asc_lib` nicht ändern.
- Downstream: B3 fährt `asc_check.py --all` und legt `asc-readback.txt` ab (AC-19 = Definition of Done des Tickets).

## Recherche (Apple-Doku, 2026-10-25)
- App-Privacy-Fragebogen: keine öffentliche API (fastlane nutzt inoffizielle Schnittstelle mit Apple-ID statt API-Schlüssel) →
  AC-14 bleibt Browser-Beleg, `asc_check` kann ihn nicht lesen. Quelle: https://docs.fastlane.tools/uploading-app-privacy-details/
- Altersfreigabe: `GET /v1/appStoreVersions/{id}/ageRatingDeclaration` in API 4.4 entfernt; jetzt
  `GET /v1/appInfos/{id}/ageRatingDeclaration`. Quelle: https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-4-release-notes
- In-App-Käufe/Abos seit API 4.4.1 versionsbasiert: Lokalisierungen über `GET /v1/inAppPurchaseVersions/{id}/localizations`,
  `GET /v1/subscriptionVersions/{id}/localizations`, `GET /v1/subscriptionGroupVersions/{id}/localizations`; die alten
  verschachtelten Lese-Endpunkte sind veraltet. Review-Screenshots weiter am Produkt (`inAppPurchaseAppStoreReviewScreenshots`,
  `subscriptionAppStoreReviewScreenshots`). Zustände der Versionen: `PREPARE_FOR_SUBMISSION` → `READY_FOR_REVIEW` → …
  Quellen: https://developer.apple.com/documentation/appstoreconnectapi/migrating-in-app-purchase-metadata-to-v2 ,
  https://developer.apple.com/documentation/appstoreconnectapi/working-with-subscription-group-versions
- Abo-Gruppen: `GET /v1/apps/{id}/subscriptionGroups`. Quelle: https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-subscriptiongroups
- Screenshots: Sets je `appStoreVersionLocalization` (`appScreenshotSets`), Typ für 6,9" in der Doku nicht aufgeführt (Forum: größter
  iPhone-Wert weiter `APP_IPHONE_67`) → Prüfung besser über Bildmaße als über den Enum-Namen.
  Quelle: https://developer.apple.com/forums/thread/763908
- API 4.5 ändert nichts an den hier gelesenen Ressourcen. Quelle: https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-5-release-notes

## Risks & Considerations
- **Erlaubnisliste:** Fast alle Lesepfade von `asc_check` (builds, ageRatingDeclaration, subscriptionGroups, inAppPurchasesV2,
  appScreenshotSets, appStoreReviewDetail, appPriceSchedule, appAvailabilityV2) blockiert `asc_lib.api` heute; der B2a-Test verlangt
  das sogar (Z. 110). „Ohne `asc_lib` zu ändern“ geht nur mit eigenem, reinem GET-Zaun in `asc_check`. Entscheidung in der Analyse.
- **AC-12** braucht einen Abruf von `emmrich-business.com` (fremder Host, ohne Token) — darf nie über `api` laufen, eigener Weg
  ohne Authorization-Header. AC-12 ist laut Spec blockiert, solange die Seite falsch ist.
- **AC-14** (App Privacy) per API nicht lesbar → Abschnitt meldet „manuell belegen“ statt „ok“; AC-19 „alle ok“ muss das berücksichtigen.
- **v1/v2-Wandel der Kauf-Endpunkte** ist neu (4.4.1) und am echten Konto unbelegt; Schein-Antworten sind die einzige Prüfung vor B3.
- Umfang: Schätzung ~190 Zeilen; mit eigenem Zaun, sieben Abschnitten und Schein-Antwort-Tests vermutlich darüber → vor Beginn vorlegen.
- Quelltextverbote (AC-10h) sollten auch für `asc_check.py` gelten (keine Schreibmethoden, keine Einreichungs-Endpunkte).

## Analysis

### Type
Feature (Werkzeug: Gegenlese-Skript und dauerhafter Texttest; keine App-Änderung)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_check.py` | CREATE | Nur-Lese-Gegenleser mit eigenem GET-Zaun; Abschnitte `metadata`, `privacy-url`, `appinfo`, `iap`, `screenshots`, `build`, `status`, `--all` (AC-11…AC-19) |
| `scripts/test_asc_check.py` | CREATE | Schein-Antworten (Muster `FakeASC` aus `test_asc_scripts.py`): je Abschnitt ok/Abweichung, Zaun (nur GET, nur Host, nur Lesepfade, kein Token an Fremdhost), Quelltextverbote wie AC-10h. **In der Spec bisher nicht aufgeführt**, für TDD aber nötig |
| `scripts/test_asc_texts.py` | CREATE | AC-9…AC-9d dauerhaft, dazu F001 (unsichtbare Zeichen, CR, BOM, Vergleich mit Spec-Tabelle) |
| `.github/workflows/ci.yml` | MODIFY | `test_asc_texts.py`, `test_asc_scripts.py`, `test_asc_check.py` in den Schritt „Strukturtests (Python)“ (ohne Netz, ohne Schlüssel) — bisher läuft keiner der ASC-Tests in CI |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | B2b-Abschnitt: dritte Datei, eigener Zaun, AC-14 „manuell“, Endpunkte API 4.4/4.4.1 |

### Scope Assessment
- Files: 3 neu + 2 geändert (ci.yml +3 Zeilen, Spec nur Doku)
- Estimated LoC: asc_check ~240, test_asc_check ~150, test_asc_texts ~70, ci.yml +3 → **~+460** (Spec-Schätzung war 190; Test für asc_check fehlte dort, sieben Abschnitte sind mehr als 130 Zeilen)
- Risk Level: LOW für das Produkt (keine App-Datei, nur GET); MEDIUM für die Aussagekraft, weil die v2-Kauf-Endpunkte (API 4.4.1) erst in B3 am echten Konto belegt werden

### Technical Approach (Empfehlung)
- **Eigener GET-Zaun in `asc_check`** (`read(path)`): fester Host, nur GET, Pfade gegen eine eigene Leseliste, nutzt `make_token` und `urllib_send` aus `asc_lib` (ohne Proxy, ohne Weiterleitung). `asc_lib` bleibt unverändert, der B2a-Test (builds bleibt dort verboten) bleibt gültig. Schreibmethoden kennt `asc_check` gar nicht.
- **Alternative 1:** Leseliste in `asc_lib.ALLOWED` erweitern — kippt den Spec-Satz „ohne asc_lib zu ändern“ und den B2a-Test Z. 110; ein Zaun für Schreib- und Leseskript zugleich wäre größer als nötig. Verworfen.
- **Alternative 2:** Kein Skript, B3 nur per Browser mit Beleg-Screenshots — spart ~390 Zeilen, aber AC-19 („ein Lauf, alle ok“) wäre nie wiederholbar und jede Nachkorrektur kostet einen neuen Browser-Durchgang. Kippt AC-11…AC-19 als Skript-Nachweis.
- **Datenschutzseite (AC-12):** eigener Abruf ohne Authorization-Header über einen eigenen Opener ohne Weiterleitung, nur `https://emmrich-business.com/datenschutz`; nie über den ASC-Zaun.
- **AC-14 (App Privacy):** keine öffentliche API → Abschnitt meldet „manuell belegen“; `--all` endet mit Exit 0 nur, wenn alle API-Abschnitte ok sind, und nennt AC-14 ausdrücklich als offen.
- **Endpunkte nach API 4.4/4.4.1:** Altersfreigabe über `appInfos/{id}/ageRatingDeclaration`; Käufe über `apps/{id}/inAppPurchasesV2`, `apps/{id}/subscriptionGroups`, Lokalisierungen über die Versionsressourcen; Screenshots über `appScreenshotSets` je Lokalisierung, geprüft über Bildmaße 1320×2868, nicht über den Enum-Namen.
- **Texttest:** übernimmt die Logik aus `check_b1.py`, plus F001; liest nur Repo-Dateien.

### Dependencies
- Upstream: `asc_lib.parse_texts`, `make_token`, `urllib_send`, `BUNDLE` (unverändert).
- Downstream: B3 fährt `asc_check.py --all` gegen ASC (nur auf Hennings Wort) und legt `asc-readback.txt` ab.

### Open Questions
- [x] Umfang ~460 statt ±250: PO 2026-10-25 „Ein Durchgang“ freigegeben (5 Dateien, davon 3 neu)
