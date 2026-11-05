---
spec_file: docs/specs/views/legal-text-darstellung.md
spec_sha256: 4727429c0a62d4e9db312c428933e57aea39ed0d29885e3b6840b5ee8af47cb6
spec_frozen_sha256: 5266072a7dae4e63660d875b096c3d170e7b794d52a10b19ceb6c5577cfb63db
---

# PO-Briefing: fix-214-181-legal-pfeil

- **Spec:** docs/specs/views/legal-text-darstellung.md
- **Issue:** #214 und #181
- **Erstellt:** 2026-11-05

## Was gebaut wird

Rechtstexte erscheinen mit Absätzen, Trennlinien und Aufzählungen, und der Rezeptplan-Hinweis zeigt einen echten Pfeil.

## Definition of Done

Datenschutz, Nutzungsbedingungen und Impressum zeigen getrennte Absätze ohne „———“, auch in größter Schrift, und der Hinweis zeigt „→“ statt „u{2192}“.

## Wie geprüft wird

Automatische Tests und ein Simulator-Durchlauf mit Aufnahmen belegen Darstellung und Pfeil; nichts wird auf deinem Gerät, mit VoiceOver oder auf Dauer der CI gemessen.

## Kritische Anmerkungen

- Ob die gewählte Darstellung auf iOS 26/27 Zeilenumbrüche und Fettdruck erhält, ist ungemessen; erst der erste Testlauf zeigt es.
- Die Laufzeit der CI-Hälfte A mit den neuen Tests ist ungemessen; über 55 Minuten bräuchte es eine CI-Änderung.
- Umfang liegt mit fünf Dateien und etwa 200 Zeilen knapp am Limit; das Impressum kam ohne Ticketwunsch dazu.

## Freigabe-Frage

Soll das Impressum, das im Ticket nicht genannt ist, im selben Durchgang mit umgestellt werden?

## Ampel

Ampel: rot
