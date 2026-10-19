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

Nur `workflow_dispatch`. Eine Eingabe `mode` (`choice`): `export` (Standard) oder
`import-development`.

### Schutz (AC-2, AC-3)

`permissions: contents: read`, `concurrency: cloudkit-schema` ohne Abbruch laufender Läufe,
`macos-26`, 15 min je Job. Der Job `import-development` läuft nur bei `mode=import-development`,
nach dem Job `export`, im Environment `cloudkit` (Reviewer Henning) und bricht als ersten Schritt
ab, wenn der Lauf nicht von `main` kommt. Der Job `export` hat kein Environment, damit er ohne
Freigabe als reiner Lesezugriff läuft.

### Nie nach Production (AC-4)

`import-schema` kommt nur im Import-Job vor und nur mit `--environment development`.
`reset-schema` kommt nirgends vor. Production wird nur mit `export-schema` gelesen.

### Token (AC-5)

Der Token steht ausschließlich in `secrets.CLOUDKIT_MANAGEMENT_TOKEN`, wird je Job genau einmal
als `env` an den Schritt „Save management token“ gereicht, per Pipe an
`xcrun cktool save-token --type management --method file` übergeben (Datei statt Schlüsselbund,
der auf dem Runner gesperrt sein kann) und im letzten Schritt des Jobs mit `always()` entfernt.
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
`gh secret set CLOUDKIT_MANAGEMENT_TOKEN`, Environment `cloudkit` mit Reviewer anlegen.

## Offene Grenzen

- Ob `cktool save-token` den Wert auf dem Runner aus der Pipe liest (statt nur interaktiv), ist
  nicht belegt; ebenso `remove-token --method file`. Stufe B: erster Lauf mit `mode=export`.
- Der Ablauf erkennt einen vergessenen Production-Deploy nur beim Ausführen (Diff Development →
  Production), nicht automatisch vor einem TestFlight-Upload. Ein Anschluss an `testflight.yml`
  (Export-Job als Vorbedingung) ist ein möglicher Folgeschritt, kein Teil von #169.
- Ein Management-Token hat Vollzugriff auf das Schema beider Umgebungen. Das Secret liegt auf
  Repo-Ebene, damit `export` ohne Freigabe läuft; wer das Repo pushen kann, kann einen Ablauf
  schreiben, der es liest. Mitigation: nur Henning hat Push-Rechte; Rotation wie beim
  App-Store-Connect-Schlüssel; Production bleibt ohnehin unerreichbar für `cktool`.
