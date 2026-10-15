# Pflicht-Durchlauf #145 Durchgang 1 (AC-10)

- Stand: Commit a03ecd7769cc61b21740c91972d7caecdf97dbbe, Lauf 2026-10-15 13:04–13:05 (MESZ)
- Ziel: Simulator Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7). Kein Gerät des Users berührt.
- App: Debug-Build aus der Gesamtsuite desselben Stands (Worktree sauber = HEAD), per `simctl install` eingespielt;
  md5 gebaut = md5 installiert (`5c4389f9…`), beide Argumente im installierten Binary vorhanden.
- Rohprotokoll: `durchlauf-protokoll.txt`.

## Beobachtung

1. **Start ohne Test-Argumente** direkt nach der Gesamtsuite (`durchlauf-1-ohne-argumente.png`): Startseite ohne
   DEV-Pill; `defaults read com.johannesemmrich.Restock developerMode` → „does not exist“. Die Suite hat nach
   `DeveloperModeUnlockUITests` (Entsperren schreibt `developerMode = true`) also wirklich aufgeräumt (AC-4).
2. **Start nur mit `-devPasswordHashForUITests 0000`** (`durchlauf-2-nur-hash-argument.png`): Startseite ohne
   DEV-Pill, `developerMode` existiert weiter nicht — die Überschreibung allein entsperrt nichts, sie ändert nur
   den Vergleichswert im Passwort-Sheet.
3. Kein Absturz, kein Absturzbericht.

## Grenze dieses Durchlaufs

Der Simulator läuft fensterlos; `simctl` kann nicht tippen. Die Tippkette (5× „Version“, Passwort, „Entsperren“
bzw. falsches Passwort und „Abbrechen“) ist deshalb nur über XCUITest belegt: in der Gesamtsuite
`DeveloperModeUnlockUITests` (Richtig-Pfad bis DEV-Pill und Neustart, Falsch-Pfad mit Überschreibung) und
`PaywallUITests.testWrongDevPasswordShowsErrorAndKeepsSheetOpen` (ohne Überschreibung, Release-Hash) grün,
`full-suite-ui-gruen-unit-haenger.txt`. Release-Pfad mit echtem Passwort: ungetestet (Passwort dem Test unbekannt).
