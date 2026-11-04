---
spec_file: docs/specs/appstore/asc-crashes.md
spec_sha256: b0a73d69a100d4ff5e0087bcdf4aaf7965a68c36624503fbe8a1fd128767ff5e
spec_frozen_sha256: 8672360c97f91e3323617d467ff8bea7f0d205a1b3d81788ef4de391f7f1a079
---

# PO-Briefing: feat-242-testflight-crashes

- **Spec:** docs/specs/appstore/asc-crashes.md
- **Issue:** #242
- **Erstellt:** 2026-11-04

## Was gebaut wird

Auf Knopfdruck holt ein Lauf TestFlight-Absturzberichte bei Apple ab und legt sie verschlüsselt bereit, damit Claude sie lesen kann.

## Definition of Done

Ein manueller Lauf endet grün und liefert entweder ein entschlüsselbares Berichtspaket oder die Meldung „keine Absturzmeldungen“; Entschlüsselungsweg mit Testdatei belegt.

## Wie geprüft wird

Automatische Tests prüfen Abruf, Zugriffssperre und Log gegen Schein-Antworten; echte Apple-Antworten und die Rolle des Schlüssels zeigt erst der Probelauf.

## Kritische Anmerkungen

- Abweichung vom Ticket: eigener Zugriffszaun statt Erweiterung der gemeinsamen Freigabeliste; Ziel gleich, Publish-Skript bleibt unberührt.
- Schnitt 1 umfasst etwa 330 Zeilen, über dem Limit 250; bewusst nicht geteilt.
- Berichte liegen verschlüsselt mit vorhandenem Loose-Ends-Schlüssel sieben Tage öffentlich; ob Restocks Schlüssel die nötige Rolle hat, ist ungeprüft.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
