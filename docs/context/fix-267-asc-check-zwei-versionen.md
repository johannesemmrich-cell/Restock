# Context: fix-267-asc-check-zwei-versionen

## Request Summary
Apple hat 1.0.1 (Build 40) am 2026-11-09 mit 2.1(b) abgelehnt (Kauffehler auf dem iPad). Um zu klären, ob die Käufe angehängt sind, Build 41 hochgeladen ist und die Vereinbarung für bezahlte Apps gilt, muss `scripts/asc_check.py` den Stand der Version 1.0.1 lesen können. Heute bricht es mit `appInfo: 2 Treffer statt genau 1` ab.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_check.py` | `context()` (Z. 138–150) liest genau die Version „1.0“ (`VERSION_QUERY`) und wählt das appInfo nur über `state == PREPARE_FOR_SUBMISSION`, sonst `one(infos)`. Mit zweitem appInfo (live 1.0 + Eintrag zu 1.0.1 in anderem Zustand) bricht `one()` ab. Eigener Lese-Zaun `FENCE` (Z. 44–47). `sec_status` (Z. 395) erwartet `appVersionState == PREPARE_FOR_SUBMISSION`, was nach der Ablehnung nicht mehr gilt. |
| `scripts/asc_lib.py` | `VERSION_QUERY = "filter[versionString]=1.0&filter[platform]=IOS"` (Z. 11), Zaun `check_path` lässt Versionsabfragen nur exakt mit dieser Abfrage zu (Z. 116). Das ist der Grund, warum meine direkte Abfrage der Versionsliste abgelehnt wurde. |
| `scripts/test_asc_check.py` | Schein-Antworten (`self.version`, `self.info` mit Zustand `PREPARE_FOR_SUBMISSION`), Zauntests (Z. 406–420), Abschnitte iap, build, status, review. |
| `scripts/test_asc_scripts.py` | Tests von `asc_lib`/`asc_publish`, Zaun `VERSION_QUERY`. |
| `scripts/asc_publish.py` | schreibt nur in den Entwurf von 1.0; nicht Teil dieser Änderung. |
| `project.yml` | `MARKETING_VERSION: 1.0.1`, `CURRENT_PROJECT_VERSION: 41`. |

## Existing Patterns
- Zwei getrennte Zäune (`asc_lib.check_path` für Lesen/Schreiben von `asc_publish`, `asc_check.FENCE` nur Lesen); Pfade und Abfragen exakt, keine Weiterleitungen.
- `one(items, what)` verlangt genau einen Treffer; Fehler nennen die Anzahl.
- Tests laufen gegen Schein-Antworten ohne Netz und Schlüssel (CI-Schritt „Strukturtests (Python)“).

## Dependencies
- Upstream: App Store Connect API 4.5.1 (`/v1/apps/{id}/appStoreVersions`, `/appInfos`, `/v2/inAppPurchases`, Builds, Review-Einreichungen).
- Downstream: `docs/specs/appstore/app-store-auftritt.md`, Protokolle unter `docs/artifacts/feat-175-*`, Entscheidung zur Resubmission von 1.0.1.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (B2b/B3a/B3b: `asc_check`, Abschnitte, Zäune)
- `docs/specs/appstore/asc-fehlertext.md`

## Befund aus dem Fehlschlag (2026-11-11)
- `asc_check --section iap|build|status|review` bricht überall mit `appInfo: 2 Treffer statt genau 1` ab, weil `context()` alle Abschnitte gemeinsam lädt.
- Der Zustand der appInfos ist unbekannt; Ursache vermutlich: kein Eintrag steht mehr auf `PREPARE_FOR_SUBMISSION` (live + in Prüfung/abgelehnt), dann greift `or infos` mit zwei Einträgen.
- Das Skript kennt Version 1.0.1 gar nicht (nur 1.0), erst recht nicht deren Käufe-Zuordnung.

## Risks & Considerations
- Zaun nur um **lesende** Pfade erweitern (Versionen 1.0.1, Käufe der Version, Builds); keine Einreichungs-Endpunkte, kein Schreiben.
- Ob das Anhängen der Käufe per API geht (`/v1/subscriptionSubmissions`, `/v1/inAppPurchaseSubmissions`) ist ungeprüft und bleibt außenwirksam (nur auf Wort des PO), nicht Teil dieser Änderung.
- Stand der Vereinbarung für bezahlte Apps ist per API nicht sicher lesbar; ggf. nur in der Weboberfläche.
- Nichts darf „ok“ melden, wenn Zustände unbekannt sind (Regel aus B3b).

## Analysis

### Type
Bug (Werkzeug `asc_check`), Fortsetzung #265/#266.

### Root Cause (aus dem Code, Live-Lauf steht noch aus)
`context()` (`scripts/asc_check.py:138`) ist an zwei Stellen auf „1.0 im Entwurf“ festgenagelt:
1. Version: `VERSION_QUERY` (`asc_lib.py:11`, `filter[versionString]=1.0`) und der Zaun `FENCE` (`asc_check.py:44`) kennen nur 1.0; 1.0.1 ist nicht abfragbar.
2. appInfo: `one([… state == PREPARE_FOR_SUBMISSION] or infos)`. Steht kein appInfo mehr auf dem Entwurfszustand (1.0 live, 1.0.1 abgelehnt), greift `or infos` mit zwei Einträgen → „2 Treffer statt genau 1“. Da `context()` alle Abschnitte teilt, bricht jeder Abschnitt ab.
Zusätzlich: `sec_status` erwartet `PREPARE_FOR_SUBMISSION` (falsch nach Ablehnung), `sec_build` prüft „≥ 37“ statt der Zielnummer, `sec_iap` prüft Käufe, aber nicht deren Zuordnung zur Version.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| scripts/asc_check.py | MODIFY | `--version <x>` (Standard 1.0, rückwärtskompatibel); Version über Argument; appInfo-Wahl: Entwurf, sonst über Zustand eindeutig bestimmen, sonst Abbruch MIT Zustandsliste; `sec_status` meldet den echten Zustand je Version statt starr DRAFT; neuer Abschnitt `submission` (lesend: Käufe der Version / Review-Zustand) |
| scripts/asc_lib.py | MODIFY | Versionsabfrage als Muster `filter[versionString]=<x.y[.z]>&filter[platform]=IOS` statt Festtext (nur Ziffern/Punkte) |
| scripts/test_asc_check.py | MODIFY | Fälle: zwei appInfos in `READY_FOR_SALE`/`REJECTED`, Version 1.0.1 abgelehnt, unbekannter Zustand ≠ ok, Zaun lehnt `versionString=1.0.1&…x` ab |
| scripts/test_asc_scripts.py | MODIFY | Zauntest für das Versionsmuster |

### Scope Assessment
- Files: 4, Estimated LoC: +140/-20, Risk: LOW–MEDIUM (nur Lesewerkzeug, aber Zaun wird gelockert)

### Technical Approach (Regelweg, kein Modell)
Zaun nur um eine Versionsnummer-Regex erweitern, weiterhin GET und feste Pfade. appInfo-Zuordnung nicht raten: bei mehreren Treffern ohne Entwurf Abbruch, der alle Zustände nennt (Regel B3b: nichts „ok“ bei Unbekanntem). Erst der Live-Lauf (Lesen, kein Gerät, nichts außenwirksam) zeigt die echten Zustände; danach Spec.
Alternative: das Werkzeug nicht erweitern, sondern den Stand einmalig per Weboberfläche lesen — schneller, aber nicht wiederholbar und kippt die Entscheidung „Stand prüfbar machen“ (#267 Ziel 1). Verworfen.

### Dependencies
`asc_publish.py` teilt `asc_lib.check_path`; das gelockerte Muster gilt auch dort (nur GET). Schreibpfade unverändert.

### Open Questions
- [ ] Live-Lauf braucht `ASC_KEY_ID/ISSUER_ID/KEY_PATH` (im Schlüsselbund/`~/.appstoreconnect`, in dieser Sitzung nicht gesetzt) – in Phase 3 aus dem vorhandenen Ablauf beziehen.
- [ ] Käufe an eine Version anhängen per API ungeprüft; bleibt außenwirksam, nur auf Wort des PO, nicht Teil dieser Änderung.
- [ ] Paid-Apps-Vereinbarung per API nicht lesbar (Weboberfläche).
