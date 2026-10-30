# CloudKit-Schema vor Build 37 (AC-5)

Stand: 2026-10-29. Nur lesend: `xcrun cktool export-schema` für Development und Production (Container `iCloud.com.johannesemmrich.SmartCart`, Team `XK87E2B3VR`, Token aus dem Schlüsselbund, nie angezeigt). Nichts importiert, nichts deployt.

| Vergleich | Ergebnis |
|---|---|
| Repo-Datei `docs/cloudkit/private-schema-aktuell.ckdb` gegen Development | kein Unterschied |
| Development gegen Production | kein Unterschied |

App-Code dieses Zweigs gegen `origin/main` (`1b190c8`, CI auf main grün, Lauf vom 2026-10-28): `git diff --stat origin/main -- SmartCart` ist leer. Die Unit-Suite von main enthält `MirroredSchemaSnapshotTests` (T1–T3), die Modelle und Felder gegen die Repo-Datei prüfen. Damit deckt die Production-Fassung alle Felder des Codes, den Build 37 enthält.

Grenzen: Der Test erkennt einen vergessenen Production-Deploy nicht, nur der Export oben tut das. Beziehungen und Feldtypen prüft er nicht. Ein Gerätetest mit dem TestFlight-Build ist nicht belegt.

Folgerung: Es ist kein Deploy im Dashboard nötig. Build 37 kann auf Hennings Wort hochgeladen werden.
