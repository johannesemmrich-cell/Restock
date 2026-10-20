# Durchlauf als Nutzer im Simulator (AC-18) — #145 Durchgang 4

## Runde 3 (Adversary, nach Fix-Runde 1) — maßgeblicher Stand

- Zeitstempel: 2026-10-20, 06:45–06:48 CEST (Restock-Validate), 06:49–06:53 CEST (Wegwerf-Simulator iPhone SE 3. Generation)
- Stand: Commit 18954a4fabeff887efee37083d7dbd29e446e5a8 plus uncommittete Phase-6-Änderungen (inkl. Fix-Runde 1). Produktcode `SmartCart/` der Prüfkopie byte-gleich zum Arbeitsstand (`diff -rq` leer). SHA-256 zum Zeitpunkt des Laufs: PaywallView.swift 86c1d734…, PremiumService.swift a4bcc4c0…, FakePurchaseStore.swift c946312e…, DesignSystem.swift b8827cc3…
- Geräte: Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7, iOS 26.5, 402 × 874 pt) und Wegwerf-Simulator `Restock-Adv3-SE` (iPhone SE 3. Generation, iOS 26.5, 375 × 667 pt, nach dem Lauf gelöscht)
- Weg: Wegwerf-UI-Test `AdversaryRunde3UITests` in einer Scratchpad-Kopie (nur an `PurchaseUITests.swift` angehängt), Start je Fall mit `-hasCompletedOnboarding YES -developerMode NO [-purchaseScenarioForUITests <name>]`, Tipp ohne vorheriges Wischen, wenn der Knopf antippbar ist. Restock-Validate: 13 Abläufe, 12 grün, 1 Abbruch im Prüfablauf selbst (W2: zweimaliges Wischen nach unten hat das Sheet geschlossen, kein Produktbefund); SE: 13/13 grün. Protokoll: `durchlauf-hinweis-sichtbarkeit-runde3.log`, Screenshots `durchlauf-r3-h874-*.png` und `durchlauf-r3-h667-*.png`.

### (a) Ohne Szenario-Argument (echtes StoreKit)

- Kaufknopf „Jetzt freischalten — 8,99 €/Jahr“ (Ersatzpreis, keine Produkte). Kaufen → Paywall offen, „Der Kauf konnte nicht geladen werden. Bitte versuche es später erneut.“, vollständig sichtbar (y 809,7–840,0 von 874). `durchlauf-r3-h874-ohne-szenario-kauf.png`
- „Käufe wiederherstellen“ → Systemdialog „Bei Apple Account anmelden“ (Springboard-Alert), `durchlauf-r3-h874-ohne-szenario-wiederherstellen-2s.png`. „Abbrechen“ getippt → Paywall offen, wörtlich: „Wiederherstellen wurde nicht abgeschlossen. Wenn du nicht selbst abgebrochen hast, prüfe die Internetverbindung und versuche es erneut.“ auf der Akzentfläche, vollständig sichtbar (y 776,3–828,0), kein Absturz, keine Fehlermeldung. `durchlauf-r3-ohne-szenario-wiederherstellen-abbruch.png`. Auf dem SE identisch (y 603,0–655,0 von 667).

### (b) Neun Szenarien (acht der Spec plus `restoreCancel`)

| Szenario | Ausgang | Sichtbarkeit 874 pt | Sichtbarkeit 667 pt (SE) |
|---|---|---|---|
| `success` | Paywall zu, fork.knife öffnet Rezeptplan | – | – |
| `cancel` | Paywall offen, kein Hinweis | – | – |
| `pending` | Info „Der Kauf wartet auf Zustimmung …“ | voll, nach 0,1 s, y 794,3–828,0 | voll, y 603,0–655,0 |
| `fail` | Fehler „Kauf fehlgeschlagen: Testfehler Kauf“ | voll, y 825,7–840,0 | voll, y 652,5–667,0 |
| `productMissing` | Fehler „Der Kauf konnte nicht geladen werden …“ | voll, y 809,7–840,0 | voll, y 636,5–667,0 |
| `restoreNone` | Info „Kein Kauf gefunden …“ | voll, y 776,3–828,0 | voll, y 603,0–655,0 |
| `restoreFound` | Paywall zu, Rezeptplan frei | – | – |
| `restoreFail` | Fehler „Wiederherstellen hat nicht geklappt …“ | voll, y 809,7–840,0 | voll, y 636,5–667,0 |
| `restoreCancel` | Info „Wiederherstellen wurde nicht abgeschlossen …“ (Akzentfläche) | voll, y 776,3–828,0 | voll, y 603,0–655,0 |

Screenshots: `durchlauf-r3-h874-messung-*.png`, `durchlauf-r3-h874-ausgang-*.png`, gleiche Namen mit `h667`; `durchlauf-restoreCancel.png` (= `durchlauf-r3-h874-messung-restoreCancel.png`).

### Kante: derselbe Hinweis ein zweites Mal (Finding F004)

- `productMissing`, 874 pt: erster Tipp → Hinweis voll sichtbar. Nutzer rollt nach oben (zwei Wischer nach unten), Kaufknopf bleibt bei y 775,7 antippbar, Hinweis bei y 870,7 (11 % sichtbar). Zweiter Tipp auf Kaufen → **kein Hinrollen**, Hinweis bleibt bei y 870,7, 11 % sichtbar, unten angeschnitten. `durchlauf-r3-wiederholung-productMissing.png`
- Gegenprobe `restoreCancel` (asynchroner Weg), gleicher Ablauf: zweiter Tipp → Hinweis voll sichtbar (y 776,3). Ursache: In `PaywallView.purchase()` werden `notice = nil` und `notice = .error(…)` ohne `await` dazwischen gesetzt; SwiftUI sieht keinen Wechsel, `.onChange(of: notice)` feuert nicht.
- SE: Dort war der Kaufknopf nach dem Hochrollen nicht antippbar, das Wischen zum Knopf brachte den Hinweis mit ins Bild — die Kante tritt dort in diesem Ablauf nicht auf.

---

## Runde 1 (2026-10-19, vor Fix-Runde 1, überholt)

- Zeitstempel: 2026-10-19, 18:29–18:32 CEST (Szenarien und echter StoreKit-Weg), 18:40 CEST (Sichtbarkeitsmessung)
- Stand: Commit 18954a4fabeff887efee37083d7dbd29e446e5a8 plus uncommittete Phase-6-Änderungen (Produktcode `SmartCart/` byte-gleich zur Prüfkopie, `diff -rq` leer)
- Gerät: Simulator Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7, iOS 26.5, 402 × 874 pt), Bundle-ID `com.johannesemmrich.Restock` (aus `project.pbxproj`; die im Auftrag genannte `com.johannesemmrich.smartcart` ist das Präfix der Produkt-IDs, nicht der App)
- Weg: Wegwerf-UI-Test `AdversaryDurchlaufUITests` in einer Scratchpad-Kopie des Arbeitsstands (nur die Testdatei ersetzt), Start je Fall mit `-hasCompletedOnboarding YES -developerMode NO [-purchaseScenarioForUITests <name>]`, Tipps wie ein Nutzer, Screenshot per `XCUIScreen.main.screenshot()` direkt in Dateien. Protokoll: `durchlauf-log.txt`, Messung: `durchlauf-hinweis-sichtbarkeit.log`, Sonde: `adversary-sonde-messung.swift.txt`.

## (a) Ohne Szenario-Argument (echtes StoreKit)

- Paywall über fork.knife geöffnet; Kaufknopf zeigt den Ersatzpreis „Jetzt freischalten — 8,99 €/Jahr“ (keine Produkte geladen).
- Kaufen → Paywall bleibt offen, Text „Der Kauf konnte nicht geladen werden. Bitte versuche es später erneut.“ (kein stilles Schließen mehr). Screenshot `durchlauf-ohne-szenario-kauf.png`.
- „Käufe wiederherstellen“ → Knopf „Wird wiederhergestellt…“, iOS zeigt den Systemdialog „Bei Apple Account anmelden“ (Felder Apple Account/Passwort, Knöpfe „Abbrechen“, „OK“), `durchlauf-ohne-szenario-wiederherstellen-2s.png`. Nach „Abbrechen“: Paywall offen, Text „Wiederherstellen hat nicht geklappt. Prüfe die Internetverbindung und versuche es erneut.“ (`durchlauf-ohne-szenario-wiederherstellen-8s.png`, `durchlauf-ohne-szenario-ende.png`). Kein Absturz. Befund: Der Nutzer hat selbst abgebrochen und bekommt einen Internet-Hinweis (Finding F002).

## (b) Acht Szenarien

- `success` (Kaufen): Paywall schließt, fork.knife öffnet danach den Rezeptplan („Tag hinzufügen“). `durchlauf-success.png`, `durchlauf-success-danach.png`
- `cancel` (Kaufen): Paywall offen, kein Hinweis. `durchlauf-cancel.png`
- `pending` (Kaufen): Hinweis „Der Kauf wartet auf Zustimmung. Sobald er bestätigt ist, wird Restock Pro automatisch freigeschaltet.“ im Baum vorhanden, Paywall offen — **auf dem Bildschirm nicht sichtbar** (nur ein Streifen der Akzentfläche am unteren Rand). `durchlauf-pending.png`
- `fail` (Kaufen): „Kauf fehlgeschlagen: Testfehler Kauf“, Paywall offen; nur der obere Rand der Zeile sichtbar. `durchlauf-fail.png`
- `productMissing` (Kaufen): „Der Kauf konnte nicht geladen werden …“, Paywall offen; nur angeschnitten sichtbar. `durchlauf-productMissing.png`
- `restoreNone` (Wiederherstellen): „Kein Kauf gefunden …“, Paywall offen; nicht sichtbar. `durchlauf-restoreNone.png`
- `restoreFound` (Wiederherstellen): Paywall schließt, Rezeptplan frei. `durchlauf-restoreFound.png`, `durchlauf-restoreFound-danach.png`
- `restoreFail` (Wiederherstellen): „Wiederherstellen hat nicht geklappt …“, Paywall offen; nur angeschnitten sichtbar. `durchlauf-restoreFail.png`

## Zusatzwege AC-1 und Kantenfälle

- chart.bar, Szenario `success`: Paywall → Kaufen → Paywall zu → chart.bar öffnet „Ausgaben“ ohne Paywall. `durchlauf-ac1-chartbar-nach-kauf.png`
- Einstellungen, Szenario `success`: Zeile „Restock Pro freischalten“ → Paywall → Kaufen → Paywall zu, Zeile weg, „Pro aktiv“ sichtbar. `durchlauf-ac1-einstellungen-vor-kauf.png`, `durchlauf-ac1-einstellungen-nach-kauf.png`
- Unbekannter Szenarioname `gibtsnicht`: verhält sich wie echtes StoreKit (Ladefehler-Text), kein Absturz. `durchlauf-gibtsnicht.png`
- Doppeltipp auf Kaufen (`pending`): genau ein Hinweis, Paywall offen. Doppeltipp (`success`): Paywall zu, kein Absturz, Rezeptplan frei. `durchlauf-kante-doppeltipp-*.png`

## Sichtbarkeit der Hinweise (Messung, Fenster 0…874 pt)

- pending: Hinweis y = 882,7 … 916,3 → sichtbarer Anteil 0,00, `isHittable` false
- restoreNone: y = 882,7 … 934,3 → 0,00, `isHittable` false
- fail: y = 870,7 … 885,0 → 0,23
- productMissing: y = 870,7 … 901,0 → 0,11
- restoreFail: y = 870,7 … 901,0 → 0,11

Der Kaufknopf (y = 775,7 … 829,7) und „Käufe wiederherstellen“ (y = 845,7 … 862,7) sind ohne Scrollen antippbar; die Paywall scrollt nach dem Tipp nicht zum Hinweis. Screenshots `durchlauf-messung-*.png`.
