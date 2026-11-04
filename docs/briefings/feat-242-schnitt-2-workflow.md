---
spec_file: docs/specs/appstore/asc-crashes.md
spec_sha256: 314133037b041e662c302d121b130417b7f55397cd913f5af10264f1709d83e7
spec_frozen_sha256: ca0d1e8500467db029a5f455d182d366336188710773d218f57f5bcd61f34d1e
---

# PO-Briefing: feat-242-schnitt-2-workflow

- **Spec:** docs/specs/appstore/asc-crashes.md
- **Issue:** #242
- **Erstellt:** 2026-11-04

## Was gebaut wird

Ein CI-Knopf holt TestFlight-Absturzmeldungen ab und legt sie verschlüsselt ab, damit Claude sie lesen kann.

## Definition of Done

Der Probelauf endet grün, mit entschlüsselbaren Meldungen oder dem Hinweis „keine Absturzmeldungen“; die Anleitung steht in der Doku.

## Wie geprüft wird

Strukturtests prüfen den Ablauf; ob Apple antwortet und Entschlüsseln klappt, zeigen erst echte Läufe.

## Kritische Anmerkungen

- Abweichung: verschlüsselte statt Klartext-Ablage, da das Repo öffentlich ist; Lesen nur mit Schlüssel auf Hennings Mac.
- Nachweise (Probelauf, Eingabe „selftest“, Artefakt „crashes-selftest“) folgen erst nach dem Zusammenführen; bei Fehlschlag folgt eine Korrektur.
- „Echte Meldung ausgewertet“ aus dem Ticket gehört nicht zu diesem Schnitt; Schlüsselrolle bei Apple ungeprüft.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
