---
spec_file: docs/specs/views/paywall-produkte-nachladen.md
spec_sha256: c2544d556cf2efa4106c984ed3bd05c84e2a08ab36dd2da76f268ea7b7f59f49
spec_frozen_sha256: 9ab939ad67a26ca31a3c38ae55cb07ce5017ba6134853d7988107fcd35a08018
---

# PO-Briefing: fix-265-iap-ladbar

- **Spec:** docs/specs/views/paywall-produkte-nachladen.md
- **Issue:** #265
- **Erstellt:** 2026-11-09

## Was gebaut wird

Die Paywall lädt Produkte erneut, statt nach einem Fehlstart dauerhaft „Der Kauf konnte nicht geladen werden“ zu zeigen.

## Definition of Done

Im Simulator mit zunächst leerem Produktabruf lässt sich der Kauf ohne Fehlertext auslösen, und die App trägt die Build-Nummer 41.

## Wie geprüft wird

Unit- und UI-Tests gegen einen Ersatz-Appstore belegen das Nachladen; ein echter Apple-Kauf und Apples Prüfumgebung sind nicht prüfbar.

## Kritische Anmerkungen

- Code-Fix allein behebt die Ablehnung wohl nicht; entscheidend ist das Einreichen der drei Käufe, getrennt und nur auf PO-Wort.
- Ursache bei Apple nur gestützt, nicht bestätigt; ob das Nachladen in Apples Prüfumgebung wirkt, ist nicht nachstellbar.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
