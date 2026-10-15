---
spec_file: docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md
spec_sha256: 40be782454ae80bf9efea86b46aef1f8cd8b6a98da8f305ba8d1cd6491bdf779
spec_frozen_sha256: 29b7cb8f30f990747593b1f9c0e0cc77295684b15fbb9756f295681ca8a82668
---

# PO-Briefing: test-145-d2-mitteilungserlaubnis

- **Spec:** docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md
- **Issue:** #145
- **Erstellt:** 2026-10-15

## Was gebaut wird

Ein automatischer Test bedient den echten Mitteilungsdialog und prüft, ob der Schalter Erlauben bzw. Ablehnen übernimmt.

## Definition of Done

Ein Skriptlauf auf dem Test-Simulator besteht für beide Entscheidungen, Protokoll und Screenshots liegen vor, die App ist danach wieder deinstalliert.

## Wie geprüft wird

Tests beweisen, dass der Schalter nach Erlauben bzw. Ablehnen richtig steht, auch nach erneutem Öffnen; nicht geprüft: Teilen-Erweiterung, echte Zustellung.

## Kritische Anmerkungen

- Zusatz: Der CI-Anschluss wurde nicht verlangt; scheitert er, färbt er Testhälften rot, Rückfall ist vorgesehen.
- Die zweite Mitteilungsanfrage der Teilen-Erweiterung bleibt ungeprüft; Verhalten auf dem englischen CI-Runner ist erst nach dem ersten Lauf belegt.

## Freigabe-Frage

Soll der Mitteilungsdialog automatisch geprüft werden, einschließlich CI-Anbindung mit Rückfall, obwohl die Teilen-Erweiterung ungeprüft bleibt?
