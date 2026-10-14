# Context: test-98-durchgang-7-tagesmitteilung

## Request Summary
#98 Punkt 5: Die gebündelte Tagesmitteilung (`NotificationService`) und der Hintergrundlauf
(`ReplenishmentBackgroundRefresh.run`) laufen in keinem Test. Die Planungsregel selbst ist
unit-getestet, die Kette bis zur Mitteilungszentrale nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Services/NotificationService.swift` | `scheduleReplenishmentDigests` (nacheinander, ersetzt alte `replenish-*`, `center.add`, `log.replace`), `cancelAll`, `isAuthorized`, `requestPermission` |
| `SmartCart/Services/ReplenishmentDigest.swift` | `ReplenishmentDigestPlanner` (getestet), `ReplenishmentDigestLog` (`commitDelivered` → Ledger), `ReplenishmentBackgroundRefresh` (`isEnabled`, `schedule`, `earliestBeginDate` getestet, `run(container:now:)` ungetestet) |
| `SmartCart/Services/HabitService.swift` | `notificationCandidates`, `scheduleReplenishmentNotifications` (Task-Wrapper), `OverdueNotificationLedger` |
| `SmartCart/Views/Home/HomeView.swift` (~1665) | `refreshDueSoon()` ruft die Planung nur bei `notificationsEnabled` |
| `SmartCart/SmartCartApp.swift` (~759–765) | `.backgroundTask(.appRefresh(...))` ruft `run(container:)`; `schedule()` beim Verlassen der App |
| `SmartCart/Views/Settings/SettingsView.swift` (~410–425) | einzige Stelle, die die Mitteilungserlaubnis anfragt (Schalter, nur Developer Mode) |
| `RestockTests/ReplenishmentDigestTests.swift` | testet Planer, Ledger, Protokoll-Logik, `earliestBeginDate`; Vorlage für feste Daten/UserDefaults-Suite |

## Existing Patterns
- Unit-Tests laufen mit der App als Host (`TEST_HOST`/`BUNDLE_LOADER` gesetzt), `UNUserNotificationCenter.current()` stürzt daher nicht ab.
- Ledger, Protokoll, Snoozes, Sperrliste, Rückmeldungen liegen in `UserDefaults.standard`; die Klassen nehmen eine Suite entgegen, `run(container:)` und `NotificationService` aber nicht → Tests müssen die Schlüssel in `tearDown` selbst entfernen (Muster aus #98 Durchgang 4).
- `run(container:now:)` nimmt einen `ModelContainer`: In-Memory-Container möglich.

## Messung im Simulator (Wegwerf-Kopie, Restock-Validate, 2026-10-13)
Test in einer Kopie des Projekts, nicht im Repo: ein Kandidat → `scheduleReplenishmentDigests` → Zentrale lesen.
- Erlaubnis-Status im Testlauf: `notDetermined` (0). `simctl privacy` kennt den Dienst `notifications` nicht (Dienstliste: calendar, contacts, location, photos, media-library, …) – die Erlaubnis lässt sich nicht von außen setzen.
- `center.add` wirft **nicht**, aber `pendingNotificationRequests()` bleibt **leer**.
- `ReplenishmentDigestLog.planned().count == 1`: Das Protokoll hält die Mitteilung für geplant.
- Der Kommentar in `NotificationService` („Ohne Erlaubnis scheitert das“) stimmt damit nicht.

## Befund (Produkt, neben dem Testauftrag)
Fehlt die Erlaubnis, gilt der Artikel trotzdem als geplant. Nach der Zustellzeit trägt `commitDelivered` ihn ins Ledger ein, obwohl nie etwas verschickt wurde: Er wird in diesem Kaufzyklus nicht erneut gemeldet. Die Erlaubnis wird nur beim Einschalten des Schalters angefragt; der Standardwert von `notificationsEnabled` ist `true`, wer den Schalter nie bedient, wird nie gefragt. Betrifft nur den Developer Mode (Nachkauf kommt erst in 1.1, siehe Release-Umfang). Wie das behoben wird, ist eine Analysefrage, nicht Teil dieses Kontexts.

## Dependencies
- Upstream: `UNUserNotificationCenter`, `BGTaskScheduler`, SwiftData (`PurchaseRecord`, `ShoppingItem`, `Store`), `HabitService`, `ReplenishmentSnoozes/Blocklist/Feedback/KeyMigration`.
- Downstream: `HomeView.refreshDueSoon`, `SmartCartApp`, `SettingsView` (`cancelAll`).

## Existing Specs
- `docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md`, `…-5-…`, `…-6-…` – Aufbau und Form der Durchgänge.
- `docs/context/test-98-testluecken.md` – Gesamtübersicht #98 (Punkt 5 offen).

## Risks & Considerations
- Gemeinsame `UserDefaults.standard`: Tests dürfen keine Schlüssel zurücklassen (Ledger, `scheduledReplenishmentDigests`, Snoozes, Sperrliste, Rückmeldungen, `developerMode`, `notificationsEnabled`).
- Echte Auslieferung um 9:00 und der vom System gestartete Hintergrundlauf sind nicht automatisierbar (Recherche: nur per Debugger-Befehl, nur bei angemeldeter Aufgabe) → offene Grenze im Ticket.
- Mit erteilter Erlaubnis lässt sich der Weg nur über einen UI-Test mit Systemdialog (`UIInterruptionMonitor`) fahren; die App fragt nur im Einstellungsschalter an.
- `BGTaskScheduler.submit` scheitert im Simulator immer (Kommentar im Code) → `schedule()` prüfbar nur über `isEnabled`/Abmelden, nicht über eine tatsächlich angemeldete Anfrage.
- Auf Hennings Geräten läuft nichts.

## Analysis

### Type
Feature (Testarbeit, #98 Punkt 5) plus ein gefundener Produktfehler (Developer Mode).

### Recherche (vor der Analyse)
- `UNUserNotificationCenter.add` wirft ohne Erlaubnis nicht; bei `notDetermined` bleibt die Anfrage still liegen. Empfehlung in den Foren: vorher `notificationSettings()` prüfen. Deckt sich mit der Messung im Simulator (add wirft nicht, Zentrale leer, Protokoll hält 1 Mitteilung für geplant).
- Quellen: https://developer.apple.com/tutorials/data/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:).md · https://developer.apple.com/forums/thread/713515 · https://developer.apple.com/forums/thread/684226

### Ursache des Produktfehlers (belegt durch Messung)
`performDigestScheduling` wertet `try? await center.add(...) != nil` als „geplant". Ohne Erlaubnis gelingt `add` formal, also landet der Eintrag im `ReplenishmentDigestLog`; `commitDelivered` schreibt ihn nach 9:00 ins Ledger. Folge: Artikel gilt für den Kaufzyklus als gemeldet, ohne dass etwas verschickt wurde. Die Erlaubnis wird nur beim Einschalten des Schalters erfragt, der Standard `notificationsEnabled = true` umgeht das.

### Technischer Ansatz (Empfehlung, Regelweg, kein Modell nötig)
1. **Naht für die Mitteilungszentrale**: kleines Protokoll `DigestNotificationCenter` (`authorizationStatus()`, `pending()`, `remove(ids)`, `add(request)`), `UNUserNotificationCenter` als Standard, im Test ein Fake. Damit läuft die echte Kette `run(container:)` → Muster → Kandidaten → Planer → Zentrale → Protokoll → Ledger ohne Systemerlaubnis (die sich per `simctl` nicht setzen lässt).
2. **Unit-Tests** (`NotificationDigestChainTests`, In-Memory-`ModelContainer`, feste Zeit):
   - D1 Kette: Kaufhistorie in SwiftData → `run` → Fake enthält genau eine Sammelnachricht um 9:00 mit dem richtigen Artikel.
   - D2 Abgemeldet: `developerMode` aus bzw. `notificationsEnabled` aus → `run` plant nichts.
   - D3 Ersetzen: zweiter Lauf ersetzt `replenish-*`, fremde Kennungen bleiben.
   - D4 Ledger erst nach Zustellzeit: vor 9:00 kein Eintrag, danach Artikel nicht erneut gemeldet.
   - D5 Ohne Erlaubnis (Fehlerfall): nichts im Protokoll, Artikel bleibt meldbar.
   - D6 `cancelAll` leert Zentrale und Protokoll.
   Aufräumen: `tearDown` entfernt Ledger-, Protokoll-, Snooze-, Sperrlisten-, Rückmeldungs-Schlüssel sowie `developerMode`/`notificationsEnabled` (Muster Durchgang 4).
3. **Produktfix (nur wenn der PO zustimmt)**: in `performDigestScheduling` zuerst Status prüfen; bei nicht erteilter Erlaubnis nichts ins Protokoll. Der falsche Kommentar wird korrigiert. Kleinster Eingriff, ca. +10 Zeilen.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/NotificationService.swift` | MODIFY | Protokoll-Naht, Erlaubnisprüfung vor `add` (Fix), Kommentar korrigieren |
| `SmartCart/Services/ReplenishmentDigest.swift` | MODIFY | `run(container:now:center:)` reicht die Naht durch |
| `RestockTests/NotificationDigestChainTests.swift` | CREATE | D1–D6 mit Fake-Zentrale |
| `Restock.xcodeproj/project.pbxproj` | MODIFY | Testdatei registrieren |
| `CLAUDE.md` | MODIFY | Durchgang 7 festhalten |

### Scope Assessment
- Dateien: 5 (davon 1 Doku)
- Umfang: ca. +230 / −10 LoC (Produktcode ca. 40, Test ca. 190)
- Risiko: NIEDRIG–MITTEL (Produktcode berührt Planung der Mitteilungen, nur Developer Mode; Release 1.0 ohne Nachkauf)

### Alternativen
- **UI-Test mit Systemdialog** (`UIInterruptionMonitor`, Erlaubnis in den Einstellungen schalten): prüft das echte System, aber der Schalter ist nur im Developer Mode, die Zentrale ist aus dem UI-Test nicht lesbar, und die Zustellung um 9:00 bleibt unprüfbar. Als Ergänzung später möglich, nicht als Ersatz.
- **Nur `isAuthorized` testen, ohne Naht**: kein Produktcode, aber die Kette bis zur Zentrale bliebe offen (der Messbefund zeigt, dass genau dort der Fehler sitzt).
- **Erlaubnis beim ersten Start des Developer Mode erfragen** statt Prüfung vor `add`: ändert das Produktverhalten sichtbar (Systemdialog), PO-Thema. Gekippt würde nichts, aber die Entscheidung „Erlaubnis nur am Schalter" in #30 wird berührt.
- Gekippte Entscheidung bei der Empfehlung: keine.

### Offene Grenzen (ins Ticket)
Echte Zustellung um 9:00, vom System gestarteter Hintergrundlauf, `BGTaskScheduler.submit` im Simulator (scheitert immer), Systemdialog der Erlaubnis. Auf Hennings Geräten läuft nichts.

### Pflicht-Durchlauf
Vor Abschluss: App im Simulator starten, Developer Mode an, Nachkauf-Daten seeden, Zentrale lesen; Nachweis als registriertes Artefakt.

### Open Questions
- [x] Produktfehler (Artikel gilt ohne Erlaubnis als gemeldet) mitbehandeln? PO 2026-10-13: ja.
