# Mini-Spec: fix-115-replenishment-seed

Issue #115 · Fast Track · Ursache belegt in `docs/artifacts/fix-115-replenishment-seed/probe-output.txt`
und im Kommentar https://github.com/johannesemmrich-cell/Restock/issues/115#issuecomment-6021878150

## Ursache (belegt)
Die Testdaten der Listen-Artikel („Listenreis“, „Listennudeln“) liegen zu knapp am Banner-Fenster:
Käufe vor 37/23/9 Tagen → Termin heute +5, Fenster 3 Tage (`PurchaseRecord.swift:92`), also 1 Tag
Reserve. Dienstags zieht die Schließtag-Regel den Termin von So auf Sa vor (`PurchaseRecord.swift:162`),
und `daysUntilNeeded` zählt volle 24-h-Blöcke ab Uhrzeit (`PurchaseRecord.swift:96–98`): Dienstag ab
13 Uhr ist es 3 = Fenster → „Listenreis“ steht im Banner. Jahresprobe: 678 von 8760 Stunden scheitern
(jeden Dienstagnachmittag, einzelne Feiertage, Zeitumstellung). **Kein Produktfehler.**

## Was ändert sich
- `SmartCart/SmartCartApp.swift`: Die Kauf-Abstände des Nachkauf-Seeds werden eine benannte,
  nur im Testmodus vorhandene Konstante (`replenishmentSeedDaysAgo`, innerhalb `#if DEBUG`), damit ein
  Unit-Test sie lesen kann. Werte der Listen-Artikel: **−46/−26/−6** statt −37/−23/−9 (Abstand 20 Tage,
  Termin heute +14, Fenster 4 Tage, Besuchsabstand des Listenladens 20 Tage). Banner-Artikel
  (−29/−19/−9) bleiben unverändert. Doku-Kommentar am Seed passend.
- `RestockTests/ReplenishmentSeedYearTests.swift` (neu, in `project.pbxproj` an vier Stellen registriert):
  Unit-Test, der den Seed mit den Konstanten nachbaut und für **jede Stunde eines Jahres** (Europe/Berlin,
  Land DE, inkl. Feiertage und Zeitumstellung) prüft: Bannerbutter und Bannerquark stehen im Banner
  (`HabitService.dueSoonItems`), Listenreis und Listennudeln **nicht**, aber sie stehen in
  `HabitService.dueBeforeNextVisit` des Listenladens („Vielleicht auch fällig“).
- `docs/specs/ui-tests/replenishment-uitest.md` (Zeilen 76 und 165): neue Werte und Begründung.

## Was darf sich nicht ändern
- Kein Eingriff in `HabitService`, `PurchaseRecord`, `RetailClosedDays` oder sonstigen Produktcode:
  Die Nachkauf-Logik (4b Schließtage, B3 Fenster, `daysUntilNeeded`) bleibt wie sie ist.
- Die Tests in `ReplenishmentUITests.swift` bleiben unverändert (gleiche Erwartungen).
- Der Seed läuft weiterhin nur mit `-seedReplenishmentForUITests` und nur in DEBUG-Builds; ohne das
  Argument und im Release ändert sich nichts.
- Banner-Seed (Bannerladen) unverändert.

## Test-Schritte (automatisiert, keine manuellen Schritte)
1. **RED:** Der neue Jahres-Unit-Test läuft zuerst gegen die alten Werte (−37/−23/−9) und schlägt
   mit genau den belegten Stunden fehl (z. B. Di 06.10. 13:00).
2. **GREEN:** Mit −46/−26/−6 besteht er für alle 8760 Stunden.
3. `ReplenishmentUITests` (10 Tests) laufen auf Restock-Validate **am Nachmittag, nicht nur morgens**
   — der Fehler war uhrzeitabhängig; zusätzlich ein Lauf des Jobs `ui-test` in der CI.
4. Gesamte Unit-Suite grün (getrennt von der UI-Suite, siehe Memory zum Testrunner-Hänger).
5. Die Anwendung wird vor der Übergabe im Simulator mit dem Seed gestartet und der Banner-Ablauf
   durchgespielt (Banner zeigt genau zwei Artikel, Listenladen zeigt „Vielleicht auch fällig“).

## Umfang
- 4 Dateien (SmartCartApp.swift, neue Testdatei, project.pbxproj, replenishment-uitest.md), ca. +70/−10 LoC.

## Offene Grenze / Alternativen
- Nicht Teil dieser Reparatur: `daysUntilNeeded` rechnet ab Uhrzeit statt in Kalendertagen, ein echter
  Artikel kann daher mitten am Tag ins Banner springen. Ist so spezifiziert (B3), bleibt unverändert;
  Änderung wäre ein eigenes Produktthema (PO-Entscheidung).
- Verworfen: Seed an einen festen Wochentag binden (komplizierter, nicht feiertagsfest).
