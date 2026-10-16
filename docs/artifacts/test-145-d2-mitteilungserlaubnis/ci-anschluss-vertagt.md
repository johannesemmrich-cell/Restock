# CI-Anschluss vertagt (AC-13, Rückfall)

Stand 2026-10-16. PO-Entscheidung: Der CI-Anschluss wird aus Durchgang 2 herausgenommen und ist ein Folgeschritt in #145.

## Gründe
- Im Ticket war der Anschluss nicht verlangt. Das PO-Briefing vom 2026-10-15 führt ihn als „Zusatz“.
- AC-13 verlangt einen grünen Push-Lauf als Beleg. Das Commit-Gate lässt aber erst nach dem Prüfurteil festschreiben, und hochgeladen wird erst danach. Vor dem Push ist der Beleg deshalb nicht zu erbringen.
- Der Ausnahmeweg mit `override-ambiguous` und PO-Wort „ausnahme“ wurde vom Auto-Mode-Klassifizierer blockiert, am 2026-10-16 zweimal.

## Messung / Stand
- Lokal sind beide Wege grün, je auf einem Wegwerf-Simulator: `test-green-output.txt`.
- Der geplante Anschluss liegt unverändert als Entwurf vor: `ci-anschluss-vertagt.diff`.
  - Hälfte A setzt `allow` und wählt die Klasse zusätzlich.
  - Hälfte B setzt `deny`.
  - `HEAVY_CLASSES` bleibt unverändert.
- Ohne Anschluss setzt keine CI-Hälfte `RESTOCK_NOTIF_DECISION`. Beide Tests überspringen sich deshalb mit Grund (AC-3), die Suite bleibt grün.

## Folgeschritt (#145)
Den Entwurf einspielen und den Push-Lauf beider Hälften als Beleg führen. Damit wird auch der englische Dialog geprüft (AC-5 en).
