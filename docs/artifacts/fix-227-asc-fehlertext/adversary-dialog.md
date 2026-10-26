# Adversary-Dialog: fix-227-asc-fehlertext

Spec: `docs/specs/appstore/asc-fehlertext.md` · Prüfer: implementation-validator · Orchestrator: Hauptkontext

### Runde 1

Angriff mit Wegwerf-Proben auf `apple_error_suffix` (100000-stellige Zahl, 100000-fach verschachteltes JSON, ungültiges UTF-8, `None`, `5`, `bytearray`, `NaN`, BOM, Nicht-String-Werte, ESC, `\r\n`): keine Ausnahme. Geheimnis-Probe mit `detail`/`id`/`source` gleich Token und Schlüsselpfad: Meldung `HTTP 409 bei GET /v1/apps — C: T`, nichts davon enthalten. `urllib_send`: Deckel 64 KiB, Lesefehler gibt `b""`, Weiterleitungen nicht verfolgt. Zaun und `fetch_privacy` unverändert.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_lib.py
  Description: Der Filter `[\x00-\x1f\x7f-\x9f]` lässt Lone-Surrogates (U+D800..DFFF), U+2028/2029 und Bidi-Zeichen (U+202E) durch. Ein Lone Surrogate im Zusatz lässt `print` in `asc_check.py` bei strengem UTF-8 mit UnicodeEncodeError abbrechen.
  Evidence: `s.encode('utf-8','strict')` wirft; `ascii()` zeigt U+2028 und U+202E erhalten.
  Remediation: Zeichen der Kategorien Cc/Cf/Cs/Zl/Zp entfernen, Test ergänzen.

### Runde 2

F001 unabhängig bestätigt und eingeordnet: Weg nach stderr (`asc_publish`) sicher, Weg nach stdout (`asc_check`) nicht. Realer Auslöser wäre ein Apple-Titel mit Lone-Surrogate-Escape, unwahrscheinlich, aber ohne Spec-Verstoß nicht auszuschließen. Kürzung auf 80 und Limit von 3 Einträgen über Tests und Code bestätigt. Verdict Runde 1/2: AMBIGUOUS. Entscheidung des Orchestrators: Fix per TDD (neuer Test rot, dann Filter über `unicodedata.category` in {Cc, Cf, Cs, Zl, Zp}).

Confirmation:
  AC: AC-1 bis AC-11 funktional bewiesen
  Code reference: scripts/asc_lib.py
  Code reference: scripts/asc_check.py
  Status: CONFIRMED (bis auf F001)

### Runde 3

Nachprüfung nach dem Fix. Zehn Sonderzeichen (U+D800, U+DFFF, U+2028, U+2029, U+202E, U+200B, U+FEFF, U+0085, U+0000, U+001B) je in `code` und `title`: Ergebnis exakt `" — AB: TU"`, `.encode('utf-8')` wirft nicht. Kürzung greift nach dem Filter (100 × U+200B + 100 × `a` ergibt 80 × `a`). Umlaute und Akzente bleiben erhalten. Tests: 25 + 42 + 10 = 77 bestanden, 0 fehlgeschlagen. Scope: nur `asc_lib.py`, `asc_check.py`, `test_asc_scripts.py` und das Artefaktverzeichnis geändert.

Confirmation:
  AC: AC-1, AC-3, AC-4 (inkl. F001-Filter), AC-5
  Code reference: scripts/asc_lib.py
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-6, AC-7, AC-8, AC-11
  Code reference: scripts/asc_lib.py
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10
  Code reference: scripts/asc_check.py
  Status: CONFIRMED

Confirmation:
  AC: Testabdeckung F001 (`test_error_suffix_strips_surrogates_and_format_chars`)
  Code reference: scripts/test_asc_scripts.py
  Status: CONFIRMED

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:9fda121e9e646b573b547520bb0ba87bf85f2a13eb502ec76bb069ebbd71c7e3  scripts/asc_check.py
- sha256:f53c47452e48d27105125541ff5861abc09d37e2e12fe24f3b4f068e7c232d40  scripts/asc_lib.py
- sha256:e96392d32692bfb994dae3f0d32b1307f0fa9ad098a3bd7b92b561ffe797b7d8  scripts/test_asc_scripts.py

## Prüfbasis

- base: 33ee24b0bd3bd87fcc0ba3b527dda6254acaa7db
- blob:45d680ea7c443ebe3944fbf1254b38010949cd50  scripts/asc_check.py
- blob:dc2b8085559b45a346b63f8d8aca498218706346  scripts/asc_lib.py
- blob:c044fee9d31261951f079a2d436f093104e62646  scripts/test_asc_scripts.py
