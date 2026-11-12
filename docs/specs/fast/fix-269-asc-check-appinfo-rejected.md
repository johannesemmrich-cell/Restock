# Mini-Spec: asc_check wählt bei abgelehnter Version die abgelehnte appInfo (#269)

Fortschreibung von `docs/specs/appstore/asc-check-version.md` (Punkt „appInfo-Wahl in `info_id()`“, AC-1).
Dort stand: „bleibt bewusst streng, bis die Zustandsliste des Live-Laufs eine weitere Regel begründet.“
Der Live-Lauf vom 2026-11-12 hat sie geliefert: `READY_FOR_DISTRIBUTION` (1.0 live) neben `REJECTED` (1.0.1 abgelehnt).

## Was ändert sich
- `info_id()` in `scripts/asc_check.py` bekommt eine dritte Regel vor dem Abbruch. Reihenfolge danach:
  (a) genau ein appInfo → dieses; (b) genau eines im Zustand `PREPARE_FOR_SUBMISSION` → dieses;
  **(c) neu: ist die gewählte Version (`appVersionState`) `REJECTED` und genau ein appInfo im Zustand `REJECTED`
  → dieses**; (d) sonst Abbruch mit der bisherigen Meldung samt allen Zuständen.
- Damit lesen `--section metadata` und `--section appinfo` für 1.0.1 (abgelehnt) die Texte, Kategorien und
  Altersfreigabe der abgelehnten appInfo statt abzubrechen.
- Die Regel hängt am Zustand der **Version**, nicht allein an den appInfos: Bei einer Version in anderem Zustand
  (z. B. 1.0 `READY_FOR_SALE`) bleibt `REJECTED` neben einer zweiten appInfo mehrdeutig und bricht weiter ab.
- Zustandstexte der Abbruchmeldung unverändert (bereinigt, 80 Zeichen, `unbekannt`).
- Spec `asc-check-version.md`: AC-1 und Punkt „appInfo-Wahl“ erhalten einen Verweis auf diese Fortschreibung
  (nur Changelog-Zeile, Haupttext bleibt).

## Was darf sich nicht ändern
- Kein Raten: zwei oder mehr `REJECTED`-appInfos, kein `REJECTED`, oder Version nicht `REJECTED` → Abbruch wie bisher,
  nie „ok“.
- Regeln (a) und (b) und alle anderen Abschnitte (`privacy-url`, `iap`, `screenshots`, `build`, `review`, `status`,
  `submission`) verhalten sich wie vorher. Nur lesende Aufrufe, `ALLOWED`/Zaun unverändert.

## Akzeptanzkriterien
- **AC-1:** Version `REJECTED`, appInfos `READY_FOR_DISTRIBUTION` + `REJECTED` → `metadata` und `appinfo` laufen
  (Exit 0 bei sonst passenden Daten) und lesen die Unterpfade der `REJECTED`-appInfo, nicht der anderen.
- **AC-2:** Version `REJECTED`, zwei appInfos `REJECTED` → Abbruch „kein eindeutiger Entwurf“ mit allen Zuständen.
- **AC-3:** Version `REJECTED`, appInfos `LIVE` + `WAITING` (keine `REJECTED`) → Abbruch.
- **AC-4:** Version nicht `REJECTED` (z. B. `READY_FOR_SALE`), appInfos `READY_FOR_DISTRIBUTION` + `REJECTED` → Abbruch
  (bisheriges Verhalten, vormals AC-1 des Hauptspecs).
- **AC-5:** Entwurf-appInfo hat weiter Vorrang (b) vor (c).

## Manuelle Test-Schritte
1. Nach der Änderung `scripts/asc_check.py --section metadata --version 1.0.1` und `--section appinfo --version 1.0.1`
   gegen das echte Konto lesen (nur lesend, Schlüssel aus der Umgebung) — nur auf Wort des PO.

## Inline-Test
- [ ] `scripts/test_asc_check.py`: AC-1 bis AC-5 (vorhandener Test `test_two_infos_without_draft_aborts_with_all_states`
  wird auf Version nicht-`REJECTED` umgestellt = AC-4).
