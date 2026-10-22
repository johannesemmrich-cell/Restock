---
spec_file: docs/specs/services/community-prices-erst-hinweis.md
spec_sha256: 86150dea6bf1e98b45c9240642faf10aaa8e9f73feb631b0e6f7113ee7d5228f
spec_frozen_sha256: 3da3ff46511c591b5508075f292e8cd465f70c215e2922809ee51664559e7bf3
---

# PO-Briefing: feat-186-preisteilen-hinweis

- **Spec:** docs/specs/services/community-prices-erst-hinweis.md
- **Issue:** #186
- **Erstellt:** 2026-10-22

## Was gebaut wird

Vor dem ersten Preisbeitrag fragt die App einmal, ob Preise anonym geteilt werden dürfen.

## Definition of Done

Im Simulator erscheint beim ersten Bon-Speichern der Hinweis; „Nicht teilen“ schließt den Screen und schaltet das Teilen aus.

## Wie geprüft wird

Automatische Tests prüfen Regel, Zurückhalten und Bon-Ablauf; „Preis eintragen“ und das echte iPhone bleiben ungeprüft.

## Kritische Anmerkungen

- „Preis eintragen“ hat keinen Oberflächentest, nur die gemeinsame Logik.
- Bestandsnutzer sehen den Hinweis trotz früherem Teilen; Preise gehen verloren, wenn die App währenddessen beendet wird.
- Doppeltipp auf „Speichern“ ist nicht automatisch getestet.

## Freigabe-Frage

Soll der Hinweis vor dem Hochladen erscheinen und bei „Nicht teilen“ alles zurückhalten, wie entschieden?
