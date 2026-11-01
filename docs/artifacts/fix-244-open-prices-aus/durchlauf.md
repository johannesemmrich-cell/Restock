# Durchlauf im Simulator — #244 Open Prices in 1.0 ausgeblendet

- Datum: 2026-11-01, 11:05
- Simulator: Restock-Validate-27 (`9034BD4F-2D5F-49D5-B906-838326D51C95`), iOS 27
- Stand: Arbeitsstand von `fix-244-open-prices-aus` (Produktänderung in `OpenPricesContributionService.swift` und `SettingsView.swift`), Debug-Build aus `build/dd-244`. Konstante gilt in Debug und Release gleich.
- Ablauf: `xcodebuild test` mit `RestockUITests/testSettingsHideOpenPrices` (Einstellungen öffnen, bis „Standard-Läden“ wischen) und `ReceiptReviewUITests/testSavedReceiptShowsReceiptAsPriceSource` (Bon-Prüf-Screen mit Seed, Speichern tippen, Preisquelle „Bon“ in der Liste). Protokoll `durchlauf-log.txt`, Ergebnis `durchlauf.xcresult`: Executed 2 tests, with 0 failures.

## Vorher
`openPricesContributionEnabled` per `simctl spawn … defaults write` auf `YES` gesetzt (`durchlauf-defaults-vorher.txt`): Schalter wie bei einem TestFlight-Tester, der ihn eingeschaltet hatte.

## Gesehen
- `durchlauf-bilder/C7F38FEB-B42E-4DF4-8C74-E0976C3D9FA6.png`: Einstellungen → Funktionen: Siri & Schnellzugriff, Benachrichtigungen, Ausgeblendete Vorschläge, Standard-Läden — danach direkt Abschnitt „Daten“. Kein Eintrag „Open Prices“.
- `durchlauf-bilder/8156AF7D-A6AE-4C7A-A809-F4D000FE4425.png`: nach dem Nachziehen dasselbe, Fußzeile „Restock 1.0 (38)“.
- Bon gespeichert, Liste zeigt die Preisquelle „Bon“ (Testbehauptung grün).

## Nachher
`durchlauf-defaults-nachher.txt`: nur `openPricesContributionEnabled = 1`, kein Schlüssel `openPricesLastResult` — es wurde kein Beitrag versucht oder protokolliert.

## Grenze dieses Belegs
Im Simulator gibt es weder Open-Food-Facts-Token noch Filiale; ohne die Sperre hätte der Dienst hier mit `.notLoggedIn` ebenfalls nichts gesendet. Dass die Sperre auch bei vollständiger Bereitschaft (Schalter, Token, Filiale, Foto) greift, belegen nur die Unit-Tests `testUnavailableServiceNeverSends` und `testSharedServiceIsUnavailable`. Nichts auf Hennings Geräten geprüft.
