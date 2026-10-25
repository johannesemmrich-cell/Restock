# Context: feat-175-b3-asc-betrieb

## Request Summary
Issue #175, Durchgang B3 (Betrieb): Version 1.0 in App Store Connect nach der freigegebenen Spec ausfüllen und gegenlesen –
Produktseite de/en, Käufe, Kategorien, Altersfreigabe, App Privacy, Screenshots, Build 37, Review-Kontakt. Kein Quellcode;
jeder außenwirksame Schritt einzeln auf Hennings Wort. Vorgänger B3a (Lesepfade nach API 4.5.1) ist mit PR #223 im Hauptstand.

## Stand am 2026-10-25 (geprüft zu Beginn dieses Workflows)
- `asc_check.py` (B2b + B3a) und `asc_publish.py` (B2a) sind im Hauptstand, nur gegen Schein-Antworten getestet; **noch kein
  einziger Lauf gegen Apple**, auch kein lesender.
- ASC-Schlüssel: `/Users/hem/Developer/AuthKey_K928C9Z9P2.p8` vorhanden (Rechte 600, Inhalt nie lesen); Key-ID `K928C9Z9P2`,
  Issuer-ID `6c350cda-a185-45ac-a852-70e84119b6f1` (Memory `lokaler-upload-mit-api-schluessel`). Das ältere Kontextdokument
  nannte Downloads – überholt.
- Datenschutzseite `https://emmrich-business.com/datenschutz`: HTTP 200, weiterhin alter Text (kein „Community“, kein „Open Prices“,
  keine englische Fassung). Pflegt ein Dritter (PO 2026-10-25) → AC-12, AC-19 blockiert.
- Build: `CURRENT_PROJECT_VERSION` = 37 in `project.yml`/`project.pbxproj`; letzter Upload Build 36 (2026-10-22). Build 37 nicht hochgeladen → AC-17 offen.
- #215 (Paywall ohne Rechtslinks) offen – Ablehnungsrisiko, nicht Teil von B3.
- Produktkennungen `SmartCart/Services/PremiumService.swift:124-126`: `com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}`.
- Zustand des Entwurfs in ASC (Version 1.0, appInfo, Käufe, Abo-Gruppe): unbekannt.

## Ablauf laut Spec (Abschnitt „Durchgang B3“)
1. Lesetrockenlauf `python3 scripts/asc_check.py --all` (nur GET)
2. `asc_publish` Trockenlauf (Plan sichten)
3. `asc_publish --apply` – **Wort nötig**
4. Browser (Chrome): drei Käufe, Abo-Gruppe „Restock Pro“, Basisland DEU, Preise 1,99/8,99/14,99, Kategorien, Altersfreigabe,
   Content Rights, Preise/Verfügbarkeit, Review-Kontakt, App Privacy – **je Schritt Wort**; Käufe anlegen ist unumkehrbar
5. Screenshots 1320×2868 aus dem Simulator (`-premiumForScreenshots`, `-seedSharedAssignmentForScreenshots`), Vorschau de/en an
   Henning, dann Upload – **Wort nötig**
6. Build 37 per `testflight.yml` (`build_number=37`), Zuordnung zu Version 1.0 – **Wort nötig**
7. Schlusslauf `asc_check --all` → `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt`

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_check.py` | Gegenleser (nur GET, eigener Zaun), Abschnitte metadata/privacy-url/appinfo/iap/screenshots/build/review/status |
| `scripts/asc_publish.py`, `scripts/asc_lib.py` | Schreibt Texte de-DE/en-US, Trockenlauf Standard, `--apply` |
| `docs/appstore/{de,en}.md`, `docs/appstore/datenschutz.md` | Sollwerte; Datenschutztext zum Weitergeben |
| `docs/specs/appstore/app-store-auftritt.md` | AC-11 bis AC-19, Abschnitt B3, Privacy-Tabelle, Offene Grenzen |
| `SmartCart/Services/PremiumService.swift:124-126` | Produktkennungen |
| `SmartCart/SmartCartApp.swift` | Screenshot-Seed |
| `.github/workflows/testflight.yml` | Upload Build 37 (`build_number`, `dry_run`) |
| `docs/artifacts/feat-175-app-store-auftritt/` | Belegordner |

## Existing Patterns
- Trockenlauf zuerst, Schreiben nur mit `--apply`; Gegenlesen mit `asc_check` als Beleg (Zeitstempel + Commit).
- OpenAPI 4.5.1 als Referenz vor jedem ASC-Lauf neu laden (Memory `asc-openapi-referenz`).
- Screenshots per `simctl io … screenshot` auf Wegwerf-/eigenem Simulator, Sperren `/tmp/heavy-build.lock` + `/tmp/loose-ends-testlauf.lock`.
- Vorschau-Regel: Screenshots samt Bildunterschriften als Artefakt-Seite vor dem Upload.
- TestFlight-Upload: „Was testen?“-Text vorher Henning zeigen (Memory `testflight-was-testen-pflicht`).

## Dependencies
- Upstream: ASC API 4.5.1, Schlüssel, öffentliche Datenschutzseite (Dritter), GitHub-Ablauf `testflight.yml`.
- Downstream: Einreichung 1.0 (nicht Teil von B3), Release-1.0-Meilenstein, #215.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md`
- `docs/specs/ci/testflight-upload-workflow.md`

## Risks & Considerations
- Erster echter Lauf: echte Antworten können vom Fake abweichen → Skriptkorrektur wäre Code (eigener kleiner Durchgang mit Test), nicht im Betrieb nebenbei.
- Unumkehrbar: Produktkennungen, Abo-Gruppe; Basisland des Preisplans.
- Name/Untertitel im appInfo evtl. nicht änderbar (unbelegt).
- App Privacy nur per Browser, Beleg-Screenshots im Zustand „Veröffentlicht“.
- Belege (Screenshots) könnten im LoC-Gate als Dateien zählen.
- Nichts auf Hennings Geräten.
- Workflow-Phasen TDD RED/GREEN passen schlecht auf reinen Betrieb – in der Analyse festlegen, was als „Test“ gilt (asc_check-Abschnitte als Nachweis).

## Analysis

### Type
Feature (Betrieb) mit vorgeschaltetem Werkzeug-Fix. Dieser Workflow trägt zuerst **B3b** (Code + Tests, passt auf TDD RED/GREEN);
die außenwirksamen Betriebsschritte folgen danach, je Schritt auf Hennings Wort.

### Erster echter Leselauf (2026-10-25 12:15 UTC, Commit eac705e, nur GET)
Protokoll: `docs/artifacts/feat-175-b3-asc-betrieb/asc-erstlauf-2026-10-25.txt`. OpenAPI vorher neu geladen: weiterhin 4.5.1.
- Entwurf fast leer: nur `name (de-DE)` ok und Status `PREPARE_FOR_SUBMISSION`. Es fehlen: en-US-Lokalisierungen (Version und appInfo),
  alle Texte de-DE (Beschreibung, Schlüsselwörter, Werbetext, Support-URL, Untertitel, Datenschutz-URL), Kategorien, Content Rights,
  Abo-Gruppe und alle drei Käufe, Screenshots, Build, Review-Kontakt. Auth, Zaun und Lesepfade funktionieren gegen Apple.
- **F1 (Falschmeldung):** `privacy-url` meldet HTTP 403. Ursache belegt: die Seite sperrt den User-Agent `Python-urllib/3.15`;
  `curl/8`, Browser-UA, `Restock-asc-check/1.0` und `asc_check` liefern 200. `fetch_privacy` sendet leere Header.
- **F2 (falsches „ok“):** `ageRatingDeclaration` meldet ok, obwohl alle Antwortfelder `null` sind (nur Overrides `NONE`); Apple legt die
  Ressource automatisch an, `Report.present` prüft nur Existenz. `appPriceSchedule` ebenso: Ressource-ID = App-ID, existiert immer,
  `manualPrices`/`baseTerritory` werden nicht gelesen.
- **F3 (Abbruch statt Abweichung):** `GET /v1/apps/{id}/appAvailabilityV2` → 404 (Pfad steht in 4.5.1); vermutlich „noch nicht
  eingerichtet“ (Recherche ohne Apple-Beleg, nur Muster in Foren). Das Skript bricht den Abschnitt als „Fehler“ ab.
- Datenschutzseite inhaltlich weiter alt (0 Treffer „Community“/„Open Prices“); AC-12/AC-19 warten auf den Dritten.

### Affected Files (B3b)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_check.py` | MODIFY | F1 eigener User-Agent in `fetch_privacy`; F2 Altersfreigabe: Antwortfelder ausgefüllt, Preisplan: `baseTerritory` + `manualPrices` lesen (Zaun-Leseliste ergänzen); F3 404 nur für `appAvailabilityV2` → „Abweichung: nicht gesetzt“, kein pauschales 404 = leer |
| `scripts/test_asc_check.py` | MODIFY | Tests mit echten Antwortformen: alle Felder null, 404 Verfügbarkeit, gesendeter User-Agent, Preisplan ohne manualPrices |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | Abschnitt B3b, ACs, Leseliste, Offene Grenzen |

### Scope Assessment
- Files: 3 · Estimated LoC: ~+60 bis +90 (inkl. Tests) · Risk Level: LOW (nur lesendes Werkzeug, ohne Netz getestet)
- Betrieb danach: ~0 LoC, Risiko HOCH an den unumkehrbaren Stellen (Produktkennungen, Abo-Gruppe, Basisland).

### Technical Approach
1. B3b (dieser Workflow): F1–F3 im Gegenleser beheben, Tests zuerst; danach Leselauf wiederholen (erwartet: privacy-url 200 mit
   Inhaltsabweichung, Altersfreigabe/Preisplan/Verfügbarkeit als Abweichung statt ok/Fehler).
2. Betrieb, je Schritt auf Wort, Reversibles zuerst: `asc_publish` Trockenlauf → `--apply`; Browser: Kategorien, Altersfreigabe,
   Content Rights, Verfügbarkeit/Preis, Review-Kontakt, App Privacy; dann Käufe (Kennungen vorher gegen
   `PremiumService.swift:124-126`); Screenshots mit Vorschau; Build 37; Schlusslauf.
- Alternative A: Betrieb zuerst, B3b am Ende — schneller, aber Zwischenläufe zeigen falsches „ok“ (F2) und der Browser-Beleg müsste
  die Kontrolle ersetzen. Verworfen.
- Alternative B: nur F1+F3 jetzt (~15 LoC), F2 später — F2 ist der gefährlichste Fehler (falsches Grün). Verworfen.
- Kippt: Spec-Aussage „B3 ändert keinen Quellcode“ gilt weiter für B3; B3b ist ein neuer, kleiner Code-Durchgang davor.

### Dependencies
- B3b: keine. Betrieb: Hennings Wort je Schritt; AC-12/AC-19 Datenschutzseite (Dritter, Text `docs/appstore/datenschutz.md`);
  AC-17 Upload Build 37; Screenshots unter beiden Simulator-Sperren.
- Restrisiko: Kaufpfade v2/Preisplan sind erst nach dem (unumkehrbaren) Anlegen der Käufe gegen Apple prüfbar.

### Open Questions
- keine PO-Frage für B3b (rein technisch). Entscheidungen im Betrieb (Altersfreigabe-Antworten, Verfügbarkeit, Review-Kontaktdaten)
  werden dort einzeln vorgelegt.
