# Mini-Spec: doc-126-cktool-schema (Issue #126)

## Was ändert sich
- `docs/testflight-setup.md`, Abschnitt „CloudKit-Schema veröffentlichen …“: neuer Unterabschnitt „Werkzeugweg mit cktool (statt Dashboard-Klicken)“.
  - Ablauf: Management-Token im Dashboard erzeugen und per `cktool save-token --type management --method keychain` in den Schlüsselbund legen (Wert nie anzeigen), dann `export-schema` → Datei um die neuen Felder ergänzen → `validate-schema` → `import-schema` (nur Development) → Gegenprobe per erneutem Export und `diff` → danach `remove-token --type management`.
  - Grenze: Nach Production hochstufen geht nur im Dashboard („Deploy Schema Changes…“, Diff prüfen, Deploy); danach Production und Development per Export vergleichen.
  - Container `iCloud.com.johannesemmrich.SmartCart`, Team `XK87E2B3VR`; im Dashboard öffnet sich zuerst ein fremder Container, die ID immer prüfen.
  - Stand 2026-10-08: `categoriesJSON` und `assignmentsJSON` (STRING) sind in Development und Production.
- Keine anderen Dateien, kein Code.

## Was darf sich nicht ändern
- Die bestehenden Schritte 1 und 2 (Dashboard-Weg) und der Absatz zum Drift-Test `testT8_sharedStoreFieldListMatchesPublishedSchema` bleiben inhaltlich unverändert.
- Keine Zugangsdaten, Token oder Schlüsselinhalte im Text.

## Manuelle Test-Schritte
Entfallen (nur Doku). Prüfung: Diff zeigt nur `docs/testflight-setup.md`; Abschnitt enthält alle fünf cktool-Befehle in der genannten Reihenfolge und den Hinweis, dass Production nur über das Dashboard geht.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] `grep` auf `export-schema`, `validate-schema`, `import-schema`, `remove-token`, `Deploy Schema Changes` in der Datei findet jeweils mindestens eine Stelle.
