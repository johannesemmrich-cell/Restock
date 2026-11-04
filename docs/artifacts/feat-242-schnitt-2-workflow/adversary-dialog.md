# Adversary Dialog — feat-242-schnitt-2-workflow
Spec: docs/specs/appstore/asc-crashes.md
Datum: 2026-11-04 13:55

## Checkliste
- [x] AC-16: Auslöser nur workflow_dispatch (Eingabe selftest), contents: read, Secrets nur im env, Upload nur crashes.tar.gpg (7 Tage)
- [x] AC-17: Schlüssel entpacken wie testflight.yml, chmod 600, umask 077, trap EXIT räumt auf
- [x] AC-18: Leerer Ordner ergibt kein Artefakt; sonst gpg --recipient-file
- [x] AC-19: Öffentlicher Schlüssel ohne privaten Teil, Doku-Abschnitt mit gh run download und gpg --decrypt
- [x] AC-23: Selbsttest ersetzt den Abruf, eigenes Artefakt crashes-selftest
- [x] AC-24: Workflow-Test steht in der Liste „Strukturtests (Python)“ in ci.yml
- AC-20 bis AC-22: Nachweise nach dem Zusammenführen auf main, nicht Teil dieser Prüfung

## Dialog

### Runde 1
**Adversary:** Jeden AC gegen den Spec-Wortlaut geprüft, alle Tests ausgeführt: test_asc_crashes_workflow.py 6, test_asc_crashes.py 15, test_asc_scripts.py 28, test_asc_check.py 47, zusammen 96 bestanden, 0 fehlgeschlagen.
Scope: geändert nur ci.yml (+1 Zeile) und docs/testflight-setup.md (+14); neu asc-crashes.yml und crash-recipient.asc; asc_lib, asc_check, asc_publish, asc_crashes.py und App-Code unberührt.
Schlüssel: `gpg --show-keys` zeigt ed25519 [SC] 12B7274736C82FE794EC2E03E70D4EA560DB0DEE mit cv25519 [E]-Unterschlüssel, kein Ablauf, kein Widerruf, 0 Treffer für PRIVATE. Round-Trip mit den Workflow-Optionen (tar, gpg --batch --trust-model always --recipient-file --encrypt, dann --decrypt und tar -x): SHA-256 vor und nach gleich.
Lecks: kein set -x, kein echo von Secrets, kein secrets.* in run:; trap wird vor dem Schreiben der Schlüsseldatei gesetzt; Upload-Pfad ausschließlich crashes.tar.gpg, Klartextordner und Tar liegen in RUNNER_TEMP und werden vom trap gelöscht.
Logik: leerer Ordner beendet den Schritt mit exit 0 (trap läuft, kein Chiffrat, Upload per hashFiles übersprungen); Fehlschlag von asc_crashes.py macht den Schritt rot (bash -e), Uploads laufen nicht; im Selbsttest läuft asc_crashes.py nie, also kein Apple-Zugriff.
Doku: Befehle, Artefaktnamen und Selbsttest-Flag passen zum Workflow; Datenschutz-, 403- und Merge-Reihenfolge-Hinweis vorhanden.
Code reference: .github/workflows/asc-crashes.yml:37
Code reference: .github/crash-recipient.asc:1
Code reference: docs/testflight-setup.md:99
Code reference: .github/workflows/ci.yml:45
Code reference: scripts/test_asc_crashes_workflow.py:53
**Implementierer:** Keine offenen Nachfragen; Beweise (Testausgaben, Round-Trip) vom Adversary selbst erhoben.

### Runde 2
**Adversary:** Gezielte Brechversuche: leeres oder falsch formatiertes Secret (Schritt rot, trap räumt), gpg schlägt fehl (rot, kein Upload), alte crashes.tar.gpg im Checkout (gibt es nicht), Artefaktverwechslung (Namen über if strikt getrennt), retention-days und Berechtigungen gleich Spec, gpg-Optionen wortgleich zur Spec. Kein Defekt gefunden.
Code reference: .github/workflows/asc-crashes.yml:37
**Implementierer:** Keine Nachfragen.

## Findings
- F001 (LOW): AC-17 wird vom Test nur über Teilstrings abgesichert; ein Umbau, der den trap hinter das Schreiben des Schlüssels setzt, würde nicht auffallen. Der aktuelle Workflow ist korrekt. Code reference: scripts/test_asc_crashes_workflow.py:53. Kein Fix in diesem Schnitt (Test ist Bestand aus RED).
- F002 (LOW): „GnuPG bereitstellen“ (brew install gnupg) kann auf dem Runner langsam sein oder scheitern; Timeout 15 min fängt es ab, der Probelauf auf main zeigt es. Code reference: .github/workflows/asc-crashes.yml:31.

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Basis: merge-base(origin/main, HEAD) 45eb8645efc5a834050b4ddfeb32c90953e46856

## Geprüfte Dateien

- sha256:caa0b90e0b485be2bf7f8a32c59e22253688e4263786655d00c7ef25c2cff7a0  .github/crash-recipient.asc
- sha256:015ea9508aa9bd48def0255e84e3c584a1de304e58d9ef812a6c1187264afee8  .github/workflows/asc-crashes.yml
- sha256:145893bc87b73b1220308ee4d652283aae1a178e321d68539eec9a1af0e8ea76  .github/workflows/ci.yml
- sha256:1e25f29b77d0c2989b79862284f37168b85ed48ebb0f11bcb0b344bb57206f6c  docs/testflight-setup.md
- sha256:1d94c78d36b16e8a8da00a15f29e3aa5639cd86b9d8ab65bab0658ec3255e6a9  scripts/test_asc_crashes_workflow.py

## Prüfbasis

- base: 45eb8645efc5a834050b4ddfeb32c90953e46856
- blob:99eda3118a19daaebca8664f933f531eb1a61741  .github/crash-recipient.asc
- blob:d665bdbeabd6cc051e5ec4d0cc51c3b779e1391a  .github/workflows/asc-crashes.yml
- blob:004eccb65f7517b41c9c107415524b257e18b7dc  .github/workflows/ci.yml
- blob:9f0055407f92d08034f8939606aafa50311764b6  docs/testflight-setup.md
- blob:af5c4f4e737ad1069a779c21b916116fe62b999b  scripts/test_asc_crashes_workflow.py

## Geprüfte Dateien

- sha256:caa0b90e0b485be2bf7f8a32c59e22253688e4263786655d00c7ef25c2cff7a0  .github/crash-recipient.asc
- sha256:015ea9508aa9bd48def0255e84e3c584a1de304e58d9ef812a6c1187264afee8  .github/workflows/asc-crashes.yml
- sha256:145893bc87b73b1220308ee4d652283aae1a178e321d68539eec9a1af0e8ea76  .github/workflows/ci.yml
- sha256:1e25f29b77d0c2989b79862284f37168b85ed48ebb0f11bcb0b344bb57206f6c  docs/testflight-setup.md
- sha256:1d94c78d36b16e8a8da00a15f29e3aa5639cd86b9d8ab65bab0658ec3255e6a9  scripts/test_asc_crashes_workflow.py

## Prüfbasis

- base: 45eb8645efc5a834050b4ddfeb32c90953e46856
- blob:99eda3118a19daaebca8664f933f531eb1a61741  .github/crash-recipient.asc
- blob:d665bdbeabd6cc051e5ec4d0cc51c3b779e1391a  .github/workflows/asc-crashes.yml
- blob:004eccb65f7517b41c9c107415524b257e18b7dc  .github/workflows/ci.yml
- blob:9f0055407f92d08034f8939606aafa50311764b6  docs/testflight-setup.md
- blob:af5c4f4e737ad1069a779c21b916116fe62b999b  scripts/test_asc_crashes_workflow.py
