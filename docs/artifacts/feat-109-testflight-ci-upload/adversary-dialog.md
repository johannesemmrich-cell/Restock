# Adversary-Dialog Issue #109 (feat-109-testflight-ci-upload)

Geprüft gegen docs/specs/ci/testflight-upload-workflow.md. Eigener Lauf des Strukturtests: 11 Tests, OK. plutil -lint der ExportOptions-plist: OK. RED-Beleg (test-red-output.txt): FAILED (failures=7, errors=2), Exit ungleich 0 gegen die leere Datei. Umfang nachgezählt: 241 Zeilen, 5 Dateien.

### Runde 1

Status: CONFIRMED
AC: AC-1
Evidence: Eigener Lauf 11/11 OK (Exit 0); RED-Artefakt test-red-output.txt zeigt FAILED (failures=7, errors=2) gegen die leere testflight.yml.
Code reference: scripts/test_testflight_workflow.py:109

Status: CONFIRMED
AC: AC-2
Evidence: Auslöser nur workflow_dispatch (Zeilen 3-4), vom Test per PyYAML mit set-Vergleich erzwungen (Zeile 25).
Code reference: .github/workflows/testflight.yml:3

Status: CONFIRMED
AC: AC-3
Evidence: dry_run type boolean, default true (Zeilen 6-9); build_number ohne required (Zeilen 10-13); Test Zeilen 26-29.
Code reference: .github/workflows/testflight.yml:6

Status: CONFIRMED
AC: AC-4
Evidence: environment testflight, runs-on macos-26, timeout 30, permissions contents read, cancel-in-progress false (Zeilen 15-26); Test Zeilen 31-37 mit exaktem Gleichheitsvergleich.
Code reference: .github/workflows/testflight.yml:24

Status: CONFIRMED
AC: AC-5
Evidence: Export-Schritt hat if mit refs/heads/main und !inputs.dry_run (Zeile 81), Prüf- und Artefaktschritt haben if inputs.dry_run (Zeilen 59, 73).
Code reference: .github/workflows/testflight.yml:81

Status: CONFIRMED
AC: AC-6
Evidence: Nur die Bausteine actions/ (Zeile 33 und Zeile 74) als uses.
Code reference: .github/workflows/testflight.yml:33

Status: CONFIRMED
AC: AC-7
Evidence: Die drei Secrets stehen nur im Job-env (Zeilen 28-30), kein secrets. in einem run-Block; Test Zeile 50.
Code reference: .github/workflows/testflight.yml:28

Status: CONFIRMED
AC: AC-8
Evidence: Schritt "Remove API key" mit if always() und rm -f auf AuthKey.p8 (Zeilen 88-90).
Code reference: .github/workflows/testflight.yml:88

Status: CONFIRMED
AC: AC-9
Evidence: Xcode-Auswahl-Zeilen identisch mit dem ersten Job in ci.yml (Test vergleicht gestrippte run-Zeilen, Zeile 60); xcodebuild -version und -showsdks in Zeile 43.
Code reference: .github/workflows/testflight.yml:34

Status: CONFIRMED
AC: AC-10
Evidence: Archiv-Schritt (Zeilen 52-56) enthält alle sieben geforderten Parameter; Export verweist auf scripts/ExportOptions-testflight.plist (Zeile 84).
Code reference: .github/workflows/testflight.yml:52

Status: CONFIRMED
AC: AC-11
Evidence: plist enthält method, destination, teamID XK87E2B3VR, signingStyle automatic, uploadSymbols true, kein manageAppVersionAndBuildNumber; plutil -lint meldet OK (eigener Lauf).
Code reference: scripts/ExportOptions-testflight.plist:5

Status: CONFIRMED
AC: AC-12
Evidence: Der Diff-Vergleich der Datei ci.yml gegen origin/main ist leer (eigener Lauf); Test test_ci_unchanged ok.
Code reference: scripts/test_testflight_workflow.py:86

Status: CONFIRMED
AC: AC-13
Evidence: docs/testflight-setup.md hat Einrichtung (Rolle Admin, Environment, Secrets), Rotation, Rückfall und die Regel "nie dieselbe Build-Nummer auf zwei Wegen"; CLAUDE.md verweist in Zeile 16 auf docs/testflight-setup.md.
Code reference: docs/testflight-setup.md:5
Code reference: CLAUDE.md:16

Status: CONFIRMED
AC: AC-14
Evidence: Diff-Zählung plus neue Dateien: 5 Dateien (yml, CLAUDE.md, plist, Doku, Test), 241 Zeilen, nichts unter SmartCart/, SmartCartWidgets/, RestockShareExtension/, RestockTests/, RestockUITests/, Restock.xcodeproj/.
Code reference: scripts/test_testflight_workflow.py:97

Finding:
  ID: F001
  Severity: LOW
  Category: security
  Code reference: .github/workflows/testflight.yml:27
  Description: Die drei Secrets stehen im Job-env und sind damit für jeden Schritt sichtbar, auch für Auschecken, Artefakt-Upload und alle Build-Skripte/Makros im xcodebuild-Lauf; die .p8 liegt während des Archivs auf der Platte.
  Spec requirement: AC-7 — Secrets nur in env, nie in run-Text
  Conflict: Spec-konform (Spec verlangt Job-env), aber breiter als nötig. Das Archiv-Artefakt enthält die .p8 nicht, da sie unter RUNNER_TEMP außerhalb des xcarchive liegt. Nur actions/-Bausteine und manueller Start mit Environment-Freigabe begrenzen das Risiko.
  Remediation: Optional Secrets je Schritt statt im Job-env setzen; nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/testflight.yml:56
  Description: Der Ausdruck mit BUILD_NUMBER (Plus-Doppelpunkt-Muster) für CURRENT_PROJECT_VERSION ist unquotiert, ein Wert mit Leerzeichen würde als zusätzliche xcodebuild-Argumente geteilt. Nur Nutzer mit Dispatch-Recht können das setzen; keine Expression-Injection, da über env.
  Spec requirement: AC-10 — Archiv-Parameter, build_number als CURRENT_PROJECT_VERSION
  Conflict: Keine Verletzung; fehlende Eingabevalidierung.
  Remediation: Optional vorher per Regex auf Ziffern prüfen.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: .github/workflows/testflight.yml:47
  Description: Der Ablauf nutzt RUNNER_TEMP/AuthKey.p8 direkt statt ASC_KEY_PATH in GITHUB_ENV (Spec Zeilen 75 und 91).
  Spec requirement: Spec Schritt 4 und 8 — Pfad in GITHUB_ENV (ASC_KEY_PATH), Löschen über diese Variable
  Conflict: Rein kosmetisch: gleicher Pfad an allen vier Stellen (Zeilen 47, 54, 85, 90), der Löschschritt trifft dieselbe Datei; weniger Zustand über GITHUB_ENV ist eher besser. Kein AC verlangt die Variable. Spec sollte nachgezogen werden.
  Remediation: Spec-Text an die Umsetzung anpassen.

### Runde 2

Zweiter Angriff: Tippfehler, Boolean-Semantik, macOS-Eigenheiten, Testlücken.

Code reference: .github/workflows/testflight.yml:59
Prüfung boolean: Bei workflow_dispatch mit type boolean ist inputs.dry_run ein echter Boolean; inputs.dry_run und !inputs.dry_run sind korrekt und schließen sich aus. Kein String-Vergleich nötig.

Code reference: .github/workflows/testflight.yml:47
Prüfung base64: macOS base64 kennt -d seit macOS 13, Runner macos-26 ok. Der Schlüssel wird nie geechot (nur Pipe). Leeres Secret ergibt leere Datei und Fehler im Archiv, nicht stillen Erfolg. Löschen läuft per always() auch bei Fehlschlag in Archiv oder Export.

Code reference: .github/workflows/testflight.yml:52
Prüfung Parameter: Alle Flags korrekt geschrieben; der Test prüft sie wörtlich (Zeilen 67-69). Archiv-Artefakt (Zeile 77) ist nur das xcarchive, keine Zugangsdaten.

Code reference: Restock.xcodeproj/project.pbxproj:220
Prüfung PlugIns-Annahme: Embed-Phase hat dstSubfolderSpec = 13 (PlugIns) mit SmartCartWidgets.appex und RestockShareExtension.appex; der Glob auf PlugIns/*.appex (testflight.yml Zeile 62) trifft beide.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/testflight.yml:66
  Description: Die Prüfausgabe nutzt grep mit "|| true"; fehlen Team/Entitlements, bleibt der Summary-Block still leer und der Schritt grün. In B1 wird das sichtbar, weil der Block dann leer ist.
  Spec requirement: AC-B1 (Stufe B) — Summary zeigt Team, Bundle-ID, aps-environment, App-Gruppe
  Conflict: Kein Stufe-A-Verstoß; schwächere Selbstprüfung.
  Remediation: Optional nach dem Block ein Test auf erwartetes Team, der den Schritt rot macht.

Finding:
  ID: F005
  Severity: MEDIUM
  Category: edge_case
  Code reference: .github/workflows/testflight.yml:67
  Description: Der Dry-Run prüft die Entitlements im Archiv. Xcode signiert das Archiv bei automatischer Signierung typischerweise mit Development-Identität; aps-environment = production entsteht erst beim Export (Distribution-Neusignierung). Das Summary könnte daher development zeigen, obwohl der Export richtig wäre.
  Spec requirement: AC-B1 — aps-environment = production in der Summary (Stufe B, nicht Stufe A)
  Conflict: Die Spec behauptet production für den Dry-Run ohne Beleg und benennt das selbst als unbewiesen (Risikotabelle). Betrifft nur Stufe B; keine Stufe-A-AC verletzt.
  Remediation: Im Probelauf B1 prüfen; bei development AC-B1 anpassen (kein Änderungsbedarf jetzt).

Finding:
  ID: F006
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_testflight_workflow.py:42
  Description: test_upload_guard prüft nur, dass dry_run als Teilstring im if des Export-Schritts vorkommt, nicht die Negation. Eine Umkehr zu "und inputs.dry_run" würde den Test bestehen.
  Spec requirement: AC-5 — if-Bedingung enthält refs/heads/main und dry_run (nicht true)
  Conflict: Test schwächer als die Absicht; die Datei selbst erfüllt sie (Zeile 81).
  Remediation: Test auf !inputs.dry_run schärfen.

Prüfung Dokument: Rückfall und Regel vorhanden, keine Werte oder Schlüssel.
Code reference: docs/testflight-setup.md:19
Prüfung CLAUDE.md: Verweis nennt Ablauf und Rückfall.
Code reference: CLAUDE.md:16
Prüfung Plist: uploadSymbols true, kein manageAppVersionAndBuildNumber (Standard true, wie Spec).
Code reference: scripts/ExportOptions-testflight.plist:15

Umfang: 241 von 250 Zeilen, 5 von 5 Dateien; knapp, aber im Limit. Der Strukturtest zählt docs/specs, docs/briefings, docs/context, docs/artifacts bewusst nicht mit (Zeile 11), wie die Spec.

Restvorbehalt (nicht BROKEN):
- AC-15 (CI ci.yml test und ui-test auf dem PR grün) ist jetzt nicht beweisbar.
- Stufe B (AC-B1, AC-B2) braucht Hennings Admin-Schlüssel; Funktion von Cloud-Signierung, Zertifikaten, Upload und Build-Nummern-Anhebung ist offen. F005 zeigt ein konkretes Risiko für AC-B1.

CRITICAL 0, HIGH 0, MEDIUM 1, LOW 5

VERDICT: VERIFIED - AC-1 bis AC-14 mit Beleg bestätigt (11/11 Tests, plutil OK, 5 Dateien/241 Zeilen, ci.yml unverändert); kein CRITICAL/HIGH; Restvorbehalt: AC-15 (CI auf dem PR) und Stufe B (AC-B1/B2, insbesondere F005 aps-environment im Archiv) sind noch nicht beweisbar.

### Runde 3

Änderung nach Runde 2: nur der Block am Dateiende des Strukturtests (Zeilen 109-112) wurde umgebaut. Er ruft unittest.main mit exit=False auf, druckt die Zeile "Executed N tests, with F failures" und beendet mit Exit 0 bei wasSuccessful, sonst 1. Die Testfälle (Zeilen 18-106) sind unverändert gelesen: gleiche Prüflogik für AC-2 bis AC-14. Fehlschlag-Pfad aus dem Code: bei jedem failure oder error ist wasSuccessful falsch, also SystemExit(1), Exit bleibt ungleich 0.
Code reference: scripts/test_testflight_workflow.py:110
Code reference: .github/workflows/testflight.yml:81

Status: CONFIRMED
AC: AC-1
Evidence: Eigener Lauf: Exit 0, letzte Zeile "Executed 11 tests, with 0 failures"; Fehlschlag liefert über wasSuccessful den Exit 1 (Zeile 112), RED-Beleg gegen die leere Datei bleibt gültig.

Status: CONFIRMED
AC: AC-14
Evidence: Neu gezählt ohne docs/specs, briefings, context, artifacts: yml 89 + CLAUDE.md 2 + Test 112 + Doku 24 + plist 16 = 243 Zeilen in 5 Dateien (Limit 250), keine App-Ordner.
Code reference: scripts/test_testflight_workflow.py:97

Bestehende Findings unverändert: F005 MEDIUM; F001, F002, F003, F004, F006 LOW. Restvorbehalt unverändert: AC-15 und Stufe B nicht beweisbar.

CRITICAL 0, HIGH 0, MEDIUM 1, LOW 5

VERDICT: VERIFIED - AC-1 bis AC-14 bestätigt (Test jetzt Exit 0 mit "Executed 11 tests, with 0 failures", Prüflogik unverändert, Fehlschlag weiter Exit 1; 5 Dateien, 243 Zeilen); kein CRITICAL/HIGH; Restvorbehalt: AC-15 (CI auf dem PR) und Stufe B (AC-B1/B2, F005) nicht beweisbar.

## Geprüfte Dateien

- sha256:d53ecd008f23b80a4c5278d4c51affaae2349c4c18c43c524c87d516b145a724  .github/workflows/testflight.yml
- sha256:9bf6e4367ab12a9bee90102a83855c0ddbb85125d8e51572eec31bbebb70e061  CLAUDE.md
- sha256:9eaee2a26b8560a4455f17dc952dce40db0d72a221fb34debfc9e76a0c1161a9  Restock.xcodeproj/project.pbxproj
- sha256:7f2cca8b70c0c8fe4c927c53ce4dfb59e849cd14db13a58e8ddf2f39e32af9d6  docs/testflight-setup.md
- sha256:175b77819929b7e34dc190edce25be1e14638ddac35658cf19b8f5ea75a943d2  scripts/ExportOptions-testflight.plist
- sha256:e3f97a9150728564d4739d1ae4551326deb3da2bba1c6a6fdf9dce09e0f68bde  scripts/test_testflight_workflow.py
