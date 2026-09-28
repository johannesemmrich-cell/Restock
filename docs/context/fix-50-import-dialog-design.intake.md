# Intake #50 — Import-Dialog entspricht nicht dem Design

Workflow: `fix-50-import-dialog-design` · Track: Standard (Summe 3) · Datum: 2026-09-27

## Ursprungsmeldung (Issue #50)

Screenshot: Bon-Prüfliste (`ReceiptScannerView` mit `ReceiptReviewCard`), Laden DM, 8 Positionen.

1. Überschrift ist zu klein
2. „Anderer Name" zeigt den oft überraschend sinnvollen Vorschlag erst an, nachdem man auswählt
3. Titel sollte selektierter sein
4. Was passiert, wenn keine Option ausgewählt ist?

## Klärung durch den PO (2026-09-27)

- **Zu Punkt 1:** Gemeint ist der **Bontext in der Karte** (graue 13-pt-Zeile ganz oben,
  z. B. „Frosch Holzreiniger 750ml") — nicht die Zeile „8 Positionen · 8 ausgewählt · 32,95 €".
- **Zu Punkt 3:** Gemeint war ursprünglich, den **Bontext auf dem Bildschirm markieren und
  per Kopieren/Einfügen weiterverwenden** zu können. Das ging nicht.
  Zusätzlich vom PO freigegeben: der **Bontext soll als eigene, antippbare Option** gelten,
  nicht nur als Beschriftung — dabei **die Schreibweise normalisieren**, weil Bontexte oft
  komplett in Großbuchstaben gedruckt sind.
- Punkte 2 und 4 stehen unverändert.

## Beobachtung aus dem Screenshot (noch zu belegen)

Die erste Karte hat den Haken gesetzt, aber **keine** Auswahlzeile markiert. Damit ist offen,
unter welchem Namen diese Position gespeichert wird (Punkt 4).

## Betroffener Code (erste Sichtung, nicht abschließend)

- `SmartCart/Views/Prices/ReceiptReviewCard.swift` — Auswahlzeilen, Bontext, `selectionOptions`
- `SmartCart/Views/Prices/ReceiptScannerView.swift` — Abschnitts-Kopf und Fußnote der Liste
- Bestehende Specs: `docs/specs/views/receipt-review-card.md` (Issue #23, #37)
