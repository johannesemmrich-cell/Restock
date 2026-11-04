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

---

# Nachtrag Schnitt 2 (Workflow `feat-242-schnitt-2-workflow`, 2026-11-04)

Schnitt 1 ist gemergt (PR #253, `45eb864` auf `main`): `scripts/asc_crashes.py`, `scripts/test_asc_crashes.py`, Eintrag in `ci.yml`.
Schnitt 2 setzt AC-16 bis AC-22 der Spec `docs/specs/appstore/asc-crashes.md` um.

## Vorlage und Bestand
| Quelle | Befund |
|---|---|
| Loose Ends `.github/workflows/asc-crashes.yml` | 50 Zeilen, `ubuntu-latest`, nur `workflow_dispatch`, `permissions: contents: read`, Secrets nur in `env`, `umask 077`, `trap` löscht Schlüssel/Ordner/Tar, `gpg --batch --trust-model always --recipient-file`, Upload nur `crashes.tar.gpg` (7 Tage), Ausgabe `encrypted=true/false` steuert den Upload |
| Loose Ends `.github/crash-recipient.asc` | 14 Zeilen, öffentlicher Block „Loose Ends Crash Intake“; der geheime Teil liegt im lokalen GnuPG-Bund (Kennung `E70D4EA560DB0DEE`, per `gpg --list-secret-keys` bestätigt) |
| `.github/workflows/testflight.yml` Z. 47–51 | Schlüssel entpacken: Klartext-.p8 oder Base64, `chmod 600`; Secret `ASC_KEY_P8`; Actions `checkout@v4`, `upload-artifact@v4` |
| `scripts/asc_crashes.py` | liest `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (nicht `ASC_KEY_FILE`), Argument Zielordner |
| `.github/workflows/ci.yml` Z. 35–47 | feste Liste „Strukturtests (Python)“; `test_asc_crashes_workflow.py` kommt dazu |
| `docs/testflight-setup.md` | letzter Abschnitt „Privater iCloud-Abgleich“ endet mit „### Fallen“; neuer Abschnitt „Absturzberichte abholen“ wird angehängt |
| `docs/artifacts/feat-242-testflight-crashes/` | existiert (Schnitt-1-Belege); Belege für AC-20/21 kommen dazu |

## Unterschiede zur Vorlage
1. Secret `ASC_KEY_P8` statt `ASC_PRIVATE_KEY`, dazu der Base64-Fall; Variable `ASC_KEY_PATH` statt `ASC_KEY_FILE`.
2. Kein `ASC_POLL_SECONDS`, keine Umgebung `testflight` (Repository-Secrets genügen zum Lesen).
3. Actions-Versionen wie im Repo (`@v4`).
4. AC-21 (Testdatei durch Verschlüsseln, Hochladen, Entschlüsseln) braucht einen einmaligen Beleglauf, der den Workflow nicht dauerhaft verändert.

## Risiken
- `workflow_dispatch` läuft erst, wenn die Datei auf dem Standardzweig `main` liegt: AC-20 und AC-21 sind daher erst nach dem Merge möglich. In der Spec ist das noch nicht festgehalten und wird in `/20-analyse` geklärt (zweiter kleiner Beleg-PR oder Lauf über einen Zweig, falls GitHub das für neue Workflow-Dateien zulässt).
- Rolle des Schlüssels für `betaFeedbackCrashSubmissions` ungeprüft (403 wäre ein Thema für Henning, AC-22).
- Das Repo ist öffentlich: Klartext nie in Log oder Artefakt, `trap` muss auch bei Fehlschlag greifen.
- Die Bash-Guards dieser Umgebung blockieren Befehle mit Schlüsselstichwörtern und zusammengesetzte Aufrufe.

## Analysis Schnitt 2 (2026-11-04)

### Type
Feature (zweiter Schnitt von #242; setzt AC-16 bis AC-22 um).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/asc-crashes.yml` | CREATE | `workflow_dispatch` (Eingabe `selftest`, Standard false), Schlüssel entpacken (Klartext/Base64, `ASC_KEY_P8`), `umask 077`, `trap`, Skript, `tar`, `gpg --recipient-file`, Upload nur `crashes.tar.gpg` (7 Tage) |
| `.github/crash-recipient.asc` | CREATE | öffentlicher Schlüssel aus dem lokalen GnuPG-Bund (nur Export des öffentlichen Teils) |
| `scripts/test_asc_crashes_workflow.py` | CREATE | liest nur Repo-Dateien, AC-16 bis AC-19 |
| `.github/workflows/ci.yml` | MODIFY | Testdatei in die feste Liste „Strukturtests (Python)“ |
| `docs/testflight-setup.md` | MODIFY | Abschnitt „Absturzberichte abholen“ |
| `docs/specs/appstore/asc-crashes.md` | MODIFY | AC-20/21 als Nachweis nach dem Merge, `selftest` aufnehmen |

### Scope Assessment
- Files: 6, Estimated LoC: ca. +150, Risk Level: MEDIUM (öffentliches Repo, Klartext darf nie in Log/Artefakt; Rolle des Schlüssels ungeprüft)

### Technical Approach
Recherche (zuerst): Ein `workflow_dispatch`-Workflow läuft nur, wenn die Datei auf dem Standardzweig liegt; `gh workflow run --ref <zweig>` findet eine neue, nur auf einem Zweig liegende Datei meist nicht (GitHub-Community-Diskussionen 198084, 178194, 25756; Bericht dev.classmethod.jp). Ein Umweg über absichtlich kaputte Syntax ist inoffiziell und wird nicht benutzt.
Folge: AC-20/AC-21 sind **erst nach dem Merge** möglich. Ablauf: (1) PR mit Workflow, Schlüssel, Strukturtest, Doku; CI grün; selbst mergen. (2) Auf `main`: `gh workflow run asc-crashes.yml` (AC-20) und `gh workflow run asc-crashes.yml -f selftest=true` (AC-21). (3) Belege (Lauf-ID, Zählung, Prüfsummen) in einem kleinen Doku-PR unter `docs/artifacts/feat-242-testflight-crashes/`. Die Spec sagt das bisher nicht und wird in `/30-write-spec` angepasst (AC-20/21 ausdrücklich nach dem Merge, nicht als Vorbedingung für Validate; Memory „CI-Beleg nie als Pre-Push-AC“).
`selftest`: Eingabe im Workflow ersetzt den Abholschritt durch eine im Runner erzeugte Zufallsdatei (keine Testerdaten, kein Apple-Aufruf), danach derselbe Weg tar → gpg → Upload. Nach dem Herunterladen wird lokal entschlüsselt und die Prüfsumme verglichen. Der Eingang bleibt dauerhaft im Workflow (≈10 Zeilen) und ist damit auch später ein Gesundheitstest des Entschlüsselungswegs.

### Alternativen
1. Beleglauf über ein Wegwerf-Workflow nach dem Merge (zweiter PR, danach löschen) — kein dauerhafter Code, aber ein zusätzlicher PR-Zyklus und der Weg bleibt später nicht prüfbar. Verworfen.
2. Entschlüsselung nur durch AC-20 belegen, falls echte Meldungen vorliegen — unsicher, vermutlich noch keine Meldungen. Verworfen.
3. Klartext-Artefakt — verworfen (öffentliches Repo).
Regelweg: reine Skript-/Workflow-Aufgabe, kein Modell; keine ADR wird gekippt.

### Dependencies
`scripts/asc_crashes.py` (Schnitt 1, gemergt), Actions `checkout@v4`/`upload-artifact@v4`, `gpg` auf `ubuntu-latest`, drei Repository-Secrets (gesetzt), lokaler geheimer Schlüssel „Loose Ends Crash Intake“ für das Entschlüsseln.

### Open Questions
- [ ] Rolle des Restock-Schlüssels für `betaFeedbackCrashSubmissions` (klärt AC-20 nach dem Merge; 403 = Thema für Henning)
- [ ] Gibt es schon Meldungen (sonst belegt AC-20 „keine Absturzmeldungen“, AC-21 den Entschlüsselungsweg)
