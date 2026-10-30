---
spec_file: docs/specs/views/paywall-rechtslinks.md
spec_sha256: 8940317edb05ba8acbb7be716c80eef8d5aad3ccb6b3359f3c168994fe566b06
spec_frozen_sha256: cbecfd89d7b60d3cc3fc5171658c6b36bc2b67f647199d144c4f186b4c60d947
---

# PO-Briefing: fix-215-paywall-rechtslinks

- **Spec:** docs/specs/views/paywall-rechtslinks.md
- **Issue:** #215
- **Erstellt:** 2026-10-30

## Was gebaut wird

Die Bezahlseite zeigt Links zu Datenschutz und Nutzungsbedingungen sowie einen Abo-Text mit Laufzeit, Preis und Kündigungsfrist.

## Definition of Done

Nach dem Hochscrollen sind beide Links und der Abo-Text lesbar und antippbar, auch bei größter Schrift, hell und dunkel.

## Wie geprüft wird

Tests prüfen Sichtbarkeit, Lage und Link-Adressen; ob der Browser sich öffnet und Apple die Lösung akzeptiert, bleibt ungeprüft.

## Kritische Anmerkungen

- Die Datenschutzseite gehört einem Dritten und beschreibt Funktionen noch falsch; der Link besteht nur formal.
- Apples genauer Wortlaut (Schedule 2) ist nicht belegt; Ablehnung bleibt möglich.
- Der Abo-Text geht über die geforderten Links hinaus, steht aber im freigegebenen Entwurf A.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
