# Spec: ASC-Werkzeuge zeigen Apples Fehlercode und -titel (Issue #227)

Workflow: `fix-227-asc-fehlertext` · Folge aus #175 B3 · Kontext: `docs/context/fix-227-asc-fehlertext.md`

## Problem
`scripts/asc_publish.py --apply` brach mit „HTTP 409 bei POST /v1/appStoreVersionLocalizations" ab. Die Ursache blieb
unsichtbar: `urllib_send` verwirft bei einem HTTP-Fehler den Antwortkörper (`return e.code, b""`), `asc_lib.api` und
`asc_check.Reader.get` nennen nur Status und Pfad. Apples JSON:API-Fehlerantwort (`{"errors":[{"status","code","title",
"detail","id","source"}]}`) trägt aber die Ursache in `code` und `title`.

## Lösung (Regelweg, kein Modell: zwei JSON-Felder auslesen)
- `urllib_send` (`scripts/asc_lib.py`) gibt bei `HTTPError` den Fehlerkörper zurück, höchstens 64 KiB gelesen
  (`e.read(65536)`), bei Lesefehler `b""`. Verhalten bei 2xx und das Nichtverfolgen von Weiterleitungen bleiben.
- Neue reine Funktion `apple_error_suffix(raw)` in `asc_lib`: liefert einen Zusatz wie
  `" — STATE_ERROR: Titel; ENTITY_ERROR.ATTRIBUTE.INVALID: Titel2"`, sonst `""`.
- `asc_lib.api` und `asc_check.Reader.get` hängen den Zusatz hinten an die bestehende Meldung
  `HTTP {status} bei {method} {path}` an. `HttpError` behält `.status` und nimmt den Zusatz als dritten, optionalen
  Parameter (`HttpError(status, path, suffix="")`).
- Ausgegeben werden nie `detail`, `id`, `source`, Header, Token oder Schlüsselpfad.

## Acceptance Criteria
- [ ] AC-1: `apple_error_suffix` liest aus `{"errors":[{"code":"A","title":"B"}]}` den Zusatz `" — A: B"`; zwei Fehler werden mit `"; "` verbunden. Test: `test_error_suffix_reads_code_and_title`.
- [ ] AC-2: Ungültiges JSON, kein Objekt, fehlendes oder nicht-listenartiges `errors`, Einträge, die keine Objekte sind, leerer Körper `b""`, Nicht-Bytes (`None`) ergeben `""` und lösen nie eine Ausnahme aus. Test: `test_error_suffix_invalid_input_is_empty`.
- [ ] AC-3: Höchstens 3 Fehler gehen in den Zusatz; ein vierter erscheint nicht. Test: `test_error_suffix_max_three_errors`.
- [ ] AC-4: `code` und `title` werden je auf 80 Zeichen gekürzt; Steuerzeichen und Zeilenumbrüche (inkl. `\r`, `\n`, `\t`, ESC) werden entfernt. Ein Eintrag ohne `code` und `title` als Strings (fehlend, Zahl, Liste) entfällt; fehlt nur eines, steht das andere allein ohne Doppelpunkt. Test: `test_error_suffix_truncates_and_strips_control_chars`.
- [ ] AC-5: `detail`, `id` und `source` erscheinen nie im Zusatz, auch wenn sie Token-ähnliche Strings oder den Schlüsselpfad enthalten. Test: `test_error_suffix_never_contains_detail_id_source`.
- [ ] AC-6: `asc_lib.api` mit Schein-Antwort `(409, <errors-JSON>)` über die `send`-Naht wirft `RuntimeError` mit Präfix `HTTP 409 bei POST /v1/appStoreVersionLocalizations` und dem Zusatz aus AC-1; die Meldung enthält weder das Bearer-Token noch `detail`. Test: `test_api_error_message_includes_apple_code_and_title`.
- [ ] AC-7: `asc_lib.api` mit Fehlerkörper ohne gültiges JSON meldet exakt wie bisher `HTTP {status} bei {method} {path}` ohne Zusatz; das gilt auch für 3xx (z. B. `(302, b"")`, bestehender Test `test_api_turns_redirect_status_into_error` bleibt grün); trägt ein 3xx-Körper `errors`, kommt der Zusatz über dieselbe Funktion. Test: `test_api_error_without_json_keeps_old_message`.
- [ ] AC-8: `urllib_send` liefert bei einem HTTP-Fehler den Körper (lokaler Test-Server, Status 409 mit errors-JSON), gelesen höchstens 64 KiB (Körper von 200 KiB ergibt `len(raw) <= 65536`); bei 302 weiter Status 302 und kein Folgeaufruf (`test_urllib_send_never_follows_redirect` bleibt grün). Test: `test_urllib_send_returns_error_body_capped`.
- [ ] AC-9: `asc_check.Reader.get` wirft bei `(409, <errors-JSON>)` einen `HttpError` mit `.status == 409` und Meldung `HTTP 409 bei GET {path}` plus Zusatz; Pfad ohne Query wie bisher. Test: `test_reader_get_error_includes_apple_code_and_title`.
- [ ] AC-10: Die bestehenden Meldungen in `test_asc_check.py` (`Fehler appinfo: HTTP {status} bei GET …`, Zeilen ~594, 608, 615) bleiben mit Schein-Antworten ohne Fehlerkörper unverändert; `fetch_privacy` bleibt unverändert und wertet nur den Status. Test: bestehende Tests plus `test_fetch_privacy_ignores_error_body`.
- [ ] AC-11: Geheimnistests bleiben grün (`test_no_secrets_in_output_or_errors` in beiden Testdateien); zusätzlich enthält eine Fehlerantwort mit `detail`/`id` = Token und Schlüsselpfad in keiner Meldung (`str(exception)`) und keiner Ausgabe diese Strings. Test: `test_error_with_secret_like_detail_never_leaks` (in `test_asc_scripts.py`, deckt `api` und `Reader.get` ab).

## Tests
Schein-Antworten über die `send`-Naht, kein Netz, kein Schlüssel: `scripts/test_asc_scripts.py` (AC-1 bis AC-8, AC-11), `scripts/test_asc_check.py` (AC-9, AC-10). Beide laufen im CI-Schritt „Strukturtests (Python)". AC-8 nutzt wie `test_urllib_send_never_follows_redirect` einen lokalen Server auf 127.0.0.1.

## Scope
4 Dateien (`scripts/asc_lib.py`, `scripts/asc_check.py`, `scripts/test_asc_scripts.py`, `scripts/test_asc_check.py`), ca. 50–70 LoC. Keine Änderung an Zaun (`check_path`, `ALLOWED`), Token, Pfadlisten, App-Code oder `fetch_privacy`.

## Alternative (verworfen)
Fehlertext nur mit `--verbose`: im Normalfall wäre der Fehler wieder blind, der Anlass (409 ohne Ursache) ließe sich nicht beim ersten Lauf lesen. Ein Modell zum Deuten der Antwort entfällt, die zwei Felder sind deterministisch lesbar.

## Offene Grenzen
- Nicht gegen eine echte Apple-Antwort geprüft; das Format stützt sich auf die JSON:API-Beschreibung und die ASC-OpenAPI (4.5.1). Folgeschritt: #175 B3 Schritt 3 erneut, dort zeigt sich der 409-Text.
- `code`/`title` sind Apples Texte; sie könnten theoretisch Eingaben wiederholen. Gemildert durch Kürzung auf 80 Zeichen, höchstens 3 Fehler, Steuerzeichen entfernt; `detail` bleibt draußen.
- Körper über 64 KiB werden abgeschnitten, dann ist das JSON meist ungültig und der Zusatz leer (wie bisher).
- `fetch_privacy` zeigt weiterhin nur den Status.
