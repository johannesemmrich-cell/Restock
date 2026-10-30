---
entity_id: b3-betrieb-restschritte
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
version: "1.0"
workflow: feat-175-b3-betrieb
tags: [feature, appstore, betrieb, release-1-0, issue-175]
---

# App Store Auftritt, Durchgang B3: Restschritte im Betrieb (Issue #175)

## Approval

- [ ] Approved

Fortschreibung von `docs/specs/appstore/app-store-auftritt.md` (Abschnitt „Durchgang B3“). Die Haupt-Spec ist nach
`phase8_complete` für Edits gesperrt (nur Changelog); maßgeblich für die Restschritte ist diese Datei. Die Acceptance
Criteria AC-12 und AC-15 bis AC-19 der Haupt-Spec gelten unverändert und werden hier nicht neu verhandelt.
Quelle: `docs/context/feat-175-b3-betrieb.md`.

## Purpose

Version 1.0 ist in App Store Connect einreichbar, wenn `asc_check --all` mit Exit 0 endet (AC-19). Erledigt sind Texte
(de-DE/en-US), Kategorien, Altersfreigabe, Content Rights, Basisland, App-Preis, Verfügbarkeit, Review-Kontakt und der
App-Privacy-Fragebogen. Offen sind fünf Punkte: Screenshots, drei Käufe, Build 37, Datenschutzseite, Schlusslauf. Diese
Spec legt Reihenfolge, Regeln und Nachweise dieser Restschritte fest. Es ändert sich kein Quellcode und nichts an der App.

Hat es bisher funktioniert? Ja; es ist keine Störung, sondern Restarbeit (Stand: Lauf vom 2026-10-27/28).

## Source

- `docs/specs/appstore/app-store-auftritt.md` (ACs 12, 15–19, Abschnitt B3)
- `scripts/asc_check.py` (nur lesen), `SmartCart/Services/PremiumService.swift:124-126`, `Restock.storekit`
- `docs/appstore/{de,en,datenschutz}.md`, `.github/workflows/testflight.yml`, `docs/testflight-setup.md`

## Dependencies

| Art | Abhängigkeit | Stand |
|-----|--------------|-------|
| Upstream | Konto von Henning in App Store Connect (Browser) | vorhanden |
| Upstream | `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH` für Lesenläufe (Schlüsselinhalt wird nie gelesen) | beim Lauf zu setzen |
| Upstream | Simulator „iPhone 17 Pro Max“ (Wegwerf), beide Sperren | beim Lauf anzulegen |
| Blocker extern | Datenschutzseite pflegt ein Dritter (AC-6) | offen |
| Blocker extern | Build 37 lädt Henning hoch (AC-5) | offen |
| Downstream | Einreichbarkeit von 1.0, Meilenstein #35 #75 #99 #145 #175; Einreichen selbst nicht Teil davon | – |

## Scope

- **Affected Files:** 0 Quelldateien; Belege unter `docs/artifacts/feat-175-app-store-auftritt/` (`screenshots/{de,en}/*.png`, `asc-readback.txt`) und `docs/artifacts/feat-175-b3-betrieb/`; optional `scripts/make-store-screenshots.sh`.
- **Estimated Changes:** ~0 LoC Produktivcode (optional ~100 Zeilen Hilfsskript), Rest Protokolle und Binärbilder.

Kein Quellcode. Dateien nur als Belege unter `docs/artifacts/` (Bilder, Protokolle) und gegebenenfalls ein Hilfsskript
`scripts/make-store-screenshots.sh` (~100 Zeilen, nur wenn die Aufnahme wiederholbar sein soll; sonst entfällt es).
Außerhalb des Repos: Screenshots, Abo-Gruppe und drei Käufe in App Store Connect.

Nicht im Umfang: Einreichen („Submit for Review“), Paywall-Rechtslinks (#215), Änderungen am Werkzeug `asc_check`/`asc_lib`
(Korrektur wäre ein eigener Durchgang mit Test), alles auf Hennings Geräten.

## Implementation Details

Reihenfolge und Regeln (verbindlich):

1. **Screenshots erzeugen (lokal, ohne Außenwirkung).** Wegwerf-Simulator „iPhone 17 Pro Max“ (1320×2868; `Restock-Validate*` bleibt
   unberührt), beide Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` per Skript, Statusleiste per
   `simctl status_bar override` (9:41), gesäte Testdaten ohne echte Namen und Fotos, `-premiumForScreenshots`, je Bild das
   passende Aufräum-Argument. Fünf Bilder je Sprache: Startseite mit Läden, Einkaufsliste, Schnell-hinzufügen mit Ladenvorschlag,
   Bon-Prüfung, Pro-Übersicht. Ohne Sprachmodell, reine Aufnahme.
2. **Vorschau an Henning:** Bilder samt Bildunterschriften de/en (Text in der Vorschau, nicht ins Bild gebrannt) als Artefakt-Seite.
   Erst nach seiner Freigabe oder Korrektur folgt der Upload.
3. **Screenshot-Upload** per Browser, auf Hennings getipptes Wort. Beleg: `asc_check --section screenshots`.
4. **Datenschutzseite (AC-12):** Claude liefert den Text aus `docs/appstore/datenschutz.md` zum Weitergeben an den Dritten; Prüfung
   danach nur lesend (`--section privacy-url`).
5. **Build 37 (AC-17):** Vorher prüft Claude das CloudKit-Produktionsschema (CLAUDE.md, #151/#163/#155) und meldet das Ergebnis.
   Der Upload läuft über `testflight.yml` mit `build_number=37` auf Hennings Wort (Freigabepflicht der Umgebung `testflight`).
   Zuordnung zu Version 1.0 anschließend lesend belegt.
6. **Käufe zuletzt (AC-15):** Kennungen unumkehrbar. Unmittelbar vorher werden `com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}`
   erneut gegen `PremiumService.swift:124-126` und `Restock.storekit` gelesen; Gruppe „Restock Pro“; Monatsabo 1,99 €, Jahresabo 8,99 €,
   lifetime (nicht verbrauchbar) 14,99 €; Texte de/en; ein Review-Screenshot je Produkt; `sharedlists` steht nur in der lokalen Testdatei `Restock.storekit` und wird in App Store Connect nicht angelegt.
7. **Schlusslauf (AC-19):** `python3 scripts/asc_check.py --all`, Ausgabe unverändert als `asc-readback.txt`.

Regeln für jeden außenwirksamen Schritt (3, 5, 6): Claude nennt per Auswahlfrage genau, was geschrieben wird, und führt erst nach
Hennings getippter Zeile für genau diesen Schritt aus; ein Wort gilt nie für den nächsten. Nach jedem Schritt läuft
`asc_check --section <passend>` als Beleg (vorher committen, dann Echtlauf; Zeit und Commit im Kopf). Weicht der Ist-Zustand ab,
wird gestoppt und berichtet; das Werkzeug wird im Betrieb nicht geändert.

Die fünf unveröffentlichten Beleg-Commits des Vorgänger-Zweigs werden vor einem PR per cherry-pick auf einen frischen Zweig
gesichert (kein Rebase; Autor-/Noreply-Problem bleibt zu beachten, kein Umschreiben ohne Hennings Wort).

## Expected Behavior

- **Input:** Hennings getippte Freigaben je außenwirksamem Schritt.
- **Output:** ASC enthält je Sprache 3–10 Screenshots, Abo-Gruppe und drei Käufe, Build 37 ist Version 1.0 zugeordnet;
  `asc_check --all` endet mit Exit 0; Beleg-Screenshot zu AC-14 liegt vor.
- **Side effects:** außenwirksam nur Screenshots, Käufe, Build-Upload; nichts wird eingereicht, nichts auf Hennings Geräten.

## Alternativen (zum bisherigen Weg)

1. **Screenshots mit Marketing-Rahmen** (Gerätekontur, Titelzeile im Bild): optisch stärker, aber eigener Gestaltungsdurchgang,
   je Sprache doppelt zu pflegen; kippt die Annahme „reine Simulator-Aufnahme“ in AC-16.
2. **Nur drei Bilder je Sprache** (Minimum): schneller, weniger Fläche für die Funktionen.
3. **Aufnahme per XCUITest-Anhang statt Skript:** wiederholbar in CI, aber mehr Aufwand und Last; sinnvoll erst, wenn die Bilder
   später oft zu aktualisieren sind.
4. **Käufe per API anlegen:** bereits als Alternative 15 der Haupt-Spec verworfen (Preise bleiben im Browser).
5. **Empfehlung (diese Spec):** fünf Bilder je Sprache per Skriptlauf, Käufe zuletzt im Browser.

Kein Sprachmodell im Spiel; Regeln und feste Abläufe.

## Acceptance Criteria

- **AC-1 (Screenshots lokal):** Vorbedingung: Wegwerf-Simulator iPhone 17 Pro Max. Aktion: Aufnahme der fünf Bilder je Sprache.
  Ergebnis: Dateien `docs/artifacts/feat-175-app-store-auftritt/screenshots/{de,en}/*.png`, je 3–10, alle 1320×2868.
  - Nachweis: `sips -g pixelWidth -g pixelHeight` je Datei, Protokoll im Belegverzeichnis
- **AC-2 (Vorschau vor Upload):** Henning hat Bilder und Bildunterschriften de/en gesehen, bevor etwas hochgeladen wurde.
  - Nachweis: veröffentlichte Vorschau-Seite unter `docs/artifacts/feat-175-b3-betrieb/`, Hennings Freigabezeile im Verlauf
- **AC-3 (Screenshots in ASC):** Entspricht AC-16 der Haupt-Spec.
  - Nachweis: `python3 scripts/asc_check.py --section screenshots`, erwartet „ok“
- **AC-4 (Käufe):** Entspricht AC-15 der Haupt-Spec; Kennungen wurden unmittelbar vorher gegen Code und `Restock.storekit` gelesen.
  - Nachweis: `python3 scripts/asc_check.py --section iap`, erwartet „ok“, Status nicht eingereicht
- **AC-5 (Build):** Entspricht AC-17; das CloudKit-Produktionsschema wurde vorher geprüft und das Ergebnis berichtet.
  - Nachweis: `python3 scripts/asc_check.py --section build`, erwartet „ok“; Schemacheck: Protokoll `docs/artifacts/feat-175-b3-betrieb/cloudkit-schema-check.txt` (cktool-Export-Diff Development/Production über `cloudkit-schema.yml`, `mode=export`, erwartet kein Unterschied)
- **AC-6 (Datenschutzseite):** Entspricht AC-12. Zwei Zustände: „bereitgestellt“ (Text aus `docs/appstore/datenschutz.md` an den Dritten übergeben, Claudes Anteil) und „ok“ (Seite zeigt den Text, vom Dritten abhängig).
  - Nachweis: `python3 scripts/asc_check.py --section privacy-url`, erwartet „ok“ (hängt vom Dritten ab)
- **AC-7 (Wort je Schritt):** Für Screenshot-Upload, Build-Upload und jeden Kauf liegt vor der Ausführung eine von Henning getippte
  Freigabezeile für genau diesen Schritt; nichts wurde eingereicht.
  - Nachweis: `python3 scripts/asc_check.py --section status`, erwartet `PREPARE_FOR_SUBMISSION`; Protokoll im Belegverzeichnis nennt je Schritt Zeit und Wort
- **AC-8 (Abschluss, entspricht AC-19):** `python3 scripts/asc_check.py --all` endet mit Exit 0, Ausgabe als
  `docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt` mit UTC-Zeit und Commit; Beleg-Screenshot zum App-Privacy-Fragebogen (AC-14 der Haupt-Spec, `docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg`) liegt vor.

## Definition of Done

- [ ] Screenshots de/en in ASC, `--section screenshots` ok (AC-1 bis AC-3)
- [ ] Drei Käufe samt Gruppe, `--section iap` ok (AC-4)
- [ ] Build 37 zugeordnet, Schemacheck belegt (AC-5)
- [ ] Datenschutzseite bereitgestellt; ok, sobald der Dritte sie übernimmt (AC-6)
- [ ] Je außenwirksamem Schritt Hennings Wort, nichts eingereicht (AC-7)
- [ ] `asc_check --all` Exit 0, `asc-readback.txt` abgelegt (AC-8)

## Test Plan

Kein Code, daher keine RED-Tests. Die Prüfung ist der lesende Gegenleser nach jedem Schritt (`asc_check --section …`), der
Bildmaßtest per `sips` und der Schlusslauf. Das Werkzeug ist durch `scripts/test_asc_check.py` (Schein-Antworten) bereits getestet.

## Known Limitations

- AC-3, AC-5 und AC-6 hängen von Hennings Wort bzw. vom Dritten (Datenschutzseite) ab; B3 bleibt offen, bis `--all` Exit 0 liefert.
- Der Gegenleser ist gegen echte Antworten für Screenshots, Käufe und Build noch nicht gelaufen; Abweichungen führen zu Stopp und Bericht, nicht zu Korrektur im Betrieb.
- Die Paywall ohne Rechtslinks (#215) bleibt ein Ablehnungsrisiko bei der Einreichung.
- Die Bilder sind eine Aufnahme aus dem Simulator; wie sie auf Hennings Geräten wirken, ist nicht geprüft.
- Abostufen und Abo-Laufzeit liest `asc_check` nicht. Eine einmalige Lesung (`asc-readback-abo-laufzeit-stufe.txt`) belegt die Laufzeiten; die Stufen sind dort uneindeutig (siehe Changelog 2026-10-30). Der Einmalkauf trägt gekürzte Beschreibungen (Browser-Sitzung), der Prüfer vergleicht nur das Vorhandensein.
- Der Screenshot-Prüfer erkennt weder Duplikate noch Reihenfolge noch falsche Bildsprache im Set; bekannte Sprachmängel stehen in `docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt` (Paywall-Untertitel doppelt, Pfeil-Textfehler `\u{2192}`, en/03 mit deutscher Zielkarte).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Betrieb nach festem Ablauf der Haupt-Spec, keine neue Architekturentscheidung.

## Changelog

- 2026-10-28: Erstfassung, Fortschreibung von #175 Durchgang B3 (Restschritte nach Browser-Block 1 und 2).
- 2026-10-28 (PO-Wort, Auswahlfrage in Phase 6): Aufnahme der Store-Bilder per kleinem UI-Test `RestockUITests/StoreScreenshotCaptureUITests.swift` (Alternative 3), weil `simctl` nicht antippen kann und Einkaufsliste, Bon-Prüfung und Pro-Übersicht hinter Tipps liegen. Reiner Testcode, keine App-Änderung; der Test überspringt sich ohne `TEST_RUNNER_RESTOCK_STORE_SHOTS_DIR`, läuft also in CI nicht. Betrifft „Kein Quellcode“ im Scope und Schritt 1 der Implementation Details; AC-1 unverändert.
- 2026-10-29: Der Prüfer `scripts/asc_check.py --section screenshots` akzeptiert für AC-3/AC-16 beide Bildgrößen, 1206×2622 und 1320×2868, und prüft je Screenshot-Set statt je Sprache: 3 bis 10 Bilder, alle in derselben gültigen Größe, und je Sprache mindestens ein gültiges Set. Je Set zeigt er Display-Typ (nur zur Anzeige), Anzahl, Größen und `assetDeliveryState` mit Zählern. Bei 0×0 oder fehlendem `imageAsset` nennt die Abweichung den Zustand, damit sich „wird verarbeitet“ von „defekt“ unterscheiden lässt. Grund: ASC verlangt im Pflicht-Platz „mittleres Display“ 1206×2622, die 1320×2868-Bilder liegen im optionalen 6,9″-Platz. Quelle: Bericht der Browser-Sitzung vom 2026-10-29. Die Recherche dazu ist uneindeutig (Blogs: 6,9″ genügt). Ein Set ist nur gültig, wenn jedes Bild den Zustand `COMPLETE` hat. Tests in `scripts/test_asc_check.py`, Beleg `docs/artifacts/feat-175-b3-betrieb/test-green-asc-check-screenshots.txt`. Die 1206×2622-Bilder liegen in `docs/artifacts/feat-175-app-store-auftritt/screenshots-6-3/{de,en}/`. Sie wurden aus den 1320×2868-Bildern mit `sips -z 2622 1206` skaliert, das Seitenverhältnis weicht um etwa 0,1 % ab (0,4603 zu 0,4599). Es sind dieselben 8 Bilder (de 01–05; en 01-start, 03-schnell-hinzufuegen, 06-artikel-hinzufuegen).
- 2026-10-30: Betriebsschritte abgeschlossen (Datenschutzseite ok, Build 37 zugeordnet, Käufe monthly/yearly/lifetime, „Was testen?“-Text, `asc_check --all` Exit 0). Der Schemacheck zu AC-5 (`cloudkit-schema-check.txt`) ist der Rohlauf von `xcrun cktool export-schema` (nur lesend) lokal auf dem Mac, nicht über `cloudkit-schema.yml`; Ergebnis: Repo-Datei = Development = Production, kein Unterschied. Grund: kein Workflow-Lauf nötig für denselben Befehl. Die Wortfreigaben je Schritt stehen in `freigaben-ac7.md`; die Zuordnung des Builds führte Henning selbst aus, ohne getipptes Wort. Der Prüfer liest Abo-Laufzeit und Abostufe nicht; eine einmalige Lesung der Abos zeigt Laufzeit ONE_MONTH/ONE_YEAR, `groupLevel` beider Abos jedoch 1 (uneindeutig, ob das Feld die Reihenfolge in der Gruppe abbildet). Aus Adversary-Runde 4 und 5 (F006 bis F010).
- 2026-10-30 (Nachtrag, Tech-Lead-Entscheidung): Beide Abos stehen auf Stufe 1 (Henning in App Store Connect bestätigt, deckt sich mit `groupLevel` 1 in der Lesung). Das bleibt so: Gleiche Stufe bedeutet bei Apple einen Wechsel auf gleicher Ebene (Monats- und Jahresabo desselben Inhalts), nicht Auf- oder Abstufung; Restock bietet in beiden dieselben Funktionen. Die Stufenzahlen 2/1 in `Restock.storekit` gelten nur für den lokalen Test. Die frühere Aussage „Jahresabo soll Stufe 1 und Monatsabo Stufe 2“ wird damit nicht weiterverfolgt.
