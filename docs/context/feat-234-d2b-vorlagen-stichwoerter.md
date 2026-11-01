# Context: feat-234-d2b-vorlagen-stichwoerter

## Request Summary
Issue #234, Durchgang 2b („Kategorien einrichten“, zweiter Teil). PO-Zuschnitt vom 2026-10-31: vier Mustervorlagen
(Discounter, Vollsortimenter, Drogerie, Baumarkt; Kennzeichen „Vorschlag, bitte prüfen“), Stichwörter je Gang
bearbeiten, Wischaktionen in der Kategorie-Auswahl in Läden mit Gängen, Übernahme alter eigener Kategorien (#85).
Dazu aus der Validierung von 2a: Einzahl „1 Kategorie“ in der Gang-Zeile und UI-Tests für Wisch-Löschen in der
Übersicht, „gehört zu Gang …“, Emoji-Auswahl und den Hinweis bei geteilten Läden. PO-Schätzung ca. 400–450 Zeilen.

## Related Files
| File | Relevance |
|------|-----------|
| `SmartCart/Models/StoreCategories.swift` (428 Z.) | `Station` (177–182: name, emoji, builtIns, keywords), `StationConfig` (186–190: stations, hidden, date), `lidlTemplate` (272–310, 12 Gänge, Baumarkt-Kategorien hidden), Auflösung `station(forItemNamed:…)` (202), `stationForKeywords` (234, Wort gleich/endet auf, längstes gewinnt), Bearbeitungsfunktionen (`addingStation` 340, `renamingStation` 349 – behält keywords, `movingStations` 365, `assigning` 379, `hiding`/`opening`/`releasing` 386–417, `deletingStation` 398), `emojiChoices` (31–36, 48 Emojis, ohne 🏬/🔨), `normalizedName` (79). **Keine Funktion zum Hinzufügen/Entfernen von Stichwörtern.** |
| `SmartCart/Views/Store/StationSetupView.swift` (562 Z.) | Übersicht (10–262), Vorlagen-Dialog in `StationSetupDialogs` (265–317, nur Eintrag „Lidl“, Kennung `stationSetup.templateLidl`), `sharedHint` (88–94, bei `store.shareID != nil`), `StationSetupRow` (320–338, `station.setup.row.summary` ohne Einzahl), `StationDetailView` (358–532, Stichwörter nur lesend 408–414, Emoji-`DisclosureGroup` + `StationEmojiGrid` 432–442/535–562, Kategoriezeilen 488–499 mit „gehört zu Gang %@“), `deleteDialog` (AC-11 aus 2a). |
| `SmartCart/Views/Store/CategoryPickerView.swift` (314 Z.) | Mit Gängen `stationSections` (108–130) ohne Wischaktionen; ohne Gänge #85-Kategorien mit `.swipeActions` (152–164: Löschen mit Rückfrage 88–102, Bearbeiten → Sheet `CustomCategoryEditor` 241–313). Muster für Wischen in Gängen. |
| `SmartCart/Models/Store.swift` | #85-Felder `customCategoryEmojis` (59), `customCategoryDates` (62), `categoryAssignments` (66), `categoryAssignmentDates` (69); `customCategoryEntries` (524), `add/update/deleteCustomCategory` (564/582/624), `rememberCategory` (648), `isStationChoice` (683); Gänge: `applyStationConfig` (+ `ensureCustomCategory` 380–386, 479–487), `renameStation` (424–459, zieht Merkungen/Weg mit), `deleteStation` (464–476, löscht gleichnamige #85-Kategorie mit), `shareID` aus UserDefaults (85); `enum Category` (915–953) mit `drugstore`/`hardware`/`grocery`-Regalen. |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | `station.setup.*` in Z. 427–458 (u. a. `row.summary` „%d Kategorien · %d Stichwörter“ 446, `detail.keywords` „Stichwörter (nur Anzeige)“ 452, `detail.bound` 451, `template.lidl` 433, `shared` 445). Kein .stringsdict/.xcstrings; Mehrzahl per Schlüsselpaar `.one`/`.other` (Muster `menuplan.daysadded.*`, MenuPlanView.swift:649–651). |
| `SmartCart/SmartCartApp.swift` | Seed `-seedStationStoreForUITests` (405–425, Lidl-Vorlage, sechs Artikel), Aufräumer `-clearStationStoreForUITests`. Setzt weder `shareID` noch #85-Kategorien → neue Tests brauchen Zusatz-Seed. |
| `RestockTests/StoreStationsTests.swift` (1105 Z.) | T1–T19 (D1), S1–S17 + S8b (D2a); T8 `testTemplateIsConsistent` (231) = Invarianten für Vorlagen (Namen eindeutig, builtIns gültig, „Lebensmittel“ in keinem Gang, hidden ∩ builtIns leer, ≤ 15 Stichwörter, ≥ 3 Zeichen, ohne Leerzeichen); S13 `testSetupStringsExistInBothLanguages` (988–1024) feste Schlüsselliste mit Platzhalterzahl → neue/geteilte Schlüssel dort nachziehen. |
| `RestockUITests/StoreStationsUITests.swift` (857 Z.) | U1–U5, U8, V1–V10, Helfer (37–305); je Test 40–113 s; Klasse allein in CI-Teil C (`SOLO_CLASSES`, ~49 min) → neue Tests verlängern C, ggf. Aufteilung nötig. |
| `.github/workflows/ci.yml` | Matrix A/B/C, `SOLO_CLASSES: "StoreStationsUITests"`, 60-min-Limit je Teil. |

## Existing Patterns
- Reine Funktionen in `StoreCategories` liefern eine neue `StationConfig`; `Store` speichert per `updateStationConfig`/`applyStationConfig`. Neue Stichwort-Bearbeitung folgt diesem Muster (`settingKeywords`/`addingKeyword`/`removingKeyword`).
- Vorlage = statisches `StationConfig` (`lidlTemplate`) + Eintrag im `confirmationDialog`. Weitere Vorlagen sind laut 2a-Spec (Z. 199–202) weitere Einträge desselben Dialogs.
- Wischaktionen im Picker: Muster aus dem #85-Zweig (Löschen mit Rückfrage, Bearbeiten im Sheet); für Gänge `store.renameStation`/`deleteStation` statt `update/deleteCustomCategory`.
- Mehrzahl: zwei Schlüssel, Auswahl im Code per `count == 1`.
- UI-Tests: Seed per DEBUG-Launch-Argument + Pflicht-Aufräumer im `tearDown`; Verschiebegriffe über Lage, nie über Beschriftung (iOS 26.5 vs. 27.2).

## Dependencies
- Upstream: `AssignmentService.categoryOrder` (35 Rohwerte, AssignmentService+Category.swift:222–231), `Category`-Regale, `StoreCategories.builtIns`, Localizable.strings, UserDefaults `shareID_<uuid>`.
- Downstream: `ShoppingRoute.SortInput.stationRank` (Sortierung), `StoreDetailView` (Abschnitte, Untertitel), `CategoryPickerView`, `AddItemView`/`EditItemView` (Merkung), `MirroredSchemaSnapshotTests` (kein neues Feld geplant → kein Schema-Schritt).

## Existing Specs
- `docs/specs/views/station-setup.md` — 2a-Spec; Ausblick 2b Z. 415–422, Known Limitations 385–403 (Stichwörter nur lesend, Überführung #85 in 2b, Vorlage-Dialog statt eigenem Blatt). Freigegebener Teil eingefroren → 2b bekommt eine eigene Spec (z. B. `docs/specs/views/station-setup-2b.md`).
- `docs/specs/models/store-stations.md` — Modell, Lidl-Tabelle 251–294 mit Stichwort-Regeln, Known Limitations 436–459.
- `docs/context/gaenge-recherche-maerkte.md` — Datenquelle der Vorlagen: Muster A Discounter (Aldi Süd), B Vollsortimenter (Edeka/Kaufland), C Drogerie (dm abgeleitet), D Baumarkt (Hornbach, 8 Stationen); Empfehlung „drei Vorlagen plus Baumarkt“.
- `docs/artifacts/feat-234-d2-kategorien-einrichten/entwurfsvorschau.html` — freigegebener Entwurf: Vorlagen-Blatt mit Lidl + Discounter 🏷️, Vollsortimenter 🏬, Drogerie 🧴, Baumarkt 🔨, je Badge „Vorschlag, bitte prüfen“; Gang-Detail mit Kopf „Stichwörter · Teil 2b: bearbeiten“; Einzahl/Mehrzahl „Kategorie/Kategorien“.

## Risks & Considerations
- **Umfang:** PO-Schätzung 400–450 Zeilen; 2a lief bei ~1.560 statt 640 (Tests allein ~790). Scoping-Limit 250 wird sicher überschritten → Zuschnitt in der Analyse früh benennen (Memory `issue-234-d2a-umfang-akzeptiert`, PO lehnt Splitten meist ab).
- **CI-Laufzeit:** `StoreStationsUITests` füllt Teil C mit ~49 min. 4–6 neue UI-Tests à 40–110 s reißen das 60-min-Limit → neue Tests in eigene Klasse (z. B. `StationSetupExtrasUITests`) und eigenen Matrix-Teil oder Aufteilung von C.
- **Übernahme #85:** Semantik offen (PO-Frage): alte eigene Kategorien als neue Gänge anlegen, einem Gang als Stichwort zuschlagen, oder Merkungen umhängen? Merkungen auf #85-Kategorien gelten heute als „veraltet“ und werden übersprungen; Daten sind unverändert vorhanden.
- **Vorlage auf bestehende Gänge:** Wählen einer Vorlage ersetzt die Konfiguration (wie Lidl). Merkungen auf Gang-Namen, die in der neuen Vorlage fehlen, fallen auf „Sonstiges“ zurück.
- **Vorlagen-Inhalte:** Namen deutsch auch in Englisch (bekannte Grenze aus D1); Emojis 🏬/🔨 fehlen in `emojiChoices`.
- **Stichwort-Regeln:** ≥ 3 Zeichen, ohne Leerzeichen, klein, eindeutig je Gang? Ein Stichwort in zwei Gängen → längstes/früherer Gang gewinnt; Validierung bei Eingabe nötig.
- **Wischen im Picker:** Löschen eines Gangs aus dem Artikel-Dialog heraus ist folgenreich (Artikel fallen nach „Sonstiges“) → Rückfrage wie in der Einrichtung; letzter Gang → „Gänge entfernen?“ (AC-11 aus 2a gilt sinngemäß).
- **Geteilte Läden:** Gänge bleiben lokal (D3); Hinweis-Test braucht Seed mit `shareID`.
- **Sichtbare Änderung:** Entwurf liegt aus 2a vor (Vorlagen-Blatt, Stichwort-Kopf); für Stichwort-Bearbeitung und Wischaktionen im Picker ist noch kein Entwurf freigegeben → Vorschau in `/20-analyse` (Regel 2026-09-22).

## Analysis

### Type
Feature (Fortsetzung #234, Durchgang 2b)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Models/StoreTemplates.swift` | CREATE | Vier Vorlagen `discounterTemplate`, `fullRangeTemplate`, `drugstoreTemplate`, `hardwareTemplate` als `extension StoreCategories` (StoreCategories hat schon 428 Z.); pbxproj-Eintrag in App-, Widget- und Teilen-Ziel prüfen (StoreCategories steht in allen drei) |
| `SmartCart/Models/StoreCategories.swift` | MODIFY | reine Funktionen `normalizedKeyword`, `addingKeyword(_:toStation:in:) -> StationConfig?`, `removingKeyword(_:fromStation:in:)`, `stationsContainingKeyword` (für Hinweis); `legacyCustomCategories(entries:config:)` (alte #85-Kategorien = `customCategoryEntries` ohne gleichnamigen Gang) |
| `SmartCart/Views/Store/StationSetupView.swift` | MODIFY | Vorlagen-Blatt statt `confirmationDialog` (Lidl + 4 mit Badge), Stichwort-Abschnitt editierbar (Zeilen, Wisch-Löschen, Eingabefeld, Duplikat-Hinweis), Abschnitt „Eigene Kategorien von früher“ mit „Übernehmen“/„Alle übernehmen“, Einzahl in `StationSetupRow` |
| `SmartCart/Views/Store/CategoryPickerView.swift` | MODIFY | `.swipeActions` an Gang-Zeilen (Bearbeiten-Sheet Name+Emoji über `store.renameStation`, Löschen mit `StationSetupView.deleteDialog`), `selection` nach Löschen → Sonstiges-Marke, nach Umbenennen → neuer Name |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` | MODIFY | Vorlagen-Namen/-Untertitel, Badge, Stichwort-Texte und -Hinweise, Übernahme-Abschnitt, `row.categories.one/other`, `row.keywords.one/other` (ersetzt `row.summary`) |
| `SmartCart/SmartCartApp.swift` | MODIFY | DEBUG-Seeds: Zusatz `-seedLegacyCustomCategoriesForUITests` (alte #85-Kategorie + Merkung im Stationsladen), `-seedStationStoreSharedForUITests` (setzt `shareID`); Aufräumen über `-clearStationStoreForUITests` erweitern |
| `RestockTests/StoreStationsTests.swift` | MODIFY | T8 → `assertTemplateInvariants` für alle fünf Vorlagen; Stichwort-Funktionen; Übernahme (Merkung und von Hand gesetzte Kategorie lösen sich nach Übernahme auf den neuen Gang auf); S13-Schlüsselliste |
| `RestockUITests/StationSetupExtrasUITests.swift` | CREATE | neue Klasse (Vorlage Discounter, Stichwort anlegen → Artikel wandert, Wischen im Picker, Übernahme, + vorgemerkt: Wisch-Löschen Übersicht, „gehört zu Gang …“, Emoji, Hinweis geteilt) |
| `.github/workflows/ci.yml` | MODIFY | Matrix-Teil D (`EXTRA_CLASSES`), B überspringt die Klasse (~10 Z.) |

### Scope Assessment
- Files: 9–10 (Limit 4–5 überschritten)
- Estimated LoC: Produkt ~485, Tests ~550, gesamt ~1.000–1.050 (PO-Schätzung war 400–450; 2a lag ebenfalls bei Faktor ~2,3)
- Risk Level: MEDIUM — kein neues Datenfeld, kein Schema-Schritt; Risiko liegt im Picker (Löschen/Umbenennen eines Gangs, während ein Artikel-Dialog ihn ausgewählt hat) und in der CI-Laufzeit

### Technical Approach
- **Vorlagen:** reine Daten wie `lidlTemplate`; Inhalte nach `gaenge-recherche-maerkte.md` (Tabelle im Entwurf, Abschnitt 2). Discounter 10 Gänge (Aldi Süd), Vollsortimenter 12 (Edeka/Kaufland), Drogerie 11 (dm-Prosa, abgeleitet), Baumarkt 8 (Hornbach). Baumarkt-Kategorien in den drei Lebensmittel-Vorlagen `hidden` wie Lidl; Drogerie/Baumarkt ohne `hidden`. „Lebensmittel“ in keinem Gang (T8-Invariante gilt für alle). Alle Vorlagen-Emojis stehen schon in `emojiChoices`; 🏷️🏬🧴🔨 sind nur Symbole im Blatt.
- **Vorlagen-Blatt** statt `confirmationDialog` (Entwurf aus 2a war so freigegeben; 2a hatte das Menü als Known Limitation). Rückfrage vor dem Ersetzen vorhandener Gänge bleibt.
- **Stichwörter:** Normalisierung trim + lowercase; Regel: ein Wort (keine Leerzeichen, sonst trifft `stationForKeywords` nie, weil es den Namen in Wörter zerlegt), ≥ 3 Zeichen, nicht doppelt im selben Gang (→ `nil`, Hinweis). Gleiches Stichwort in anderem Gang: annehmen mit Hinweis „Gang weiter oben gewinnt“ (Auflösung ist deterministisch: längstes, bei Gleichstand früherer Gang, `StoreCategories.swift:234`). Keine Obergrenze für Nutzer (≤ 15 nur Vorlagen-Invariante). Speichern über `store.updateStationConfig`.
- **#85-Übernahme:** im Code verifiziert (`StoreCategories.station(...)` 201–215, `stationNamed` 218): Merkung (`categoryAssignments`) und von Hand gesetzte Kategorie (`item.category` + `categoryManuallySet`) lösen sich über den Gang-Namen auf. Ein Gang gleichen Namens übernimmt die Artikel daher ohne Datenumbau. Übernehmen = `addingStation(name, emoji: altesEmoji)` + `updateStationConfig`; `ensureCustomCategory` lässt den alten Eintrag unverändert. Abschnitt nur sichtbar, wenn alte Kategorien existieren.
- **Picker-Wischen:** Muster aus dem #85-Zweig (`CategoryPickerView.swift:151–164`), Rückfrage beim Löschen, letzter Gang → „Gänge entfernen?“ (AC-11 aus 2a).
- **Einzahl:** zwei Schlüsselpaare `.one/.other`, Auswahl per `count == 1` (Muster `menuplan.daysadded.*`).
- **CI:** neue UI-Tests in eigener Klasse und Matrix-Teil D; `StoreStationsUITests` füllt Teil C bereits mit ~49 von 60 min.

### Alternativen (Regel 2026-09-19)
| Punkt | Empfehlung | Alternative | Folge der Alternative |
|---|---|---|---|
| Vorlage wählen | eigenes Blatt mit Badge | Systemmenü mit Text „· Vorschlag“ | ~40 Z. weniger, Hinweis geht unter |
| Stichwörter | Zeilen + Wisch-Löschen + Feld | Wortwolke mit ✕ | kompakter, kleine Tippziele |
| Duplikat-Stichwort | annehmen + Hinweis | stillschweigend / ablehnen | ablehnen ist strenger als das Modell |
| Picker | Wischen Bearbeiten/Löschen | Eintrag „Gänge bearbeiten …“ öffnet Einrichtung | ein Weg weniger, Artikel-Dialog wird verlassen |
| #85-Übernahme | Abschnitt, je Kategorie + „Alle“ | einmalige Frage beim Vorlagen-Wählen | keine Auswahl einzelner, nur ein Zeitpunkt |
| Zuschnitt | zwei Durchgänge 2b-1 (~540) / 2b-2 (~480) | ein Durchgang (~1.000) | Limit ×4, wie bei 2a vom PO akzeptiert |

### Befunde gegen den Plan
- Umfang ~1.000 statt 400–450 (Faktor 2,3 wie 2a).
- Drogerie-Vorlage ist nicht belegt, nur abgeleitet (Recherche Z. 110) → Badge „Vorschlag, bitte prüfen“ ist Pflicht, nicht Kosmetik.
- Übernahme ist kein Datenproblem, nur ein UI-Angebot (Annahme „Merkungen umhängen“ aus dem Kontext entfällt).

### Entwurfsvorschau
`docs/artifacts/feat-234-d2b-vorlagen-stichwoerter/entwurfsvorschau.html` (veröffentlicht: https://claude.ai/artifact/GDVYKsJHVtBPNsLEF4u7Lh), Heute-Bilder aus den Durchläufen von D1/2a.

### Open Questions
- [x] PO 2026-11-01: Entwürfe 1, 3, 4, 5 freigegeben, jeweils die Empfehlung (Vorlagen-Blatt mit Badge, Stichwörter als Zeilen mit Wisch-Löschen + Feld + Duplikat-Hinweis, Wischen Bearbeiten/Löschen im Picker, Abschnitt „Eigene Kategorien von früher“ mit „Übernehmen“/„Alle übernehmen“)
- [x] PO 2026-11-01: Vorlagen-Inhalte wie in Abschnitt 2 der Vorschau übernehmen (Badge „Vorschlag, bitte prüfen“)
- [x] PO 2026-11-01: Zuschnitt zwei Durchgänge

### Zuschnitt (PO 2026-11-01)
- **Dieser Workflow = 2b-1 (~540 Z.):** vier Vorlagen (`StoreTemplates.swift`) mit eigenem Vorlagen-Blatt, Stichwörter bearbeiten (Funktionen + Gang-Detail), Einzahl „1 Kategorie“/„1 Stichwort“, Unit-Tests dazu. UI-Tests für Vorlage und Stichwort; wenn sie Teil C über 60 min heben, Klasse `StationSetupExtrasUITests` + CI-Teil D schon hier.
- **2b-2 (eigener Workflow danach, ~480 Z.):** Wischen in der Kategorie-Auswahl, Übernahme früherer #85-Kategorien, die vier vorgemerkten UI-Tests aus 2a (Wisch-Löschen Übersicht, „gehört zu Gang …“, Emoji, Hinweis geteilt) mit Seeds.

### Nebenbefund
- `CD_Store.CD_stationConfigJSON` ist seit 2026-11-01 in Production (Gegenprobe run 41279956193, Repo = Development = Production; Meldung einer anderen Sitzung).
