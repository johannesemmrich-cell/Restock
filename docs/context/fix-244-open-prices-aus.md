# Context: fix-244-open-prices-aus

## Request Summary
Apple hat 1.0 mit Guideline 2.1 zurückgegeben. PO-Entscheidung 2026-11-01: „Open Prices“ (öffentlicher Upload von Bonfotos an Open Food Facts, noch gegen den Testserver) wird für 1.0 ausgeblendet; danach neuer Build und Antwort an Apple mit Notes-Text und Bildschirmaufnahme.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Settings/SettingsView.swift:139–144` | NavigationLink „Open Prices“ im Abschnitt „Funktionen“, einziger Einstieg in die Funktion |
| `SmartCart/Views/Settings/OpenPricesSettingsView.swift` | Schalter, Anmeldung, Filialwahl; bleibt als Code bestehen |
| `SmartCart/Services/OpenPricesContributionService.swift:305–318` | `OpenPricesContribution` (Schlüssel, `enabledDefault = false`, `environment = .preProduction`, `isEnabled(in:)`) |
| `SmartCart/Services/OpenPricesContributionService.swift:412–518` | Dienst; `contribute(lines:…)` prüft `readiness` (Schalter, Anmeldung, Filiale, Foto), `contributeInBackground` startet ihn |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:842–845` | einziger Sendeaufruf, am Ende von `save()` |
| `RestockTests/OpenPricesContributionTests.swift` | Bestehende Tests; Dienst wird mit eigener `UserDefaults`-Suite und Fake-API gebaut (`service(_:tokens:enabled:)`, Z. 31) |
| `SmartCart/Views/Settings/LegalView.swift:85–86, 98`, `SmartCart/PrivacyInfo.xcprivacy`, `docs/appstore/datenschutz.md` | Datenschutztexte nennen Open Prices als Opt-in |
| `docs/appstore/review-notes.md` (unversioniert) | Notes-Entwurf; erwähnt Open Prices nicht als Funktion, nur Open-Food-Facts-Daten |

## Existing Patterns
- Abschaltbare Funktionen: `aiPriceEstimationEnabled` (#164) nur im Entwicklermodus sichtbar, Standard aus; KI-Preis bleibt „aus bis zum Nachweis“.
- Dienste nehmen Nähte per Initialisierer (`api`, `tokens`, `defaults`, `now`) — Tests bauen eine eigene Instanz, der Singleton `shared` nutzt Standardwerte.
- Release-Prüfung per `strings` auf dem Release-Binary (#145, #208), wenn etwas nur unter `#if DEBUG` steht.

## Dependencies
- Upstream: `UserDefaults.standard` (`openPricesContributionEnabled`), Schlüsselbund-Token, `OpenPricesLocationStore`, `OpenPricesClient`.
- Downstream: `ReceiptScannerView.save()` (Senden), `SettingsView` (Eintrag), `OpenPricesSettingsView` (liest Dienst und Umgebung).

## Existing Specs
- `docs/specs/services/open-prices-contribution.md` — Funktion #184
- `docs/specs/appstore/manifest-standort.md`, `docs/specs/appstore/app-store-auftritt.md` — Datenschutz-Angaben inkl. Open Prices

## Risks & Considerations
- **Altzustand bei TestFlight-Testern:** Seit #184 (2026-10-22, Builds 34–38) war der Eintrag sichtbar. Wer Schalter an und Anmeldung hat, würde ohne Einstieg weiter senden. Ausblenden des Eintrags allein reicht also nicht; der Sendeweg muss selbst gesperrt sein.
- **Build-Nummer:** Build 38 ist bereits hochgeladen (TestFlight-Lauf 41181247059, 2026-10-31, Stand `2a7db1b`). Der neue Build ist 39; `CURRENT_PROJECT_VERSION` in `project.yml`/`project.pbxproj` (App, Widget, Teilen-Erweiterung) anheben. Seit 38 sind die Laden-Gänge (#234 D1, D2a) dazugekommen; Modell-Feld `stationConfigJSON` ist in Production deployt.
- **Bestehende Tests** bauen den Dienst mit Schalter an und erwarten Senden; eine globale Sperre muss injizierbar sein, sonst werden sie rot.
- **Datenschutztexte** nennen Open Prices weiter. Zu viel deklariert ist zulässig; eine Änderung an `LegalView` zöge `datenschutz.md` und die fremd gepflegte Seite nach sich — nicht Teil dieses Tickets.
- **Außenwirksame Schritte** (Upload, Zuordnung zu 1.0, Notes-Feld, Antwort im Resolution Center) nur auf Hennings Wort; die Aufnahme macht Henning auf seinem iPhone.

## Analysis

### Type
Feature-Änderung (Funktion für 1.0 abschalten), kein Fehler.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/OpenPricesContributionService.swift` | MODIFY | `OpenPricesContribution.isAvailable = false` (eine Stelle, Kommentar #244); Dienst bekommt Init-Parameter `available` (Standard `isAvailable`), `readiness` meldet ohne Verfügbarkeit `.disabled` — damit sendet `contribute` nie, egal wie Schalter, Anmeldung und Filiale stehen |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | NavigationLink „Open Prices“ nur bei `OpenPricesContribution.isAvailable` |
| `RestockTests/OpenPricesContributionTests.swift` | MODIFY | Helfer `service(...)` baut mit `available: true` (Bestand bleibt grün); neue Tests: Konstante ist `false`; Dienst mit Schalter an, Token, Filiale, Foto und `available: false` liefert `nil` und ruft die Fake-API nie auf; `shared` übernimmt die Sperre |
| `RestockUITests/RestockUITests.swift` | MODIFY | Einstellungen öffnen: „Standard-Läden“ sichtbar (Gegenprobe), „Open Prices“ fehlt — auch mit `-developerMode YES` |

Nicht geändert: `OpenPricesSettingsView`, `ReceiptScannerView` (Aufruf bleibt, der Dienst sperrt), Datenschutztexte (zu viel deklariert ist zulässig), Lokalisierung.

Getrennt danach (eigener kleiner Schritt wie #239): `CURRENT_PROJECT_VERSION` 38 → 39 in `project.yml` und `project.pbxproj`, dann TestFlight-Upload, Zuordnung zu 1.0, Notes-Feld und Antwort — jeder außenwirksame Schritt auf Hennings Wort.

### Scope Assessment
- Files: 4
- Estimated LoC: +~60/-~3 (davon ~45 Test)
- Risk Level: LOW

### Technical Approach
Eine Konstante als einziger Schalter für die Verfügbarkeit, an zwei Stellen gelesen: Einstieg in den Einstellungen und Bereitschaftsprüfung des Dienstes. Der Sendeweg prüft selbst, weil TestFlight-Tester seit Build 34 den Schalter eingeschaltet haben können. Injizierbar über den Initialisierer wie die übrigen Nähte, damit die Bestandstests die Funktion weiter prüfen. Die Konstante gilt in DEBUG und Release gleich, damit UI-Test und Simulator-Durchlauf genau das Release-Verhalten zeigen; ein Release-Nachweis per `strings` ist dann nicht nötig.

### Alternativen
- **Nur im Entwicklermodus zeigen** (Muster KI-Preisschätzung #164): Henning könnte weiter testen; verworfen, weil die Funktion ohnehin nur an den Testserver sendet und App Review keinen Weg zu öffentlichem Bonfoto-Upload finden soll.
- **`#if DEBUG`**: Release ohne Funktion, Debug mit; verworfen, weil der UI-Test (DEBUG) dann das Release-Verhalten nicht zeigt.
- **Code ganz entfernen**: größter Umfang, kippt #184 (Spec `open-prices-contribution.md`); für eine spätere Version nicht nötig.
- **Gespeicherten Schalter beim Start auf aus setzen**: ändert Nutzerdaten, schützt nicht gegen späteres Einschalten; schwächer als die Sperre im Dienst.

### Dependencies
`ReceiptScannerView.save()` → `contributeInBackground` → `contribute(lines:…)` → `readiness`. `OpenPricesSettingsView` liest `readiness` nicht für das Senden; sie wird nur nicht mehr erreichbar.

### Open Questions
- keine (PO-Entscheidung im Ticket; Build-Nummer 39 statt 38 ist eine technische Korrektur)
