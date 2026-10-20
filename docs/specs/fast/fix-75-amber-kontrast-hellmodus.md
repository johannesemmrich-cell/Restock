# Fix: Warnfarbe Amber unter WCAG-AA-Kontrast im Hellmodus (Issue #75)

**Gemeldet 30.09.2026 bei der Spec zu #57, umgesetzt 20.10.2026 (Meilenstein „Öffentliches Release 1.0“, PO-Entscheidung „A“).**

## Befund

`Color.amber` (`RCAmber`) ist die App-weite Farbe für Nachkauf-Dringlichkeit und seit #57/#160 für „ca.“-Mengen, „ca.“-Preise, die Quelle „Schätzung“ und den Chip „Preis?“. Im Hellmodus erreichte sie 3,52:1 gegen `RCSurface` und 3,64:1 gegen die weiße Karte; WCAG 2.1 AA (Kriterium 1.4.3) verlangt für Fließtext 4,5:1. Dunkelmodus: 6,64:1, in Ordnung.

## Entscheidung

Entwurfsvorschau mit Ist, Vorschlag A (dunklerer Amber) und Alternative B (Farbe bleibt, „≈“ und fette Schrift) in `docs/artifacts/fix-75-amber-kontrast/entwurfsvorschau.html`; PO am 2026-10-20: **A**.

## Änderung

- `Assets.xcassets/RCAmber.colorset`: Hellmodus 0,663/0,498/0,180 → **0,544/0,408/0,148** (alle Kanäle × 0,82, Farbton bleibt Amber). Dunkelmodus unverändert.
- Kein Code: alle Stellen (`ItemRow`, `HomeView`-Banner, `StoreDetailView` „Vielleicht auch fällig“, `ReplenishmentStatsView`) lesen das Token. Die Banner-Hintergründe mit 12–16 % Deckkraft sind kein Text und werden nur unwesentlich dunkler.

## Kontrast

| Modus | Vorher | Nachher | gegen |
|---|---|---|---|
| Hell | 3,52:1 | **4,94:1** | `RCSurface` 0,992/0,984/0,957 |
| Hell | 3,64:1 | **5,12:1** | weiße Karte |
| Dunkel | 6,64:1 | 6,64:1 | `RCSurface` 0,114/0,110/0,086 |

## Tests

`AssignmentServiceQuantitySuggestionTests.testAmberLightModeContrastMeetsWCAGAA` (neu, gegen Hintergrund und Karte) neben dem bestehenden `testAmberDarkModeContrastMeetsWCAGAA`. Beide halten die Werte aus dem Asset-Katalog als Literale fest; ein Zurückdrehen der Farbe macht den Test rot, ein Abweichen des Katalogs vom Test fällt nur bei bewusster Pflege auf (Grenze wie bisher, in der Spec zu #57 begründet).

## Offene Grenzen

- Der Test liest nicht den Asset-Katalog selbst, sondern die abgeschriebenen Werte.
- Sichtprüfung am Gerät im Hellmodus steht aus (#187).
- Die UI-Tests prüfen Texte, keine Farben; sie sind von der Änderung nicht betroffen.
