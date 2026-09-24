# Mini-Spec: Bon-Parser — Bestätigungszeile nach STORNO wird zur Phantom-Position

## Was ändert sich
- In `ReceiptParserService.parseClassic` wird eine reine Mengen-/Gewichts-Bestätigungszeile
  (z. B. `"-4 Stk x 0,39"` oder `"4 Stk x 0,39"`), die direkt auf eine STORNO-Zeile folgt,
  ab sofort übersprungen statt in den `" x "`-Zweig zu laufen.
- `pendingStornoCancel` bleibt dabei unverändert `true` (wird NICHT verbraucht), damit die
  eigentliche Storno-Erkennung weiter unten (Namens-/Preis-Pfad) beim nächsten passenden
  Zeilenpaar wie gewohnt greift.

## Was darf sich nicht ändern
- Bestehendes Verhalten von `pendingStornoCancel` außerhalb dieses Falls (Storno gefolgt von
  Namens-/Preiszeile, Storno gefolgt von reiner Preiszeile) bleibt unverändert.
- Bestehendes Verhalten der Mengen-/Gewichts-Bestätigungszeile OHNE vorausgehendes STORNO
  (Zeile 374–385) bleibt unverändert — inkl. der Rechenprobe Menge × Rate ≈ Zeilenpreis.
- Kein neues Datenfeld, keine API-Änderung.

## Acceptance Criteria
- **AC-1:** `ReceiptParserService.parseClassic` liefert für die Zeilenfolge `["GOUDA JUNG 1,65 B", "LAUGENBROETCHEN 1,56 B", "STORNO", "-4 Stk x 0,39"]` genau 2 Positionen (Gouda, Laugenbrötchen) — keine dritte Phantom-Position mit Name `"-4 Stk x 0,39"`.
- **AC-2:** `pendingStornoCancel` bleibt nach einer direkt auf STORNO folgenden reinen Mengen-/Gewichts-Bestätigungszeile unverändert `true` (wird nicht verbraucht), damit die Storno-Erkennung beim nächsten passenden Namens-/Preis-Zeilenpaar weiterhin greift.
- **AC-3:** Das bestehende Verhalten der Mengen-/Gewichts-Bestätigungszeile OHNE vorausgehendes STORNO (inkl. Rechenprobe Menge × Rate ≈ Zeilenpreis) bleibt unverändert — bestehender Regressionstest bleibt grün.

## Manuelle Test-Schritte
entfällt — Fast Track, kein manuelles Testen (siehe CLAUDE.md/global rules).

## Inline-Test (wird während Implementierung geschrieben)
- [ ] `ReceiptParserServiceTests`: `parse(["GOUDA JUNG 1,65 B", "LAUGENBROETCHEN 1,56 B", "STORNO", "-4 Stk x 0,39"])`
      liefert weiterhin 2 Positionen (Gouda, Laugenbrötchen), keine dritte Phantom-Position
      mit Name `"-4 Stk x 0,39"`.
- [ ] Regressionstest: bestehender Test für Mengen-/Gewichts-Bestätigungszeile ohne STORNO
      bleibt grün (Rechenprobe-Übernahme in `results.last`).
