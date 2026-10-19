---
entity_id: cloudkit-schema-workflow
type: ci
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: feat-169-cloudkit-schema-ci
tags: [ci, github-actions, cloudkit, cktool, schema, infrastruktur]
---

# CloudKit-Schema per GitHub Actions (Issue #169)

## Approval

- [x] Beauftragt — PO am 2026-10-19 („Ja, mach das Token als GitHub-Secret auch“)
- [ ] Erster Lauf mit echtem Token (Stufe B) — offen

## Purpose

Jede Schema-Änderung (neue Felder an gespiegelten `@Model`-Typen, `SharedStore`, seit #163 der
Typ `CommunityPrice`) lief bisher nur über Hennings Mac: Management-Token im Dashboard erzeugen,
`xcrun cktool export/validate/import-schema`, Deploy im Dashboard, Token entfernen
(`docs/testflight-setup.md`). Die Cloud-Session des Tech Leads kann davon nichts, weil `cktool`
Teil von Xcode ist und nur auf einem Mac läuft. Der GitHub-Runner `macos-26` hat Xcode. Mit dem
Token als Repo-Secret erledigt ein manueller Ablauf dort den Development-Teil und liefert den
Beleg (Export, Diff), der bisher von Hand zusammengetragen wurde.

**Was bleibt bei Henning:** das Hochstufen nach Production. `cktool` kann es nicht; es geht nur
im Dashboard mit Apple-ID und Zwei-Faktor-Code, und ein falscher Deploy ist nie rückgängig zu
machen. Der Ablauf schreibt deshalb nie nach Production.

## Source

- **Neu:** `.github/workflows/cloudkit-schema.yml` (ca. 150 Zeilen),
  `scripts/test_cloudkit_schema_workflow.py` (Strukturtest, PyYAML), diese Spec.
- **Geändert:** `docs/testflight-setup.md` (Abschnitt „Werkzeugweg über GitHub Actions“),
  `CLAUDE.md` (ein Absatz).
- **Nicht geändert:** App-Code, `Restock.xcodeproj`, `ci.yml`, `testflight.yml`,
  `docs/cloudkit/private-schema-aktuell.ckdb`.

## Verhalten

### Auslöser und Eingaben (AC-1)

Nur `workflow_dispatch`. Eingabe `mode` (`choice`): `export` (Standard) oder
`import-development`; Eingabe `confirm` (`string`, leer), die für den Import genau `development`
lauten muss.

### Schutz (AC-2, AC-3)

`permissions: contents: read`, `concurrency: cloudkit-schema` ohne Abbruch laufender Läufe,
`macos-26`, 15 min je Job. Der Job `import-development` läuft nur bei `mode=import-development`,
nach dem Job `export`, und bricht vor dem Checkout ab, wenn der Lauf nicht von `main` kommt
(Schritt 1) oder `confirm` nicht `development` lautet (Schritt 2). Kein Job nutzt ein GitHub-
Environment: eine Freigabe-Regel mit Reviewer braucht Admin-Rechte am Repo, die Henning nicht hat
(Repo gehört seinem Sohn; festgestellt am 2026-10-19). Die getippte Bestätigung ersetzt sie.

### Nie nach Production (AC-4)

`import-schema` kommt nur im Import-Job vor und nur mit `--environment development`.
`reset-schema` kommt nirgends vor. Production wird nur mit `export-schema` gelesen.

### Token (AC-5)

Der Token steht ausschließlich in `secrets.CLOUDKIT_MANAGEMENT_TOKEN`, wird je Job genau einmal
als `env` an den Schritt „Save management token“ gereicht, als Positionsargument an
`xcrun cktool save-token <token> --type management --method file --force` übergeben (Datei statt
Schlüsselbund, der auf dem Runner gesperrt sein kann; GitHub maskiert den Wert im Log) und im
letzten Schritt des Jobs mit `always()` entfernt (`remove-token … --force`).
Kein `run`-Schritt enthält `secrets.`, keiner gibt den Wert aus. Fehlt das Secret, bricht der
Schritt mit Hinweis auf die Einrichtung ab.

### Export und Vergleich (AC-6)

Der Export-Job exportiert Development und Production nach `$RUNNER_TEMP/schema/<env>.ckdb`, legt
sie als Artefakt `cloudkit-schema-export` ab (14 Tage) und schreibt zwei Diffs (`diff -u`) in die
Zusammenfassung: Repo-Datei → Development und Development → Production, jeweils „Kein
Unterschied“ oder der Diff; Unterschiede ergeben eine `::notice::`, keinen Fehlschlag (Development
darf der Repo-Datei vorauslaufen, ein ausstehender Deploy ist eine Information). Der Import-Job
lädt das Artefakt als „vorher“, validiert und importiert die Repo-Datei, exportiert Development
erneut und zeigt den Diff vorher → nachher samt dem nächsten Handschritt (Dashboard-Deploy, dann
`mode=export` als Gegenprobe). Alle `uses` sind `actions/*`.

### Xcode wie CI (AC-7)

Der Schritt „Select latest available Xcode“ ist wortgleich mit `ci.yml` (in beiden Jobs).

### Dokumentation (AC-8)

`docs/testflight-setup.md` nennt Datei, Secret, Modus und Environment; `CLAUDE.md` den Ablauf.

## Einrichtung (Henning)

Siehe `docs/testflight-setup.md`, „Werkzeugweg über GitHub Actions“: Token im Dashboard erzeugen,
Secret `CLOUDKIT_MANAGEMENT_TOKEN` setzen (erledigt am 2026-10-19 über die GitHub-Oberfläche).

## Offene Grenzen

- Stufe B, Lauf 1 (2026-10-19, `main` `4465166`): `save-token` las nichts von stdin („Interaction
  was required while running in non-interactive mode … No token or token type was provided in
  command arguments“), `remove-token` fragte nach Bestätigung. Lauf 2 (`main` `e31057a`): „Unknown
  option '--token'“, Usage `cktool save-token [<token>] [--type <type>] [--method <method>]
  [--force]`. Seitdem Token als Positionsargument plus `--force`; Lauf 3 steht aus.
- Der Ablauf erkennt einen vergessenen Production-Deploy nur beim Ausführen (Diff Development →
  Production), nicht automatisch vor einem TestFlight-Upload. Ein Anschluss an `testflight.yml`
  (Export-Job als Vorbedingung) ist ein möglicher Folgeschritt, kein Teil von #169.
- Ein Management-Token hat Vollzugriff auf das Schema beider Umgebungen. Das Secret liegt auf
  Repo-Ebene; wer das Repo pushen kann, kann einen Ablauf schreiben, der es liest. Die getippte
  Bestätigung schützt vor Versehen, nicht vor Absicht. Mitigation: nur Henning hat Push-Rechte; Rotation wie beim
  App-Store-Connect-Schlüssel; Production bleibt ohnehin unerreichbar für `cktool`.
