# Plan: Restock als beste App zum gemeinsamen Einkaufen

Stand: 2026-10-06. Entwurf, nicht abgestimmt. Marktdaten aus Websuche, nicht aus eigenen Tests.

## 1. Markt

| App | Stärke beim Teilen | Schwäche (laut Quellen) |
|---|---|---|
| Bring! | Einfache Listen, Icon-Katalog, mehrere Listen, kostenlos | Werbung/Angebote, überladen, Premium (ca. 14 €/Jahr) schaltet nur Werbung ab |
| AnyList | Echtzeit-Sync, Rezeptimport, Gang-Sortierung pro Laden | Fokus Rezepte/Meal Planning, Teilen ist Beiwerk |
| OurGroceries | Kostenlos, Alexa | Schlicht, kein Lernen |
| Listonic | Echtzeit, Familien, Preisvergleich | Werbung |
| Apple Erinnerungen | Gratis, Zuweisung an Personen, Apple Intelligence sortiert | Kein Laden-Konzept, keine Preise, kein Nachkauf |
| Shopping Lists+ | Teilen pro Laden, Echtzeit | Klein |

Alle Wettbewerber lösen „Liste gemeinsam führen, Haken in Echtzeit sehen“. Das ist Standard und kein Alleinstellungsmerkmal.

Quellen: [Listonic-Vergleich](https://fpdev.listonic.com/best-grocery-list-apps), [iphone-ticker zu Bring!](https://www.iphone-ticker.de/einkaufsliste-bring-jetzt-mit-premium-abo-155218/), [heise Überblick](https://www.heise.de/tipps-tricks/Einkaufslisten-Apps-im-Ueberblick-4883163.html), [Apple Erinnerungen teilen](https://support.apple.com/en-sg/105124), [Shopping Lists+](https://apps.apple.com/app/id6467395431).

## 2. Ist-Stand Restock (aus dem Code)

- Teilen pro Laden per Einladungscode (10 Zeichen), CloudKit **Public** DB (`SharedStoreService`), Sync über `SyncCoordinator`.
- `addedBy` / `completedBy` pro Artikel, Anzeigename pro Gerät.
- Geteilt werden auch Kategorien, gelernte Preise, Kategorie-Zuordnungen (#94).
- Gelernte Einkaufsroute pro Gerät, Nachkauf-Vorschläge, Bon-Scan mit Preisen, Live Activity, Siri.
- Alle Teilen-Funktionen sind kostenlos (Pro nur Ausgaben-Statistik und Rezeptplan).
- Offen/Lücken: Sicherheitsmodell (Public DB), geteilter Sync nur mit Merge-Unit-Tests geprüft, nie mit zwei echten Apple-IDs (#98 Rest), kein Android.

## 3. Wo Restock sich abheben kann

Ziel: nicht „noch eine geteilte Liste“, sondern **gemeinsam einkaufen im Laden**. Drei Hebel, die nur Restock mit seinem Datenbestand glaubwürdig liefern kann:

1. **Einkauf aufteilen:** Zwei Personen im selben Laden, jede nimmt sich Abschnitte/Artikel („Ich nehme Obst & Milch“). Basis: gelernte Route + Kategorien.
2. **Wer-kauft-was-Status:** „Anna ist gerade bei Rewe“, nichts doppelt kaufen, nach dem Einkauf Zusammenfassung („Anna hat 14 Artikel, Ben 6“). Basis: `completedBy`, Live Activity.
3. **Gemeinsames Nachkauf-Gedächtnis:** Der Haushalt hat einen Verbrauchsrhythmus, nicht jede Person einen eigenen. Banner „Milch fast leer“ erscheint einmal für alle, nicht doppelt. Basis: `HabitService`, `PurchaseRecord` im Sync.
4. Rahmen: **keine Werbung, keine Angebots-Reiter, alles Teilen kostenlos** als bewusster Gegenpol zu Bring!.

Nicht verfolgen: Rezept-Plattform (AnyList), Gutscheine/Werbung, Android.

## 4. Phasen

**Phase 0 — Fundament (vor jedem neuen Feature)**
- Echter Zwei-Konten-Test des Teilens (Einladung, Push, Offline-Konflikt). Ohne den bleibt jede Aussage „funktioniert“ unbelegt.
- Entscheidung Sicherheitsmodell: bei Ausbau von Teilen auf `CKShare` migrieren (Backlog „CKShare-Migration“ ist dann nicht mehr optional, weil mehr Nutzer und mehr Daten im Share).
- Latenz messen: Wie schnell sieht Person B den Haken von A?

**Phase 1 — Teilen so gut wie der Standard**
- Sichtbare Mitglieder, Einladung per Link (nicht nur Code), Entfernen/Verlassen.
- Echtzeit-Gefühl: Push bei Änderungen, „Anna hat Milch abgehakt“ als stilles Update.
- Aufräumen: Fehlerfälle bei Beitritt, abgelaufene Codes.

**Phase 2 — Differenzierung**
- Abschnitte/Artikel beanspruchen („ich nehme“), mit Rückgabe.
- Laden-Präsenz („unterwegs bei …“) über Live Activity auch für Mitglieder.
- Gemeinsame Nachkauf-Vorschläge (ein Banner pro Haushalt).

**Phase 3 — Haushalt**
- Haushalt als Einheit mit mehreren Läden statt Einzel-Share pro Laden.
- Einkaufsabschluss mit Bon: Kosten pro Person sichtbar (optional, kein Splitwise-Nachbau).

## 5. Entscheidungen, die du treffen musst

1. Zielgruppe: Paare/Familien in einem Haushalt (Empfehlung) oder auch WG/Gruppen?
2. Android/Web: ja oder bewusst iOS-only? (Beeinflusst die Backend-Wahl.)
3. CloudKit/CKShare beibehalten oder eigenes Backend? Empfehlung: CKShare, kein Server, keine laufenden Kosten, keine Konten.
4. Hebel 1 und 2 zuerst, oder erst Phase 0/1?

## 6. Risiken

- Teilen funktioniert nur mit iCloud-Konto: Familienmitglieder ohne iPhone sind ausgeschlossen.
- Echtzeit über CloudKit ist Push-basiert und nicht garantiert sofort; „live“ nicht versprechen.
- Ohne echten Mehrkonten-Test sind Konflikte beim gleichzeitigen Einkaufen ungetestet.
- Datenschutz: Mitglieder-Anzeigenamen werden gespeichert (Datenschutzerklärung ist angepasst).

## 7. Erfolgskriterien

- Zwei echte Geräte/Konten durchlaufen Einladung → gemeinsame Liste → aufgeteilter Einkauf ohne Doppelkauf, automatisiert oder protokolliert nachgewiesen.
- Zeit von Haken bis Anzeige beim Partner gemessen und dokumentiert.
