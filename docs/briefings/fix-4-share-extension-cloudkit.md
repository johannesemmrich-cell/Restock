---
spec_file: docs/specs/models/shared-model-container.md
spec_sha256: e32aff31976251799b844434826806342125e333cb0cabe48c1a02224252ab68
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

Automatisierte Tests decken den Weg über die Fotos-App ab, nicht den ursprünglich gemeldeten Weg über Lidl.

## Kritische Anmerkungen

- Das Ticket meldete den Absturz auch beim Teilen aus der Lidl-App; automatisiert geprüft wird nur der Fotos-App-Weg.
- Das Widget hat denselben Fehler, wird aber bewusst nicht mitgeprüft — ein dortiger Absturz bliebe unentdeckt.
- Ob der Cloud-Abgleich direkt nachweisbar ist, steht offen; sonst trägt der Fotos-App-Test allein diesen Beweis.

## Freigabe-Frage

Reicht der Nachweis über die Fotos-App, oder muss vor Freigabe auch der Lidl-Weg automatisiert geprüft werden?
