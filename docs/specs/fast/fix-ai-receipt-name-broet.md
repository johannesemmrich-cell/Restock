# Fix: KI-Vorschlag „Bröt.“ für alle Bonzeilen

**Gemeldet 18.10.2026:** Beim Scannen eines dm-Bons schlug die KI-Stufe (Stufe 5, `ReceiptNameAIResolver`) für jede Zeile „Bröt.“ vor („Ricola Bonbon Salbei“, „Mentos Gum 3 Fruity Fresh“, …).

## Ursache (abgeleitet, am Gerät nicht reproduziert)

Der Prompt bekam die eigenen Artikelnamen des Nutzers mit der Bitte „bevorzuge eine Übereinstimmung/Ähnlichkeit hiermit“. Steht dort ein früher als Rohtext gespeichertes Kürzel wie „Bröt.“ (jüngster Kauf = erster Listeneintrag), übernimmt das kleine On-Device-Modell diesen Eintrag für jede Zeile. Es gab keine Prüfung danach.

## Änderung

1. Prompt: Eigene Namen nur verwenden, wenn die Bonzeile eindeutig genau diesen Artikel meint, sonst ignorieren.
2. `ReceiptResolutionService.knownItemNames`: Namen, die auf ein Kürzel mit Punkt enden („Bröt.“), kommen nicht mehr in den Prompt.
3. `ReceiptNameAIResolver.sanitize`: Antwort, die auf ein Kürzel mit Punkt endet, wird verworfen (Rohtext bleibt). „Dr. Oetker Pizza“ und „Milch 3.5“ bleiben erlaubt.
4. `ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers`: Liefert das Modell dieselbe Antwort für mindestens drei verschiedene Bonzeilen, bleibt sie nur dort stehen, wo Antwort und Rohtext ein Wort mit denselben ersten drei Buchstaben teilen („Schoko Lolli“ → „Schokolade“); sonst Rohtext.

## Naht für Tests (Nachtrag)

`ReceiptNameAIResolver` nimmt das Modell als `ReceiptNameLanguageModel` (`isAvailable`, `respond(to:)` → rohe Antwort vor `sanitize`); produktiv `SystemReceiptNameLanguageModel` (FoundationModels). `ReceiptResolutionService.resolve` hat den Parameter `aiResolver` (Standard `.shared`, Aufrufer unverändert). Der Prompt steht in `ReceiptNameAIResolver.prompt(for:knownNames:)`.

`RestockTests/ReceiptAIResolutionChainTests.swift` (K1–K7) prüft die ganze Kette mit Schein-Modell, Daten: dm-Bon vom 05.10.2026 und Lidl-Bon aus `ReceiptParserLidlFullReceiptTests`. K2 stellt den vermuteten Ablauf nach (Modell übernimmt den ersten eigenen Namen aus dem Prompt). Was das echte Modell antwortet, misst die lokale Auswertung (eigenes Issue).

## Tests

`ReceiptNameAIResolverSanitizeTests` (Kürzel, gemeldeter Bon, Schokolade-Gruppe, Schwelle, gleiche Rohtexte), `ReceiptKnownItemNamesTests.testExcludesAbbreviatedNames`.

## Offene Grenzen

- Der eigentliche Modellaufruf ist im Simulator/CI nicht testbar; ob die neue Prompt-Formulierung allein reicht, ist erst am Gerät belegbar. Die Prüfungen 3 und 4 greifen unabhängig davon.
- Eine falsche Antwort, die nur ein- oder zweimal vorkommt und kein Kürzel ist, wird weiter angezeigt (der Nutzer sieht jede Zeile vor dem Speichern).
- Bereits gespeicherte „Bröt.“-Einträge in Kaufhistorie oder Aliasen werden nicht bereinigt.
