---
entity_id: open-prices-contribution
type: module
created: 2026-10-22
updated: 2026-10-22
status: draft
version: "1.0"
tags: [pricing, services, open-prices, issue-184, issue-163]
---

# Preise an Open Prices beitragen (Weg B): Opt-in, Konto, Filiale, Nachweis — bis Pre-Production

## Approval

- [ ] Approved

## Ziel (Issue #184, Folge von #163)

Beim Bon-Scan erkannte Preise zusätzlich an Open Prices (Open Food Facts) beitragen, damit sie allen
helfen. Open Prices verlangt ein OFF-Konto (Bearer-Token), einen Nachweis (Bonfoto, Typ `RECEIPT`,
CC BY-SA, also öffentlich), die Filiale als OpenStreetMap-Ort und je Preis Barcode **oder**
OFF-Kategorie (`category_tag` + `price_per`). Dieser Durchgang baut den vollständigen Weg gegen die
**Pre-Production-Umgebung** (`prices.openfoodfacts.net`); nach Production geht nichts, bis der
Nachweis (unten) vorliegt und `OpenPricesContribution.environment` umgestellt wird.

## Entscheidungen

- **Eigener Opt-in-Schalter, Standard aus**, unabhängig vom Community-Schalter (#163): „Bons an Open
  Prices beitragen“ mit Hinweis beim Einschalten (Bonfoto öffentlich, persönliche Angaben abdecken,
  Preise unter dem OFF-Namen). Ausschalten sofort.
- **Konto:** Nutzername/Passwort in den Einstellungen → `POST /auth` → Token im Schlüsselbund
  (`KeychainTokenStore`, nur dieses Gerät, `AfterFirstUnlockThisDeviceOnly`); Nutzername in
  `UserDefaults`. Abmelden löscht beides.
- **Filiale je Laden:** Nominatim-Suche (`NominatimClient`, eigener `User-Agent`, nur auf Tipp),
  gemerkt in `OpenPricesLocationStore` (`UserDefaults`, kein neues gespiegeltes Feld am `Store`).
- **Zeilen:** nur Bonzeilen, deren Name einen Katalogeintrag mit OFF-Kategorie trifft
  (`PriceCatalogEntry.offCategory`, Quelle `data/price-catalog/off-categories.json`, 218 Lebensmittel);
  Gewichtszeilen als Preis je Kilogramm, sonst je Stück. Zeilen ohne Kategorie werden übersprungen
  und nur gezählt. Keine Zeile beitragbar → kein Foto-Upload.
- **Ablauf:** Nachweis zuerst (`POST /proofs/upload`, multipart: `file`, `type=RECEIPT`,
  `location_osm_id/type`, `date`, `currency`, `receipt_price_count`, `receipt_price_total`), dann je
  Preis `POST /prices` mit `proof_id`. Scheitert der Nachweis, geht kein Preis hinaus. Fehler werden
  protokolliert (`os.Logger` `openprices`) und als Zähler gespeichert (Einstellungen „Letzter
  Beitrag“), nie als Dialog gezeigt. Alle Aufrufe mit `app_name=Restock&app_version=…`.
- **Bild:** nur der Foto-Weg in `ReceiptScannerView` (JPEG 0,8); die Übergabe aus der
  Teilen-Erweiterung bringt kein Bild mit → `.noImage`, kein Beitrag.

## Quelle

- `SmartCart/Services/OpenPricesContributionService.swift` — `OpenPricesEnvironment`, `OpenPricesLocation`,
  `OpenPricesProofUpload`, `OpenPricesPriceUpload` (`body`), `OpenPricesAPI`/`OpenPricesClient`
  (`multipartBody`, `formBody`, `url`), `OpenPricesTokenStore`/`KeychainTokenStore`/`InMemoryTokenStore`,
  `OpenPricesLocationStore`, `PlaceSearchAPI`/`NominatimClient` (`parse`), `OpenPricesContribution`
  (Schlüssel, `readiness`, `pricePer`, `plan`, Texte), `OpenPricesLastResult`, `OpenPricesContributionService`
  (`login`, `logout`, `contribute`, `contributeInBackground`, `readiness(for:hasImage:)`).
- `SmartCart/Views/Settings/OpenPricesSettingsView.swift` — Schalter mit Hinweis, Konto, Filialen, letzter
  Beitrag; `OpenPricesPlaceSearchView` (Nominatim).
- `SmartCart/Views/Settings/SettingsView.swift` — Eintrag „Open Prices“ unter „Funktionen“.
- `SmartCart/Views/Prices/ReceiptScannerView.swift` — `receiptImageData` aus `process`, Aufruf am Ende von `save()`.
- `SmartCart/Views/Settings/LegalView.swift` — Absatz „Open Prices (nur nach ausdrücklicher Anmeldung)“.
- `data/price-catalog/off-categories.json`, `scripts/build-price-catalog.py` (emittiert `off:`),
  `scripts/check-off-categories.py` (Taxonomie-Prüfung, braucht Netz), `SmartCart/Models/PriceCatalog.swift`
  (`offCategory`).
- Texte `settings.openprices.*` (21 Schlüssel, de/en).

## Nachweis gegen Pre-Production (offen, braucht Netz zu `prices.openfoodfacts.net`)

Vor dem Wechsel auf Production (und als Antwort auf die offenen Fragen aus dem Issue) mit `curl`:

```bash
B=https://prices.openfoodfacts.net/api/v1
curl -sS "$B/status"
curl -sS -X POST "$B/auth" -d "username=$OFF_USER" -d "password=$OFF_PASS"        # → access_token
curl -sS -X POST "$B/proofs/upload?app_name=Restock" -H "Authorization: Bearer $T" \
  -F file=@bon.jpg -F type=RECEIPT -F location_osm_id=123 -F location_osm_type=NODE -F date=2026-10-22 -F currency=EUR
curl -sS -X POST "$B/prices?app_name=Restock" -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
  -d '{"category_tag":"en:milks","price":1.19,"price_per":"UNIT","currency":"EUR","location_osm_id":123,"location_osm_type":"NODE","date":"2026-10-22","proof_id":1}'
curl -sS -X POST "$B/prices?app_name=Restock" ... ohne proof_id                   # Frage 1: wird ein Preis ohne Nachweis angenommen?
```

Festzuhalten als Artefakt `docs/artifacts/feat-184-open-prices/pre-production-nachweis.md`: Antworten
(Status, Feldnamen, ob `proof_id` Pflicht ist, Rate-Limits aus den Headern), danach
`scripts/check-off-categories.py --write` für die Kategorien. Stichprobe „wie viele Bonzeilen lassen sich
ohne EAN zuordnen“: mit den Testbons dm/Lidl/Rewe über `OpenPricesContribution.plan` (Unit-Test P1 zeigt
den Mechanismus; die Zahl folgt mit dem Nachweis).

## Tests

`RestockTests/OpenPricesContributionTests.swift`: P1–P5 Plan (Kategorie, UNIT/KILOGRAM, Überspringen,
kein Plan ohne Zeile, Datum, Rundung, Feldnamen), B1 Bereitschaft (Reihenfolge der Gründe, Standard aus,
Pre-Production), S1–S5 Dienst (Anmeldung/Abmeldung, Nachweis vor Preisen mit `proof_id`, Nachweisfehler
→ keine Preise, Preisfehler gezählt, aus/abgemeldet/ohne Filiale → nichts), C1–C3 Client-Körper
(Multipart, Formular, URLs mit `app_name`), L1–L2 Filialspeicher und Nominatim-Parser, Schlüssel,
Katalog-Tags nur für Lebensmittel.

## Offene Grenzen

- API-Form aus der Projekt-Doku, **nicht** gegen Pre-Production belegt (Netz gesperrt am 2026-10-22);
  `OpenPricesAPIError.badStatus` macht Abweichungen in den Einstellungen sichtbar („HTTP 422 …“).
- OFF-Kategorien aus dem Gedächtnis der Taxonomie (`verified: false`), Prüfung per Skript offen.
- Kein Rate-Limit-Schutz über „ein Bon je Speichern“ hinaus; kein Wiederholen nach Netzfehler.
- Schlüsselbund im Unit-Test nicht geprüft (In-Memory-Speicher), nur auf dem Gerät.
- Kein UI-Test; nichts auf Hennings Geräten geprüft. Production bleibt ein eigener Schritt.
