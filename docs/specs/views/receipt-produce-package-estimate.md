---
entity_id: receipt-produce-package-estimate
type: bugfix
created: 2026-10-12
updated: 2026-10-12
status: draft
version: "1.0"
tags: [bugfix, receipt, produce, quantity, lidl]
---

# Bon-Import: Packungsgewicht für abgepacktes Obst und Gemüse schätzen

## Purpose

Lidl verkauft Obst und Gemüse meist abgepackt zum Festpreis. Auf dem Bon steht dann nur
„Bio Trauben kernlos 3,19 A“, ohne Gewichtszeile („0,734 kg x 1,69 EUR/kg“ gibt es nur bei
gewogener Ware). Bisher fiel so eine Zeile auf den Rückfall „1 Stück“: Die Prüfkarte zeigte
„3,19 € · 1 St. · 3,19 € je Stück“, gelernt wurde ein Stückpreis, der Kaufdatensatz bekam „1 /
leer“. Für eine Schale Trauben ist das falsch. Entscheidung (Henning, 12.10.2026): Das
Packungsgewicht wird geschätzt.

## Verhalten

- `ReceiptParserService.producePackageGrams` — Tabelle typischer Packungsgewichte (Trauben 500 g,
  Pflaumen 500 g, Erdbeeren 500 g, Äpfel 1 kg, Kartoffeln 2 kg, Champignons 250 g …).
  Einzeln verkaufte Ware (Gurke, Salat, Brokkoli, Avocado, Melone) steht bewusst nicht darin.
- `ReceiptParserService.estimatedProducePackageGrams(for:)` — vergleicht ganze Wörter des Namens
  mit der Tabelle; nil bei gedruckter Größe im Namen und bei Verarbeitungswörtern („passiert“,
  „Konfitüre“, „Saft“ …). „Traubenzucker“ oder „Kartoffelsalat“ treffen nicht.
- `EditableReceiptLine.estimatedPackageGrams` — die Schätzung für den aufgelösten `name`, nur wenn
  keine Gewichtszeile, keine Stückzahl > 1 und keine Nutzereingabe (`quantityConfirmedByUser`).

Reihenfolge in `learningQuantity`/`learningUnit`/`purchaseRecordQuantity`: Gewichtszeile →
Stückzahl > 1 → Menge des gelisteten Artikels (nur Lernen) → gedruckte Größe → **Schätzung (g)**
→ 1 Stück.

Prüfkarte: „3,19 € · ca. 500 g · 6,38 € je kg“. Der Editor („Ändern“) öffnet auf Gramm mit dem
Schätzwert; jede Eingabe dort (auch „Stück“) setzt `quantityConfirmedByUser` und schaltet die
Schätzung ab.

## Grenzen

- Die Werte sind Schätzungen, gemessen an keinem konkreten Sortiment; abweichende Packungen
  (z. B. Pflaumen 1 kg) muss der Nutzer im Editor korrigieren.
- Öffnen des Editors übernimmt den Schätzwert als Eingabe („ca.“ entfällt danach).
- Ein `PurchaseRecord` speichert nicht, dass die Menge geschätzt ist.

## Tests

`RestockTests/ReceiptSavePurchaseQuantityTests.swift`, Klasse `ReceiptProducePackageEstimateTests`.
