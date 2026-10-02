# Adversary-Dialog fix-11-falsch-gelernte-preise

Spec: docs/specs/models/legacy-price-reset-migration.md
Basis: base_commit 33d80390c07083691362fb666cbe9baa2c44ef63
Geänderte Code-Dateien: SmartCart/Models/LegacyLearnedPriceReset.swift, SmartCart/Models/ShoppingItem.swift, SmartCart/SmartCartApp.swift

## Checkliste

- [x] AC-1: Altwert-Artikel ohne Einheit werden auf die Schätzung zurückgesetzt, isAutoDerived = true (Runde 1)
- [x] AC-2: Manueller Preis mit Abweichung > 0,005 bleibt (Runde 1)
- [x] AC-3: Artikel mit nicht leerem learnedPriceUnits-Eintrag bleibt (Runde 1)
- [x] AC-4: Auto-abgeleitete und preislose Artikel bleiben (Runde 1)
- [x] AC-5: Namens-Schlüssel nutzt dieselbe Funktion wie ShoppingItem.init (Runde 1)
- [x] AC-6: Abgehakte und offene Artikel gleich behandelt (Runde 1)
- [x] AC-7: Artikel ohne Store unverändert, kein Absturz (Runde 1)
- [x] AC-8: Flag legacyLearnedPriceResetV1Applied, zweiter Lauf ändert nichts (Runde 1)
- [x] AC-9: Toleranzgrenze 0,004 true / 0,006 false (Runde 1)
- [x] AC-10: learnedPrices, learnedPriceUnits, learnedPriceDates unberührt (Runde 1)
- [x] AC-11: Aufruf direkt nach PriceProvenanceMigration.runIfNeeded (Runde 1, in Runde 3 am Diff bestätigt)
- [x] AC-12: UI-Durchlauf zeigt kein „1,56“, Kontrollartikel zeigt „2,50“ (Runde 3, F002 geschlossen)
- [x] AC-13: Aufräum-Argument und Bestandssuite im gemeinsamen Lauf grün (Runde 3, F001 geschlossen)
- [x] AC-14: ShoppingItem.init verhaltensgleich (Runde 1)

### Runde 1

Produktivcode ohne Defekt gefunden. 31 Unit-Tests (LegacyLearnedPriceResetTests 11, ShoppingItemFuzzyPriceMatchTests 13, PriceProvenanceMigrationTests 7) vom Prüfer selbst ausgeführt: 0 Failures, TEST SUCCEEDED.

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4
  Code reference: SmartCart/Models/LegacyLearnedPriceReset.swift:18
  Evidence: shouldReset bildet die Tabellenzeilen 1–7 in derselben Reihenfolge ab; Toleranz inklusiv. Manuelle, auto-abgeleitete, preislose und Raten-Artikel bleiben. Unit-Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-14
  Code reference: SmartCart/Models/ShoppingItem.swift:186
  Evidence: git diff Zeile für Zeile gelesen; matchingLearnedPriceKey ist wortgleich zum entfernten Closure-Inhalt, init ruft sie mit demselben Namen auf. 13 Fuzzy- und 7 Provenance-Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-7, AC-8, AC-9, AC-10
  Code reference: SmartCart/Models/LegacyLearnedPriceReset.swift:30
  Evidence: Geschrieben werden nur estimatedPrice und estimatedPriceIsAutoDerived. Flag-Guard vorn, Flag-Set nur nach erfolgreichem Fetch. Kein Force-Unwrap bei store == nil. learned*-Maps werden nie geschrieben.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/SmartCartApp.swift:568
  Evidence: Zeile 567 PriceProvenanceMigration.runIfNeeded, Zeile 568 LegacyLearnedPriceReset.runIfNeeded im selben .task.
  Status: CONFIRMED

### Runde 2

Nachbohren an AC-12, AC-13 und der Seed-Isolation. Seed und Aufräum-Argument liegen nur unter #if DEBUG.

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: SmartCart/SmartCartApp.swift:568
  Description: Kein voller gemeinsamer Lauf, nur Teilläufe.
  Spec requirement: AC-13 — Bestandssuite bleibt im gemeinsamen Lauf grün
  Conflict: Ohne gemeinsamen Lauf ist nicht belegt, dass Seed und Aufräumen die Nachbartests nicht stören.
  Remediation: Vollen Lauf ohne -only-testing fahren und archivieren. Status: in Runde 3 geschlossen.

Finding:
  ID: F002
  Severity: HIGH
  Category: spec_violation
  Code reference: SmartCart/SmartCartApp.swift:568
  Description: Die Gegenprobe zu AC-12 war nur behauptet, nicht archiviert.
  Spec requirement: AC-12 — nach App-Start zeigt kein Altlast-Artikel „1,56“
  Conflict: Ein Test, der nie rot gesehen wurde, beweist die Wirkung der Migration nicht.
  Remediation: Migrationsaufruf vorübergehend deaktivieren, Test laufen lassen, Log und Screenshot archivieren. Status: in Runde 3 geschlossen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: SmartCart/SmartCartApp.swift:299
  Description: Die Spec sprach beim Seed von „vier Artikeln“, der Seed legt drei an.
  Spec requirement: Implementation Details, Seed
  Conflict: Spec und Seed widersprachen sich in der Anzahl.
  Remediation: Spec auf „drei Artikel“ korrigieren. Status: in Runde 3 geschlossen.

### Runde 3

Alle Belege vom Prüfer selbst nachgesehen.

Confirmation:
  AC: AC-12
  Code reference: SmartCart/SmartCartApp.swift:568
  Evidence: Gegenprobe (test-gegenprobe-output.txt, Aufruf auskommentiert): UI-Test rot an LegacyLearnedPriceResetUITests.swift:42 („kein Altlast-Artikel darf 1,56 zeigen“), Zeilen 33 und 38 bestanden; TEST FAILED. Screenshot gegenprobe-altzustand-1-56.png zeigt im Altzustand „Laugenbrötchen groß 1,56 €“, erledigt „Laugenbrötchen 1,56 €“, „Kontrollbrot 2,50 €“, Summe 4,06 €. Mit aktivem Aufruf passed (Gesamtlauf 12,6 s). Aufruf ist wiederhergestellt, kein GEGENPROBE-Rest im Code.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/SmartCartApp.swift:568
  Evidence: Ein gemeinsamer Lauf ohne -only-testing (test-full-suite-output.txt): 353 Unit-Tests 0 Failures, 38 UI-Tests (1 selbst übersprungen, ReceiptShareExtensionTests, nicht änderungsbezogen) 0 Failures, keine Wiederholungen, TEST SUCCEEDED. Aufräum-Argument löscht Läden, Artikel und Flag; Nachbartests laufen danach grün. Einschränkung: ein einzelner Gesamtlauf beweist keine Stabilität über viele Läufe.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Models/ShoppingItem.swift:186
  Evidence: Im Gesamtlauf alle 353 Unit-Tests grün, darunter testMatchingKeyMatchesInitBehavior, die Tests zu gelernten Preisen und PriceProvenanceMigrationTests.
  Status: CONFIRMED

F003 geschlossen: Spec Zeile 132 lautet „drei Artikel“; übrige „vier“-Treffer betreffen die pbxproj-Registrierung.

Restrisiko (nicht änderungsbezogen): Kaltstart-Flakes der UI-Suite (Issues #21, #82), Hänger von xcodebuild nach dem Lauf.

### Runde 4

Prüfung auf dem Merge-Stand (Rebase auf origin/main 3bc0abf, #85/#86). Vom Prüfer selbst gelesen und ausgeführt.

Diff gegen origin/main, ShoppingItem.swift: nur die Extraktion matchingLearnedPriceKey, wortgleich zum früheren Closure. Der #85-Block (rememberedCategory) steht nach der Preiszuweisung und berührt Preislogik und learned*-Maps nicht. pbxproj: LegacyLearnedPriceReset.swift nur im App-Target, Tests in den Test-Targets, keine doppelten Definitionen.

Testläufe (Restock-Validate, nacheinander, ohne CODE_SIGNING_ALLOWED=NO): Unit, gesamtes RestockTests-Target: Executed 377 tests, 0 failures, TEST SUCCEEDED. UI: LegacyLearnedPriceResetUITests passed (12,9 s), TEST SUCCEEDED, kein Kaltstart-Timeout.

Confirmation:
  AC: AC-5, AC-14
  Code reference: SmartCart/Models/ShoppingItem.swift:186
  Evidence: Merge-Diff zeigt nur die verhaltensgleiche Extraktion; 377 Unit-Tests grün, inklusive Fuzzy-, Provenance- und Reset-Suiten.
  Status: CONFIRMED

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-6, AC-7, AC-8, AC-9, AC-10
  Code reference: SmartCart/Models/LegacyLearnedPriceReset.swift:18
  Evidence: Datei unverändert seit Runde 1; LegacyLearnedPriceResetTests im Merge-Stand grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/SmartCartApp.swift:568
  Evidence: Aufruf steht im Merge-Stand direkt nach PriceProvenanceMigration; Seed und Cleanup setzen und löschen das Flag.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/SmartCartApp.swift:568
  Evidence: UI-Durchlauf passed auf dem Merge-Stand mit umgebauter StoreDetailView: kein „1,56“, Kontrollartikel „2,50“. Die Gegenprobe aus Runde 3 bleibt gültig, Migration und Test sind unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/SmartCartApp.swift:303
  Evidence: Gesamte Unit-Suite im Merge-Stand 377 Tests, 0 Failures; Seed- und Cleanup-Pfad laufen. Einschränkung: die komplette UI-Suite wurde auf dem Merge-Stand nicht erneut gefahren, der letzte gemeinsame Lauf (38 UI-Tests grün) liegt vor dem Rebase; die CI deckt das vor der Auslieferung ab.
  Status: CONFIRMED

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/LegacyLearnedPriceReset.swift:43
  Description: Die Migration ruft PriceEstimator.estimate mit item.category auf. Bei Artikeln mit gemerkter eigener Kategorie (#85, in init nach der Preisschätzung gesetzt) und ohne Stichwort-Treffer kann das Ergebnis vom Konstruktionswert abweichen.
  Spec requirement: Zurücksetzen auf die Schätzung für die aktuelle Kategorie
  Conflict: Kein Widerspruch zur Spec, nur ein dokumentierter Unterschied zur Konstruktion.
  Remediation: Keine nötig. Status: akzeptiert.

Restrisiko (nicht änderungsbezogen): Kaltstart-Flakes der UI-Suite (Issues #21, #82).

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:9ab6f36dcf0414262122f9abc171f21b68bd336e2f592e2d0a272afeff9f5288  SmartCart/Models/LegacyLearnedPriceReset.swift
- sha256:bd393dcda7de96d43ba532cd6bb0d92627544f3149418b34a4ff33d1ac8d89fe  SmartCart/Models/ShoppingItem.swift
- sha256:2ac988ccb11e6f665d0e41c2ee0d60fccca2b8034d8be9a61b1e145f56b17ab1  SmartCart/SmartCartApp.swift
