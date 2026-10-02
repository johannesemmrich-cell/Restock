# Context: Bon-Namenserkennung – Regelwerk ausbauen statt Sprachmodell (#14)

## Request Summary
Henning: „Prüfe, was sich durch ein Regelwerk besser erfassen lässt als durch ein LLM.“ Issue #14
fordert: erst die Durchfall-Quote je Stufe messen (Nulllinie), dann Regel-Hebel umsetzen, dann erneut messen.

## Ist-Zustand (verifiziert am Code, 2026-10-02)
Auflösung pro Bon-Zeile in `ReceiptResolutionService.resolve` (`SmartCart/Services/ReceiptResolutionService.swift:75-195`),
erste treffende Stufe gewinnt:
1. gelernter Alias – `ReceiptAliasService.shared.resolve`
2. Wörterbuch – `ReceiptParserService.expandAbbreviations` (`ReceiptParserService.swift:1033-1091`; 21 Kürzel + 4 Phrasen)
3. Fuzzy gegen **abgehakte** Artikel dieses Ladens – `completedItemCandidates`, Auto-Übernahme ab 0,6 (`:1168`)
4. Fuzzy gegen Kaufhistorie **desselben Ladens** – `historyMatch` (`:1221`), Schwelle 0,6
5. Apple Intelligence – `ReceiptNameAIResolver.expand` (`:1255`), nur iOS 26+, 25 s Timeout, `KEIN_PRODUKT`-Ausweg
6. Rohtext bleibt stehen

Bewertung überall `lcsSimilarity` (Dice über längster gemeinsamer Teilsequenz, `:1110`).

## Abgleich der Issue-Behauptungen mit dem Code
| Hebel im Issue | Befund |
|---|---|
| a) Wortschatz (`knownItemNames`, 40 Namen) nur als Prompt-Hinweis | **Teilweise falsch.** Stufe 3 gleicht bereits gegen abgehakte Artikel ab, Stufe 4 gegen die Laden-Historie. Wahr bleibt: nicht-abgehakte Artikel des Ladens (`store.items`) und Historie **anderer** Läden fließen nur in den Prompt bzw. nur in Vorschlags-Chips (`suggestionPool`), nie in die Auto-Übernahme. |
| b) Stufe 4 sucht nur im selben Laden | **Stimmt** (`historyMatch` filtert `storeName`). Doku nennt es „bewusst“ (kein ladenübergreifendes Auto-Apply). Ladenübergreifend als Rangkriterium statt Filter wäre ein Gegenentwurf zu dieser Entscheidung. |
| c) Wörterbuch ist ein Startsatz | **Stimmt.** Wächst nur per Bugreport. Kommentar warnt: Fehltreffer in Stufe 2 sind final. |
| d) Verwaltungszeilen in den Filter statt Prompt | **Stimmt teilweise.** `isAdminLine` (`:96`) filtert beim Parsen bereits; `KEIN_PRODUKT` ist Sicherheitsnetz für Durchrutscher (Fall 24.08.2026, Phantom-„Pizza Baguette“). |

## Nulllinie – fehlt tatsächlich
- Kein Zähler, wie oft welche Stufe greift oder durchfällt. `resolvedByAI` pro Zeile existiert, wird aber nirgends aggregiert.
- **Kein Korpus echter Bons im Repo** (keine Fixtures außer Testdaten in `ReceiptParser*Tests`, `ReceiptKnownItemNamesTests`, `ReceiptHistoryMatchTests`).
- **Stufe 5 läuft in Simulator/CI nicht** (Apple Intelligence nicht verfügbar) – ihre Trefferquote ist dort nicht messbar, nur auf einem Gerät mit Apple Intelligence. Die Regel-Spalte dagegen ist überall messbar.
- Alias-Speicher (`ReceiptAliasService`) und Kaufhistorie sind Nutzerdaten – eine Messung braucht entweder anonymisierte Echtdaten von Henning oder einen synthetischen Satz.

## Related Files
| Datei | Relevanz |
|---|---|
| `SmartCart/Services/ReceiptResolutionService.swift` | Stufen-Kaskade, `knownItemNames` |
| `SmartCart/Services/ReceiptParserService.swift` | Wörterbuch, `lcsSimilarity`, `completedItemCandidates`, `historyMatch`, `isAdminLine`, `ReceiptNameAIResolver` |
| `SmartCart/Services/ReceiptAliasService.swift` | Stufe 1 (gelernte Korrekturen) |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | Aufrufer (`process()`, `reResolveAIIfNeeded()` für Share-Handoff) |
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | Zeigt KI-Kennzeichnung (Art. 50), Auswahlzeilen |
| `RestockTests/ReceiptAbbreviationExpansionTests`, `ReceiptHistoryMatchTests`, `ReceiptKnownItemNamesTests`, `ReceiptNameAIResolverSanitizeTests`, `ReceiptParserSuggestionTests` | bestehende Tests der Stufen |

## Dependencies
- Upstream: `PurchaseRecord`-Historie, `Store.completedItems`/`items`, `ReceiptAliasService`, FoundationModels (iOS 26).
- Downstream: Share Extension (ruft `resolve` mit `allowAIResolution: false`), Review-Screen, `save()` (Preis-/Lernschreibung über `matchedItemID`).

## Existing Specs
- `docs/specs/views/receipt-review-card.md`, `receipt-review-card-nachtrag-1b.md`
- `docs/specs/services/receipt-parser-quantity-confirmation.md`
- `docs/context/fix-37-receipt-name-preselect.md`, `fix-52-fuzzy-price-match.md`, `fix-66-ai-resolved-name-selection.md` (Vorarbeiten zur Namenswahl)
- Keine Spec für die Stufen-Kaskade selbst.

## Offene Alternativen (für /20-analyse, Regel vor Modell)
- Regelweg: Wörterbuch datengetrieben erweitern; `store.items` + alle Läden als Rangkriterium; Admin-Filter vor Prompt; Normalisierung (Umlaute, Gewichtsangaben wie „8x130Bl“ abtrennen) vor `lcsSimilarity`.
- Modellweg ist die Alternative: Stufe 5 behalten, aber nur für Rest nach den Regeln; oder ganz streichen, wenn die Messung zeigt, dass sie weniger trifft, als sie erfindet.
- Bei der Messung gilt die Regel „Nulllinie zählt“: Regel-Spalte vs. Modell-Spalte, ohne Rücksicht auf bestehende Architektur.

## Risks & Considerations
- Falsche Auto-Übernahme in Stufe 2–4 ist stiller als ein Rohtext (Datenverfälschung, Lernen falscher Preise → Berührung mit #10/#11). Schwellen nicht ohne Messung anheben/senken.
- Komposita-Kollisionen (`Apfel`/`Apfelsaft` ≈ 0,71) sind dokumentierte Grenze von `lcsSimilarity`.
- Ladenübergreifendes Auto-Apply kippt eine bewusste frühere Entscheidung (Kommentar `historyMatch`).
- Datenschutz: Echtbons für einen Korpus brauchen Hennings Freigabe/Anonymisierung.
- #49 (Open Prices) und #13-Preismodell sind separate Themen; Produktnamen aus Open Food Facts als Wörterbuchquelle wäre neue Netzabhängigkeit – nicht Teil dieses Tickets ohne Entscheidung.
- Scoping: Messung und jeder Hebel einzeln halten (≤ 4–5 Dateien, ±250 LoC pro Änderung); Issue ist vermutlich in mehrere Tickets zu splitten.

## Analysis

### Type
Feature (Messung zuerst). Kein Bug.

### Recherche (Stand 2026-10-02)
Zwei allgemeine Suchen ergaben nichts Bon-Spezifisches für deutsche Märkte. Belegt ist nur: Kürzel sind
Platzprodukte der Kasse; der Stand der Praxis ist hybrid (Regeln für das Gewöhnliche, Modell für den Rest).
Eine 98-%-F1-Angabe für „Name expandieren“ gilt für GPT-4 auf Produktattributen, nicht für das kleine
On-Device-Modell – sie trägt nichts für Stufe 5. Quellen:
- https://arxiv.org/abs/2403.02130
- https://tianpan.co/blog/2026/04/17/llm-data-normalization-production
- https://hal-univ-rochelle.archives-ouvertes.fr/hal-02316286v1
Konsequenz: eigene Messung ist unvermeidlich, es gibt keinen Fremdwert.

### Ohne Modell geht es nicht, weil …
… für Kürzel ohne Bezug zu Wörterbuch, Liste oder Historie (neues Produkt, kryptisches Kürzel) keine Regel
den Namen kennt. Beleg dafür fehlt aber: es gibt keine Zahl, wie oft das vorkommt. Bis dahin ist der
Regelweg der Vorschlag.

### Befund zu den Hebeln (siehe Abgleich oben)
- a) teils falsch (Stufe 3/4 existieren), wahr nur für offene Artikel + andere Läden → identisch mit b).
- Eigentliches Loch: **die Wahrheit über die Stufen fehlt**. `save()` sieht pro Zeile Rohtext, aufgelösten
  Namen und finalen Namen (`ReceiptScannerView.swift:639-651`) – damit ist die Korrekturquote je Stufe
  ohne Fremddaten messbar: Nutzer ändert Namen = Stufe lag falsch.

### Technischer Ansatz (Empfehlung, dieses Ticket = nur Messung)
1. `ResolvedReceiptLine` bekommt `stage` (Alias/Wörterbuch/Abgehakt/Historie/KI/Rohtext/Nicht-Produkt),
   Default-Wert für Alt-Payloads der Share-Extension (Codable-sicher, wie `resolvedByAI`).
2. Beim Speichern zählt ein kleiner lokaler Zähler (App-Gruppe, nur Zahlen, keine Namen) je Stufe:
   Zeilen gesamt / vom Nutzer geändert / als Nicht-Produkt abgewählt.
3. Anzeige in der bestehenden Dev-Ansicht (Settings, Muster `ReplenishmentStatsView`) – sichtbar nur im
   Entwicklermodus.
4. Regelspalte zuerst: Auflösungs-Kaskade ohne Stufe 5 ist im Simulator/CI testbar; Stufe 5 nur auf
   Hennings Gerät durch den Zähler messbar.

### Alternativen (Pflicht)
- **Kein Zähler, Korpus-Harness im Test-Target** mit Hennings anonymisierten Bons: wiederholbar, aber braucht
  Echtdaten von ihm und deckt Stufe 5 nie ab. Als Ergänzung später möglich.
- **Stufe 5 komplett streichen, stattdessen Vorschlag statt automatisch setzen:** Rohtext bleibt, Review
  zeigt Chips aus Liste + gesamter Historie. Kippt die KI-Kennzeichnung (Art. 50), das 25-s-Budget und den
  Sonderweg der Teilen-Erweiterung; Preis: mehr Taps. Entscheidung erst nach der Messung.
- **Wörterbuch nur aus Korrekturen speisen** statt Open Food Facts → #91.
- Gekippte frühere Entscheidungen je Alternative: ladenübergreifendes Auto-Apply (→ #89, Kommentar in
  `historyMatch`); „KEIN_PRODUKT im Prompt“ (→ #90).

### Affected Files
| File | Change | Beschreibung |
|---|---|---|
| `SmartCart/Services/ReceiptResolutionService.swift` | MODIFY | `stage` je Zeile setzen |
| `SmartCart/Views/Prices/ReceiptScannerView.swift` | MODIFY | in `save()` Korrektur vs. Auflösung zählen; `stage` durch die drei Konstruktionsstellen reichen |
| `SmartCart/Services/ReceiptResolutionStats.swift` | CREATE (+pbxproj) | Zähler, App-Gruppe |
| `SmartCart/Views/Settings/ReceiptResolutionStatsView.swift` | CREATE (+pbxproj) | Dev-Anzeige |
| `SmartCart/Views/Settings/SettingsView.swift` | MODIFY | Link im Dev-Abschnitt |
| `RestockTests/ReceiptResolutionStatsTests.swift` | CREATE | Tests der Zählung |

### Scope Assessment
- Files: 6 (davon 3 neu) – knapp über 4–5 wegen pbxproj; LoC ≈ +200. Risk: NIEDRIG (nur zählen, Verhalten der Auflösung unverändert).
- Folge-Tickets: #89 (ladenübergreifend), #90 (Nicht-Produkt-Regel), #91 (Wörterbuch).

### Dependencies
Share-Extension-Payload (Codable, Alt-Payloads), App-Gruppe, Dev-Modus-Einstellungen.

### Open Questions
- [x] **FREIGEGEBEN 2026-10-02 (Henning): Variante A** (eigener Bildschirm „Bon-Auflösung“ im Entwicklermodus, alle Stufen einzeln, Zurücksetzen). Nächster Schritt `/30-write-spec #14`.
- (erledigt) Entwurf liegt vor (`docs/artifacts/bon-namenserkennung-regelwerk-14/entwurf.html`, veröffentlicht: https://claude.ai/artifact/PcvB4pxmku2SAyjwVEvgmJ) — Variante A (eigener Bildschirm, empfohlen) vs. B (Abschnitt in Nachkauf-Statistik). Freigabe/Korrektur durch Henning steht aus, erst dann `/30-write-spec`.
- (Hintergrund) UI-Entwurf: Die Dev-Anzeige ist sichtbar neu → laut Regel Vorschau („Heute“ vs. Entwurf, Dunkel/Hell, 1 Alternative) vor `/30-write-spec`, unter `docs/artifacts/bon-namenserkennung-regelwerk-14/`. Kleine Alternative: Zahlen nur als Text in der bestehenden Nachkauf-Statistik statt eigener Bildschirm.
