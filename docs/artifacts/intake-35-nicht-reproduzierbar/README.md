# Intake #35 — Bon-Prüf-Screen nach Neuinstallation: nicht reproduzierbar (2026-10-20)

Ergebnis: In sechs Kaltstarts unter CPU-Last erschien das Bon-Prüf-Sheet jedes Mal, die Nutzlast war danach
jedes Mal verbraucht. In 51 roten CI-Läufen seit 2026-09-21 kommt der Fehlertext nicht vor. #35 ist auf
PO-Entscheidung geschlossen (nicht nachstellbar). Details im Ticket-Kommentar vom 2026-10-20.

Aufbau: Stand `main` `ae41d4a`, Xcode 27.1, Wegwerf-Simulator iPhone 17 / iOS 27.0, vor jedem Lauf `simctl erase`,
Last = 10 Rechenschleifen (`perl -e 'alarm N; 1 while 1'`) auf 10 Kernen.

| Datei | Inhalt |
|---|---|
| `repro-35-summary.txt` | Läufe 1–4 ohne Codeänderung: Ergebnis, Vorbedingungsfehler, Nutzlast im App-Gruppen-Speicher |
| `repro-35-run3-zeitachse.txt` | Lauf 3: Start unter Last brauchte 536 s, Sheet erschien, `tearDown`-Hänger „Failed to terminate" (→ #133 Teil 2) |
| `repro-35b-summary.txt`, `repro-35b-run2/3.diag.log` | Läufe 5–6 mit Diagnose-Kopie: `DIAG35`-Zeilen zeigen `activeStores=1` schon beim `onAppear`-Aufruf |
| `ci-logs-35-result.txt` | 51 rote CI-Läufe (xcpretty-Ausgabe, enthält Assertion-Texte): 0 Treffer „Sheet ist nicht erschienen" |
| `repro-35.sh`, `repro-35b.sh` | Lauf-Skripte (Pfade zeigen auf das Sitzungs-Scratchpad) |
| `patch_diag35.py` | Setzt die Diagnosezeilen in eine Wegwerf-Kopie von `HomeView.swift`; nie fürs Repo |
| `ci_logs_35.py` | Durchsucht `gh run view --log` der roten CI-Läufe |

Lauf 1 der Diagnose-Serie brach mit rc=64 ab (vorhandenes `-resultBundlePath` aus einem gestoppten Vorlauf) und zählt nicht.
