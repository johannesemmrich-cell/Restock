# Adversary-Dialog B1 (#175, feat-175-b1-store-texte)

Testausgabe des Prüfers (selbst ausgeführt, Exit 0): 43 ok, 0 FAIL. Kopie: docs/artifacts/feat-175-b1-store-texte/laengen.txt (vom Prüfer neu geschrieben).

## Checkliste

- [x] AC-9: de.md und en.md haben genau die sieben Überschriften in Spec-Reihenfolge, kein whats_new, alle Werte nicht leer.
- [x] AC-9a: Längen unabhängig nachgerechnet und gleich der Spec-Tabelle (de: name 7, subtitle 27, keywords 93 Bytes/91 Zeichen, promo 104, desc 2008; en: 7, 28, 87/87, 109, 1844); kein Schlüsselwort ≤ 2 Zeichen; keine Überschneidung Schlüsselwörter mit Name/Untertitel.
- [x] AC-9b: verbotene Begriffe fehlen in beiden Dateien; Schlüsselwörter ohne Einkaufsliste, shopping list, Restock.
- [x] AC-9c: beide Beschreibungen enden mit Datenschutz-URL und Apple-EULA-URL; privacy_url und support_url wie gefordert.
- [x] AC-9d: datenschutz.md hat ## Deutsch und ## English; Deutsch ist zeichengenau (strikt, nicht nur whitespace-normalisiert) gleich LegalView.privacyPolicy (79 Zeilen); English nennt die deutsche Fassung als maßgeblich (Zeile 87).
- [x] Freigabe: alle Feldwerte (name, subtitle, keywords, promotional_text) und beide Beschreibungen sind wortgleich mit dem Abschnitt Texte (Entwurf zur Freigabe) der Spec (eigener Vergleich; einziger Unterschied war ein von mir beim Schneiden erzeugter Schlusszeilenumbruch).
- [x] Randfälle: kein BOM, keine CR, keine unsichtbaren Zeichen (Kategorien Cf/Cc/Zs außer Leerzeichen), keine Leerzeichen am Zeilenende, keine Doppelleerzeichen, keine Markdown-Reste in den Feldwerten, Dateien enden mit genau einem Zeilenumbruch, Werte ohne Rand-Leerraum.
- [x] Englische Übersetzung: absatzweise geprüft, alle sieben Abschnitte samt Unterabschnitten vorhanden, Aufzählung der Rechte vollständig, keine erfundenen Fakten.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (precondition_origins.default_lang); Durchgang B1 schreibt nur Textdateien, keine Produktionsfelder.

### Runde 1

Prüfer ausgeführt, Ergebnis 43/43. Prüferlücken gesucht: Er vergleicht die Überschriftenfolge als Liste (Reihenfolge ok) und fängt leere Werte. Er vergleicht Feldwerte NICHT mit dem Spec-Wortlaut und prüft keine unsichtbaren Zeichen, Anführungszeichenart oder Zeilenenden. Verbotene Begriffe werden über die ganze Datei gesucht (strenger als nötig).

Code reference: docs/artifacts/feat-175-b1-store-texte/check_b1.py:41
Code reference: docs/appstore/de.md:1
Code reference: docs/appstore/en.md:1

### Runde 2

Eigene Gegenrechnung mit separatem Python: Spec-Werte gegen Dateiwerte (Feld für Feld, Beschreibung Zeile für Zeile), Byte- und Zeichenlängen, Scan auf unsichtbare Zeichen, Zeilenenden, strikter Vergleich Deutsch gegen LegalView, inhaltlicher Absatzvergleich der englischen Datenschutzfassung. Keine Abweichung. Anführungszeichen: de-Beschreibung nutzt typografische, en-Beschreibung gerade (identisch zur freigegebenen Spec); im deutschen Datenschutztext steht wie in der App-Quelle öffnend typografisch, schließend gerade, bewusst wortgleich.

Code reference: docs/appstore/datenschutz.md:3
Code reference: SmartCart/Views/Settings/LegalView.swift:51
Code reference: docs/specs/appstore/app-store-auftritt.md:197

### Runde 3

Nachtrag des Orchestrators nach dem Dialog: `qa_gate.py` erkannte die Summenzeile „43 ok, 0 FAIL“ nicht („Could not determine test result“). Einzige Änderung am Prüfer: die Summenzeile lautet jetzt „43 passed, 0 failed“ (Zeile 85); die Prüflogik ist unverändert. Erneuter Lauf: 43 passed, 0 failed, Exit 0 (`test-green-output.txt`). Die Gegenproben aus `gegenprobe.txt` hängen nicht an der Summenzeile.

Code reference: docs/artifacts/feat-175-b1-store-texte/check_b1.py:85

## Findings

- {id: F001, severity: LOW, category: anti_pattern, description: check_b1.py prüft den Spec-Wortlaut der Feldwerte nicht und kennt keine Zeichen-Hygiene (unsichtbare Zeichen, CR, BOM), evidence: docs/artifacts/feat-175-b1-store-texte/check_b1.py:41-66; eigene Gegenprobe zeigt, dass die Dateien trotzdem sauber sind, remediation: Im dauerhaften Test von B2 Wortgleichheit mit der Spec und einen Scan auf Cf/Cc-Zeichen ergänzen. Kein Blocker für B1.}

Keine CRITICAL-, HIGH- oder MEDIUM-Findings.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:d54795f35e203d162b215a975a7be32ba2af6f2639f9d2fcc1386d898816ce44  SmartCart/Views/Settings/LegalView.swift
- sha256:71978bb4048ed2d8d69bf1bd45e51a9199464c07e22991e01645e22dcc6840a7  docs/appstore/datenschutz.md
- sha256:b9cb1936d6fb0a589e7f781d53c533c5c2744718d9ae14e89dd3787604994391  docs/appstore/de.md
- sha256:4ae666076442ce0629728e91d7f5b2d4eb9f0a31cde44290be5ef32478d60196  docs/appstore/en.md
- sha256:675f4b12e52cd21aed81291f2c5ec87c1c609a470cd074564dec2d8d21b72fd5  docs/artifacts/feat-175-b1-store-texte/check_b1.py
- sha256:895eddd0e35ea0ab6f3728b20ee5175de8d3fa21d9f1f9e0765c36837900cc58  docs/specs/appstore/app-store-auftritt.md

## Prüfbasis

- base: 3b86b0bd6a9442f803924c67cf1c18b689ac3580
- blob:e4f02a43f89d2b625b35188bca22e0bafb3daff6  SmartCart/Views/Settings/LegalView.swift
- blob:2b81a8d551bae96c818777d0e3d9083c09179d6b  docs/appstore/datenschutz.md
- blob:c75f5775cefbeccc51f681e497a6404abe1d8d82  docs/appstore/de.md
- blob:eab193e5d18d4e7eb2c739984378dbf1e536683d  docs/appstore/en.md
- blob:8b495d41ed302d017059d3f729975174f9351e34  docs/artifacts/feat-175-b1-store-texte/check_b1.py
- blob:5d2c1b2a3a8be2e2ba7d21061c7b7b4e46798a87  docs/specs/appstore/app-store-auftritt.md
