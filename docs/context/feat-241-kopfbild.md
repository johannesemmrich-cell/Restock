# Context: feat-241-kopfbild

## Request Summary
Issue #241: Für die App-Store-Seite von Restock 1.0 ein Kopfbild („Kopfzeile und Suchergebnisse“) gestalten. Entwurf zur Freigabe durch den PO (Hell und Dunkel), Bild in beiden Größen (5244 × 2950 und 3840 × 1646 px) ins Repo, hochladen, **nicht** zur Prüfung einreichen ohne ausdrückliches Wort des PO. Für die Veröffentlichung nicht nötig, zählt erst bei Einreichung für Hervorhebungen.

## Recherche (zuerst, Regel „Recherche zuerst“)
- Apple-Hilfe „Creative assets specifications“: Produktseiten-Kopf 21:9, 3840 × 1646; Suchergebnisse 3:2, 1920 × 1280 bis 3840 × 2560; JPEG/JPG/PNG. Quelle: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- Das 16:9-PNG mit 5244 × 2950 gilt für beide Plätze („Use header asset in search results“); Kopf und Suchkarte schneiden unterschiedlich zu, beide Zuschnitte müssen geprüft werden. Quelle: https://aso.dev/app-store-connect/placements/
- **Kein Alphakanal, keine Transparenz.**
- API: Es gibt eine „App Asset Library API“ (Adapty-Hinweis), aber **keine Endpunkte gefunden**. Ob sich das Kopfbild per API hochladen lässt, ist unbelegt.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/appstore/{de,en}.md` | Name „Restock“, Untertitel „Einkaufsliste mit Ladenwahl“, Werbetext „Schreib auf, was fehlt. Restock sortiert es in den passenden Laden …“ — Textquelle fürs Bild |
| `docs/artifacts/feat-175-app-store-auftritt/screenshots/{de,en}/01…05*.png` | Fünf vorhandene Store-Bilder (1320×2868), Vorlage für „Heute“ im Entwurf |
| `SmartCart/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | App-Symbol, Bildelement |
| `SmartCart/Assets.xcassets/RC*.colorset` | Markenfarben: RCAccent hell (0.400/0.435/0.220, olivgrün), dunkel (0.655/0.682/0.420); RCCanvas hell (0.961/0.949/0.914), dunkel (0.078/0.075/0.063); RCSurface hell (0.992/0.984/0.957), dunkel (0.114/0.110/0.086) |
| `scripts/asc_lib.py` (`ALLOWED`) | GET/POST/PATCH-Zaun, nur Versions-/Info-Lokalisierungen; Asset-Library-Pfade nicht enthalten |
| `scripts/asc_check.py` | Lese-Prüfung je Abschnitt (`--section screenshots` …); Kopfbild-Abschnitt gibt es nicht |
| `docs/specs/appstore/b3-betrieb-restschritte.md` | Muster: Screenshots lokal erzeugen, Vorschau, Upload „per Browser auf Hennings getipptes Wort“ |
| `RestockUITests/StoreScreenshotCaptureUITests.swift` | Aufnahmewerkzeug der Store-Bilder (läuft nicht in CI) |

## Existing Patterns
- Store-Bilder wurden lokal im Wegwerf-Simulator erzeugt, vor dem Upload per Artefakt-Vorschau gezeigt, dann hochgeladen und mit `asc_check` belegt.
- Entwurfsregel (CLAUDE.md global, 2026-09-22): Vorschau als veröffentlichte Artefakt-Seite mit „Heute“ neben „Entwurf“ in den echten App-Farben, Hell und Dunkel, mindestens eine Alternative; Ablage unter `docs/artifacts/<workflow>/`; erst nach Freigabe `/30-write-spec`.
- Erzeugung wiederholbar per Skript (`scripts/make-store-screenshots.sh` als Vorbild).

## Dependencies
- Upstream: Markenfarben, App-Symbol, Store-Texte, vorhandene Screenshots.
- Downstream: Nur die Store-Seite in App Store Connect. Kein App-Code, kein Schema, kein Manifest.

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (Haupt-Spec #175), `docs/specs/appstore/b3-betrieb-restschritte.md`

## Risks & Considerations
- **Upload-Weg unklar:** API-Pfad unbelegt, Zaun in `asc_lib` kennt ihn nicht. Fällt er weg, bleibt der Browserweg (wie bei den Screenshots) — das Werkzeug wird repariert, der Schritt nicht an den PO gereicht.
- **Zwei Zuschnitte:** Kopf (21:9) und Suchkarte (3:2) schneiden das 16:9-Bild verschieden; wichtige Inhalte müssen in beiden Zuschnitten sichtbar bleiben.
- **Hell/Dunkel:** Das Bild selbst hat nur eine Fassung; „Hell und Dunkel“ im Entwurf heißt: beide Varianten zeigen, PO wählt.
- **Außenwirkung:** Upload ist außenwirksam → nur auf getipptes Wort des PO; Einreichen ohne ausdrückliches Wort verboten.
- **Offene PR #140** (anderer Zweig) berührt dieses Thema nicht.
- Scope: keine Quelldatei der App; neue Dateien (Bilder, optional Erzeugungsskript) — LoC-Gate zählt Skript, nicht Bilder.

## Analysis

### Type
Feature (reine Store-Grafik, kein App-Code)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/artifacts/feat-241-kopfbild/entwurfsvorschau.html` | CREATE | Entwurfsvorschau (Heute, Entwurf A/B, Hell/Dunkel, Zuschnitte 21:9 und 3:2); veröffentlicht als Artefakt |
| `scripts/make-header-image.*` | CREATE (nach Freigabe) | Wiederholbare Erzeugung der zwei Größen aus dem freigegebenen Entwurf |
| `docs/artifacts/feat-241-kopfbild/kopfbild-5244x2950.png`, `kopfbild-3840x1646.png` | CREATE (nach Freigabe) | Fertige Bilder, ohne Transparenz |
| `docs/specs/appstore/kopfbild.md` | CREATE | Spec |

### Scope Assessment
- Files: 4–5, davon Bilder; LoC ca. +150 (Skript und Spec)
- Risk Level: LOW (kein App-Code, Upload nur auf Wort des PO)

### Technical Approach
Kein Modell, keine API-Annahme: Das Bild wird aus HTML/CSS (derselbe Entwurf wie die Vorschau) per Headless-Browser in 5244×2950 gerendert und die 3840×1646-Fassung daraus als 21:9-Zuschnitt neu gerendert. Inhalt bleibt im gemeinsamen Sicherheitsbereich (mittlere 76 % Höhe, mittlere 84 % Breite), damit Kopf und Suchkarte nichts abschneiden. Upload: zuerst prüfen, ob die App-Store-Connect-API das Kopfbild kennt (bisher keine Endpunkte gefunden); sonst Browserweg wie bei den Screenshots, nur auf Wort des PO. Alternative zum Entwurf A: Entwurf B (drei Läden). Alternative zum Rendern: Screenshots aus dem Simulator in ein Layout setzen; verworfen, weil die Liste im Entwurf ohnehin gezeichnet ist und so reproduzierbar bleibt.

### Dependencies
Markenfarben, App-Symbol, Store-Texte (`docs/appstore/de.md`); danach nur App Store Connect.

### Open Questions
- [ ] PO-Wahl: Entwurf A oder B, Hell oder Dunkel
- [ ] Nur deutsch oder auch englisches Bild? (Empfehlung: beide Sprachen, gleiche Gestaltung)
- [ ] API-Pfad für den Upload belegt oder Browserweg

### Nachtrag Analyse: Passt der Satz zum Alleinstellungsmerkmal? (PO-Frage 2026-11-06)
- PO wählt Entwurf A Hell, fragt aber, ob „Schreib auf, was fehlt.“ trifft, was Restock von anderen Einkaufslisten unterscheidet; eine frühere Untersuchung dazu liegt weder im Repo noch in Tickets noch in Memory (gesucht: docs, BACKLOG.md, Memory, `gh issue`), sie wird nicht rekonstruiert.
- Kurzrecherche (Web, 2026-11-06, dünn): Aufschreiben, Teilen, Barcode, Rezepte und Sortierung nach Marktweg gibt es bei anderen Apps (Bring, Listonic, AnyList, „Einkaufsliste“-App laut heise, Meinkaufen). Für Kassenbon-Scan mit Preislernen und automatische Zuordnung eines Artikels zum passenden Laden fand die Suche keine Treffer; das ist kein Beleg, dass es sie nicht gibt.
- Folgerung: „Schreib auf, was fehlt.“ beschreibt jede Liste. Unterscheidend sind laut App: Artikel landet selbst im richtigen Laden, Weg durch den Markt wird gelernt, Bon-Preise fließen in die Kostenschätzung.
- Quellen: heise.de/tipps-tricks/Einkaufslisten-Apps-im-Ueberblick-4883163.html, iphone-ticker.de/meinkaufen-app-will-einkaufslisten-einfacher-verwalten-277882/, foodieprep.ai/de/blog/einkaufsliste-app, listonic.com/best-grocery-list-apps

### PO-Entscheidung 2026-11-06
- Entwurf A, Fassung Hell. Satz: „Die Liste, die weiß, wo etwas hingehört.“ mit Unterzeile „Restock lernt deinen Weg durch den Markt und rechnet mit Preisen aus deinen Kassenbons.“
- Vorschau (Version 2, überarbeiteter Satz): https://claude.ai/artifact/MyUE3fUwcXd9PKtqygh9Qx, Datei `docs/artifacts/feat-241-kopfbild/entwurfsvorschau.html`.
- Noch offen für die Spec: Sprachen (Empfehlung de + en), Upload-Weg (API oder Browser), Erzeugungsweg (Headless-Browser, Schriften).

- PO-Entscheidung 2026-11-06 (Auswahl): Sprachen Deutsch und Englisch, wie in der Spec.
