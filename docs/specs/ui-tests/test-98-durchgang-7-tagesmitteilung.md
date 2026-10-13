---
entity_id: test-98-durchgang-7-tagesmitteilung
type: test
created: 2026-10-13
updated: 2026-10-13
status: draft
workflow: test-98-durchgang-7-tagesmitteilung
tags: [test, unit-test, notifications, digest, background-refresh, replenishment, produktfix]
---

# Test-Durchlauf: Gebündelte Tagesmitteilung und Hintergrundlauf (Issue #98, Durchgang 7)

## Approval

- [ ] Approved — PO (offen)

## Purpose

Punkt 5 aus #98. Die gebündelte Tagesmitteilung „Zeit zum Nachkaufen“ (`NotificationService.scheduleReplenishmentDigests`)
und der Hintergrundlauf `ReplenishmentBackgroundRefresh.run(container:now:)` laufen in keinem Test. Die
Planungsregel (`ReplenishmentDigestPlanner`), das Ledger und die Protokoll-Logik sind in
`ReplenishmentDigestTests` unit-geprüft; die **Kette** Kaufhistorie → Muster → Kandidaten → Planer →
Mitteilungszentrale → Protokoll → Ledger ist unbewiesen.

**Gefundener Produktfehler (Messung im Simulator Restock-Validate, 2026-10-13, Wegwerf-Kopie):** Ohne
Mitteilungserlaubnis (`notDetermined`) wirft `center.add` **nicht**, die Zentrale bleibt aber **leer**, und
`ReplenishmentDigestLog.planned()` hält die Mitteilung trotzdem für geplant. `commitDelivered` trägt den
Artikel nach der Zustellzeit (9:00) ins `OverdueNotificationLedger` ein, obwohl nie etwas verschickt wurde: Er
wird in diesem Kaufzyklus nicht mehr gemeldet. Der Kommentar in `performDigestScheduling` („Ohne Erlaubnis
scheitert das“) ist falsch. Die Erlaubnis wird nur beim Einschalten des Schalters in den Einstellungen
erfragt, der Standardwert von `notificationsEnabled` ist `true`; wer den Schalter nie bedient, wird nie
gefragt. Betrifft nur den Developer Mode (Nachkauf kommt erst mit 1.1). Der PO hat den Produktfix am
2026-10-13 freigegeben.

**Recherche (vor der Analyse):** `UNUserNotificationCenter.add` wirft ohne Erlaubnis nicht; bei `notDetermined`
bleibt die Anfrage still liegen, die Foren empfehlen, vorher `notificationSettings()` zu prüfen. Quellen:
https://developer.apple.com/tutorials/data/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:).md ·
https://developer.apple.com/forums/thread/713515 · https://developer.apple.com/forums/thread/684226

Kein Modell beteiligt, alles deterministisch (Regel vor Modell). Ticket-Rahmen: #98 ist ein Ticket mit
mehreren Durchgängen (Entscheidung Henning 2026-10-03); die Scoping-Limits gelten je Durchgang. Dies ist
Durchgang 7 = Punkt 5. Punkt 6 (Siri/Widget) bleibt offen.

**Offene Grenzen (gelten für jede positive Zusage dieses Durchgangs):**

- **Echte Zustellung um 9:00** durch das System ist nicht automatisierbar; geprüft wird, was in der
  Zentrale **angemeldet** ist.
- **Vom System gestarteter Hintergrundlauf** (`BGAppRefreshTask`): geprüft wird `run(container:now:center:)`
  als Funktion, nicht der Start durch iOS.
- **`BGTaskScheduler.submit`** scheitert im Simulator immer; `schedule()` ist nur über `isEnabled` und
  Abmelden prüfbar, nicht über eine tatsächlich angemeldete Anfrage.
- **Systemdialog der Erlaubnis:** `simctl privacy` kennt den Dienst `notifications` nicht; die Erlaubnis lässt
  sich von außen nicht setzen. Der Weg mit echter erteilter Erlaubnis läuft nur über die Fake-Zentrale.
- **Hennings Geräte bleiben unberührt:** Es läuft kein Test auf einem Gerät des Users (Regel: nur auf sein Wort).

## Source

- **Geändert:** `SmartCart/Services/NotificationService.swift` — Protokoll `DigestNotificationCenter`
  (`authorizationStatus()`, Kennungen ausstehender Anfragen, `remove(ids)`, `add(request)`, `removeAll()`),
  Erweiterung von `UNUserNotificationCenter` als Standard-Implementierung;
  `scheduleReplenishmentDigests(candidates:now:center:)` und `cancelAll(center:)` nehmen die Naht mit
  Standardwert `UNUserNotificationCenter.current()` entgegen; Erlaubnisprüfung am Anfang von
  `performDigestScheduling` (Produktfix); falscher Kommentar korrigiert.
- **Geändert:** `SmartCart/Services/ReplenishmentDigest.swift` — `ReplenishmentBackgroundRefresh.run(container:now:center:)`
  reicht die Naht durch (Standardwert wie oben).
- **Neu:** `RestockTests/NotificationDigestChainTests.swift` — Unit-Tests D1–D6 mit Fake-Zentrale.
- **Geändert:** `Restock.xcodeproj/project.pbxproj` — Testdatei in `PBXBuildFile`, `PBXFileReference`,
  `PBXGroup` (RestockTests) und `PBXSourcesBuildPhase` des Unit-Test-Targets (~10 LoC; vier Stellen laut
  `CLAUDE.md` „Adding new Swift files“).
- **Geändert:** `CLAUDE.md` — Absatz „Durchgang 7“.
- **Neu:** diese Spec.
- **Nicht geändert (ausdrücklich):** `ReplenishmentDigestPlanner`, `ReplenishmentDigestLog`,
  `OverdueNotificationLedger`, `HabitService`, `HomeView`, `SmartCartApp`, `SettingsView` (Schalter und
  Anfrage der Erlaubnis bleiben wie sie sind), alle Texte, `Info.plist`, Scheme, Launch-Argumente, Modelle.
  `ReplenishmentBackgroundRefresh.schedule`/`isEnabled` unverändert. Kein neuer `@AppStorage`-Schlüssel.

Geschätzter Umfang: **5 Dateien** (`NotificationService.swift`, `ReplenishmentDigest.swift`,
`NotificationDigestChainTests.swift`, `project.pbxproj`, `CLAUDE.md`; dazu diese Spec), ca. **+230 / −10 LoC**,
davon Produktcode ca. 40, Test ca. 190. Das liegt innerhalb der Limits (4–5 Dateien, ±250 LoC); die
Summe aus Hinzufügungen und Löschungen (~240) liegt knapp darunter. Überschreitet die Umsetzung ±250 LoC:
stoppen und mit Schätzung nachfragen.

## Verhalten

### Befunde aus dem Code

- **Planung:** `scheduleReplenishmentDigests` reiht Aufrufe nacheinander ein (`digestScheduling`).
  `performDigestScheduling` ruft `log.commitDelivered(now:to:ledger)`, plant mit
  `ReplenishmentDigestPlanner.plan`, entfernt alle ausstehenden Anfragen mit Präfix `replenish-` (fremde
  Kennungen bleiben), fügt je Sammelnachricht eine Anfrage `replenish-digest-<Jahr>-<Monat>-<Tag>` hinzu und
  schreibt die erfolgreich angemeldeten ins Protokoll (`log.replace`).
- **Hintergrundlauf:** `run(container:now:)` ruft `schedule(now:)`, bricht ab, wenn `!isEnabled`
  (`developerMode` aus **oder** `notificationsEnabled` aus; Standard von `notificationsEnabled` ist `true`),
  liest `PurchaseRecord`s und offene `ShoppingItem`s aus `container.mainContext`, bildet Muster, führt
  `ReplenishmentKeyMigration.runIfNeeded` aus, bereinigt Snoozes und ruft
  `NotificationService.shared.scheduleReplenishmentDigests`.
- **Ledger erst nach Zustellzeit:** Ein Artikel gilt erst als gemeldet, wenn die Zustellzeit seiner Nachricht
  vorbei ist (`commitDelivered`), nicht beim Planen.
- **Schlüssel in `UserDefaults.standard`** (im Code ermittelt): Ledger `notifiedOverdueReplenishments`
  (`OverdueNotificationLedger.defaultsKey`), Protokoll `scheduledReplenishmentDigests`
  (`ReplenishmentDigestLog.defaultsKey`), Snoozes `snoozedReplenishments`, Sperrliste `blockedReplenishments`,
  Rückmeldungen `dismissedReplenishments` und `acceptedReplenishments`, Schlüsselmigration
  `replenishmentKeysByPurchaseDate` (`ReplenishmentKeyMigration.doneKey`), Metrik
  `replenishmentMetricsCounts`/`replenishmentMetricsShown`, dazu `developerMode` und `notificationsEnabled`.
  `run(container:)` und `NotificationService` nehmen keine Suite entgegen; der Test muss diese Schlüssel selbst
  aufräumen.

### Naht `DigestNotificationCenter`

Kleines Protokoll vor der Mitteilungszentrale, `UNUserNotificationCenter` als Standard. Im Test ersetzt eine
Fake-Zentrale (Klasse im Testtarget) sie: speichert Anfragen in einem Wörterbuch nach Kennung, liefert einen
einstellbaren Erlaubnis-Status. Damit läuft die echte Kette ohne Systemerlaubnis, die sich per `simctl` nicht
setzen lässt. `cancelAll` läuft ebenfalls über die Naht.

### Produktfix

Am Anfang von `performDigestScheduling` wird der Erlaubnis-Status der Zentrale gelesen. Nur `.authorized` und
`.provisional` gelten als erteilt. Andernfalls (`notDetermined`, `denied`, `ephemeral`, unbekannt): **nichts
planen, nichts entfernen, nichts ins Protokoll schreiben** (auch kein `log.replace([])`, kein
`commitDelivered`-Eintrag neuer Art), sodass der Artikel meldbar bleibt, sobald die Erlaubnis später erteilt
wird. Der Kommentar „Ohne Erlaubnis scheitert das …“ wird durch eine zutreffende Aussage ersetzt (add wirft
ohne Erlaubnis nicht; deshalb wird vorher geprüft). Mit Erlaubnis bleibt das Verhalten unverändert.

Reihenfolge: Die Erlaubnisprüfung steht vor `commitDelivered`. Ohne Erlaubnis wird also auch nichts aus dem
Protokoll ins Ledger übertragen; ein Eintrag bleibt im Protokoll liegen, bis die Erlaubnis wieder vorliegt.

### Unit-Tests `NotificationDigestChainTests`

Aufbau: In-Memory-`ModelContainer` mit den Modellen der App (`Store`, `ShoppingItem`, `PurchaseRecord`),
Fake-Zentrale, feste Zeit (feste Daten Sept./Okt. 2026 ohne Zeitumstellung, fester Kalender wie in
`ReplenishmentDigestTests`), `developerMode = true` und `notificationsEnabled = true` in
`UserDefaults.standard` je Test gesetzt. Kaufhistorie: genügend `PurchaseRecord`s an gleichmäßigen Abständen
(Eignung: ≥ 3 Kauftage, Variationskoeffizient ≤ 0,5), sodass ein Artikel im 7-Tage-Fenster fällig wird.

- **D1 Kette:** Kaufhistorie → `run(container:now:center:)` → die Fake-Zentrale enthält genau **eine**
  Anfrage `replenish-digest-…` mit Auslösezeitpunkt 9:00 des erwarteten Tages, Titel/Text nennen den richtigen
  Artikel; `ReplenishmentDigestLog.planned()` hat denselben Eintrag.
- **D2 Abgemeldet:** (a) `developerMode` aus, (b) `notificationsEnabled` aus → `run` plant nichts, Zentrale und
  Protokoll leer.
- **D3 Ersetzen:** Zentrale enthält vorab eine fremde Anfrage (z. B. `other-1`) und eine alte `replenish-old`;
  nach dem Lauf ist `replenish-old` weg, `other-1` bleibt; ein zweiter Lauf mit geänderter Kaufhistorie ersetzt
  die Sammelnachricht (keine Dopplung derselben Kennung).
- **D4 Ledger erst nach Zustellzeit:** Nach `run` vor 9:00 des Zustelltags steht der Artikel **nicht** im
  Ledger. Ein weiterer Lauf **nach** 9:00 (Zustellzeit vorbei) trägt ihn ins Ledger; der Artikel erscheint in
  keiner neuen Sammelnachricht desselben Kaufzyklus.
- **D5 Ohne Erlaubnis (Fehlerfall, Produktfix):** Status `notDetermined` (und `denied`) → nichts in der
  Zentrale, **nichts im Protokoll**, kein Ledger-Eintrag auch nach Zustellzeit, und derselbe Artikel wird nach
  Erteilung der Erlaubnis (Status `authorized`, nächster Lauf) geplant, also **bleibt meldbar**. Dieser Test
  muss **vor dem Fix rot** sein (Protokoll hält 1 Mitteilung).
- **D6 `cancelAll`:** nach geplanter Sammelnachricht leert `cancelAll(center:)` die Zentrale **und** das
  Protokoll.

`tearDown()` entfernt alle berührten `UserDefaults.standard`-Schlüssel (siehe oben, Liste im Code ermittelt)
einschließlich `developerMode` und `notificationsEnabled` und **prüft** per `XCTAssertNil`, dass keiner übrig
ist (Muster Durchgang 4: `SharedStoreMergeTests`). Der `setUp` prüft denselben Ausgangszustand.

## Acceptance Criteria

- **AC-1:** Naht: Das Protokoll `DigestNotificationCenter` existiert; `UNUserNotificationCenter` ist die
  Standard-Implementierung; `scheduleReplenishmentDigests(candidates:now:center:)`,
  `ReplenishmentBackgroundRefresh.run(container:now:center:)` und `cancelAll(center:)` nehmen die Naht mit
  Standardwert entgegen. Nachweis: Die bestehenden Aufrufer (`HomeView`, `SmartCartApp`, `SettingsView`)
  bleiben ohne Änderung kompilierbar (Build grün, `git diff` ohne diese Dateien).
- **AC-2:** Kette (D1): Aus einer Kaufhistorie im In-Memory-Container entsteht über `run(container:now:center:)`
  in der Fake-Zentrale genau eine Anfrage `replenish-digest-<Y>-<M>-<D>` um 9:00 des erwarteten Tages mit dem
  richtigen Artikelnamen im Text; das Protokoll enthält denselben Eintrag.
- **AC-3:** Abgemeldet (D2): Bei `developerMode` aus und bei `notificationsEnabled` aus plant `run` nichts
  (Zentrale und Protokoll leer).
- **AC-4:** Ersetzen (D3): Ein weiterer Lauf entfernt alte `replenish-*`-Anfragen und ersetzt die
  Sammelnachricht ohne Dopplung; fremde Kennungen (ohne Präfix `replenish-`) bleiben unverändert stehen.
- **AC-5:** Ledger erst nach Zustellzeit (D4): Vor 9:00 des Zustelltags steht der Artikel nicht im
  `OverdueNotificationLedger`; nach der Zustellzeit steht er darin und wird im selben Kaufzyklus nicht erneut
  gemeldet (keine neue Anfrage für ihn).
- **AC-6:** Produktfix (D5): Ohne erteilte Erlaubnis (`notDetermined`, `denied`) plant
  `scheduleReplenishmentDigests` nichts, entfernt nichts und schreibt nichts ins Protokoll; der Artikel steht
  auch nach der Zustellzeit nicht im Ledger und wird nach Erteilung der Erlaubnis (nächster Lauf) geplant.
  **Rot-vor-Fix-Nachweis:** D5 wird vor dem Produktfix ausgeführt und schlägt fehl (Protokoll enthält 1
  Eintrag), nach dem Fix ist D5 grün; beide Läufe liegen als Ausgabe unter `docs/artifacts/test-98-durchgang-7-tagesmitteilung/`.
  `.authorized` und `.provisional` planen wie bisher.
- **AC-7:** `cancelAll` (D6): Nach `cancelAll(center:)` ist die Fake-Zentrale leer und
  `ReplenishmentDigestLog.planned()` leer.
- **AC-8:** Aufräumen: `NotificationDigestChainTests.tearDown()` entfernt `notifiedOverdueReplenishments`,
  `scheduledReplenishmentDigests`, `snoozedReplenishments`, `blockedReplenishments`,
  `dismissedReplenishments`, `acceptedReplenishments`, `replenishmentKeysByPurchaseDate`,
  `replenishmentMetricsCounts`, `replenishmentMetricsShown`, `developerMode` und `notificationsEnabled` aus
  `UserDefaults.standard` und prüft, dass keiner übrig ist. Nachweis: Die Bestandssuiten (insbesondere
  `ReplenishmentDigestTests`, `ReplenishmentPackageA/B/CTests`, `ReplenishmentSeedYearTests` und die UI-Suiten) laufen im gemeinsamen Lauf mit der
  neuen Klasse grün. „Executed 0 tests“ oder ein Abbruch ist kein Grün; die Testzahl wird geprüft.
- **AC-9:** Echter Weg statt Nachbau: Die Tests rufen die echten Funktionen (`run`,
  `scheduleReplenishmentDigests`, `cancelAll`) mit echtem Planer, Ledger, Protokoll und SwiftData; ersetzt
  wird nur die Mitteilungszentrale. Ledger, Protokoll und Muster werden nicht von Hand gesetzt, außer als
  dokumentierter Ausgangszustand (D3: fremde/alte Anfrage in der Fake-Zentrale).
- **AC-10:** Stabilität: Feste Zeit, fester Kalender, keine Wartezeiten, keine Abhängigkeit von der Systemuhr.
  Nachweis: mindestens drei Läufe der neuen Klasse hintereinander grün.
- **AC-11:** Umfang: ≤ 5 geänderte Dateien (Produkt: `NotificationService.swift`, `ReplenishmentDigest.swift`;
  dazu Testdatei, `project.pbxproj`, `CLAUDE.md`), Summe ≤ ±250 LoC (Schätzung +230/−10); im Produktcode
  keine weiteren Änderungen als Naht, Erlaubnisprüfung und Kommentar. Nachweis: `git diff --stat` gegen
  `origin/main`.
- **AC-12:** Pflicht-Durchlauf (siehe unten) ist als registriertes Artefakt vorhanden, aus einem echten Lauf
  (Commit-Kennung und Zeitstempel passen zum Stand), und nicht von Hand gesetzt.
- **AC-13:** Offene Grenzen sind in Spec, Kopfkommentar der Testklasse, `CLAUDE.md` und Ticketkommentar von #98
  benannt: echte Zustellung um 9:00, vom System gestarteter Hintergrundlauf, `BGTaskScheduler.submit` im
  Simulator, Systemdialog der Erlaubnis, keine Tests auf Hennings Geräten. Keine Zusage lautet „Tagesmitteilung
  geprüft“ ohne diese Einschränkungen.
- **AC-14:** Hennings Geräte: Kein Schritt dieses Durchgangs startet, installiert oder liest ein Gerät des
  Users; alle Läufe nur im Simulator Restock-Validate bzw. im Unit-Test-Host.

## Tests

| # | Testfall | Datei | Art | Prüft |
|---|----------|-------|-----|-------|
| T1 | D1 Kette Kaufhistorie → Sammelmitteilung 9:00 | `NotificationDigestChainTests` | Unit | AC-1, 2, 9 |
| T2 | D2 abgemeldet (`developerMode` aus / `notificationsEnabled` aus) | `NotificationDigestChainTests` | Unit | AC-3 |
| T3 | D3 Ersetzen, fremde Kennungen bleiben | `NotificationDigestChainTests` | Unit | AC-4 |
| T4 | D4 Ledger erst nach Zustellzeit | `NotificationDigestChainTests` | Unit | AC-5 |
| T5 | D5 ohne Erlaubnis (rot vor dem Fix) | `NotificationDigestChainTests` | Unit | AC-6 |
| T6 | D6 `cancelAll` leert Zentrale und Protokoll | `NotificationDigestChainTests` | Unit | AC-7 |
| T7 | Bestandssuiten im gemeinsamen Lauf, Schlüssel-Leerprüfung in `tearDown` | alle | Unit+UI | AC-8 |
| T8 | Wiederholung mindestens 3x | neue Klasse | Unit | AC-10 |
| T9 | Diff-Nachweis: Dateizahl, LoC, Aufrufer unverändert (`git diff --stat` gegen `origin/main`) | — | Diff | AC-1, 11 |
| T10 | Durchlauf im Simulator, Artefakt durch Werkzeug | — | durch Werkzeug | AC-12, 14 |

TDD: Zuerst die Naht als reines Refactoring (Verhalten gleich), dann Testdatei D1–D6 schreiben. D1–D4 und D6
sollten sofort grün sein, **D5 muss rot** sein (Fehler am Stand ohne Fix belegt: Protokoll hält 1
Mitteilung). Danach der Produktfix; D5 grün. Eine Mutationsprobe (Erlaubnisprüfung entfernen → D5 rot) belegt,
dass der Test nicht leer läuft.

## Risiken

- **Gemeinsame `UserDefaults.standard`:** `run` und `NotificationService` nehmen keine Suite; hinterlassene
  Schlüssel beeinflussen andere Tests (Memory „UI-Test-Seeds müssen aufräumen“). Gegenmittel: AC-8.
- **Zeit und Kalender:** `NotificationService` nutzt `Calendar.current` für Auslösekomponenten; die Tests
  wählen Daten, bei denen Zeitzone und Zeitumstellung das Ergebnis nicht ändern, und vergleichen
  Komponenten robust.
- **Singleton `NotificationService.shared`:** `digestScheduling` hält den vorigen Lauf; Tests warten jeden
  Aufruf mit `await` ab, laufen nacheinander.
- **`BGTaskScheduler.shared.submit/cancel`** in `run` → `schedule` wird im Test-Host aufgerufen; scheitert im
  Simulator still (`try?`), `cancel` ist unschädlich.
- **Fix ändert sichtbares Verhalten im Developer Mode:** Ohne Erlaubnis wird nichts mehr als „gemeldet“
  geführt; wer nie gefragt wurde, bekommt weiterhin keine Mitteilung, aber der Artikel bleibt im Banner meldbar.
  Release 1.0 ohne Nachkauf ist nicht betroffen.
- **Null-Test-Lauf:** „Executed 0 tests … TEST SUCCEEDED“ nach Abbruch ist kein Grün (Memory); Nachweise prüfen
  Testzahl und Abbrüche.
- **Umfang:** Schätzung +230/−10 liegt nah an ±250; Überschreitung = STOP und Nachfrage.

## Alternativen

- **(a) UI-Test mit Systemdialog (`UIInterruptionMonitor`, Erlaubnis in den Einstellungen schalten):** prüft das
  echte System, aber der Schalter existiert nur im Developer Mode, die Zentrale ist aus dem UI-Test nicht
  lesbar, die Zustellung um 9:00 bleibt unprüfbar. Als spätere Ergänzung möglich, nicht als Ersatz. Kippt
  keine ADR.
- **(b) Nur `isAuthorized` testen, ohne Naht:** kein Produktcode, aber die Kette bis zur Zentrale bliebe offen,
  und genau dort sitzt der Fehler (Messung). Würde die Aussage „Produktcode bleibt in Testdurchgängen
  unverändert“ aus den Durchgängen 4–6 nicht kippen, verfehlt aber das Ziel.
- **(c) Erlaubnis beim ersten Start des Developer Mode erfragen** statt Prüfung vor `add`: ändert das
  Produktverhalten sichtbar (Systemdialog) und berührt die Entscheidung „Erlaubnis nur am Schalter“ aus #30.
  PO-Thema, **nicht Teil dieses Durchgangs**; würde diese #30-Entscheidung kippen.
- **Ohne Modell:** nichts hier braucht ein Sprachmodell.

**Entscheidung:** Naht plus Unit-Tests D1–D6 und kleiner Produktfix (Prüfung vor `add`), weil nur so die Kette
ohne Systemerlaubnis beweisbar ist und der gefundene Fehler am reproduzierten Fall rot/grün belegt wird.

## Pflicht-Durchlauf

Grüne Unit-Tests sind kein Nachweis, dass das Feature lebt. Vor Übergabe wird die App im Simulator
**Restock-Validate** mit dem Stand dieses Durchgangs gebaut, installiert und gestartet, mit Developer Mode
und gesäten Nachkauf-Daten: `-hasCompletedOnboarding YES -developerMode YES -seedReplenishmentForUITests`
(bestehende Argumente; keine neuen). Ablauf: Startseite zeigt den Nachkauf-Banner aus den gesäten Käufen
(die App berechnet das Fällige selbst), die Planung läuft ohne Absturz durch (Protokoll
`os.Logger`/App-Protokoll prüfen), und im Simulator ohne erteilte Erlaubnis ist die Zentrale leer **und** das
Protokoll `scheduledReplenishmentDigests` leer (Beleg des Fixes am echten Weg, derselbe Weg wie die Messung
vom 2026-10-13). Aufräumen mit `-clearReplenishmentForUITests`. Der Nachweis wird als Artefakt durch das
Werkzeug registriert (Commit-Kennung und Zeitstempel müssen zum aktuellen Stand passen), nie von Hand
gesetzt. Es läuft nichts auf Hennings Geräten.

## Offene Punkte

- Keine für den PO offen (Produktfix am 2026-10-13 freigegeben).
- Gehört nicht zu diesem Durchgang, als Folgearbeit im Ticketkommentar von #98 festzuhalten: UI-Test mit
  Systemdialog der Erlaubnis; Entscheidung, ob die Erlaubnis beim ersten Start des Developer Mode erfragt
  werden soll (PO-Thema); Punkt 6 (Siri/Widget).
- Offene Grenze (gilt für jede Zusage dieses Durchgangs): echte Zustellung um 9:00, vom System gestarteter
  Hintergrundlauf, `BGTaskScheduler.submit` im Simulator, Systemdialog der Erlaubnis, keine Tests auf Hennings
  Geräten.
