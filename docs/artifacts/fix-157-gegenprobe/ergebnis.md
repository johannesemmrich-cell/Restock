# Gegenprobe #157: Sind die neuen Tests ohne die Schutzregeln rot?

**Anlass:** Die Tests aus #157 wurden mit dem Produktcode im selben Commit gepusht; ein roter Lauf gegen den alten Code war nie belegt (kein Xcode in der Arbeitsumgebung). Henning fragte am 19.10.2026 nach Vorher/Nachher-Tests.

**Aufbau:** Branch `claude/gegenprobe-157-rot` (PR #170, nie gemergt, geschlossen): `main` (39910eb) mit den Tests unverändert, aber jede Schutzregel auf das Altverhalten zurückgedreht — alter Prompt-Hinweis („bevorzuge eine Übereinstimmung/Ähnlichkeit“), `sanitize` ohne Kürzel-Prüfung, `discardingRepeatedUnrelatedAnswers` ohne Wirkung, `knownItemNames` ohne Kürzel-Filter, `ReceiptAliasService.isLearnableTarget` immer `true`, `ReceiptLearning.aliasLearnableIndices` sperrt nichts, `AbbreviatedNameCleanup.runIfNeeded` ohne Wirkung. Die Naht (`ReceiptNameLanguageModel`, `resolve(aiResolver:)`) blieb, damit alles kompiliert. Lauf: CI-Job `test`, Commit 0ec5729, 2026-10-19 06:38 UTC.

**Ergebnis:** 572 Tests, 66 Fehlschläge, verteilt auf genau diese 10 Tests:

| Test | Regel, die fehlt |
|---|---|
| `ReceiptAIResolutionChainTests.testSameAbbreviationForEveryLineNeverReachesReview` (K1) | Kürzel-Prüfung + Wiederholungs-Regel: „Bröt.“ kam auf allen Zeilen an |
| `ReceiptAIResolutionChainTests.testModelCopyingFirstKnownNameIsCaught` (K2) | Kürzel-Filter im Prompt („Kürzel darf nicht in den Prompt“), Wiederholungs-Regel |
| `ReceiptNameAIResolverSanitizeTests.testAbbreviationAnswerIsRejected` | `sanitize` ließ „Bröt.“/„Schokol.“ durch |
| `ReceiptNameAIResolverSanitizeTests.testSameUnrelatedAnswerForManyLinesIsDiscarded` | Wiederholungs-Regel |
| `ReceiptNameAIResolverSanitizeTests.testRepeatedAnswerIsKeptWhereRawTextSharesAWord` | Wiederholungs-Regel (Wortbezug) |
| `ReceiptKnownItemNamesTests.testExcludesAbbreviatedNames` | Kürzel-Filter der eigenen Namen |
| `AbbreviatedNameCleanupTests.testAbbreviationIsNotALearnableAliasTarget` | Alias-Sperre auf Kürzel-Ziel |
| `AbbreviatedNameCleanupTests.testSameNameOnUnrelatedLinesBlocksAliasLearning` | Alias-Sperre bei ≥ 3 fremden Zeilen |
| `AbbreviatedNameCleanupTests.testRemovesLearnedPricesUnderAbbreviatedKeysOnly` | Aufräumung gelernter Preise |
| `AbbreviatedNameCleanupTests.testRemovesBugPatternRecords` | Aufräumung der Kaufdatensätze |

Grün geblieben, wie erwartet: K3–K7 (reine Naht: Antworten übernehmen, bereinigen, Rohtext-Rückfall, nicht verfügbar/abgeschaltet, Lidl-Zeilenauswahl) und die „bleibt unverändert“-Gegenproben (`testRunsOnlyOnce`, `testKeepsRecordsOutsideThePattern`, `testBugPatternDecisionGroupsByNameStoreAndDay`, `testRelatedOrRareRepeatsStayLearnable`, `testAnswerRepeatedForTwoLinesIsUntouched`, `testIdenticalRawLinesCountOnce`), die ohne Regel trivial wahr sind.

**Schluss:** Jede der sieben Schutzregeln aus #157 hat mindestens einen Test, der ohne sie rot wird. Der grüne Lauf auf `main` (39910eb, 541 Tests) ist damit ein echtes Nachher. Auszug des CI-Protokolls: `ci-unit-job-auszug.txt`.

**Grenze:** Die Gegenprobe prüft die Regeln gegen Schein-Antworten, nicht gegen Apples Modell (#159).
