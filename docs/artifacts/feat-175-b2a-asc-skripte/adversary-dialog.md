# Adversary-Dialog B2a (#175, feat-175-b2a-asc-skripte)
Testlauf: python3 scripts/test_asc_scripts.py -v -> Ran 15 tests, OK (0 Fehler, 0 uebersprungen; Stand nach Runde 3); Ausgabe in scratchpad/adversary_test_output.txt
## Checkliste
- [x] AC-10: Gesamt erfuellt; Weiterleitungs-Luecke F001 behoben (NoRedirect, leerer ProxyHandler, 3xx = Fehler, Runde 3 belegt); alle Unterpunkte getestet und eigene Proben bestanden
- [x] AC-10a: check_path (asc_lib.py:68-77) lehnt Methode, //, Fremdhost, /v2, reviewSubmissions, ../, %2e%2e, Kleinschreibung vor send ab; Probe und test_api_rejects_before_send
- [x] AC-10b: IDs aus Antworten mit ../, ? oder / werden von der ID-Regex (asc_lib.py:8) abgelehnt, 0 Schreibaufrufe (Probe); aber Bundle-ID-Filter ist seit Runde 3 exakt festgelegt (F002 behoben); eine fremde App-ID im Pfad bleibt in api moeglich, asc_publish leitet sie nur aus der Antwort ab (Rest-LOW unter F004)
- [x] AC-10c: Ohne --apply kein POST/PATCH (asc_publish.py:90-92), Plan wird ausgegeben, Exit 0; test_dry_run_never_writes
- [x] AC-10d: check_state (asc_publish.py:23-33) bricht bei 0/>1 App, Version, appInfo und fremdem/unbekanntem Zustand ab, vor build_plan; test_state_checks_abort_before_writing
- [x] AC-10e: plan_for (asc_publish.py:36-52) PATCH nur Diff-Felder, POST nur fuer fehlende Sprache mit Relationship, kein whatsNew; test_patch_existing_post_missing
- [x] AC-10f: Leerer Diff erzeugt keinen Aufruf; zweiter Lauf 0 Schreibaufrufe; test_idempotent
- [x] AC-10g: Fehlermeldungen nur Status+Pfad ohne Query (asc_lib.py:89), openssl-Fehler ohne Befehlszeile (asc_lib.py:44-45), fehlende Variablen nennen nur Namen; Probe mit nicht existentem Schluesselpfad zeigt keinen Pfad; JWT/DER-Test ok
- [x] AC-10h: test_source_bans prueft Verbote, URLs, Stdlib, Argumentliste; Quelltext selbst gelesen, keine Verstoesse
### Runde 1
Tests selbst ausgefuehrt (12 OK). Quelltext beider Skripte gelesen. Testluecken: kein Test fuer Weiterleitungen (urllib_send, asc_lib.py:59-65 nie ausgefuehrt, da send immer ersetzt), kein Test fuer Query-Inhalte (check_path erlaubt beliebige Query, asc_lib.py:73-75), kein Test fuer feindliche IDs in Antworten, kein Test fuer Abbruch mitten in --apply, kein Test mit leerem Quelltextfeld. Der Bann-Test prueft nur Gross/Kleinschreibung exakt (DELETE), da die Methodenliste ALLOWED aber Whitelist ist, unkritisch.
Code reference: scripts/asc_lib.py:59
Code reference: scripts/asc_publish.py:77
Code reference: scripts/test_asc_scripts.py:105
### Runde 2
Eigene Proben mit Schein-send/-sign (scratchpad/probe1.py-Inhalt inline ausgefuehrt): Pfadtricks /v1/apps/../reviewSubmissions, %2e%2e, Zeilenumbruch im Pfad, get klein, #-Fragment alle abgelehnt. Erlaubt (nur Query): /v1/apps?filter[bundleId]=evil.other.app, /v1/apps?filter[bundleId]=x&include=builds, /v1/apps/OTHERAPP/appInfos?x=//evil, PATCH .../abc?x=1, POST ...?x=1, CR/LF in der Query (check_path laesst durch; Python http.client lehnt es danach mit InvalidURL ab, also nur Defense-in-depth-Luecke). Redirect: urllib.request.HTTPRedirectHandler.redirect_request behaelt Authorization bei Weiterleitung auf https://evil.example/x (belegt). Feindliche IDs aus Antworten (../x, a?b=c, A/../B, A?x): Exit 1, 0 Schreibaufrufe, Meldung ohne Geheimnisse. Fehlende Umgebungsvariablen: Exit 1, nur Namen. Normalfall: Exit 0, 4 Schreibaufrufe, Token nicht in Ausgabe. Mitten im --apply: erster Fehler bricht ab (asc_publish.py:93-95), bereits gedruckte ok-Zeilen zeigen den Stand; Rest per Idempotenz.
Code reference: scripts/asc_lib.py:68
Code reference: scripts/asc_lib.py:80
Code reference: scripts/asc_publish.py:93
Code reference: scripts/test_asc_scripts.py:226
### Runde 3
Nachpruefung der Behebungen. Testlauf: 15 Tests OK. F001: lokaler HTTP-Server mit 301, 302, 303, 307 und 308 sowie gesetztem HTTP_PROXY (auf toten Port): urllib_send liefert jeweils nur den Status der Weiterleitung, der Server sieht genau eine Anfrage (/a), das Ziel /b wird nie angefragt, Proxy-Umgebung wird ignoriert (ProxyHandler({})); api wirft bei jedem Status ausser 2xx. F002/F003: check_path laesst nur noch exakt filter[bundleId]=com.johannesemmrich.Restock an /v1/apps und exakt VERSION_QUERY an /v1/apps/{id}/appStoreVersions zu; abgelehnt: zusaetzliche Parameter, Grossschreibung, prozentkodierte Klammern, %0d%0a, echter Zeilenumbruch, leere Query, Query an appInfos, POST/PATCH mit ? . Rest: /v1/apps/{beliebige-ID}/... bleibt in api erlaubt (nur Ablaufebene bindet an die eigene App), LOW.
Code reference: scripts/asc_lib.py:61
Code reference: scripts/asc_lib.py:81
Code reference: scripts/asc_publish.py:25
Code reference: scripts/test_asc_scripts.py:105
## Findings
- {status: BEHOBEN (Runde 3), id: F001, severity: MEDIUM, category: security, description: urllib_send nutzt urlopen mit Standard-Redirect-Handler; bei einer 3xx-Antwort wird der Authorization-Header (Bearer-Token) an den Ziel-Host weitergereicht und der Host-Zwang von AC-10a umgangen, check_path prueft nur den Anfangspfad, evidence: scripts/asc_lib.py:62 und Probe redirect_request(... https://evil.example/x) behaelt Authorization, remediation: eigenen Opener mit HTTPRedirectHandler-Unterklasse die redirect_request None zurueckgibt (3xx als Fehler melden) und ProxyHandler leer; Test mit Schein-Opener ergaenzen}
- {status: BEHOBEN fuer den Filter (Runde 3), id: F002, severity: LOW, category: spec_violation, description: api erzwingt weder die eigene Bundle-ID im Filter noch die eigene App-ID; /v1/apps?filter[bundleId]=beliebig und /v1/apps/BELIEBIG/appInfos sind erlaubt (AC-10b gilt nur auf Ablaufebene durch asc_publish), evidence: scripts/asc_lib.py:74-75, remediation: Filter auf com.johannesemmrich.Restock festnageln oder Query gegen feste Muster pruefen}
- {status: BEHOBEN (Runde 3), id: F003, severity: LOW, category: edge_case, description: Query-Teil wird ausser bei /v1/apps nicht geprueft (beliebige Parameter, auch CR/LF); Python lehnt CR/LF spaeter ab, evidence: scripts/asc_lib.py:73-75, remediation: Query gegen [A-Za-z0-9=&%.\[\]_-] pruefen oder ganz verbieten}
- {status: OFFEN (nur Restluecken), id: F004, severity: LOW, category: anti_pattern, description: Testluecken: urllib_send/Redirect, Query-Inhalte und feindliche Antwort-IDs sind ungetestet, evidence: scripts/test_asc_scripts.py:105-124, remediation: Tests fuer F001-F003 ergaenzen}
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:f5ea7c0772c3322629857d7932f9c1b249d6acd0dc639db82fb53fdb7ac40be9  scripts/asc_lib.py
- sha256:53bd9c265772ee69ccbbc3a863df29e0e72bb39d480480c570e1d06900e00718  scripts/asc_publish.py
- sha256:95b07761c75e594683165663d6a2fe1ff288c56810c9515d9236c1d0f16570ac  scripts/test_asc_scripts.py

## Prüfbasis

- base: 5f70de11c454159d7d0a3ede17e2e753f952aa00
- blob:fde58bf0f1c62d92d5daa1e29f5db6830ecde1e9  scripts/asc_lib.py
- blob:e89a4ee49b4cac8ea98568a32ef7df0731373bf4  scripts/asc_publish.py
- blob:197985d8861a2dd26c9389ef34ab67894c102f0e  scripts/test_asc_scripts.py
