# Context: fix-227-asc-fehlertext

## Request Summary
Issue #227 (Folge aus #175 B3): Bei HTTP-Fehlern sollen die ASC-Werkzeuge Apples `code` und `title` aus der Fehlerantwort
anzeigen. Anlass: `asc_publish --apply` brach mit „HTTP 409 bei POST /v1/appStoreVersionLocalizations" ab, die Ursache
blieb unsichtbar, weil das Werkzeug nur Status und Pfad nennt.

## Befund (Code gelesen)
- `scripts/asc_lib.py:71-78` `urllib_send`: bei `HTTPError` wird der Antwortkörper verworfen (`return e.code, b""`).
  Die Information geht also schon vor `api()` verloren, nicht erst bei der Meldung.
- `scripts/asc_lib.py:103-104` `api()`: `raise RuntimeError(f"HTTP {status} bei {method} {path}")`.
- `scripts/asc_check.py:72-89` `HttpError(status, path)` und `Reader.get`: gleiche Form, nur GET; nutzt `urllib_send` aus `asc_lib`.
- `asc_check.fetch_privacy` nutzt ebenfalls `urllib_send` (Datenschutzseite, nur Status ausgewertet).
- Apples Fehlerformat (JSON:API): `{"errors":[{"status","code","title","detail","id","source"}]}`.
  `detail` kann eingesendete Werte (Texte, Namen) wiederholen, `id` ist eine Anfragekennung: beides bleibt draußen.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_lib.py` | `urllib_send` verwirft Körper; `api()` baut die Meldung |
| `scripts/asc_check.py` | `HttpError`, `Reader.get`, eigene Meldung |
| `scripts/test_asc_scripts.py` | Tests Zaun, Weiterleitung (`test_urllib_send_never_follows_redirect`), Geheimnistest `test_no_secrets_in_output_or_errors` |
| `scripts/test_asc_check.py` | Tests mit Meldungen „HTTP {status} bei GET …" (Zeilen 594, 608, 615) müssen weiter passen |

## Existing Patterns
- Fehlermeldungen nennen nur Status und Pfad, nie Token, Schlüsselpfad oder Antworttext (AC-10g, AC-20e).
- Tests mit Schein-Antworten (`send`-Naht), kein Netz.

## Risks & Considerations
- Sicherheitszaun: nur `code` und `title` ausgeben, begrenzt in Länge, Steuerzeichen entfernt; Antwort ohne gültiges JSON → wie bisher nur Status und Pfad.
- Geheimnistest muss grün bleiben (auch wenn eine Antwort Token-ähnliche Strings enthält, werden nur die zwei Felder gelesen).
- Bestehende Meldungstexte (Präfix „HTTP {status} bei {method} {path}") bleiben, der Zusatz hängt hinten an.

## Analysis

### Type
Feature (Werkzeug-Verbesserung, Regelweg: reines Auslesen zweier JSON-Felder, kein Modell nötig).

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| `scripts/asc_lib.py` | MODIFY | `urllib_send` gibt Fehlerkörper zurück (begrenzt); neue Funktion `apple_error_suffix(raw)`; `api()` hängt sie an |
| `scripts/asc_check.py` | MODIFY | `Reader.get` hängt dieselbe Zusatzangabe an `HttpError` |
| `scripts/test_asc_scripts.py` | MODIFY | Tests für Auslesen, Kürzen, kein `detail`, Geheimnisse |
| `scripts/test_asc_check.py` | MODIFY | Test für den Lesepfad |

### Scope Assessment
4 Dateien, ca. 50–70 LoC; Risiko MEDIUM (Sicherheitszaun).

### Alternative
Fehlertext nur mit `--verbose` zeigen: verworfen, im Normalfall wieder blind.

### Open Questions
- Keine.
