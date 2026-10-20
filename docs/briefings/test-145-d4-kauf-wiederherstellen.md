---
spec_file: docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md
spec_sha256: 70034930eb3b30cd55b24b2344e8586b0139e312c1fce73a3cdeb4619376eef0
spec_frozen_sha256: 5c887118dc35ea8ffae9e5c357558383a71f7cab4c5ef9efea503a0e78f0dd8f
---

# PO-Briefing: test-145-d4-kauf-wiederherstellen

- **Spec:** docs/specs/ui-tests/test-145-durchgang-4-kauf-wiederherstellen.md
- **Issue:** #145
- **Erstellt:** 2026-10-19

## Was gebaut wird

Kauf und Wiederherstellen von Restock Pro melden jeden Ausgang verständlich; der Schließen-Knopf zeigt wieder sein vollständiges Wort.

## Definition of Done

Alle acht simulierten Kaufausgänge zeigen im Simulator den richtigen Hinweis, alle Tests laufen grün, und der Release-Build enthält keinen Testcode.

## Wie geprüft wird

Tests beweisen unsere Logik und die Paywall gegen einen Ersatz-Appstore, nicht Apples echten Kaufdialog oder einen echten Kauf.

## Kritische Anmerkungen

- Echter Kauf bleibt ungeprüft; ob die drei Produkte in App Store Connect existieren, weiß niemand (#175).
- Umfang liegt bei etwa 570 statt freigegebener 450 Zeilen, sieben Dateien.
- Ursache des abgekürzten Schließen-Knopfs unbekannt; der Fix könnte andere Bildschirme verändern.

## Freigabe-Frage

Gibst du die neuen Kaufhinweise frei, obwohl der echte Kauf erst später auf deinem iPhone geprüft wird?
