# Benutzen-Befund AC-10 (2026-11-09)

Aufbau: Debug-Build, Simulator Restock-Validate-272, Start über `UITestLaunch` mit
`-purchaseScenarioForUITests productsLoadLate -developerMode NO`; Paywall per fork.knife geöffnet,
„Jetzt freischalten“ getippt (`PurchaseUITests/testProductsLoadLateStillPurchasable`, 1 Test, 0 Fehlschläge).

Aufnahme nach dem Tipp: `nach-kauf.png` — kein Fehlertext, Paywall geschlossen (Startseite sichtbar).

Grenze: Ersatz-Appstore, kein echter StoreKit-Kauf; Laden in Apples Prüfumgebung nicht nachstellbar.
