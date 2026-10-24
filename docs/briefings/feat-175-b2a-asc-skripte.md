---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: 0f8c1b0d12c7596987e5c4b80b85467b70c131cee6f55807d3905c017f0cb3fe
spec_frozen_sha256: 5335a4fa0755072de5fa911540734cec90f9e8d512e9f3ac056c82f83de35e2f
---

# PO-Briefing: feat-175-b2a-asc-skripte

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-24

## Was gebaut wird

Ein Werkzeug, das die fertigen Store-Texte per Knopfdruck in den Entwurf von Version 1.0 bei Apple einträgt.

## Definition of Done

Der Sicherheitstest läuft grün, und das Werkzeug zeigt im Trockenlauf genau an, was es bei Apple ändern würde, ohne etwas zu ändern.

## Wie geprüft wird

Tests mit Schein-Antworten beweisen, dass nur der Entwurf der eigenen App beschrieben und nie eingereicht wird; ein echter Apple-Lauf fehlt.

## Kritische Anmerkungen

- Kein echter Apple-Lauf: Ob Name und Untertitel änderbar sind, zeigt sich erst im nächsten Durchgang.
- Bricht das Schreiben mittendrin ab, bleibt ein Mischstand; Abhilfe ist nur erneuter Lauf und spätere Gegenprüfung.
- Umfang ~330 statt 250 Zeilen; von dir angenommen, das Prüftor könnte anders zählen.

## Freigabe-Frage

Soll das Werkzeug gebaut werden, wobei es erst im nächsten Durchgang auf dein Wort echt bei Apple läuft?
