---
spec_file: docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md
spec_sha256: 4e2f96e627724e03acbf78a6e4da2a04a0f479048559e727a86ad2cf668376de
---

# PO-Briefing: test-98-durchgang-5-onboarding-paywall

- **Spec:** docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md
- **Issue:** #98
- **Erstellt:** 2026-10-12

## Was gebaut wird

Automatische Tests für Onboarding, Bezahlsperre und falsches Entwickler-Passwort, plus Korrektur des Paywall-Textes.

## Definition of Done

Alle neuen Tests laufen grün, auch dreimal wiederholt und zusammen mit den Bestandstests; die Paywall nennt "Rezeptplan" statt "dieses Feature".

## Wie geprüft wird

Tests bedienen die echte Oberfläche und prüfen Läden, Name, Sperre und Fehlermeldung; Kauf, Wiederherstellen und richtiges Passwort bleiben ungeprüft.

## Kritische Anmerkungen

- Fund: Paywall zeigte "dieses Feature" statt Funktionsname; wird nun mitkorrigiert, einzige sichtbare Textänderung am Produkt.
- Umfang: 5 Dateien, ca. 275 Zeilen, über der 250er-Grenze; Kürzung möglich.
- Kauf, Wiederherstellen, richtiges Dev-Passwort und Ladeneinrichtung bleiben ungetestet.

## Freigabe-Frage

Gibst du Durchgang 5 mit fünf geänderten Dateien, ungeprüftem Kauf und der Paywall-Textkorrektur frei?
