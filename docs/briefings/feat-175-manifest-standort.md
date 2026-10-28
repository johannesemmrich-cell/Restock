---
spec_file: docs/specs/appstore/manifest-standort.md
spec_sha256: 8d729d6bf40ea85b0b3266a0305c50f6446454b149fad5c3469fcd3de7ec7aea
spec_frozen_sha256: 7077fc2f59d7c1e461721447e310d7cd64e43255c0b714a682d86d160a5fb30b
---

# PO-Briefing: feat-175-manifest-standort

- **Spec:** docs/specs/appstore/manifest-standort.md
- **Issue:** #175
- **Erstellt:** 2026-10-28

## Was gebaut wird

Die App meldet Apple künftig denselben ungefähren Standortbezug wie der veröffentlichte Fragebogen, und die Datenschutzerklärung erwähnt ihn.

## Definition of Done

Das Manifest nennt sieben statt sechs Datenarten, deckungsgleich mit dem Fragebogen, und die Erklärung in der App nennt den Standortbezug.

## Wie geprüft wird

Tests prüfen Manifest und Erklärungstext im Paket; nicht geprüft: Apples Annahme und die Seite des Dritten.

## Kritische Anmerkungen

- Sechs statt vier bis fünf Dateien; die Freigabe akzeptiert diese Überschreitung des Richtwerts.
- Der Schlüsselname des Standorttyps stützt sich nur auf Fremdquellen, nicht auf Apples Dokumentation; Prüfung steht noch aus.
- Die öffentliche Datenschutzseite des Dritten bleibt zunächst alt und widerspricht damit dem Fragebogen, bis er den Satz übernimmt.

## Freigabe-Frage

Gibst du das Nachziehen des Standorts im Manifest, mit sechs Dateien und Erklärungssatz, für Build 37 frei?
