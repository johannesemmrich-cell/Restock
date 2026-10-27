---
entity_id: asc-publish-reihenfolge
type: bugfix
created: 2026-10-27
updated: 2026-10-27
status: draft
---

# Spec: asc_publish legt App-Angaben vor den Produktseiten an (Issue #229)

Workflow: `fix-229-asc-reihenfolge` · Folge aus #175 B3 · Kontext: `docs/context/fix-229-asc-reihenfolge.md`

## Purpose
`asc_publish.py` soll neue Sprachen in App Store Connect so anlegen, dass Apple nicht mit DUPLICATE_NAME ablehnt: App-Angaben (Name) zuerst, Produktseite danach.

## Source
- `scripts/asc_publish.py`, Funktion `build_plan` (Reihenfolge der Plan-Liste), ausgeführt von `main`
- Test: `scripts/test_asc_scripts.py`

## Dependencies
| Abhängigkeit | Art |
|--------------|-----|
| `scripts/asc_lib.py` (`api`, Pfad-Erlaubnisliste) | unverändert, beide Ressourcen sind zugelassen |
| `docs/specs/appstore/app-store-auftritt.md` (B2a, Ablauf) | wird um die Reihenfolge ergänzt |
| `docs/specs/appstore/asc-fehlertext.md` (#227) | macht Apples Ursache im Protokoll sichtbar |

## Problem
Der Eintragungslauf 2 und 3 (`docs/artifacts/feat-175-b3-eintragen/asc-publish-apply-2.txt`, `-3.txt`) brach beim ersten
`POST /v1/appStoreVersionLocalizations` (en-US) mit HTTP 409 `STATE_ERROR.DUPLICATE_NAME.DIFFERENT_ACCOUNT: Cannot add
localization due to app name` ab, auch nach dem Wechsel des englischen Namens auf „Restock Shopping List“. `build_plan` in
`scripts/asc_publish.py` hängt zuerst die Produktseiten (`appStoreVersionLocalizations`), dann die App-Angaben
(`appInfoLocalizations`, enthalten den Namen) an; `main` führt den Plan in dieser Reihenfolge aus.

## Hypothese (nicht von Apple bestätigt)
Legt man eine neue Sprache über die Version an, legt Apple die App-Angaben der Sprache mit dem Primärnamen („Restock“) mit an,
und den hat in en-US ein anderes Konto belegt. Quellen: Apple-Forum 838394 (Sprache über „App-Informationen“ klappt, über die
Version nicht), 662737 (lokalisierter Name muss sich vom Primärnamen unterscheiden, wenn dieser fremd belegt ist), 844943 (derselbe
Fehlertext, keine offizielle Lösung). Belegt ist nur der Fehler und die bisherige Reihenfolge.

## Lösung (Regelweg: Reihenfolge der Plan-Liste)
- `build_plan` gibt zuerst den Plan für `appInfoLocalizations`, danach den für `appStoreVersionLocalizations` zurück.
  Innerhalb einer Ressource bleibt die Reihenfolge (Sprachen in Lesereihenfolge von `texts`).
- Weil Trockenlauf-Ausgabe und `--apply` denselben Plan benutzen, gilt die Reihenfolge für beide.
- Keine Änderung an `plan_for`, `asc_lib`, der Pfad-Erlaubnisliste, `asc_check` oder den Store-Texten.

## Acceptance Criteria
- [ ] AC-1: In `--apply` mit leeren Sprachlisten (beide Ressourcen müssen angelegt werden) steht in der Aufrufreihenfolge der Schreibaufrufe (`FakeASC.writes`) jeder Schreibaufruf auf `appInfoLocalizations` vor dem ersten Schreibaufruf auf `appStoreVersionLocalizations`. Test: `test_info_localizations_written_before_version_localizations`.
- [ ] AC-2: Dasselbe gilt für gemischte Fälle (eine Sprache nur als PATCH, eine fehlt als POST): alle `appInfoLocalizations`-Aufrufe (PATCH und POST) kommen vor allen `appStoreVersionLocalizations`-Aufrufen. Test: gleicher Test, zweiter Fall.
- [ ] AC-3: Die Trockenlauf-Ausgabe nennt die Zeilen der App-Angaben vor denen der Produktseiten, und der Trockenlauf schreibt weiter nichts. Test: `test_dry_run_lists_info_before_version`.
- [ ] AC-4: Bricht ein Schreibaufruf der Produktseiten mit 409 ab, sind die App-Angaben bereits geschrieben und ein zweiter Lauf schreibt nur den Rest (Idempotenz bleibt). Test: `test_second_run_after_version_failure_writes_only_rest`.
- [ ] AC-5: Alle bestehenden Tests in `scripts/test_asc_scripts.py` (inkl. `test_patch_existing_post_missing`, `test_idempotent`, Geheimnistests) bleiben grün.

## Definition of Done
- [ ] Alle ACs erfüllt, `scripts/test_asc_scripts.py` und `scripts/test_asc_check.py` grün
- [ ] Ablauf Punkt 3 in `app-store-auftritt.md` nennt die Reihenfolge
- [ ] Kein Schreibaufruf gegen Apple in diesem Durchgang

## Test Plan
Schein-Antworten über `FakeASC` und `run(fake, "--apply")`, kein Netz, kein Schlüssel; laufen im CI-Schritt „Strukturtests (Python)“.
AC-4 erzeugt den Abbruch mit einer Variante des Fakes, die den ersten Schreibaufruf auf `appStoreVersionLocalizations` mit 409 beantwortet.

## Scope
3 Dateien: `scripts/asc_publish.py` (≈ 3 Zeilen), `scripts/test_asc_scripts.py` (≈ 40 Zeilen),
`docs/specs/appstore/app-store-auftritt.md` (Ablauf Punkt 3 um den Satz zur Reihenfolge ergänzen, Verweis auf diese Spec).

## Alternativen
1. App-Angaben einmalig im Browser anlegen, Werkzeug unverändert: nicht wiederholbar, Chrome-Verbindung derzeit nicht verfügbar.
2. Englisch für 1.0 streichen: kippt die zweisprachigen Store-Texte (Alternative 10 der Haupt-Spec).
Verworfen für diesen Durchgang; die Reihenfolge ist klein, wiederholbar und reversibel.

## Offene Grenzen
- Die Hypothese ist unbestätigt. Hilft die Reihenfolge nicht, zeigt der nächste Eintragungslauf Apples Ursache dank #227 erneut; der Test belegt nur die Reihenfolge, nicht die Wirkung bei Apple.
- Mischstand möglich: Scheitert die Produktseite nach den App-Angaben, bleiben die App-Angaben stehen; der Lauf ist idempotent.
- Der Eintragungslauf nach der Korrektur ist ein außenwirksamer Schritt und folgt in B3 nur auf Hennings Wort.

## Changelog
- 2026-10-27: Erstfassung (Issue #229).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Vertauschung der Reihenfolge in einer Plan-Liste eines Hilfsskripts; keine neue Struktur, keine Abhängigkeit.

## Freigabe
- [ ] Approved
