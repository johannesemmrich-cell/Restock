# Context: fix-194-inmemory-container-cloudkit

## Request Summary
Issue #194: Auf iOS 27.0 reißt `NotificationDigestChainTests` den Test-Host achtmal ab (24 Absturzberichte am
2026-10-21, drei Läufe), weil der In-Memory-Testspeicher ohne `cloudKitDatabase: .none` angelegt wird und iOS 27
den Speicher nach dem gescheiterten CloudKit-Aufbau entfernt („No eligible connection available"). Fünf Testdateien
haben diesen Aufbau; zwölf weitere schalten die Spiegelung bereits ab. PO-Entscheidung 2026-10-21: alle fünf plus
Strukturtest, voller Prozess mit kurzer Tiefe; #99 wartet darauf.

## Related Files
| File | Relevance |
|------|-----------|
| `RestockTests/NotificationDigestChainTests.swift:203` | abstürzende Klasse, `ModelConfiguration(isStoredInMemoryOnly: true)` ohne CloudKit-Abschaltung; Absturz in Zeile 208 (`save()`) |
| `RestockTests/ReceiptAIResolutionChainTests.swift:56` | gleicher Aufbau (async-Tests, `@MainActor`), noch nicht abgestürzt |
| `RestockTests/ReceiptKnownItemNamesTests.swift:11` | gleicher Aufbau |
| `RestockTests/ReceiptParserSuggestionTests.swift:14` | gleicher Aufbau |
| `RestockTests/ReceiptResolutionStatsTests.swift:33` | gleicher Aufbau |
| 12 weitere Testdateien (z. B. `PriceSourceTests.swift:107`, `AddItemIntentTests.swift:19`) | Vorbild: `ModelConfiguration(… isStoredInMemoryOnly: true, cloudKitDatabase: .none)` |
| `SmartCart/SmartCartApp.swift:123` | Produktcode nutzt In-Memory nur mit `groupContainer: .none, cloudKitDatabase: .none`; bleibt unverändert |
| `scripts/test_ci_release_build.py`, `scripts/test_ci_ui_retry.py` | Muster für Strukturtests (unittest, Repo-Dateien lesen) |
| `docs/artifacts/feat-99-release-build-iphone-only/test-green-output-full.log` (Zweig #99) | Beleg: CloudKit-Fehler 134400 → „store was removed" → Ausnahme |

## Existing Patterns
- Zwölf Testdateien setzen bereits `cloudKitDatabase: .none`; das ist die etablierte Form im Projekt.
- Strukturtests unter `scripts/test_*.py` lesen die Repo-Dateien und machen Abweichungen rot.
- Nachweise unter `docs/artifacts/<workflow>/`, RED vor GREEN, Lauf im Simulator `Restock-Validate-27`
  (iPhone 17, iOS 27.0, UDID 9034BD4F-2D5F-49D5-B906-838326D51C95); Sperren über die Hauptsitzung.

## Dependencies
- Upstream: SwiftData `ModelConfiguration` (Parameter `cloudKitDatabase`, seit iOS 17), Test-Host `Restock.app` mit
  iCloud-Berechtigung, Simulator ohne iCloud-Konto.
- Downstream: #99 (AC-9 „bestehende Unit-Tests grün" auf iOS 27), jede künftige lokale Suite auf iOS 27; CI (iOS 26)
  unverändert grün.

## Existing Specs
- `docs/specs/ci/release-build-und-iphone-only.md` (#99) — wartet auf diesen Fix.
- keine Spec zu Test-Containern.

## Risks & Considerations
- Nur Testcode; kein Verhalten der App ändert sich. Risiko: minimal.
- `.none` statt `.automatic` ändert nichts am Testinhalt: keiner der fünf Tests prüft CloudKit.
- #195 (OCR 15/18 auf iOS 27) bleibt in der Suite rot; das ist ein anderes Ticket und wird in jeder Zusage genannt.
- Hänger nach Testende (Diagnose-Sammlung bis 10 min, #21) ist bekannt und kein Fehler dieses Fixes.

## Analysis

### Type
Bugfix (Testinfrastruktur). Reproduziert: 24 Absturzberichte `Restock-2026-10-21-*.ips`, alle Zeile 208; Gegenprobe
auf unverändertem Stand identisch (Entwickler-Agent #99, `test-baseline-head-failing-classes.log`).

### Root Cause
`ModelConfiguration(isStoredInMemoryOnly: true)` lässt `cloudKitDatabase` auf `.automatic`. Der Test-Host trägt die
iCloud-Berechtigung, SwiftData hängt die Spiegelung an den In-Memory-Speicher, der Aufbau scheitert ohne Konto
(`NSCocoaErrorDomain 134400`), iOS 27 entfernt den Speicher (`The store was removed before the mirroring delegate
could recover`), `save()` wirft `NSInternalInconsistencyException: No eligible connection available`. Auf iOS 26
blieb der Speicher trotz Fehler bestehen. Fremdbelege: Wockett PR 118, FRUS-Explorer #1325, fitness-app #253.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `RestockTests/NotificationDigestChainTests.swift` | MODIFY | `cloudKitDatabase: .none` ergänzen (1 Zeile) |
| `RestockTests/ReceiptAIResolutionChainTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptKnownItemNamesTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptParserSuggestionTests.swift` | MODIFY | dito |
| `RestockTests/ReceiptResolutionStatsTests.swift` | MODIFY | dito |
| `scripts/test_inmemory_containers_no_cloudkit.py` | CREATE | Strukturtest: jede Zeile mit `isStoredInMemoryOnly: true` unter `RestockTests/` enthält `cloudKitDatabase: .none` (auch mehrzeilige Aufrufe); ~35 Zeilen |

### Scope Assessment
- Files: 6 (5 MODIFY, 1 CREATE)
- Estimated LoC: +40/-5
- Risk Level: LOW

### Technical Approach
1. Strukturtest schreiben → RED (5 Treffer). Abstürzende Klasse isoliert auf iOS 27 laufen lassen → RED (Host-Absturz,
   Protokoll als Beleg).
2. Fünf Aufrufstellen um `cloudKitDatabase: .none` ergänzen (gleiche Form wie die zwölf Vorbilder).
3. GREEN: Strukturtest 0 Treffer; `NotificationDigestChainTests` 8/8 ohne Host-Neustart; gesamte Unit-Suite auf
   iOS 27 ohne Absturz (bekannt rot nur #195, Zahl der `Restarting after unexpected exit` = 0).
4. Durchlauf im Simulator: Test-Host-App startet (Startseite), weil die Suite den Host startet; zusätzlich ein
   Bildschirmfoto wie bei #99.

### Alternatives
- **Gemeinsame Hilfsfunktion** (`makeInMemoryContainer(schema:)`) und alle 17 Stellen darauf umstellen: einheitlich,
  aber 17 Dateien statt 5 und Umbau funktionierender Tests. Verworfen für diesen Durchgang; der Strukturtest schützt
  gleichwertig.
- **Nur die abstürzende Datei:** vom PO abgelehnt (2026-10-21).
- **iOS-26-Laufzeit nachladen:** umgeht das Problem nur lokal, CI-Wechsel auf Xcode 27 steht an.

### Dependencies
- Reihenfolge: Strukturtest RED → Klasse RED → Fix → GREEN → Suite → Adversary → Validate → PR → Merge → #99 rebasen.

### Open Questions
- [ ] keine
