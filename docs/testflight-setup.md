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
