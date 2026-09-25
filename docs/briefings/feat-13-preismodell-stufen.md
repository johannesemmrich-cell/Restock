---
spec_file: docs/specs/models/price-estimator-stages.md
spec_sha256: e627860e5fe69df36ae6b3ea4dc15c8dd25d8e5d4e2fca99ae167bd261de4d02
---

# PO-Briefing: feat-13-preismodell-stufen

- **Spec:** docs/specs/models/price-estimator-stages.md
- **Issue:** #13
- **Erstellt:** 2026-09-25

## Was gebaut wird

Nichts Sichtbares: das bestehende Preis-Rangfolge-Verhalten wird nur dokumentiert und gegen ungewollte Änderungen abgesichert.

## Definition of Done

Fertig ist es, wenn die heutige Preis-Rangfolge durch automatische Tests abgesichert ist, ohne dass sich für Nutzer etwas ändert.

## Wie geprüft wird

Tests belegen, dass gelernte Preise vor Produkt-Keywords vor Kategorie-Pauschalen gewinnen; sie prüfen keine echten Marktpreise.

## Kritische Anmerkungen

- Ticket bringt keinerlei sichtbare oder funktionale Änderung — nur interne Doku und Regressionstests.
- Ursprünglich verlangte echte Marktpreise (Open Prices) sind komplett auf Folgeticket #49 verschoben.
- Gelernte Preise bleiben zeitlich unbegrenzt gültig — auch geplante Veraltungsregel wurde nach #49 verschoben.

## Freigabe-Frage

Reicht dir eine reine Dokumentation ohne neue Preisquelle als Abschluss von #13, während echte Marktpreise erst mit #49 kommen?
