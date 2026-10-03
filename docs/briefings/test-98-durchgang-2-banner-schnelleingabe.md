---
spec_file: docs/specs/ui-tests/replenishment-uitest.md
spec_sha256: bd3de4caef2265ba79c0835209bda7ed5a6ad8ce12f1ab5adcc5b4d4026ae028
---

# PO-Briefing: test-98-durchgang-2-banner-schnelleingabe

- **Spec:** docs/specs/ui-tests/replenishment-uitest.md
- **Issue:** #98
- **Erstellt:** 2026-10-03

## Was gebaut wird

Automatische Tests bedienen den Nachkauf-Banner und „Vielleicht auch fällig“ wie ein Nutzer, inklusive Neustart.

## Definition of Done

Neue Tests laufen dreimal in Folge grün, bestehende bleiben grün, ein Durchlauf in der App ist belegt.

## Wie geprüft wird

Tests starten mit rückdatierten Käufen und beweisen, dass Vorschläge erscheinen, verschwinden und gesperrt bleiben; Aussehen und Schnelleingabe prüfen sie nicht.

## Kritische Anmerkungen

- Beide Oberflächen existieren nur im Entwicklermodus; normale Nutzer sehen sie nie, getestet wird also nur dort.
- Schnelleingabe aus dem Ticket entfällt hier und folgt in Durchgang 3; Ticket bleibt dafür offen.
- Menü-Bedienung ist in Tests heikel; scheitert sie, melden wir uns mit Schätzung statt Tests auszulassen.

## Freigabe-Frage

Soll der Nachkauf-Banner im Entwicklermodus bleiben und die Schnelleingabe erst in Durchgang 3 folgen?
