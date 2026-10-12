# Context: #98 Durchgang 5 — Onboarding, Paywall, Dev-Passwort, Laden-Einrichtung (Punkt 7)

## Request Summary
Punkt 7 aus #98: Paywall, Onboarding, PremiumService, StoreSetupView und Dev-Passwort laufen in keinem Test den echten Weg. Ein Ticket, mehrere Durchgänge (Entscheidung 2026-10-03); Punkt 7 ist vor Release 1.0 nötig (Entscheidung 2026-10-12, nur iPhone). Punkte 5 (Tagesmitteilung) und 6 (Siri/Widget) bleiben offen für einen späteren Durchgang.

## Ist-Stand der Ketten

### Onboarding (`SmartCart/Views/Settings/OnboardingView.swift`, 345 Z.)
- Aktiv, solange `@AppStorage("hasCompletedOnboarding")` false ist (`SmartCartApp.swift:757–763`).
- Schritte: 0 Willkommen („Loslegen“) → 1 Name („Weiter“, deaktiviert bei leerem Namen) → 2 Land (Standard aus Locale; Antippen setzt `presetStores`) → 3 Läden („Alle auswählen“, „Einkaufen starten“) → 4 Tutorial („Los geht's!“).
- `finishOnboarding()` legt die Voreinstellungs-Läden an (`isActive` = ausgewählt), `context.save()`, setzt das Flag.
- Nebenwirkungen, die ein Test aufräumen muss: Läden im App-Gruppen-Speicher; Anzeigename in der App-Gruppen-UserDefaults (`UserIdentity.storageKey`, Suite `group.com.johannesemmrich.SmartCart`); `hasCompletedOnboarding` in `UserDefaults.standard` (nur wenn nicht per Launch-Argument überschrieben); `selectedCountry`.
- Alle bestehenden UI-Tests umgehen das Onboarding mit `-hasCompletedOnboarding YES`. Kein Test sieht es je.
- Textmerkmale: Schritt 4 ist hartkodiert („So funktioniert Restock“, „Los geht's!“); Schritte 0–3 über `onboarding.*`-Schlüssel (de.lproj). Szenario pinnt Sprache de.

### Paywall (`SmartCart/Views/Premium/PaywallView.swift`, 367 Z.)
- Zwei Auslöser auf Home (`HomeView.swift:1389–1406`): fork.knife → „den Rezeptplan“, chart.bar → „die Ausgaben-Analyse“, jeweils nur wenn `!premium.hasPremiumAccess`. Dritter Auslöser in `SettingsView.swift:145–150` („Restock Pro freischalten“, „alle Pro-Features“), solange kein Premium.
- `hasPremiumAccess` = `developerMode` ODER gekaufte Produkt-ID ODER (DEBUG) Argument `-premiumForScreenshots`. Ein Test mit Paywall muss also OHNE `-developerMode YES` laufen und `developerMode` ausdrücklich auf NO setzen (`-developerMode NO`), weil der Wert persistiert.
- Titelzeile „Schalte \(feature) und alle weiteren Pro-Features frei.“, Schaltflächen „Schließen“, „Käufe wiederherstellen“, CTA „Jetzt freischalten — …“.
- **DEBUG-Fallback:** `purchase()` ruft bei fehlendem Produkt `dismiss()` auf (PaywallView:350). Im Simulator ohne StoreKit-Konfiguration ist `products` leer, ein CTA-Tipp schließt das Sheet — ohne Kauf. Im Release-Bau: Fehlermeldung „Der Kauf konnte nicht geladen werden…“. Das heißt: Der DEBUG-Zweig ist nicht der Release-Weg, ein Test im Simulator beweist ihn nicht.
- Es gibt keine `.storekit`-Konfigurationsdatei im Repo und keine im Scheme (gesucht). Ein echter Kauf, Wiederherstellen, Abo-Verlängerung sind im Simulator ohne Konfigurationsdatei nicht prüfbar.

### PremiumService (`SmartCart/Services/PremiumService.swift`, 95 Z.)
- `hasPremiumAccess`-Logik als Singleton mit `@AppStorage` — nicht unit-testbar ohne Umbau (Singleton, StoreKit im Init). Rein logisch ist nur die Entscheidung „developerMode / Produkt-IDs“ trennbar.

### Dev-Passwort (`SettingsView.swift:34, 228–241, 322–332, 608–658`)
- Fünf Tipps auf die Version innerhalb von je 2 s Abstand → Sheet `DevPasswordSheet` (`private struct`), SecureField „Passwort“, „Entsperren“, SHA256-Vergleich gegen `devPasswordHash`; falsch → „Falsches Passwort“, Eingabe geleert; richtig → `developerMode = true`.
- Das echte Passwort kenne ich nicht (nur der Hash steht im Code). Ein UI-Test kann den Falsch-Pfad prüfen. Der Richtig-Pfad braucht entweder das Passwort im Test (nicht gewollt) oder eine Auslagerung des Vergleichs in eine reine Funktion `matches(input:hash:)`, die ein Unit-Test mit einem Testhash prüft.

### StoreSetupView (`SmartCart/Views/Settings/StoreSetupView.swift`, 353 Z.)
- Aktive Läden (Wischen: Deaktivieren, Umsortieren per `onMove`), inaktive Läden (Aktivieren, Löschen mit Dialog), eigener Laden anlegen (`AddCustomStoreView`), Emoji ändern. Das Hinzufügen über „Läden aus anderen Ländern“ berührt der Test in `RestockUITests.swift:175–200` nur am Rand.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `SmartCart/Views/Settings/OnboardingView.swift` | Onboarding-Kette, Nebenwirkungen |
| `SmartCart/SmartCartApp.swift` | Umschalter Onboarding/Home (Z. 757), DEBUG-Seed-/Clear-Argumente (Muster) |
| `SmartCart/Views/Premium/PaywallView.swift` | Paywall, DEBUG-Fallback Z. 350 |
| `SmartCart/Services/PremiumService.swift` | `hasPremiumAccess` |
| `SmartCart/Views/Home/HomeView.swift` | Paywall-Auslöser Z. 1389–1406 |
| `SmartCart/Views/Settings/SettingsView.swift` | Paywall-Zeile, Versions-Tipp, `DevPasswordSheet` |
| `SmartCart/Views/Settings/StoreSetupView.swift` | Laden-Einrichtung |
| `RestockUITests/RestockUITests.swift` | Bestandstest mit Onboarding-Umgehung |
| `RestockUITests/UITestWait.swift` | `UITestLaunch.start`, `waitUntilHittable`, `waitForLabel` — für neue Tests zu nutzen |
| `docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md` | Format der Vorgänger-Spec |

## Existing Patterns
- Gesäte UI-Tests: DEBUG-Launch-Argumente `-seed…ForUITests` / `-clear…ForUITests` in `SmartCartApp.swift`; jede Testklasse räumt in `tearDown()` per Clear-Argument auf (Memory „UI-Test-Seeds müssen aufräumen“).
- Start über `UITestLaunch.start` (zweiter Start mit Messzeile), Warten über `UITestWait`-Helfer.
- Szenario pinnt Sprache `de`, Tests lesen deutsche Labels; Text-Änderungen können Tests brechen.
- Memory „Nur Workflow-Slash-Commands“, „Simulator nie parallel“, „Eigenes Testgerät je Projekt“ (Restock-Validate), „Null-Test-Lauf ist kein Grün“.

## Dependencies
- Upstream: SwiftData-Container (App-Gruppe), `UserDefaults`, `Store.presets(for:)`, StoreKit (nur Paywall).
- Downstream: Alle UI-Tests nutzen `-hasCompletedOnboarding YES`; Änderungen an dessen Auswertung würden alle betreffen — deshalb darf der Produktcode des Onboardings nicht verändert werden.

## Risiken
1. **Aufräumen:** Ein Onboarding-Durchlauf hinterlässt Läden und Namen im App-Gruppen-Container und kann nachfolgende Tests brechen. Braucht ein Clear-Argument und einen Beleg im gemeinsamen Lauf (Memory #28).
2. **`hasCompletedOnboarding` persistiert:** Ohne Argument liest die App den gespeicherten Wert; ein Onboarding-Test muss `-hasCompletedOnboarding NO` setzen und darf den Wert für andere Tests nicht dauerhaft verändern (Argument-Domain überlagert — zu prüfen).
3. **Paywall-Beweis nur zur Hälfte:** Sperre und Sheet sind prüfbar; der Kaufpfad (und der Release-Zweig der Fehlermeldung) nicht. Offene Grenze ins Ticket.
4. **Umfang:** Schätzung über 250 Zeilen (Onboarding-Klasse ~130, Paywall/Dev-Passwort ~130, StoreSetup ~100, Produktcode DEBUG ~30). Entweder aufteilen (5a Onboarding + Dev-Passwort, 5b Paywall + StoreSetup) oder Überschreitung vorab zur Freigabe vorlegen.
5. **Dev-Passwort-Richtig-Pfad** nur über Auslagerung der Prüffunktion testbar — eine kleine Produktcode-Änderung an einer sicherheitsnahen Stelle (Blast Radius wächst).

## Alternativen (zur Analyse)
- Onboarding nicht per UI durchspielen, sondern Schritt-Logik (`finishOnboarding`) in eine testbare Funktion ziehen → verletzt „echter Weg“, deshalb nur als Ergänzung.
- Paywall mit `.storekit`-Konfigurationsdatei im Scheme: ermöglicht echten Kauf im Simulator, ändert aber Scheme und Release-Pfade; neue Datei, Entscheidung für die Analyse.
- Punkt 7 vollständig vertagen und stattdessen 5/6 vor Release: widerspricht dem Beschluss vom 12.10.

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-3-schnelleingabe-notfallpfad.md`, `…-4-sync-merge.md`, `replenishment-uitest.md` (Vorlagen)
- `docs/context/test-98-testluecken.md` (Gesamtübersicht der Durchgänge)

## Analysis

### Type
Feature (Testabdeckung, kein Produktverhalten). Kein sichtbares UI-Redesign, daher keine Entwurfs-Vorschau nötig.

### Recherche (zuerst, mit Quellen)
- UI-Tests und StoreKit-Konfigurationsdatei: Eine `SKTestSession`, die im Testprozess nach dem App-Start angelegt wird, gibt der gestarteten App die Testumgebung nicht — echte Kaufabläufe sind per XCUITest nur über die im Scheme hinterlegte `.storekit`-Datei erreichbar. Quellen: https://developer.apple.com/documentation/storekittest/sktestsession.md, https://developer.apple.com/forums/thread/736989 (Forum: `.purchase()` wirft in XCTest im Simulator `StoreKitError.Unknown`).
- **Korrektur zum Kontext-Entwurf:** `Restock.storekit` existiert im Repo-Wurzelordner (zwei Nicht-Verbrauchsprodukte: Pro Lifetime, Geteilte Listen), ist aber in keinem Scheme und nicht im Projekt verdrahtet (Suche in `xcshareddata` und `project.pbxproj`: kein Treffer). Der Kauf bleibt also im Simulator ungetestet; Verdrahten wäre eine Scheme-Änderung mit Wirkung auf alle Testläufe.

### Bestätigt im Code
- `PremiumService.hasPremiumAccess` = `developerMode` ODER `-premiumForScreenshots` (DEBUG) ODER gekauft (Zeilen 22–29).
- Paywall-`purchase()` ohne Produkt: DEBUG `dismiss()`, Release Fehlermeldung (PaywallView ~347–356) — der Simulator-Test sieht nur den DEBUG-Zweig.
- Dev-Passwort: Hash im Code (`SettingsView.swift:34`), SHA256-Vergleich in Zeile ~648.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| RestockUITests/OnboardingUITests.swift | CREATE | Onboarding Schritt 0–4 durchspielen, Läden/Name prüfen, tearDown räumt auf |
| RestockUITests/PaywallUITests.swift | CREATE | Sperre ohne Premium: Rezeptplan + Ausgaben + Einstellungen öffnen Paywall; Schließen; Dev-Passwort Falsch-Pfad |
| SmartCart/SmartCartApp.swift | MODIFY (DEBUG) | `-clearOnboardingForUITests` (Läden, Namen, Flag, Land entfernen) |
| Restock.xcodeproj/project.pbxproj | MODIFY | zwei neue Testdateien registrieren |
| docs/specs/ui-tests/test-98-durchgang-5-….md | CREATE | Spec |

### Scope Assessment
- Durchgang 5: 5 Dateien, ca. +250/−0 LoC, Risiko MEDIUM (Aufräumen im gemeinsamen App-Gruppen-Container, Memory #28).
- **Schnitt:** Durchgang 5 = Onboarding + Paywall-Sperre + Dev-Passwort Falsch-Pfad. **StoreSetupView (~100 Z.) wird Durchgang 6** — sonst über Limit (Schätzung 350+).

### Technical Approach
1. `OnboardingUITests`: Start mit `-hasCompletedOnboarding NO` (Argument-Domain überlagert, persistiert nicht — im Test belegen), Szenario-Sprache de; Weg: Loslegen → Name → Land → Läden → Tutorial → Home zeigt gewählte Läden. tearDown: `-clearOnboardingForUITests`.
2. `PaywallUITests`: Start ohne Premium (`-developerMode NO`), drei Auslöser öffnen die Paywall mit passendem Funktionsnamen, „Schließen“ schließt. Nachweis des Kaufwegs entfällt (offene Grenze, siehe unten).
3. Dev-Passwort: nur Falsch-Pfad per UI-Test („Falsches Passwort“, Eingabe geleert). Richtig-Pfad: reine Funktion `matches(input:hash:)` auslagern + Unit-Test mit Testhash — nur wenn ≤ 15 Zeilen, sonst offene Grenze.
4. Gemeinsamer Lauf mit der Bestandssuite als Beweis, dass nichts hinterlassen wird.

### Alternativen (und was sie kippen würden)
- **A: `Restock.storekit` ins Scheme verdrahten** → echter Kauf im Simulator möglich, aber globale Scheme-Änderung, Forum meldet `StoreKitError.Unknown` unter XCTest; kippt die Entscheidung „Scheme unverändert“. Als eigenes Folge-Ticket prüfen, nicht jetzt.
- **B: Onboarding-Logik in eine Funktion ziehen und per Unit-Test prüfen** → verletzt den „echten Weg“ (Regel Reproduktion/Benutzen), nur Ergänzung.
- **C: Punkt 7 vertagen, 5/6 vor Release** → widerspricht Beschluss vom 12.10.
- **Ohne Modell:** nichts davon braucht ein Sprachmodell; reine UI-/Regelprüfung.

### Dependencies
Upstream: SwiftData-App-Gruppe, UserDefaults (Suite `group.com.johannesemmrich.SmartCart`), `UITestLaunch`/`UITestWait`. Downstream: alle UI-Tests nutzen `-hasCompletedOnboarding YES` — Produktcode des Onboardings bleibt unverändert.

### Offene Grenzen (kommen in jede Zusage)
Kauf, Wiederherstellen und Release-Fehlermeldung der Paywall sind nicht automatisiert prüfbar; Dev-Passwort-Richtig-Pfad nur über Unit-Test der Vergleichsfunktion; StoreSetupView folgt in Durchgang 6.

### Open Questions
- [ ] Keine PO-Frage nötig (technischer Schnitt liegt bei Claude).
