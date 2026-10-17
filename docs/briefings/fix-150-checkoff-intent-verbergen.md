---
spec_file: docs/specs/services/checkoff-intent-verbergen.md
spec_sha256: 8cb190b898a67a71f29bcd553a54b532d5a61565dd7f9c40fb76f6463fcd9e9f
spec_frozen_sha256: 4428483fe5c9356c6b7d0a0f8a73ba472f73a3aa2a1be5c3b6d7f94fc8d3bcb7
---

# PO-Briefing: fix-150-checkoff-intent-verbergen

- **Spec:** docs/specs/services/checkoff-intent-verbergen.md
- **Issue:** #150
- **Erstellt:** 2026-10-17

## Was gebaut wird

Der Befehl „Nächsten Artikel abhaken“ erscheint nicht mehr in Siri und Kurzbefehlen, der Knopf der Live Activity bleibt.

## Definition of Done

Im Build ist der Befehl als nicht auffindbar eingetragen, und das Abhaken über die laufende Live Activity funktioniert weiterhin.

## Wie geprüft wird

Automatische Tests lesen die Build-Daten und führen den Befehl im Simulator aus; die Kurzbefehle-App und der echte Knopftipp bleiben ungeprüft.

## Kritische Anmerkungen

- Kurzbefehle-App und echter Knopftipp nicht getestet; Verbergen ist nur über Build-Daten und Apple-Dokumentation belegt.
- Abweichung vom Ticket: Test zum Nichtstun ohne Live Activity bleibt unverändert als Gegenprobe.
- Bestehende Kurzbefehle mit diesem Befehl verschwinden; vor Release 1.0 praktisch niemand betroffen.

## Freigabe-Frage

Soll der Befehl wie entschieden verborgen werden, auch wenn die Kurzbefehle-App-Oberfläche nicht automatisch geprüft wird?
