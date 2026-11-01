# Context: feat-234-d2b2-picker-uebernahme (Issue #234, Durchgang 2b-2)

## Request Summary
Zweiter Teil von Durchgang 2b nach PO-Entscheidung vom 2026-11-01 (Issue-Kommentar, Entwurf
`docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html`, Abschnitte 4 und 5,
jeweils die Empfehlung freigegeben): (a) Wischen „Bearbeiten“ (Name, Emoji) und „Löschen“ auf den
Gang-Zeilen der Kategorie-Auswahl beim Artikel, Löschen mit Rückfrage, beim letzten Gang „Gänge
entfernen?“; (b) Abschnitt „Eigene Kategorien von früher“ in „Kategorien einrichten“, nur wenn es
welche gibt, je Zeile „Übernehmen“ (→ Gang am Ende), dazu „Alle übernehmen“; zugeordnete Artikel
stehen sofort im neuen Gang; (c) die vier vorgemerkten UI-Tests aus 2a: Löschen per Wischen in der
Übersicht, Untertitel „gehört zu Gang …“, Emoji-Auswahl, Hinweis in geteilten Läden. Schätzung
~480 Zeilen mit Tests. Kein neues Datenfeld, kein iCloud-Schritt. Einzahl „1 Kategorie“ ist mit
2b-1 schon erledigt (`StationSetupRow.summaryText`).

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Views/Store/CategoryPickerView.swift` (313) | `stationSections` zeigt Gänge nur zum Antippen (Z. 109–130); in Läden ohne Gänge haben eigene Kategorien schon Wischen Bearbeiten/Löschen (Z. 152–164) mit `CustomCategoryEditor` und `confirmationDialog` → Muster für (a). `CustomCategoryEditor` ruft `store.updateCustomCategory`, für Gänge falsch (muss `renameStation`). |
| `SmartCart/Views/Store/StationSetupView.swift` (762) | Übersicht, Abschnitte `stationSection`/`openSection`/`hiddenSection` (Z. 37–39) → Ort für (b). `static delete(_:in:)` und `static deleteDialog(for:in:)` (Z. 244–262) sind schon wiederverwendbar für (a). Wischen-Löschen in der Übersicht Z. 101–105 (Kennung `stationSetup.row.delete.<Name>`), `sharedHint` Z. 89–93 (`stationSetup.sharedHint`, nur bei `store.shareID != nil`), Untertitel „gehört zu/in Gang …“ `subtitle(state:bound:)` Z. 578–590, `StationEmojiGrid` Z. 735ff. Datei ist schon groß; Übernahme-Abschnitt eher als eigene View-Struktur. |
| `SmartCart/Models/Store.swift` | `customCategories` (Z. 543), `applyStationConfig` legt jeden Gang-Namen als eigene Kategorie an (`ensureCustomCategory`, Z. 380–386), `addStation`, `renameStation` (zieht Merkungen, Artikel, Weg, Sitzung mit), `deleteStation` (löscht eigene Kategorie gleichen Namens), `removeStations` (lässt eigene Kategorien liegen), `rememberCategory`, `rememberedCategory`, `categoryEmoji`. |
| `SmartCart/Models/StoreCategories.swift` | Reine Logik: `station(forItemNamed:category:manuallySet:remembered:config:)` — Merkung mit Gang-Namen und von Hand gesetzte Kategorie mit Gang-Namen treffen über `stationNamed` (compareKey). `addingStation(_:emoji:to:)` (lehnt Namen ab, die schon Gang/„Sonstiges“ sind). Ort für eine neue reine Funktion „frühere eigene Kategorien“ und „übernehmen“. |
| `SmartCart/SmartCartApp.swift` | DEBUG-Seeds `-seedStationStoreForUITests`/`-clearStationStoreForUITests` (Z. 404–430). Für (b) braucht es einen Seed mit eigener Kategorie samt Artikel bzw. Merkung, für den Hinweis in geteilten Läden einen mit `shareID`. |
| `RestockUITests/StoreStationsUITests.swift` (857, 16 Tests, CI-Teil C ~49 min) / `RestockUITests/StationSetupExtrasUITests.swift` (425, 3 Tests, CI-Teil D 24 min) | Neue UI-Tests gehören nach D (oder in eine neue Klasse, die dann eine Liste in `.github/workflows/ci.yml` braucht, sonst landet sie in B). |
| `RestockTests/StoreStationsTests.swift` | Unit-Tests T/S/K; neue Logik dort. |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | neue Schlüssel; `LocalizationKeyParityTests` erzwingt Gleichstand. |

## Existing Patterns
- Wischaktionen auf Listenzeilen: `.swipeActions(edge: .trailing)` mit destruktivem „Löschen“ und
  indigo „Bearbeiten“ (CategoryPickerView Z. 152–164).
- Löschen eines Gangs immer über `StationSetupView.delete`/`deleteDialog` (letzter Gang → Gänge
  entfernen, AC-11 aus 2a).
- Logik als reine `static func` in `StoreCategories`, Schreiben über `Store`-Methoden, die
  `updateStationConfig` nutzen (Zeitstempel, Weg-Version).
- UI-Tests: Seed + gleichnamiger Aufräumer im `tearDown()`, `UITestWait`-Helfer, `UITestLaunch.start`.
- Durchlauf-Nachweis per XCTAttachment-Fotos (Memory `issue-234-d2a-umfang-akzeptiert`).

## Dependencies
- Upstream: `StationConfig`/`Station`, `Store.customCategoryEntries`, `categoryAssignments`,
  `ShoppingItem.category`/`categoryManuallySet`.
- Downstream: Die Kategorie-Auswahl hängt in `AddItemView` und `EditItemView` (eigenes
  Picker-Binding, merkt die Wahl). Ein Löschen/Umbenennen aus der Auswahl ändert die `selection`
  des offenen Dialogs, die danach gespeichert wird.

## Existing Specs
- `docs/specs/models/store-stations.md` (D1), `docs/specs/views/station-setup.md` (D2a),
  `docs/specs/views/station-templates-keywords.md` (2b-1). 2b-2 braucht eine eigene Spec (z. B.
  `docs/specs/views/station-picker-adoption.md`), die alten sind gesperrt.

## Risks & Considerations
- **„Von früher“ ist nicht dasselbe wie „eigene Kategorie, die kein Gang ist“.** `applyStationConfig`
  legt jeden Gang-Namen als eigene Kategorie an, `removeStations` und das Ersetzen per Vorlage lassen
  sie liegen. Nach Lidl → Discounter stünden „Backstation“ usw. als „frühere eigene Kategorien“ da.
  Die Analyse muss festlegen, welche Kategorien gezeigt werden (z. B. nur mit Artikeln/Merkungen,
  oder Gang-Namen beim Ersetzen löschen, oder hinnehmen). Kein neues Datenfeld erlaubt.
- Übernahme braucht keine Datenmigration: Merkung und von Hand gesetzte Kategorie mit dem Namen
  treffen den neuen Gang über `stationNamed`. Name-Kollision mit vorhandenem Gang, „Sonstiges“ oder
  einer festen Kategorie muss geprüft werden (`addingStation` übernimmt bei festem Namen die feste
  Kategorie).
- Bearbeiten in der Auswahl muss `renameStation` nutzen (nicht `updateCustomCategory`), und die
  `selection` des Dialogs auf den neuen Namen setzen; Löschen des gewählten Gangs → Rückfall der
  Auswahl festlegen (Sonstiges-Marke oder automatische Kategorie).
- Hinweis in geteilten Läden: Seed mit `shareID` könnte den Abgleich mit der öffentlichen
  CloudKit-Datenbank anstoßen; vorhandener Präzedenzfall `store.shareID = "444-RU8"`
  (SmartCartApp Z. 241–256, Screenshot-Seed) prüfen.
- CI-Zeit: Teil C ~49 min, Teil D 24 min → neue UI-Tests nach D.
- `StationSetupView.swift` ist mit 762 Zeilen groß; Funktionen ≤ 50 Zeilen einhalten.

## Analysis

### Type
Feature (Durchgang 2b-2 von #234; Entwurf Empfehlungen 4 und 5 vom PO am 2026-11-01 freigegeben, keine neue Vorschau nötig)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreCategories.swift` | MODIFY | reine Funktion `adoptableCategories(custom:config:used:templateNames:)` (Regel R3, Vergleich über `compareKey`), `templateStationNames` aus `StoreTemplates.allTemplates` (+ `lidlTemplate` zur Sicherheit) |
| `SmartCart/Models/Store.swift` | MODIFY | `adoptableCategories` (Nutzung aus `items` offen+erledigt und Werten in `categoryAssignments`), `adoptCategory(_:) -> String?` über `addingStation(name, emoji: categoryEmoji(name), …)` (eigenes Emoji behalten, NICHT `addStation` mit `suggestedEmoji`), `adoptAll()` mit genau einem `updateStationConfig` |
| `SmartCart/Views/Store/CategoryPickerView.swift` | MODIFY | Wischen „Bearbeiten“/„Löschen“ auf Gang-Zeilen (`stationSections`), Muster Z. 152–164; `CustomCategoryEditor` mit Gang-Modus → `renameStation` (Ergebnis `nil` = abgelehnt, Meldung `station.setup.name.rejected`); Löschen über `StationSetupView.deleteDialog`/`.delete` (letzter Gang → „Gänge entfernen?“); Auswahl nachziehen (siehe Risiken) |
| `SmartCart/Views/Store/AddItemView.swift`, `EditItemView.swift` | MODIFY (klein) | Rückfall-Gang für den Picker nach Löschen des gewählten Gangs (Closure `automaticStation`) |
| `SmartCart/Views/Store/StationAdoptionSection.swift` | CREATE | Abschnitt „Eigene Kategorien von früher“ mit „Übernehmen“ je Zeile und „Alle übernehmen“; in `project.pbxproj` registrieren |
| `SmartCart/Views/Store/StationSetupView.swift` | MODIFY (klein) | Abschnitt einhängen nach `hiddenSection`, nur wenn Liste nicht leer; Kennungen für Untertitel „gehört zu Gang …“ und Emoji-Raster, falls Tests sie brauchen |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Seeds `-seedLegacyCustomCategoriesForUITests` (Gänge + „Asia-Regal“ mit von Hand zugeordnetem Artikel + ungenutzte Vorlagen-Altlast) und `-seedStationStoreSharedForUITests` (`shareID` = unwahrscheinliche Kennung `UITEST-NOSHARE`, nicht „444-RU8“); Aufräumen über `-clearStationStoreForUITests` (löscht alle Läden) |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | MODIFY | neue Schlüssel (Abschnitt, Übernehmen, Alle übernehmen, Wischaktionen) |
| `RestockTests/StoreStationsTests.swift` | MODIFY | Unit-Tests R3-Regel, Übernahme, Kollisionen, Emoji bleibt, Alle übernehmen = ein Schreibvorgang |
| `RestockUITests/StationSetupExtrasUITests.swift` | MODIFY | vier nachgeholte Tests aus 2a + Picker-Wischen (Umbenennen/Löschen, Auswahl konsistent) + Übernahme; bleibt in CI-Teil D (`EXTRA_CLASSES`), keine ci.yml-Änderung |
| `docs/specs/views/station-picker-adoption.md` | CREATE | eigene Spec (2a- und 2b-1-Specs gesperrt) |

### Scope Assessment
- Files: 11 + pbxproj + Spec
- Estimated LoC: ca. +525 (davon ~250 Tests, ~35 Seeds) — knapp über der PO-Schätzung ~480; PO hat 2b-2 als ein Stück beschlossen, bleibt ein Durchgang
- Risk Level: MEDIUM — Auswahl-Binding in Add/Edit beim Umbenennen/Löschen des gerade gewählten Gangs; sonst additive Logik, kein neues Datenfeld, kein iCloud-Schritt

### Kernbefund: Herkunft eigener Kategorien nicht gespeichert
`applyStationConfig`/`updateStationConfig`/`addStation` legen jeden Gang-Namen per `ensureCustomCategory` als eigene Kategorie an; Vorlage ersetzen und `removeStations` löschen sie nicht. „Vom Nutzer angelegt“ vs. „aus Gang entstanden“ ist ohne neues Feld nicht unterscheidbar (`CustomCategoryEntry` hat nur emoji/date). Regelvarianten:

| | Regel | „Asia-Regal“ (#85, ohne Artikel) | Lidl → Discounter | Gänge entfernt, neu eingerichtet |
|---|---|---|---|---|
| R1 | alle eigenen Kategorien, die kein Gang sind | erscheint | ~10 Lidl-Gang-Namen als Altlast | alte Gang-Namen als Altlast |
| R2 | nur mit Nutzung (Artikel/Merkung) | verschwindet (falsch) | sauber | sauber |
| **R3** | **Name in keiner Vorlage ODER genutzt** | **erscheint** | **sauber; genutzte erscheinen** | **sauber** |
| R4 | Vorlage-Ersetzen löscht ungenutzte Gang-Kategorien | erscheint | sauber | greift nicht ohne Änderung an `removeStations` |
| R5 | neues Herkunftsfeld | exakt | exakt | exakt — vom PO ausgeschlossen (kein neues Feld, Schema-Schritt) |

Entscheidung (Tech Lead): **R3**. Grenze: eine ungenutzte eigene Kategorie, die zufällig wie ein Vorlagen-Gang heißt, erscheint nicht (hinnehmbar, sie trägt nichts). Alle Varianten sind Regeln, kein Modell nötig.

### Technical Approach
1. Spec, dann Unit-Tests RED für `adoptableCategories`/`adoptCategory`/`adoptAll`.
2. Logik in `StoreCategories` (rein) und `Store` (Schreiben über `updateStationConfig`). Übernahme braucht keine Datenwanderung: Merkungen und von Hand gesetzte Artikel-Kategorien treffen den neuen Gang über `stationNamed`.
3. Picker-Wischen mit Auswahl-Nachziehen:
   - Umbenennen: `if selection == old { selection = new }` — sonst überschreibt `EditItemView.applyCategory` das umbenannte `item.category` mit dem alten Wert (echter Fehler, wenn vergessen).
   - Löschen eines Gangs (nicht letzter): Auswahl auf den Gang, der automatisch gälte (`stationName(forItemNamed:…)`), sonst Sonstiges-Marke — nicht `automaticCategory`, sonst `categoryManuallySet = true` im Add-Pfad.
   - Letzter Gang gelöscht (Laden ohne Gänge): `selection = automaticCategory`.
4. Abschnitt „Eigene Kategorien von früher“ als eigene Struktur (StationSetupView ist 762 Zeilen, Funktionen ≤ 50).
5. Seeds, UI-Tests, `LocalizationKeyParityTests`.

### Alternativen
- **A — R1 ohne Vorlagen-Filter**, dafür Wischen-Löschen in „von früher“: einfacher, aber nach jedem Vorlagenwechsel eine lange Altlastenliste; widerspricht „nur wenn es welche gibt“.
- **B — Zuschnitt:** Übernahme (b) in eigenen Durchgang 2b-3, nur (a)+(c) jetzt; spart die Regelfrage, kippt aber den PO-Zuschnitt vom 2026-11-01.
- **C — Herkunftsfeld (R5):** exakt und behebt nebenbei, dass `ensureCustomCategory` eine gelöschte Gang-Kategorie beim nächsten `updateStationConfig` neu anlegt; kippt den Beschluss „kein neues Feld, kein iCloud-Schritt“.

### Dependencies
- Upstream: `StationConfig`/`Station`, `StoreCategories.addingStation`/`stationNamed`/`compareKey`, `StoreTemplates.allTemplates`, `Store.renameStation`/`deleteStation`/`removeStations`, `StationSetupView.delete`/`deleteDialog`.
- Downstream: `AddItemView`/`EditItemView` (Picker-Binding, Speichern), `StoreDetailView`-Gruppierung (liest Gang je Artikel), Sync geteilter Läden (`categoriesJSON` trägt eigene Kategorien, nicht die Gänge — Liste „von früher“ kann je Gerät abweichen, hinnehmbar bis D3).

### Risiken
- Seed mit `shareID`: `StoreDetailView` stößt `SyncCoordinator.pull` an; ohne Datensatz nur Fehler-Banner, kein Schreiben. Deshalb unwahrscheinliche Kennung `UITEST-NOSHARE`, im Test nichts, was einen Push auslöst. Nur aus dem Code begründet.
- Löschen eines übernommenen Gangs löscht die eigene Kategorie mit (Bestandsverhalten von `deleteStation`) — in der Spec benennen.
- CI-Teil D: von 3 auf ~9 Tests, geschätzt < 45 min (Limit 60).
- Neue Swift-Datei muss in `project.pbxproj` eingetragen werden.

### Open Questions
- keine (Zuschnitt und Entwurf vom PO am 2026-11-01 entschieden; R3 und Auswahl-Rückfall sind technische Entscheidungen)
