---
spec_file: docs/specs/services/icloud-einrichtung-sichtbar.md
spec_sha256: 763b179c72b724678fa785a2cbc4f2f252799f2b05785acabe245223ba0774be
spec_frozen_sha256: 759f529ba95fea552eedd086390167ef033c53dfa9104ebdd4836a99efd50e34
---

# PO-Briefing: fix-166-icloud-einrichtung-sichtbar

- **Spec:** docs/specs/services/icloud-einrichtung-sichtbar.md
- **Issue:** #166
- **Erstellt:** 2026-10-19

## Was gebaut wird

Die Entwickler-Diagnose zeigt künftig, wenn die iCloud-Einrichtung beim App-Start scheitert, samt Ursache wie „kein iCloud-Konto“.

## Definition of Done

Im Simulator ohne iCloud-Konto zeigt die Diagnose „Einrichtung fehlgeschlagen“ mit Code 134400 statt „noch kein Lauf“; spätere erfolgreiche Einrichtung ersetzt den Fehler.

## Wie geprüft wird

Automatische Tests und ein echter Simulatorlauf belegen die Anzeige; nicht belegt ist das Verhalten auf Hennings iPhone oder mit echt erfolgreicher iCloud-Einrichtung.

## Kritische Anmerkungen

- Die iCloud-Überwachung startet früher, für alle Nutzer, nicht nur Entwickler; sie liest nur, laut Spec unschädlich.
- Nur „kein iCloud-Konto“ bekommt Klartext; andere Fehler erscheinen nur als Code und Systemtext.
- Gerät und echter CloudKit-Erfolg sind ungeprüft.

## Freigabe-Frage

Soll die Diagnose gescheiterte iCloud-Einrichtungen anzeigen, mit diesen bekannten Grenzen freigegeben werden?
