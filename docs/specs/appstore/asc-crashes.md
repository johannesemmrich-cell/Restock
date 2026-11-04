# Spec: TestFlight-Absturzberichte per CI abholen (Issue #242)

Workflow: `feat-242-testflight-crashes` · Kontext: `docs/context/feat-242-testflight-crashes.md` · Vorbild: Loose Ends #773 (Schnitt 1 PR #775, Schnitt 2 PR #778, am 2026-10-31 mit echtem Lauf belegt)

## Problem
Stürzt die App bei einem TestFlight-Tester ab, liegt die Meldung nur in App Store Connect. Henning müsste sie von Hand herunterladen und weiterreichen, damit Claude sie lesen kann. Das lehnt er ab. Gebraucht wird ein Handlauf in der CI, der die Meldungen und Berichte über die App-Store-Connect-API abholt und so ablegt, dass Claude sie lesen kann, ohne dass Testerdaten öffentlich werden. Das Repo ist öffentlich: Lauf-Logs und Artefakte kann jeder mit GitHub-Konto lesen, die Meldungen enthalten aber E-Mail, Kommentar, Gerätemodell und Zeitzone der Tester.

## Lösung (Regelweg, kein Modell: zwei GET-Aufrufe, `tar`, `gpg`)
Zwei Schnitte wegen des Limits von ±250 LoC je Änderung.

**Schnitt 1: Skript, Test, Testliste.**
- `scripts/asc_crashes.py <zielordner>` holt nur lesend ab. Token über `asc_lib.make_token` (Umgebung `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`), Bundle-ID `asc_lib.BUNDLE`, Fehlertext über `asc_lib.apple_error_suffix` (Regel aus #227).
- **Eigener Lesezaun im Skript** (Vorbild `asc_check.check_read`/`Reader`). `asc_lib.ALLOWED` bleibt unverändert. Erlaubt sind nur: `GET /v1/apps?filter[bundleId]=<BUNDLE>` (App-ID, schon bekannte Abfrage), `GET /v1/apps/{id}/betaFeedbackCrashSubmissions?limit=200` und `GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog` (ohne Abfrage). IDs nur aus vorherigen Antworten. Abweichung vom Ticketwortlaut („kommen in `ALLOWED`“): Die Liste gilt auch für `asc_publish` mit Schreibwegen, eine Erweiterung dort würde dessen Reichweite vergrößern; Ziel des Tickets (nur diese lesenden Pfade) bleibt gleich.
- `links.next` wird nur gefolgt, wenn Host gleich `api.appstoreconnect.apple.com`; es wird in Pfad plus Abfrage zerlegt und läuft wieder durch den Zaun (die Seitenabfrage von Apple darf zusätzlich `cursor` tragen, sonst nichts). Schleifenbremse: ein schon angefragter Pfad oder mehr als 50 Seiten bricht ab.
- Je Meldung `<id>.json` (Attribute wie geliefert) und, wenn Apple einen Bericht hat, `<id>.crash` (`logText`), Dateimodus 0600, Ordner 0700. Die Datei-ID muss `[A-Za-z0-9._-]+` entsprechen.
- Wiederholung bei HTTP 5xx, 429 und Netzfehlern: höchstens 5 Versuche mit kurzer, injizierbarer Wartezeit. HTTP 404 beim Bericht heißt „ohne Bericht“ (nur `.json`). Jeder andere Fehler bricht mit Status, Pfad und Apples `code`/`title` ab (Exit 1).
- Log nur Kennzeile je Meldung: Id, Plattform, Datum, jedes Feld durch `safe_field` (nur `[A-Za-z0-9._:+-]`, höchstens 64 Zeichen, sonst `?`; kein Feld beginnt mit `::`, damit keine Workflow-Befehle entstehen). Nie E-Mail, Kommentar, Gerätedaten, Berichtstext, Token oder Schlüsselpfad. Schlusszeile mit Anzahl; ohne Meldungen „keine Absturzmeldungen“.
- `scripts/test_asc_crashes.py` fährt das Skript im Unterprozess gegen einen lokalen Schein-ASC (127.0.0.1) und Einzelfunktionen über die `send`-Naht. Kein Netz, kein echter Schlüssel. Eintrag in die feste Liste „Strukturtests (Python)“ in `.github/workflows/ci.yml`.

**Schnitt 2: Workflow, Schlüssel, Doku, Probelauf.**
- `.github/workflows/asc-crashes.yml`: nur `workflow_dispatch`, `permissions: contents: read`, Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` ausschließlich über `env` (Namen wie in `testflight.yml`, nicht wie bei Loose Ends). Der Schlüssel wird wie in `testflight.yml` entpackt (Klartext-.p8 oder Base64) nach `$RUNNER_TEMP`, Modus 600, `umask 077`. Ablauf: Skript, `tar`, `gpg --batch --trust-model always --recipient-file .github/crash-recipient.asc --encrypt`. Hochgeladen wird nur `crashes.tar.gpg` (Artefakt `crashes`, 7 Tage). Ein `trap` löscht Schlüssel, Klartextordner und Klartext-Tar. Ohne Meldungen entsteht kein Artefakt, das Protokoll sagt „keine Absturzmeldungen“.
- `.github/crash-recipient.asc`: öffentlicher Schlüssel „Loose Ends Crash Intake“, derselbe wie bei Loose Ends (ein geheimer Schlüssel im GnuPG-Bund dieses Macs genügt). Nie ein privater Schlüssel im Repo.
- `docs/testflight-setup.md`: Abschnitt „Absturzberichte abholen“ (Auslösen, `gh run download <id> -n crashes`, `gpg --decrypt`, `tar -x`, Datenschutzhinweis).

## Acceptance Criteria

### Schnitt 1 (Skript, Test, Testliste)
- [ ] AC-1: Der Lesezaun lässt genau drei Aufrufarten durch (App-Lookup mit `filter[bundleId]=<BUNDLE>`, Meldungsliste mit `?limit=200`, bei Folgeseiten zusätzlich `cursor=<Wert>` als einzige weitere Abfrage, Bericht ohne Abfrage); jede andere Methode (POST, PATCH, DELETE), jeder andere Pfad, jede andere Abfrage und jeder Pfad `//…` oder ohne führenden `/` wirft `ValueError`. Test: `test_fence_allows_only_three_read_paths`.
- [ ] AC-2: Eine ID im Pfad, die nicht aus einer früheren Antwort stammt, wird vom Zaun abgelehnt. Test: `test_fence_rejects_id_not_from_response`.
- [ ] AC-3: `asc_lib.ALLOWED` und `asc_lib.check_path` sind durch das Skript unverändert (die Liste `ALLOWED` wird in `test_asc_crashes.py` als feste Erwartung festgeschrieben und gegen den Import verglichen; das Skript fügt ihr nichts hinzu und ruft `check_path` nicht verändert auf). Test: `test_asc_lib_allowed_unchanged`.
- [ ] AC-4: Der Lauf legt je Meldung `<id>.json` an, mit den Attributen wie geliefert, und `<id>.crash` mit dem `logText`, wenn Apple einen Bericht hat; Dateien haben Modus 0600, der Zielordner 0700. Test: `test_writes_json_and_crash_files_mode_0600`.
- [ ] AC-5: 404 beim Bericht ergibt nur `<id>.json` und keinen Fehler; ein leerer oder fehlender `logText` ebenso. Test: `test_missing_crash_log_is_not_an_error`.
- [ ] AC-6: `links.next` wird über mehrere Seiten gefolgt, alle Meldungen landen im Zielordner. Test: `test_follows_links_next_over_pages`.
- [ ] AC-7: `links.next` mit fremdem Host oder anderem Schema wird nie angefragt und bricht den Lauf mit Exit 1 ab; ein schon angefragter Pfad (Schleife) und mehr als 50 Seiten brechen ebenfalls ab. Test: `test_links_next_foreign_host_and_loop_abort`.
- [ ] AC-8: Bei 5xx, 429 und Netzfehler wird bis zu 5-mal angefragt (Wartezeit in Tests auf 0); gelingt ein späterer Versuch, ist der Lauf grün. Nach dem fünften Fehlschlag Exit 1 mit Status und Pfad. Test: `test_retries_on_5xx_429_and_network_error`.
- [ ] AC-9: 4xx außer 404 beim Bericht und außer 429 wird nicht wiederholt, sondern bricht sofort ab; die Meldung nennt Status, Pfad und Apples `code`/`title`, nie `detail`, `id`, Token oder Schlüsselpfad. Test: `test_client_error_aborts_with_code_and_title_only`.
- [ ] AC-10: Die Kennzeile im Log enthält je Meldung nur Id, Plattform und Datum; E-Mail, Kommentar, Gerätemodell, Berichtstext, Token und Schlüsselpfad aus der Schein-Antwort erscheinen weder in Standardausgabe noch in Fehlerausgabe. Test: `test_log_contains_only_id_platform_date`.
- [ ] AC-11: `safe_field` ersetzt Werte mit `::`, Zeilenumbruch, Steuerzeichen oder unzulässigen Zeichen durch `?` und kürzt auf 64 Zeichen; ein Feld mit Inhalt `::error::x` (auch nach Zeilenumbruch) erzeugt keine Logzeile, die mit `::` beginnt oder einen Umbruch enthält. Test: `test_safe_field_blocks_workflow_command_injection`.
- [ ] AC-12: Eine Datei-ID außerhalb von `[A-Za-z0-9._-]+` (z. B. `../x`, `a/b`) schreibt nie außerhalb des Zielordners und bricht den Lauf ab. Test: `test_unsafe_submission_id_is_rejected`.
- [ ] AC-13: Ohne Meldungen bleibt der Zielordner leer, das Skript meldet „keine Absturzmeldungen“ und endet mit Exit 0. Test: `test_no_submissions_exits_zero`.
- [ ] AC-14: Ohne `ASC_KEY_ID`, `ASC_ISSUER_ID` oder `ASC_KEY_PATH`, ohne Zielordner-Argument oder ohne App zur Bundle-ID endet das Skript mit Exit ≠ 0 und einer Meldung ohne Geheimnis. Test: `test_missing_config_or_app_fails_cleanly`.
- [ ] AC-15: `scripts/test_asc_crashes.py` steht in der Liste „Strukturtests (Python)“ in `.github/workflows/ci.yml` und läuft dort mit `python3 -I`. Test: `test_ci_lists_crash_test` (liest nur `ci.yml`).

### Schnitt 2 (Workflow, Schlüssel, Doku, Probelauf)
- [ ] AC-16: `asc-crashes.yml` hat als einzigen Auslöser `workflow_dispatch`, `permissions: contents: read`, die drei Secrets nur im `env`-Block (nie im Skripttext oder in `run:` direkt als `${{ secrets… }}`), und lädt ausschließlich `crashes.tar.gpg` hoch (`retention-days: 7`). Test: `test_workflow_structure_dispatch_env_only_encrypted_upload` in `scripts/test_asc_crashes_workflow.py`.
- [ ] AC-17: Der Schritt entpackt `ASC_KEY_P8` wie `testflight.yml` (Klartext mit `BEGIN PRIVATE KEY` oder Base64), `chmod 600`, `umask 077`, und ein `trap … EXIT` löscht Schlüssel, Klartextordner und Klartext-Tar. Test: `test_workflow_unpacks_key_and_traps_cleanup`.
- [ ] AC-18: Ist der Zielordner leer, legt der Lauf kein Artefakt an und schreibt „keine Absturzmeldungen“; sonst wird mit `gpg --recipient-file .github/crash-recipient.asc` verschlüsselt. Test: `test_workflow_skips_artifact_without_submissions`.
- [ ] AC-19: `.github/crash-recipient.asc` ist ein öffentlicher Schlüsselblock (`BEGIN PGP PUBLIC KEY BLOCK`), enthält keinen `PRIVATE KEY`-Block, und `docs/testflight-setup.md` enthält den Abschnitt „Absturzberichte abholen“ mit `gh run download` und `gpg --decrypt`. Test: `test_recipient_is_public_key_and_docs_section_exists`.
- [ ] AC-20 (Nachweis, Probelauf): `gh workflow run asc-crashes.yml` auf `main` endet grün. Entweder liegt ein Artefakt `crashes` vor, das per `gh run download <id> -n crashes` abrufbar und mit dem lokalen geheimen Schlüssel entschlüsselbar ist (`gpg --decrypt`, `tar -x` im Scratchpad; Inhalt wird nur gezählt, nie ins Log oder in den Chat geschrieben), oder das Protokoll sagt „keine Absturzmeldungen“. Beleg: Lauf-ID und Zählung unter `docs/artifacts/feat-242-testflight-crashes/`. Test: Nachweis-Lauf, kein automatischer Test.
- [ ] AC-21 (Nachweis, Entschlüsselungsweg): Weil es noch keine Meldung geben kann, wird der Weg Verschlüsseln → Hochladen → Herunterladen → Entschlüsseln einmal mit einer erzeugten Testdatei (ohne Testerdaten) im Runner belegt; die entschlüsselte Datei ist byteidentisch mit der Eingabe (Prüfsumme). Beleg: Lauf-ID und Prüfsummen unter `docs/artifacts/feat-242-testflight-crashes/`. Test: Nachweis-Lauf, kein automatischer Test.
- [ ] AC-22 (Nachweis, Rolle): Antwortet Apple im Probelauf mit 403 oder einem anderen Rollenfehler, steht im Protokoll nur Status, Pfad und `code`/`title`; der Lauf ist dann rot und die Rolle des Schlüssels ist ein Thema für Henning (kein stilles Überspringen). Test: Nachweis-Lauf; die Fehlermeldung selbst deckt AC-9 ab.

## Tests
Schnitt 1: `scripts/test_asc_crashes.py` (AC-1 bis AC-15), Unterprozess gegen lokalen Schein-ASC auf 127.0.0.1 und Einzelfunktionen über die `send`-Naht, Wartezeit und Uhr injiziert, kein Netz, keine Schlüsselabhängigkeit (der Token-Signierer wird in Tests ersetzt oder ein Wegwerfschlüssel mit `openssl` erzeugt). Schnitt 2: `scripts/test_asc_crashes_workflow.py` liest nur Repo-Dateien (AC-16 bis AC-19; steht ebenfalls in der Liste „Strukturtests (Python)“ in `ci.yml`); AC-20 bis AC-22 sind Nachweise aus echten Läufen. Zusätzlich bleiben `test_asc_scripts.py` und `test_asc_check.py` grün.

## Scope
Schnitt 1: 3 Dateien (`scripts/asc_crashes.py` ca. 130 LoC, `scripts/test_asc_crashes.py` ca. 200 LoC, `.github/workflows/ci.yml` 1 Zeile), zusammen ca. 330 LoC und damit **über** dem Limit von ±250; bewusst nicht weiter geteilt, weil Zaun, Abruf und Dateischreiben ohne Test nicht einzeln belegbar sind (das Vorbild hatte denselben Umfang, 154 + 428 Zeilen). Schnitt 2: 5 Dateien (`.github/workflows/asc-crashes.yml` ca. 50, `.github/crash-recipient.asc` ca. 15, `docs/testflight-setup.md` ca. 20, `scripts/test_asc_crashes_workflow.py` ca. 60, `.github/workflows/ci.yml` 1 Zeile für den Workflow-Strukturtest), zusammen ca. 150 LoC. Keine Änderung an `asc_lib`, `asc_check`, `asc_publish`, App-Code oder Schema. `scripts/test_testflight_workflow.py::test_ci_unchanged` schlägt bei jeder `ci.yml`-Änderung an (läuft nicht in der CI, Bestand).

## Alternativen
- **Weg a: `ALLOWED` erweitern** (Ticketwortlaut): weniger Code, aber `asc_publish` teilt die Liste und bekäme zusätzliche Pfade samt neuer Abfrageregeln; AC-10 des Zauns müsste mitwachsen. Verworfen zugunsten des eigenen Zauns wie bei `asc_check`.
- **Klartext-Artefakt:** einfacher, aber das Repo ist öffentlich, jeder mit GitHub-Konto könnte E-Mail, Kommentar und Gerät der Tester lesen. Verworfen.
- **Manueller ZIP-Download in App Store Connect:** kein Werkzeug nötig, aber Handarbeit je Absturz durch Henning, von ihm abgelehnt.
- **Modell zum Lesen der Berichte:** entfällt, hier geht es nur ums Abholen; Auswerten macht Claude danach am entschlüsselten Bericht.

## Offene Grenzen
- Rolle des Schlüssels `ASC_KEY_ID` (Restock) für `betaFeedbackCrashSubmissions` ist ungeprüft; belegt ist der Endpunkt nur bei Loose Ends. Erst der Probelauf zeigt es, ein 403 wäre ein Thema für Henning.
- Es gibt vermutlich noch keine Meldungen: AC-20 kann dann nur „keine Absturzmeldungen“ belegen, den Entschlüsselungsweg belegt AC-21 mit einer Testdatei. Das Verhalten bei echten Meldungen ist nicht gegen eine echte Apple-Antwort aus Restock geprüft, nur gegen Schein-Antworten nach dem Vorbild.
- Das Chiffrat liegt 7 Tage im Artefaktspeicher des öffentlichen Repos; wer den geheimen Schlüssel nicht hat, kann es nicht lesen, es ist aber herunterladbar. Der geheime Schlüssel liegt nur auf Hennings Mac (ohne Passphrase).
- Der Schlüssel heißt „Loose Ends Crash Intake“ (kosmetisch; Umbenennen würde ihn ändern). Ein Schlüsselverlust macht alte Chiffrate unlesbar.
- Meldungen werden bei jedem Lauf vollständig neu abgeholt, es gibt keinen Merker „schon gesehen“.
- Schnitt 1 ist allein nicht ausgeliefert nutzbar; ohne Schnitt 2 gibt es keinen Handlauf in der CI.
- Nichts auf Hennings Geräten geprüft; der Lauf berührt keine Geräte.
