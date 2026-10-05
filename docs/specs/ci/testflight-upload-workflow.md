---
entity_id: testflight-upload-workflow
type: ci
created: 2026-10-05
updated: 2026-10-05
status: draft
workflow: feat-109-testflight-ci-upload
tags: [ci, github-actions, testflight, signing, app-store-connect, infrastruktur]
---

# TestFlight-Upload per GitHub Actions (Issue #109)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Der Upload zu TestFlight läuft heute lokal über die in Xcode angemeldete Apple-ID-Sitzung. Am
2026-10-05 scheiterte er mit `exportArchive Failed to Use Accounts` (abgelaufene Sitzung) und ging
erst nach Neuanmeldung durch. Dieser Ablauf macht den Upload unabhängig von einer lokalen
Anmeldung: GitHub Actions signiert per App-Store-Connect-API-Schlüssel (Cloud-Signierung) und lädt
hoch. Die leere `.github/workflows/testflight.yml` (von Henning am 2026-10-04 angelegt) wird gefüllt.
Kein App-Code ändert sich. Der lokale Weg bleibt als Rückfall.

**Offene Grenze (gilt für jede positive Zusage in diesem Dokument):** Ohne Hennings Admin-Schlüssel
ist nur die **Struktur** des Ablaufs bewiesen (Stufe A). Dass Signierung, Cloud-Zertifikate und
Upload auf dem GitHub-Runner tatsächlich funktionieren, zeigt erst der Probelauf (Stufe B) nach dem
Merge. Bis dahin ist #109 nicht abgeschlossen.

Research-Grundlage und Alternativen: `docs/context/feat-109-testflight-ci-upload.md`, Abschnitt
`## Analysis`.

## Source

- **Geändert:**
  - `.github/workflows/testflight.yml` — von leer auf ca. 100 Zeilen
  - `CLAUDE.md` — ca. 5 Zeilen Verweis auf Ablauf und lokalen Rückfall
- **Neu:**
  - `scripts/ExportOptions-testflight.plist` (ca. 20 Zeilen)
  - `docs/testflight-setup.md` (ca. 40 Zeilen)
  - `scripts/test_testflight_workflow.py` (ca. 50 Zeilen, Strukturtest; Python-Standardbibliothek +
    `plistlib`; `yaml` (PyYAML) nur wenn lokal vorhanden, sonst Textprüfung)
- **Nicht geändert:** `.github/workflows/ci.yml`, `Restock.xcodeproj/project.pbxproj`, `project.yml`,
  alle Dateien in `SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`, `RestockTests/`,
  `RestockUITests/`, die Entitlements.

Umfang: 5 Dateien (Limit 4–5), ca. +215 LoC (Limit ±250), kein Produktcode.

**Nicht-Ziele:** Auslöser bei Merge oder Tag; automatisches Schreiben der Build-Nummer ins Repo;
Änderung von `project.pbxproj`/`project.yml`; JWT-Skript zur Build-Nummer (nur Rückfall, falls der
Probelauf zeigt, dass die Automatik die Nummer nicht anhebt); Xcode Cloud.

## Verhalten

### Auslöser und Rahmen

- Einziger Auslöser: `workflow_dispatch`. Kein `push`, `pull_request`, `schedule`.
- Eingaben: `dry_run` (boolean, Default `true`) und `build_number` (string, optional, Default leer).
  Ist `build_number` gesetzt, wird sie als `CURRENT_PROJECT_VERSION=<Wert>` auf der
  `xcodebuild`-Kommandozeile übergeben (Archiv); sonst gilt der Wert aus dem Projekt (heute 9).
- Ein Job auf `macos-26` mit `environment: testflight`, `timeout-minutes: 30`,
  `permissions: contents: read`, `concurrency` (Gruppe `testflight`, `cancel-in-progress: false`).
- Es werden ausschließlich Bausteine `actions/*` verwendet (`actions/checkout@v4`,
  `actions/upload-artifact@v4`).

### Schritte

1. Checkout.
2. Xcode-Auswahl wörtlich wie `ci.yml` („Select latest available Xcode“, `ls -d /Applications/Xcode_*.app | sort -V | tail -1`,
   Rückfall `/Applications/Xcode.app`, Eintrag `DEVELOPER_DIR` in `$GITHUB_ENV`).
3. `xcodebuild -version` und `xcodebuild -showsdks` (Ausgabe auch in die Step-Summary, damit sichtbar
   ist, ob das Runner-SDK für Apple reicht).
4. Schlüssel schreiben: Secret `ASC_KEY_P8` (Base64 des `.p8`) per `env:` einlesen, mit `base64 -d`
   nach `$RUNNER_TEMP/AuthKey.p8` schreiben, `chmod 600`. Pfad in `$GITHUB_ENV` (`ASC_KEY_PATH`).
5. Archiv: `xcodebuild archive -project Restock.xcodeproj -scheme Restock -configuration Release
   -destination 'generic/platform=iOS' -archivePath $RUNNER_TEMP/Restock.xcarchive
   -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …
   -skipMacroValidation` (plus `CURRENT_PROJECT_VERSION=` bei gesetzter Eingabe). Key-ID und Issuer-ID
   kommen aus den Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` über `env:`. Auch das Archiv braucht die drei
   Parameter, weil die Profile dort angelegt werden.
6. **Nur `dry_run == true`:** kein Export. Stattdessen Prüfausgabe in `$GITHUB_STEP_SUMMARY` für
   App, Widget (`SmartCartWidgets.appex`) und Teilen-Erweiterung (`RestockShareExtension.appex`):
   `codesign -d --entitlements :- <Bundle>` (Auszug `aps-environment`, App-Gruppe), Bundle-ID und
   Team (`codesign -dvv`), Build-Nummer aus der `Info.plist`. Archiv als Artefakt
   (`actions/upload-artifact@v4`, `retention-days: 7`).
7. **Nur `dry_run == false` und `github.ref == 'refs/heads/main'`:** `xcodebuild -exportArchive
   -archivePath … -exportOptionsPlist scripts/ExportOptions-testflight.plist -exportPath
   $RUNNER_TEMP/export -allowProvisioningUpdates` mit denselben drei Schlüssel-Parametern. Mit
   `destination upload` lädt dieser Schritt direkt zu App Store Connect hoch.
8. `if: always()`: `.p8` löschen (`rm -f "$ASC_KEY_PATH"`).

Secrets stehen ausschließlich in `env:`-Blöcken, nie als `${{ secrets.… }}` direkt in einem `run:`-Text.

### ExportOptions (`scripts/ExportOptions-testflight.plist`)

`method` = `app-store-connect`, `destination` = `upload`, `teamID` = `XK87E2B3VR`,
`signingStyle` = `automatic`, `uploadSymbols` = `true`. `manageAppVersionAndBuildNumber` wird
**bewusst nicht gesetzt** (Standard `true` seit Xcode 13): ist die Build-Nummer in App Store Connect
schon belegt, vergibt Xcode beim Export eine höhere. So braucht der Ablauf keine eigene
Build-Nummern-Logik und keinen `chore:`-PR je Upload.

### Regel „nie dieselbe Nummer auf zwei Wegen“

Lokaler Upload (Rückfall) und dieser Ablauf nutzen denselben Zähler in App Store Connect. Wer
hochlädt, prüft vorher die letzte Nummer dort; ein Upload mit belegter Nummer wird abgelehnt (lokal)
oder angehoben (CI). Beides gleichzeitig laufen zu lassen ist untersagt (in `docs/testflight-setup.md`).

### Export-Compliance (geprüft, kein offener Punkt für diese Änderung)

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` ist in `project.pbxproj` für das App-Target
(Debug und Release, Bundle-ID `com.johannesemmrich.Restock`) gesetzt (Zeilen 1220 und 1311). Der Build
bleibt damit nicht auf „Fehlende Compliance“. Widget und Erweiterung brauchen den Schlüssel nicht
(nur die App wird eingereicht). Wird im Probelauf B2 nebenbei bestätigt (Build ohne Compliance-Hinweis).
Aufbewahrt wird das nur als Bestätigung; es ändert sich nichts.

## Acceptance Criteria

### Stufe A — im Repo ohne Zugangsdaten beweisbar (Teil dieses Workflows)

- AC-1: `python3 scripts/test_testflight_workflow.py` beendet sich mit Exit-Code 0; derselbe Aufruf
  gegen die leere `testflight.yml` (vor der Implementierung) beendet sich mit Exit-Code ≠ 0 (RED
  nachweisbar im TDD-Lauf).
- AC-2: `testflight.yml` ist gültiges YAML (Strukturtest parst sie mit PyYAML, falls vorhanden,
  sonst grundlegende Textprüfung) und hat unter `on:` ausschließlich `workflow_dispatch`
  (kein `push`, `pull_request`, `schedule`).
- AC-3: Die Eingabe `dry_run` ist vom Typ `boolean` mit Default `true`; `build_number` existiert,
  ist nicht `required`.
- AC-4: Der Job trägt `environment: testflight`, `timeout-minutes: 30`, `runs-on: macos-26`;
  `permissions` enthält genau `contents: read`; `concurrency` hat `cancel-in-progress: false`.
- AC-5: Der Export-/Upload-Schritt hat eine `if:`-Bedingung, die sowohl `refs/heads/main` als auch
  `dry_run` (nicht `true`) enthält; der Prüf-/Artefakt-Schritt ist an `dry_run` gebunden.
- AC-6: Jede `uses:`-Zeile beginnt mit `actions/`.
- AC-7: Kein `run:`-Block enthält den Text `secrets.`; Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_P8`) erscheinen nur in `env:`.
- AC-8: Ein Schritt löscht die `.p8` und trägt `if: always()`.
- AC-9: Der Schritt „Select latest available Xcode“ ist zeichengleich mit dem aus `ci.yml`
  (gleiche `run`-Zeilen); `xcodebuild -version` und `-showsdks` kommen vor.
- AC-10: Archiv-Schritt enthält `-allowProvisioningUpdates`, `-authenticationKeyPath`,
  `-authenticationKeyID`, `-authenticationKeyIssuerID`, `-skipMacroValidation`,
  `generic/platform=iOS`, `-configuration Release`; Export-Schritt verweist auf
  `scripts/ExportOptions-testflight.plist`.
- AC-11: `scripts/ExportOptions-testflight.plist` ist per `plistlib` lesbar und enthält
  `method=app-store-connect`, `destination=upload`, `teamID=XK87E2B3VR`, `signingStyle=automatic`,
  `uploadSymbols=true`; `manageAppVersionAndBuildNumber` ist nicht vorhanden oder `true`, nie `false`.
  `plutil -lint scripts/ExportOptions-testflight.plist` meldet `OK`.
- AC-12: `.github/workflows/ci.yml` ist gegenüber `main` unverändert (`git diff origin/main --
  .github/workflows/ci.yml` leer).
- AC-13: `docs/testflight-setup.md` existiert und enthält Abschnitte zu Einrichtung (Schlüssel mit
  Rolle Admin, Secrets, Environment), Rotation, Rückfall (lokaler Upload) und die Regel „nie dieselbe
  Build-Nummer auf zwei Wegen“; `CLAUDE.md` enthält einen Verweis auf `docs/testflight-setup.md`.
- AC-14: Der Diff umfasst höchstens 5 Dateien und höchstens 250 geänderte Zeilen und enthält keine
  Datei unter `SmartCart/`, `SmartCartWidgets/`, `RestockShareExtension/`, `RestockTests/`,
  `RestockUITests/` und nicht `Restock.xcodeproj/`.
- AC-15: Die bestehende CI (`ci.yml`: `test` und `ui-test`) bleibt auf dem PR grün.

### Stufe B — Probelauf nach Merge auf `main` (offene Grenze, Handlung des PO)

Braucht Hennings Admin-Schlüssel in den Secrets; nicht automatisierbar und von Claude nicht
auslösbar. Erst wenn beide Punkte erfüllt sind, wird #109 geschlossen.

- AC-B1: Lauf von `testflight.yml` auf `main` mit `dry_run=true` endet grün; die Step-Summary zeigt
  für App, Widget und Teilen-Erweiterung je Team `XK87E2B3VR`, die jeweilige Bundle-ID,
  `aps-environment = production` und die App-Gruppe `group.com.johannesemmrich.SmartCart`.
- AC-B2: Lauf mit `dry_run=false` auf `main` endet grün; in App Store Connect steht ein neuer Build
  mit Build-Nummer > 9, Verarbeitung abgeschlossen, ohne Compliance-Hinweis. Zeigt der Lauf, dass die
  Nummer nicht angehoben wird, folgt das JWT-Skript als eigenes Ticket.

## Tests

| # | Fall | Art | Beweist |
|---|------|-----|---------|
| 0 | RED/GREEN-Nachweis des Strukturtests: Exit ≠ 0 gegen die leere `testflight.yml` (Artefakt `test-red-output.txt`), Exit 0 nach der Implementierung (Artefakt `test-green-output.txt`) | `python3 scripts/test_testflight_workflow.py` (Lauf im TDD-Ablauf) | AC-1 |
| 1 | Nur `workflow_dispatch` | `test_testflight_workflow.py` | AC-2 |
| 2 | `dry_run` Boolean, Default true; `build_number` optional | `test_testflight_workflow.py` | AC-3 |
| 3 | `environment`, Timeout, Permissions, Concurrency | `test_testflight_workflow.py` | AC-4 |
| 4 | Upload-Schritt an `refs/heads/main` und `dry_run` gebunden | `test_testflight_workflow.py` | AC-5 |
| 5 | Alle `uses:` mit `actions/` | `test_testflight_workflow.py` | AC-6 |
| 6 | Keine `secrets.` in `run:` | `test_testflight_workflow.py` | AC-7 |
| 7 | `.p8`-Löschschritt mit `if: always()` | `test_testflight_workflow.py` | AC-8 |
| 8 | Xcode-Auswahl identisch mit `ci.yml` | `test_testflight_workflow.py` | AC-9 |
| 9 | Archiv-/Export-Parameter vorhanden | `test_testflight_workflow.py` | AC-10 |
| 10 | ExportOptions lesbar, Schlüssel, kein `manageAppVersionAndBuildNumber=false` | `test_testflight_workflow.py` (`plistlib`) | AC-11 |
| 11 | `plutil -lint` der plist | Shell | AC-11 |
| 12 | YAML-Syntax | `test_testflight_workflow.py` / `python3 -c "import yaml…"` | AC-2 |
| 13 | `ci.yml` unverändert, Dateizahl/LoC, keine App-Dateien | `git diff --stat origin/main` | AC-12, AC-14 |
| 14 | Dokumentation und CLAUDE.md-Verweis | `grep` in `test_testflight_workflow.py` | AC-13 |
| 15 | Bestehende CI grün | GitHub-CI auf dem PR | AC-15 |
| 16 | Probelauf `dry_run=true` (B1) | **manuell, nicht automatisierbar** — braucht Admin-Schlüssel, Cloud-Signierung läuft nur bei Apple/GitHub | AC-B1 |
| 17 | Probelauf `dry_run=false` (B2) | **manuell, nicht automatisierbar** — echter Upload mit Zugangsdaten, nur der PO kann sie hinterlegen | AC-B2 |

Seed/Muster entfällt (keine App-Daten, keine UI).

**TDD-Hinweis:** Der Strukturtest wird vor dem Workflow geschrieben und läuft zuerst gegen die leere
`testflight.yml` (RED, Exit ≠ 0). Danach wird `testflight.yml`, die plist und die Dokumentation
geschrieben, bis er grün ist. Der Test hängt keine Prüfung an Dinge, die er sich selbst herstellt:
er liest die echten Dateien aus dem Repo.

## Handlung des PO (nicht automatisierbar)

1. In App Store Connect (Benutzer und Zugriff → Integrationen → Team-Schlüssel) einen API-Schlüssel
   mit Rolle **Admin** anlegen, die `.p8` einmalig laden.
2. Im GitHub-Environment `testflight` (Reviewer: Henning, Deployment nur von `main`) die Secrets
   `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (Base64 der `.p8`) setzen.
3. Im Developer-Portal die Zahl der Distribution-Zertifikate ansehen (Limit).
4. Den Probelauf freigeben (Stufe B), erst `dry_run=true`, dann `dry_run=false`.

Claude sieht den Schlüssel nie (`secrets_guard`), liest ihn nie aus Keychain oder Secrets und gibt ihn
nie aus. Die Dokumentation beschreibt nur das Verfahren, enthält keine Werte.

## Risiken

| Risiko | Gegenmaßnahme |
|--------|---------------|
| Admin-Schlüssel in GitHub kann Team/Zertifikate verändern | Nur Environment-Secrets, Pflicht-Freigabe durch Henning, nur `main`, nur `actions/*`, Rotation alle 6–12 Monate, bei Verdacht sofort widerrufen |
| Zertifikate-Limit (unkontrolliertes Erzeugen je Lauf kann alte Zertifikate verdrängen) | Vor dem Probelauf Limit prüfen; Probelauf zählt Zertifikate vorher und nachher mit |
| Runner-Xcode hinter dem von Apple verlangten SDK | `-showsdks` und `-version` in der Summary; Rückfall lokaler Upload |
| Entitlements: `SmartCart.entitlements` hat `aps-environment = development` im Quelltext; die Signierung setzt für Distribution `production` | Wird in B1 nachgewiesen (`aps-environment = production`); vorher nur behauptet, nicht bewiesen |
| Kosten macOS-Minuten (10-faches Gewicht im privaten Repo) | Nur manueller Lauf, ca. 10–20 Min, `dry_run` Standard |
| Export-Compliance | `ITSAppUsesNonExemptEncryption = NO` im App-Target gesetzt (geprüft), in B2 bestätigt |
| Doppel-Upload mit lokalem Weg | Regel „nie dieselbe Nummer auf zwei Wegen“, Prüfung der letzten Nummer vor jedem Upload |
| Versehentlicher Start | `dry_run` Default true, Upload nur auf `main`, Environment-Freigabe |
| Ablauf läuft nur auf GitHub | Stufe A beweist Struktur; Stufe B ist offene Grenze |

## Alternativen (und welche frühere Entscheidung sie kippen)

1. **Xcode Cloud:** kein Schlüssel in GitHub, Signierung bei Apple, 25 Std/Monat kostenlos;
   Einrichtung nur in der Xcode-Oberfläche, nicht im Repo prüfbar. Kippt die Wahl „GitHub-Weg“
   (Hennings `testflight.yml`). Gewinnt, wenn der Admin-Schlüssel in GitHub nicht akzeptiert wird oder
   der Probelauf an der Cloud-Signierung scheitert.
2. **Lokaler Upload durch Claude** (Memory `app-store-upload-process`): bleibt als Rückfall. Ein
   lokaler Schlüssel (`-authenticationKey*`) würde „Failed to Use Accounts“ auch ohne CI entschärfen,
   müsste aber lokal liegen (Konflikt mit `secrets_guard`).
3. **Build-Nummer per `chore:`-PR** (heute #83/#108): wird durch die Xcode-Automatik überflüssig;
   Auto-Commit ins Repo wird nicht empfohlen (Schreibrechte, Branchenschutz).
4. **Auslöser bei Merge oder Tag:** würde TestFlight fluten und Nummern verbrauchen; erst nach
   erfolgreichem Probelauf und nur auf Wunsch. Kippt „nur manuell“.
5. **JWT-Skript „letzte TestFlight-Nummer + 1“:** ca. 60 Zeilen plus Fremdpaket. Regelweg
   (Standardverhalten von `manageAppVersionAndBuildNumber`) kommt zuerst; das Skript ist Rückfall,
   falls B2 zeigt, dass die Automatik die Nummer nicht anhebt.

**Entscheidung:** Manueller GitHub-Ablauf mit API-Schlüssel, `dry_run` als Standard, Build-Nummer
über die Xcode-Automatik, Struktur per Test bewiesen (Stufe A), Funktion per Probelauf nach dem
Merge (Stufe B). Alternative 1 ist der Plan B, wenn Stufe B an der Schlüssel-Rolle oder der
Cloud-Signierung scheitert.

## Offene Punkte

- (PO) Rolle **Admin** für den Schlüssel in GitHub-Secrets akzeptieren — erst beim Probelauf nötig,
  nicht für Spec und Strukturtest. Sonst Alternative 1.
- Nachrüsten eines Tag-Auslösers erst nach erfolgreichem Probelauf und nur auf Wunsch des PO.
- Memory und Ticket pflegen: nach Probelauf Memory `app-store-upload-process` (neuer Weg, Rückfall)
  und Issue #109 aktualisieren; #109 bleibt bis zum erfolgreichen B2 offen.
- Export-Compliance: geprüft (App-Target hat `ITSAppUsesNonExemptEncryption = NO`), kein Eingriff;
  wird in B2 gegengeprüft.
