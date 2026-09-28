---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 127ad63b32218e8199c9a6562227fbe8d954c5c61da27e6b640da808cde24461
---

# PO-Briefing: fix-50-import-dialog-design

- **Spec:** docs/specs/views/receipt-review-card.md (Pakete 1 und 1b)
- **Issue:** #50
- **Erstellt:** 2026-09-27

## Was gebaut wird

Eine Bon-Position zeigt sichtbar genau einen markierten Namen — außer wenn die Auflösung einen Namen trifft, der wörtlich auf deiner Liste steht (offen, #66).

## Definition of Done

Beim Öffnen aus einer geteilten App trägt eine Position den markierten Namen, außer im Fall #66; ein leeres oder nur mit Leerzeichen gefülltes Namensfeld kehrt zum vorherigen zurück.

## Wie geprüft wird

Tests belegen den regelbasierten Weg und das geleerte Feld; den KI-Weg zeigt der Simulator nicht.

## Kritische Anmerkungen

- Gemeldeter Fall offen: bei namensgleichem Vorschlag keine Markierung (#66, Entwurf zuerst).
- Altlast: nach Wechsel auf den eigenen Namen kann der Preis am falschen Artikel landen (#67).
- Bontext lesbar und wählbar folgt in #65.

## Freigabe-Frage

Gibst du diesen Stand frei, obwohl ein gemeldeter Fall und zwei Darstellungspunkte in eigene Tickets gehen?
