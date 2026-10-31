---
spec_file: docs/specs/views/station-setup.md
spec_sha256: b4084eeca4f6f6f9e7ec4353d5f64239bbb9d4a6d39582d754e05995906e232b
spec_frozen_sha256: b7ef0a5e9e84705c71eac34a135f950c3a2348fc349c3ca5c53c790f3dfa37c9
---

# PO-Briefing: feat-234-d2-kategorien-einrichten

- **Spec:** docs/specs/views/station-setup.md
- **Issue:** #234
- **Erstellt:** 2026-10-31

## Was gebaut wird

Der Nutzer kann in der Ladenliste Gänge anlegen, umbenennen, sortieren, löschen und feste Kategorien zuordnen oder ausblenden.

## Definition of Done

Im Menü der Ladenliste öffnet „Kategorien einrichten“; umbenannte, zugeordnete oder ausgeblendete Gänge zeigen Artikel sofort im richtigen Abschnitt.

## Wie geprüft wird

Unit- und Oberflächentests belegen Umbenennen, Zuordnen, Löschen und Sortieren im Simulator; echte Geräte und geteilte Läden bleiben ungeprüft.

## Kritische Anmerkungen

- Ziehen der Gänge läuft über einen Knopf „Sortieren“ statt dauerhaft sichtbarer Griffe wie im freigegebenen Entwurf.
- Nur Lidl-Vorlage; Stichwörter nur lesbar, Mustervorlagen folgen in 2b. Umfang rund 640 Zeilen.
- Hinweiszeile für geteilte Läden hat keinen Test, nur Textprüfung.

## Freigabe-Frage

Ist das Sortieren über einen Knopf „Sortieren“ statt dauerhaft sichtbarer Ziehgriffe für dich in Ordnung?

## Ampel

Ampel: rot
