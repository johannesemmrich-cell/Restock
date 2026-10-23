---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: fbe8b7aa15a4338c262398be326555011ad78e1f8779bd3f84e3c3f00758e9bb
spec_frozen_sha256: 0f7b528836c5c44e0be204d06a6712e2930976650191dae12e98adb330bdc9dd
---

# PO-Briefing: feat-175-a2-berechtigungstexte

- **Spec:** docs/specs/appstore/app-store-auftritt.md (Durchgang A2)
- **Issue:** #175
- **Erstellt:** 2026-10-23

## Was gebaut wird

Die Kamera- und Foto-Abfrage der App erscheint auf Deutsch und Englisch; die Build-Nummer steigt auf 37.

## Definition of Done

Im Simulator zeigt der Kamera-Dialog des Bon-Scans den deutschen Text mit Bons, Barcodes und Rezeptfotos, und die Version lautet 37.

## Wie geprüft wird

Tests prüfen Textdateien, Build-Nummer 37 und den Inhalt des gebauten Pakets; den Dialog selbst belegt nur ein Simulator-Durchlauf, nichts auf Geräten.

## Kritische Anmerkungen

- Ob die Übersetzungsdateien bei erzeugter Konfiguration greifen, ist nicht aus Quellen belegt; erst Test und Simulator beweisen es.
- Nichts wird auf Hennings Geräten gestartet; Upload von Build 37 erfolgt nur auf sein ausdrückliches Wort.
- Kein automatischer Test prüft den angezeigten Dialogtext; nur Screenshots belegen ihn.

## Freigabe-Frage

Soll Durchgang A2 so umgesetzt werden, mit lokalisiertem Kamera- und Fototext und Build-Nummer 37?
