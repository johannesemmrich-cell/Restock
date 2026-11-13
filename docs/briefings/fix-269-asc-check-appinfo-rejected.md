---
spec_file: docs/specs/fast/fix-269-asc-check-appinfo-rejected.md
spec_sha256: a6f39d6a60dd7f599821f7647e4e382d6cfcefc85e840aafee2a2ddada000d46
spec_frozen_sha256: 396567bcab31a6eb16c993d0b5344583fd96f791cedb5da904d4e862a568a211
---

# PO-Briefing: fix-269-asc-check-appinfo-rejected

- **Spec:** docs/specs/fast/fix-269-asc-check-appinfo-rejected.md
- **Issue:** #269
- **Erstellt:** 2026-11-12

## Was gebaut wird

Das App-Store-Prüfwerkzeug liest bei abgelehnter Version die Texte und Altersfreigabe der abgelehnten Eintragung, statt abzubrechen.

## Definition of Done

Der Lesebefehl für Texte und App-Infos läuft für die abgelehnte Version 1.0.1 durch, ohne „kein eindeutiger Entwurf“ zu melden.

## Wie geprüft wird

Automatische Tests mit Schein-Antworten decken Erfolg und alle Abbruchfälle ab; ein Lauf gegen das echte Konto folgt nur auf dein Wort.

## Kritische Anmerkungen

- Echtes Konto ist nicht geprüft; ob Apples Antwort der Annahme entspricht, zeigt erst der spätere Lesebefehl.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
