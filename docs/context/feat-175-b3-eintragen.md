# Context: feat-175-b3-eintragen

## Request Summary
Issue #175, Durchgang B3 (Betrieb): Version 1.0 in App Store Connect nach der freigegebenen Spec ausfüllen und gegenlesen.
Kein Quellcode; jeder außenwirksame Schritt einzeln auf Hennings ausdrückliches Wort. Der Vorgänger-Workflow
`feat-175-b3-asc-betrieb` (B3b, PR #226) ist gemergt; dieser Workflow ist der Betrieb selbst.

## Stand (Lesetrockenlauf 4, 2026-10-25T20:44Z, Commit f3db445)
Protokoll: `docs/artifacts/feat-175-b3-eintragen/asc-check-lauf-4-2026-10-25.txt` (nur GET). Gleicher Befund wie Lauf 3:
- ok: Name de-DE, Datenschutz-URL HTTP 200, `appPriceSchedule` vorhanden, Status `PREPARE_FOR_SUBMISSION`.
- Leer/fehlend: Beschreibung, Schlüsselwörter, Werbetext, Support-URL, Untertitel, Datenschutz-URL (de-DE); komplette Lokalisierung en-US;
  Kategorien (primär/sekundär), Content Rights, Altersfreigabe (alle 24 Felder), Review-Kontakt, Screenshots (0), Build-Zuordnung.
- Basisland USA statt DEU, App-Preis und Verfügbarkeit nicht eingerichtet.
- Käufe: Abo-Gruppe „Restock Pro“, `lifetime` (IAP), `monthly`, `yearly` (SUB) fehlen.
- Datenschutzseite: alter Text, beide Sprachabschnitte fehlen (Dritter pflegt sie).
- AC-14 App-Privacy-Fragebogen: per API nicht lesbar, Beleg-Screenshot.

## Zugang
Key-ID `K928C9Z9P2`, Issuer-ID `6c350cda-a185-45ac-a852-70e84119b6f1`, Schlüssel `/Users/hem/Developer/AuthKey_K928C9Z9P2.p8`
(Inhalt nie lesen). Aufruf über die Umgebung `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.

## Ablauf laut Spec (Abschnitt „Durchgang B3“), Wort je Schritt
1. Lesetrockenlauf – erledigt (Lauf 4).
2. `asc_publish` Trockenlauf (lesend, Plan sichten).
3. `asc_publish --apply` – Wort nötig (Texte de-DE/en-US in den Entwurf).
4. Browser: Basisland DEU/Preis 0/Verfügbarkeit, Kategorien SHOPPING + PRODUCTIVITY, Altersfreigabe, Content Rights, Review-Kontakt,
   App Privacy, Abo-Gruppe „Restock Pro“, Käufe `com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}` zu 1,99/8,99/14,99 –
   je Schritt Wort; Kauf-Kennungen sind unumkehrbar (`SmartCart/Services/PremiumService.swift:124-126` vorher gegenprüfen).
5. Screenshots 1320×2868 aus dem Simulator, Vorschau samt Bildunterschriften de/en, dann Upload – Wort.
6. Build 37 per `testflight.yml` (`build_number=37`), „Was testen?“-Text vorher zeigen – Wort.
7. Schlusslauf `asc_check --all` als `asc-readback.txt`.

## Related Files
`scripts/asc_check.py`, `scripts/asc_publish.py`, `scripts/asc_lib.py`, `docs/appstore/{de,en,datenschutz}.md`,
`docs/specs/appstore/app-store-auftritt.md`, `.github/workflows/testflight.yml`, `docs/context/feat-175-b3-asc-betrieb.md` (Vorgänger).

## Existing Patterns
Trockenlauf vor `--apply`; Gegenlesen als Beleg mit Zeitstempel und Commit (erst committen, dann Echtlauf);
Vorschau-Regel für Sichtbares; Simulator-Sperren bei Screenshots; OpenAPI 4.5.1 als Referenz.

## Risks & Considerations
- Käufe anlegen ist unumkehrbar (Produktkennungen).
- Name/Untertitel im Entwurf: Änderbarkeit erst im echten `--apply` sichtbar.
- Abbruch mitten in `--apply` hinterlässt Mischstand; erneuter Lauf ist idempotent.
- Blocker für den Abschluss: Datenschutzseite (Dritter), Build 37, #215 nicht Teil von B3.
- Korrekturen am Werkzeug wären Code und gehören in einen eigenen kleinen Durchgang mit Test.

## Analysis

### Type
Feature (Betriebsdurchgang, kein Quellcode). Spec: Abschnitt „Durchgang B3“ in `docs/specs/appstore/app-store-auftritt.md` (bereits freigegeben, wird in Phase 3 nur fortgeschrieben).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt` | CREATE | Schlusslauf `asc_check --all` |
| `docs/artifacts/feat-175-b3-eintragen/*` | CREATE | Läufe, Trockenlauf-Plan, Beleg-Screenshots Browserweg |
| `docs/artifacts/feat-175-app-store-auftritt/screenshots/{de,en}/*.png` | CREATE | 1320×2868 aus dem Simulator |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | Fortschreibung Stand B3 |
| Außerhalb des Repos: App Store Connect, `testflight.yml`-Lauf | – | nur auf Hennings Wort je Schritt |

### Gegenprobe Kauf-Kennungen (vor dem unumkehrbaren Anlegen)
`PremiumService.swift:124-126` und `Restock.storekit` stimmen überein: `…premium.monthly` 1,99 / `…yearly` 8,99 / `…lifetime` 14,99, Abo-Gruppe „Restock Pro“. Dazu Basisland DEU, App kostenlos (PO 2026-10-25).

### Scope Assessment
- Files: 0 Quelldateien; LoC ±0 (Belege zählen als Belegverzeichnis)
- Risk Level: MEDIUM — Kauf-Kennungen unumkehrbar, `--apply` kann Mischstand hinterlassen (idempotent wiederholbar)

### Technical Approach
Reihenfolge aus der Spec: (2) `asc_publish` Trockenlauf → (3) `--apply` → (4) Browser-Eintragungen → (5) Screenshots → (6) Build 37 → (7) Schlusslauf. Regelweg: API-Skripte und Gegenleser, kein Modell nötig. Alternative: Alles per Browser statt `asc_publish` — verworfen, weil nicht gegenlesbar/idempotent; ADR-Änderung wäre B2a. Reihenfolge-Alternative: Käufe zuletzt anlegen, weil unumkehrbar — empfohlen, nach Texten und Kategorien.

### Dependencies
Blocker: Datenschutzseite (Dritter) für AC-12/AC-19; Build 37 nicht hochgeladen (AC-17); #215 (Paywall-Rechtslinks) nicht Teil von B3. Simulator-Screenshots brauchen beide Sperren.

### Open Questions
- [ ] Wann liefert der Dritte die Datenschutzseite?
- [ ] Review-Kontaktdaten (Name, Telefon, E-Mail) — von Henning zu nennen.
