# Context: fix-208-community-nacharbeiten

## Request Summary
Nacharbeiten aus #186 (Issue #208): (1) Fußnote unter „Preise anonym mit anderen teilen“ begann mit
„Voreingestellt an.“ und stand so auch unter dem ausgeschalteten Schalter; (2) Bestands-UI-Tests
speichern Bons mit Schalter auf Standard „an“ und senden damit echte `CommunityPrice`-Records an die
CloudKit-Entwicklungsumgebung; (3) `contributeInBackground(_ contribution:)` (Einzel-Überladung) ohne
Aufrufer seit #186.

## Entscheidungen (Tech Lead, 2026-10-22; PO hat die Bearbeitung delegiert)
- Teil 1: Fußnote folgt dem Schalterstand. An: bisheriger Text ohne „Voreingestellt an.“; aus: „Aus.
  Beim Bon-Scan und bei ‚Preis eintragen‘ verlässt kein Preis das Gerät. Preise anderer Nutzer
  erscheinen weiterhin als ‚Community‘.“ Der Standard steht weiterhin in `LegalView`. Entwurfsvorschau
  hell/dunkel: `docs/artifacts/fix-208-community-nacharbeiten/entwurfsvorschau.html`.
- Teil 2: DEBUG-Launch-Argument `-blockCommunityContributionsForUITests` → `CommunityPriceService.shared`
  bekommt `BlockedCommunityPriceDatabase` (Speichern und Lesen werfen; Lesen wirft, damit ein leeres
  Ergebnis nicht Aggregate aus dem Zwischenspeicher entfernt). Auswahl als reine Funktion
  `defaultDatabase(arguments:)` (Muster `PremiumService.defaultStore(arguments:)`). Strukturtest
  `scripts/test_ui_tests_block_community_contributions.py`: jede UI-Testdatei mit
  `-seedReceiptReview…ForUITests` oder `-clearCommunityPricesNoticeForUITests` muss das Argument setzen.
- Teil 3: Überladung entfernt; die Listenfassung bleibt (zwei Aufrufer in `CommunityShareNotice.swift`).

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/CommunityPriceService.swift` | `shared`, `defaultDatabase(arguments:)`, `blockContributionsArgument`, `BlockedCommunityPriceDatabase` (DEBUG) |
| `SmartCart/Views/Settings/SettingsView.swift` | Fußnote je Schalterstand |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `settings.community.footer` (ohne „Voreingestellt an.“), neu `settings.community.footer.off` |
| `RestockUITests/{ReceiptReview,ReceiptResolutionStats,DynamicType,CommunityShareNotice}UITests.swift` | setzen das Sperr-Argument |
| `RestockTests/CommunityPriceTests.swift` | `testDefaultDatabaseIsBlockedOnlyWithArgument`, `testBlockedDatabaseSendsNothingAndKeepsCache`, Schlüsselliste |

## Offene Grenzen
- Nachweis „kein Record im Pool“ ist strukturell (Argument gesetzt, Datenbank lehnt ab), nicht per
  Abfrage der Entwicklungsumgebung nach einem CI-Lauf.
- Ältere Fremddaten aus früheren UI-Läufen bleiben im Development-Pool (nur Development, nie Production).
