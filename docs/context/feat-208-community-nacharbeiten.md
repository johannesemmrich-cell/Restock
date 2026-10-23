# Context: feat-208-community-nacharbeiten (#208)

## Request Summary
Drei Nacharbeiten aus #186 mit gemeinsamem Ziel „Community-Preis-Teil stimmig, keine Fremddaten“:
(1) Fußnote unter dem Schalter widerspricht bei Schalter „aus“, (2) Bestands-UI-Tests senden echte
`CommunityPrice`-Records an CloudKit-Development, (3) toter Code `contributeInBackground(_ contribution:)`.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Resources/de.lproj/Localizable.strings:421`, `en.lproj/...:421` | `settings.community.footer` beginnt mit „Voreingestellt an.“ / „On by default.“ (Teil 1) |
| `SmartCart/Views/Settings/SettingsView.swift:18-20,111-115` | Schalter `communitySharingEnabled` + Fußnote als `Text` darunter, immer derselbe Text |
| `SmartCart/Services/CommunityPriceService.swift:179` | Einzel-Überladung `contributeInBackground(_:)`, ohne Aufrufer (Teil 3); `:194` Listen-Überladung bleibt |
| `SmartCart/Services/CommunityPriceService.swift:~80` | `static let shared` mit `CKContainer(...).publicCloudDatabase` — hier entsteht der echte Netzweg (Teil 2) |
| `SmartCart/Views/Prices/CommunityShareNotice.swift:26,63` | beide Sendestellen (`„Weiter teilen“`, `holdForNoticeOrSend`) laufen über `shared.contributeInBackground(list)` |
| `SmartCart/Views/Prices/ReceiptScannerView.swift:839`, `ActualPriceEntryView.swift:156` | Eingänge, die senden |
| `SmartCart/Views/Store/StoreDetailView.swift:116` | `refreshAndApply` liest ebenfalls aus der öffentlichen DB (Lesen erzeugt keine Records) |
| `SmartCart/SmartCartApp.swift:36,543` | DEBUG-Launch-Argumente; Muster für Aufräumer |
| `RestockUITests/{ReceiptReviewUITests,ReceiptResolutionStatsUITests,DynamicTypeUITests}.swift` | speichern einen Bon mit `-communityPricesNoticeShown YES` → Schalter Standard „an“ → echter Versand |
| `RestockUITests/CommunityShareNoticeUITests.swift` | testet den Hinweis, nie mit `-communityPricesNoticeShown`/`-communityPricesSharingEnabled`; „Weiter teilen“ sendet echt |
| `RestockTests/CommunityPriceTests.swift` | `FakeCommunityPriceDatabase`, `makeService(_:sharing:)` — Naht ist schon da |

## Existing Patterns
- Netz hinter Protokoll `CommunityPriceDatabase`; Fake in den Unit-Tests.
- DEBUG-only Launch-Argumente in `SmartCartApp.init()`, kein Release-Code (Nachweis per `strings`, siehe #145 D1/D4).
- Argument-Domain-Falle: `-communityPricesSharingEnabled` als Launch-Argument überlagert `@AppStorage`/`defaults.set` und würde Schalter-Tests der Klasse brechen.
- 22 UI-Testklassen starten die App; es gibt keinen gemeinsamen Start-Helfer für alle (`UITestLaunch` nur für gesäte Klassen).

## Dependencies
- Upstream: `CKContainer.publicCloudDatabase`, `UserDefaults.standard`.
- Downstream: Preislogik liest nur den Zwischenspeicher (`CommunityPriceCache`), nicht den Versand.

## Existing Specs
- `docs/specs/services/community-prices.md`, `docs/specs/services/community-prices-erst-hinweis.md`

## Risks & Considerations
- Teil 2: Wo der Versand abgeschaltet wird, muss ALLE 22 Klassen erfassen, ohne jede einzeln anzufassen; sonst bleibt eine Lücke. Möglichkeit: in DEBUG nimmt `shared` eine Ersatz-Datenbank, sobald irgendein Argument auf `…ForUITests` endet (fast alle Klassen haben so eins); Prüfung per Strukturtest. Alternative: ein eigenes Argument `-discardCommunityPricesForUITests` in jeder Klasse (22 Stellen, Vergessensgefahr).
- Der Beleg „kein Record mehr“ braucht einen messbaren Weg: Ersatz-Datenbank zählt Speicherversuche (z. B. Zähler in der App-Gruppe oder Log), der UI-Test liest ihn.
- `CommunityShareNoticeUITests` muss den echten Hinweisablauf weiter fahren; nur die Datenbank wird ersetzt, nicht der Schalter.
- Teil 1 ist eine Produktfrage und braucht vor der Spec eine Entwurfsvorschau hell/dunkel mit Alternative (Henning 2026-09-22).
- Teil 3: reine Löschung, kein Verhalten.
- Alternativen zum bisherigen Weg (Regel „in Alternativen denken“): Standard „an“ in Debug-Bauten ganz auf „aus“ statt Ersatz-Datenbank; Fußnote nach Schalterstand statt statisch.

## Analysis

### Type
Feature (Nacharbeit, drei Teile, gemeinsames Ziel „Community-Preis-Teil stimmig, keine Fremddaten“).

### Befund Teil 2 (eingegrenzt)
Echte `CommunityPrice`-Records entstehen nur an zwei Sendestellen: `holdForNoticeOrSend` (Bon-Prüf-Screen, „Preis eintragen“) und „Weiter teilen“ im Erst-Hinweis (`CommunityShareNotice.swift:26`). Von 22 UI-Klassen erreichen nur vier diese Stellen: `ReceiptReviewUITests`, `ReceiptResolutionStatsUITests`, `DynamicTypeUITests` (alle mit `-communityPricesNoticeShown YES`) und `CommunityShareNoticeUITests` („Weiter teilen“). Eine App-weite Abschaltung über alle 22 Klassen ist nicht nötig, aber eine zentrale Stelle, die jede künftige Klasse erfasst, ist besser.
Nicht belegt: ob der Versand auf dem Rechner tatsächlich ankommt (CI-Simulator ohne iCloud-Konto scheitert vermutlich mit `notAuthenticated`; lokal mit Konto nicht gemessen). Der Nachweis muss in der Spec messbar werden.

### Empfehlung Teil 2
Ersatz-Datenbank per DEBUG-Argument `-discardCommunityPricesForUITests` (Auswahl wie `PremiumService.defaultStore(arguments:)`, `shared` wählt beim Start). Die Ersatz-Datenbank verwirft und zählt Speicherversuche (Zähler in `UserDefaults.standard`, Schlüssel nur in DEBUG). Die vier Klassen übergeben das Argument; ein Strukturtest erzwingt: jede UI-Testdatei, die `-communityPricesNoticeShown` setzt oder „Weiter teilen“ tippt, enthält das Argument. Der UI-Test `CommunityShareNoticeUITests` prüft nach „Weiter teilen“, dass der Zähler >0 ist (Versand-Pfad lief bis zur Datenbank) und kein echtes CloudKit angesprochen wurde; Unit-Test für die Auswahl (Argument → Ersatz, unbekannt → CloudKit). Release: per `strings` kein Symbol/Argument.
Alternative: Standard „aus“ in DEBUG-Bauten — verworfen, ändert das geprüfte Produktverhalten und der Hinweisablauf wäre nicht mehr fahrbar. Alternative 2: ein Argument in allen 22 Klassen — Vergessensgefahr.

### Teil 1 (Produktfrage, Entwurfsvorschau)
Vorschau: https://claude.ai/artifact/NpRgntQ3tPqFHv7odLuTeT, Datei `docs/artifacts/feat-208-community-nacharbeiten/entwurfsvorschau.html`. Entwurf A: „Voreingestellt an.“ streichen, ein Text. Alternative B: Text nach Schalterstand. Betroffen: `de.lproj`/`en.lproj` `settings.community.footer` (+ bei B ein Schlüssel `…footer.off`, `SettingsView` Zeile 111–115).

### Teil 3
Einzel-Überladung `contributeInBackground(_ contribution:)` (`CommunityPriceService.swift:~179`) löschen; kein Aufrufer (grep geprüft). Unit-Suite grün als Nachweis.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Resources/{de,en}.lproj/Localizable.strings | MODIFY | Fußnote (A: Satz streichen; B: zusätzlich Aus-Text) |
| SmartCart/Views/Settings/SettingsView.swift | MODIFY (nur B) | Fußnote nach Schalterstand |
| SmartCart/Services/CommunityPriceService.swift | MODIFY | Einzel-Überladung löschen; `shared` wählt Datenbank per Argument |
| SmartCart/Services/DiscardingCommunityPriceDatabase.swift (+pbxproj) | CREATE | Ersatz-Datenbank, nur `#if DEBUG`, zählt |
| RestockUITests/{ReceiptReview,ReceiptResolutionStats,DynamicType,CommunityShareNotice}UITests.swift | MODIFY | Argument übergeben; Zähler prüfen |
| RestockTests/CommunityPriceTests.swift | MODIFY | Auswahl-Test |
| scripts/test_ui_tests_discard_community_prices.py | CREATE | Strukturtest |

### Scope Assessment
- Files: ~10 (über 4–5), davon 2 Strings-Dateien, 1 pbxproj, 1 Skript; Estimated LoC: ca. +150/−15 → Bündel unter 250 LoC, Dateizahl über dem Limit → in der Spec offenlegen/Freigabe.
- Risk Level: LOW–MEDIUM (Teil 2 berührt `shared`; nur DEBUG)

### Open Questions
- [ ] Teil 1: Entwurf A oder Alternative B?

### Entscheidung PO (2026-10-22)
Teil 1: Entwurf A (Satz „Voreingestellt an.“ streichen, ein Text für beide Zustände). `SettingsView.swift` bleibt unberührt (~9 Dateien). Offene Frage erledigt.
