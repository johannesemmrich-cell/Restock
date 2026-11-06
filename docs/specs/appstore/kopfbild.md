---
entity_id: kopfbild
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
version: "1.0"
workflow: feat-241-kopfbild
tags: [feature, appstore, kopfbild, release-1-0, issue-241]
---

# App Store Kopfbild (Issue #241)

## Approval

- [ ] Approved

Quelle: `docs/context/feat-241-kopfbild.md`, Entwurfsvorschau `docs/artifacts/feat-241-kopfbild/entwurfsvorschau.html`
(Artefakt https://claude.ai/artifact/MyUE3fUwcXd9PKtqygh9Qx). Fortschreibung von `docs/specs/appstore/app-store-auftritt.md`
(Haupt-Spec #175, gesperrt); die dortigen ACs gelten unverändert.

## Purpose

Die App-Store-Seite von Restock 1.0 bekommt ein Kopfbild („Kopfzeile und Suchergebnisse“). Es ist für die Veröffentlichung
nicht nötig und zählt erst bei Einreichung für Hervorhebungen, soll aber fertig im Repo liegen und in App Store Connect
hinterlegt sein. Es ist reine Store-Grafik: kein App-Code, kein Schema, kein Manifest.

Hat es bisher funktioniert? Es gab noch nie ein Kopfbild; keine Störung, sondern neue Arbeit.

PO-Entscheidung 2026-11-06: Entwurf A, Fassung Hell. Satz „Die Liste, die weiß, wo etwas hingehört.“, Unterzeile
„Restock lernt deinen Weg durch den Markt und rechnet mit Preisen aus deinen Kassenbons.“ Gestützt auf die Analyse: Der
alte Satz „Schreib auf, was fehlt.“ beschreibt jede Liste; unterscheidend sind Ladenzuordnung, gelernter Weg und
Bon-Preise. Belege ohne Anspruch auf Vollständigkeit (andere Apps könnten Ähnliches haben): Abschnitt „Nachtrag Analyse“
im Kontextdokument.

## Source

- Apple „Creative assets specifications“: Produktseiten-Kopf 21:9 (3840 × 1646), Suchergebnisse 3:2 (1920 × 1280 bis 3840 × 2560), JPEG/PNG, kein Alphakanal; das 16:9-Bild 5244 × 2950 gilt für beide Plätze, beide Zuschnitte werden von Apple unterschiedlich gewählt.
- `docs/appstore/{de,en}.md` (Name, Untertitel, Werbetext), `SmartCart/Assets.xcassets` (`AppIcon-1024.png`, `RC*.colorset`)
- `scripts/asc_lib.py` (`ALLOWED`: kennt keinen Pfad für Kopfbilder)

## Dependencies

| Art | Abhängigkeit | Stand |
|-----|--------------|-------|
| Upstream | Google Chrome (headless) auf dem Mac für das Rendern | vorhanden (`/Applications/Google Chrome.app`) |
| Upstream | Konto in App Store Connect (Browser) für den Upload | vorhanden |
| Blocker extern | Upload ist außenwirksam: nur nach getipptem Wort des PO | offen |
| Downstream | Nur die Store-Seite; kein Code | – |

## Scope

- **Affected Files:** `scripts/make-header-image.sh` (neu), `scripts/header-image/kopfbild.html` (neu, Vorlage mit Platzhaltern für Sprache), `scripts/test_header_image.py` (neu, Strukturtest), vier Bilder unter `docs/artifacts/feat-241-kopfbild/`, diese Spec.
- **Estimated Changes:** ca. +150 LoC (Skript, Vorlage, Test); Bilder zählen nicht.

Nicht im Umfang: Einreichen zur Prüfung (verboten ohne ausdrückliches Wort des PO), Dunkel-Fassung (PO wählte Hell),
Änderung der Store-Texte, Änderung von `asc_lib`/`asc_check`.

## Requirements

1. Das Kopfbild zeigt Entwurf A Hell wie in der freigegebenen Vorschau: Symbol, Satz, Unterzeile, Karte „Lidl · 5“ mit vier Zeilen und Schätzpreisen. Farben aus den Marken-Farbsätzen `RCCanvas`, `RCSurface`, `RCAccent` (Hellwerte).
2. Zwei Größen aus einer Vorlage: 5244 × 2950 (16:9, gilt für Kopf und Suche) und 3840 × 1646 (21:9, Seitenkopf), jeweils neu gerendert, nicht nachträglich skaliert oder beschnitten.
3. Aller Inhalt liegt im gemeinsamen Sicherheitsbereich (mittlere 76 % der Höhe, mittlere 84 % der Breite), damit weder der 21:9-Kopf noch die 3:2-Suchkarte etwas abschneidet.
4. Sprachen: Deutsch und Englisch, gleiche Gestaltung. Englischer Text: „The list that knows where things belong.“ / „Restock learns your way through the store and works out costs from your receipts.“ (Kartenzeilen englisch: „Bananas · 1 kg“, „Bread“, „Milk“, „Pasta“, Preise „ca.“ → „approx. €1.80“ usw.).
5. Das Bild hat keinen Alphakanal und ist PNG.
6. Erzeugung wiederholbar: `scripts/make-header-image.sh [de|en]` rendert mit Chrome headless in genau die Zielgrößen und prüft Breite/Höhe der Ergebnisse (Abbruch bei Abweichung).
7. Upload: Zuerst wird belegt, ob die App-Store-Connect-API das Kopfbild kennt (OpenAPI 4.5.1 durchsuchen). Gibt es keinen Pfad, geschieht der Upload im Browser (wie bei den Screenshots), jeweils erst nach getipptem Wort des PO. `asc_lib.ALLOWED` wird nicht erweitert, ohne dass ein Pfad belegt ist.

## Acceptance Criteria

- AC-1: `scripts/make-header-image.sh de` erzeugt `docs/artifacts/feat-241-kopfbild/kopfbild-de-5244x2950.png` und `kopfbild-de-3840x1646.png` mit exakt diesen Pixelmaßen.
- AC-2: Dasselbe für `en` (`kopfbild-en-5244x2950.png`, `kopfbild-en-3840x1646.png`).
- AC-3: Keines der vier PNGs hat einen Alphakanal (Farbtyp ohne Alpha, geprüft im Strukturtest).
- AC-4: Der sichtbare Text der deutschen Fassung enthält wörtlich „Die Liste, die weiß, wo etwas hingehört.“ und die Unterzeile aus der PO-Entscheidung; der Text steht in der Vorlage genau einmal je Sprache (Strukturtest).
- AC-5: Aller Text und alle Kartenzeilen liegen innerhalb des Sicherheitsbereichs (mittlere 76 % Höhe, mittlere 84 % Breite) in beiden Größen; geprüft per Messung der Elementrahmen im gerenderten Dokument (Chrome `--dump-dom` mit Messskript) oder, falls nicht möglich, durch Pixelprüfung, dass außerhalb des Bereichs nur die Hintergrundfarbe vorkommt.
- AC-6: Beide Zuschnitte, Seitenkopf 21:9 und Suchkarte 3:2, werden als Bild gegen die gerenderte 16:9-Fassung gelegt und dem PO vor dem Upload gezeigt (Artefakt-Vorschau); nichts Wichtiges ist abgeschnitten.
- AC-7: Die Farben der Vorlage stimmen mit den Hellwerten von `RCCanvas`, `RCSurface`, `RCAccent` in den Colorsets überein (Strukturtest vergleicht).
- AC-8: Ein Beleg zum Upload-Weg liegt im Repo (`docs/artifacts/feat-241-kopfbild/upload-weg.md`): ob die API einen Pfad kennt, mit Quelle.
- AC-9: Hochgeladen wird erst nach getipptem Wort des PO („Upload jetzt“); eingereicht wird nichts. Der Nachweis nach dem Upload ist ein Screenshot der Seite in App Store Connect mit Bild in beiden Sprachen, abgelegt unter `docs/artifacts/feat-241-kopfbild/`.

## Test Plan

- `scripts/test_header_image.py` (Python, läuft ohne Chrome im CI-Schritt „Strukturtests (Python)“): Vorlage enthält die Pflichttexte genau einmal je Sprache, Farbwerte gleich den Colorsets, Skript nennt beide Zielgrößen. Das Rendern selbst und die Pixelprüfung (AC-1, AC-2, AC-3, AC-5) laufen lokal im Skript und werden im Protokoll `docs/artifacts/feat-241-kopfbild/render-protokoll.txt` belegt (Chrome gibt es im CI nicht verlässlich).
- Kein UI-Test: kein App-Code berührt.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine

Begründung: reine Store-Grafik ohne App-Code, kein Schema, keine neue Abhängigkeit. Der Erzeugungsweg (HTML/CSS mit Chrome headless statt Layout aus Simulator-Screenshots) ist Werkzeugwahl innerhalb dieser Spec.

## Definition of Done

- [ ] `scripts/test_header_image.py` grün
- [ ] Vier PNGs mit exakt den Pixelmaßen aus AC-1 und AC-2, ohne Alphakanal
- [ ] Render-Protokoll `docs/artifacts/feat-241-kopfbild/render-protokoll.txt` vorhanden
- [ ] Zuschnitt-Vorschau (21:9 und 3:2) dem PO gezeigt
- [ ] `docs/artifacts/feat-241-kopfbild/upload-weg.md` vorhanden
- [ ] Upload erst nach getipptem Wort des PO, nichts eingereicht

## Known Limitations

- Ob Apple das Kopfbild bei Hervorhebungen berücksichtigt, hängt von Apple ab.
- Schätzpreise der Karte sind Beispielwerte, keine Messung.
- „Heller Entwurf“ gewählt; Dunkel entfällt, weil das Bild nur eine Fassung hat.
- Die Alleinstellungs-Aussage stützt sich auf eine dünne Kurzrecherche (keine Treffer, kein Beleg für Nichtexistenz).
- Upload per Browser kann an Oberflächenänderungen von App Store Connect scheitern; dann wird der Weg angepasst, nicht an den PO weitergereicht.

## Changelog

- 2026-11-06: Spec angelegt (Entwurf A Hell, PO-Entscheidung).
