# Context: feat-242-testflight-crashes

## Request Summary
Henning (2026-11-04): „Ich habe für Loose Ends einen Mechanismus einbauen lassen, der sich bei Apple die Absturzberichte zieht.
Kannst du das übernehmen?“ Gemeint ist Issue #242 (Restock): TestFlight-Absturzmeldungen per CI abholen, damit Claude sie lesen und
auswerten kann, ohne dass Henning etwas herunterlädt. Vorbild ist Loose Ends #773 (Schnitt 1 PR #775, Schnitt 2 PR #778, am
2026-10-31 mit echtem Lauf belegt: 5 Meldungen abgeholt, daraus #780).

## Das Vorbild (Loose Ends, nur gelesen, nichts dort geändert)
| Datei (loose-ends) | Rolle |
|---|---|
| `scripts/asc_crashes.py` (154 Zeilen) | Liste `GET /v1/apps/{id}/betaFeedbackCrashSubmissions?limit=200`, `links.next` folgen (Schleifenbremse), je Meldung `GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog` (`logText`; 404 = ohne Bericht), schreibt `<id>.json` und `<id>.crash` mit Modus 0600, Log nur Kennzeile (Id, Bundle, Plattform, Datum; `safe_field` gegen Log-Injektion) |
| `scripts/test_asc_crashes.py` (428 Zeilen) | Unterprozess gegen lokalen Nachbau `FakeASC` |
| `.github/workflows/asc-crashes.yml` (50 Zeilen) | nur `workflow_dispatch`; Skript, `tar`, `gpg --recipient-file .github/crash-recipient.asc`; hochgeladen wird nur `crashes.tar.gpg` (7 Tage); `trap` löscht Schlüssel und Klartext; Secrets nur über `env` |
| `.github/crash-recipient.asc` | öffentlicher Schlüssel „Loose Ends Crash Intake“ (ed25519/cv25519, ohne Passphrase) |

Der geheime Teil dieses Schlüssels liegt im GnuPG-Schlüsselbund dieses Macs (`gpg --list-secret-keys` zeigt
`Loose Ends Crash Intake`, Unterschlüssel D5BB4927B5F934DB). Entschlüsseln: `gh run download <id> -n crashes`, `gpg --decrypt`, `tar -x`
in den Scratchpad.

## Restock heute
| Datei | Befund |
|---|---|
| `scripts/asc_lib.py` | Token (ES256 per `openssl`), `api()` mit Zaun `check_path` und Freigabeliste `ALLOWED` (GET/POST/PATCH). GET mit Abfrage ist **nur** für zwei exakte Fälle erlaubt (`/v1/apps?filter[bundleId]=…`, `appStoreVersions` mit `VERSION_QUERY`). Umgebung: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (nicht `ASC_KEY_FILE`). Kein Wiederholen bei 5xx/429. Fehler nennen Status, Pfad, Apples `code`/`title` (#227) |
| `scripts/asc_check.py` | liest nur, mit **eigenem** Lesezaun (`check_read`, `Reader`), `asc_lib` unverändert; Präzedenz für „eigener Zaun statt `ALLOWED` erweitern“ |
| `scripts/asc_publish.py` | benutzt `asc_lib.api` mit Schreibwegen; teilt `ALLOWED` mit allem, was dort ergänzt wird |
| `scripts/test_asc_scripts.py` | Sicherheitstest des Zauns (AC-10…); läuft im CI-Schritt „Strukturtests (Python)“ |
| `.github/workflows/ci.yml` Z. 35–46 | Strukturtests sind eine **feste Liste**; neue Testdatei muss dort eingetragen werden (anders als bei Loose Ends, wo `unittest discover` sie mitnimmt) |
| `.github/workflows/testflight.yml` | Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, **`ASC_KEY_P8`** (Name abweichend von Loose Ends `ASC_PRIVATE_KEY`); Schlüssel liegt als Klartext-.p8 **oder Base64** im Secret (Z. 47–49), muss genauso entpackt werden |
| `docs/testflight-setup.md` | Doku zum TestFlight-Weg; bekommt den Abschnitt zum Abruf |
| Repo | `johannesemmrich-cell/Restock`, **öffentlich**; Lauf-Logs und Artefakte sind für jeden mit GitHub-Konto lesbar. Henning hat keine Admin-Rechte (Memory `repo-gehoert-dem-sohn-keine-admin-rechte`); die drei ASC-Secrets sind schon gesetzt |

## Unterschiede, die beim Übernehmen zählen
1. **Zaun:** Das Vorbild nutzt `asc_wait_build.get_json` (ohne Zaun). Restock hat den strengen Zaun. Zwei Wege: (a) zwei GET-Muster in
   `ALLOWED` plus Abfrage-Regel für `limit` und Apples `cursor` ergänzen (so steht es im Ticket); (b) eigener Lesezaun im Skript wie
   `asc_check`, `asc_lib` unverändert. (a) erweitert die Liste, die auch `asc_publish` (Schreibwege) benutzt; (b) vermeidet das.
2. **Wiederholung:** Restock-`api()` wiederholt nichts; das Vorbild fünf Versuche bei 5xx/429/Netz.
3. **404 beim Bericht:** Vorbild erkennt es am Text der Ausnahme; Restock-`api()` wirft `RuntimeError("HTTP 404 bei GET …")`.
4. **Secret-Name und Schlüsselformat** (`ASC_KEY_P8`, Klartext oder Base64).
5. **Bundle-ID:** `com.johannesemmrich.Restock` (`asc_lib.BUNDLE`), nicht frei wählbar.
6. **Testlauf in der CI:** feste Liste in `ci.yml` (Änderung an `ci.yml` löst `scripts/test_testflight_workflow.py::test_ci_unchanged` aus, der aber nicht in der CI läuft).

## Existing Patterns
- Eigenes Skript je ASC-Aufgabe, Tests ohne Netz gegen Schein-Antworten (`FakeASC`), Schlüssel nur als Pfad an `openssl`.
- Handläufe als `workflow_dispatch` (`testflight.yml`, `cloudkit-schema.yml`), Secrets nur über `env`, Umgebung nur wo Freigabepflicht nötig.
- Jede Spec nennt Alternativen und offene Grenzen; Spec-Ordner `docs/specs/ci/` für Workflows, `docs/specs/appstore/` für ASC-Skripte.

## Dependencies
- Upstream: `asc_lib` (Token, Zaun), App-Store-Connect-API (Rollen ADMIN/APP_MANAGER/DEVELOPER für die Pfade), `gpg` (auf `ubuntu-latest`
  vorhanden, hier `/opt/homebrew/bin/gpg`), Actions `checkout` und `upload-artifact` (Hauptversionen wie in `testflight.yml`).
- Downstream: `asc_publish` über gemeinsames `ALLOWED` (nur bei Weg a); CI-Strukturtestliste.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (Zaun AC-10a…h, `asc_check`-Lesezaun), `docs/specs/ci/testflight-upload-workflow.md`,
  `docs/specs/appstore/asc-fehlertext.md` (#227, Fehlertext-Regel, die auch hier gilt).
- Vorbild-Specs in Loose Ends: `docs/specs/tooling/feat-773-schnitt-1-crash-skript.md`, `…schnitt-2-crash-ci.md`.

## Risks & Considerations
- **Datenschutz (öffentliches Repo):** Meldungen enthalten E-Mail, Kommentar, Gerätemodell, Zeitzone der Tester. Kein Klartext verlässt
  den Runner; Log nur Zahlen und Kennzeile; Chiffrat 7 Tage.
- **Log-Injektion:** Zeilen mit `::` am Anfang sind Workflow-Befehle; Kennzeile nur über `safe_field`.
- **Gleicher Empfängerschlüssel für beide Projekte:** ein geheimer Schlüssel auf diesem Mac genügt; der öffentliche Teil wird nach
  `.github/crash-recipient.asc` kopiert. Der Schlüssel heißt „Loose Ends Crash Intake“ (kosmetisch; Umbenennen würde ihn ändern).
- **Zaun-Lockerung:** Jede Erweiterung von `ALLOWED` ist sicherheitsrelevant; Tests AC-10 müssen mitgeführt werden.
- **Keine Meldungen vorhanden:** Restock hat vermutlich noch wenige TestFlight-Tester; „keine Absturzmeldungen“ ist ein gültiger Lauf, der
  Nachweis des Entschlüsselungswegs fehlt dann. Abhilfe in der Spec klären (z. B. Entschlüsselungs-Probe mit Testdatei, Gerätewege nur auf
  Henning-Wort).
- **Endpunkt:** `betaFeedbackCrashSubmissions` ist in Loose Ends belegt (echter Lauf), in Restock noch nicht; Rolle des Schlüssels
  `ASC_KEY_ID` (Restock) ist ungeprüft.
- **Scope-Limit:** Vorbild zusammen ~630 Zeilen, Restock-Limit ±250 LoC je Änderung. Test und Skript müssen schlanker werden oder in
  Schritte geteilt werden (Schnitt 1 Skript+Zaun+Test, Schnitt 2 Workflow+Schlüssel+Doku, wie im Vorbild).
- Der Haupt-Checkout ist gesperrt (Hook), gearbeitet wird im Worktree `moonlit-whistling-sundae`.

## Analysis

### Type
Feature (Übernahme eines in Loose Ends #773 belegten Mechanismus).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_crashes.py` | CREATE | Liste + Bericht abholen, eigener Lesezaun (zwei GET-Muster, Abfrage nur `limit`/`cursor`), Wiederholung bei 5xx/429, 404 = ohne Bericht, Dateien 0600, Log nur Kennzeile |
| `scripts/test_asc_crashes.py` | CREATE | Unterprozess gegen Schein-ASC, Zaun-Fälle, Log-Injektion |
| `.github/workflows/ci.yml` | MODIFY | Testdatei in die feste Liste „Strukturtests (Python)“ |
| `.github/workflows/asc-crashes.yml` | CREATE | `workflow_dispatch`, Schlüssel entpacken (Klartext oder Base64, `ASC_KEY_P8`), Skript, `tar`, `gpg`, nur `crashes.tar.gpg` hochladen (7 Tage) |
| `.github/crash-recipient.asc` | CREATE | öffentlicher Schlüssel aus dem GnuPG-Bund dieses Macs (derselbe wie Loose Ends) |
| `docs/testflight-setup.md` | MODIFY | Abschnitt „Absturzberichte abholen“ |
| `docs/specs/appstore/asc-crashes.md` | CREATE | Spec |

### Scope Assessment
- Files: 7 (Schnitt 1: 3, Schnitt 2: 4), Estimated LoC: ca. +600 gesamt (Vorbild 154 + 428 + 50), Risk: MEDIUM
- Über dem Limit (±250) → zwei Schnitte wie im Vorbild: **Schnitt 1** Skript + Test + `ci.yml` (Test schlanker als Vorbild, ca. 200 Zeilen; Skript ca. 130); **Schnitt 2** Workflow + Schlüssel + Doku + echter Probelauf.

### Technical Approach
Empfehlung: Skript mit **eigenem Lesezaun** (wie `asc_check`), `asc_lib` nur für Token und Bausteine, `ALLOWED` bleibt unverändert.
Begründung: `ALLOWED` gilt auch für `asc_publish` (Schreibwege); jede Erweiterung dort erweitert dessen Reichweite und braucht neue AC-10-Tests. Der Zaun im neuen Skript hält die Lockerung dort, wo sie gebraucht wird. Abweichung vom Ticketwortlaut („kommen in `ALLOWED`“) — technische Entscheidung, Ziel (nur diese zwei GET-Pfade) bleibt gleich.
Einzelheiten: `links.next` folgen mit Schleifenbremse und nur innerhalb des Hosts; Bundle-ID aus `asc_lib.BUNDLE`; Fehlertext über `apple_error_suffix`; kein Klartext im Log (öffentliches Repo: E-Mail, Kommentar, Gerät der Tester stecken in den Meldungen).
Belegablauf: Entschlüsselung mit dem lokalen geheimen Schlüssel in den Scratchpad. Gibt es noch keine Meldung, belegt der Probelauf „keine Absturzmeldungen“; den Entschlüsselungsweg belegt dann eine Probe mit Testdatei im Runner (kein Gerät nötig).

### Alternativen
1. Henning lädt ZIPs in App Store Connect herunter (kein Werkzeug) — Handarbeit je Absturz, von Henning abgelehnt.
2. `ALLOWED` erweitern (Ticketwortlaut) — weniger Code, aber breitere Reichweite für `asc_publish`.
3. Klartext-Artefakt statt `gpg` — verworfen: öffentliches Repo, jeder mit GitHub-Konto könnte Testerdaten lesen.
Modell/Regel: reine Regel-/API-Aufgabe, kein Modell; keine ADR wird gekippt.

### Dependencies
`asc_lib` (Token, `BUNDLE`, `apple_error_suffix`), ASC-Rolle des Schlüssels `ASC_KEY_ID` (ungeprüft, Probelauf klärt es), `gpg` auf `ubuntu-latest`, Actions `checkout`/`upload-artifact`.

### Open Questions
- [ ] Hat der Restock-Schlüssel die Rolle für `betaFeedbackCrashSubmissions`? (Probelauf in Schnitt 2; 403 wäre ein Thema für Henning)
- [ ] Gibt es schon Meldungen? (sonst Entschlüsselungs-Probe mit Testdatei)
