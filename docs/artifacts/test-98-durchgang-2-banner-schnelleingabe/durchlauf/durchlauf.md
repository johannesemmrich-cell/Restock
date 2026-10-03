# Pflicht-Durchlauf (AC-19) — #98 Durchgang 2

- Stand: Commit `0aa2a1a`, Arbeitskopie ohne Änderungen an Produktcode seit diesem Commit
- Zeitpunkt: 2026-10-03, 18:29–18:32 Uhr (Systemuhr des Simulators, in den Bildern sichtbar)
- Gerät: Simulator „Restock-Validate", Debug-Build mit Seed `-seedReplenishmentForUITests` und `-developerMode YES`
- Art: echte Bedienung der App durch den Testläufer, dabei alle 2 s ein Bildschirmfoto per `simctl io screenshot`
  (Lauf 1: `testBannerPlusAddsItemToStoreList`, `testAlsoDuePlusAddsItem`, 2 Tests grün;
  Lauf 2: `testBannerStillHaveItHidesSuggestion`, `testBannerBlockSurvivesRestart`,
  `testBannerAddAllAddsEverything`, `testAlsoDueBlockSurvivesRestart`, 4 Tests grün)

## Bilder
1. `01-banner.png` — Banner „Zeit zum Nachkaufen" mit Bannerbutter und Bannerquark (Seed: nur Läden und rückdatierte Käufe)
2. `02-ladenliste-nach-plus.png` — Listenladen: „Vielleicht auch fällig" zeigt Listennudeln, Listenreis steht nach `+` in der Einkaufsliste
3. `03-bannerladen-nach-plus.png` — Bannerladen: Bannerbutter steht nach `+` in der Liste
4. `04-ablauf-hab-noch-sperre-alle-hinzufuegen.png` — Kontaktbogen: geöffnetes Menü („Hab noch" / „Nicht mehr vorschlagen"),
   Zustand nach Neustart (gesperrter bzw. verschobener Vorschlag bleibt weg), „Alle hinzufügen" (Banner weg, „Bannerladen · 2")

## Beobachtung am Rand (kein Fehler dieses Durchgangs)
Banner-Artikel mit Fälligkeit „in knapp einem Tag" stehen als „Überfällig" da (Abrundung auf ganze Tage). Die Tests sind davon nicht abhängig;
ob die Anzeige so gewollt ist, ist eine Produktfrage und gehört nicht zu diesem Durchgang.
