# TestFlight-Upload per GitHub Actions (Issue #109)

Ablauf: `.github/workflows/testflight.yml`, nur manuell (Actions → TestFlight → Run workflow). `dry_run` (Standard) archiviert und prüft die Signatur, lädt aber nicht hoch; hochgeladen wird nur mit `dry_run` aus und nur von `main`.

## Einrichtung

1. App Store Connect → Benutzer und Zugriff → Integrationen → Team-Schlüssel: API-Schlüssel mit Rolle **Admin** anlegen, `.p8` einmalig laden.
2. GitHub → Settings → Environments → Environment `testflight` (nur der Besitzer kann das): Reviewer = Henning, Deployment nur von `main`. Die Umgebung ist nur für die Freigabepflicht nötig; ohne „Required reviewers“ startet der Upload ohne Klick.
3. Secrets als **Repository-Secrets** setzen (Settings → Secrets and variables → Actions → New repository secret; geht ohne Admin-Rechte, belegt 2026-10-20): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (Inhalt der `.p8`: Datei im Texteditor öffnen, alles kopieren und einfügen; Base64 geht auch). Secrets im Environment wären nur ein Vorrang, kein Muss.
4. Im Developer-Portal die Zahl der Distribution-Zertifikate prüfen (Limit).

Stufe B braucht Hennings Schlüssel: erst Probelauf mit `dry_run` an, dann echter Lauf mit `dry_run` aus. **Belegt am 2026-10-20:** Lauf 8 (run 39453132619) hat Build 33 von `main` hochgeladen (`Upload succeeded`); der Trockenlauf wurde übersprungen. Fehlende Secrets zeigen sich als `xcodebuild: error: The flag -authenticationKeyID is required` beim Archivieren (Lauf 7).

## Rotation

Schlüssel alle 6–12 Monate neu anlegen, Secrets ersetzen, alten Schlüssel widerrufen. Bei Verdacht auf Missbrauch sofort widerrufen.

## Rückfall

Lokaler Upload über Xcode (Organizer) oder `xcodebuild -exportArchive` wie bisher.

## Regel: nie dieselbe Build-Nummer auf zwei Wegen

Lokaler Weg und CI teilen den Zähler in App Store Connect. Vor jedem Upload die letzte Nummer dort prüfen; nie beide Wege gleichzeitig nutzen.

## CloudKit-Schema veröffentlichen, wenn sich die Felder von `SharedStore` ändern

**Auch für `CommunityPrice` (Issue #163):** Der Record-Typ für den Community-Preispool (Felder `itemKey`, `chain`, `price`, `unit`, `observedAt`, `clientID`; Vorlage in `docs/cloudkit/private-schema-aktuell.ckdb`) muss vor dem ersten Upload mit #163 in Development angelegt (cktool-Weg unten oder erster Xcode-Lauf mit eingeschaltetem Schalter „Preise anonym mit anderen teilen“) und nach Production deployt werden. Fehlt er in Production, scheitert nur das Teilen still (Protokoll `community`), Lesen liefert nichts, die App läuft weiter. Drift-Test: `CommunityPriceTests.testSchemaFieldsMatchPublishedExport`.

Stand 2026-10-19: `CommunityPrice` liegt in Development und Production (Deploy im Dashboard durch Henning; Bericht in `docs/artifacts/feat-163-community-preise/production-deploy-2026-10-19.md`), per `cktool`-Export belegt durch `cloudkit-schema.yml` Lauf 3 (run 39247424086): je 9 Record-Typen, Development → Production ohne Unterschied.

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
5. Token **nicht** entfernen: Er bleibt dauerhaft im Schlüsselbund (Henning, 2026-10-18). Apple zeigt den Wert nur einmal; ohne Schlüsselbund-Eintrag ist der Token im Dashboard wertlos. Vorher prüfen: `xcrun cktool get-teams` muss das Team zeigen; nur wenn nicht, einmalig neu anlegen (Dashboard-Schritt per Claude-Desktop-Prompt).

**Grenze:** Nach Production hochstufen kann `cktool` nicht. Das geht nur im Dashboard: „Deploy Schema Changes…“ → Diff prüfen (es dürfen nur die erwarteten Felder und deren Indizes auftauchen) → Deploy. Danach Production und Development jeweils exportieren und vergleichen.

Stand 2026-10-08: `categoriesJSON` und `assignmentsJSON` (`STRING`) liegen in Development und Production.

### Werkzeugweg über GitHub Actions (Issue #169)

Derselbe cktool-Weg ohne Mac: manueller Ablauf `.github/workflows/cloudkit-schema.yml` (Actions → CloudKit Schema → Run workflow) auf dem macOS-Runner, Token aus dem Repo-Secret `CLOUDKIT_MANAGEMENT_TOKEN`.

- `mode=export` (Standard): exportiert Development und Production, legt beide als Artefakt `cloudkit-schema-export` ab (14 Tage) und schreibt zwei Diffs in die Zusammenfassung: Repo-Datei `docs/cloudkit/private-schema-aktuell.ckdb` → Development und Development → Production. Schreibt nichts. Ein Unterschied Development → Production heißt: Deploy im Dashboard steht aus.
- `mode=import-development`: erst der Export wie oben, dann (nur von `main` und nur mit dem Pflichtfeld `confirm` = `development`) `validate-schema` und `import-schema` der Repo-Datei nach Development, danach erneuter Export und Diff vorher → nachher in der Zusammenfassung. **`import-schema` ersetzt das ganze Development-Schema durch die Repo-Datei**, deshalb muss die Datei vollständig sein (alle Typen, auch `SharedStore`, `SharedItemPhoto`, `Users`).
- Nach Production schreibt der Ablauf nie. Hochstufen bleibt im Dashboard („Deploy Schema Changes…“, Diff prüfen, Deploy), danach `mode=export`: Development → Production muss „Kein Unterschied“ zeigen.

Einrichtung:

1. CloudKit-Dashboard → Konto-Menü → Settings → Tokens → Create Management Token. Den Wert nie anzeigen, nie ins Repo, nie in einen Chat.
2. `gh secret set CLOUDKIT_MANAGEMENT_TOKEN --repo johannesemmrich-cell/Restock` (Wert einfügen) oder GitHub → Settings → Secrets and variables → Actions → New repository secret.
3. Keine Environment-Freigabe: Environments mit Reviewer brauchen Admin-Rechte am Repo, die Henning nicht hat (Repo gehört seinem Sohn). Schranke für den Import ist stattdessen das Pflichtfeld `confirm`, in das beim Start genau `development` eingetippt wird; sonst bricht der Job vor dem Checkout ab.
4. Rotation wie beim App-Store-Connect-Schlüssel: alle 6–12 Monate neu erzeugen und das Secret ersetzen, alten Token im Dashboard löschen; bei Verdacht auf Missbrauch sofort.

Der Token liegt auf dem Runner nur für die Dauer des Jobs als Datei (`cktool save-token <token> --type management --method file --force`) und wird in einem `always()`-Schritt entfernt (`remove-token --force`); kein Schritt gibt ihn aus, GitHub maskiert ihn im Log. Strukturtest: `python3 scripts/test_cloudkit_schema_workflow.py`. Läufe 1 und 2 am 2026-10-19 zeigten: Ohne Terminal liest `cktool` nichts von stdin („No token or token type was provided in command arguments“), `--token` kennt es nicht (Usage `save-token [<token>] [--type] [--method] [--force]`), und `remove-token` fragt ohne `--force` nach.

## Privater iCloud-Abgleich: Typen vor jedem Upload in Production

Der eigene Abgleich der Läden und Listen (nicht der geteilten Läden) läuft über die **private** Datenbank: SwiftData spiegelt jede Entität aus `SchemaV1` (`SmartCart/Services/SchemaVersions.swift`) in die Zone `com.apple.coredata.cloudkit.zone`, als Record-Typ `CD_<Entität>` mit Feldern `CD_<Attribut>`. Gespiegelt werden alle fünf Modelle: `CD_Store`, `CD_ShoppingItem`, `CD_PurchaseRecord`, `CD_FeedbackItem`, `CD_TodoItem` (Issue #155).

**Wann:** vor jedem Upload, der ein neues Modell oder ein neues Attribut an einem bestehenden Modell mitbringt. Der Test `RestockTests/MirroredSchemaSnapshotTests.swift` meldet das: T1 schlägt fehl, sobald sich Modelle oder Attribute ändern; T2/T3 schlagen fehl, wenn `docs/cloudkit/private-schema-aktuell.ckdb` einen Typ oder ein Feld nicht kennt.

### Rezept

Container `iCloud.com.johannesemmrich.SmartCart`, Team `XK87E2B3VR`. Alle `cktool`-Schritte nur mit `--environment development`.

1. Management-Token in den Schlüsselbund legen (wie oben, `cktool save-token --type management --method keychain`, Wert nie anzeigen).
2. `xcrun cktool export-schema --team-id XK87E2B3VR --container-id iCloud.com.johannesemmrich.SmartCart --environment development --output-file vorher.ckdb`
3. Arbeitsdatei = `vorher.ckdb` plus die neuen Typen bzw. Felder, von Hand und im Stil der vorhandenen `CD_`-Typen: Felder alphabetisch, `String` und `UUID` als `STRING QUERYABLE SEARCHABLE SORTABLE` (wie `CD_id`), `Bool`/`Int` als `INT64 QUERYABLE SORTABLE`, `Date` als `TIMESTAMP QUERYABLE SORTABLE`, `Double` als `DOUBLE QUERYABLE SORTABLE`, dazu `CD_entityName`, die sechs `"___"`-Systemfelder und die drei `GRANT`-Zeilen wie bei `CD_Store`.
4. `xcrun cktool validate-schema … --environment development --file arbeit.ckdb` muss „Schema is valid“ melden.
5. `xcrun cktool import-schema … --environment development --file arbeit.ckdb`. **Achtung:** `import-schema` ersetzt das **ganze** Development-Schema durch die Datei. Alle bestehenden Typen (auch `SharedStore`, `SharedItemPhoto`, `Users`) müssen unverändert in der Datei stehen.
6. Erneut exportieren nach `docs/cloudkit/private-schema-aktuell.ckdb` (nach **jedem** Import, sonst prüft T2 einen alten Stand) und mit `diff` gegen `vorher.ckdb` vergleichen: Es dürfen nur die erwarteten Typen und Felder auftauchen.
7. Dashboard → Container-ID prüfen (es öffnet sich zuerst oft ein fremder Container) → „Deploy Schema Changes…“ → Diff prüfen (nur die erwarteten Typen/Felder) → Deploy. Production erlaubt keine Löschungen; ein falsch deployter Typ bleibt für immer.
8. Gegenprobe: `xcrun cktool export-schema … --environment production` und mit dem Development-Export vergleichen; bei den `CD_`-Typen darf es keinen Unterschied geben.
9. Token im Schlüsselbund lassen (siehe oben), nie `remove-token`.

### Fallen

- **Production legt nie Typen oder Felder an.** Development erzeugt sie just-in-time beim ersten Speichern, Production lehnt den Record ab („Cannot create new type … in production schema“, `CKError` 12). Im Simulator lässt sich das nicht nachstellen.
- **Ein abgelehnter Record lässt den ganzen Export scheitern.** Ein einziges Feedback oder Todo ohne Typ in Production blockiert damit auch den Abgleich der Läden und Artikel für die Sitzung. Der Entwicklermodus ist auch in TestFlight freischaltbar.
- **`nil`-Felder erscheinen im Just-in-time-Schema nicht.** Ein optionales Attribut (z. B. `TodoItem.notes`) entsteht in Development nur, wenn es beim Speichern gefüllt war. Deshalb wird die `.ckdb` von Hand ergänzt statt per Debug-Lauf.
- **Große Werte als `_ckAsset`.** Für große `Data`-/Blob-Werte legt die Spiegelung ein Zusatzfeld `CD_<Attribut>_ckAsset` an; `CD_photoData_ckAsset` (ASSET) ist seit Issue #156 im Schema; alle übrigen `_ckAsset`-Felder fehlen bewusst (PO-Entscheidung, praktisch nur das Foto erreichbar).

Stand 2026-10-18: Alle fünf `CD_`-Typen (`CD_Store`, `CD_ShoppingItem`, `CD_PurchaseRecord`, `CD_FeedbackItem`, `CD_TodoItem`) liegen in Development und Production mit denselben Feldern (`docs/cloudkit/private-schema-aktuell.ckdb`; Production-Export ohne Unterschied, `docs/artifacts/fix-155-icloud-produktionsschema/`). Seit #156 zusätzlich `CD_ShoppingItem.CD_photoData_ckAsset` (ASSET).
