---
spec_file: docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md
spec_sha256: e7e2fce83cd8d6bff52e06e861e637041e9fe918cdda961b34bbd3b63bd0fdea
---

# PO-Briefing: test-98-durchgang-5-onboarding-paywall

- **Spec:** docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md
- **Issue:** #98
- **Erstellt:** 2026-10-12

## Was gebaut wird

Automatische Tests spielen Onboarding, Paywall-Sperre und falsche Dev-Passwort-Eingabe wie ein echter Nutzer durch.

## Definition of Done

Neue und bestehende Oberflächentests laufen gemeinsam dreimal grün, ohne Rückstände zu hinterlassen.

## Wie geprüft wird

Tests bedienen sichtbare Elemente und beweisen Sperre, Läden, Name und Neustart, nicht aber Kauf, Wiederherstellen oder richtiges Passwort.

## Kritische Anmerkungen

- Kauf, Wiederherstellen und richtiges Dev-Passwort bleiben ungetestet; Punkt 7 ist nur teilweise erledigt.
- Laden-Einrichtung fehlt bewusst (Durchgang 6); Punkt 7 ist erst danach vollständig.
- Umfang etwa 265 statt 250 Zeilen; bei Überschreitung Rückmeldung vor Weiterbau.

## Freigabe-Frage

Gibst du Durchgang 5 frei, obwohl Kauf, richtiges Passwort und Laden-Einrichtung noch offen bleiben?
