# Freigaben je außenwirksamem Schritt (AC-7)

Zusammenstellung am 2026-10-30 nach Abschluss der Betriebsschritte, auf Befund F008 der Adversary-Runde 4. Die Wortzeilen
hat Henning im Gespräch getippt; sie stehen im Gesprächsverlauf der Sitzung und hier, nicht in einem maschinellen Beleg.
Zeiten sind UTC und als Eingrenzung zu lesen: „nach“ ist die letzte Lesung vor dem Schritt, „vor“ die erste danach.
Nichts davon wurde zur Prüfung eingereicht (`asc_check --section status`: `PREPARE_FOR_SUBMISSION`).

| Schritt | Hennings Wort | Zeitpunkt der Ausführung | Eingrenzung durch Beleg |
|---|---|---|---|
| Screenshot-Upload | „Screenshots hochladen“ | 2026-10-29, genaue Zeit nicht belegt | vor 15:07:16Z, siehe `screenshots-aufnahme.txt` |
| Build 37 hochladen | „build hochladen“ | GitHub-Lauf 40926284358, angelegt 2026-10-29T17:57:47Z, beendet 18:05:40Z, `success`, Commit `1b190c8` | Lauf selbst (`gh run view`) |
| Kauf monthly (Gruppe „Restock Pro“ und Monatsabo) | „Kauf monthly“ | 2026-10-30, genaue Zeit nicht belegt | nach 07:19:26Z, vor 07:45:35Z (`asc-readback-iap-monthly.txt` erste Fassung zeigt monthly vorhanden) |
| Review-Screenshot monthly | im Wort „Kauf monthly“ enthalten | durch Hennings Browser-Sitzung | vor 07:56:28Z (`asc-readback-iap-monthly.txt`) |
| Kauf yearly | „Kauf yearly“ | 2026-10-30, genaue Zeit nicht belegt | nach 07:56:28Z, vor 08:24:46Z (`asc-readback-iap-yearly.txt`) |
| Kauf lifetime | „Kauf lifetime“ | 2026-10-30, genaue Zeit nicht belegt | nach 08:24:46Z, vor 08:56:42Z (`asc-readback-iap-lifetime.txt`) |
| Build 37 der Version 1.0 zuordnen | Kein getipptes Wort „Build zuordnen“; Henning schrieb „Ich habe den Build zugeordnet.“ und führte den Schritt selbst in App Store Connect aus | 2026-10-30, genaue Zeit nicht belegt | nach 07:19:26Z (zugeordnet: Ist keiner), vor 07:45:49Z (`asc-readback-build-4.txt`: zugeordnet) |
| „Was testen?“-Text Build 37 (de-DE) | „Text ok“ nach Vorlage des Wortlauts | 2026-10-30, Lesung im Lauf nach dem Setzen | `testflight-was-testen-build37.txt` |

Hinweis zur Zuordnung des Builds: Dieser Schritt lief nicht über mein Werkzeug und nicht auf ein getipptes Wort, sondern durch
Henning selbst in App Store Connect. Der Beleg ist die Lesung, nicht die Zeile im Gespräch.

Henning hat nie „Zur Prüfung hinzufügen“ oder eine Einreichung ausgelöst; das ist ausdrücklich nicht Teil von B3.
