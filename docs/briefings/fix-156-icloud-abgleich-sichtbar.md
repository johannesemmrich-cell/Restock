---
spec_file: docs/specs/services/icloud-abgleich-sichtbar.md
spec_sha256: 2b6086c797ee237f310f787c28e8254e2fea3161493c39f7577c44aaedc1d5f5
spec_frozen_sha256: 4fea37ed0dc643128eef47d7d689411038190a94cf5d3807df204f3b52cb6a15
---

# PO-Briefing: fix-156-icloud-abgleich-sichtbar

- **Spec:** docs/specs/services/icloud-abgleich-sichtbar.md
- **Issue:** #156
- **Erstellt:** 2026-10-18

## Was gebaut wird

Die App zeigt im Entwicklermodus iCloud-Exportfehler und doppelte Läden an und verhindert neue Doppel bei Neuinstallation.

## Definition of Done

Im Entwicklermodus erscheinen die Zeilen „iCloud-Abgleich“ und „Doppelte Läden“, die Ersteinrichtung wartet höchstens 10 Sekunden auf iCloud, das Foto-Feld liegt in Produktion.

## Wie geprüft wird

Automatische Tests prüfen Fehleranzeige, Doppelerkennung und Warteverhalten mit simulierten Daten; echtes iCloud und Hennings Geräte bleiben ungeprüft.

## Kritische Anmerkungen

- Umfang ca. 670 statt akzeptierter 400–500 Zeilen; die Freigabe bestätigt diese Überschreitung.
- Bestehende Doppel-Läden werden nur angezeigt, nicht entfernt; Aufräumen bleibt offen.
- Echter Exportfehler und Wartezeit mit echtem iCloud am Gerät nicht belegt; vergessenes Produktions-Deployment bliebe unentdeckt.

## Freigabe-Frage

Gibst du die Spec frei, inklusive des größeren Umfangs von etwa 670 Zeilen?
