# Context: feat-175-b2a-asc-skripte

## Request Summary
Durchgang B2a von #175 (PO-Schnitt 2026-10-24): Python-Skripte, die die Store-Texte aus `docs/appstore/{de,en}.md`
per App Store Connect API in den Entwurf von Version 1.0 schreiben, plus Sicherheits-Strukturtest (AC-10).
B2b (`asc_check.py`, `test_asc_texts.py`) folgt getrennt; B3 (echte Eintragungen) danach.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/specs/appstore/app-store-auftritt.md` | Gesamt-Spec #175; Abschnitt „Durchgang B2“ (Z. 138–149), AC-10 (Z. 434–437), Test Plan AC-10 (Z. 489) |
| `docs/appstore/de.md`, `docs/appstore/en.md` | Eingabe: Abschnitte `## name`, `## subtitle`, `## keywords`, `## promotional_text`, `## description`, `## support_url`, `## privacy_url` |
| `docs/artifacts/feat-175-b1-store-texte/check_b1.py` | B1-Parser `sections()` (re.split auf `^## `) — Vorlage für den Parser in `asc_lib` |
| `scripts/test_testflight_workflow.py`, `scripts/test_*.py` | Muster der Strukturtests: `unittest`, `R = Path(__file__).resolve().parent.parent`, knapper Stil |
| `project.yml` | Bundle-ID der App `com.johannesemmrich.Restock` (Nachschlagen der App-ID) |
| `/Users/hem/Developer/AuthKey_K928C9Z9P2.p8` | ASC-Schlüssel (Admin-Rolle), außerhalb des Repos; Inhalt nie lesen/ausgeben; Key-ID `K928C9Z9P2`, Issuer `6c350cda-a185-45ac-a852-70e84119b6f1` (keine Geheimnisse, Memory) |
| `.github/workflows/testflight.yml` | Nutzt dieselben Secrets `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_P8`; B2a läuft nur lokal |

## Recherche (2026-10-24)
- Token: JWT, Header `alg=ES256`, `kid`, `typ=JWT`; Payload `iss` (Issuer), `iat`, `exp` ≤ iat+1200 s (sonst 401), `aud=appstoreconnect-v1`, optional `scope` (Liste „METHODE /pfad“; Token wird für nicht passende Anfragen abgelehnt). Quelle: developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
- ES256-Signatur im JWT ist rohes R||S (64 Byte, RFC 7518 §3.4). Weder PyJWT noch `cryptography` installiert; vorhanden ist `openssl` 3.5.9 (`/opt/homebrew/bin/openssl`). Weg ohne neue Abhängigkeit: `openssl dgst -sha256 -sign <p8>` liefert DER → in Python nach R||S umwandeln. Schlüsselinhalt geht dabei nur als Pfad an openssl.
- Version-Texte: `PATCH /v1/appStoreVersionLocalizations/{id}` (Attribute laut Schema: `description`, `keywords`, `promotionalText`, `supportUrl`, `marketingUrl`, `whatsNew`; `whatsNew` für 1.0 nicht senden). Fehlt eine Sprache: `POST /v1/appStoreVersionLocalizations` mit Relationship `appStoreVersion`; POST auf vorhandene Sprache → 409.
- App-Texte: `PATCH /v1/appInfoLocalizations/{id}` (`name`, `subtitle`, `privacyPolicyUrl`, …), nur im bearbeitbaren Zustand; POST `/v1/appInfoLocalizations` für neue Sprache.
- Navigation: `GET /v1/apps?filter[bundleId]=…` → App-ID; `GET /v1/apps/{id}/appStoreVersions?filter[versionString]=1.0&filter[platform]=IOS`; `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations`; `GET /v1/apps/{id}/appInfos` → `GET /v1/appInfos/{id}/appInfoLocalizations`.
- `appStoreState` ist veraltet, neu `appVersionState` (Version) bzw. `state` (AppInfo) — Quelle: fastlane PR #21895 / Issue #21890; genaue Werte in der Analyse gegen Apples Schema prüfen.
- Einreichung läuft über `reviewSubmissions`/`appStoreVersionSubmissions` — AC-10 verbietet beide im Quelltext.

## Existing Patterns
- Strukturtests als `unittest` unter `scripts/test_*.py`, ohne Netz, statische Quelltextprüfung (z. B. Secrets nur als `secrets.X`, kein Inhalt).
- Geheimnisse nur als Pfad/Argument weiterreichen, nie lesen (Memory „Lokaler Upload mit API-Schlüssel“, `secrets_guard`).
- Keine Drittbibliotheken (Projektregel); stdlib `urllib.request`, `json`, `subprocess`.

## Dependencies
- Upstream: ASC-API, `openssl`, Repo-Textdateien aus B1.
- Downstream: B2b `asc_check.py` (nutzt `asc_lib` für GET und Parser), B3 (echter Lauf mit Hennings Wort).

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` — B2-Abschnitt muss für B2a/B2b aufgeteilt werden (Dateiliste, Schätzung, AC-Zuordnung).

## Risks & Considerations
- Außenwirkung: Schreiben verändert nur den Entwurf (`PREPARE_FOR_SUBMISSION`); trotzdem echter Lauf erst in B3 auf Hennings Wort; B2a-Tests laufen nur mit Schein-Antworten (kein Netz).
- Schlüssel-Leck: Token/Schlüssel nie in Ausgabe oder Protokoll; `secrets_guard` kann Pfade auf `.p8` blockieren → Pfad nur aus Umgebungsvariable.
- Falsche App treffen: App-ID muss fest an die Bundle-ID gebunden sein; jeder Pfad wird gegen eine Erlaubnisliste geprüft (nur Ressourcen unter der eigenen App bzw. IDs, die aus deren Antworten stammen).
- 20-min-Token-Grenze; Rate-Limits (Antwortkopf `X-Rate-Limit`) bei wenigen Aufrufen unkritisch.
- Ob Apple Name/Untertitel-Änderung im aktuellen AppInfo-Zustand erlaubt, zeigt erst B3.
- Alternative zum Eigenbau: fastlane `deliver` (neue Abhängigkeit, Ruby; widerspricht „keine neuen Dependencies“) oder Eintragen per Hand im Browser (kein Gegenlese-Automat) — in der Analyse abwägen.
- Umfang: ~220 Zeilen in 3 Dateien; `asc_lib` muss den Parser so schneiden, dass B2b ihn wiederverwendet.

## Analysis

### Type
Feature (Werkzeug außerhalb der App; keine sichtbare Oberfläche, daher kein Entwurfsbild nach Regel 2026-09-22)

### Recherche-Ergebnisse dieser Phase (2026-10-24)
- Zustandswerte aus Apples OpenAPI-Dokument (Abschrift api-evangelist/ios, `ios-appinfos-api-openapi.yml`):
  `AppInfo.state` ∈ {ACCEPTED, DEVELOPER_REJECTED, IN_REVIEW, PENDING_RELEASE, PREPARE_FOR_SUBMISSION, READY_FOR_DISTRIBUTION,
  READY_FOR_REVIEW}; `appStoreState` (veraltet) nutzt `AppStoreVersionState`. Version: `appVersionState` mit u. a.
  PREPARE_FOR_SUBMISSION, READY_FOR_REVIEW, WAITING_FOR_REVIEW, IN_REVIEW (fastlane PR #21895, apis.io-Spiegel).
  Bearbeitbar laut Apple („open for editing“): PREPARE_FOR_SUBMISSION (auch DEVELOPER_REJECTED). B2a erlaubt **nur**
  PREPARE_FOR_SUBMISSION (Erlaubnisliste, AC-18); jeder andere oder unbekannte Wert → Abbruch ohne Schreiben.
- Es kann mehrere `appInfos` geben (live + Entwurf) → den mit `state == PREPARE_FOR_SUBMISSION` wählen, genau einer, sonst Abbruch.
- `PATCH /v1/appInfos/{id}` ändert nur Kategorien; Name/Untertitel/Datenschutz-URL gehen über `appInfoLocalizations`
  (Apple-Doku „App Info Localizations“). Bekannter Fehler: 404 auf Lokalisierungs-ID aus falschem appInfo (Apple-Forum 747116).
- ES256 ohne neue Abhängigkeit **belegt**: Wegwerf-P-256-Schlüssel, `openssl dgst -sha256 -sign` → DER → R||S (64 Byte) →
  zurück nach DER → `openssl dgst -verify`: 200/200 „Verified OK“ (Skript im Scratchpad, Schlüssel danach gelöscht; Hennings
  Schlüssel nicht berührt).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_lib.py` | CREATE | `parse_texts(path)` (Parser aus check_b1, B2b nutzt ihn), `make_token(env, sign=…)` (Pfad aus `ASC_KEY_PATH`, openssl als Liste, DER→R‖S), `api(method, path, body, send=…)` (nur Host api.appstoreconnect.apple.com, nur GET/POST/PATCH, Pfad-Erlaubnisliste, Fehler nur Status+Pfad) |
| `scripts/asc_publish.py` | CREATE | App über `filter[bundleId]=com.johannesemmrich.Restock` (genau 1), Version 1.0 IOS (genau 1, `PREPARE_FOR_SUBMISSION`), bearbeitbares appInfo; Feldzuordnung Datei→API; erst alle GETs und Prüfungen, dann Schreiben; PATCH nur bei Abweichung, POST nur bei fehlender Sprache; **Trockenlauf Standard**, Schreiben nur mit `--apply` |
| `scripts/test_asc_scripts.py` | CREATE | AC-10: statisch (kein fremder Host, kein DELETE, kein `reviewSubmissions`/`appStoreVersionSubmissions`, kein `shell=True`, kein Lesen des Schlüssels, kein Ausgeben des Tokens); dynamisch mit Schein-`send` (Pfade nur unter eigener App-ID bzw. aus deren Antworten, Trockenlauf schreibt nichts, falscher Zustand bricht ohne Schreiben ab, 409-Vermeidung); DER→R‖S mit fester Probe. Nur stdlib, kein PyYAML |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | B2-Abschnitt in B2a/B2b aufteilen (Dateien, Schätzung, AC-Zuordnung) |

### Scope Assessment
- Files: 3 neu + Spec
- Estimated LoC: ~+330 Code (asc_lib ~100, asc_publish ~120, Test ~110) — **über ±250**; Kontext-Schätzung (~220) war zu knapp
- Risk Level: MEDIUM — kein App-Code, aber das Skript kann außen schreiben (nur Entwurf, Trockenlauf Standard, echter Lauf erst B3 auf Hennings Wort)

### Technical Approach (Empfehlung)
B2a in einem Durchgang wie oben, Netz und Token injizierbar (`send`, `sign`), damit die Tests ohne Netz und ohne Schlüssel laufen.
Umfang ~330 offen vorlegen. Teil-Schreiben (de ok, en scheitert) wird durch „erst alles lesen und prüfen, dann schreiben“,
Idempotenz und das Gegenlesen in B2b abgefangen.

### Alternativen
- **Nur Gegenlesen automatisieren:** Texte in B3 per Hand im Browser eintragen, nur `asc_check` (GET) bauen. Kleinster und
  sicherster Weg (keine Schreibrechte im Skript), spart ~150 Zeilen; verliert die Wiederholbarkeit für 1.1/weitere Sprachen,
  Tippfehler fängt erst das Gegenlesen. Kippt die Spec-Entscheidung „Skript schreibt“ (B2-Abschnitt).
- **fastlane `deliver`:** neue Ruby-Abhängigkeit (Projektregel), Einreichen per Schalter möglich → AC-10/AC-18 schwerer zu garantieren. Verworfen.
- **Weiter teilen** (B2a-1 `asc_lib`+Test, B2a-2 `asc_publish`): hält die Limits, aber B2a-1 hat allein keinen Nutzen.

### Dependencies
- Upstream: B1-Texte (`docs/appstore/*.md`), `openssl` (System), ASC-API v1.
- Downstream: B2b importiert `parse_texts` und `api`; B3 fährt `asc_publish.py` (erst Trockenlauf, dann `--apply`) auf Hennings Wort.

### Open Questions
- [x] PO 2026-10-24: Umfang ~330 Zeilen in einem Durchgang angenommen (Skript schreibt, Trockenlauf Standard); Alternative „nur Gegenlesen“ verworfen.
- [ ] B3: ob Name/Untertitel im aktuellen appInfo-Zustand änderbar sind, zeigt erst der echte Trockenlauf.
