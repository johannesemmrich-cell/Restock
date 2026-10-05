---
spec_file: docs/specs/ci/testflight-upload-workflow.md
spec_sha256: 85b722ba5250f7d0dcb3c6d35f5c5b215ef66e4c94e23e58396a6b82daae349d
---

# PO-Briefing: feat-109-testflight-ci-upload

- **Spec:** docs/specs/ci/testflight-upload-workflow.md
- **Issue:** #109
- **Erstellt:** 2026-10-05

## Was gebaut wird

Build-Uploads zu TestFlight starten per Knopfdruck auf GitHub, ohne dass du dich lokal in Xcode anmelden musst.

## Definition of Done

Ein Probelauf auf GitHub lädt einen neuen Build mit höherer Nummer als 9 fertig verarbeitet in TestFlight hoch.

## Wie geprüft wird

Ein automatischer Test belegt nur den Aufbau des Ablaufs; ob Signieren und Hochladen klappen, zeigt erst dein Probelauf.

## Kritische Anmerkungen

- Das Ticket bleibt offen, bis dein Probelauf mit Admin-Schlüssel gelingt; vorher ist nur der Aufbau bewiesen.
- Admin-Schlüssel liegt in GitHub und könnte Team und Zertifikate ändern; Alternative ohne Schlüssel: Xcode Cloud.
- Hochzählen der Build-Nummer übernimmt Xcode selbst, ungeprüft bis zum echten Lauf; Rückfall wäre ein eigenes Zählskript.

## Freigabe-Frage

Soll der Upload per GitHub gebaut werden, obwohl du dafür später einen Admin-Schlüssel dort hinterlegen musst?
