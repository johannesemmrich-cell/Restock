---
entity_id: community-prices
type: module
created: 2026-10-19
updated: 2026-10-20
status: draft
version: "1.0"
tags: [pricing, services, cloudkit, issue-163]
---

# Community-Preise: anonymer Pool in der öffentlichen CloudKit-Datenbank (Weg A)

## Approval

- [ ] Approved

## Purpose

Nutzer sollen sich mit Preisen gegenseitig helfen (PO, 2026-10-18). Bon-Scan und „Preis eintragen“
liefern Artikel, Kette, Preis je Einheit und Datum; mit eingeschaltetem Schalter wandern diese Werte
anonym in einen Pool, aus dem alle Nutzer derselben Kette einen Median als Stufe vor dem Katalog
bekommen. Entscheidungen (Tech Lead) in Issue #163.

## Source

- `SmartCart/Models/CommunityPriceCache.swift` — `CommunityPrice` (Kette, Schlüssel, Aggregat,
  `resolve` für `ShoppingItem.init`), `CommunityPriceCache` (App-Gruppe, `communityPrices.v1`);
  in App-, Widget- und Share-Extension-Ziel.
- `SmartCart/Services/CommunityPriceService.swift` — `CommunityPriceDatabase` (Protokoll, Fake in
  Tests), `CommunityPriceSchema`, `CommunityPriceService` (`contribute`, `refresh`, `apply`,
  `refreshAndApply`); nur App-Ziel.
- `SmartCart/Models/ShoppingItem.swift` — Stufe „community“ in `init`, `priceOrigin`,
  `priceSourceDetail`, `PriceSourceDisplay.text`.
- Schreibstellen: `ReceiptScannerView.save()`, `ActualPriceEntryView.share(_:in:)`.
- Lesestelle: `StoreDetailView.task(id: store.id)` → `refreshAndApply`.
- Schalter: `SettingsView` (`communityPricesSharingEnabled`, `UserDefaults.standard`, Standard **an**
  seit 2026-10-20 auf Wort des PO, vorher aus; `CommunityPriceService.sharingEnabledDefault`, fehlender
  Schlüssel = Standard, nur gespeichertes `false` schaltet ab);
  Datenschutz: `LegalView`, Abschnitt „Community-Preise (optional)“.

## Datenmodell

Record `CommunityPrice`, öffentliche Datenbank, Container `iCloud.com.johannesemmrich.SmartCart`:

| Feld | Typ | Inhalt |
|---|---|---|
| `itemKey` | STRING | Artikelname kleingeschrieben (`learnedPrices`-Schlüssel) |
| `chain` | STRING | erstes Wort des Ladennamens, kleingeschrieben, nur Buchstaben/Ziffern |
| `price` | DOUBLE | Preis je Bezugsgröße |
| `unit` | STRING | `"stk"` oder `"g"` (`learnedPriceUnits`) |
| `observedAt` | TIMESTAMP | Zeitpunkt des Beitrags |
| `clientID` | STRING | zufällige Kennung je Installation (App-Gruppe), keine Apple-ID |

Record-Name = `cp-` + SHA256(`clientID|chain|itemKey`): je Installation, Kette und Artikel genau ein
aktueller Eintrag (Upsert über `serverRecordChanged` → Server-Record aktualisieren).

## Regeln

- Beitrag nur mit Schalter an (Standard an; ausdrückliches Aus gilt), Preis > 0, Kette und Schlüssel nicht leer, Bezugsgröße nicht leer.
- Aggregat: Beobachtungen der letzten 180 Tage, häufigste Bezugsgröße (Gleichstand: alphabetisch
  kleinere), jüngste 20, mindestens 3 → Median; sonst kein Eintrag.
- Stufe in `ShoppingItem.init`: nach eigenem Preis (dieser Laden, anderer Laden), vor Katalog;
  exakter Schlüssel, Entscheidungstabelle `learnedRateUsage`, Obergrenze 200 €. Ergebnis bleibt
  `estimatedPriceIsAutoDerived == true`, Quelle `community:<Kette>`, Datum = jüngste Beobachtung.
- Anzeige: Betrag ohne „ca.“, Quelle „Community · Rewe · 12.10.“; kein „Preis?“.
- `apply` beim Öffnen der Liste ersetzt nur automatisch hergeleitete, offene Preise; verliert ein
  Artikel sein Aggregat, fällt er auf Katalog/Pauschale zurück. `CatalogEstimateRefresh` fasst
  Community-Preise nicht an.
- Fehler (Netz, fehlendes Production-Schema) werden protokolliert (`os.Logger`, Kategorie
  `community`), nie gezeigt.

## Tests

`RestockTests/CommunityPriceTests.swift`: Kette/Schlüssel, Aggregat (Mindestzahl, Frist, Median
gerade/ungerade, jüngste 20, Bezugsgrößen-Mehrheit), Zwischenspeicher, Schreiben (Schalter aus →
nichts, Schlüssel fehlt → Standard an → Beitrag, Felder, deterministischer Name, Upsert, `serverRecordChanged`, Netzfehler), Lesen (Aggregat,
Entfernen, Fehler lässt Zwischenspeicher stehen), Stufe in `init` (Rangfolge, Einheit, Obergrenze),
`apply`, Schema-Drift gegen `docs/cloudkit/private-schema-aktuell.ckdb`, Texte.

## Offene Grenzen

- Kein echter Schreib-/Lesetest gegen CloudKit; Production-Schema muss vor dem TestFlight-Upload
  deployt werden (`docs/testflight-setup.md`).
- Exakter Schlüssel: „Skyr“ findet „skyr natur 500g“ nicht; Beiträge laufen deshalb unter dem Namen
  des gemeinten Artikels, nicht unter dem Bontext.
- Kein Hinweis nach dem ersten Bon-Scan, keine Region, kein Missbrauchsschutz über Median und
  Obergrenze hinaus; Weg B (Open Prices beitragen) als Folge-Issue.
- Nichts auf Hennings Geräten geprüft.
