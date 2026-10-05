# Context: feat-109-testflight-ci-upload

## Request Summary
Issue #109: Die leere `.github/workflows/testflight.yml` (von Henning am 2026-10-04 in der GitHub-Oberfläche angelegt) so füllen, dass ein Build ohne lokale Xcode-Anmeldung signiert und zu App Store Connect hochgeladen wird. Auslöser: Der lokale Upload von Build 9 scheiterte am 2026-10-05 mit `exportArchive Failed to Use Accounts` (abgelaufene Apple-ID-Sitzung in Xcode); nach Neuanmeldung ging er durch.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `.github/workflows/testflight.yml` | Leer (1 Leerzeile), Ziel der Aufgabe |
| `.github/workflows/ci.yml` | Vorbild: Runner `macos-26`, Xcode-Auswahl (`ls /Applications/Xcode_*.app \| sort -V \| tail -1`), baut das eingecheckte `.xcodeproj` (nie `xcodegen`, `project.yml` ist veraltet), `-skipMacroValidation`, Signierung dort aus (`CODE_SIGNING_REQUIRED=NO`) |
| `Restock.xcodeproj/project.pbxproj` | `CURRENT_PROJECT_VERSION` (6 Stellen, aktuell 9), `MARKETING_VERSION 1.0`, `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = XK87E2B3VR` (10 Stellen) |
| `project.yml` | `CURRENT_PROJECT_VERSION` (2 Stellen); stale gegenüber dem Projekt, wird nur von Hand mitgepflegt |
| `SmartCart/SmartCart.entitlements`, `SmartCartWidgets/…entitlements`, `RestockShareExtension/…entitlements` | Capabilities: iCloud/CloudKit (`iCloud.com.johannesemmrich.SmartCart`), App-Gruppe `group.com.johannesemmrich.SmartCart`, Push (`aps-environment`), Key-Value-Store |

## Auslieferungsrelevante Ziele (Bundle-IDs)
- `com.johannesemmrich.Restock` (App)
- `com.johannesemmrich.Restock.SmartCartWidgets` (Widget)
- `com.johannesemmrich.Restock.RestockShareExtension` (Teilen-Erweiterung)
Nicht ausgeliefert: `…RestockTests`, `…RestockUITests`.
Alle drei brauchen ein Distribution-Provisioning-Profil mit iCloud, App-Gruppe und Push; bisher erzeugte das Xcode lokal automatisch (`-allowProvisioningUpdates`).

## Heutiger Upload-Weg (Stand 2026-10-05)
`xcodebuild archive -configuration Release -destination generic/platform=iOS -allowProvisioningUpdates`, dann `xcodebuild -exportArchive` mit `ExportOptions.plist` (`method app-store-connect`, `destination upload`, `teamID XK87E2B3VR`, `signingStyle automatic`). Läuft über die in Xcode angemeldete Apple-ID-Sitzung. Funktionierte am 2026-10-01 (Build 8) und 2026-10-05 nach Neuanmeldung (Build 9); dazwischen schlug es mit „Failed to Use Accounts“ fehl. Build-Nummer wird vorher per eigenem `chore:`-PR von Hand erhöht (#83, #108).

## Existing Patterns
- Projektregel: Ein Upload mit bereits belegter Build-Nummer wird abgelehnt (Memory `app-store-upload-process`).
- Zugangsdaten gehören nie in den Code; `secrets_guard` blockiert jedes Auslesen von Keychain/Schlüsseln.
- CI-Jobs auf `macos-26` brauchen `ui-test` ~45 Min; ein Upload-Job braucht diese nicht.

## Dependencies
- Upstream: Apple Developer Team `XK87E2B3VR`, App-Store-Connect-API-Schlüssel (existiert noch nicht), GitHub-Secrets (existieren noch nicht), Xcode auf dem `macos-26`-Runner (neueste vorinstallierte Version).
- Downstream: TestFlight/App Store Connect; die manuelle Build-Nummern-Routine; Hennings Workflow „Claude lädt hoch“ (Memory), der als Rückfall bleiben soll.

## Existing Specs
Keine zu CI/Upload unter `docs/specs/`.

## Risks & Considerations
- **Zugangsdaten:** Der Schlüssel (`.p8`, Key-ID, Issuer-ID) kann nur Henning in App Store Connect anlegen und in GitHub als Secrets hinterlegen. Ich darf ihn nie sehen oder ausgeben.
- **Cloud-Signierung:** Mit API-Schlüssel kann `xcodebuild -allowProvisioningUpdates -authenticationKey*` Zertifikate und Profile selbst verwalten; dafür ist je nach Apple-Doku die Rolle „Admin“ (oder „App Manager“ plus Cloud-Signierung) nötig. Apple begrenzt die Zahl der Distribution-Zertifikate; ein unkontrolliertes Erzeugen je Lauf kann alte Zertifikate verdrängen (Forenberichte).
- **Build-Nummer:** Heute von Hand im Projekt. Automatisch aus der Lauf-Nummer abzuleiten würde `project.pbxproj` und die Handpflege entkoppeln; Entscheidung für `/20-analyse`.
- **Auslöser:** Nur manuell (`workflow_dispatch`), bei Tag oder bei Merge nach `main`? Ein automatischer Upload bei jedem Merge würde Build-Nummern verbrauchen und TestFlight fluten.
- **Nicht lokal testbar:** Der Ablauf läuft nur auf GitHub; ein echter Probelauf braucht die Secrets. Prüfbar ohne Secrets: YAML-Syntax, Schritt „Archiv bauen“ ohne Upload (`workflow_dispatch` mit Trockenlauf-Eingabe).
- **Doppelte Wege:** Der lokale Upload bleibt als Rückfall; nie dieselbe Build-Nummer auf zwei Wegen hochladen.
- **Runner-Xcode vs. lokales Xcode:** Der Upload verlangt ein SDK, das Apple akzeptiert; der Runner nimmt die neueste vorinstallierte Version.
- **Offene Frage für die Analyse (Alternative):** Xcode Cloud statt GitHub Actions (keine Schlüsselverwaltung, Signierung bei Apple) oder eine Neuanmelde-Routine lokal.

## Analysis

### Type
Feature (Infrastruktur/CI, keine sichtbare App-Änderung, kein Modell beteiligt; alles deterministisch). Keine Entwurfs-Vorschau nötig (kein UI).

### Recherche (vor der Analyse, mit Quellen)
- `xcodebuild archive`/`-exportArchive` akzeptieren `-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID` zusammen mit `-allowProvisioningUpdates` — Anmeldung per App-Store-Connect-API-Schlüssel statt Apple-ID-Sitzung ([techconcepts.org](https://techconcepts.org/blog/github-actions-ios), [dev.to/karaiskc](https://dev.to/karaiskc/archive-and-export-ios-app-with-github-actions-3gnh)).
- Cloud-Signierung per API-Schlüssel braucht die Rolle **Admin**; Developer/App Manager scheitern mitten im Lauf mit „Cloud signing permission error“ ([Apple-Forum 698117](https://developer.apple.com/forums/thread/698117), [776036](https://developer.apple.com/forums/thread/776036), [Apple: Cloud-managed certificates](https://developer.apple.com/help/account/create-certificates/cloud-managed-certificates/)).
- Der Fehler vom 2026-10-05 („Failed to Use Accounts“) ist ein bekanntes Muster abgelaufener Xcode-Sitzungen ([Apple-Forum 742458](https://developer.apple.com/forums/thread/742458), [744834](https://developer.apple.com/forums/thread/744834)).
- **Build-Nummer:** Der Export-Schlüssel `manageAppVersionAndBuildNumber` ist seit Xcode 13 standardmäßig `true`; App Store Connect erhöht eine bereits belegte Nummer dann selbst, sodass der Upload nicht an Duplikaten scheitert ([Apple-Forum 693862](https://developer.apple.com/forums/thread/693862), [Bitrise-Forum](https://discuss.bitrise.io/t/xcode-13-and-manage-version-and-build-number-option/18244)). Alternative: letzte TestFlight-Nummer per API + 1 ([fastlane](https://docs.fastlane.tools/actions/latest_testflight_build_number/)).
- Xcode Cloud: 25 Rechenstunden/Monat im Developer Program, GitHub-Anbindung, TestFlight bei Merge, Signierung bei Apple ([Apple](https://developer.apple.com/xcode-cloud/), [Kodeco](https://www.kodeco.com/36548823-getting-started-with-xcode-cloud)).

### Entscheidung zur Build-Nummer (Regelweg vor Eigenbau)
Ein eigenes Skript (JWT gegen die App-Store-Connect-API, „letzte Nummer + 1“, ca. 60 Zeilen plus Fremdpaket) wurde vom Plan-Agenten vorgeschlagen. **Einfacher und zuerst zu bauen:** `manageAppVersionAndBuildNumber` in der ExportOptions auf dem Standard (`true`) lassen; Xcode/App Store Connect zählen eine belegte Nummer selbst hoch. Optionaler Handgriff: Eingabe `build_number` überschreibt per `CURRENT_PROJECT_VERSION=` auf der Kommandozeile. Das JWT-Skript bleibt **Rückfall**, falls der echte Probelauf zeigt, dass die Automatik die Nummer nicht anhebt. Gekippt wird damit nichts am Repo: keine Dateiänderung für die Nummer, `project.yml` bleibt stale.
Nachweis im Probelauf: hochgeladene Nummer in App Store Connect ist > 9 (Build 9 liegt schon dort).

### Affected Files (with changes)
| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `.github/workflows/testflight.yml` | MODIFY (leer → ca. 100 Z.) | `workflow_dispatch` mit `dry_run` (Default true) und optional `build_number`; Job mit `environment: testflight`; .p8 aus Secret nach `$RUNNER_TEMP`, nach dem Lauf gelöscht; Archiv + Export mit Schlüssel; nur `actions/*` |
| `scripts/ExportOptions-testflight.plist` | CREATE (ca. 20 Z.) | `method app-store-connect`, `destination upload`, `teamID XK87E2B3VR`, `signingStyle automatic`, `uploadSymbols true`; `manageAppVersionAndBuildNumber` bewusst nicht gesetzt (Standard true) |
| `docs/testflight-setup.md` | CREATE (ca. 40 Z.) | Einrichtung (Schlüssel, Secrets, Environment), Rotation, Rückfall, Regel „nie dieselbe Nummer auf zwei Wegen“ |
| `CLAUDE.md` | MODIFY (ca. 5 Z.) | Verweis auf Ablauf und lokalen Rückfall |

### Scope Assessment
- Dateien: 4 (Limit 4–5), Umfang ca. +165 LoC (Limit ±250). Kein Produktcode, keine Tests im App-Target.
- Risk Level: HIGH im Blast Radius (Admin-Schlüssel in GitHub, Signierung), MEDIUM in der Umsetzung (Ablauf läuft nur auf GitHub).

### Technical Approach
- Auslöser nur manuell; `dry_run=true` ist Standard (versehentlicher Start lädt nie hoch). Upload-Schritt nur auf `refs/heads/main`. Environment `testflight` mit Pflicht-Freigabe durch Henning; Secrets nur dort. `permissions: contents: read`, `concurrency` ohne Abbruch, `timeout-minutes: 30`.
- Schritte: Checkout, Xcode-Auswahl wörtlich wie `ci.yml`, `xcodebuild -version`/`-showsdks`, .p8 schreiben (Secret per `env:`, Base64 → `base64 -d`, `chmod 600`), `xcodebuild archive` für `generic/platform=iOS` mit den drei Authentifizierungs-Parametern und `-allowProvisioningUpdates` (auch das Archiv braucht sie), Export mit eingechecktem ExportOptions, `if: always()` Löschen der .p8; bei `dry_run` Archiv-Prüfung (`codesign -d --entitlements`, `security cms -D -i embedded.mobileprovision` für App, Widget, Teilen-Erweiterung) in die Step-Summary statt Upload.
- Prüfbar ohne Secrets: YAML-Syntax, `plutil -lint`, Archiv-Trockenlauf mit `CODE_SIGNING_ALLOWED=NO` (zeigt, dass drei Ziele und SDK passen, aber nicht Signierung/Entitlements). Nur der echte Lauf zeigt Schlüssel-Rolle, Cloud-Signierung der drei Profile (iCloud, App-Gruppe, Push), `aps-environment` production, Upload-Annahme.
- Handlung des PO (nicht automatisierbar): Schlüssel mit Rolle **Admin** in App Store Connect anlegen (Benutzer und Zugriff → Integrationen → Team-Schlüssel), `.p8` einmalig laden, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (Base64) als Environment-Secrets im Environment `testflight` setzen (Reviewer = er selbst, nur `main`), Zertifikate-Limit im Developer-Portal ansehen, Probelauf freigeben. Ich sehe den Schlüssel nie (`secrets_guard`).

### Alternativen (und welche frühere Entscheidung sie kippen)
1. **Xcode Cloud:** kein Schlüssel in GitHub, Signierung bei Apple, 25 Std/Monat kostenlos; Einrichtung nur in der Xcode-Oberfläche, nicht im Repo prüfbar. Kippt die Wahl „GitHub-Weg“ (Hennings `testflight.yml`). Gewinnt, wenn Henning einen Admin-Schlüssel in GitHub nicht akzeptiert oder der Probelauf an der Cloud-Signierung scheitert.
2. **Lokal weiter durch Claude hochladen** (Memory `app-store-upload-process`): bleibt als Rückfall; die abgelaufene Sitzung ist mit Neuanmeldung behoben. Ein lokaler Schlüssel (`-authenticationKey*`) würde „Failed to Use Accounts“ auch ohne CI entschärfen, müsste aber lokal liegen.
3. **Build-Nummer per `chore:`-PR** (heute, #83/#108): kippt durch die Xcode-Automatik; spart einen PR je Upload. Auto-Commit der Nummer ins Repo wird nicht empfohlen (braucht Schreibrechte und Umgehung des Branchenschutzes).
4. **Auslöser bei Merge/Tag:** würde TestFlight fluten und Nummern verbrauchen; erst nach erfolgreichem Probelauf und nur auf Wunsch.

### Dependencies
- Upstream: App-Store-Connect-API-Schlüssel (Admin), GitHub-Environment `testflight`, `macos-26`-Runner mit passender Xcode-Version, Team `XK87E2B3VR`.
- Downstream: TestFlight; lokaler Rückfall-Upload; Export-Compliance (`ITSAppUsesNonExemptEncryption` im Info.plist in der Spec prüfen, sonst bleibt der Build auf „Fehlende Compliance“).

### Risiken (zusätzlich zum Kontext)
- Admin-Schlüssel kann Team/Zertifikate ändern → nur Environment-Secrets, Pflicht-Freigabe, nur `main`, nur `actions/*`, Rotation 6–12 Monate, bei Verdacht sofort widerrufen.
- macOS-Minuten kosten das 10-Fache (privates Repo); Archiv+Upload ca. 10–20 Min je manuellem Lauf, überschaubar.
- Runner-Xcode kann hinter dem von Apple verlangten SDK liegen → `-showsdks` in der Summary.

### Open Questions
- [ ] (PO) Rolle **Admin** für den Schlüssel in GitHub-Secrets akzeptieren — sonst Xcode Cloud. Empfehlung: akzeptieren, abgesichert wie oben. Wird erst beim Probelauf gebraucht, nicht für Spec/Tests.
- [ ] (technisch, für die Spec) `ITSAppUsesNonExemptEncryption` im Info.plist prüfen.
