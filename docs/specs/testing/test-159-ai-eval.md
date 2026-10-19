# Test #159: Bon-KI (Stufe 5) mit dem echten Modell messen

**Ziel:** Wiederholbare Messung von `ReceiptNameAIResolver` mit Apples On-Device-Modell, ohne iPhone, auf einem Mac mit Apple Intelligence. Erste Frage: Hätte die Prompt-Änderung aus #157 allein den „Bröt.“-Fehler verhindert?

## Aufbau

- `RestockTests/ReceiptNameAIEvaluationTests.swift`, ganz in `#if AI_EVAL` (in CI, Xcode und auf Restock-Validate leer). Nur `scripts/run-ai-eval.sh` setzt die Bedingung.
- Datensatz: dm-Bon vom 05.10.2026 (16 Zeilen), Lidl-Bon (`ReceiptParserLidlFullReceiptTests.lidlLines`, durch den echten Parser), Rewe-eBon (`ReceiptParserReweTests.reweLines`, jetzt `internal`), 7 Verwaltungszeilen mit Erwartung „kein Produkt“. Je Zeile mehrere akzeptierte Antworten (gefaltet, Teilwort in beide Richtungen).
- Namenslisten: `sauber` und `vergiftet` (mit „Bröt.“ vorn, wie am 18.10.2026 vermutet).
- Varianten: `heutiger Prompt + Prüfungen` (echter Code: `ReceiptNameAIResolver.prompt`, `sanitize`, `discardingRepeatedUnrelatedAnswers`, Kürzel-Filter der Namensliste) und `alter Prompt (vor #157), alte Prüfung` (Prompt-Text und Nachbearbeitung von vor #157, im Test festgehalten).
- Modellaufruf über die Produkt-Naht `SystemReceiptNameLanguageModel` (seit #159 mit `GenerationOptions(sampling: .greedy)`, damit Läufe vergleichbar sind), 25 s Frist je Aufruf über `withRealTimeout`.
- Metriken je Variante × Liste: Treffer, Kürzel-Antworten, durch die Wiederholungs-Regel verworfen, KEIN_PRODUKT-Fehlalarme, Timeouts, Ø Sekunden; dazu alle Einzelzeilen. Bericht zwischen `AI-EVAL-REPORT-BEGIN/END` im Protokoll, das Skript hebt ihn nach `docs/artifacts/test-159-ai-eval/bericht-<zeit>.md`.
- Tests: `testProbeModelReallyGenerates` (Vorprobe: „verfügbar“ reicht nicht, ein echter Aufruf muss antworten — auf GitHub-Runnern meldet der Simulator verfügbar und generiert nicht), `testMeasureAllVariants` (Messung, rot nur bei Timeouts), `testCurrentPromptNeverRepeatsBroet` (hartes Urteil: heutige Kette mit vergifteter Liste liefert kein „Bröt.“).

## Lauf (lokal, nur auf dem Mac)

```
scripts/run-ai-eval.sh            # iOS 27.0, iPhone 17 Pro, Wegwerf-Simulator
scripts/run-ai-eval.sh 26.5       # andere Runtime
```
Sperren `/tmp/heavy-build.lock` und `/tmp/loose-ends-testlauf.lock` wie bei den anderen Skripten; Restock-Validate bleibt unberührt. Grün nur bei genau 3 Tests, 0 Fehlschlägen, 0 Übersprungenen und vorhandenem Bericht.

## Voraussetzungen und bekannte Grenzen

- Mac mit Apple Silicon, macOS 26+, Apple Intelligence in den Systemeinstellungen eingeschaltet (Apple DTS, Forum 815397). Ob der iPhone-Simulator auf dem jeweiligen Mac generiert, ist nicht sicher (Berichte: M4 mit 26.2–26.4 scheitert, M1 läuft); die Vorprobe entscheidet. Scheitert sie, bleibt als Ausweg ein macOS-Ziel (nicht gebaut).
- Nicht kompiliert: In dieser Umgebung gibt es kein Xcode; der erste Lauf auf dem Mac kann Kompilierfehler in der Testdatei zeigen. Die Skriptausgabe nennt sie.
- Gleiche Antwort für fremde Zeilen wird in `testCurrentPromptNeverRepeatsBroet` nur gemeldet, nicht bewertet (zwei Tuchmasken dürfen gleich heißen).
- Apples Evaluations-Framework (Xcode 27, `@Test(.evaluates(…))`, Xcode-Bericht, Model-Judge) ist bewusst nicht benutzt: API hier nicht prüfbar, Nutzen für die erste Frage gering. Ausbaustufe, falls die Messung regelmäßig laufen soll.
- Mac- und iPhone-Modell: gleiche Architektur, identische Gewichte nicht belegt; Gegenprobe am Gerät vor Release bleibt.

## Ergebnis

Noch kein Lauf. Bericht erscheint unter `docs/artifacts/test-159-ai-eval/`.
