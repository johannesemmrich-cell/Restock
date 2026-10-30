# AC-8: Rechtsblock auf den Paywall-Store-Bildern (Issue #215)

- Stand: Commit 44c7e31 plus ungestagte Umsetzung (`PaywallView.swift`, `PurchaseUITests.swift:274`)
- Zeit: 2026-10-30, 17:21–17:24 CET
- Gerät: Simulator Restock-Validate-27 (9034BD4F-2D5F-49D5-B906-838326D51C95), iOS 27, Bildgröße 1206×2622
- Lauf: `StoreScreenshotCaptureUITests/testCaptureGerman` und `testCaptureEnglish`, 2 Tests, 0 Fehlschläge
  (Protokoll `store-shots-run.txt`), Ablage `TEST_RUNNER_RESTOCK_STORE_SHOTS_DIR` = `docs/artifacts/fix-215-paywall-rechtslinks/store-shots/`
  (Wegwerf-Ablage, die echten Store-Bilder sind unberührt)

| Bild | Befund |
|------|--------|
| `store-shots/de/05-pro.png` | **nicht sichtbar** |
| `store-shots/en/05-pro.png` | **nicht sichtbar** |

Beide Bilder enden unten am angeschnittenen Knopf „Käufe wiederherstellen“. Weder der Abo-Text noch die
Link-Zeile liegen im Bild. Nach AC-8 ist damit nichts weiter zu tun.

Nebenbefund (nicht Teil von #215): Auch `en/05-pro.png` zeigt die Paywall auf Deutsch, weil die Paywall-Texte
nur deutsch sind (Bestand, siehe Offene Grenzen der Spec).

Offene Grenze: Die Aussage gilt nur für die Größe 1206×2622 von Restock-Validate-27, nicht für die zweite
Größenklasse 1320×2868.
