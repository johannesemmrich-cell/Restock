---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 869afd608093a606308c41af1488b3b54a2544f12ada3e2512410c90f4d73380
---

# PO-Briefing: fix-67-currentname-matcheditem

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #67
- **Erstellt:** 2026-09-29

## Was gebaut wird

Der Bon-Prüf-Screen ordnet den gelernten Preis wieder dem gerade angezeigten Artikelnamen zu, nicht einem alten.

## Definition of Done

Der PO erkennt es daran: nach Namenswechsel zurück zum Ursprungsnamen lernt die App den Preis am richtig angezeigten Artikel, nie am vorherigen.

## Wie geprüft wird

Ein automatisierter Test bestätigt die korrekte Zuordnung nach Namenswechsel; ein Nutzer-Durchlauf im Simulator ist für diese interne Logik nicht vorgesehen.

## Kritische Anmerkungen

- Inhalt identisch zur zuvor freigegebenen Fassung — nur AC-Nummer und Codezeilen wurden wegen Issue #66 aktualisiert.

## Freigabe-Frage

Gibst du frei, dass ab jetzt der zuletzt angezeigte Name entscheidet, welchem Artikel der gelernte Preis zugeordnet wird?
