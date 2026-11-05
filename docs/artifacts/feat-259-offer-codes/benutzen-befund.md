# Benutzen-Befund Offer-Code-Einstieg (#259, AC-9)

Quelle: `build/ui-259.xcresult` (23 Tests, 0 Fehlschläge), Simulator Restock-Validate-272 (iPhone 17 Pro, iOS 27.2).
Exportiert per `xcrun xcresulttool export attachments`. Keine Code-Änderung.

Befund: Im Bündel steckt nur **je ein Bild pro Test, nur helle Darstellung**. Dunkel-Bilder für diese beiden Tests existieren nicht. Die Dateien `*-hell`/`*-dunkel` gibt es nur für den Schließen-Chip (`PurchaseUITests/testCloseChipShowsFullWord`), nicht für den Code-Einstieg.

## Einstellungen (`einstellungen-vor-tipp.png`)

- Einstieg sichtbar: **ja**. Zeile „Code einlösen“ mit Ticket-Symbol im Abschnitt „DATEN“, direkt unter „Restock Pro freischalten“ und über „Geteilter Liste beitreten“.
- Vollständig: **ja**. Zeile ganz im Bild, Chevron rechts, Schrift lesbar.
- Lesbar: **ja**, Standardschrift, kein Abschneiden erkennbar.
- Nach dem Tipp: **nicht belegt**. `einstellungen-nach-tipp.png` ist byte-identisch mit `einstellungen-vor-tipp.png` (MD5 gleich: 2a98b2de…). Das Bild nach dem Tipp zeigt also genau denselben Bildschirm wie davor. Es ist im Bild kein Systemdialog und kein Sheet zu sehen. Ob der Einlöse-Dialog von StoreKit (eigener Prozess) gar nicht in den Screenshot der App fällt oder der Tipp nichts öffnet, lässt sich aus den Bildern nicht entscheiden. Das Testprotokoll (`OfferCode: nach Tipp …`-Zeile mit Alert- und Sheet-Zahl) liegt im Bündel nicht vor, die Aussage „kein Alert/Sheet im Baum, App im Vordergrund“ aus der Aufgabe ist deshalb nicht aus dem Bündel belegt. Die Bilder zeigen nur: Die App läuft weiter, nichts Sichtbares passiert.

## Paywall (`paywall-vor-tipp.png`)

- Einstieg sichtbar: **ja**. „Code einlösen“ als Textknopf unter „Käufe wiederherstellen“, über den Rechtslinks.
- Vollständig: **ja**. Knopf im Bild, Abstand zu den Rechtslinks sichtbar, Schließen-Chip oben vollständig.
- Lesbar: **ja**, grau auf hellem Grund, deutlich lesbar, aber schwächer als „Käufe wiederherstellen“ (gleiche Farbe wie der Rest, kein Kontrast gemessen).
- Nach dem Tipp: **nicht belegt**. Für die Paywall gibt es **kein** Nach-Tipp-Bild, der Test macht nur ein Bild vor dem Tipp.

## Auffälligkeit: AccessibilityXXXL (`paywall-xxxl-vor-tipp.png`)

Dieses Bild stammt aus `testPaywallRedeemCodeButtonAtLargestTextSize`, nicht aus den beiden AC-9-Tests. Es ist byte-identisch zu `paywall-vor-tipp.png` (MD5 9766b178…). Die Schrift ist in beiden gleich groß. Das Launch-Argument für die größte Schrift hat im Bild also offenbar keine Wirkung gehabt. Das ist nicht bewiesen, aber es ist das, was die Bilder zeigen. Der XXXL-Test ist damit im Bild nicht belegt.

Nachtrag Orchestrator: Ursache ist der Bestand, nicht die neue Änderung. `PaywallView.swift` nutzt 16-mal feste Schriftgrößen (`.system(size:)`) ohne Dynamic-Type-Anbindung, die Paywall wächst bei größter Schrift also nicht mit. Der XXXL-Test belegt hier nur Lage und Antippbarkeit, nicht das Aussehen bei großer Schrift. Das Launch-Argument kommt beim Prozess an (identische Übergabe wie in `DynamicTypeUITests`). Offene Grenze, nicht Teil von #259.

## Kurz

| Bild | Einstieg sichtbar | vollständig | lesbar | nach Tipp |
|---|---|---|---|---|
| einstellungen-vor-tipp.png | ja | ja | ja | nicht belegt, identisch zu „nach Tipp“ |
| paywall-vor-tipp.png | ja | ja | ja | nicht belegt, kein Bild vorhanden |
