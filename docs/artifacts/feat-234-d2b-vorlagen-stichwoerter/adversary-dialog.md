# Adversary Dialog — feat-234-d2b-vorlagen-stichwoerter
Spec: docs/specs/views/station-templates-keywords.md
Datum: 2026-11-01 12:26

## Checkliste
- [x] **AC-1:** [PROVEN: X1 gruen; Kennzeichen nur wenn id != lidl; Foto durchlauf/03-vorlagen-blatt.png] „Vorlage wählen …“ öffnet ein Blatt mit fünf Vorlagen: Lidl und die vier Muster Discounter, Vollsortimenter, Drogerie, Baumarkt (Name, „N Gänge“); die vier Muster tragen sichtbar „Vorschlag, bitte prüfen“, Lidl nicht. (X1, K8)
- [x] **AC-2:** [PROVEN: Sheet fragt nur bei hasStations (StationSetupView.swift:366); X1 prueft Rueckfrage und Abbrechen; V8 Laden ohne Gaenge sofort, gruen] Eine gewählte Vorlage ersetzt die Gänge des Ladens: sofort, wenn der Laden keine Gänge hat; nach einer Rückfrage „Vorhandene Gänge ersetzen?“, wenn er welche hat; Abbrechen ändert nichts. (X1)
- [x] **AC-3:** [PROVEN: K8 gruen im eigenen Lauf (adversary-test-output.txt); StoreTemplates.swift mit den Spec-Tabellen verglichen, identisch; max 10 Stichwoerter je Gang] Jede der fünf Vorlagen erfüllt die Invarianten: Gang-Zahl 12/10/12/11/8, Gang-Namen eindeutig und nie „Sonstiges“, alle Kategorien gültig, „Lebensmittel“ in keinem Gang und nicht ausgeblendet, keine Kategorie in zwei Gängen, Name-gebundene Kategorien im eigenen Gang, Emoji aus der Auswahl, höchstens 15 Stichwörter je Gang, jedes Stichwort normalisiert und im Gang eindeutig. Baumarkt-Kategorien sind in Lidl, Discounter und Vollsortimenter ausgeblendet, in Drogerie und Baumarkt nicht. (K8)
- [x] **AC-4:** [PROVEN: K9 gruen im eigenen Lauf] Die Vorlagen sortieren Beispielartikel in den erwarteten Gang (Salami, Bratwurst, Zahnpasta, Gouda, Hammer, Tapete). (K9)
- [x] **AC-5:** [PROVEN: K10 gruen; Sheet ruft nur Store.applyStationConfig] Das Anwenden einer Vorlage lässt Artikel, Merkungen und vorhandene eigene Kategorien unberührt und legt Gang-Namen (außer festen Kategorien) als eigene Kategorien an; der Zeitstempel ist jetzt. (K10, X1)
- [x] **AC-6:** [PROVEN: K1 gruen; StoreCategories.swift:421; Umlaute und Grossbuchstaben ok, 123 angenommen (Spec erlaubt Ziffern); Hinweis sichtbar (X2, Foto 09); siehe F001] Ein Stichwort wird beim Hinzufügen getrimmt und klein geschrieben; es muss ein einzelnes Wort aus Buchstaben und Ziffern mit mindestens 3 Zeichen sein, sonst wird es abgelehnt (nichts gespeichert, Hinweis sichtbar). (K1, X2)
- [x] **AC-7:** [PROVEN: K2, K7 gruen; add() ruft store.updateStationConfig, keine Obergrenze] Ein gültiges Stichwort wird am Ende der Stichwörter des Gangs gespeichert (über `store.updateStationConfig`, `date` jetzt, Weg-Version erhöht); für Nutzer gibt es keine Obergrenze. (K2, K7, X2)
- [x] **AC-8:** [PROVEN: K3 gruen; StoreCategories.swift:428 liefert .duplicate; X2, Foto 10] Ein Stichwort, das im selben Gang schon steht (Vergleich ohne Groß-/Kleinschreibung), wird abgelehnt mit dem Hinweis „steht hier schon“; nichts ändert sich. (K3, X2)
- [x] **AC-9:** [PROVEN: K4 gruen; others in Gang-Reihenfolge; Hinweistext nennt Gaenge und weiter oben gewinnt] Steht dasselbe Stichwort schon in einem anderen Gang, wird es angenommen; der Hinweis nennt die anderen Gänge und „Der Gang weiter oben in der Liste gewinnt“. Die Auflösung folgt unverändert der D1-Regel (längstes Stichwort, bei Gleichstand der frühere Gang). (K4, X2)
- [x] **AC-10:** [PROVEN: K5, X3 gruen; swipeActions ohne Rueckfrage; nach Umbenennen korrekt, da StationDetailView.name dem Umbenennen folgt] Ein Stichwort lässt sich per Wischen (nach links, „Löschen“) ohne Rückfrage entfernen; die Reihenfolge der übrigen bleibt. (K5, X3)
- [x] **AC-11:** [PROVEN: K6, K7, X2, X3 gruen; updateStationConfig erhoeht Weg-Version, onChange meldet an die Liste] Hinzufügen und Entfernen wirken sofort auf die Ladenliste: ein Artikel ohne Merkung und ohne Handwahl wechselt in den Gang des Stichworts bzw. zurück; Merkung und Handwahl gewinnen weiter davor. (K6, K7, X2, X3)
- [x] **AC-12:** [PROVEN: K11 gruen; StationSetupView.swift:421, de und en Paare vorhanden] Die Gang-Zeile zeigt „1 Kategorie“ und „1 Stichwort“ in der Einzahl, sonst Mehrzahl, „noch leer“ bei 0 und 0; beides in Deutsch und Englisch. (K11)
- [x] **AC-13:** [PROVEN: eigener Lauf LocalizationKeyParityTests und S13 gruen; beide .strings plutil OK, je 488 Schluessel, keine Dubletten, keine kaputten Escapes] Alle neuen Texte haben deutsche und englische Fassung mit gleichen Schlüsseln und Platzhaltern (`LocalizationKeyParityTests` und S13 grün). (S13)
- [x] **AC-14:** [PROVEN: ci.yml Matrix A-D, D nur EXTRA_CLASSES, B ueberspringt HEAVY, SOLO und EXTRA, A und C unveraendert, Retry und Summary matrixunabhaengig; 6 Strukturtests OK; kein Modell- oder Schemafeld; pbxproj OK; 2 rote ConsumptionPatternTests am Basisstand identisch (Issue 231)] Die neue UI-Testklasse läuft in einem eigenen CI-Teil D; Teil B überspringt sie, A und C bleiben unverändert. Kein neues `@Model`-Feld, kein neuer `@AppStorage`-Schlüssel, keine Schemaänderung; Läden ohne Gänge verhalten sich unverändert; alle Bestandstests bleiben grün (außer den in der Offenlegung genannten angepassten S13/T8). (Gesamtlauf, CI)

## Dialog

### Runde 1
**Adversary:** Alle gestagten Aenderungen gelesen (ci.yml, pbxproj, Strings, StoreCategories, StationSetupView, StoreTemplates). Geprueft: kaputte Escapes und Dubletten in .strings (keine), pbxproj falsches Ziel oder doppelt (nein), ci.yml-Logik D/B/A/C (korrekt), Funktionen ueber 50 Zeilen (laengste ca. 34), Zustand nach Umbenennen (aktuell), unbekannter Gang (.invalid), Vorlage ohne Gaenge (V8 sofort). Eigener Lauf StoreStationsTests, LocalizationKeyParityTests, MirroredSchemaSnapshotTests: 56 Tests, 0 Fehler (adversary-test-output.txt). Sechs Strukturtests gruen.
Code reference: SmartCart/Models/StoreCategories.swift:421
Code reference: SmartCart/Models/StoreTemplates.swift:23
Code reference: SmartCart/Views/Store/StationSetupView.swift:313
**Implementierer:** (nicht beteiligt)

### Runde 2
**Adversary:** Randfaelle per Codelesen (dynamische Sondierung vom Worktree-Guard blockiert, nicht ausgefuehrt): Umlaut, ß, Grossbuchstaben ok; 123 angenommen (F001); Hochzahlen und Kombinationszeichen passieren CharacterSet.alphanumerics (F001); Diakritik-Duplikat kase gleich kaese wird abgelehnt, konsistent mit der Aufloesung; Loeschen nach Umbenennen funktioniert; gleiche Fehlermeldung zweimal loest kein erneutes Scrollen aus, Zeile ist aber sichtbar (kein Defekt). Fotos 03 und 10 gesehen. Abweichungen ohne PO-Wort (ScrollViewReader, Kennung stationSetup.keyword.duplicate, festes Bedienhilfen-Label aus lokalisierten Teilen) unkritisch.
Code reference: SmartCart/Models/StoreCategories.swift:428
Code reference: SmartCart/Models/StoreTemplates.swift:107
Code reference: SmartCart/Views/Store/StationSetupView.swift:626
**Implementierer:** (nicht beteiligt)

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: SmartCart/Models/StoreCategories.swift:421
  Description: normalizedKeyword nutzt CharacterSet.alphanumerics (L, M, N): reine Ziffern, Hochzahlen und Kombinationszeichen werden angenommen; der Hinweis sagt aber mindestens 3 Buchstaben.
  Spec requirement: AC-6 — Buchstaben und Ziffern, mindestens 3 Zeichen
  Conflict: Nur Wortlaut des Hinweises ungenau; Verhalten entspricht der Spec.
  Remediation: Hinweis auf Buchstaben oder Ziffern aendern; nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: .github/workflows/ci.yml:160
  Description: docs/specs/ci/ui-test-job-in-zwei-haelften.md nennt noch drei Teile; falls Branch-Protection Pflicht-Checks nach Namen fuehrt, fehlt ui-test (D) (nicht pruefbar).
  Spec requirement: AC-14 — Teil D, A und C unveraendert
  Conflict: Nur Doku oder Einstellung, kein Codefehler.
  Remediation: Doku beim Abschluss nachziehen, Branch-Protection pruefen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Begruendung: Alle 14 Punkte belegt (eigener Lauf 56 von 56 gruen, 6 von 6 Strukturtests gruen, ci.yml, .strings und pbxproj ohne Fehler); nur zwei LOW-Befunde; die 2 roten ConsumptionPatternTests sind am Basisstand identisch (Issue 231).

## Geprüfte Dateien

- sha256:c398a23820f09e60b045b602bb5c40ff07f5c41167aaf002a8fecfbfb6dafe69  .github/workflows/ci.yml
- sha256:af55a3df099f3edc26d1f94b91667d0beb5ea3c5e4b7dcce6a9f9bc07171a76f  SmartCart/Models/StoreCategories.swift
- sha256:2cc6e55308eba43a0e75b5bba4197f1602452adf7589c8c6e2f3df1c08f862f1  SmartCart/Models/StoreTemplates.swift
- sha256:f5bf5c8eff33fb77065de752e5b9e28fd41744b2c6aede768cc8cfa3b60bfdb7  SmartCart/Views/Store/StationSetupView.swift

## Prüfbasis

- base: 9ee68452809cb0f20f994508e387dca58d802efc
- blob:eab20d1f4554d8b7a0028834e4ea82e7155c97c0  .github/workflows/ci.yml
- blob:66592f5888d6ff969a62a489db2f0392495494d7  SmartCart/Models/StoreCategories.swift
- blob:29b1e65548dfc701815dbdf0cbf18ed7061d9d69  SmartCart/Models/StoreTemplates.swift
- blob:6e0d3b4256132f346b9c076c408f8604ad6b7b4f  SmartCart/Views/Store/StationSetupView.swift
