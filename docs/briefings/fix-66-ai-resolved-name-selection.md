---
spec_file: docs/specs/views/receipt-review-card.md
spec_sha256: 43af4a3a8dac35a83e48e9c20812be207ff1dadd0783ff8a3e4898e9c7a066f2
---

# PO-Briefing: fix-66-ai-resolved-name-selection

- **Spec:** docs/specs/views/receipt-review-card.md
- **Issue:** #66
- **Erstellt:** 2026-09-28

## Was gebaut wird

Bon-Prüfliste markiert nach automatischer Namenserkennung wieder zuverlässig genau eine Auswahl, auch wenn KI den Namen auflöst.

## Definition of Done

Ein Artikel, dessen Name die KI-Erkennung wortgleich zu einem Listenvorschlag auflöst, zeigt danach immer genau einen markierten Auswahlkreis.

## Wie geprüft wird

Automatisierte Tests bestätigen die Markierungslogik für alle Fälle; der KI-Auflösungsbildschirm selbst wird nicht vorgeführt, da Apple Intelligence im Simulator fehlt.

## Kritische Anmerkungen

- Nach dem Fix bedeutet „markiert" nicht „verknüpft": Preis lernt ohne Zusatztipp weiterhin nicht auf den Artikel zurück.
- Zwei gleichnamige Artikel mit falscher Verknüpfung bleiben weiterhin ohne markierte Auswahl, bewusst nicht Teil dieser Korrektur.
- Der eigentliche KI-Auflösungsfall wird nicht am Bildschirm vorgeführt, nur über nachgebaute Testdaten bewiesen.

## Freigabe-Frage

Reicht die Korrektur, obwohl der zugehörige Preis ohne einen weiteren Handgriff des Nutzers nicht automatisch dem Artikel zugeordnet wird?
