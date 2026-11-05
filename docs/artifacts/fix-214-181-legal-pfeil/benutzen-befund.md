# Benutzen-Befund (AC-16) — fix-214-181-legal-pfeil

- Stand: Basis-Commit 78f5756 plus uncommittete Umsetzung (LegalView.swift, beide Localizable.strings, Testergänzungen); Commit folgt nach dem Adversary-Verdict
- Zeit der Läufe: 2026-11-05, ca. 11:32 (hell) und 11:35 (dunkel), Uhrzeit aus der Statusleiste der Aufnahmen
- Gerät: Simulator Restock-Validate-272 (6728F5AB-712F-46E0-A1D1-2047A9771C8E), Schriftgröße AccessibilityXXXL
- Herkunft: `XCTAttachment` aus `DynamicTypeUITests` (echter Lauf, aus dem xcresult exportiert, nicht von Hand gesetzt)
- Angesehen von Claude (Orchestrator): Datenschutz dunkel, Nutzungsbedingungen hell, Rezeptplan dunkel. Die übrigen fünf Aufnahmen hat der Developer-Agent angesehen und beschrieben; sie sind vom Orchestrator nicht einzeln geprüft.

| Aufnahme | Absätze sichtbar | Trennlinie statt ——— | Aufzählungspunkte | Pfeil sichtbar |
|---|---|---|---|---|
| green-datenschutz-xxxl-hell | ja (Agent) | ja (Agent) | n. z. (Abschnitt 5 liegt unterhalb) | n. z. |
| green-datenschutz-xxxl-dunkel | ja (Adresse dreizeilig, Überschriften fett) | ja | n. z. | n. z. |
| green-nutzungsbedingungen-xxxl-hell | ja | ja | ja (8 Punkte sichtbar: 5 normal, 3 mit fettem Anfang, der letzte am unteren Rand angeschnitten; hängende Einrückung) | n. z. |
| green-nutzungsbedingungen-xxxl-dunkel | ja (Agent) | ja (Agent) | ja (Agent) | n. z. |
| green-impressum-xxxl-hell | ja (Agent) | ja (Agent) | n. z. | n. z. |
| green-impressum-xxxl-dunkel | ja (Agent) | ja (Agent) | n. z. | n. z. |
| green-rezeptplan-hinweis-xxxl-hell | n. z. | n. z. | n. z. | ja (Agent) |
| green-rezeptplan-hinweis-xxxl-dunkel | n. z. | n. z. | n. z. | ja: „… nach rechts wischen → "Speichern"." steht ganz im Bild, kein „u{2192}“ |

Beobachtungen: Der Rechtstext wächst bei AccessibilityXXXL nicht mit (feste Schrift 14, Bestand, nicht Teil dieses Tickets). E-Mail-Adresse erscheint farbig als Link; ein Tipp darauf wurde nicht geprüft. Bedienung mit VoiceOver wurde nicht geprüft.
