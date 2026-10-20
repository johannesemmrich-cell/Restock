# Fix: Bon-Prüf-Screen fehlt beim ersten Start nach Neuinstallation (Issue #35)

**Gemeldet 23.09.2026, umgesetzt 20.10.2026 (Meilenstein „Öffentliches Release 1.0“).**

## Symptom

Im isolierten Lauf von `ReceiptReviewUITests` scheiterte sporadisch der erste Test der Klasse an der Vorbedingung „Das Bon-Prüf-Sheet ist nicht erschienen“ (2 von 4 Läufen am 23.09.2026). Für echte Nutzer: Wer die App frisch installiert und sofort einen Bon aus Fotos teilt, sieht den Prüf-Screen erst beim nächsten Öffnen.

## Ursache (im Code gelesen, in #35 belegt)

`HomeView.checkPendingReceiptScan()` prüft `!activeStores.isEmpty` **vor** `ReceiptShareHandoff.takePending()`, damit die Nutzlast nicht verworfen wird, solange kein Laden da ist (Schutz nach dem Datenverlust vom 20.09.2026). Beim ersten Start nach Neuinstallation ist die `@Query` `activeStores` in `onAppear` unter Last noch leer. Danach rief nichts die Prüfung erneut auf: `scenePhase` bleibt `.active`, `restock://receiptscan` kommt bei der Übergabe über die App-Gruppe nicht. Längere Wartezeiten im Test helfen deshalb nicht.

## Änderung

`HomeView`: `.onChange(of: activeStores.isEmpty) { _, isEmpty in if !isEmpty { checkPendingReceiptScan() } }`. Sobald die Läden geladen sind, genau ein Nachversuch. Die Prüfung ist idempotent: ohne Nutzlast liefert `takePending()` `nil`, mit offenem Sheet (`pendingReceiptScan != nil`) bricht sie ab. Der Schutz der Nutzlast bleibt unverändert; es wird nur häufiger versucht, nie früher verworfen.

Kein neues Launch-Argument, kein neuer Zustand.

## Nachweis

- Ein Unit-Test ist nicht möglich: Die Logik hängt an der SwiftUI-`@Query` in `HomeView`, der Zeitpunkt des Befüllens ist nicht steuerbar.
- Der Weg ist durch `ReceiptReviewUITests.testReviewSheetOpensFromShareHandoff` und die 19 weiteren Tests der Klasse abgedeckt (Seed `-seedReceiptReviewForUITests` legt die Nutzlast beim App-Start in die App-Gruppe, genau der Weg der Teilen-Erweiterung). Der Fehler war sporadisch (nur beim ersten Test nach kaltem Install unter Last), daher ist „grün in CI“ nach dem Fix kein Beweis, sondern nur „nicht widerlegt“; seit #173 würde die CI-Wiederholung einen Einzelfehler zudem verdecken (die `xcresulttool`-Zusammenfassung in der Lauf-Zusammenfassung zeigt Wiederholungen aber an).
- Erwartete Messung: In der Lauf-Zusammenfassung der UI-Hälften darf `testReviewSheetOpensFromShareHandoff` keine Wiederholung mehr brauchen. Bisherige Rate laut #35: 2 von 4 isolierten Läufen.

## Offene Grenzen

- Der Gerätetest „frisch installieren, sofort Bon teilen“ (Issue #187, Punkt 7) steht aus.
- #17 (UI-Tests setzen den Zustand nicht zurück) und #33 (Seeds löschen ungeprüft) bleiben eigene Tickets.
