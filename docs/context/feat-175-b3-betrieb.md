# Context: feat-175-b3-betrieb

## Request Summary
Issue #175, Rest von Durchgang B3 (Betrieb): Screenshots, drei In-App-Käufe mit Abo-Gruppe, Build 37 und Schlusslauf in App Store Connect.
Kein Quellcode; jeder außenwirksame Schritt einzeln auf Hennings getipptes Wort. Fortschreibung der Haupt-Spec
`docs/specs/appstore/app-store-auftritt.md` (Abschnitt „Durchgang B3“, dort Reihenfolge und Regeln verbindlich).
Vorgänger-Kontext: `docs/context/feat-175-b3-eintragen.md` (Workflow `feat-175-b3-eintragen`, Eintragungsläufe 1–5 und Browser-Blöcke 1–2).

## Stand (2026-10-28)
Erledigt und belegt unter `docs/artifacts/feat-175-b3-eintragen/` und `docs/artifacts/feat-175-app-store-auftritt/`:
- Texte de-DE/en-US per `asc_publish --apply` (Name en-US „Restock Shopping List“), `asc_check --all nach apply 5`: Metadaten ok.
- Browser-Block 1: appInfo komplett ok (Kategorien, Altersfreigabe, Content Rights, Basisland DEU, App-Preis 0, Verfügbarkeit).
- Browser-Block 2: Review-Kontakt ok (alle Felder „gesetzt“), AC-14 Fragebogen veröffentlicht, Beleg `ac14-app-datenschutz-beleg.jpg`.
- Manifest/Erklärung „Ungefährer Standort“ per PR #232 in main.

Noch offen (laut letztem `--all`-Lauf, 2026-10-27, teils inzwischen behoben):
1. Screenshots: 0 je Sprache (Soll 3–10, 1320×2868, AC-16). Verzeichnis `…/screenshots/{de,en}/` existiert nicht.
2. Käufe: Abo-Gruppe „Restock Pro“, `monthly`/`yearly` (SUB), `lifetime` (IAP) fehlen (AC-15).
3. Build 37 nicht hochgeladen/zugeordnet (AC-17); `CURRENT_PROJECT_VERSION` steht schon auf 37 in `project.yml`.
4. Datenschutzseite des Dritten: alter Text, neuer Standortsatz fehlt (AC-12); Text liegt in `docs/appstore/datenschutz.md`.
5. Schlusslauf `asc_check --all` Exit 0 als `asc-readback.txt` (AC-19).

## Gegenprobe Kaufkennungen (gelesen am 2026-10-28)
`SmartCart/Services/PremiumService.swift:124-126`: `com.johannesemmrich.smartcart.premium.{monthly,yearly,lifetime}`.
`Restock.storekit`: dieselben drei IDs, Gruppe „Restock Pro“, Monatsabo P1M 1,99 / Jahresabo P1Y 8,99 / Lifetime NonConsumable 14,99 (Memory/Spec);
das Produkt `…sharedlists` (4,99) steht noch in der Datei, entfällt laut AC-15 und wird nicht angelegt.
Vor dem Anlegen im Browser wird dies erneut gelesen (Spec-Regel).

## Related Files
| Datei | Relevanz |
|---|---|
| `docs/specs/appstore/app-store-auftritt.md` | Haupt-Spec, ACs 14–19, B3-Ablauf; nach `phase8_complete` von a2 für edit_gate gesperrt (nur Changelog änderbar) |
| `scripts/asc_check.py` | Lesender Gegenleser (`--section screenshots|iap|build|…`, `--all`) |
| `scripts/asc_lib.py`, `asc_publish.py` | Schreibzaun nur Texte; Käufe/Screenshots nicht per Skript (Alternative 15 verworfen) |
| `SmartCart/Services/PremiumService.swift` | Kaufkennungen, `-premiumForScreenshots` (Zeile 143) |
| `Restock.storekit` | Preise, Gruppe |
| `.github/workflows/testflight.yml` | Build-Upload (nur `main`, `build_number=37`, Freigabepflicht); Spec sagt Upload bei Henning |
| `docs/appstore/{de,en,datenschutz}.md` | Store- und Datenschutztexte |
| `docs/testflight-setup.md` | CloudKit-Schema-Deploy vor Upload |

## Existing Patterns
- Vorher committen, dann Echtlauf; Beleg mit UTC-Zeit und Commit unter `docs/artifacts/feat-175-b3-eintragen/`.
- Browser-Eintragungen mit Beleg-Screenshots; Kaufpreise im Browser, nie per API.
- Vorschau-Regel: Screenshots samt Bildunterschriften de/en erst an Henning, dann Upload.
- Simulator-Läufe nur mit den Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` per Skript; Wegwerf-Simulator, nicht `Restock-Validate` verändern; keine Geräte (Gerätegrenze aus CLAUDE.md).

## Dependencies
- Upstream: App Store Connect API/Browser (Konto Henning), Simulator für Screenshots, `testflight.yml` + Secrets für Build 37.
- Downstream: Einreichbarkeit von Version 1.0 (DoD #175); Release-Meilenstein 1.0 (#35 #75 #99 #145 #175).

## Risks & Considerations
- Käufe anlegen ist unumkehrbar (Kennungen); deshalb zuletzt und nach erneuter Gegenprobe.
- Zweig `feat/175-b3-eintragen` ist 7 Commits vor `origin/main`, davon `a54282e` und `a6d9eaa` (Manifest-Standort) bereits per Squash als PR #232 in main; ein Rebase kollidiert daher. Zudem Autor-/Noreply-Problem ([[push-abgelehnt-private-mail]]). Die fünf Beleg-Commits sind unveröffentlicht; sichern per cherry-pick auf frischen Zweig vor PR.
- Screenshots: gesäte Daten ohne echte Namen/Fotos; `-premiumForScreenshots`; Paywall ohne Rechtslinks (#215) ist Ablehnungsrisiko, nicht Teil von B3.
- Build 37: Upload bleibt bei Henning; CloudKit-Produktionsschema (Preisquelle-Felder, CommunityPrice) vor dem Upload prüfen (CLAUDE.md, #151/#163).
- Änderungen am Werkzeug im Betrieb verboten (eigener Durchgang mit Test).
- Haupt-Spec ist für Edits gesperrt: Fortschreibung als neue Spec-Datei bzw. Changelog.
- Nichts auf Hennings Geräten.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md`, `docs/specs/appstore/manifest-standort.md`

## Analysis (2026-10-28)

### Type
Feature, reiner Betrieb: kein Quellcode, keine neue Spec-Datei nötig außer einer Fortschreibung (Haupt-Spec ist für Edits gesperrt, nur Changelog). ACs 14–19 gelten unverändert.

### Restliste und Reihenfolge (Stand laut Lauf 2026-10-28 12:01Z, Review-Kontakt und appInfo inzwischen ok)
| # | Punkt | AC | Außenwirkung | Wer |
|---|-------|----|--------------|-----|
| 1 | Screenshots erzeugen (Simulator, 6,9" = 1320×2868, je Sprache 3–10) | 16 | nur lokal, bis Upload | Claude |
| 2 | Vorschau Bilder + Bildunterschriften de/en an Henning | 16 | keine | Claude → Henning |
| 3 | Screenshot-Upload in ASC (Browser) | 16 | ja, auf Wort | Claude |
| 4 | Abo-Gruppe + monthly/yearly + lifetime anlegen (Browser, Preise 1,99/8,99/14,99, de/en-Texte, Review-Screenshot je Produkt) | 15 | ja, unumkehrbar (Kennungen), zuletzt, auf Wort | Claude |
| 5 | Build 37 per `testflight.yml` (`build_number=37`), vorher CloudKit-Produktionsschema prüfen | 17 | ja, Freigabepflicht | Henning (Spec: Upload bei ihm) |
| 6 | Datenschutzseite: neuer Standortsatz | 12 | Dritter | Dritter, Text liegt in `docs/appstore/datenschutz.md` |
| 7 | Schlusslauf `asc_check --all` → `asc-readback.txt` | 19 | nur lesen | Claude |

### Befunde
- **Gerätegröße:** 1320×2868 liefert nur ein 6,9"-Gerät (iPhone 16/17 Pro Max). Lokal vorhanden: iPhone 17 (1206×2622, falsch), iPhone 17e, `Restock-Validate-27`, `Restock-UITest-Verify`. Es braucht einen Wegwerf-Simulator „iPhone 17 Pro Max“ (nicht `Restock-Validate*` verändern). Wegwerf-Muster wie `scripts/run-notification-permission-uitest.sh`.
- **Seeds vorhanden, kein fertiger Screenshot-Satz:** `-seedShoppingRouteForUITests`, `-seedQuickAddAssignmentForUITests` (Lidl, dm), `-seedReplenishmentForUITests`, `-seedReceiptReviewForUITests`, `-premiumForScreenshots` (PremiumService.swift:143). Alle sind Testdaten ohne echte Namen. Ein Seed pro Bild, je mit eigenem Aufräum-Argument (Container überlebt den Lauf).
- **Beschriftete Statusleiste:** `simctl status_bar override` (9:41, volle Balken) nötig, sonst Uhrzeit/Akku des Rechners im Bild.
- **ASC-Zugang in dieser Sitzung:** `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH` sind nicht gesetzt; für `asc_check` müssen sie aus dem früheren Lauf-Aufbau gesetzt werden (Schlüsselinhalt nie lesen).
- **Zweig:** `feat/175-b3-eintragen` ist 7 vor `origin/main`; 2 davon schon als PR #232 gemergt. Belege (5 Commits) per cherry-pick auf frischen Zweig, kein Rebase, Noreply-Problem [[push-abgelehnt-private-mail]].
- **Keine Gerätearbeit:** nichts auf Hennings iPhone.
- **Offene Risiken:** Paywall ohne Rechtslinks (#215) = Ablehnungsrisiko, nicht B3. Datenschutzseite des Dritten und Build 37 blockieren AC-12/AC-17/AC-19 unabhängig von Claudes Arbeit.

### Scope Assessment
- Files: 0 Quelldateien; Belege (Bilder, Protokolle) unter `docs/artifacts/`; ggf. 1 Hilfsskript `scripts/make-store-screenshots.sh` (~80–120 Zeilen), falls die Aufnahme wiederholbar sein soll
- Risk Level: MEDIUM (Käufe unumkehrbar, außenwirksam; deshalb zuletzt, je Schritt auf Hennings getipptes Wort)

### Technical Approach (Empfehlung)
Regelweg zuerst: Screenshots per `simctl io screenshot` aus einem Wegwerf-Pro-Max-Simulator, fünf Bilder je Sprache mit den vorhandenen Seeds (Startseite mit Läden, Einkaufsliste, Schnell-hinzufügen mit Ladenvorschlag, Bon-Prüfung, Pro-Übersicht). Kein Modell nötig. Bildunterschriften de/en als Text in der Vorschau, nicht ins Bild gebrannt.

Alternativen (die Spec/ADR 15–16 bleibt unberührt):
- A: Marketing-Rahmen mit Text im Bild (Gerätekontur, Titelzeile). Optisch stärker, aber eigener Gestaltungsdurchgang und je Sprache doppelt zu pflegen; kippt die Annahme „reine Simulator-Aufnahme“ in AC-16.
- B: Nur 3 Bilder je Sprache (Minimum), schneller, weniger Fläche für die Funktionen.
- C: Screenshots per XCUITest-Lauf (`XCTAttachment`) statt Skript: wiederholbar in CI, aber Aufwand und Last; Empfehlung nur, wenn die Bilder später aktualisiert werden müssen.
Empfehlung: Hauptweg (5 Bilder, einfacher Skriptlauf).

### Dependencies
- Simulator-Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` per Skript, nie parallel.
- Käufe erst nach Screenshots (Spec-Reihenfolge); Build 37 erst nach CloudKit-Schemacheck.

### Open Questions
- [ ] Welche fünf Bildschirme zeigen die Screenshots (Vorschlag oben; Henning korrigiert in der Vorschau)
- [ ] Zeitpunkt der Datenschutzseite durch den Dritten (blockiert nur AC-12/AC-19)
- [ ] Build 37: Henning startet den Upload selbst (Spec); CloudKit-Schemacheck vorher durch Claude
