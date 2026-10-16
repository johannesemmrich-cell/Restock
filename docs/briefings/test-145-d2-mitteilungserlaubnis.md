---
spec_file: docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md
spec_sha256: 25c6c46e8c41779279f9a141ea861317a819f1845af5a742926f207a63598025
spec_frozen_sha256: ec5aedd55285b53f8193e6197dd792be07d3b04487bff70aa29887fc16baf936
---

# PO-Briefing: test-145-d2-mitteilungserlaubnis

- **Spec:** docs/specs/ui-tests/test-145-durchgang-2-mitteilungserlaubnis.md
- **Issue:** #145
- **Erstellt:** 2026-10-16

## Was gebaut wird

Automatischer Test bedient den echten Mitteilungsdialog der App und prüft, dass der Schalter nach Erlauben an, nach Ablehnen aus bleibt.

## Definition of Done

Ein Skript spielt beide Entscheidungen auf je einem frischen Wegwerf-Simulator durch, beide Läufe grün, keine Reste; CI-Anschluss grün oder begründet vertagt.

## Wie geprüft wird

Der Test beweist Dialog und Schalterzustand im Simulator; nicht geprüft sind Teilen-Erweiterung, echte Zustellung und Hennings Geräte.

## Kritische Anmerkungen

- CI-Anschluss darf entfallen; dann läuft der Test nur per Skript, nicht automatisch.
- Dialog der Teilen-Erweiterung ungeprüft; englischer CI-Dialog bis zum ersten Lauf unbelegt.

## Freigabe-Frage

Genügt dir ein Test, der beide Wege per Skript prüft, auch wenn die CI-Anbindung entfallen kann?
