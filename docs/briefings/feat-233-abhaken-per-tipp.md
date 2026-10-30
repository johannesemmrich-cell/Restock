---
spec_file: docs/specs/views/item-row-tap-to-check.md
spec_sha256: d0f6e4ffc45a8119867882a065d5468ced839ad2a6e107dad0efa8a6ae688216
spec_frozen_sha256: 792746a4e298900f56d0c0942ec272f0080532529a43da8d6d39a4223c4df80f
---

# PO-Briefing: feat-233-abhaken-per-tipp

- **Spec:** docs/specs/views/item-row-tap-to-check.md
- **Issue:** #233
- **Erstellt:** 2026-10-30

## Was gebaut wird

Beim Einkaufen hakt ein Tipp irgendwo auf die Artikelzeile ab; Bearbeiten geht per Wischen, Lang drücken oder „Preis?“.

## Definition of Done

Im Simulator hakt der Zeilentipp ab und hebt auf, das Kästchen schaltet nur einmal, und Bearbeiten öffnet über Wischen, Lang drücken und „Preis?“.

## Wie geprüft wird

Automatische Oberflächentests belegen Tippen, Wischen, Lang drücken und „Preis?“; Sprachausgabe-Aktion, Live Activity und erledigte Zeilen werden nur im manuellen Durchlauf belegt.

## Kritische Anmerkungen

- Lang drücken im Test auf iOS 26 ist ungeprüft; der erste Lauf kann Anpassungen erzwingen.
- Zehn statt vier bis fünf Dateien, von dir freigegeben.
- Neue Nutzer erhalten keinen Hinweis, dass Tippen nicht mehr bearbeitet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
