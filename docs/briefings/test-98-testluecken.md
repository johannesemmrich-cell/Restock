---
spec_file: docs/specs/ui-tests/shopping-route-learning-uitest.md
spec_sha256: 4aa1bc59096866f79176d29aed15ebd10def0f278786acd07472f037ffb12044
---

# PO-Briefing: test-98-testluecken

- **Spec:** docs/specs/ui-tests/shopping-route-learning-uitest.md
- **Issue:** #98 (Durchgang 1)
- **Erstellt:** 2026-10-03

## Was gebaut wird

Ein automatischer Test hakt Artikel in einer Ladenliste ab und prüft, dass die App daraus den Einkaufsweg lernt.

## Definition of Done

Der Test zeigt in drei Läufen hintereinander grün: langsam abgehakte Artikel ändern die Reihenfolge, schnell abgehakte nicht, und alle bisherigen Tests bleiben grün.

## Wie geprüft wird

Der Test tippt echte Haken und simuliert 31 Minuten Ruhe; nicht geprüft werden Abhaken im Bearbeiten-Dialog sowie über Widget oder Siri.

## Kritische Anmerkungen

- Von acht Lücken in Ticket #98 wird nur Punkt 1 geschlossen, und auch dieser nur teilweise; Rest folgt später.
- Die 2,1-Sekunden-Wartezeit zwischen Haken ist ungemessene Vermutung; der Test kann auf dem Prüfrechner wackeln.
- Wie der Test die gelernte Reihenfolge abliest, ist noch offen; zusätzlich kommt eine Testhilfe in die App (nur Entwicklerversion).

## Freigabe-Frage

Ist es für dich in Ordnung, Ticket #98 in Durchgängen abzuarbeiten und jetzt nur Abhaken plus Einkaufsweg-Lernen zu testen?
