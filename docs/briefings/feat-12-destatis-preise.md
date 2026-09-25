---
spec_file: docs/specs/models/price-estimator-category-fallback.md
spec_sha256: 9313941b330cd69da54968dfc6d8a278ccf84cc5c60b3a30c79ebf976bc34216
---

# PO-Briefing: feat-12-destatis-preise

- **Spec:** docs/specs/models/price-estimator-category-fallback.md
- **Issue:** #12
- **Erstellt:** 2026-09-25

## Was gebaut wird

Kategorie-Preisschätzungen werden differenziert, damit z. B. Obst und sonstige Lebensmittel nicht mehr denselben Pauschalpreis zeigen.

## Definition of Done

Fertig, wenn alle 26 Kategorie-Pauschalpreise unterschiedlich sind und bestehende Preis-Tests weiterhin fehlerfrei durchlaufen.

## Wie geprüft wird

Automatisierte Tests belegen, dass alle 26 Werte verschieden sind — sie prüfen nicht, ob die Beträge realistisch sind.

## Kritische Anmerkungen

- Deine Entscheidung vom 25.9.: amtliche Destatis-Preise entfallen, nur Symptom (gleiche Preise) wird behoben.
- Nur 12 der 26 Kategorie-Pauschalen ändern sich; die 32 Produkt-Fixpreise bleiben komplett unangetastet.
- Neue Preise bleiben frei geschätzt, keine Datenquelle — nur bewusst unterschiedlich gemacht.

## Freigabe-Frage

Reicht dir eine reine Symptomkorrektur (unterschiedliche Schätzpreise, keine amtliche Quelle) als Ergebnis dieses Tickets?
