# Durchlauf als Nutzer, #234 Durchgang 2a (2026-10-31)

Simulator `6728F5AB-712F-46E0-A1D1-2047A9771C8E` (Restock-Validate), Debug-Build aus `build/dd-d2a`,
Stand: Commit 18f3255 plus AC-11-Korrektur (Rückfrage beim letzten Gang). Gefahren über einen
einmaligen XCUITest-Ablauf `testZZDurchlaufMitFotos` (Simulator fensterlos, keine Touch-Eingabe
von außen), Start nur mit Seed `-seedStationStoreForUITests`, danach alles über die Oberfläche.
Der Ablauf wurde nach dem Lauf wieder aus `StoreStationsUITests.swift` entfernt. Protokoll:
`../durchlauf-log.txt` (`** TEST SUCCEEDED **`).

| Foto | Schritt | Befund |
|---|---|---|
| 01 | ··· → Kategorien einrichten → Gänge entfernen | Liste in Standard-Kategorien |
| 02 | Einrichten im Laden ohne Gänge | nur „Vorlage wählen …“ und „Gang hinzufügen“ |
| 03 | Vorlage „Lidl“ | 12 Gänge |
| 04 | Gang „Käse“ → „Käsetheke“ | Name übernommen |
| 05 | „Elektronik“ → Zuordnen → Drogerie | aus „Offen“ verschwunden |
| 06 | erste offene Kategorie → Ausblenden | steht unter „Ausgeblendet“ |
| 07 | Gang „Käsetheke“ löschen (Detail) | 11 Gänge, Rückfrage „Gang … löschen?“ |
| 08 | Sortieren: „Tiefkühl“ nach oben gezogen | Reihenfolge folgt |
| 09 | Artikel „Zahnpasta“ hinzugefügt, Modus Kategorie | Zahnpasta und Batterien unter „Drogerie“ |
| 10 | Modus Einkaufsweg | flach mit Gang-Untertiteln |
| 11 | Laden mit genau einem Gang „Lager“ → Gang löschen | Rückfrage „Gänge entfernen?“ mit deren Text |

Gefunden im Durchlauf:
- Foto 11 (erster Lauf): Der Knopf der Rückfrage hieß noch „Gang löschen“; jetzt „Gänge entfernen“
  (`deleteDialog(...).button`, geprüft in S8b und V10).
- Fotos 07/08: Zeilentext „1 Kategorien“ ohne Einzahl. Wortlaut steht so in der freigegebenen Spec
  (`station.setup.row.summary`), daher nicht hier geändert, sondern für Durchgang 2b vorgemerkt.
- Der erste Lauf scheiterte am Ablauf selbst (Verschiebegriff „Drogerie“ lag außerhalb des
  sichtbaren Bereichs), kein Produktfehler; zweiter Lauf mit „Tiefkühl“ grün.

Nichts auf Hennings Geräten.
