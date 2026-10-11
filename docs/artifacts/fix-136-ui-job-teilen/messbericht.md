# Messbericht #136: UI-Suite in zwei Hälften

Stand 2026-10-11. Quelle: `gh run view <id> --json jobs` und Logs der Läufe. Grenze: `timeout-minutes: 60` je Hälfte, Ziel < 45 min.

| Lauf | Auslöser | ui-test (A) | ui-test (B) | Job `test` |
|---|---|---|---|---|
| 38155829579 | Pull Request | 27,0 min (Boot 2,0 · Rechte 2,1 · Bau+Test 22,4) | 25,2 min (Boot 1,8 · Rechte 1,1 · Bau+Test 21,4) | 8,0 min |
| 38157803310 | Push auf main | 24,6 min (Boot 1,2 · Bau+Test 22,7) | 31,9 min (Boot 2,6 · Rechte 0,8 · Bau+Test 27,9) | 8,6 min |
| 38166136000 | manuell auf main | 24,5 min (Boot 1,7 · Bau+Test 20,9) | 32,4 min (Boot 2,3 · Rechte 0,9 · Bau+Test 28,4) | 13,0 min |

Größte Hälfte: 32,4 min, also 27,6 min Abstand zum Limit (Ziel: mindestens 15 min). Zuvor am Stück: 40–55 min, einmal Abbruch bei 60.

**Testzählung (AC-2):** A 38 Tests, B 46 Tests (1 übersprungen), Summe 84, in allen drei Läufen 0 Fehler. Lauf 2 und 3 im Log belegt; Lauf 1 aus der Übergabe (38 / 46), im Log nicht erneut geprüft.

**Leerer erster Start (`UITestLaunch: zweiter Start nötig …`):** in den Logs von Lauf 2 und 3 je 0 Treffer (Lauf 1 nicht erneut geprüft).

## AC-4: Lauf unter Last — offene Grenze

Nicht durchgeführt. Auf dem gehosteten Runner lässt sich Last nur über eine Änderung an `ci.yml` (Hintergrundprozesse) erzeugen; das wäre ein eigener Eingriff in die CI und würde nicht den Normalbetrieb messen. Belegt ist nur: unter Normallast bleiben beide Hälften unter 45 min und der leere Start tritt nicht auf. Ob das unter hoher Last (wie lokal bei #105) so bleibt, ist unbelegt.

## Offene Grenzen

- Runner-Schwankung bleibt. Drei Läufe belegen den Abstand für diese Läufe, nicht „garantiert“ für künftige. B schwankt zwischen 25 und 32 min.
- `testChangeStoreMovesItemAndRemembersCorrection` gehört zu #118.
- Mehrverbrauch an Runner-Minuten: zwei Jobs statt einem, Bau und Simulator-Start doppelt (Summe A+B ≈ 57 min statt ≈ 40–55 min Einzeljob).
- Alternative (b), drei Jobs: nicht nötig, keine Hälfte über 45 min.
