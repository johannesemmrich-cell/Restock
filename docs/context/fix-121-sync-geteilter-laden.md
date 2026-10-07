# Context: fix-121-sync-geteilter-laden (#121)

## Request Summary
PO 2026-10-07: „Die Synchronisierung klappt nicht“ — **geteilter Laden**, **gar nichts kommt an**, beide Geräte **über TestFlight**, im Laden steht der Hinweis **„Sync fehlgeschlagen — Änderungen werden möglicherweise nicht mit anderen geteilt“** (= `SyncFailureKind.other`, also weder Schreibberechtigung noch fehlende iCloud-Anmeldung). Höchste Priorität (vor #120).

## Intake-Bewertung
| Kriterium | Score | Begründung |
|---|---|---|
| Scope | Medium | Sync-Dienst, Views, ggf. Diagnose; Ursache noch offen |
| Blast Radius | High | Datenabgleich, kritischer Pfad, geteilte Daten |
| Unsicherheit | High | Ursache hängt an Server-Konfiguration, die aus dem Repo nicht lesbar ist |
Summe 5 → voller Prozess, Context und Analyse getrennt, Opus.

## Befund 1: Das Teilen ist ein Eigenbau auf der öffentlichen CloudKit-Datenbank, kein CKShare
Quelle: Code-Analyse (Explore-Agent, 2026-10-07), Stellen mit Zeilen:
- `SmartCart/Services/SharedStoreService.swift:9` `container.publicCloudDatabase`; ein Einzel-Record `SharedStore` je Laden, Name = 10-stelliger Code; Items als JSON-Strings (`itemsJSON`, `membersJSON`, `deletedJSON`, `pricesJSON`, `categoriesJSON`, `assignmentsJSON`).
- Kein CKShare, keine Zonen, keine Change-Tokens. Abgleich über `record.modificationDate` gegen Wasserstand `lastSync_<code>` (UserDefaults): `SharedStoreService.swift:171` (`remoteModified <= lastSync` → nichts Neues), `:67` (Wasserstand nach Push).
- Pull: 15-s-Schleife nur bei aktiver App (`SmartCartApp.swift:730-738`, `SyncCoordinator.swift:187-195`); Hintergrund nur per stiller Nachricht (`AppDelegate.swift:37-52`, `CKQuerySubscription`, `SharedStoreService.swift:219-232`).
- Entitlement: `SmartCart/SmartCart.entitlements` `aps-environment=development` (bei TestFlight-Signierung wird `production` eingesetzt); `UIBackgroundModes` über `project.yml:31`.

## Befund 2: Fehler werden still verschluckt
- `SyncCoordinator.swift:73-76, 93-96` fangen jeden Fehler, geben nur `false` + `lastFailureKind` zurück, **kein Log**; `pullAllSharedStores`/`pullStore` werfen das Ergebnis weg (`:156-175`); `pushInBackground` schluckt bewusst (`:106-114`); `apply`-Save-Fehler ohne Log (`:310-312`).
- `SharedStoreService.swift:55-60` behandelt **jeden** Fehler beim Record-Fetch als „neuer Record“.
- `StoreShareSheet.swift:176-177, 416-417`: `subscribe`-Fehler nur `print`; Teilen/Beitreten gilt trotzdem als erfolgreich. `:371-376`: jeder Fehler beim Beitritts-Lookup wird zu „nicht gefunden“.
- Es gibt **kein** `os_log`, **keinen** Account-Status-Check (`CKAccountStatus`), **keine** Sync-Diagnoseansicht; `lastFailureKind` wird nach Erfolg nie zurückgesetzt. Der Fehlerhinweis erscheint nur bei Pull/Push aus `StoreDetailView` (`:275`, `:1075-1089`).

## Befund 3: Recherche (Internet, 2026-10-07) — zur Einordnung
Der Eigenbau nutzt kein CKShare; die gefundenen iOS-26-Fälle zu `CKShare` (Share ohne Root, Zone wird beim Annehmen gelöscht, `NSPersistentCloudKitContainer.share()` hängt) treffen daher **nicht** zu. Relevant bleiben:
- Öffentliche Datenbank: Schreiben nur durch den Ersteller, wenn die Security Role im Dashboard nicht „Authenticated: write“ erlaubt; Query-Subscriptions brauchen einen abfragbaren Index auf `recordName`.
- Stille Nachrichten: Apple-Forum „iOS 26 stops receiving push notifications“ (Regression 26.4, https://developer.apple.com/forums/thread/805157); Hinweise zu `shouldSendContentAvailable`, Hintergrundmodi und gedrosselter Zustellung (https://developer.apple.com/forums/thread/667852, https://developer.apple.com/forums/thread/671087).
- Produktivumgebung: Ein Entwicklungsschema wirkt nicht in TestFlight/App Store; Record-Typ und Indizes müssen mit „Deploy Schema to Production“ veröffentlicht sein (Apple CloudKit-Dokumentation).
Quellen: https://developer.apple.com/forums/thread/815020, https://developer.apple.com/forums/thread/822913, https://developer.apple.com/forums/thread/805157

## Befund 4: PO-Hinweis „bisher hat es perfekt funktioniert“ → Verschlechterung durch eine Änderung
- Build 8 (2026-10-01) → Build 9 (2026-10-05, Stand nach #98 Durchgang 3). Dazwischen am 2026-10-02 zwei **neue Felder im Record `SharedStore`**: `categoriesJSON` (Commit 3bc0abf, #85/#86/#87) und `assignmentsJSON` (6c4a032, #94/#96). `pricesJSON` ist älter (2026-07-25).
- `SharedStoreService.swift:127-128` schreibt beide Felder bei **jedem** Speichern (auch leer: `"{}"`). Gelesen werden sie mit Vorgabewert (`:92, 97, 183-184`), ein Pull funktioniert also ohne die Felder.
- In der **Produktivumgebung** legt CloudKit unbekannte Felder nicht automatisch an (nur in Entwicklung). Fehlen die zwei Felder im Produktions-Schema, wird **jedes Speichern abgelehnt** → Push scheitert bei beiden Geräten → nichts kommt an; die Klassifizierung in `SyncCoordinator` ergibt `.other` („Sync fehlgeschlagen“). Passt zu allen drei Beobachtungen (Zeitpunkt, TestFlight/Produktion, Hinweistext).
- Noch nicht bewiesen: es fehlt der Blick ins Produktions-Schema (Felder von `SharedStore`).

## Hypothesen (nach Wahrscheinlichkeit; keine bewiesen)
0. **Neue Felder `categoriesJSON`/`assignmentsJSON` fehlen im Produktions-Schema** (Befund 4) — jetzt Hauptverdacht; die Prüfung ist eine Ja/Nein-Frage im Dashboard, die Behebung „Deploy Schema to Production“ (Konfiguration, kein Code).
1. **Schema in der Produktivumgebung fehlt oder unvollständig** (Record-Typ `SharedStore`, Felder, Index auf `recordName`, Rolle). Stützt: beide Geräte über TestFlight (= Produktion), Hinweis „Sync fehlgeschlagen“ = `.other`, das Fehler wie `invalidArguments`/`serverRejectedRequest` einschließt; „früher ging es“ nur mit Xcode-Läufen (Entwicklungsumgebung). **Gegen:** schon das Einrichten des Teilens hätte dann einen Fehler mit Details gezeigt (`StoreShareSheet.swift:185-198`), wenn es in Produktion erfolgt wäre.
2. Laden wurde in der Entwicklungsumgebung geteilt und erscheint durch Spiegelung (SwiftData-iCloud / `CloudPreferencesSync`) als geteilt, der Record existiert in Produktion nicht → jeder Pull/Push scheitert.
3. Wasserstand überspringt Updates (`SharedStoreService.swift:67/171`, `SyncCoordinator.swift:91/307-312`) — erklärt eher „manches fehlt“ als „gar nichts“.
4. Stille Nachrichten im Hintergrund unzuverlässig — erklärt Verzögerung, nicht „gar nichts“ bei geöffneter App (Polling alle 15 s).

## Was aus dem Repo / von hier nicht prüfbar ist
Server-Konfiguration (Security Roles, Indizes, Produktions-Deploy). Kein CloudKit-Management-Token auf diesem Rechner (`cktool get-teams` → „No management token found“); die Browser-Erweiterung ist mit einem anderen claude.ai-Konto verbunden und deshalb nicht nutzbar.

## Alternativen zum bisherigen Weg (Pflicht: in Alternativen denken)
- **A. Eigenbau beheben + sichtbar machen:** Fehlertext des echten `CKError` im Banner und in einer Dev-Diagnoseansicht, Account-Status prüfen, Fehler beim Fetch nicht als „neuer Record“ werten. Behält die öffentliche Datenbank.
- **B. Auf Apples CKShare + private/shared Datenbank umstellen:** Rechte, Zonen, Push und Annahme übernimmt das System; kippt die Entscheidung für den Code-Eigenbau und braucht Migration der bestehenden geteilten Läden. Groß, nur bei belegter Sackgasse.
- **C. Kein Server-Sync, nur Export/Import:** verworfen — widerspricht dem Ziel.
Empfehlung: A zuerst (belegt die Ursache, behebt Sichtbarkeit), B nur als eigenes Ticket bei Bedarf.

## Offene Frage (PO)
Existiert im CloudKit-Dashboard (Container `iCloud.com.johannesemmrich.SmartCart`) in der **Produktivumgebung** der Record-Typ `SharedStore`, und ist „Deploy Schema to Production“ nach der letzten Schemaänderung erfolgt?

## Related Files
| File | Relevanz |
|------|----------|
| `SmartCart/Services/SharedStoreService.swift` | Record `SharedStore` (Public DB), Felder, Merge, Fehler beim Fetch, Subscription |
| `SmartCart/Services/SyncCoordinator.swift` | Pull/Push, 15-s-Schleife, `lastFailureKind`, still verschluckte Fehler |
| `SmartCart/Views/Store/StoreDetailView.swift` | Fehlerhinweis „Sync fehlgeschlagen“ (`:275`, `:1075-1089`) |
| `SmartCart/Views/Store/StoreShareSheet.swift` | Teilen/Beitreten, Fehlerdetail beim Teilen (`:185-198`) |
| `SmartCart/AppDelegate.swift` | Stille Nachrichten (`:37-52`) |
| `RestockTests/SharedStoreMergeTests.swift` | Bestehende Merge-Tests ohne CloudKit (#98 Durchgang 4) |

## Dependents (Aufrufer von SharedStoreService/SyncCoordinator)
HomeView, AllItemsView, MenuPlanView, AddItemView, EditItemView, QuickAddTargetViews, StoreSetupView, ReceiptScannerView, RecipeImportView, ReceiptShareHandoff, SharedItemPhotoService, Store, ShoppingItem, SmartCartApp.

## Existing Specs
`docs/specs/models/shared-model-container.md` (anderer Pfad: SwiftData-Container); `docs/specs/ui-tests/test-98-durchgang-4-sync-merge.md` (Merge-Logik, offene Grenze: echtes Teilen, Server). Keine Spec zum Record-Schema von `SharedStore`.

## Risks & Considerations
- Server-Schema ist aus dem Repo nicht lesbar; ohne Dashboard-Blick bleibt die Ursache Hypothese. Beweis kann auch aus der App kommen (echter `CKError`-Text im Diagnose-Build).
- Änderungen am Sync-Code berühren geteilte Daten: keine Änderung am Merge ohne Tests; Fallback ohne die neuen Felder darf geteilte Kategorien/Zuordnungen nicht still verwerfen, sondern muss es anzeigen.
- PO hat nur ein Smartphone zur Hand (2026-10-07): Installation neuer Stände über TestFlight möglich, Dashboard-Prüfung am Telefon nur umständlich.

## Analysis

### Type
Bug (Verschlechterung zwischen Build 8 und Build 9; Ursache belegt durch Zeitverlauf + Code, Schema-Zustand in Produktion noch nicht eingesehen)

### Recherche (vor der Analyse, mit Quellen)
- TestFlight-Builds nutzen standardmäßig die **Produktionsumgebung**; dort dürfen Record-Typen und Felder nicht neu angelegt werden, das Schema muss aus der Entwicklung veröffentlicht werden („Deploy Schema Changes“): https://developer.apple.com/forums/thread/723675, https://developer.apple.com/videos/play/wwdc2021/10117/
- Wörtliche Fehlermeldung bei unbekanntem Feld: „Cannot create or modify field '…' in record '…' in production schema“: https://developer.apple.com/forums/thread/749729
- Weitere Fälle derselben Art: https://developer.apple.com/forums/thread/819507, https://developer.apple.com/forums/thread/740460

### Root Cause (mit Belegen)
`SharedStoreService.mergeIntoRecord` schreibt bei **jedem** Speichern `categoriesJSON` und `assignmentsJSON` (`SharedStoreService.swift:127-128`). Beide Felder wurden am 2026-10-02 eingeführt (3bc0abf #85/#87, 6c4a032 #94/#96) und sind erstmals in Build 9 (2026-10-05) auf Geräte gekommen. Fehlen sie im Produktions-Schema, lehnt CloudKit jedes `save` ab (Fehlertext oben). `syncToCloud` bewertet das als `.other` → „Sync fehlgeschlagen“ (`SyncCoordinator.swift`, `StoreDetailView.swift:1075-1089`). Ein Pull funktioniert weiter (fehlende Felder → Vorgabewert, `:92, 97, 183-184`). Zeitpunkt, TestFlight, Hinweistext und „gar nichts kommt an“ passen zusammen.
**Noch nicht bewiesen:** Blick ins Produktions-Schema. Reproduktion in Produktion von hier nicht möglich (kein Zugang). Ersatz-Nachweis im Test: ein Fake der Datenbank, der wie die Produktion Datensätze mit unbekannten Feldern ablehnt (RED), danach grün mit der Behebung.
**Zusatz:** „Deploy Schema“ überträgt nur Felder, die in der **Entwicklungsumgebung** existieren; sie entstehen dort nur, wenn ein Xcode-Lauf nach dem 2026-10-02 einen geteilten Laden gespeichert hat. Unbekannt.

### Alternativen zum bisherigen Weg
- **C. Nur Konfiguration, kein Code:** Schema veröffentlichen. Einfachster Weg, heilt sofort; schützt aber nicht vor dem nächsten Feld und macht Fehler weiter unsichtbar. Wird **zuerst** empfohlen (durch den Kontoinhaber), Code-Härtung ergänzt.
- **A. Härtung (Empfehlung für den Code):** (1) Beim Ablehnen wegen Produktions-Schema: Speichern ohne die optionalen Erweiterungsfelder wiederholen, damit der Kern (Artikel, Preise, Mitglieder) wieder abgleicht; Zustand „Schema unvollständig“ anzeigen. (2) Echten Fehlertext erfassen (`lastFailureDetail`, `Logger`), im Entwicklermodus voll, sonst kurz anzeigen. (3) Drift-Test: Feldliste des Datensatzes steht im Test; Änderung schlägt an mit Hinweis „Schema vor TestFlight-Upload veröffentlichen“. (4) Eintrag in `docs/testflight-setup.md`.
- **B. Umbau auf Apples CKShare / private+shared Datenbank:** Rechte, Zonen, Annahme übernimmt das System; kippt die Eigenbau-Entscheidung, Migration geteilter Läden nötig. Nicht jetzt; eigenes Ticket nur bei belegter Sackgasse.
- Regel vor Modell: kein Modell beteiligt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Services/SharedStoreService.swift` | MODIFY | Datenbank hinter kleinem Protokoll (testbar); Fallback ohne Erweiterungsfelder bei Ablehnung wegen Produktions-Schema; Feldlisten als Konstanten |
| `SmartCart/Services/SyncCoordinator.swift` | MODIFY | `SyncFailureKind.schemaIncomplete`, `lastFailureDetail`, `Logger`, Zustand „Schema unvollständig“ |
| `SmartCart/Views/Store/StoreDetailView.swift` | MODIFY | Hinweistext für „Schema unvollständig“, Fehlerdetail im Entwicklermodus |
| `RestockTests/SharedStoreSchemaTests.swift` | CREATE | RED: Fake-Produktion lehnt neue Felder ab; Drift-Test der Feldliste; Erkennung der Fehlertexte |
| `docs/testflight-setup.md` | MODIFY | Schritt „CloudKit-Schema veröffentlichen, wenn sich Felder von `SharedStore` ändern“ |
(+ `project.pbxproj`: neue Testdatei registrieren)

### Scope Assessment
- Files: 5 (+ pbxproj) — Grenze 4–5 ausgereizt
- Estimated LoC: ca. +180/−20 (Grenze ±250); Funktionen ≤ 50 LoC
- Risk Level: HIGH (kritischer Pfad, geteilte Daten) → Adversary 2 Runden

### Technical Approach
Fehlererkennung rein regelbasiert (kein Modell): `CKError` mit `ServerErrorDescription` bzw. `localizedDescription`, die „production schema“ enthält. Wiederholung des Speicherns nur ein Mal und nur mit den Kernfeldern; Zustand wird nicht still verschluckt, sondern im Banner genannt. Der Banner-Aufbau bleibt unverändert (nur Text/zweite Zeile), daher kein Entwurfs-Mockup.

### Dependencies
`CloudKit` (`CKDatabase`, `CKError`), `os.Logger`; Aufrufer von `SharedStoreService`/`SyncCoordinator` bleiben unverändert (Schnittstelle gleich).

### Open Questions
- [ ] (Konfiguration, nur Kontoinhaber) Schema in Produktion veröffentlichen und vorher prüfen, ob `categoriesJSON`/`assignmentsJSON` in der **Entwicklungsumgebung** stehen. Blockiert den Code nicht.
- [x] Keine PO-Entscheidung zum Code nötig (technisch).
