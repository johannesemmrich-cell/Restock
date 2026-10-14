# RED-Nachweis Durchgang 8 (2026-10-14)

- Unit (`CheckoffQueueTests` Q1–Q6, `AddItemIntentTests` A1–A4): Build bricht ab, `cannot find 'CheckoffQueue' in scope` und
  `AddShoppingItemIntent` hat kein `add(name:quantity:unit:in:)` — beide Typen/Funktionen gibt es noch nicht (RED durch Übersetzungsfehler,
  Ausgabe `test-red-output-unit.txt`).
- UI (`QuickAddControlUITests`): derselbe Übersetzungsfehler des Unit-Ziels blockiert den Lauf (`test-red-output-ui.txt`), weil das Schema
  alle Testziele baut. Der fachliche Rot-Nachweis (Argument `-pendingQuickAddForUITests` unbekannt, kein Fokus) wird in Phase 6 geführt:
  erst `CheckoffQueue`/`add` einführen (reines Verschieben), UI-Test laufen lassen (muss rot sein), dann das DEBUG-Argument.
