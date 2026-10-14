---
spec_file: docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
spec_sha256: 3d0b030765c6ec068334eb4fb3bb16eb4a2ef6ce165f6529cc2e91157af0b011
---

# PO-Briefing: test-98-durchgang-7-tagesmitteilung

- **Spec:** docs/specs/ui-tests/test-98-durchgang-7-tagesmitteilung.md
- **Issue:** #98
- **Erstellt:** 2026-10-13

## Was gebaut wird

Automatische Tests prüfen die tägliche Sammelmitteilung „Zeit zum Nachkaufen“, und ein Fehler ohne Mitteilungserlaubnis wird behoben.

## Definition of Done

Sechs neue Tests laufen dreimal grün, der Fehlertest war vorher rot, bisherige Tests bleiben grün, Simulator-Durchlauf ist registriert.

## Wie geprüft wird

Echte Planungskette mit Attrappe statt Systemzentrale; nicht geprüft: Zustellung um 9 Uhr, Systemstart des Hintergrundlaufs, Erlaubnisdialog.

## Kritische Anmerkungen

- Mitgebehobener Fehler: Ohne Erlaubnis galt ein Artikel fälschlich als gemeldet; nur im Entwicklermodus sichtbar.
- Ticket verlangt den echten Weg; die Mitteilungszentrale ist jedoch eine Attrappe. Umfang 230 von 250 Zeilen.
- Offen bleiben Siri/Widget und die Frage, ob die Erlaubnis früher erfragt werden soll.

## Freigabe-Frage

Geben Sie diese Tests samt Fehlerbehebung und den genannten Grenzen frei?
