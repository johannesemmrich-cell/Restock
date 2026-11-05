# Benutzen-Befund Rückbau Promo-Pool (#259, Durchgang 2, AC-17)

Stand: 2026-11-05, Arbeitsstand des Zweigs `feat/259-d2-promo-rueckbau` (HEAD 37bc8ba plus die uncommitteten Rückbau-Änderungen).
Keine Code-Änderung am Produkt und kein Eingriff in den Worktree.

## Wie die Bilder entstanden

- **Gerät:** Wegwerf-Simulator `Restock-AC17-Wegwerf-20261105` (iPhone 17 Pro, iOS 27.2, `com.apple.CoreSimulator.SimRuntime.iOS-27-2`). Neu angelegt und vor dem gewerteten Lauf gelöscht (`simctl erase`), danach entfernt. Kein echtes Gerät und keins von Hennings Geräten.
- **Weg:** Wie beim Vorgänger (AC-9) per XCUITest mit `XCTAttachment` aus einem echten UI-Lauf, nur hell. Weil kein Bestandstest den Entwickler-Abschnitt oder alle Seiten aufnimmt, lief der Durchgang in einer **Wegwerf-Kopie** der Quellen im Sitzungs-Scratchpad. Dort hängt eine Erweiterung von `PurchaseUITests` mit fünf Tests an (Abschrift: `benutzen-wegwerf-test.swift.txt`). Die App wurde aus derselben Kopie gebaut, also aus genau dem Stand des Worktrees. Im Repo steht dieser Test nicht.
- **Start:** `-hasCompletedOnboarding YES -developerMode NO -purchaseScenarioForUITests cancel` (ohne Pro) bzw. `-developerMode YES` für den Entwickler-Abschnitt (dieses Argument wird nur gelesen, und der Simulator wurde danach gelöscht).
- **Prüfung:** Jede Seite wurde von oben nach unten durchgeblättert. Auf jeder Seite suchte der Test im Element-Baum nach `promo` in Label, Platzhalter oder Kennung, ohne Rücksicht auf Groß- und Kleinschreibung. Die Bilder nach dem Tipp zeigen den **ganzen Bildschirm** (`XCUIScreen.main`), nicht nur die App. So wären auch Systemfenster aus anderen Prozessen zu sehen, anders als im AC-9-Befund.
- **Ergebnis:** 5 Tests, 0 Fehlschläge (`benutzen-lauf-output.txt`). Auf allen Seiten gab es 0 Promo-Treffer (Einstellungen 14 Seiten, Entwickler 13, Paywall 2).

## Einstellungen ohne Pro

`einstellungen-oben.png`: Profil, Darstellung, Region, Funktionen. `einstellungen-vor-tipp.png`: Funktionen-Ende, Daten, Support. `einstellungen-unten.png`: Daten bis Fußzeile „Restock 1.0 (39)“.

- **Einstieg sichtbar:** ja. Zeile „Code einlösen“ mit Ticket-Symbol im Abschnitt „DATEN“, zwischen „Restock Pro freischalten“ und „Geteilter Liste beitreten“.
- **Vollständig:** ja. Die Zeile liegt ganz im Bild, mit Chevron.
- **Lesbar:** ja (Standardschrift, kein Abschneiden).
- **Kein Promo-Feld:** ja. Auf keiner Seite gibt es ein Eingabefeld „Promo-Code“ oder einen Knopf „Einlösen“. Der Baum liefert auf allen 14 Seiten 0 Treffer.
- **Nach dem Tipp (`einstellungen-nach-tipp.png`, ganzer Bildschirm, 5 s nach dem Tipp):** Es ist **nichts Sichtbares passiert**. Der Bildschirm gleicht dem Bild vor dem Tipp. Laut Protokoll ist die App im Vordergrund (Zustand 4), es gibt 0 Alerts und 0 Sheets, und die Zeile ist weiter antippbar. Das deckt sich mit dem AC-9-Befund. Da diesmal der ganze Bildschirm aufgenommen wurde, ist belegt, dass auch **kein Systemfenster** erschien.

## Paywall

`paywall-oben.png` (Kopf bis „Käufe wiederherstellen“), `paywall-vor-tipp.png` (Abschnitte bis zu den Rechtslinks).

- **Einstieg sichtbar:** ja. Textknopf „Code einlösen“ unter „Käufe wiederherstellen“, über dem Abo-Text und „Datenschutz · Nutzungsbedingungen (EULA)“.
- **Vollständig:** ja, ganz im Bild. Der Schließen-Chip ist voll ausgeschrieben.
- **Lesbar:** ja, grau auf hellem Grund, schwächer als „Käufe wiederherstellen“ (Kontrast nicht gemessen).
- **Kein Promo-Feld:** ja, auf beiden Seiten 0 Treffer.
- **Nach dem Tipp (`paywall-nach-tipp.png`, ganzer Bildschirm):** Über der Paywall öffnet sich ein **leeres weißes Blatt** vom unteren Rand fast bis oben. Die Paywall ist dahinter abgedunkelt, „Schließen“ ist noch angeschnitten zu sehen. Inhalt, Titel und Eingabefeld fehlen. Im Baum der App erscheint das Blatt nicht (0 Sheets, 0 Alerts, Knopf laut XCUITest weiter „antippbar“). Es gehört also sehr wahrscheinlich zu einem fremden Prozess, vermutlich Apples Einlöse-Fenster, das im Simulator ohne App-Store-Anmeldung leer bleibt. Das ist Deutung, nicht belegt.

## Entwicklermodus-Abschnitt

`entwickler-abschnitt-anfang.png` (Daten, Support, Kopf „Entwickler“ mit „Feedback“), `entwickler-abschnitt-ende.png` (ganzer Abschnitt bis Fußzeile).

- **Abschnitt erreicht:** ja. Einträge: Feedback, Todos & Ideen, Nachkauf-Statistik, Bon-Auflösung, iCloud-Abgleich („Einrichtung fehlgeschlagen · 18:33“, im Simulator ohne iCloud-Konto zu erwarten), Doppelte Läden („keine“), KI-Preisschätzung (aus), Developer Mode deaktivieren.
- **Kein „Promo-Codes“:** ja. Der Eintrag fehlt im Bild, und der Baum liefert auf allen 13 Seiten 0 Treffer. Unter allen gesehenen Labels ist keins mit „promo“.
- Im Entwicklermodus steht unter „DATEN“ „Pro aktiv“ und **keine** Zeile „Code einlösen“. Das ist so gewollt, die Zeile gibt es nur ohne Pro.

## Kurz

| Bild | Einstieg sichtbar | vollständig | lesbar | Promo-Feld | nach Tipp |
|---|---|---|---|---|---|
| einstellungen-vor-tipp.png | ja | ja | ja | keins | nichts Sichtbares, kein Systemfenster |
| paywall-vor-tipp.png | ja | ja | ja | keins | leeres weißes Blatt (fremder Prozess, Deutung) |
| entwickler-abschnitt-*.png | – | ja | ja | kein „Promo-Codes“ | – |

## Auffälligkeiten

1. **Gleicher Eingang, anderes Verhalten.** Derselbe Einlöse-Aufruf öffnet in der Paywall ein leeres weißes Blatt, in den Einstellungen gar nichts. Die Ursache ist nicht untersucht. Mögliche Ursachen sind ein anderer Präsentationskontext (die Einstellungen sind selbst ein Sheet) oder der Simulator. Ob in den Einstellungen auf einem echten Gerät etwas erscheint, ist **nicht belegt**. Diese Lücke stammt aus Durchgang 1, nicht aus dem Rückbau.
2. Das leere Blatt der Paywall hat sichtbar keinen eigenen Schließen-Knopf. Im Simulator käme man nur per Wischen heraus (nicht ausprobiert).
3. Das Blättern ist im Einstellungs-Sheet träge: Manche Wisch-Gesten bewegen die Liste nicht. Deshalb gibt es mehrere fast gleiche Seitenbilder. Die ganze Liste ist trotzdem abgedeckt (oben, Mitte, unten).
4. Es gibt nur helle Bilder. Dunkel und größte Schrift wurden nicht aufgenommen (nicht verlangt).
