---
spec_file: docs/specs/models/shared-model-container.md
spec_sha256: ef824685166a2241977b75b34f0bc9a8324b9c2d7e05961b279f4f4d2d38ce0a
---

# PO-Briefing: fix-4-share-extension-cloudkit

- **Spec:** docs/specs/models/shared-model-container.md
- **Issue:** #4
- **Erstellt:** 2026-09-20

## Was gebaut wird

Der Bon-Import per Teilen aus anderen Apps stürzt nicht mehr ab, sondern gelingt.

## Definition of Done

Ein geteiltes Bon-Foto wird ohne Absturz erkannt und zeigt die Erfolgsanzeige.

## Wie geprüft wird

Automatisierte Tests prüfen jede einzelne Anforderung der Spezifikation, decken aber nicht den ursprünglich gemeldeten Weg über die Lidl-App ab.

## Kritische Anmerkungen

- Der ursprünglich gemeldete Weg über die Lidl-App wird nicht automatisch geprüft, nur der Weg über die Fotos-App.
- Das Widget hat denselben Fehler, wird aber bewusst nicht automatisiert nachgewiesen – ein dortiger Absturz bliebe unentdeckt.
- Neu gegenüber dem letzten Briefing: Der Cloud-Abgleich wird jetzt direkt bewiesen, der vorher offene Punkt ist geklärt.

## Freigabe-Frage

Reicht der Nachweis über die Fotos-App, oder muss vor Freigabe auch der Lidl-Weg automatisiert geprüft werden?
