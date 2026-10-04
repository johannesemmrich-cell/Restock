---
spec_file: docs/specs/ui-tests/test-98-durchgang-3-schnelleingabe-notfallpfad.md
spec_sha256: fd101216c84843a09b096eefb2ce4a05aa2c922f5674e6db7278d788a40e578d
---

# PO-Briefing: test-98-durchgang-3-schnelleingabe-sync

- **Spec:** docs/specs/ui-tests/test-98-durchgang-3-schnelleingabe-notfallpfad.md
- **Issue:** #98
- **Erstellt:** 2026-10-04

## Was gebaut wird

Neue Tests belegen, dass Schnelleingabe-Artikel in der Ladenliste landen und der Notfall-Neustart die Läden löscht.

## Definition of Done

Alle Tests laufen dreimal stabil grün, ein Simulator-Durchlauf liegt vor, die ausgelieferte App enthält keine Testzweige.

## Wie geprüft wird

Echte Bedienung im Simulator weist Liste, Verschieben, Hinweis „Daten neu geladen“ und Neustart nach; der natürliche Auslöser bleibt ungeprüft.

## Kritische Anmerkungen

- Sync stand für Durchgang 3 im Ticket, wurde wegen des Umfangs auf Durchgang 4 verschoben.
- Offene Grenze: Dass die App selbst in den Notfallpfad gerät, ist im Simulator nicht erzeugbar, also unbewiesen.
- Der Testzweig der App löscht echte Daten und prüft zusätzlich per Hilfsdatei, dass keine Fremddateien getroffen werden.

## Freigabe-Frage

Gibst du Durchgang 3 mit verschobenem Sync und dieser offenen Grenze frei?
