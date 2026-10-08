# TestFlight-Upload per GitHub Actions (Issue #109)

Ablauf: `.github/workflows/testflight.yml`, nur manuell (Actions → TestFlight → Run workflow). `dry_run` (Standard) archiviert und prüft die Signatur, lädt aber nicht hoch; hochgeladen wird nur mit `dry_run` aus und nur von `main`.

## Einrichtung

1. App Store Connect → Benutzer und Zugriff → Integrationen → Team-Schlüssel: API-Schlüssel mit Rolle **Admin** anlegen, `.p8` einmalig laden.
2. GitHub → Settings → Environments → Environment `testflight` anlegen: Reviewer = Henning, Deployment nur von `main`.
3. Secrets im Environment `testflight` setzen: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (Inhalt der `.p8`: Datei im Texteditor öffnen, alles kopieren und einfügen; Base64 geht auch).
4. Im Developer-Portal die Zahl der Distribution-Zertifikate prüfen (Limit).

Stufe B braucht Hennings Schlüssel: erst Probelauf mit `dry_run` an, dann echter Lauf mit `dry_run` aus.

## Rotation

Schlüssel alle 6–12 Monate neu anlegen, Secrets ersetzen, alten Schlüssel widerrufen. Bei Verdacht auf Missbrauch sofort widerrufen.

## Rückfall

Lokaler Upload über Xcode (Organizer) oder `xcodebuild -exportArchive` wie bisher.

## Regel: nie dieselbe Build-Nummer auf zwei Wegen

Lokaler Weg und CI teilen den Zähler in App Store Connect. Vor jedem Upload die letzte Nummer dort prüfen; nie beide Wege gleichzeitig nutzen.

## CloudKit-Schema veröffentlichen, wenn sich die Felder von `SharedStore` ändern

TestFlight und App Store nutzen die CloudKit-**Produktion**, Xcode-Läufe die **Entwicklung**. Die Produktion legt unbekannte Felder nicht an und lehnt das Speichern ab („… in production schema“, Issue #121). Deshalb vor jedem Upload, der neue Felder von `SharedStore` mitbringt:

1. CloudKit-Dashboard → Container `iCloud.com.johannesemmrich.SmartCart` → Development → Record-Typ `SharedStore`: prüfen, dass alle Felder (insbesondere neue) dort stehen. Ein Feld entsteht in Development erst, wenn ein Xcode-Lauf einen geteilten Laden damit gespeichert hat.
2. „Deploy Schema Changes…“ → nach Production übernehmen.

Der Drift-Test `testT8_sharedStoreFieldListMatchesPublishedSchema` in `RestockTests/SharedStoreSchemaTests.swift` schlägt fehl, sobald sich die Feldliste ändert; dann diesen Schritt ausführen und die Liste im Test nachziehen. Fehlen in der Produktion nur `categoriesJSON`/`assignmentsJSON`, speichert die App ohne sie weiter (Artikel, Preise, Mitglieder gleichen ab) und zeigt im Laden „Server-Einrichtung unvollständig …“.

### Werkzeugweg mit cktool (statt Felder im Dashboard anzulegen)

Neue Felder lassen sich ohne Klicken im Dashboard in Development anlegen. Container `iCloud.com.johannesemmrich.SmartCart`, Team `XK87E2B3VR`; im Dashboard öffnet sich zuerst oft ein fremder Container, die ID immer prüfen.

1. Management-Token im Dashboard erzeugen (Name → Settings → Tokens → Create Management Token) und mit `cktool save-token --type management --method keychain` in den Schlüsselbund legen. Den Wert nie anzeigen oder ins Repo schreiben.
2. `cktool export-schema` (Environment `development`) → die Schemadatei um die neuen Felder ergänzen (gleicher Typ wie die vorhandenen JSON-Felder: `STRING`).
3. `cktool validate-schema`, danach `cktool import-schema` (nur Development).
4. Gegenprobe: Schema erneut exportieren und mit der ergänzten Datei per `diff` vergleichen.
5. Token wieder entfernen: `cktool remove-token --type management`.

**Grenze:** Nach Production hochstufen kann `cktool` nicht. Das geht nur im Dashboard: „Deploy Schema Changes…“ → Diff prüfen (es dürfen nur die erwarteten Felder und deren Indizes auftauchen) → Deploy. Danach Production und Development jeweils exportieren und vergleichen.

Stand 2026-10-08: `categoriesJSON` und `assignmentsJSON` (`STRING`) liegen in Development und Production.
