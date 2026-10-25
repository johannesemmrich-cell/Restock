# Adversary Dialog — feat-175-b3-asc-betrieb
Spec: docs/specs/appstore/app-store-auftritt.md
Datum: 2026-10-25

## Checkliste
- [x] **AC-23:** Gegenleser meldet keine Falschmeldungen mehr (gilt, weil AC-23a bis AC-23e gelten).
- [x] **AC-23a:** `fetch_privacy` sendet `User-Agent: Restock-asc-check/1.0`, kein `Authorization`, nur die eine URL.
- [x] **AC-23b:** Altersfreigabe ist nur „ok“, wenn alle 24 Pflichtfelder gesetzt sind; sonst Abweichung mit Feldliste.
- [x] **AC-23c:** Preisplan der App: Plan-ID aus der Antwort, Basisland DEU, genau ein gültiger Betrag 0; 404 an manualPrices ist „nicht eingerichtet“.
- [x] **AC-23d:** 404 an appAvailabilityV2 ist die Abweichung „nicht eingerichtet“; jedes andere 404 (außer manualPrices, AC-23c) und 403/500 bleiben Fehler.
- [x] **AC-23e:** Zaun lässt nur baseTerritory (ohne Abfrage) und manualPrices (exakte Abfrage) mit Plan-ID aus einer Antwort zu; Bestand AC-20 bis AC-22g grün.
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-1 bis AC-8** — nicht Gegenstand von B3b
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-9, AC-9a bis AC-9e** — nicht Gegenstand von B3b (`test_asc_texts.py` grün: 10 Tests OK)
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-10, AC-10a bis AC-10h** — nicht Gegenstand von B3b (`test_asc_scripts.py` grün: 15 Tests OK)
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-11 bis AC-19, AC-17a** — nicht Gegenstand von B3b (Betrieb in B3)
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-20, AC-20a bis AC-20g, AC-21** — nicht Gegenstand von B3b; Bestand, in `test_asc_check.py` grün
- (außerhalb B3b, kein Nachweis in diesem Durchgang) **AC-22, AC-22a bis AC-22g** — nicht Gegenstand von B3b; Bestand, in `test_asc_check.py` grün

## Dialog

### Runde 1
Alle drei Suiten grün: `test_asc_check.py` „Ran 39 tests … OK“, `test_asc_scripts.py` 15 OK, `test_asc_texts.py` 10 OK. Bestand AC-20 bis AC-22g damit grün (u. a. `test_source_bans`, `test_fence_rejects_before_send`, `test_today_is_injectable`).

Confirmation:
  AC: AC-23a
  Code reference: scripts/asc_check.py:100
  Evidence: `fetch_privacy` setzt `User-Agent: Restock-asc-check/1.0`, weist jede andere URL mit ValueError ab, kein Authorization; `urllib_send` folgt keiner Weiterleitung, ein 3xx kommt als Status zurück.
  Code reference: scripts/test_asc_check.py:519
  Status: CONFIRMED (Schein-`send` liefert ohne den Kopf 403, Test grün)

Confirmation:
  AC: AC-23b
  Code reference: scripts/asc_check.py:214
  Evidence: `check_age` wertet nur `None`/fehlend als leer; `false` und `"NONE"` gelten als beantwortet. Bei lauter `null` alle 24 Namen in Listenreihenfolge; ohne `attributes` identisch (geprobt). Echter Lauf 3 zeigt genau diese Zeile.
  Code reference: scripts/test_asc_check.py:529
  Status: CONFIRMED

Confirmation:
  AC: AC-23c
  Code reference: scripts/asc_check.py:224
  Evidence: Plan-ID aus `plan["id"]`, nie die App-ID. Geprobt: Basisland `deu`/USA → Abweichung; kein Plan → Abweichung; fehlender Preispunkt → „Preispunkt fehlt“; abgelaufener Eintrag → „kein gültiger Preis“; `endDate == heute` gültig; 0.0 und 1.99 → Abweichung; 404 an manualPrices → „Ist nicht eingerichtet“, Abschnitt läuft weiter; 403/500 dort bleiben Fehler.
  Code reference: scripts/test_asc_check.py:596
  Status: CONFIRMED

Confirmation:
  AC: AC-23d
  Code reference: scripts/asc_check.py:206
  Evidence: Nur `HttpError` 404 an appAvailabilityV2 wird zur Abweichung, andere Status werden weitergeworfen. 404 an baseTerritory, appPriceSchedule, primaryCategory, ageRatingDeclaration bleibt „Fehler appinfo: HTTP 404 bei GET <Pfad>“ (geprobt, `test_404_on_other_path_stays_error`). Meldung nur Status und Pfad ohne Abfrage.
  Code reference: scripts/test_asc_check.py:585
  Status: CONFIRMED

Confirmation:
  AC: AC-23e
  Code reference: scripts/asc_check.py:49
  Evidence: Genau zwei neue Zaunmuster; baseTerritory ohne Abfrage, manualPrices nur `APP_PRICE_QUERY`. Vor `send` abgelehnt (geprobt): URL-kodierte Abfrage (`%26`, `%5B`), `&x=1`, nacktes `?`, `../`, `#fragment`, Zeilenumbruch am Ende, fremde Plan-ID, `automaticPrices`, Listenpfad, POST, PATCH.
  Code reference: scripts/test_asc_check.py:618
  Status: CONFIRMED

Early-Agreement-Skepsis: Beweise aus eigenen Proben mit dem FakeASC des Testmoduls, nicht aus Testnamen; Randfälle in Runde 2.

### Runde 2
Gezielte Angriffe auf die Grenzen der Regeln.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:221
  Description: `check_age` zählt nur `None` als leer; ein Pflichtfeld mit `""` gilt als beantwortet (geprobt: `lootBox=""` → „ok“).
  Spec requirement: AC-23b — „nur `null` oder fehlend gilt als leer“
  Conflict: Kein Konflikt; Apple liefert Booleans oder Enums, leerer String unrealistisch.
  Remediation: Optional; kein Blocker.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:239
  Description: `distinct == {Decimal(0)}` wertet die Menge der Beträge; zwei gültige Einträge mit 0 ergeben „ok“. Gleiches Verhalten wie `check_price` aus B3a.
  Spec requirement: AC-23c — „genau einem gültigen Betrag 0“
  Conflict: Mehrdeutig; gemeint ist „genau ein verschiedener Betrag“. Praktisch unschädlich, beide Einträge sind 0.
  Remediation: Wortlaut bei Gelegenheit klarstellen; kein Blocker.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:403
  Description: Unerwartete Antwortformen (Plan ohne `id`, Betrag `"free"`) brechen `appinfo` mit kryptischer Meldung ab; Exit bleibt 1, keine Falschmeldung „ok“.
  Spec requirement: AC-23c/AC-20e
  Conflict: Nur Lesbarkeit, keine Apple-Form.
  Remediation: Optional klarere Meldung.

Weitere Proben ohne Befund: Verfügbarkeit 404 und manualPrices 404 zugleich → beide Abweichungen; 0 plus fehlender Preispunkt → Abweichung; Ganzzahl 0 und "0.0" gelten als 0; Reihenfolge der Feldliste durch `test_age_rating_names_missing_field` abgesichert.

Confirmation:
  AC: AC-23
  Code reference: scripts/asc_check.py:72
  Evidence: `HttpError` trägt Status, Meldung nur Status plus Pfad. Echter Lauf 3 (`asc-check-lauf-3-2026-10-25.txt`): „ok privacy-url: HTTP-Status“ (nur Inhaltsabweichung), Altersfreigabe Abweichung, App-Preis „nicht eingerichtet“, Verfügbarkeit „nicht eingerichtet“, kein „Fehler“. „Basisland: Soll DEU, Ist USA“ ist ein echter Konfigurationsbefund.
  Code reference: scripts/test_asc_check.py:596
  Status: CONFIRMED

Regressionen: keine; `HttpError` ist Unterklasse von RuntimeError, Meldungstext unverändert.
Nicht prüfbar ohne Netz: ob Apple 404 für „nicht eingerichtet“ liefert; in Known Limitations B3b benannt, durch Lauf 2 und 3 belegt.

VERDICT: VERIFIED
Tests: test_asc_check 39 bestanden, 0 fehlgeschlagen; test_asc_scripts 15 OK; test_asc_texts 10 OK. Drei LOW-Befunde ohne Falschmeldung „ok“ im realistischen Fall. Checkliste 6/6 (AC-23 bis AC-23e) bewiesen.

## Geprüfte Dateien

- sha256:9f7f05a7bf6ee6b4b1e37e9b1e399964ad89aa58e6b95fa970d6133556169506  scripts/asc_check.py
- sha256:1ad9cb07b1fd684e5f5b2c4609324034ef66e642710d545df2c18cb22acce655  scripts/test_asc_check.py

## Prüfbasis

- base: 97dceea9250bbe2bd3d9683105fa94297ca49dbb
- blob:697e21b7edb896dcdd7ed915dbfcceba5b34666a  scripts/asc_check.py
- blob:116f766ce8c92ec1a14d573824fa054ae2e2717d  scripts/test_asc_check.py
