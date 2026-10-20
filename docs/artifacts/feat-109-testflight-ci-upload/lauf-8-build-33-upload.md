# TestFlight-Upload per GitHub Actions: Lauf 8, Build 33 (Stufe B belegt)

Datum: 2026-10-20 · Lauf: https://github.com/johannesemmrich-cell/Restock/actions/runs/39453132619 (Nr. 8) · Zweig `main` 3ad3c40 · Eingaben `dry_run=false`, `build_number=33` · Start durch Claude (Sitzung session_01AeaAsxbMJFGm7JgWxjWWFy), Freigabe der Umgebung `testflight` durch Henning.

## Schritte und Dauer

| Schritt | Ergebnis | Dauer |
|---|---|---|
| Select latest available Xcode | Xcode 26.6 (17F113), macos-26 | < 1 s |
| Write API key | ok (Werte im Protokoll als `***`) | < 1 s |
| Archive | ok | 3:22 min |
| Check signing / Upload archive (dry run) | übersprungen (`dry_run=false`) | – |
| Export and upload to TestFlight | `Upload succeeded.` · `Uploaded Restock` · `** EXPORT SUCCEEDED **` | 1:49 min |
| Remove API key | ok | < 1 s |

## Was damit belegt ist

- Die drei Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` erreichen den Job als **Repository-Secrets**; Henning hat sie selbst angelegt (kein Admin, kein Environment-Secret).
- Cloud-Signierung mit API-Schlüssel der Rolle Admin, Export und Upload laufen auf dem GitHub-Runner ohne lokale Xcode-Anmeldung.
- Build-Nummer 33 über `CURRENT_PROJECT_VERSION` angehoben (seit #180 auch im Projekt).

## Vorgeschichte

- Lauf 6 (2026-10-19, Build 33, 441822b): unfreigegeben abgebrochen.
- Lauf 7 (2026-10-19, b0963a8): nach Freigabe beim Archivieren gescheitert, `xcodebuild: error: The flag -authenticationKeyID is required when specifying -authenticationKeyPath.`, weil alle drei `ASC_*`-Werte leer waren (nie gesetzt; im Protokoll leer statt `***`).

## Offen

- AC-B1 (Trockenlauf mit Signatur-Summary) nicht gelaufen; der PO wollte direkt hochladen.
- Verarbeitung in App Store Connect und Installation aus TestFlight bestätigt Henning; Nachher-Screenshot der Rewe-Liste steht aus.
- Freigabepflicht der Umgebung: Anfrage an den Besitzer, „Required reviewers“ zu entfernen.
