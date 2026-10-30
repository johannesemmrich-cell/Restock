# Adversary-Dialog: feat-175-b3-betrieb (Teil Screenshots)

Umfang: AC-1, AC-2, AC-3 (= AC-16 der Haupt-Spec), AC-7 nur für den Screenshot-Upload, Aufnahme-Test. Nicht Teil dieser Runde, weil spätere Schritte von B3 und noch nicht erledigt: AC-4 (Käufe), AC-5 (Build 37), AC-6 (Datenschutzseite), AC-8 (Abschlusslauf).

### Runde 1

Confirmation (AC-1, Maße):
Code reference: docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
Evidence: `sips` meldet de 01–05 und en 01–07 mit 1320×2868; screenshots-6-3 (de 5, en 3) mit 1206×2622. Hochgeladen: de 01–05, en 01-start, 03-schnell-hinzufuegen, 06-artikel-hinzufuegen.
Status: CONFIRMED

Confirmation (AC-1, Aufnahme-Test):
Code reference: RestockUITests/StoreScreenshotCaptureUITests.swift
Evidence: Der Test überspringt sich ohne `RESTOCK_STORE_SHOTS_DIR` (läuft nie in CI), räumt im tearDown mit allen passenden Clear-Argumenten auf und benutzt nie `-developerMode`.
Status: CONFIRMED

Confirmation (project.pbxproj):
Code reference: Restock.xcodeproj/project.pbxproj
Evidence: Die Datei steht in genau 4 Zeilen (PBXBuildFile, PBXFileReference, Gruppe RestockUITests, Sources-Phase), UUIDs eindeutig.
Status: CONFIRMED

Confirmation (AC-3/AC-16, GET-only-Zaun):
Code reference: scripts/asc_check.py
Evidence: `sec_screenshots` und `check_shot_set` benutzen nur lesende GETs, `scripts/asc_lib.py` ist unverändert, der Display-Typ ist nur Anzeige, ein leeres Set ist eine Abweichung.
Status: CONFIRMED

Confirmation (AC-3/AC-16, Beleg):
Code reference: docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
Evidence: Lauf 2026-10-29T16:45:02Z: de 5 Bilder 1206×2622 und 5 Bilder 1320×2868, en je 3 Bilder, alle COMPLETE, Exit 0.
Status: CONFIRMED

### Runde 2

Finding F001:
Severity: MEDIUM
Category: edge_case
Code reference: scripts/asc_check.py
Description: Der Prüfer wertete `assetDeliveryState` nicht aus; ein Bild mit gültigem Maß, aber Zustand FAILED galt als ok.
Spec requirement: AC-3/AC-16.
Remediation: Set nur ok, wenn alle Bilder COMPLETE sind. Behoben, siehe Runde 3.

Finding F002:
Severity: LOW
Category: spec_violation
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md
Description: Herkunft der 1206×2622-Bilder (Skalierung mit `sips`, Abweichung 0,1 %) stand nirgends.
Remediation: Changelog und Aufnahmeprotokoll ergänzen. Behoben.

Finding F003:
Severity: LOW
Category: spec_violation
Code reference: docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
Description: Die Bildpfade der Vorschau zeigten auf einen nicht vorhandenen Ordner.
Remediation: Pfade auf `../feat-175-app-store-auftritt/screenshots/` ändern. Behoben. Die veröffentlichte Artefakt-Seite behält ihre eigenen Pfade und bleibt unverändert.

Finding F004:
Severity: MEDIUM
Category: edge_case
Code reference: docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
Description: Hennings getippte Freigabe und der Upload waren nur im Gesprächsverlauf belegt.
Remediation: Abschnitt „Freigabe und Upload (AC-7)“ ergänzt. Der Upload-Zeitpunkt ist nicht exakt belegt (Eingrenzung: vor der ersten Abfrage, die Bilder fand, 2026-10-29T15:07:16Z). Offene Grenze bleibt: die Wortzeile steht nur im Gesprächsverlauf und im Protokoll, nicht in einem maschinellen Beleg.

Finding F005:
Severity: LOW
Category: edge_case
Code reference: scripts/asc_check.py
Description: Der Prüfer erkennt weder Duplikate noch Reihenfolge noch falsche Bildsprache.
Remediation: In „Known Limitations“ der Spec aufgenommen. Behoben.

### Runde 3

Confirmation (F001):
Code reference: scripts/asc_check.py
Evidence: Neuer Test `test_screenshots_valid_size_needs_complete_state`: 1320×2868 mit FAILED oder UPLOAD_COMPLETE ergibt Abweichung, mit COMPLETE ok. Vor dem Code war der Test rot (1 Fehlschlag), danach grün. Eigener Lauf: test_asc_check 47 OK, test_asc_texts 10 OK, test_asc_scripts 28 OK.
Status: CONFIRMED

Confirmation (F002 bis F005):
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md
Evidence: Changelog 2026-10-29 und „Known Limitations“ ergänzt; Aufnahmeprotokoll hat den Abschnitt zu Freigabe und Upload; in `vorschau-bilder.html` kommt `src="bilder/` nicht mehr vor.
Status: CONFIRMED

Offene Grenzen: Der Prüfer ist bei einem leeren Set und bei unbekannten Zuständen nicht gegen echte Antworten geprüft. Wort und Upload für AC-7 sind nur im Protokoll und im Gesprächsverlauf belegt. Der Aufnahme-Test wurde vom Prüfer nur gelesen, nicht ausgeführt.

VERDICT: VERIFIED

### Runde 4

Eigene Läufe: scripts/test_asc_check.py 47 OK, scripts/test_asc_texts.py 10 OK, scripts/test_asc_scripts.py 28 OK (0 Fehlschläge, 0 übersprungen). Keine Netzabfragen; nur abgelegte Belege gelesen.

Confirmation (AC-4, Preise, IDs, Gruppe):
Code reference: scripts/asc_check.py:24
Evidence: PRICES = lifetime 14.99, monthly 1.99, yearly 8.99; check_price (Zeile 289-302) verlangt genau einen zum Stichtag gültigen Betrag gleich dem Soll, state READY_TO_SUBMIT (Zeile 309), lifetime NON_CONSUMABLE (Zeile 308), "fremdes Produkt" und "doppeltes Produkt" schlagen fehl (Zeile 260-263), also kein sharedlists in ASC. asc-readback-iap-lifetime.txt (2026-10-30T08:56:42Z) zeigt alle Zeilen ok: Gruppe "Restock Pro", drei Produkte mit richtigem Typ, Preis (DEU), Lokalisierung de/en, Review-Screenshot. Die Zwischenstände monthly (07:56Z) und yearly (08:24Z) zeigen erwartbar "lifetime fehlt"; die Zeitfolge ist stimmig. Produkt-IDs in PremiumService.swift:124-126 und Restock.storekit (productID, displayPrice 1.99/8.99/14.99) stimmen mit dem Präfix plus monthly/yearly/lifetime überein.
Status: CONFIRMED

Confirmation (AC-6):
Code reference: docs/artifacts/feat-175-b3-betrieb/asc-readback-privacy-url.txt
Evidence: HTTP-Status ok, Abschnitt Deutsch 42 Zeilen, English 43 Zeilen ok; im Abschlusslauf (asc-readback.txt) erneut ok. Der Prüfer verlangt jede Zeile aus docs/appstore/datenschutz.md.
Status: CONFIRMED

Confirmation (AC-8):
Code reference: docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt
Evidence: Kopf 2026-10-30T08:57:24Z, Commit c8198fe (Commit-Zeit 08:57:17Z, stimmig); alle Abschnitte ok, appVersionState geprüft, Zeile "offen AC-14" erwartet. Beleg ac14-app-datenschutz-beleg.jpg gelesen: sieben Datentypen (Fotos und Videos, Einkaufsverlauf, Sonstige Benutzerinhalte, Name, Geräte-ID, Ungefährer Standort, Benutzer-ID), deckungsgleich mit der Manifest-Liste in CLAUDE.md. Tests siehe oben grün.
Status: CONFIRMED

Finding F006:
Severity: MEDIUM
Category: spec_violation
Code reference: scripts/asc_check.py:305
Description: check_product liest weder Abo-Laufzeit (recurringSubscriptionPeriod) noch Abostufe (groupLevel). Restock.storekit legt monthly = P1M, Stufe 2 und yearly = P1Y, Stufe 1 fest. Ein vertauschter oder falscher Zeitraum in ASC (z. B. "monthly" mit 1 Jahr zu 1,99 EUR) würde als ok gelesen.
Spec requirement: AC-4 — Käufe entsprechen AC-15 (Monatsabo 1,99, Jahresabo 8,99); Preise sind nur mit passendem Zeitraum sinnvoll.
Conflict: Laufzeit und Stufe sind nur Hennings Angabe (bekannte Grenze 1), nicht per Beleg abgedeckt.
Remediation: Im Betrieb darf das Werkzeug nicht geändert werden; als offene Grenze melden oder in einem Folgedurchgang subscriptionPeriod/groupLevel lesen, alternativ Screenshot der Abo-Seite aus ASC als Beleg ablegen.

Finding F007:
Severity: MEDIUM
Category: spec_violation
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md:122
Description: AC-5 nennt als Schemabeleg docs/artifacts/feat-175-b3-betrieb/cloudkit-schema-check.txt aus dem Ablauf cloudkit-schema.yml (mode=export). Vorhanden ist stattdessen cloudkit-schema-pruefung.md, eine Prosa-Zusammenfassung eines lokalen cktool-Exports; rohe Ausgabe oder Diff liegt nicht im Repo. "Kein Unterschied" ist damit eine Behauptung des Berichtenden. Der Vergleich des App-Codes erfolgt gegen origin/main, nicht gegen den Commit des hochgeladenen Builds.
Spec requirement: AC-5 — Schemacheck als Protokoll mit Export-Diff Development/Production.
Conflict: Dateiname, Quelle (lokal statt Workflow) und Rohbeleg weichen von der Spec ab.
Remediation: Rohe Diff-Ausgabe (leer, mit Zeit und Commit) als cloudkit-schema-check.txt ablegen oder die Spec per Changelog auf die tatsächliche Form anpassen.

Finding F008:
Severity: MEDIUM
Category: spec_violation
Code reference: docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt:149
Description: Der Abschnitt "Freigabe und Upload (AC-7)" gibt es nur für den Screenshot-Upload. Für Build-Upload, die drei Käufe und die Build-Zuordnung steht Hennings Wort nur im Gesprächsverlauf; im Belegverzeichnis fehlen Zeit und Wortlaut je Schritt. Auch die Upload-Zeit des Builds ist nirgends festgehalten (testflight-was-testen-build37.txt nennt nur Build-ID und VALID).
Spec requirement: AC-7 — Protokoll im Belegverzeichnis nennt je Schritt Zeit und Wort.
Conflict: Der Nachweis für Build-Upload, Käufe und Zuordnung ist nicht im Repo.
Remediation: Abschnitt je Schritt mit Zeit und Wortlaut aus dem Verlauf ergänzen (bleibt Selbstauskunft, kein maschinelter Beleg).

### Runde 5

Confirmation (AC-5 Build):
Code reference: docs/artifacts/feat-175-b3-betrieb/asc-readback-build-4.txt
Evidence: 2026-10-30T07:45:49Z, build zugeordnet, version, processingState VALID, usesNonExemptEncryption ok; im Abschlusslauf wiederholt. Aber der Prüfer verlangt nur version >= 37 (asc_check.py:375); Build 38 bestünde ebenso. Die Build-ID aus testflight-was-testen-build37.txt (f3ba0068-..., VALID, Build 37) steht nicht im Lesebeleg; die Zuordnung zu genau dieser ID ist nur durch Zusammenschau belegt.
Status: CONFIRMED

Finding F009:
Severity: LOW
Category: edge_case
Code reference: scripts/asc_check.py:375
Description: Build-Prüfung verlangt "mindestens 37" statt genau der hochgeladenen Nummer. Lesedateien build-2/-3/-4 zeigen mehrere Anläufe; der gültige Lauf ist nur am späteren Zeitstempel erkennbar. Der Abschlusslauf (08:57Z) liegt vor dem Setzen des "Was testen?"-Texts (Commit 72caebc, 09:00Z); der Text selbst ist per testflight-was-testen-build37.txt zurückgelesen.
Spec requirement: AC-5 — Build 37 zugeordnet.
Conflict: Schwacher Soll-Ist-Vergleich; im Ist-Zustand kein Fehler sichtbar.
Remediation: Als bekannte Grenze führen.

Finding F010:
Severity: LOW
Category: edge_case
Code reference: docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg
Description: Der AC-14-Beleg ist vom 2026-10-28 (Dateizeit 21:28, "vor 19 Stunden veröffentlicht"), nicht vom Schlusslauf. Inhalt passt (sieben Datentypen).
Spec requirement: AC-8 — Beleg-Screenshot liegt vor.
Conflict: Aktualität nicht von heute; die Spec verlangt nur Vorhandensein.
Remediation: Akzeptabel; als Grenze nennen.

Bewertung der bekannten Grenzen: (1) Abostufen: echte Lücke, siehe F006. (2) Gekürzte Einmalkauf-Beschreibung: Prüfer prüft nur Vorhandensein (asc_check.py:315); inhaltlich unproblematisch, aber nicht belegt. (3) Wortfreigaben: siehe F008. (4) Siehe F010. (5) Gerade Anführungszeichen: wortgleich übernommen, vom Prüfer als gleich bestätigt, kosmetisch, kein Finding.

Nicht per Beleg nachweisbar durch Henning: Abostufen und Laufzeit; Wortfreigaben für Build, Käufe und Zuordnung; Inhalt der Kauftexte; Inhalt der Review-Screenshots je Kauf (nur Vorhandensein); Gerätetest mit Build 37; Paywall ohne Rechtslinks (#215).

VERDICT: AMBIGUOUS

### Runde 6

Gelesen: asc-readback-abo-laufzeit-stufe.txt, cloudkit-schema-check.txt, freigaben-ac7.md, Spec-Changelog (zwei Einträge vom 2026-10-30). Kein Netz, keine Änderung. Der Diff-Vergleich von SmartCart/ gegen 1b190c8 ist leer (selbst geprüft).

Confirmation (F006, Laufzeit):
Code reference: docs/artifacts/feat-175-b3-betrieb/asc-readback-abo-laufzeit-stufe.txt
Evidence: Lesung 09:03:11Z: monthly ONE_MONTH, yearly ONE_YEAR, READY_TO_SUBMIT, Gruppe "Restock Pro". Preis und Laufzeit passen damit zusammen. Die Stufe ist ehrlich als Abweichung benannt: beide Stufe 1, Restock.storekit hat 2/1 (Zeilen 77, 103), die Spec-Nachtrag-Entscheidung nennt die Abweichung ausdrücklich. Der Prüfer liest Laufzeit und Stufe weiter nicht (Known Limitation), die Lesung ist ein Einzelbeleg ohne Wiederholbarkeit im Werkzeug.
Status: CONFIRMED

Confirmation (F007):
Code reference: docs/artifacts/feat-175-b3-betrieb/cloudkit-schema-check.txt
Evidence: Rohausgabe "Repo-Datei gegen Development: kein Unterschied; Development gegen Production: kein Unterschied". Build-Commit 1b190c8 (Lauf 40926284358) und leerer Diff von SmartCart/ gegen 1b190c8 schließen die Code-Lücke. Abweichung vom Workflow cloudkit-schema.yml ist im Changelog begründet. Es fehlt ein Zeitstempel in der Rohdatei (Datum nur im Pruefungs-Bericht vom 2026-10-29), und die Account-Zeilen sind Teil der Ausgabe; unkritisch.
Status: CONFIRMED

Confirmation (F008):
Code reference: docs/artifacts/feat-175-b3-betrieb/freigaben-ac7.md
Evidence: Je Schritt Wort, Eingrenzung durch Lesebelege und Build-Lauf; Build-Zuordnung ehrlich als eigenes Handeln von Henning ohne getipptes Wort ausgewiesen, Wortzeilen als Selbstauskunft gekennzeichnet. Das erfüllt AC-7 nicht streng ("Zeit und Wort" je Schritt: Zeiten nur als Fenster, Wortlaut nur aus dem Verlauf), ist aber offen als Grenze benannt. Nichts eingereicht: asc_check status PREPARE_FOR_SUBMISSION im Abschlusslauf. Die Aussage zum Build-Upload (Lauf, Zeit, Commit) lässt sich nur per gh prüfen, was ich nicht ausführen durfte.
Status: CONFIRMED

Finding F011:
Severity: LOW
Category: spec_violation
Code reference: docs/specs/appstore/b3-betrieb-restschritte.md:80
Description: Schritt 6 der Implementation Details und AC-4 setzen Abostufen nicht fest, aber die Abweichung zu Restock.storekit (2/1) wurde als Tech-Lead-Entscheidung im Changelog getroffen, ohne PO-Wort. Wirkung: Bei gleicher Stufe gilt Wechsel Monat/Jahr als Crossgrade statt Upgrade; Zeitpunkt des Wirksamwerdens folgt Apple-Regeln, nicht der lokalen Testdatei. Das ist eine Produktauswirkung, die Henning nur beiläufig per Auswahl bestätigt hat.
Spec requirement: AC-4 — Käufe wie AC-15 der Haupt-Spec.
Conflict: Wirkung bei echtem Wechsel nicht geprüft (kein Sandbox-Test).
Remediation: Als offene Grenze in die Abschlussmeldung; Verhalten im TestFlight/Sandbox erst auf Hennings Wort prüfen.

F009 und F010: als Grenze eingeordnet (Build nur ">= 37" plus Build-ID im Beleg, AC-14-Screenshot vom 28.10. mit passendem Inhalt); beide ehrlich benannt, kein Codewechsel nötig.

Offen: Abostufen-Wirkung (F011), Wortfreigaben nur im Gesprächsverlauf, Prüfer liest Laufzeit/Stufe nicht, Gerätetest, Paywall-Rechtslinks (#215). Keine CRITICAL/HIGH-Findings.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:5997f3487763ef4c8e2e72b119a12ff4b5ae48018c5b6d7a1cc98f7f2c3f43b6  Restock.xcodeproj/project.pbxproj
- sha256:16fb86de17f79b6bd9855f167ec72cb3dae0b063607b888538ec5332693cfd61  RestockUITests/StoreScreenshotCaptureUITests.swift
- sha256:d6cd3c7d0a42c8b81d4756235a802ed26b6b4272e2ae93e907f25d4060e15727  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- sha256:f0975313db8912f84db9d71dfd44606bfe5cd25ebf85c9642552691e84217778  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- sha256:3171632cd53cfb7e70ef9365c571f11a51ffd0973a38c0e99a73d120a642e7db  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- sha256:a13eb6312f9b31e081e1270de4bc7a746181546a733ae9357d687f3830f9c489  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- sha256:d273d8dea08972a8883ebee15a182345d8e2e46d23d9f1ce0c0f986b2a0c53d4  docs/specs/appstore/b3-betrieb-restschritte.md
- sha256:129cf1f9ad503143413cef4d4b22386c4946ef6e3f301a6a74eaba00d13d2dd3  scripts/asc_check.py

## Prüfbasis

- base: 1b190c854ee66d4bccebd4a98bb6ec6dc375ced3
- blob:6ac468fd87dfbaca711dadc385bfec95ff6ad3f9  Restock.xcodeproj/project.pbxproj
- blob:c4e8f7863b6583dd37d570fb92add140f0381404  RestockUITests/StoreScreenshotCaptureUITests.swift
- blob:cef4f2be6f4b6dcd7c0ebca7c1638c7781b642b2  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- blob:2fb598196b5f8f553d73d76287fa32fb0509ebfd  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- blob:7212b84b32b90e06d0961f1b97f25a1dd094abf1  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- blob:94d01eed4c2139f268882704c82db2026b19f7be  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- blob:e52c14cc7a0ba3e8357b78dca6a122f9857d693c  docs/specs/appstore/b3-betrieb-restschritte.md
- blob:e559230ba2e9dc0e3415ccc848ccf2efa2629db1  scripts/asc_check.py

## Geprüfte Dateien

- sha256:5997f3487763ef4c8e2e72b119a12ff4b5ae48018c5b6d7a1cc98f7f2c3f43b6  Restock.xcodeproj/project.pbxproj
- sha256:16fb86de17f79b6bd9855f167ec72cb3dae0b063607b888538ec5332693cfd61  RestockUITests/StoreScreenshotCaptureUITests.swift
- sha256:16bf5ae944a04a15516069e98b2985f7277e1b2fa887a937d6bdec24c3f1465a  docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg
- sha256:bd5b17c62a1dbdb454edb529054c5ff4a9fcf55b02314d22acaa7f2a024bef1a  docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt
- sha256:d6cd3c7d0a42c8b81d4756235a802ed26b6b4272e2ae93e907f25d4060e15727  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- sha256:35850405368ffa1e559e139cad7146783bfc36151d8d88f4053d18d465e0f45e  docs/artifacts/feat-175-b3-betrieb/asc-readback-abo-laufzeit-stufe.txt
- sha256:9525a877f3f2b798faaf33091f7600e036a356678bdf1bc4e81419373a5ea1fd  docs/artifacts/feat-175-b3-betrieb/asc-readback-build-4.txt
- sha256:56a8e75a94cbdf55e2d6c76affe29b8a2360e6cbfbe49bf4f77efe87ce4d15d6  docs/artifacts/feat-175-b3-betrieb/asc-readback-privacy-url.txt
- sha256:f0975313db8912f84db9d71dfd44606bfe5cd25ebf85c9642552691e84217778  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- sha256:956cf6faaed7e22b30d48bd4e90568f948411290d8571aee4b503a7e86ff9659  docs/artifacts/feat-175-b3-betrieb/cloudkit-schema-check.txt
- sha256:034e28cbda4635577e4f42bcb5ee6c24780aa1f9179ae6264ce85f6eec63474f  docs/artifacts/feat-175-b3-betrieb/freigaben-ac7.md
- sha256:3171632cd53cfb7e70ef9365c571f11a51ffd0973a38c0e99a73d120a642e7db  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- sha256:a13eb6312f9b31e081e1270de4bc7a746181546a733ae9357d687f3830f9c489  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- sha256:66f49e54f786e1137aa656f028caca6e777e0c7b152e7add78dceb6300aafed5  docs/specs/appstore/b3-betrieb-restschritte.md
- sha256:129cf1f9ad503143413cef4d4b22386c4946ef6e3f301a6a74eaba00d13d2dd3  scripts/asc_check.py

## Prüfbasis

- base: 1b190c854ee66d4bccebd4a98bb6ec6dc375ced3
- blob:6ac468fd87dfbaca711dadc385bfec95ff6ad3f9  Restock.xcodeproj/project.pbxproj
- blob:c4e8f7863b6583dd37d570fb92add140f0381404  RestockUITests/StoreScreenshotCaptureUITests.swift
- blob:7e1f46bd8e17a8470fc0d42d8d20c0a50f30e69d  docs/artifacts/feat-175-app-store-auftritt/ac14-app-datenschutz-beleg.jpg
- blob:68c39eb201b05187cf63d300e90ef825dbe95248  docs/artifacts/feat-175-app-store-auftritt/asc-readback.txt
- blob:cef4f2be6f4b6dcd7c0ebca7c1638c7781b642b2  docs/artifacts/feat-175-app-store-auftritt/screenshots/de/01-start.png
- blob:537cb57ccb6ace10a49f86138553c34024b1f393  docs/artifacts/feat-175-b3-betrieb/asc-readback-abo-laufzeit-stufe.txt
- blob:dd61ad1ebaea68b927be477b9cc47c1a91248b1e  docs/artifacts/feat-175-b3-betrieb/asc-readback-build-4.txt
- blob:823240bd0b1911bc57ab989d527f43156b9b71a6  docs/artifacts/feat-175-b3-betrieb/asc-readback-privacy-url.txt
- blob:2fb598196b5f8f553d73d76287fa32fb0509ebfd  docs/artifacts/feat-175-b3-betrieb/asc-readback-screenshots.txt
- blob:e7ac06cc2dd1912190895a327c3fe5679e42c734  docs/artifacts/feat-175-b3-betrieb/cloudkit-schema-check.txt
- blob:96980286c7b27a5ee599aa70b05b00abd3d6fd8c  docs/artifacts/feat-175-b3-betrieb/freigaben-ac7.md
- blob:7212b84b32b90e06d0961f1b97f25a1dd094abf1  docs/artifacts/feat-175-b3-betrieb/screenshots-aufnahme.txt
- blob:94d01eed4c2139f268882704c82db2026b19f7be  docs/artifacts/feat-175-b3-betrieb/vorschau-bilder.html
- blob:1cbb7f37db45bf5fb92932c4dbecbaae6e22ff20  docs/specs/appstore/b3-betrieb-restschritte.md
- blob:e559230ba2e9dc0e3415ccc848ccf2efa2629db1  scripts/asc_check.py
