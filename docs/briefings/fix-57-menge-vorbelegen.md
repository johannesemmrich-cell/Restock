---
spec_file: docs/specs/services/assignment-service-quantity-suggestion.md
spec_sha256: 880502dcd23d3c244309cca973a42a73bbc1d863db39f2e5644c784012ed5779
---

# PO-Briefing: fix-57-menge-vorbelegen

- **Spec:** docs/specs/services/assignment-service-quantity-suggestion.md
- **Issue:** #57
- **Erstellt:** 2026-09-30

## Was gebaut wird

Beim Anlegen ohne Mengenangabe schlägt die App aus früherem Kauf oder Packungsgröße eine Menge vor, sichtbar als Annahme markiert.

## Definition of Done

Fertig ist es, wenn eine neu angelegte Menge ohne Eingabe sichtbar als Annahme erscheint, korrigierbar bleibt und alle Tests grün laufen.

## Wie geprüft wird

Automatische Tests prüfen jede Regel einzeln und einen Durchlauf im Simulator; Sichtprüfung im Hellmodus ist nicht enthalten.

## Kritische Anmerkungen

- Im Hellmodus ist die Annahme-Markierung kaum lesbar (WCAG unterschritten) — separates Ticket #75, hier nicht behoben.
- Schnell-Eingabe und Siri-Anlage bekommen die Mengen-Vorbelegung nicht, dort bleibt es wie bisher.
- Bei Alltagsartikeln ohne Gewichtsangabe kann die Annahme fälschlich „ca. 1" ohne Einheit zeigen (rein kosmetisch, kein Preisfehler).

## Freigabe-Frage

Gibst du diese Mengen-Vorbelegung frei, obwohl Hellmodus-Lesbarkeit und Schnell-Eingabe/Siri bewusst außen vor bleiben?
