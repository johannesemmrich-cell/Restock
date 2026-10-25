# Adversary-Dialog feat-175-b2b-asc-check (Durchgang B2b)

Prüfer: implementation-validator (unabhängig), Stand 2026-10-25, Commit-Basis 804fe4c + vorgemerkter GREEN-Stand.
Gegenstand: AC-9 bis AC-9e, AC-10 (bleibt grün), AC-11 bis AC-19 mit AC-17a, AC-20 bis AC-20g, AC-21.

## Testläufe (alle mit `python3 -I`, aus dem Repo-Root)

- `scripts/test_asc_check.py -v`: Ran 20, OK
- `scripts/test_asc_texts.py -v`: Ran 10, OK
- `scripts/test_asc_scripts.py -v`: Ran 15, OK
- gesamt 45 bestanden, 0 fehlgeschlagen, 0 übersprungen
- `git diff origin/main -- scripts/asc_lib.py` leer (asc_lib unverändert); `ci.yml`: drei neue Zeilen in der Schleife „Strukturtests (Python)“, Aufruf `python3 -I "$t" || exit 1`
- Gegenprobe `texttest-gegenprobe.txt`: 11 von 11 Verderbnissen gefangen

### Runde 1

Hypothese: Der Zaun lässt sich per Pfad-Trick umgehen, und ein Abschnitt meldet fälschlich „ok“.

Zaun: `check_read` (`fullmatch` plus exakte Abfrage), 14 Pfade und 4 Methoden direkt geprobt. Abgelehnt: leeres `?`, fremde
Abfrage, `..`-Segment, `%2F`, `/v1/APPS`, Zeilenumbruch am Ende, `/builds`, Fragment `#x`, Schrägstrich am Ende, absolute URL,
fremde ID, `appStoreVersions` ohne Abfrage, `reviewSubmissions`; Methoden `get`, `OPTIONS`, `None`, `POST` abgelehnt; nur der
exakte Pfad mit bekannter ID erlaubt.

Token: `Reader.get` sendet immer `HOST + path`; `fetch_privacy` lässt nur die exakte URL zu und sendet `{}` als Header;
`urllib_send` folgt keiner Weiterleitung, 301/302 enden als Abweichung.

„ok“ trotz Mangel: 31 Mutationen der Schein-Antworten. Als Abweichung/Fehler (Exit 1) gemeldet: 2 oder 12 Screenshots,
Querformat 2868×1320, keine Sets, Build „37a“ und „36“, Build null, PROCESSING, `usesNonExemptEncryption` null, Version 1.0
fehlt, WAITING_FOR_REVIEW, leeres Telefon, `demoAccountRequired` null, Preis „abc“, leere Produkt-Lokalisierung, keine oder zwei
Abo-Gruppen, `sharedlists`, CONSUMABLE, MISSING_METADATA, fehlende Altersfreigabe, Content Rights, primäre Kategorie, Name mit
Leerzeichen am Ende, Datenschutzseite 301, leer oder ohne Englisch. Randfälle siehe F001–F004.

Nachfrage Review-Kontakt: `sec_review` nutzt nur `rep.present`; kein Kontaktwert in der Ausgabe; Fehlertexte aus `Reader.get`
nur Status und Pfad.

### Runde 2

Hypothese: Der Texttest prüft nur sich selbst, und die CI-Schleife greift nicht.

AC-9e: `test_values_equal_spec_wording` liest den Wortlaut aus der Spec (`### Deutsch` / `### English`, `spec_texts`), Spec ist
die Quelle; unsichtbare Zeichen als echte Zeichen geprüft (U+200B, U+00A0, U+00AD, U+FEFF), BOM als Bytes, CR.
AC-21: `test_ci_runs_asc_tests` verlangt alle drei Dateinamen in der Schleife; alle drei laufen unter `-I` grün.
Quelltextverbote: keine Schreibmethoden-Strings, kein `open(`, kein `ASC_KEY`. Protokollkopf: UTC-Zeitstempel und
`git rev-parse HEAD` als Argumentliste, sonst „unbekannt“. `appVersionState` konsistent mit `asc_publish`.

## Findings (alle LOW)

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:99
  Description: `Report.present` prüft nur `bool(value)`; ein Kontaktfeld aus Leerzeichen gilt als „gesetzt“ (Exit 0).
  Spec requirement: AC-17a
  Remediation: Strings nach `strip()` prüfen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:169
  Description: Kategorien als Menge verglichen; vertauschte Rollen ergeben „ok“.
  Spec requirement: AC-13; Spec erlaubt die umgekehrte Reihenfolge als Rückfall.
  Remediation: bewusst so lassen, Ist-Wert in B3 ablesen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:177
  Description: `products()` sammelt nach `productId`; ein doppeltes Produkt überschreibt sich still.
  Spec requirement: AC-15
  Remediation: Treffer je `productId` zählen, > 1 als Abweichung.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/asc_check.py:109
  Description: Scheitert `context()` nach dem Lesen der App, ist `ctx` teilweise gefüllt; Folgeabschnitte melden `Fehler appinfo: 'ver'`.
  Spec requirement: AC-20c
  Remediation: `ctx` erst nach erfolgreichem Lesen aller Teile setzen.

## Confirmations (Runden 1–2)

Confirmation:
  AC: AC-9, AC-9a, AC-9b, AC-9c, AC-9d, AC-9e
  Code reference: scripts/test_asc_texts.py:92
  Status: CONFIRMED

Confirmation:
  AC: AC-11, AC-12, AC-13, AC-15, AC-16, AC-17, AC-17a, AC-18, AC-19
  Code reference: scripts/asc_check.py:125
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-19
  Code reference: scripts/asc_check.py:306
  Status: CONFIRMED

Confirmation:
  AC: AC-20, AC-20a
  Code reference: scripts/asc_check.py:39
  Status: CONFIRMED

Confirmation:
  AC: AC-20b
  Code reference: scripts/asc_check.py:74
  Status: CONFIRMED

Confirmation:
  AC: AC-20c, AC-20d, AC-20e, AC-20f, AC-20g
  Code reference: scripts/asc_check.py:283
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/asc_lib.py:1
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: .github/workflows/ci.yml:41
  Status: CONFIRMED

Verdict nach Runde 2: VERIFIED (4 LOW-Hinweise). Entscheidung des Orchestrators: F001, F003, F004 werden behoben (falsche
„ok“-Meldungen sind genau, was das Werkzeug verhindern soll); F002 bleibt bewusst, weil die Spec den Rückfall erlaubt.

### Runde 3

Geprüft auf dem korrigierten Stand: Fixes F001, F003, F004 an Nachbarfällen, Regressionen, AC-20f, AC-17a, AC-20a.

```
python3 -I scripts/test_asc_check.py -v   -> Ran 20 tests  OK
python3 -I scripts/test_asc_texts.py -v   -> Ran 10 tests  OK
python3 -I scripts/test_asc_scripts.py -v -> Ran 15 tests  OK
```

Die Korrekturen schließen ihre Findings; jede neue Assertion war vor dem Fix rot (Wegwerfkopie, 3 Fehlschläge genau an den neuen
Assertions).
- **F001 geschlossen:** `Report.present` strippt Strings. Tab-, Zeilenumbruch- und Leerzeichen-only gelten als leer, None/0/{}/[]
  ebenfalls, Werte mit Inhalt als gesetzt. Die Ausgabe zeigt nur „gesetzt“/„leer“.
- **F003 geschlossen:** Zweimal lifetime als IAP und monthly als IAP und Abo melden je „Abweichung iap: doppeltes Produkt … 2-mal“.
- **F004 geschlossen:** `ctx.update` läuft erst nach erfolgreichem Lesen von App, Version und appInfo. `data: null` ergibt
  „0 Treffer statt genau 1“, je Abschnitt dieselbe Ursache statt eines KeyError.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:181
  Description: Fehlt einem Produkt die productId (None) und gibt es zugleich ein fremdes Produkt mit String-ID, wirft `sorted(set(found) - set(want))` TypeError; der Abschnitt endet als „Fehler iap“ statt mit Einzelzeilen, Rückgabe bleibt 1, keine falsche „ok“-Meldung.
  Spec requirement: AC-15
  Remediation: `sorted(..., key=str)`. Entscheidung des Orchestrators: als offene Grenze vermerkt, nicht behoben (kein falsches „ok“, Mischfall konstruiert).

Confirmation:
  AC: AC-17a
  Code reference: scripts/asc_check.py:98
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: scripts/asc_check.py:168
  Status: CONFIRMED

Confirmation:
  AC: AC-20c
  Code reference: scripts/asc_check.py:110
  Status: CONFIRMED

Confirmation:
  AC: AC-20a
  Code reference: scripts/asc_check.py:39
  Status: CONFIRMED

Confirmation:
  AC: AC-20f
  Code reference: scripts/test_asc_check.py:1
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10
  Code reference: scripts/test_asc_texts.py:92
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-19
  Code reference: scripts/asc_check.py:306
  Status: CONFIRMED

VERDICT: VERIFIED. 45 Tests grün, keine Regression; offen nur F005 (LOW, ohne falsches „ok“) und das bewusste F002.

## Geprüfte Dateien

- sha256:a4e549159409f7955d72ad7f625f561c8ddd52a2819c5c9bb94fcb7426d633f8  .github/workflows/ci.yml
- sha256:f132a455db6bf9dd31d38ec4f65b340f4dbe72b49ec3e0158031b930c0bc31a3  scripts/asc_check.py
- sha256:f5ea7c0772c3322629857d7932f9c1b249d6acd0dc639db82fb53fdb7ac40be9  scripts/asc_lib.py
- sha256:9acb92a31a639ff99110348b5591d0647f10d6353adc6aa226076bcdccffb27c  scripts/test_asc_check.py
- sha256:c840013ecf826e73db336133bd8bd7202a7023933df1509df6c87f461d8b80a3  scripts/test_asc_texts.py

## Prüfbasis

- base: 6dc82a889bf89ba1bdafe66be04bb8688acc5032
- blob:01e1edbb6340520c99c7dd40ad24bb0c43bc07a9  .github/workflows/ci.yml
- blob:ad2bcfd540e61171107c046896975675b282cdda  scripts/asc_check.py
- blob:fde58bf0f1c62d92d5daa1e29f5db6830ecde1e9  scripts/asc_lib.py
- blob:2577392be67a9d1d0c4c0e9d2bdd101dfda406f6  scripts/test_asc_check.py
- blob:3588ba19f59dae367ac00a85e3dddb2c99a8c37f  scripts/test_asc_texts.py
