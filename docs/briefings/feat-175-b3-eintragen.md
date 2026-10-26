---
spec_file: docs/specs/appstore/app-store-auftritt.md
spec_sha256: 1aef98498af7b06fd1e12c9a2c64d3f8b0af2a658312856c063bf0324b590d68
spec_frozen_sha256: 35f82f9be9765364fd8026075a13ca16c5353cdad2fd42cd26aaf76120092371
---

# PO-Briefing: feat-175-b3-eintragen

- **Spec:** docs/specs/appstore/app-store-auftritt.md
- **Issue:** #175
- **Erstellt:** 2026-10-26

## Was gebaut wird

Die Store-Seite von Restock 1.0 wird in App Store Connect ausgefüllt: Texte, Kategorien, Screenshots, drei Käufe, Testbuild.

## Definition of Done

Das Prüfwerkzeug meldet alle Abschnitte „ok“ und der Datenschutz-Fragebogen ist per Screenshot belegt; Einreichen gehört nicht dazu.

## Wie geprüft wird

Nach jedem Schritt liest ein Werkzeug den Stand bei Apple zurück und vergleicht ihn mit den Soll-Texten; Fragebogen und Optik bleiben ungeprüft.

## Kritische Anmerkungen

- Abschluss hängt an Offenem: Datenschutzseite des Dritten, dein Review-Kontakt, Build 37 nicht hochgeladen.
- Käufe sind unumkehrbar und kommen zuletzt (1,99/8,99/14,99), abweichend von der Spec-Nummerierung.
- Fehlende Rechtslinks in der Paywall (#215) bleiben Ablehnungsrisiko, nicht enthalten.

## Freigabe-Frage

Darf der Betrieb starten, wobei jeder Schritt in App Store Connect dein einzelnes getipptes Wort braucht?
