# Adversary Dialog — feat-241-kopfbild
Spec: docs/specs/appstore/kopfbild.md
Datum: 2026-11-06 07:16

## Checkliste
- [x] AC-1: `scripts/make-header-image.sh de` erzeugt `docs/artifacts/feat-241-kopfbild/kopfbild-de-5244x2950.png` und `kopfbild-de-3840x1646.png` mit exakt diesen Pixelmaßen.
- [x] AC-2: Dasselbe für `en` (`kopfbild-en-5244x2950.png`, `kopfbild-en-3840x1646.png`).
- [x] AC-3: Keines der vier PNGs hat einen Alphakanal (Farbtyp ohne Alpha, geprüft im Strukturtest).
- [x] AC-4: Der sichtbare Text der deutschen Fassung enthält wörtlich „Die Liste, die weiß, wo etwas hingehört.“ und die Unterzeile aus der PO-Entscheidung; der Text steht in der Vorlage genau einmal je Sprache (Strukturtest).
- [x] AC-5: Aller Text und alle Kartenzeilen liegen innerhalb des Sicherheitsbereichs (mittlere 76 % Höhe, mittlere 84 % Breite) in beiden Größen; geprüft per Messung der Elementrahmen im gerenderten Dokument (Chrome `--dump-dom` mit Messskript) oder, falls nicht möglich, durch Pixelprüfung, dass außerhalb des Bereichs nur die Hintergrundfarbe vorkommt.
- [x] AC-6: Beide Zuschnitte, Seitenkopf 21:9 und Suchkarte 3:2, werden als Bild gegen die gerenderte 16:9-Fassung gelegt und dem PO vor dem Upload gezeigt (Artefakt-Vorschau); nichts Wichtiges ist abgeschnitten.
- [x] AC-7: Die Farben der Vorlage stimmen mit den Hellwerten von `RCCanvas`, `RCSurface`, `RCAccent` in den Colorsets überein (Strukturtest vergleicht).
- [x] AC-8: Ein Beleg zum Upload-Weg liegt im Repo (`docs/artifacts/feat-241-kopfbild/upload-weg.md`): ob die API einen Pfad kennt, mit Quelle.
- [x] AC-9: Hochgeladen wird erst nach getipptem Wort des PO („Upload jetzt“); eingereicht wird nichts. Der Nachweis nach dem Upload ist ein Screenshot der Seite in App Store Connect mit Bild in beiden Sprachen, abgelegt unter `docs/artifacts/feat-241-kopfbild/`.

## Dialog

### Runde 1
**Adversary:** Kernbehauptungen unabhängig nachgemessen, nicht dem Skript geglaubt.
- AC-1/AC-2/AC-3: PNG-Header selbst gelesen (Python struct, Chunk-Liste) und mit sips/PIL gegengeprüft. Ergebnis: de/en je 5244x2950 und 3840x1646, Bittiefe 8, Farbtyp 2, Chunks nur IHDR, sRGB, eXIf, IDAT, IEND; kein tRNS, kein Alpha. Auch zuschnitt-vorschau.png ist Farbtyp 2.
Code reference: scripts/make-header-image.sh:86
Code reference: scripts/header-image/strip-alpha.swift:41
- AC-4: Pflichttexte stehen je Sprache genau einmal in der Vorlage (Test test_texts_appear_exactly_once_per_language; 6 Tests, 0 übersprungen). Der gerenderte sichtbare Text (--dump-dom im Render-Protokoll, nach meinem Neulauf unverändert) enthält Satz und Unterzeile wörtlich, de und en.
Code reference: scripts/header-image/kopfbild.html:70
Code reference: scripts/test_header_image.py:52
- AC-5: eigene Pixelprüfung mit PIL (Bounding-Box aller Pixel ungleich #F5F2E9, auch mit Schwelle >2, damit der weiche Kartenschatten mitzählt) gegen 8/92 % Breite und 12/88 % Höhe. 16:9 (de): Bbox (471,425)-(4754,2281), Abstände links 51, rechts 70, oben 71, unten 315 px; en unten 298. 21:9: Bbox (720,236)-(3110,1282), Abstände links 413, rechts 423, oben 38, unten 166. Englische Fassung und 21:9 eingeschlossen: nichts außerhalb. Knappste Stelle oben im 21:9-Bild (38 px), aber im Bereich.
Code reference: scripts/header-image/kopfbild.html:29
Code reference: scripts/header-image/strip-alpha.swift:40
- AC-6: zuschnitt-vorschau.png angesehen. Zuschnittmaße nachgerechnet: 21:9 aus 16:9 schneidet 351,5 px = 11,92 % oben/unten, 3:2 schneidet 409,5 px = 7,81 % je Seite (Vorlage: 11,89 % und 7,81 %). Gemessener Inhalt liegt in beiden Zuschnitten vollständig innen (de und en). Beide Sprachen sind in der Vorschau, Sicherheitsbereich rot gestrichelt.
Code reference: scripts/header-image/zuschnitt.html:18
Code reference: scripts/header-image/zuschnitt.html:19
- AC-7: Colorsets gelesen: RCCanvas 0,961/0,949/0,914 = #F5F2E9, RCSurface 0,992/0,984/0,957 = #FDFBF4, RCAccent 0,400/0,435/0,220 = #666F38; gleich den Variablen der Vorlage (Hellwerte, Eintrag ohne appearances). Der Test vergleicht per Teilstring.
Code reference: scripts/header-image/kopfbild.html:17
Code reference: scripts/test_header_image.py:58
- AC-8: OpenAPI-Datei im Scratchpad (Zip-SHA-256 f41ed448... wie im Beleg, info.version 4.6, 1027 Pfade) selbst ausgewertet: AppAssetLibraryPlacementType enthält PRODUCT_PAGE_HEADER_ASSET und APP_STORE_SEARCH_RESULTS_ASSET; Kategorien CREATIVE_ASSETS/APP_SCREENSHOTS_AND_PREVIEWS; die Pfade GET /v1/apps/{id}/assetLibrary, POST /v1/appAssetLibraryImages, GET/PATCH/DELETE /v1/appAssetLibraryImages/{id}, POST /v1/appAssetLibraryPlacements, GET /v1/appStoreVersionLocalizations/{id}/placements, GET /v1/appAssetLibraryRefData existieren; Create-Request verlangt fileName/fileSize/category und Beziehung assetLibrary, Placement-Request kennt appStoreVersionLocalization; uploadOperations, uploaded im Update-Request, imageSpecs/alphaAllowed/aspectRatio und Zustände bis IN_REVIEW/APPROVED/REJECTED vorhanden. Alle Behauptungen des Belegs stimmen. Der Beleg nennt Version 4.6 offen statt 4.5.1.
Code reference: docs/artifacts/feat-241-kopfbild/upload-weg.md:21
- AC-9: Diff von scripts/asc_lib.py gegen HEAD leer; Suche nach curl/wget/http(s)/appstoreconnect/asc_lib/urllib/requests in Skript, Vorlagen, Swift-Helfer und Test: keine Treffer. Die Vorlage bindet nur eine relative lokale Bilddatei ein. Hochgeladen oder eingereicht wurde nichts. Der Nachweis-Screenshot nach dem Upload steht aus, richtig, weil das Wort des PO fehlt.
Code reference: scripts/make-header-image.sh:37
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Wiederholbarkeit und Randfälle.
- scripts/make-header-image.sh de neu ausgeführt: Exit 0, alle Prüfungen bestanden. SHA-256 aller vier PNGs vor und nach dem Lauf identisch (deterministisch). Der Arbeitsbaum zeigt danach nur die bekannten ungetrackten Dateien plus mein adversary-test-output.txt; kein getrackter Pfad geändert. Das Skript nutzt ein eigenes Chrome-Profil, das laufende Chrome des Nutzers (Prozess 1218, Version 155) blieb unberührt.
Code reference: scripts/make-header-image.sh:37
- Abbruchwege: Maßprüfung, Farbtyp-2-Prüfung, outside_non_bg=0 und DOM-Messung brechen mit exit 1 ab (Zeilen 80, 86, 89ff.); die Eckfarbe wird gegen #F5F2E9 geprüft.
Code reference: scripts/make-header-image.sh:80
- Test: python3 -I scripts/test_header_image.py -v, Ausgabe in adversary-test-output.txt: Ran 6 tests, OK, 0 übersprungen, 0 Fehler.
Code reference: scripts/test_header_image.py:63
- Grenzfälle: Inhaltsfläche = min(0,84 W, 0,76 H mal Seitenverhältnis), daher bleibt 21:9 innerhalb (413 px seitlich); englischer Text (längere Preiszeile) bricht die Karte nicht (Bild angesehen).
Code reference: scripts/header-image/strip-alpha.swift:40
- Schwächen ohne Verstoß gegen ACs: (a) Inhalt sitzt oben dicht, unten weit offen (16:9 oben 71, unten 298 bis 315 px; 21:9 oben 38, unten 166). (b) Im 21:9-Bild belegt der Inhalt nur 62 % der Breite. (c) Strukturtest prüft Texte nur in der Vorlage, nicht im Render; das deckt das Render-Protokoll. (d) Farben nur als Teilstring. (e) upload-weg.md nennt keinen dauerhaften Pfad der OpenAPI-Datei; die Hash-Angabe macht es prüfbar.
Code reference: scripts/header-image/kopfbild.html:26
**Implementierer:** (nicht beteiligt, Kontextisolation)

## Structured Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/header-image/kopfbild.html:29
  Description: Inhalt in der Inhaltsfläche oben angelegt (feste obere Abstände). Gemessen oben 71 px / unten 298-315 px (16:9), oben 38 / unten 166 (21:9).
  Spec requirement: AC-5 (Inhalt im Sicherheitsbereich)
  Conflict: Kein Verstoß (alles innen), nur ungleiche Ränder; im 21:9-Bild oben knapp.
  Remediation: Optional vertikal mittig setzen; Entwurf war so freigegeben, nur Hinweis.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_header_image.py:58
  Description: Test AC-7 prüft Hexwerte als Teilstring, nicht ihre Verwendung; AC-4 nur in der Vorlage, nicht im Render.
  Spec requirement: AC-4, AC-7
  Conflict: Spec fordert genau diese Strukturprüfung; Render-Beweis liegt im Protokoll, nicht im CI.
  Remediation: Keine nötig.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-241-kopfbild/upload-weg.md:8
  Description: Beleg nennt OpenAPI 4.6 statt 4.5.1 und keine dauerhaft im Repo liegende Datei. Alle inhaltlichen Aussagen nachgeprüft richtig.
  Spec requirement: AC-8 (Quelle)
  Conflict: URL, Datum und Hash genannt, damit erfüllt.
  Remediation: Keine nötig.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/make-header-image.sh:19
  Evidence: Maße der de-PNGs selbst gelesen, nach Neulauf unverändert (gleiche SHA-256).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/make-header-image.sh:86
  Evidence: en-PNGs 5244x2950 und 3840x1646, Farbtyp 2.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/header-image/strip-alpha.swift:41
  Evidence: Chunk-Liste ohne tRNS, Farbtyp 2, sips ohne Alpha.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/header-image/kopfbild.html:70
  Evidence: Texte genau einmal in der Vorlage, sichtbarer Text im DOM wörtlich.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/header-image/kopfbild.html:29
  Evidence: eigene PIL-Bbox inkl. Schatten innerhalb 8/92 % und 12/88 % in vier Bildern.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/header-image/zuschnitt.html:18
  Evidence: Vorschau vorhanden, Zuschnitte 11,9 % und 7,8 % nachgerechnet, Inhalt innen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/header-image/kopfbild.html:17
  Evidence: Hexwerte gleich den Colorset-Hellwerten.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-241-kopfbild/upload-weg.md:21
  Evidence: alle Pfade und Schemata in openapi.oas.json 4.6 nachgewiesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/make-header-image.sh:37
  Evidence: keine Netzaufrufe, asc_lib unverändert; Upload und Einreichung nicht erfolgt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Produktions-Schreibstellen im Sinn der Tabelle (reine Grafik-Erzeugung).

## Verdict

VERDICT: VERIFIED

Begründung: alle neun ACs mit eigenen Messungen belegt (PNG-Header, PIL-Pixelprüfung inkl. Schatten, OpenAPI-Abgleich, Neulauf mit identischen Hashes). Tests: 6 bestanden, 0 fehlgeschlagen, 0 übersprungen. Nur drei LOW-Hinweise, kein Blocker. Der Upload (Nachweis-Screenshot AC-9) steht planmäßig aus und braucht das Wort des PO.

## Geprüfte Dateien

- sha256:ae8bfe864025bd72c91da2a21e9901c348650c70346618ba402982d664276abf  docs/artifacts/feat-241-kopfbild/upload-weg.md
- sha256:89e235d3d600699cfa91226f1babeefd8916a8c799f04f76eefc75d517894f62  scripts/header-image/kopfbild.html
- sha256:6fb25a4937b17ef8323b0368313665eb50f933d054d6baa00bcee637ac5f8f8d  scripts/header-image/strip-alpha.swift
- sha256:94dbb52f78b2c86032acb558522c2395136f96a89b6eab33717ef7a63ea8fac0  scripts/header-image/zuschnitt.html
- sha256:c6fb2841c9b1ac27163d3535554221c928d43574204552a0e04835c68f9ee757  scripts/make-header-image.sh
- sha256:d7f6b5339c5f9981fbb490e966e8ebb17b29b9b6e6d4bc542932633affd2a529  scripts/test_header_image.py

## Prüfbasis

- base: 6343aef22bae143c0c300c4d68def7c64e960edb
- blob:df207c4847ca742b588e86c9f5d735ee4ab5f563  docs/artifacts/feat-241-kopfbild/upload-weg.md
- blob:48459766f13f56ad7d9890d8b6fbbe54ec2243a6  scripts/header-image/kopfbild.html
- blob:9010c4b37445de86ffe46fb018f43d7f73198c21  scripts/header-image/strip-alpha.swift
- blob:ec635ef0099e642c7dd1b93b6e649a9ae12f0460  scripts/header-image/zuschnitt.html
- blob:f8eb42f4fcf55bf5a3594d84a30d967f50c4fd98  scripts/make-header-image.sh
- blob:a53afbc9769a73330463c353ed051507d6b27ac1  scripts/test_header_image.py
