# Adversary Dialog — feat-234-d2-kategorien-einrichten
Spec: docs/specs/views/station-setup.md
Datum: 2026-10-31 14:02

## Checkliste
- [x] **AC-1:** Das ···-Menü jeder Ladenliste enthält genau einen Eintrag „Kategorien einrichten“ (`store.menu.setupStations`), auch in Läden ohne Gänge; „Lidl-Vorlage übernehmen“ und „Gänge entfernen“ stehen nicht mehr im Menü. (V1)
- [x] **AC-2:** Der Eintrag öffnet eine Ansicht mit Übersicht (Vorlage wählen, Gänge, Offen, Ausgeblendet, Gänge entfernen) und Gang-Detail wie im freigegebenen Entwurf 1–4; „Fertig“ schließt sie. (V1, V2)
- [x] **AC-3:** Ein Gang lässt sich umbenennen und mit neuem Emoji versehen. Danach stehen Merkungen (`categoryAssignments`), von Hand gesetzte `item.category`, die eigene Kategorie, `routeModel.itemCategories` und die Gang-Konfiguration unter dem neuen Namen, die Gang-Reihenfolge bleibt, und kein Artikel rutscht nach „Sonstiges“. (S1, V2)
- [x] **AC-4:** Eine laufende Abhak-Sitzung wird beim Umbenennen mitgezogen: `currentTrip.entries[].category` trägt den neuen Namen, und nach Abschluss der Sitzung lernt der Weg nur den neuen Namen. (S11)
- [x] **AC-5:** Umbenennen und Anlegen werden abgelehnt (nichts ändert sich, Hinweis sichtbar), wenn der Name leer ist, schon ein anderer Gang ihn trägt, „Sonstiges“/„Other“ lautet oder die Marke enthält; nur Schreibweise/Emoji des eigenen Gangs bleiben erlaubt. Es wird nie zusammengeführt. (S2, S3, V3)
- [x] **AC-6:** Gänge lassen sich per Ziehen (Knopf „Sortieren“) umordnen; die Reihenfolge wird sofort gespeichert (`save()`), und die Liste folgt ihr (Abschnitte und Einkaufsweg). (S7, V7)
- [x] **AC-7:** Ein Gang lässt sich über „Gang hinzufügen“ am Ende der Gänge anlegen, auch in einem Laden ohne Gänge (danach `hasStations`); er steht außer bei festem Namen als eigene Kategorie. (S8, V6)
- [x] **AC-8:** Jede feste Kategorie hat genau einen von drei Zuständen, ohne neues Feld: zugeordnet (in `builtIns` genau eines Gangs), ausgeblendet (in `hidden`), offen (keins von beiden). Zuordnen löst sie aus einem anderen Gang und aus `hidden`; Ausblenden löst sie aus allen Gängen; Einblenden macht sie offen. Die Liste folgt sofort: zugeordnete Kategorie → Gang-Abschnitt, offene oder ausgeblendete → „Sonstiges“. (S4, S5, V4, V5)
- [x] **AC-9:** Trägt ein Gang den Namen einer festen Kategorie (Anlegen oder Umbenennen), übernimmt er diese automatisch; sie ist in anderen Gängen nicht antippbar („gehört zu Gang …“) und weder offen noch ausgeblendet wählbar, bis der Gang umbenannt oder gelöscht wird. Es gibt keinen stillen vierten Zustand. (S3, S5, S10)
- [x] **AC-10:** Ein Gang lässt sich löschen (Wischen in der Übersicht oder „Gang löschen“ im Detail, jeweils mit Rückfrage): seine festen Kategorien werden offen, Stichwörter fallen weg; ist er eine eigene Kategorie, gilt das Löschen aus #85 (Artikel zurück auf automatische Kategorie, Merkungen und Wegzuordnung weg); ein Gang mit festem Namen lässt Artikel bei ihrer festen Kategorie und vergisst Merkungen auf diesen Namen. (S6, V6)
- [x] **AC-11:** Das Löschen des letzten Gangs wird zu „Gänge entfernen“ (Rückfrage); danach ist der Laden ohne Gänge (`hasStations == false`), eigene Kategorien und Merkungen bleiben, und die Ansicht zeigt nur „Vorlage wählen …“ und „Gang hinzufügen“. (S8, V8)
- [x] **AC-12:** Nach jeder Operation gelten die Invarianten: Gang-Namen eindeutig und nie „Sonstiges“/Marke, jede Angabe in `categoryOrder`, keine feste Kategorie in zwei Gängen, `hidden` und `builtIns` überschneidungsfrei, Name-gebundene Kategorien im eigenen Gang. (S9)
- [x] **AC-13:** „Vorlage wählen …“ → „Lidl“ ersetzt die Gänge dieses Ladens nach der Rückfrage durch die Lidl-Vorlage (Zeitstempel jetzt, Gang-Namen als eigene Kategorien); Artikel, Merkungen und vorhandene eigene Kategorien bleiben unberührt. (S12, V8)
- [x] **AC-14:** Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern (`LocalizationKeyParityTests` grün); in geteilten Läden erscheint die Hinweiszeile „Gänge bleiben bis zum Abgleich auf diesem Gerät.“ (S13)
- [x] **AC-15:** Läden ohne Gänge verhalten sich unverändert (Menü ausgenommen: dort der neue Einstieg); es gibt keine Schemaänderung, kein neues `@Model`-Feld und keinen neuen `@AppStorage`-Schlüssel; alle D1-Tests außer den bewusst ersetzten U6/U7 und alle Bestandstests bleiben grün. (Regression: Gesamtlauf)

## Dialog

### Runde 1
**Adversary:** Beweis je AC aus Code und eigenen Läufen (Unit 788/0 in adversary-test-output.txt; UI StoreStationsUITests 14/0 in adversary-ui-output.txt).

Confirmation:
  AC: AC-1
  Code reference: SmartCart/Views/Store/StoreDetailView.swift:630
  Evidence: stationMenuItem ist ein einziger unbedingter Button (store.menu.setupStations); die D1-Einträge und -Dialoge sind entfernt, keine Treffer für applyStationTemplate oder removeStations im Produktcode. V1 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: SmartCart/Views/Store/StoreDetailView.swift:279
  Evidence: Sheet mit StationSetupView, onDismiss zählt reorderTick. Übersicht mit Vorlage, Gänge, Offen, Ausgeblendet, Gänge entfernen in fester Leiste (gebilligte Abweichung, erreichbar, V8 grün); Detail per NavigationLink; Fertig = dismiss. V1 und V2 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: SmartCart/Models/Store.swift:424
  Evidence: renameStation zieht Konfiguration (Reihenfolge per Index), eigene Kategorie (alter Eintrag Löschvermerk, neuer über applyStationConfig), Merkungen, Handwahl-Artikel, routeModel.renameCategory und bumpRouteRevision. S1 und V2 grün. Beobachtung F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: SmartCart/Models/Store.swift:441
  Evidence: Schleife über currentTrip.entries mit Zurückschreiben des Wrappers; S11 grün (Abschluss lernt nur den neuen Namen).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: SmartCart/Models/StoreCategories.swift:349
  Evidence: renamingStation lässt nur .new oder .existing(gleicher Gang) zu, alles andere nil; addingStation nur bei .new. Store.renameStation gibt dann nil ohne Änderung zurück (Guard vor jeder Schreibung). S2, S3, V3 grün; Hinweis im Detail rot (StationSetupView.swift:416). Anlegen-Ablehnung nur über zweiten Alert (F003, ungetestet).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: SmartCart/Views/Store/StationSetupView.swift:108
  Evidence: onMove ruft movingStations, updateStationConfig (bumpt Route) und changed() (context.save). Zielindex-Rechnung StoreCategories.swift:365 entspricht Array.move. S7 und V7 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: SmartCart/Views/Store/StationSetupView.swift:227
  Evidence: addStation nimmt stationConfig oder eine leere Konfiguration, hängt am Ende an, speichert; funktioniert ohne Gänge. S8 und V6 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: SmartCart/Models/StoreCategories.swift:325
  Evidence: categoryState folgt der Reihenfolge von stationForCategory (Namensbindung, hidden, builtIns, offen); assigning, hiding und opening lösen aus allen Gängen und hidden (adopting und releasing, Zeilen 411 und 420). S4, S5, V4, V5 grün. V5-Kürzung berechtigt: nach dem Ausblenden hat Drogerie keine offenen Artikel, die Überschrift entfällt (U1); V5 verlangt laut Spec nur Batterien unter Sonstiges, das prüft die verbleibende Zeile weiter.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: SmartCart/Views/Store/StationSetupView.swift:473
  Evidence: Zeile im Detail ist disabled bei Namensbindung, Untertitel gehört zu Gang; die Übersicht listet name-gebundene nie unter Offen oder Ausgeblendet (categoryState liefert assigned); assigning, hiding, opening liefern nil (StoreCategories.swift:379 und 411). S10 grün. Einschränkung F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: SmartCart/Views/Store/StationSetupView.swift:101
  Evidence: Wischen-Löschen existiert in der Übersicht (swipeActions, Rückfrage in StationSetupDialogs ab Zeile 288) und Gang löschen im Detail (Zeile 378, Rückfrage). Folgen: Store.deleteStation (Store.swift:455) = eigene Kategorie nach #85 oder Merkungen vergessen. S6 und V6 grün. Wischen selbst hat keinen UI-Test (Lücke, kein Bruch).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: SmartCart/Views/Store/StationSetupView.swift:244
  Evidence: delete() ruft bei höchstens einem Gang removeStations (Rückfrage vorher in beiden Wegen); Leiste und Sortieren hängen an hasStations, der Vorlage-Abschnitt erscheint bei config == nil. S8 und V8 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: SmartCart/Models/StoreCategories.swift:420
  Evidence: Alle Mutationen laufen über resolveStation, adopting, releasing; S9 prüft 25 Operationen mit Ablehnungen. Lücke nur im Store-Layer (eigene Kategorie), nicht in der Konfiguration (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: SmartCart/Views/Store/StationSetupView.swift:265
  Evidence: confirmationDialog mit Lidl ruft applyStationConfig(lidlTemplate) (Zeitstempel, Eigenkategorien), Artikel und Merkungen unberührt. S12 und V8 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: SmartCart/Views/Store/StationSetupView.swift:89
  Evidence: Alle im Code benutzten Schlüssel sind in de und en vorhanden (eigener Abgleich, 0 fehlend); 32 station.setup-Zeilen je Sprache; Hinweiszeile als Fußzeile bei shareID ungleich nil. S13 und LocalizationKeyParityTests im 788er Lauf grün. Hinweiszeile selbst ohne Test (bekannt).
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: SmartCart/Models/Store.swift:416
  Evidence: updateStationConfig delegiert an das bestehende applyStationConfig; kein neues Feld, kein AppStorage in StationSetupView; MirroredSchemaSnapshotTests und gesamte Unit-Suite 788/0, UI-Klasse 14/0 (U1 bis U5, U8 und D1-Tests unverändert grün).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: SmartCart/Models/Store.swift:468
  Description: ensureCustomCategory prüft categoryOrder.contains(name) exakt (Groß-/Kleinschreibung, Akzente), während StoreCategories.builtInCategory(named:) (StoreCategories.swift:333) und stationNamed über compareKey vergleichen. Legt der Nutzer einen Gang "tierbedarf" oder "Getranke" an (oder benennt so um), übernimmt der Gang die feste Kategorie Tierbedarf bzw. Getränke (builtIns), bekommt aber zusätzlich eine eigene Kategorie gleichen Namens.
  Spec requirement: AC-9 und S3 — Gang mit Namen einer festen Kategorie übernimmt sie, ohne dass eine eigene Kategorie entsteht (S3: keine eigene Kategorie angelegt).
  Conflict: Test S3 (RestockTests/StoreStationsTests.swift:667-671) prüft die Store-Seite nur mit exakter Schreibweise "Tierbedarf"; die Kleinschreib-Variante ist nur auf Konfigurationsebene (Zeile 678) geprüft. Folge: doppelte Kategorie (fest und eigene) in der Kategorie-Auswahl nach Gänge entfernen; Löschen des Gangs nimmt dann den Zweig eigene Kategorie (Merkungen auf den festen Namen bleiben).
  Remediation: In ensureCustomCategory zusätzlich StoreCategories.builtInCategory(named: name) == nil verlangen; Store-Test mit "tierbedarf".

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/Store.swift:424
  Description: Bei reinem Emoji-Wechsel (Name gleich) kehrt renameStation nach updateStationConfig zurück; der Eintrag der eigenen Kategorie behält das alte Emoji (ensureCustomCategory überschreibt vorhandene nicht, Zeilen 468-474).
  Spec requirement: AC-3 — Umbenennen und neues Emoji; eigene Kategorie unter dem neuen Namen.
  Conflict: Abschnittsüberschriften nutzen das Gang-Emoji (StoreDetailView.swift:206) und sind korrekt; die eigene Kategorie (Auswahl nach Gänge entfernen, categoryEmoji) zeigt weiter das alte Emoji. Kein Test.
  Remediation: Bei Emoji-Änderung customCategoryEntries[name] mit neuem Emoji und Datum schreiben.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Views/Store/StationSetupView.swift:57
  Description: Die Ablehnung beim Anlegen (Gang hinzufügen) läuft über einen zweiten alert (addRejected), der im Button-Handler des ersten Alerts gesetzt wird (Zeilen 227-236). Zwei Alerts am selben View kurz hintereinander sind ein bekanntes SwiftUI-Risiko (zweiter erscheint nicht). Weder UI- noch Unit-Test deckt Dublette oder Sonstiges im Alert-Weg ab; V3 testet nur Umbenennen im Detail.
  Spec requirement: AC-5 — Anlegen abgelehnt, Hinweis sichtbar.
  Conflict: Nicht bewiesen, dass der Hinweis wirklich erscheint (Logik lehnt ab, Anzeige ungeprüft).
  Remediation: UI-Test Gang hinzufügen mit Name Käse erwartet Hinweis; ggf. Hinweis als Zeile statt zweitem Alert.

**Implementierer:** (nicht befragt; Antwort auf F001 bis F003 steht aus)

### Runde 2
**Adversary:** Zweiter Angriff gezielt auf Sprachgrenzen, Zustandsübergänge und Lücken der Belege.
- Wischen-Löschen (AC-10) ausdrücklich geprüft: vorhanden (StationSetupView.swift:101), mit Rückfrage; ungetestet.
- Letzter Gang per Wischen: delete() (StationSetupView.swift:244) wählt removeStations; der Bearbeiten-Modus wird dabei nicht zurückgesetzt, ist aber nicht erreichbar (Wischen im Bearbeiten-Modus unterdrückt, Spec Offenlegung 3), und Sortieren verschwindet mit hasStations.
- Umbenennen eines Gangs mit festem Namen (Getränke zu Trinken): Handwahl-Artikel mit fester Kategorie werden per Spec-Schritt 5 auf den neuen eigenen Namen umgeschrieben (Store.swift:437); nach Gänge entfernen stünden sie in einer eigenen statt der festen Kategorie. Von der Spec so verlangt, nur Hinweis.
- Gang-Detail: Namensänderung beim Verlassen (onDisappear, StationSetupView.swift:390) mit deleted-Wächter; Löschen im Detail speichert, dann dismiss; kein Doppelzugriff.
- Speichern: jede Änderung endet in changed() mit context.save (StationSetupView.swift:109-111, 224, 239); Vorlage- und Entfernen-Dialoge rufen onChange (270, 282).
- V5-Kürzung (red-notizen Punkt 4) nachvollzogen: berechtigt, siehe AC-8.
- Regression: 788 Unit-Tests ohne Fehler; die Ausgabedatei enthält nach TEST SUCCEEDED noch die Zeile "Testing started" (xcodebuild-Ausgabe, unverändert gelassen).
- Nicht belegt: Bildschirmfoto (Anhänge entstehen nur bei Fehlern; keins erzeugt), Hinweiszeile geteilter Läden, gesperrte Zeile gehört zu Gang im UI (bekannt ohne Test; Code gelesen: StationSetupView.swift:473 und 480).
**Implementierer:** (nicht befragt)


### Runde 3
**Adversary:** Nachprüfung der Fixes und neuer Angriff.
- F001 behoben: Store.swift:473-481 ensureCustomCategory prüft StoreCategories.builtInCategory(named:) == nil (compareKey, gleiche Vergleichsart wie stationNamed). "tierbedarf" und "Getranke" legen keine eigene Kategorie mehr an. Löschen des Gangs nimmt den Zweig fester Name (nur Merkungen vergessen). S14 grün.
- F002 behoben: Store.swift:438-442 schreibt bei geändertem Emoji den Eintrag der eigenen Kategorie neu; bei Gang mit festem Namen (keine eigene Kategorie) übersprungen, kein Eintrag erzeugt. S15 grün.
- F003: V9 grün im eigenen Lauf (Hinweis erscheint beim Anlegen von "käse"). Ansicht unverändert (StationSetupView.swift:57).
- Neuer Angriff fest, eigen, fest: Gang "Getränke" nach "Trinken" (eigene Kategorie Trinken, Handwahl-Artikel umgeschrieben), dann "Trinken" nach "getränke". Der Gang übernimmt Getränke, ensureCustomCategory legt nichts an, aber Store.swift:445 schreibt Handwahl-Artikel und Merkungen von "Trinken" auf die Schreibweise "getränke". Im Gang-Modus greift das (stationNamed über compareKey). Nach Gänge entfernen wäre die Artikel-Kategorie "getränke" weder fest noch eigene Kategorie. Siehe F004.
- Emoji-Wechsel bei Gang mit festem Namen ohne eigene Kategorie: kein Absturz, kein Eintrag, Gang-Emoji in Überschriften korrekt (StoreDetailView.swift:206).
- Regression: Unit 790/0 (adversary-test-output.txt; xcodebuild druckt nach TEST SUCCEEDED noch "Testing started"). UI V9, V2, V3 3/0 (adversary-ui-output.txt). Bildschirmfoto nicht erzeugt.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/Store.swift:445
  Description: Umbenennen eines eigenen Gangs auf eine abweichende Schreibweise eines festen Kategorienamens (z. B. Trinken nach getränke) schreibt item.category und Merkungen auf die getippte Schreibweise "getränke" statt auf den Rohwert "Getränke".
  Spec requirement: AC-12 — Name-gebundene Kategorien bleiben konsistent; kein Artikel rutscht nach Sonstiges.
  Conflict: Im Gang-Modus korrekt (compareKey), nach Gänge entfernen steht die Artikel-Kategorie "getränke" außerhalb von categoryOrder und eigenen Kategorien. Randfall, Spec-Schritt 5 kennt ihn nicht. Nur per Code-Analyse, nicht ausgeführt.
  Remediation: Beim Umbenennen den kanonischen Namen (builtInCategory(named:) ?? new) für Artikel und Merkungen verwenden.

**Implementierer:** (Antwort auf F004 steht aus)


### Runde 4
**Adversary:** Nachprüfung F004 und neuer Angriff.
- F004 behoben: Store.swift:443-452 schreibt Artikel und Merkungen mit builtInCategory(named: new) ?? new und sucht nach altem Gang-Namen und dessen Rohwert (oldValues). Weg und Sitzung behalten den Gang-Namen (richtig, recordCheckOff speichert Gang-Namen). Ablehnungsfälle laufen unverändert vor jeder Schreibung (StoreCategories.swift:349). S16 grün.
- Erneutes Umbenennen "getränke" nach "Trinken": oldValues = {getränke, Getränke}, Artikel mit Rohwert Getränke ziehen mit; kein Verlust. Rohwert-Treffer per compareKey bei eigenem Namen (z. B. Käse): builtInCategory liefert nil, Verhalten wie vorher.
- Neuer Fund F005: Löschen eines Gangs mit abweichender Schreibweise eines festen Namens ("getränke"): deleteStation (Store.swift:460-470) vergisst nur Merkungen mit Wert gleich dem Gang-Namen. Seit F004 stehen Merkungen aber mit Rohwert "Getränke". Sie bleiben stehen und würden einen später gleich benannten Gang wiederbeleben, was die Spec ausdrücklich verhindern will (AC-10). Nur per Code-Analyse.
- Regression: Unit 791/0 (adversary-test-output.txt, TEST SUCCEEDED); gesamte UI-Klasse StoreStationsUITests 15/0 (adversary-ui-output.txt). UI-Ansicht unverändert (StationSetupView.swift:57, StoreDetailView.swift:630).

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/Store.swift:464
  Description: deleteStation vergleicht Merkungen mit dem gespeicherten Gang-Namen (stored). Bei einem Gang mit abweichender Schreibweise eines festen Namens (getränke) tragen Merkungen nach F004-Fix und bei Anlage über die Auswahl den Rohwert Getränke; sie werden nicht vergessen.
  Spec requirement: AC-10 — Gang mit festem Namen vergisst Merkungen auf diesen Namen.
  Conflict: Merkung bleibt als Getränke stehen; ein später angelegter Gang Getränke erbt sie. Folgenarm (Merkung ist im Klassikmodus ohnehin gültig).
  Remediation: Beim Vergessen auch builtInCategory(named: stored) berücksichtigen (oder per compareKey vergleichen).

**Implementierer:** (Antwort auf F005 steht aus)

### Runde 5
**Adversary:** Nachprüfung F005.
- Behoben: Store.swift:464-476 deleteStation vergisst im Zweig fester Name Merkungen mit dem gespeicherten Gang-Namen oder dessen Rohwert (builtInCategory(named: stored)), gleiches Muster wie renameStation. Der Zweig eigene Kategorie (deleteCustomCategory, Store.swift:468-469) ist unverändert; Handwahl-Artikel mit fester Kategorie werden im Zweig fester Name nicht angefasst (keine Artikel-Schleife), wie AC-10 verlangt. S17 grün.
- Nachbarschaft: StoreCategories.deletingStation (StoreCategories.swift:398) lässt builtIns frei (offen); die Ansicht ruft bei letztem Gang weiter removeStations (StationSetupView.swift:244); Menüeinstieg unverändert (StoreDetailView.swift:630).
- Hinweis, kein Befund: Beim Löschen eines Gangs mit festem Namen werden auch Merkungen vergessen, die im Klassikmodus mit dem Rohwert gesetzt wurden. Das entspricht dem Spec-Text "vergisst Merkungen auf diesen Namen".
- Regression: Unit 792/0 (adversary-test-output.txt, TEST SUCCEEDED). UI-Klasse in Runde 4 15/0, von F005 (nur Modell) nicht berührt, keine Neuausführung.

**Implementierer:** F001 bis F005 bearbeitet.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Alle 15 ACs belegt. Unit 792/0, UI-Klasse StoreStationsUITests 15/0. F001 bis F005 behoben und mit Tests nachgewiesen, keine offenen Befunde. Code reference: SmartCart/Models/StoreCategories.swift:398 und SmartCart/Views/Store/StationSetupView.swift:244 und SmartCart/Views/Store/StoreDetailView.swift:630.

## Geprüfte Dateien

- sha256:d7b572d83e44b47caf556a15d629b0942ea60e32b0849a5d2640fc7b634ae5a9  SmartCart/Models/Store.swift
- sha256:9c38f9417855a137b30a8aa3f8e5e32f1d98f0215b82b66c10353d76dc9e0ac9  SmartCart/Models/StoreCategories.swift
- sha256:733f56ae9c35b9f5b6afaf7eacb22fca3608af49a7e1f8170178f4d99062c460  SmartCart/Views/Store/StationSetupView.swift
- sha256:2c3acf15d65883902b18a3f6b9ebeab5e43159fddc97dd0d24210797795564af  SmartCart/Views/Store/StoreDetailView.swift

## Prüfbasis

- base: e0faa4e974730ac0d51d04409d41f5ffed0187cf
- blob:d5f693a5f836b8029856cc05a482c8e1ed52ad86  SmartCart/Models/Store.swift
- blob:2b063f6d7f571e3a7dcd5947671fb28b98c01993  SmartCart/Models/StoreCategories.swift
- blob:306f182a2e98b5e4d0a7bff514da2f2bdd028bec  SmartCart/Views/Store/StationSetupView.swift
- blob:68dd3f3057195a5f877f9264276966c2c84fa745  SmartCart/Views/Store/StoreDetailView.swift
