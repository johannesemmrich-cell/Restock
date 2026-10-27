# Context: fix-229-asc-reihenfolge

## Request Summary
Issue #229: `asc_publish --apply` scheitert beim ersten `POST /v1/appStoreVersionLocalizations` (en-US) mit HTTP 409
`STATE_ERROR.DUPLICATE_NAME.DIFFERENT_ACCOUNT: Cannot add localization due to app name` (Belege
`docs/artifacts/feat-175-b3-eintragen/asc-publish-apply-2.txt` mit altem Namen „Restock“, `-3.txt` mit „Restock Shopping List“;
beide Läufe schrieben nichts neu). Der Name „Restock“ ist in en-US bei einem fremden Konto vergeben. Der Plan legt die Produktseite
(Version) vor den App-Angaben (enthalten den Namen) an.

## Hat es bisher funktioniert?
Nie: Es war der erste echte Schreiblauf gegen App Store Connect (B3). Der Lauf davor (`asc-publish-apply.txt`) brach beim ersten
POST mit 409 ohne Ursache ab; #227 machte Apples Fehlercode sichtbar.

## Recherche (Quellen)
- Apple-Forum 838394 („Can't add a localization to an app in App Store Connect“): Anlegen einer Sprache über die Version scheitert,
  über „App Information“ klappt es.
- Apple-Forum 662737: der lokalisierte App-Name muss sich vom Primärnamen unterscheiden, wenn der Name im Konto/fremd belegt ist.
- Der exakte Fehlertext kommt in Apple-Forum 844943 (umbenannte, gelöschte App) vor, ohne offizielle Lösung.
- Nicht bestätigt: ob Apple beim Anlegen der Versions-Lokalisierung die App-Angaben mit dem Primärnamen mit anlegt. Das ist die Hypothese
  dieses Durchgangs, nicht belegt.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_publish.py:55-59` | `build_plan` hängt zuerst `appStoreVersionLocalizations`, dann `appInfoLocalizations` an; `main` führt den Plan in dieser Reihenfolge aus (Zeile 93) |
| `scripts/test_asc_scripts.py:155-172` | `test_patch_existing_post_missing` sortiert die Schreibaufrufe vor dem Vergleich, ist also reihenfolgeunabhängig |
| `scripts/test_asc_scripts.py` `FakeASC` (Zeile 50ff) | Schein-API mit `writes`-Liste in Aufrufreihenfolge |
| `docs/specs/appstore/app-store-auftritt.md` (B2a, Ablauf Punkt 3/4) | beschreibt den Plan je Sprache; Reihenfolge nicht festgelegt |
| `docs/appstore/en.md` | `## name` = `Restock Shopping List` (PO 2026-10-27) |

## Existing Patterns
- `plan_for` ist je Ressource gleich aufgebaut; `build_plan` setzt nur die Reihenfolge zusammen.
- Tests über `FakeASC` und `run(fake, "--apply")`; AC-Nummern in Kommentaren.
- Skripte zählen im LoC-Gate als Produktivcode.

## Dependencies
- Upstream: `asc_lib.api` (Pfad-Erlaubnisliste), `asc_lib.parse_texts`.
- Downstream: B3 (`feat-175-b3-eintragen`): der Eintragungslauf nach der Korrektur; `asc_check` liest nur und ist nicht betroffen.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md`, Abschnitt „Durchgang B2a“ (Ablauf von `asc_publish.py`).

## Risks & Considerations
- Die Hypothese ist unbestätigt. Hilft die Reihenfolge nicht, zeigt der nächste Lauf wieder Apples Ursache (dank #227); der Test belegt nur die Reihenfolge.
- Ein Mischstand ist möglich: Wird die App-Info zuerst angelegt und die Produktseite scheitert, bleibt die App-Info stehen. Der Lauf ist idempotent.
- Keine Änderung an `asc_lib` oder an der Pfad-Erlaubnisliste nötig (beide Ressourcen sind schon zugelassen).

## Analysis

### Type
Bug (Reihenfolge im Schreibplan), Summe 2.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_publish.py` | MODIFY | `build_plan`: App-Angaben vor Produktseite (≈ 3 Zeilen) |
| `scripts/test_asc_scripts.py` | MODIFY | neuer Test: in `--apply` kommt jeder `appInfoLocalizations`-Schreibaufruf vor dem ersten `appStoreVersionLocalizations`-Schreibaufruf, auch im Plan der Trockenlaufausgabe (≈ 15 Zeilen) |
| `docs/specs/appstore/app-store-auftritt.md` oder neue kleine Spec | MODIFY/CREATE | Ablauf Punkt 3: Reihenfolge festlegen |

### Root Cause
Vermutlich: Apple legt mit einer neuen Versions-Lokalisierung die App-Angaben der Sprache mit dem Primärnamen an. Belegt ist nur der
Fehler (Protokolle) und `build_plan` (Reihenfolge Version, dann Info); die Verknüpfung dazwischen ist Forenwissen.

### Alternativen
1. Reihenfolge im Werkzeug ändern (empfohlen, klein, wiederholbar).
2. App-Angaben einmalig im Browser anlegen, Werkzeug unverändert (nicht wiederholbar, Chrome-Verbindung steht derzeit nicht).
3. Englisch für 1.0 streichen (kippt zweisprachige Store-Texte, Spec-Alternative 10).

### Erwarteter Umfang
2 Dateien Code + 1 Spec, ca. 20 Zeilen, innerhalb der Scoping-Limits.
