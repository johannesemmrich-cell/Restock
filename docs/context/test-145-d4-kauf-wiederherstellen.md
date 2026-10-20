# Context: test-145-d4-kauf-wiederherstellen

## Request Summary
#145 Durchgang 4: Kauf, Wiederherstellen und Fehlerwege von Restock Pro automatisiert prüfen.
Release-1.0-Blocker (PO-Entscheidung 2026-10-19), weil Umsatz und App-Store-Prüfung daran hängen
und der Weg bisher nie geprüft wurde.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/PremiumService.swift` (95 Z.) | Singleton `@MainActor ObservableObject`; `loadProducts` (`Product.products`, Fehler → leere Liste, still), `purchase` (success/userCancelled/pending), `restorePurchases` (`try? AppStore.sync()`, Fehler still), `refreshPurchases` (`currentEntitlements`, ohne `revocationDate`), `Transaction.updates`-Listener. `hasPremiumAccess` = Dev-Modus ODER eine der drei IDs; DEBUG `-premiumForScreenshots`. |
| `SmartCart/Views/Premium/PaywallView.swift` (367 Z.) | Plan-Auswahl (Monat 1,99 / Jahr 8,99 / einmalig 14,99, Fallback-Preise wenn Produkte fehlen), CTA „Jetzt freischalten — …“, „Käufe wiederherstellen“, Fehlertext, Rechtstext. Eigenes `@StateObject PremiumService.shared`. |
| `SmartCart/SmartCartApp.swift:13,862` | hält `PremiumService.shared`, reicht es per `environmentObject` weiter |
| `SmartCart/Views/Home/HomeView.swift:98`, `SmartCart/Views/Settings/SettingsView.swift:24` | lesen `hasPremiumAccess` (Sperre fork.knife, chart.bar, Einstellungszeile) |
| `Restock.storekit` | Kauf-Testdatei: Abo-Gruppe „Restock Pro“ (monthly 1,99 P1M, yearly 8,99 P1Y), Einmalkauf lifetime 14,99, `sharedlists` 4,99 (im Code ungenutzt). Storefront DEU, EUR. **Nicht im pbxproj, in keinem Scheme.** |
| `Restock.xcodeproj/xcshareddata/xcschemes/Restock.xcscheme` | einziges Scheme; kein `StoreKitConfigurationFileReference` |
| `RestockUITests/PaywallUITests.swift` | #98 D5: Sperre an drei Stellen, Gegenprobe `-premiumForScreenshots`, falsches Dev-Passwort. Kein Kauf. |
| `.github/workflows/ci.yml` | `macos-26`, neuestes Xcode, Simulator mit neuester iOS-Version |

## Existing Patterns
- DEBUG-Launch-Argumente für Testzustände in `SmartCartApp.init()` / Diensten, Aufräumer im `tearDown()` Pflicht.
- Testnähte als Protokoll vor System-APIs mit Fake: `DigestNotificationCenter` (#98 D7), `SharedStoreDatabase` (#121), `CommunityPriceDatabase` (#163), `ReceiptNameLanguageModel`.
- Sonderläufe außerhalb der CI über Skript + Wegwerf-Simulator + beide Sperren (`scripts/run-notification-permission-uitest.sh`, `scripts/run-appintents-uitest.sh`).

## Dependencies
- Upstream: StoreKit 2 (`Product`, `Transaction`, `AppStore.sync`), `@AppStorage("developerMode")`.
- Downstream: Paywall-Auslöser in HomeView (fork.knife, chart.bar), SettingsView („Restock Pro freischalten“).

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-5-onboarding-paywall.md` — Paywall-Sperre, offene Grenze Kauf/Wiederherstellen/Release-Fehlermeldung.
- `docs/specs/ui-tests/test-145-durchgang-{1,2,3}-*.md` — Vorgänger-Durchgänge, Skript- und Sperrmuster.

## Recherche (2026-10-19)
- Apple-Forum 826971 (FB22237318, FB23721564): `xcodebuild test` (CLI) überträgt die `.storekit`-Datei auf iOS-26.5-Simulatoren nicht an `storekitd`; `SKTestSession` fällt auf den echten App Store durch („Bei Apple-Account anmelden“) oder wirft `SKInternalErrorDomain 3`. In Xcode (Cmd+U) geht es, iOS 26.1 nicht betroffen; Fix angekündigt für Xcode 26.6, laut Nutzern unvollständig. Manuelles Kopieren in den Container hilft nicht.
- Apple-Forum 820991: iOS-26.4-Simulator liefert lokal sofort `.userCancelled`, auch in Apples Beispiel-App.
- GitHub SaifuLog-Apple PR #24: `SKTestSession`-Unit-Tests per xcodebuild scheitern auf iOS 27.0 (Preise nicht aus Datei, Fehlerinjektion wirkungslos, ASDServerErrorDomain 907/1050), auf iOS 26.2 grün; das Projekt lädt deshalb in der CI die 26.2-Runtime (8,4 GB).
- MacObserver: Xcode 27.2 beta behebt drei StoreKit-Test-Fehler (clearTransactions/Intro-Angebot, Storefront-Updates, Fehlerdialog trotz `dialogsDisabled`).
- Lokal: Xcode 27.1, Runtimes iOS 26.5 und 27.0 — also genau die beiden als defekt berichteten. Kein 26.1/26.2.

## Beim Lesen aufgefallen (noch nicht reproduziert, für /20-analyse)
1. „Käufe wiederherstellen“ ohne Fund: keine Rückmeldung, Sheet bleibt offen, Fehler von `AppStore.sync` verschluckt.
2. `.pending` (Kaufen mit Zustimmung/Ask to Buy, SCA): `purchase` gibt `false` zurück, Paywall zeigt nichts.
3. DEBUG-Zweig: fehlt das Produkt, schließt die Paywall still (wie ein Kauf) — verdeckt im Simulator den Release-Fehlerweg.
4. `sharedlists` steht in der Testdatei, aber nicht im Code; ob die drei IDs in App Store Connect angelegt sind, ist unbekannt (→ #175).
5. Abos (Monat/Jahr) + Einmalkauf: `currentEntitlements` liefert abgelaufene Abos nicht, das ist korrekt; Widerruf über `revocationDate`.

## Risks & Considerations
- Echtes StoreKit-Testen ist auf den vorhandenen Runtimes laut Berichten kaputt → Reproduktion zuerst, bevor ein Weg gewählt wird.
- Alternative ohne echtes StoreKit: Protokoll-Naht vor `PremiumService` (Muster wie `DigestNotificationCenter`) mit Fake in Unit-Tests und DEBUG-Fake für UI-Tests — prüft unsere Logik und Oberfläche, nicht Apples Kaufablauf.
- Alternative: zusätzliche 26.2-Runtime nur für einen Skriptlauf (wie SaifuLog), Speicher ~8 GB, außerhalb der CI.
- Gerätetest (Sandbox/TestFlight) nur auf Hennings ausdrückliches Wort.
- Mögliche Produktbefunde (1–3) brauchen PO-Entscheidung, sobald reproduziert.
- Scheme-/pbxproj-Änderung betrifft alle Testläufe; StoreKit-Datei im Scheme ändert auch Xcode-Run-Verhalten (Henning startet aus Xcode).

## Analysis

### Type
Feature (Testabdeckung) mit möglichen Produktbefunden (Lücken 1–3 oben), Entscheidung beim PO.

### Reproduktion: echtes StoreKit-Testen per Kommandozeile (2026-10-19, 13:18–13:29)
Wegwerf-Paket mit `SKTestSession(contentsOf: Restock.storekit)`, vier Tests (Produkte laden, Einmalkauf,
Fehlschlag per `failTransactionsEnabled`, Kaufen mit Zustimmung per `askToBuyEnabled`), `xcodebuild test`
auf frischen Wegwerf-Simulatoren, beide Sperren gehalten, Simulatoren danach gelöscht.

| Runtime | Ergebnis | Fehler der Testsitzung |
|---------|----------|------------------------|
| iOS 26.5 | 4/4 rot, 0 Produkte | `SKInternalErrorDomain 3` bei Speichern der Konfiguration, Zurücksetzen, Löschen |
| iOS 27.0 | 4/4 rot, 0 Produkte | `SKServiceErrorDomain 2` / darunter `SKInternalErrorDomain 4` |

Deckt sich mit Apple-Forum 826971 (26.5) und SaifuLog PR #24 (27.0). Belege:
`docs/artifacts/test-145-d4-kauf-wiederherstellen/storekit-spike/`.
Grenze des Spikes: Paket-Tests ohne Host-App; die Forenberichte zeigen denselben Fehler mit Host-App.
Folge: Echter StoreKit-Kauf ist auf allen lokal vorhandenen Runtimes und in der CI (neueste Runtime)
derzeit nicht automatisierbar.

### Wege (Alternativen)
| Weg | Prüft | Kosten | Status |
|-----|-------|--------|--------|
| A Naht vor StoreKit + Fake (Muster `DigestNotificationCenter`) | unsere Logik (Berechtigung aus Transaktionen, Abbruch, ausstehend, Fehler, Wiederherstellen) und die Paywall-Oberfläche in jedem Ausgang; läuft in CI | ~430 Zeilen, 6 Dateien | **Empfehlung** |
| B iOS-26.2-Runtime (~8 GB) nur für Skriptlauf mit `SKTestSession` | zusätzlich Apples Kaufablauf gegen die Testdatei | Download, außerhalb CI, ungewiss mit Xcode 27.1 | später als Ergänzung, sobald A steht |
| C Warten auf Xcode 27.2 (behebt laut MacObserver StoreKit-Testfehler) | wie B, ggf. auch in CI | Zeit, Beta | Beobachten, Folge-Issue |
| D Sandbox/TestFlight auf Hennings iPhone | echten Kauf gegen App Store Connect | nur auf Hennings Wort; braucht angelegte Produkte (#175) | Abschluss vor Release, nicht automatisiert |

### Affected Files (with changes) — Weg A
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/PremiumService.swift` | MODIFY | Protokoll `PurchaseStore` (Produkte laden, kaufen → Ergebnis, `sync`, aktuelle Berechtigungen, Update-Strom), Standard = StoreKit; Dienst nimmt es entgegen; Ergebnis `purchased/cancelled/pending/failed` |
| `SmartCart/Services/FakePurchaseStore.swift` (oder im selben File, `#if DEBUG`) | CREATE | Fake mit Szenario aus Launch-Argument `-purchaseScenarioForUITests <success|cancel|pending|fail|restoreNone|restoreFound>` |
| `SmartCart/Views/Premium/PaywallView.swift` | MODIFY | Rückmeldung bei „ausstehend“ und „nichts gefunden“ (nur wenn PO zustimmt); DEBUG-Stillschließen entfernen |
| `RestockTests/PremiumServiceTests.swift` | CREATE | Logik: Berechtigung je ID, widerrufen, Abbruch, ausstehend, Fehler, Wiederherstellen mit/ohne Fund |
| `RestockUITests/PurchaseUITests.swift` | CREATE | Paywall je Ausgang: Kauf → Sheet zu + fork.knife frei; Abbruch; ausstehend; Fehler; Wiederherstellen |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | neue Dateien registrieren |

### Scope Assessment
- Files: 6 (Limit 4–5 überschritten)
- Estimated LoC: ~+430/-15 (Limit ±250 überschritten; Testcode ~300 davon)
- Risk Level: MEDIUM — Kaufcode ist umsatzrelevant; Naht ändert Verhalten nicht, wenn der Standard StoreKit bleibt. Scheme bleibt unverändert (keine StoreKit-Datei im Xcode-Lauf).

### Technical Approach
Weg A. Naht vor StoreKit, Fake nur unter `#if DEBUG`, Launch-Argument ohne App-Group-Zustand (kein Aufräumer nötig, aber `tearDown` prüft, dass `developerMode` nicht gesetzt wird; nie `-developerMode` als Argument). Release-Build: Fake per `strings` ausgeschlossen (Muster #145 D1).

### Dependencies
StoreKit 2 (`Product`, `Transaction.currentEntitlements/updates`, `AppStore.sync`); Paywall-Auslöser HomeView/SettingsView; `PaywallUITests` (#98 D5) bleibt unverändert grün.

### Open Questions
- [x] PO (2026-10-19): Lücken 1–3 in diesem Durchgang beheben; Entwurf der Texte vor der Spec.
- [x] PO (2026-10-19): ~430 Zeilen / 6 Dateien in einem Durchgang freigegeben.
- [x] Folge-Issue für Weg B/C angelegt: #178.

### Entwurf (vor Spec, 2026-10-19)
- Seite: https://claude.ai/artifact/TDfsYKp3hBxcq4FjV1EUms — Quelle `docs/artifacts/test-145-d4-kauf-wiederherstellen/entwurf-paywall-rueckmeldungen.html` (Bauteile `.src.html` + `scratchpad/build_entwurf.py`-Muster), Heute-Bilder `heute-paywall-{hell,dunkel}.png` (Simulator iOS 26.5, Build 32, aus Video von `PaywallUITests/testRecipePlanLockedOpensPaywall`).
- Entwurf A (Empfehlung): Hinweis unter „Käufe wiederherstellen“, Info auf Akzentfläche, Fehler in Warnfarbe; Paywall bleibt offen. Alternative B: Systemdialog mit „OK“.
- Nebenbefund: „Schließen“-Chip oben links zeigt hell und dunkel nur „…“ (auch Sekunden nach dem Öffnen, Video-Einzelbilder f044/f052).
- **PO-Freigabe 2026-10-19:** Entwurf A (Hinweis unter dem Knopf, Texte wie auf der Entwurfsseite). „Schließen“-Chip („…“) wird in diesem Durchgang mit behoben; Ursache vor dem Fix nachstellen und belegen, UI-Test prüft das sichtbare Wort „Schließen“. Dateien: + `PaywallView.swift` (schon betroffen), ggf. Chip-Stil in `DesignSystem.swift` (dann 7 Dateien; Umfang ~+20 Zeilen).
