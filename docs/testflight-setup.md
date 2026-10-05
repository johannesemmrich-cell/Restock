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
