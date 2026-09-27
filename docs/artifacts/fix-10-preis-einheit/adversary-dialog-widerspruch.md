# Widerspruch zu einem Befund des Prüfdialogs

Der Prüfdialog (`adversary-dialog.md`, Urteil **BROKEN**) enthält einen Befund, der sachlich falsch
ist. Das Protokoll selbst wird **nicht** nachträglich geändert — ein Prüfurteil umzuschreiben, weil
es unbequem ist, wäre genau die Manipulation, gegen die der Dialog existiert. Der Widerspruch steht
daher hier daneben.

## Der bestrittene Befund

Der Prüfer erklärt `test-green-final.txt` für ungültig:

> **test-green-final.txt (die bisherige "AC-20 erfüllt"-Evidenz) ist ungültig.** Ich habe die
> Suite-für-Suite-Testzahlen gegen diagnose-nach-merge.txt verglichen: `ReplenishmentPackageCTests`
> lief dort mit nur 17 statt 25 Tests — das File hat aktuell nachweislich 25 Testmethoden,
> **unverändert seit lange vor #10**. Der als "grün" gefeierte Lauf hat also 8 von 256
> Testmethoden nie ausgeführt und trotzdem "0 failures" gemeldet.

## Warum das nicht stimmt

Die Annahme „unverändert seit lange vor #10" ist widerlegbar. Commit `d6f8659` (Issue #58,
„Nachkauf – Vielleicht auch fällig in der Ladenliste", 2026-09-26 16:33) hat die Datei um
110 Zeilen und **acht Testmethoden** erweitert:

```
$ git show d6f8659 --stat -- RestockTests/ReplenishmentPackageCTests.swift
 RestockTests/ReplenishmentPackageCTests.swift | 110 ++++++++++++++++++++++++++
 1 file changed, 110 insertions(+)

$ grep -c "    func test" RestockTests/ReplenishmentPackageCTests.swift
25
$ git show d6f8659^:RestockTests/ReplenishmentPackageCTests.swift | grep -c "    func test"
17
```

17 vor #58, 25 danach. `test-green-final.txt` entstand **vor** dem Aufsetzen auf `origin/main` —
zu diesem Zeitpunkt existierten die acht Tests noch nicht. Die Testzahlen gehen damit exakt auf:

| Lauf | Stand | RestockTests |
|---|---|---|
| `test-green-final.txt` | vor dem Aufsetzen auf `main` | 248 |
| `diagnose-nach-merge.txt` | nach dem Aufsetzen (enthält #58) | 256 |

248 + 8 = 256. Kein übersprungener Test, kein stiller Ausfall. Der Lauf hat alles ausgeführt, was
zu seinem Zeitpunkt existierte.

## Was davon unberührt bleibt

Der Widerspruch betrifft **nur** diesen einen Punkt. Das Urteil **BROKEN** bleibt richtig, und zwar
aus dem anderen, tragenden Grund: **Kein gemeinsamer Lauf war grün** — weder die des Orchestrators
nach dem Aufsetzen auf `main` (zweimal Runner-Hänger, #21) noch der eigene des Prüfers (zwei
Fehlschläge). Nach dem Wortlaut von AC-20 ist das nicht erfüllt. Diese Feststellung wird
ausdrücklich geteilt, nicht bestritten.

Ebenso bleiben gültig:

- **F001** (AC-1-Testlücke, MEDIUM) — trifft zu, deckt sich mit der eigenen Einschätzung des
  Orchestrators vor dem Dialog, erfasst als Issue **#59**.
- **F002** (MenuPlan-Test bricht den gemeinsamen Lauf, HIGH) — trifft zu, #10-fremd, erfasst als
  Issue **#60** mit belegter Ursache (`MenuPlanView.swift:336`).
- **F003** (Dark-Mode-Test zusätzlich instabil, LOW) — trifft zu und war neu. Eigenständig
  nachgeprüft: `testChangeEditorWorksInDarkMode` (`ReceiptReviewUITests.swift:750`) stammt aus den
  Commits zu #38 und #34; der einzige Eingriff von #10 in diese Datei (`2f6ec0a`) fügt 44 Zeilen für
  den neuen Test an und berührt die Zeilen um 750 nicht. Damit #10-fremd. An Issue **#32**
  kommentiert.

## Lehre

Der Prüfer hat aus zwei unterschiedlichen Testzahlen auf einen verschwiegenen Ausfall geschlossen,
ohne die Dateihistorie zu prüfen. Umgekehrt hatte der Orchestrator zuvor dreimal Befunde desselben
Prüfwegs bestätigt bekommen, die zutrafen. Beides gehört zusammen: Ein Prüfurteil ist zu belegen,
nicht zu glauben — in beide Richtungen.
