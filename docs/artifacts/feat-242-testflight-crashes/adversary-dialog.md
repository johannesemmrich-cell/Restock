# Adversary Dialog — feat-242-testflight-crashes
Spec: docs/specs/appstore/asc-crashes.md
Datum: 2026-11-04 12:10

## Checkliste

- [x] AC-1: Lesezaun, drei Aufrufarten, alles andere ValueError — PROVEN (check_read, Fuzz mit 17 Varianten abgelehnt)
- [x] AC-2: ID nur aus Antwort — PROVEN
- [x] AC-3: asc_lib unverändert — PROVEN (git diff leer, Test grün)
- [x] AC-4: json/crash-Dateien 0600, Ordner 0700 (auch bei vorhandenem Ordner 0755 und Datei 0644) — PROVEN
- [x] AC-5: 404/leerer/nicht-String logText nur .json — PROVEN
- [x] AC-6: links.next über Seiten — PROVEN
- [x] AC-7: Fremdhost/Schema/Schleife/>50 Seiten — PROVEN (Userinfo, Port, Backslash, Großschreibung abgelehnt; genau 50 Seiten ok, 51. nie angefragt)
- [x] AC-8: genau 5 Versuche bei 5xx/429/OSError — PROVEN
- [x] AC-9: 4xx sofort, nur code/title — PROVEN (404, 401, 301 je 1 Aufruf)
- [x] AC-10: Log nur Id/Plattform/Datum — PROVEN
- [x] AC-11: safe_field — PROVEN
- [x] AC-12: unzulässige ID — PROVEN (vor jeglichem Schreiben geprüft)
- [x] AC-13: keine Meldungen, Exit 0 — PROVEN
- [x] AC-14: fehlende Konfiguration — PROVEN (echter Unterprozess: Exit 1/2, keine Pfade, kein Traceback)
- [x] AC-15: ci.yml listet Test, python3 -I — PROVEN

Tests: test_asc_crashes 15 OK, test_asc_scripts 28 OK, test_asc_check 47 OK (jeweils python3 -I), 0 übersprungen.

## Dialog

### Runde 1
**Adversary:** Zaun und Netz. Fuzz: doppelter cursor, limit=2000, Zeilenumbruch/Fragment in Abfrage, abschließender Schrägstrich, Großschreibung, %41 in der ID, kleingeschriebenes get, Zusatzabfrage am App-Lookup, '..': alle mit ValueError abgelehnt. links.next mit Userinfo (api...@evil), Port :443, Backslash-Trick, HTTPS-Großschreibung, '//host', Fragment, Nicht-String: alle abgelehnt. links.next auf gültigem Host, aber anderem Pfad (/v1/users, /appInfos, Zusatzparameter include): Zaun wirft vor dem Senden, Exit 1, nur zwei Aufrufe gesendet.
Finding F001: Der ID-Platz im Listenpfad akzeptiert jede bisher gesehene ID, auch eine Meldungs-ID als App-ID (und umgekehrt); IDs sind nicht nach Typ getrennt. Folgenlos, weil Pfadform fest und Apple vertrauenswürdig.
  Severity: LOW, Category: edge_case
  Code reference: scripts/asc_crashes.py:38
  Description: ids ist eine einzige Menge.
  Spec requirement: AC-2 — ID muss aus früherer Antwort stammen (erfüllt wörtlich)
  Conflict: keine Verletzung, nur Härtungslücke
  Remediation: optional getrennte Mengen für App- und Meldungs-IDs
Confirmation:
  AC: AC-1, AC-2
  Code reference: scripts/asc_crashes.py:22
  Evidence: Fuzz und Test; fullmatch auf Pfad und Abfrage, Methode nur GET.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: scripts/asc_crashes.py:81
  Evidence: next_path vergleicht Schema und netloc exakt; Schleife über seen; MAX_PAGES bei Zeile 95, 51 Seiten-Probe sendet genau 51 Aufrufe inkl. App-Lookup, also 50 Seiten.
  Status: CONFIRMED
**Implementierer:** (nicht beteiligt; Entwicklerhinweise bewertet: (a) sys.path.insert: Skriptordner scripts/ enthält keine stdlib-namigen Module, asc_check.py macht es gleich, imports der Standardbibliothek stehen davor; unkritisch. (b) beide Reihenfolgen von limit/cursor: harmlos, weicht nur gering vom Spezialwortlaut ab. (c) führender Punkt verboten: strenger als AC-12-Wortlaut, sicher, Apple-IDs sind UUIDs; akzeptabel. (d) siehe F003.)

### Runde 2
**Adversary:** Dateien, Fehlerpfade, Lecks. Symlink als Zieldatei (<id>.json): O_NOFOLLOW verhindert Schreiben, Opferdatei unverändert. ID '..', '.hid', '', 'a/b', 300 Zeichen: nur unzulässige IDs wirken sauber vor dem Schreiben ab; 300 Zeichen führt zu OSError nach Anlegen des Ordners. Vorhandener Ordner 0755 und Datei 0644 werden auf 0700/0600 gesetzt. Fehlerkörper mit Zeilenumbruch, U+2028 und '::' in code/title: Ausgabe einzeilig, beginnt mit 'Fehler:'. Defekte Antworten (ungültiges JSON, Liste statt Objekt, attributes als String, id als Zahl): Exit 1, Meldung ohne Body, kein Traceback. Unterprozess mit falschem Schlüsselpfad: nur 'openssl-Signatur fehlgeschlagen (Exit 1)'.
Finding F002: Auf case-insensitiven Dateisystemen (macOS-Runner, APFS Standard) überschreiben die IDs 'Ab' und 'aB' dieselbe Datei; ein Eintrag geht stumm verloren.
  Severity: LOW, Category: edge_case
  Code reference: scripts/asc_crashes.py:126
  Description: Dateiname ist die ID ohne Normalisierung; Apple-IDs sind UUIDs gleicher Schreibweise, daher praktisch unwahrscheinlich.
  Spec requirement: AC-4 — je Meldung eine Datei
  Conflict: bei Kollision nur eine Datei
  Remediation: Duplikate nach casefold erkennen und abbrechen
Finding F003: Bricht der Berichtsabruf mit 401/403/5xx ab, bleiben bereits geschriebene .json (mit E-Mail/Kommentar) im Zielordner liegen (Entwicklerhinweis d, in der Probe bestätigt).
  Severity: LOW, Category: edge_case
  Code reference: scripts/asc_crashes.py:126
  Description: Schreiben und Abrufen sind verschachtelt, kein Aufräumen im Fehlerfall.
  Spec requirement: AC-9 — sofortiger Abbruch; AC-4 Modi (0600 bleibt erhalten)
  Conflict: kein Spezverstoß; Klartext-PII bleibt lokal. Schnitt 2 (Trap EXIT, AC-17) muss das abdecken, ist dort vorgesehen.
  Remediation: bei Schnitt 2 prüfen oder Schreiben erst nach erfolgreichem Abruf
Finding F004: Fester Cursor-Zeichensatz [A-Za-z0-9._~%=-] und HTTPException (IncompleteRead) werden nicht wiederholt. Enthielte ein echter Apple-Cursor andere Zeichen (+ oder /), bräche der Lauf fail-closed mit Exit 1 ab; unbelegt gegen echte Antwort.
  Severity: LOW, Category: edge_case
  Code reference: scripts/asc_crashes.py:15
  Description: Zeichensatz geraten, nur Schein-Antworten.
  Spec requirement: AC-6/AC-8
  Conflict: mögliche Fehlfunktion in der Praxis, kein Sicherheitsproblem; Probelauf AC-20 in Schnitt 2 deckt es auf
  Remediation: bei Auffälligkeit Zeichensatz erweitern (+ und / wären mit %-Kodierung zu erwarten)
Confirmation:
  AC: AC-4, AC-5, AC-12
  Code reference: scripts/asc_crashes.py:105
  Evidence: write_private mit O_NOFOLLOW und fchmod 0600; ID-Prüfung vor dem Schreiben (Zeile 118); Ordner chmod 0700 (Zeile 123).
  Status: CONFIRMED
Confirmation:
  AC: AC-8, AC-9, AC-10, AC-11, AC-14
  Code reference: scripts/asc_crashes.py:53
  Evidence: 5 Versuche exakt (Probe: 500 und 429 je 5 Aufrufe; 404/401/301 je 1), Meldung nur Status, Pfad, code/title; safe_field (Zeile 42) und Ausgabe Zeile 131; main (Zeile 137) fängt alles ohne Traceback.
  Status: CONFIRMED
Confirmation:
  AC: AC-1 bis AC-14 (Testabdeckung)
  Code reference: scripts/test_asc_crashes.py:101
  Evidence: 15 Tests, je AC einer, alle grün unter python3 -I; Proben des Prüfers bestätigen dieselben Aussagen unabhängig.
  Status: CONFIRMED
Confirmation:
  AC: AC-15
  Code reference: .github/workflows/ci.yml:45
  Evidence: scripts/test_asc_crashes.py in der Schleife, die python3 -I "$t" ausführt.
  Status: CONFIRMED
**Implementierer:** (nicht beteiligt)

Hinweis: asc_lib.py unverändert (git diff leer). Alle Findings LOW, keine Spezverletzung, kein Leck.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Tests: 90 passed (15 + 28 + 47), 0 failed, 0 übersprungen
Edge cases: geprüft, nur LOW-Findings F001–F004
Regressions: keine
Checklist: 15/15 points proven

## Geprüfte Dateien

- sha256:7f040e700e8d8a95a5bb96a6e89fe70f00d6186eb033417008bb22f926c72b46  .github/workflows/ci.yml
- sha256:283e633684db98a363df0e13c6a98353c65221de611898579e53c7707409b4e2  scripts/asc_crashes.py
- sha256:11f22ca1dc2e38ae024fb3f8ee57aa1c1893542c8959e1a72b9cc69d78390c67  scripts/test_asc_crashes.py

## Prüfbasis

- base: cb8ba3febfdd29d26abf4d06a8788251fdc9892c
- blob:bfcdfe70fb8ed886fd543991722b677d111b5240  .github/workflows/ci.yml
- blob:c8a4e6ae8802605a41c6d1f6c932baf94be5e6b4  scripts/asc_crashes.py
- blob:bda7d4e652d19bf95f4fc0701d369cc6050d7c70  scripts/test_asc_crashes.py
