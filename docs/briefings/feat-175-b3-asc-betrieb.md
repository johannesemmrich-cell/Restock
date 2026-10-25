---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: ebde69da2054e47c5a9da97657a71e5882675c279c9b2bf205efb2b73de575a1
spec_frozen_sha256: 0e882e196ea0b4e943771ccef7f821e6c36e130f830e389b9f8e848c39e7133d
---

# PO-Briefing: feat-175-b3-asc-betrieb

- **Spec:** docs/specs/appstore/app-store-auftritt.md (Durchgang B3b)
- **Issue:** #175
- **Erstellt:** 2026-10-25

## Was gebaut wird

Das Prüfwerkzeug für App Store Connect meldet kein falsches Grün und keinen Abbruch mehr; die App selbst bleibt unverändert.

## Definition of Done

Ein zweiter, nur lesender Prüflauf gegen Apple zeigt Altersfreigabe, Preis und Verfügbarkeit als Abweichung statt „ok“, die Datenschutzseite ohne Zugriffsfehler.

## Wie geprüft wird

Automatische Tests mit nachgebildeten Apple-Antworten belegen jede Korrektur; ob echte Apple-Antworten so aussehen, zeigt erst der zweite Leselauf.

## Kritische Anmerkungen

- Annahme ohne PO-Beschluss: Die App selbst ist kostenlos (0 €), Pro nur per Kauf.
- Datenschutzseite bleibt veraltet, hängt am Dritten; unverändert blockiert.
- Bedeutung von „404“ als „nicht eingerichtet“ stützt sich nur auf Forenberichte.

## Freigabe-Frage

Ist es für dich richtig, dass die App selbst kostenlos ist und Pro nur über In-App-Käufe kommt?
