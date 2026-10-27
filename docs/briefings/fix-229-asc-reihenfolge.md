---
spec_file: docs/specs/appstore/asc-publish-reihenfolge.md
spec_sha256: 8161976cb2ca01cb337185d3af80f738a08ca4a275dfdc4c41f71caf572ad8cb
spec_frozen_sha256: d70ff48e5ffe7329c78c53b288a77d0a7adf97513f0e8edeb9179150f9bb11bf
---

# PO-Briefing: fix-229-asc-reihenfolge

- **Spec:** docs/specs/appstore/asc-publish-reihenfolge.md
- **Issue:** #229
- **Erstellt:** 2026-10-27

## Was gebaut wird

Das Eintragungswerkzeug legt bei neuen Sprachen zuerst die App-Angaben mit Namen an, danach erst die Produktseite.

## Definition of Done

Die Tests belegen die neue Reihenfolge; ob Apple den englischen Eintrag akzeptiert, zeigt erst ein späterer Lauf auf Ihr Wort.

## Wie geprüft wird

Schein-Antworten ohne Netz belegen Reihenfolge, Wiederholbarkeit und bisheriges Verhalten, aber nicht die Wirkung bei Apple.

## Kritische Anmerkungen

- Die Ursache ist nur eine Forenvermutung; hilft die Reihenfolge nicht, bleibt Englisch weiter blockiert.
- Kein Schreibaufruf gegen Apple in diesem Durchgang: „fertig“ heißt nicht „Fehler behoben“.
- Scheitert die Produktseite nach den App-Angaben, entsteht ein Mischstand; Wiederholung schreibt nur den Rest.

## Freigabe-Frage

Soll die Reihenfolge geändert werden, obwohl erst ein späterer Eintragungslauf zeigt, ob Apple den englischen Namen akzeptiert?
