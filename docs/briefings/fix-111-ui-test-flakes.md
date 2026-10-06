---
spec_file: docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
spec_sha256: c4975e928e8e460e2cb540aeec86048b909dc546bc126ffb860fc187f0f632ca
---

# PO-Briefing: fix-111-ui-test-flakes

- **Spec:** docs/specs/ui-tests/test-111-durchgang-1-ui-test-wait.md
- **Issue:** #111
- **Erstellt:** 2026-10-06

## Was gebaut wird

Oberflächentests warten bei langsamen Rechnern geduldiger und scheitern seltener zufällig; die App bleibt unverändert.

## Definition of Done

Fünf zufällig scheiternde Tests liefen in 150 Cloud-Wiederholungen fehlerfrei, die App ist unverändert; #111 bleibt offen.

## Wie geprüft wird

30 Wiederholungen je Test auf dem Cloud-Rechner: vorher 5 Fehler, nachher 0; beweist keine dauerhafte Stabilität.

## Kritische Anmerkungen

- Gesamte Testsuite nicht grün: zwei Nachkauf-Tests scheitern auch ohne diese Änderung (Ticket #115).
- Toast-Test bleibt zufällig anfällig, ebenso ein Wettlauf beim Antippen; Behebung erst Durchgang 2.
- Ziel „beim ersten Versuch grün“ ist nicht erreicht.

## Freigabe-Frage

Durchgang 1 freigeben, obwohl Toast-Test und zwei Nachkauf-Tests offen bleiben und #111 nicht schließt?
