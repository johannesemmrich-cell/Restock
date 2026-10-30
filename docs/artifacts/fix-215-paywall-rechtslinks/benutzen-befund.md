# AC-11: Benutzen statt nur testen, Paywall unten (Issue #215)

- Commit: 44c7e31 plus ungestagte Umsetzung (`SmartCart/Views/Premium/PaywallView.swift` +51/−3,
  `RestockUITests/PurchaseUITests.swift` +1/−1); der Stand ist noch nicht committet
- Zeit: 2026-10-30, Aufnahmen 17:32 CET
- Gerät: Simulator Restock-Validate-27 (9034BD4F-2D5F-49D5-B906-838326D51C95), iOS 27, 1206×2622

## Erzeugung

1. `xcrun simctl ui <udid> appearance light`, dann
   `-only-testing:RestockUITests/PaywallUITests/testLegalLinksReachableOnPaywall` mit eigenem `-resultBundlePath`
   (`hell.xcresult`): 1 Test, 0 Fehlschläge (`benutzen-hell-run.txt`).
2. `appearance dark`, derselbe Test mit eigenem `-resultBundlePath` (`dunkel.xcresult`): 1 Test, 0 Fehlschläge
   (`benutzen-dunkel-run.txt`). Danach `appearance light` (Ausgangszustand) wiederhergestellt.
3. Export mit `xcrun xcresulttool export attachments`. Laut `manifest.json` hat je Lauf genau ein Anhang den
   Namen mit Anfang „paywall-unten“:
   - hell: `D27F08C3-A8E0-4D0F-AE0D-BDB82DC12D7B.png` („paywall-unten_0_E3FC870B-….png“) → `paywall-unten-hell.png`
   - dunkel: `FF0DAF0D-FBEC-48CB-86F6-A956957BB601.png` („paywall-unten_0_3FF61DB9-….png“) → `paywall-unten-dunkel.png`

## Befund (Bildansicht)

| Bild | Abo-Text vollständig | beide Links vollständig |
|------|----------------------|-------------------------|
| `paywall-unten-hell.png` | ja | ja |
| `paywall-unten-dunkel.png` | ja | ja |

Je Bild liegt der Abo-Text vollständig im Bild, sieben Zeilen von „Restock Pro – Jährlich: 1 Jahr, 8,99 €/Jahr.“
bis „… verlängert sich nicht.“. Darunter steht die Link-Zeile „Datenschutz · Nutzungsbedingungen (EULA)“ in einer
Zeile, beide Links unterstrichen und nicht abgeschnitten. „Käufe wiederherstellen“ steht darüber. Die Preise sind
die Ersatzpreise der Paywall (8,99 €/Jahr, 1,99 €/Monat), weil `products` im Simulator leer ist.

AC-11 ist erfüllt.

Beobachtung: Der Abo-Text ist in `.tertiary` gesetzt (wie der Bestandstext „Alle Preise inkl. MwSt. …“) und
deutlich blasser als die Links. In beiden Modi ist er lesbar, aber kontrastarm, besonders im Dunkelmodus. Gemessen
wurde der Kontrast nicht. Die Farbe folgt der Spec (Ziffer 2: `.tertiary` wie bisher).
