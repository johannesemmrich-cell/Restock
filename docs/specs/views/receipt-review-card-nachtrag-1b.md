---
entity_id: receipt-review-card-nachtrag-1b
type: feature
created: 2026-09-27
updated: 2026-09-27
status: draft
workflow: fix-50-import-dialog-design
parent_spec: docs/specs/views/receipt-review-card.md
tags: [feature, ui, receipt-scanner, nachtrag]
---

# Nachtrag Issue #50, Paket 1b (2026-09-27): Markierung entscheidet, nicht Namensgleichheit

## Approval

- [ ] Approved

## Geltung und Vorrang

Dieser Nachtrag gehört zur Spec `docs/specs/views/receipt-review-card.md` (`entity_id:
receipt-review-card`) und ist ihr jüngster Stand. **Bei Widerspruch zwischen diesem Nachtrag und dem
Text der Hauptspec gilt dieser Nachtrag** — er wurde ausdrücklich geschrieben, um einen Widerspruch
IN der Hauptspec aufzulösen (Invariante 6 gegen „Known Limitations", siehe F001 unten).

Jeder Abschnitt unter „Wörtliche Ersetzungen in der Hauptspec" nennt den Zeilenbereich der
Hauptspec (Stand `234667dab0bd…`, 1003 Zeilen, der vom Adversary geprüfte Stand) und den neuen
Wortlaut. Die Ersetzungen sind gemeinsam anzuwenden — punktuelle Übernahme einzelner Stellen ist
ausdrücklich unzulässig (Lehre aus Issue #10: eine punktuell korrigierte Spec kostete fünf
Prüfrunden).

**Anlass:** Der Adversary-Prüfdialog zu Paket 1
(`docs/artifacts/fix-50-import-dialog-design/adversary-dialog.md`, Urteil **AMBIGUOUS**) fand zwei
Lücken: **F001 (HIGH, `spec_violation`)** und **F002 (MEDIUM, `edge_case`)`. Der PO hat am
2026-09-27 die Behebung **beider** beauftragt. F003/F004 (beide LOW, vorbestehend) bleiben offen und
werden als Folge-Issues angelegt (siehe „Known Limitations").

## Purpose

Schließt die zwei Lücken, die der Prüfdialog an Paket 1 fand, und beseitigt den dabei
offengelegten Selbstwiderspruch der Hauptspec: Die Markierung einer Auswahlzeile wird künftig an
EINER Stelle entschieden (`isSelectedIgnoringCustom`), und die Regeln, die Zeilen entfernen (Dedup,
Regel 2) oder einfügen (Regel 5), fragen dieselbe Stelle, statt mit Namensgleichheit zu arbeiten.
Ein Name aus reinen Leerzeichen verhält sich künftig wie ein leeres Feld.

---

## Befund F001 (HIGH): „keine Option markiert" bleibt für den KI-Zweig bestehen

### Der Ablauf, Schritt für Schritt

1. `ReceiptResolutionService.resolve` berechnet `resolvedName` VOR der KI-Stufe
   (`ReceiptResolutionService.swift:120`) und filtert die Vorschlagsliste gegen genau diesen
   **Vor-KI-Namen** (`:152`). Erst danach überschreibt Stufe 5 (Apple Intelligence) den Namen
   (`:175-176`). Ein von der KI aufgelöster Name kann deshalb unverändert in `line.suggestions`
   stehen.
2. `mergeAIReresolution` (`ReceiptScannerView.swift:126-141`) schreibt `name`, `suggestions`,
   `matchedItemID` und `resolvedByAI = true` in die Zeile. Für eine KI-Zeile ist `matchedItemID`
   **immer `nil`**: der `matchedItemID`-Nachgriff in `resolve` (`:130-140`) benutzt dieselbe
   Bedingung wie Stufe 3 (Ähnlichkeit ≥ `completedItemAutoApplyThreshold`, 0,6), die für eine
   `needsAI`-Zeile gerade fehlgeschlagen ist.
3. `selectionOptions` (`ReceiptReviewCard.swift:415-454`): Dedup-Regel 2 (`:418-425`) entfernt die
   `.aiSuggestion`-Zeile, weil ein `.listMatch` denselben Namen trägt. Regel 3 (`:428-433`) sortiert
   diesen `.listMatch` nach vorn. Regel 5 (`:443-447`) greift **nicht**, weil ein Kandidat
   case-insensitiv `line.name` entspricht.
4. `isSelected(.listMatch)` (`:368-371`) liefert trotzdem `false`: es verlangt `!line.resolvedByAI`
   (nach `mergeAIReresolution` ist das `true`) **und** `line.matchedItemID == suggestion.itemID`
   (für KI-Zeilen ist `matchedItemID` `nil`).

**Ergebnis: NULL markierte Zeilen bei nicht-leerem `line.name`** — genau Punkt 4 aus Issue #50
(„Häkchen gesetzt, kein Kreis gefüllt"), und zwar auf dem Weg, den AC-13 adressiert
(`reResolveAIIfNeeded()` nach dem Teilen-Handoff).

### Erreichbarkeit (im Code nachvollzogen, nicht konstruiert)

`resolve` bildet den Vorschlags-Pool aus ALLEN Artikeln des Ladens
(`ReceiptResolutionService.swift:96`, Kommentar „Breiterer Kandidaten-Pool NUR für die
Vorschlags-Chips"), die automatische Namensübernahme (Stufe 3) sucht aber nur unter **abgehakten**
Artikeln und braucht Ähnlichkeit ≥ 0,6. Ein Artikel, der **unabgehakt** auf der Liste steht, landet
deshalb in `suggestions`, löst den Namen aber nicht auf → die Zeile geht nach `needsAI`, Stufe 5
überschreibt den Namen, und der Wortschatz-Kontext der KI besteht genau aus den Artikelnamen dieses
Ladens (`knownItemNames`) — die KI liefert also bevorzugt exakt den Namen, der schon als Vorschlag
dasteht.

**Alltagsfall:** „Butter" steht unabgehakt auf der Liste, Bonzeile „BTR",
`lcsSimilarity("BTR","Butter") = 0,67` über dem Vorschlags-Floor 0,45
(`ReceiptParserService.swift:1160`), die KI löst zu „Butter" auf.

### Der Selbstwiderspruch der Hauptspec (der eigentliche Grund für AMBIGUOUS)

- **Invariante 6** (Hauptspec Z. 545-554) nennt `mergeAIReresolution` **ausdrücklich** als
  abgedeckten Zuweisungsweg und verspricht „genau eine Option markiert, sofern `line.name` nicht
  leer ist".
- Der letzte Punkt in **„Known Limitations"** (Z. 973-980, „Issue #37/#50, vorbestehende,
  ungeprüfte Randbedingung") beschreibt dasselbe Symptom als bewusst offen und schränkt Invariante 6
  darauf ein, dass `matchedItemID`/`resolvedByAI` „aus einem der bekannten Zuweisungswege" stammen
  — `mergeAIReresolution` IST aber so ein Weg. Die Einschränkung greift für diesen Fall gerade
  nicht.

Die Spec sagt an dieser Stelle beides. Paket 1b entscheidet die Richtung: **Der Code wird
präzisiert, die Zusage bleibt** (Alternative „Spec-Wortlaut einschränken" ist verworfen, siehe
„Alternativen").

## Befund F002 (MEDIUM): ein einzelnes Leerzeichen umgeht den Rückfall

Regel 10 guardet auf `name.isEmpty` (`ReceiptReviewCard.swift:497`), Regel 11 auf
`name.trimmingCharacters(in: .whitespaces).isEmpty` (`ReceiptScannerView.swift:103-107`). Tippt der
Nutzer im Feld „Anderer Name …" ein einzelnes Leerzeichen, ist `isEmpty == false`: der Rückfall
greift nicht, `applyCustomName` schreibt `line.name = " "` und löscht `matchedItemID`/`resolvedByAI`.

Nach außen bleibt die Position angehakt: Kopfzeile und Summe (`ReceiptScannerView.swift:507-509`,
`:224`) und `canSave` (`:260`) zählen weiter über `isIncluded`, `save()` verwirft sie über Regel 11
aber **still**; `Haptics.success()`/`dismiss()` laufen trotzdem. Ist es die einzige Position, wird
gar nichts gespeichert — ohne Rückmeldung. Damit hält der Buchstabe von AC-15 („`line.name` wird nie
leer geschrieben"), nicht aber die Absicht des Rückfalls, den die Spec ausdrücklich der Alternative
„Speichern sperren" vorgezogen hat, um den Nutzer nicht ratlos stehen zu lassen.

---

## Neue Regel 12 — Markierung entscheidet, nicht Namensgleichheit (Paket 1b, F001)

**Einzufügen in der Hauptspec** im Bereich „Nachtrag Issue #50, Paket 1" direkt hinter Regel 11
(nach Z. 501, vor „### `accessibilityIdentifier`-Schema", Z. 503).

Die Markierungs-Regel steht heute doppelt im Code: implizit in `selectionOptions` (Regeln 2 und 5
arbeiten mit **Namensgleichheit**) und explizit in `isSelected(_:)` der View (arbeitet mit
**Name + `matchedItemID` + `resolvedByAI` + `customActive`**). F001 ist genau der Fall, in dem die
beiden auseinanderlaufen. Paket 1b macht die explizite Fassung zur **einzigen Quelle** und führt
die beiden Regeln darauf zurück.

```swift
/// Markierungs-Regel ohne View-State — die einzige Quelle dafür, welche Option zum aktuellen
/// Zustand der Zeile gehört. `isSelected(_:)` ist die View-Sicht darauf und ergänzt nur
/// `customActive` (Issue #50, Paket 1b, Regeln 2/5).
static func isSelectedIgnoringCustom(_ option: ReceiptNameOption,
                                     for line: EditableReceiptLine) -> Bool {
    switch option {
    case .listMatch(let suggestion):
        return !line.resolvedByAI
            && line.matchedItemID == suggestion.itemID
            && line.name.caseInsensitiveCompare(suggestion.name) == .orderedSame
    case .aiSuggestion(let name):
        return line.resolvedByAI
            && line.name.caseInsensitiveCompare(line.aiSuggestedName ?? name) == .orderedSame
    case .currentName(let name):
        return line.name.caseInsensitiveCompare(name) == .orderedSame
    case .custom:
        return false
    }
}
```

Und in der View:

```swift
private func isSelected(_ option: ReceiptNameOption) -> Bool {
    if case .custom = option { return customActive }
    return !customActive && Self.isSelectedIgnoringCustom(option, for: line)
}
```

**Belegte Verhaltensgleichheit zum heutigen `isSelected` (`ReceiptReviewCard.swift:366-380`), alle
vier Options-Arten:**

| Option | heute | nach Paket 1b | gleich? |
|---|---|---|---|
| `.listMatch(s)` | `!customActive && !resolvedByAI && matchedItemID == s.itemID && name ≟ s.name` | `!customActive && (!resolvedByAI && matchedItemID == s.itemID && name ≟ s.name)` | ja — reine Ausklammerung von `!customActive` |
| `.aiSuggestion(n)` | `!customActive && resolvedByAI && name ≟ (aiSuggestedName ?? n)` | `!customActive && (resolvedByAI && name ≟ (aiSuggestedName ?? n))` | ja |
| `.currentName(n)` | `!customActive && name ≟ n` | `!customActive && (name ≟ n)` | ja |
| `.custom` | `customActive` | `customActive` (eigener Zweig VOR der `!customActive`-Klammer) | ja |

(`≟` = `caseInsensitiveCompare(…) == .orderedSame`, auf beiden Seiten dieselbe Vergleichsgrundlage,
keine zusätzliche Normalisierung.) Es ist eine **reine Umformung**: `!customActive && (A && B && C)`
ist `!customActive && A && B && C`. Der `.custom`-Zweig muss vor der Klammer stehen, weil
`isSelectedIgnoringCustom(.custom, …)` bewusst `false` liefert — `customActive` ist View-Zustand und
hat in einer reinen Funktion nichts zu suchen.

**Warum `selectionOptions` die neue Funktion braucht und nicht `isSelected`:** `selectionOptions`
ist eine `static func` ohne View-State. `customActive` ist für die Zusammensetzung der Options-Liste
auch irrelevant: während der Eingabe eines eigenen Namens verhindert der Guard aus Regel 9
(`isSelected(.custom) == true`) jede Neuberechnung.

### Folge 1 — Regel 2 (Dedup) entfällt nur zugunsten einer WÄHLBAREN Markierung

Die `.aiSuggestion`-Zeile entfällt nur dann zugunsten eines namensgleichen `.listMatch`, wenn
dieser `.listMatch` im **aktuellen Zustand der Zeile auch markiert wäre**. Ist er es nicht (F001:
`line.resolvedByAI == true`, `line.matchedItemID == nil`), bleibt die `.aiSuggestion`-Zeile stehen,
trägt die Markierung und ihre KI-Kennzeichnung, und der namensgleiche Listen-Treffer bleibt
zusätzlich sichtbar und antippbar — ein Tap darauf stellt die fehlende Verknüpfung zum Listenartikel
(`matchedItemID`) her, was vorher überhaupt nicht möglich war.

**Platzierung (Teil der Regel, kein Zufall):** Die erhaltene `.aiSuggestion` tritt an die Stelle
unmittelbar **VOR** dem namensgleichen `.listMatch`, statt wie in Regel 1 hinten angehängt zu
werden. Begründung: Regel 3 sortiert auf Namensbasis den ERSTEN namensgleichen Kandidaten nach vorn
— das wäre der `.listMatch`; die markierte KI-Zeile stünde dann an Position 3 und würde bei drei
vorhandenen `.listMatch`-Kandidaten von der Kappung (Regel 4) getroffen. Mit der Platzierung vor dem
Listen-Treffer steht die markierte Zeile an Position 0, die Kappung trifft nur unmarkierte
Kandidaten, und AC-17 gilt ohne Einschränkung.

**Invariante 3 wird dadurch stärker erfüllt, nicht schwächer:** Die KI-Kennzeichnung verschwindet
künftig nur noch dort, wo der KI-Name von einer markierten, namensgleichen Listen-Zeile vertreten
wird — nicht mehr dort, wo ihn niemand vertritt.

**Invariante 5 (max. 3 inhaltliche) bleibt gewahrt:** Regel 4 kappt unverändert auf 3.

**Bewusst in Kauf genommene Nebenwirkung:** In Konstellationen, in denen WEDER der `.listMatch`
NOCH die `.aiSuggestion` markiert ist (z. B. `line.name` = „Milch", `aiSuggestedName` = „Butter",
Vorschlag „Butter" ohne passende `matchedItemID`), bleibt die KI-Zeile jetzt ebenfalls stehen, und
zwei Zeilen tragen denselben Namen. Sie sind an ihrer rechten Quellenangabe unterscheidbar
(„KI-Vorschlag" mit `sparkles` gegen „auf deiner Liste"), und Regel 5 setzt in diesem Fall ohnehin
den geltenden Namen als markierte Zeile an Position 0. Der Preis ist eine Doppelnennung, der Gewinn
ist eine einzige, einfach prüfbare Bedingung („wäre markierbar?") statt einer zweiseitigen — siehe
die verworfene Alternative „engere Dedup-Bedingung".

### Folge 2 — Regel 5 greift auf Markierungsbasis

Die Bedingung lautet künftig „**kein verbliebener Kandidat ist MARKIERT**" statt „kein verbliebener
Kandidat entspricht case-insensitiv `line.name`". Das ist die strikt stärkere Bedingung: Jede
markierte Option trägt zwangsläufig `line.name` (alle drei Markierungs-Zweige verlangen
Namensgleichheit), aber nicht jede namensgleiche Option ist markiert. Regel 5 greift damit
zusätzlich in genau den Fällen, in denen ein namensgleicher Kandidat existiert, aber nicht markiert
werden kann:

1. **F001**, sofern die markierte KI-Zeile trotz der Platzierung aus Folge 1 nicht existiert (z. B.
   weil `aiSuggestedName` nicht gesetzt ist, die Zeile aber `resolvedByAI == true` trägt).
2. Der bisher als „vorbestehende, ungeprüfte Randbedingung" geführte Fall: zwei verschiedene
   Artikel mit exakt gleichem Namen im selben Laden, `suggestion.itemID != line.matchedItemID`.
   Regel 5 fügt dort künftig den geltenden Namen als markierte `.currentName`-Zeile ein. Dass dann
   zwei Zeilen denselben Namen tragen, ist in diesem Fall inhaltlich korrekt — es sind zwei
   verschiedene Artikel.
3. Ein eigener Name, der zufällig einem Vorschlag entspricht (`matchedItemID == nil`) — dieselbe
   Struktur wie 2.

**Regel 3 bleibt auf Namensbasis** (unverändert) und ist damit ausdrücklich nur noch eine
Anzeige-Reihenfolge: Sie entscheidet nicht, welche Zeile markiert ist. Unschädlich, weil die nach
vorn sortierte Zeile immer den geltenden Namen zeigt, und weil die markierte Zeile in jeder hier
belegten Konstellation ohnehin an Position 0 landet — über Regel 3 (markierter Kandidat ist der
erste namensgleiche), über die Platzierung aus Folge 1 (KI-Zeile vor dem namensgleichen
Listen-Treffer) oder über Regel 5 (Einfügen an Position 0). Diese Positions-Aussage hängt daran,
dass `completedItemCandidates` namensgleiche Vorschläge dedupliziert
(`ReceiptParserService.swift:1186-1192`) — sie ist deshalb bewusst **keine** AC, sondern eine
Feststellung.

### Warum das den Widerspruch auflöst

Nach Folge 1 und Folge 2 ist „genau eine Option markiert" keine Aussage über bestimmte
Zuweisungswege mehr, sondern eine **strukturelle Eigenschaft von `selectionOptions`**: Regel 5
greift genau dann, wenn sonst nichts markiert wäre. Invariante 6 kann die Einschränkung auf
„bekannte Zuweisungswege" deshalb fallen lassen, und der Punkt in „Known Limitations", der sie
zurücknahm, ist behoben statt offen. Die verbleibende, kleinere Restlücke (eine externe Änderung,
die `line.name` byte-gleich lässt) ist unten benannt und NICHT in die Invariante hineingeschrieben.

---

## Wörtliche Ersetzungen in der Hauptspec

### (A) Abschnitt „Source" (Z. 30-32) — Identifier ergänzen

Die Identifier-Liste bekommt zusätzlich: `static func isSelectedIgnoringCustom(_:for:)`.

### (B) „Problem und Design-Grundlage": neuer Absatz hinter Z. 69

> **Nachtrag Issue #50, Paket 1b (2026-09-27):** Der Adversary-Prüfdialog zu Paket 1
> (`docs/artifacts/fix-50-import-dialog-design/adversary-dialog.md`, Urteil AMBIGUOUS) fand zwei
> Lücken: F001 (HIGH) — nach `reResolveAIIfNeeded()` mit Stufe-5-Auflösung kann eine Karte OHNE
> markierte Zeile stehen, wenn der KI-Name wörtlich einem eigenen Vorschlag entspricht; F002
> (MEDIUM) — ein Name aus reinen Leerzeichen umgeht den Rückfall aus Regel 10. Der PO hat die
> Behebung beider beauftragt. Paket 1b präzisiert Regel 2 und Regel 5 in `selectionOptions` auf
> Markierungsbasis (neue Regel 12, neue reine Funktion `isSelectedIgnoringCustom`) und den Guard
> in `applyCustomNameOrFallback` auf denselben getrimmten Namenstest, den `isSavable` benutzt.
> Kein Eingriff in `ReceiptResolutionService` oder `ReceiptScannerView`. Details:
> `docs/specs/views/receipt-review-card-nachtrag-1b.md` (bei Widerspruch gilt dort).

### (C) Implementation Details, Abschnitt 2 — Regel 2 (ersetzt Z. 217-218)

> 2. **Dedup case-insensitiv über den Namen, aber nur zugunsten einer WÄHLBAREN Markierung
>    (präzisiert in Paket 1b, siehe Regel 12):** Trägt ein `.listMatch` denselben Namen wie die
>    `.aiSuggestion`, entfällt die `.aiSuggestion` nur dann, wenn dieser `.listMatch` im aktuellen
>    Zustand der Zeile auch MARKIERT wäre (`isSelectedIgnoringCustom(_:for:)`) — dann belegt der
>    Listen-Treffer den Platz und trägt die Markierung, der KI-Name bleibt über ihn wählbar
>    (Invariante 3). Wäre der namensgleiche `.listMatch` NICHT markiert (F001:
>    `line.resolvedByAI == true`, `line.matchedItemID == nil`), bleibt die `.aiSuggestion` stehen
>    und tritt an die Stelle unmittelbar VOR diesem `.listMatch`: sie trägt dort die Markierung und
>    ihre KI-Kennzeichnung, der Listen-Treffer bleibt direkt darunter antippbar (ein Tap stellt die
>    fehlende `matchedItemID`-Verknüpfung her). Die Platzierung ist Teil der Regel — nur so
>    übersteht die markierte KI-Zeile die Kappung aus Regel 4, wenn bereits drei
>    `.listMatch`-Kandidaten vorliegen.

### (D) Implementation Details, Abschnitt 2 — Regel 3 (ersetzt Z. 219-220)

> 3. Das Element, dessen Name case-insensitiv `line.name` entspricht, wird an die erste Stelle
>    sortiert; die übrigen behalten ihre relative Reihenfolge. **Präzisierung Paket 1b:** Diese
>    Sortierung bleibt auf NAMENSBASIS und ist ausdrücklich nur eine Anzeige-Reihenfolge — sie
>    entscheidet nicht, welche Zeile markiert ist (das tut allein Regel 12). Unschädlich, weil jede
>    markierte Option denselben Namen wie `line.name` trägt und die markierte Zeile in jeder
>    belegten Konstellation an Position 0 landet (Regel 12, Folge 2).

### (E) Implementation Details, Abschnitt 2 — Regel 4 (Zusatz zu Z. 221)

> Zusatz (Paket 1b): Die Kappung trifft nur unmarkierte Kandidaten — die markierte Option steht
> durch Regel 2 (Platzierung) bzw. Regel 3 an Position 0.

### (F) Implementation Details, Abschnitt 2 — Regel 5 (ersetzt Z. 222-229)

> 5. **(Issue #37, 2026-09-24; auf Markierungsbasis präzisiert in Paket 1b, siehe Regel 12)** Ist
>    nach Schritt 3/4 **kein** verbliebener Kandidat MARKIERT (`isSelectedIgnoringCustom(_:for:)`
>    liefert für keinen `true`), UND ist `line.name` **nicht leer**: `.currentName(line.name)` wird
>    zusätzlich als markierte Zeile an Position 0 eingefügt. Ist die Kandidatenliste dadurch länger
>    als 3, entfällt der letzte (schwächste, am weitesten hinten stehende) Kandidat, sodass es bei
>    max. 3 inhaltlichen Kandidaten bleibt (Invariante 5, AC-2 unverändert gültig). Ist `line.name`
>    leer, greift diese Regel nicht — weiter mit Regel 6 (heutiges Verhalten bleibt unverändert).
>    Ist bereits ein Kandidat markiert, ändert sich nichts.
>    **Bis Paket 1a lautete die Bedingung „kein verbliebener Kandidat entspricht case-insensitiv
>    `line.name`".** Die Markierungsbasis ist die strikt stärkere Bedingung und deckt zusätzlich die
>    Fälle ab, in denen ein namensgleicher Kandidat existiert, aber nicht markiert werden kann
>    (F001; zwei verschiedene Artikel mit identischem Namen im selben Laden; ein eigener Name, der
>    zufällig einem Vorschlag entspricht). Dass dann zwei Zeilen denselben Namen tragen können, ist
>    gewollt: es sind verschiedene Artikel bzw. verschiedene Quellen, unterscheidbar an der rechten
>    Quellenangabe.

### (G) Nachtrag Paket 1, Regel 9 — Prosa (ersetzt Z. 373-375 und Z. 377-379)

> … Nur eine externe Änderung, der KEINE bestehende Option mehr entspricht, löst die Neuberechnung
> aus; Regel 5 (Abschnitt 2 oben) sorgt dann dafür, dass die Karte wieder genau eine markierte
> Zeile hat — je nach Zustand die KI-Zeile (Regel 2, Paket 1b) oder der geltende Name als
> `.currentName`-Zeile. Zusage 1 ist damit ohne neue Regel in `selectionOptions` erledigt, allein
> durch das Nachführen des `onAppear`-Aufrufers. `isSelected` ist seit Paket 1b nur noch die
> View-Sicht auf `isSelectedIgnoringCustom` (Regel 12) — der Guard vergleicht damit dieselbe
> Bedingung, die `selectionOptions` beim Zusammensetzen der Liste benutzt, statt einer zweiten,
> namensbasierten.
>
> **Reichweite von Zusage 2 („immer genau eine Option markiert"):** Gilt für jede Zeile mit
> nicht-leerem `line.name` — seit Paket 1b strukturell, ohne Einschränkung auf bestimmte
> Zuweisungswege (Invariante 6 und Regel 12). Für leeren `line.name` und für die eine benannte
> Restlücke siehe „Known Limitations".

### (H) Nachtrag Paket 1, Regel 10 — Code (ersetzt Z. 420-437)

```swift
static func applyCustomNameOrFallback(
    _ line: inout EditableReceiptLine,
    name: String,
    previousSelection: (name: String, matchedItemID: UUID?, resolvedByAI: Bool)
) {
    // Paket 1b (F002): derselbe getrimmte Leer-Begriff wie in `EditableReceiptLine.isSavable` —
    // ein Feld mit reinen Leerzeichen ist für den Nutzer leer und muss es auch hier sein.
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
        let fallback = previousSelection.name.trimmingCharacters(in: .whitespaces).isEmpty
            ? (name: line.originalName, matchedItemID: nil, resolvedByAI: false)
            : previousSelection
        line.name = fallback.name
        line.matchedItemID = fallback.matchedItemID
        line.resolvedByAI = fallback.resolvedByAI
        return
    }
    applyCustomName(&line, name: name)
}
```

### (I) Nachtrag Paket 1, Regel 10 — Prosa (ersetzt die Aufzählungspunkte Z. 399-403 und Z. 404-407 sowie den Verteidigungs-Rückfall Z. 408-414)

> - **Wann greift der Rückfall:** bei JEDEM leeren Zwischenstand, sofort — nicht erst beim
>   Verlassen des Feldes. „Leer" heißt seit Paket 1b **nach `trimmingCharacters(in: .whitespaces)`
>   leer**, also auch ein Feld aus reinen Leerzeichen (F002). Regel 10 und Regel 11 benutzen damit
>   denselben Leer-Begriff; vorher guardete Regel 10 auf `isEmpty` und Regel 11 getrimmt, sodass
>   ein einzelnes Leerzeichen zwischen beiden durchfiel. Konsistent mit dem bestehenden Muster
>   dieser Karte, dass jeder Tastendruck sofort wirkt; ein Verlassen-des-Feldes-Hook existiert hier
>   nicht.
> - **Was NICHT zurückgesetzt wird:** das sichtbare Textfeld (`customName`) bleibt unangetastet —
>   leer bzw. mit den eingetippten Leerzeichen. Nur `line.name`/`matchedItemID`/`resolvedByAI`
>   fallen zurück. Würde auch `customName` befüllt, könnte der Nutzer ab einem leeren Feld nie
>   mehr einen neuen Namen eintippen, ohne dass das Feld sich unter dem Finger sofort wieder mit
>   dem alten Namen füllt.
> - **Es gibt keine vorher gewählte Option, wenn …:** In der Praxis nicht erreichbar — `.custom`
>   wird ausschließlich durch Tippen auf eine bestehende, bereits benannte Auswahlzeile betreten,
>   und ein zuvor über diese Regel zurückgefallener Zustand ist selbst wieder nicht-leer. Als reine
>   Verteidigungsmaßnahme: Ist der festgehaltene Name **getrimmt** leer, fällt
>   `applyCustomNameOrFallback` auf `line.originalName` zurück (`matchedItemID = nil`,
>   `resolvedByAI = false`) — der Bontext ist nie leer, sobald eine Karte überhaupt existiert. Der
>   getrimmte Test gilt seit Paket 1b auch hier, damit ein festgehaltenes Leerzeichen nicht als
>   gültiger Rückfall durchgeht.
>
> **Wirkung von Paket 1b auf die Datenlage:** Ein Name aus reinen Leerzeichen entsteht damit
> nirgends mehr — weder in `line.name` noch in Kopfzeile, Summe oder `canSave`. Regel 11 wird
> dadurch von einer **erreichbaren Bedingung** zur **Verteidigung in der Tiefe**.

### (J) Nachtrag Paket 1, Regel 11 — Zusatzabsatz (hinter Z. 492 einfügen)

> **Stand seit Paket 1b (2026-09-27):** Regel 11 ist reine Verteidigung in der Tiefe. Der einzige
> bekannte Weg zu einem leeren oder nur aus Leerzeichen bestehenden `line.name` — das Feld „Anderer
> Name …" — ist seit dem getrimmten Guard aus Regel 10 geschlossen (F002). Der Filter bleibt
> trotzdem: `@State customActive` fällt beim Zellen-Recycling zurück, und eine künftige, andere
> Quelle für einen leeren Namen (Änderung an `ReceiptResolutionService`/`ReceiptParserService`)
> würde den Datenschaden sonst kommentarlos zurückbringen. Der zugehörige Test
> (`testIsSavableRejectsLineWithEmptyName`) bleibt unverändert gültig und wird damit zum
> Regressionswächter statt zum Nachweis einer erreichbaren Bedingung.

### (K) Invariante 3 (ersetzt Z. 533-536)

> 3. **Die Art.-50-Kennzeichnung („KI-Vorschlag", `sparkles`) bleibt immer an der Stelle sichtbar,
>    an der der KI-Name tatsächlich zur Auswahl steht** — verschwindet nie, auch nicht nach
>    Dedup-Regel 2. Seit Paket 1b strenger: Die separate KI-Zeile entfällt nur dann, wenn ein
>    namensgleicher Listen-Treffer sie vertreten kann, weil dieser im aktuellen Zustand der Zeile
>    auch MARKIERT wäre; andernfalls bleibt die KI-Zeile stehen, trägt die Markierung und ihre
>    Kennzeichnung (Regel 12, Folge 1).

### (L) Invariante 5 (Zusatz zu Z. 539-544)

> Zusatz Paket 1b: Auch Paket 1b fügt keinen neuen Options-FALL hinzu (`ReceiptNameOption` bleibt
> vierteilig) und kappt unverändert auf 3 inhaltliche Optionen. Es kann allerdings in einer bisher
> nicht auftretenden Konstellation eine Zeile ANZEIGEN, die Regel 2 vorher verwarf (die erhaltene
> KI-Zeile) — in dieser Konstellation verschiebt sich die `option.<k>`-Belegung. Kein bestehender
> Seed trifft sie: `-seedReceiptReviewForUITests` hat für die KI-Zeile (Index 0)
> `suggestions: []` (`SmartCartApp.swift:267-270`), die Zeile mit drei Vorschlägen (Index 2) hat
> `resolvedByAI == false` und keinen `aiSuggestedName` (`:276-283`); dasselbe gilt für den zweiten
> Seed. Die vier Options-Index-Tests bleiben damit gültig.

### (M) Invariante 6 (ersetzt Z. 545-554 vollständig)

> 6. **(Issue #50, Paket 1/1b) Genau eine Option ist markiert, sofern `line.name` nicht leer ist.**
>    Seit Paket 1b strukturell garantiert und NICHT mehr auf bestimmte Zuweisungswege beschränkt:
>    - **(a) Bei jeder Berechnung von `selectionOptions`** ist am Ende genau eine Option markiert.
>      „Mindestens eine", weil Regel 5 genau dann eine markierte `.currentName`-Zeile einfügt, wenn
>      kein verbliebener Kandidat markiert ist (Regel 12, Folge 2), und weil Regel 4/5 nie eine
>      markierte Option entfernen. „Höchstens eine", weil sich die Markierungs-Zweige gegenseitig
>      ausschließen: `.listMatch` verlangt `!resolvedByAI`, `.aiSuggestion` verlangt `resolvedByAI`;
>      zwei namensgleiche `.listMatch` entstehen nicht (`ReceiptParserService.swift:1186-1192`);
>      `.currentName` wird nur eingefügt, wenn nichts markiert ist.
>    - **(b) Nach jedem Nutzer-Tap** ist die angetippte Option markiert (Gegenspiel
>      `applySelection`/`isSelected`, im Prüfdialog für alle vier Options-Arten belegt).
>    - **(c) Nach jeder Änderung von `line.name` von außen** ist entweder weiterhin eine Option
>      markiert, oder Regel 9 rechnet neu und (a) greift.
>
>    **Nicht abgedeckt, bewusst als Known Limitation geführt statt die Invariante zu überdehnen:**
>    eine externe Änderung, die `matchedItemID`/`resolvedByAI` ändert, `line.name` aber
>    byte-gleich lässt — Regel 9 hängt am Namen und führt dann nicht nach. Ebenfalls unverändert:
>    Ist `line.name` leer, ist keine Option automatisch markiert (Regel 6, seit Issue #37
>    unverändert); Regel 10 schließt den einzigen produktiv erreichbaren Weg dorthin.

### (N) Acceptance Criteria — AC-4 (ersetzt Z. 739-744)

> - **AC-4:** Der beste Treffer / aktuelle Zustand der Zeile ist vorausgewählt. Ist **keine** der
>   bis zu 3 angezeigten Kandidaten-Zeilen zum aktuellen Zustand der Position markierbar (Regel 12)
>   UND ist `line.name` nicht leer, wird der geltende Name zusätzlich als eigene Zeile angeboten und
>   ist markiert — dafür entfällt der schwächste (am weitesten hinten stehende) der bisherigen
>   Kandidaten (Issue #37, Regel 5; auf Markierungsbasis präzisiert in Paket 1b). Ist `line.name`
>   leer, bleibt das bisherige Verhalten unverändert.

### (O) Acceptance Criteria — AC-14 (ersetzt Z. 766-769)

> - **AC-14 (Issue #50, Zusage 2; in Paket 1b neu gefasst):** Jede Zeile mit nicht-leerem
>   `line.name` hat genau eine markierte Auswahlzeile — „genau ein gefüllter Auswahlkreis, nie null
>   und nie zwei". Ohne Einschränkung auf bestimmte Zuweisungswege, weil Regel 5 auf
>   Markierungsbasis genau dann greift, wenn sonst keine Option markiert wäre (Regel 12). Zwei
>   benannte Ausnahmen, beide in „Known Limitations": (a) während der Eingabe eines eigenen Namens
>   trägt keine Zeile den sichtbaren Kreis bzw. den `.isSelected`-Trait (F004, vorbestehend), (b)
>   eine externe Änderung, die nur `matchedItemID`/`resolvedByAI` ändert und `line.name`
>   byte-gleich lässt, löst das Nachführen aus Regel 9 nicht aus. Siehe Invariante 6.

### (P) Acceptance Criteria — AC-15 (ersetzt Z. 770-773)

> - **AC-15 (Issue #50, Zusage 3):** Leert der Nutzer das vorbelegte Feld „Anderer Name …"
>   vollständig **oder reduziert es auf reine Leerzeichen** (Paket 1b, F002), fällt die Karte auf
>   die Auswahl zurück, die unmittelbar zuvor galt (Name, `matchedItemID` UND `resolvedByAI`
>   gemeinsam) — `line.name` trägt danach nie einen leeren oder nur aus Leerzeichen bestehenden
>   Namen. Das sichtbare Textfeld selbst bleibt unangetastet, der Nutzer kann sofort weitertippen.

### (Q) Acceptance Criteria — neu, hinter AC-16 (hinter Z. 777)

> - **AC-17 (Issue #50, Paket 1b, F001):** Löst die Namensauflösung eine Position auf einen Namen
>   auf, der wörtlich (case-insensitiv) einem ihrer eigenen `suggestions` entspricht und dabei
>   `resolvedByAI = true` mit `matchedItemID = nil` setzt, ist nach der Neuberechnung aus Regel 9
>   GENAU EINE Zeile markiert: die KI-Zeile, mit ihrer KI-Kennzeichnung („KI-Vorschlag",
>   `sparkles`). Der namensgleiche Listen-Treffer bleibt zusätzlich sichtbar und antippbar, sodass
>   ein Tap die fehlende `matchedItemID`-Verknüpfung zum Listenartikel herstellt. Gilt auch bei
>   bereits drei `.listMatch`-Kandidaten (die markierte KI-Zeile steht vor der Kappung).
> - **AC-18 (Issue #50, Paket 1b, F002):** Ein Name aus reinen Leerzeichen löst denselben Rückfall
>   aus wie ein vollständig geleertes Feld. Es entsteht keine angehakte Position, die in Kopfzeile
>   und Summe mitzählt, beim Speichern aber still verworfen wird; Regel 11 bleibt als Verteidigung
>   in der Tiefe unverändert bestehen.

### (R) „Out of Scope" — Zusatz hinter Z. 120

> **Paket 1b:** fügt ebenfalls keinen neuen Options-FALL und keine neue Options-ART hinzu; die
> erhaltene KI-Zeile (Regel 2) ist eine bereits existierende Options-Art, die vorher verworfen
> wurde. Änderungen an `ReceiptResolutionService`, `ReceiptScannerView`, `SmartCartApp` (Seeds) und
> `project.pbxproj` sind ausdrücklich NICHT Teil von Paket 1b.

---

## Scope-Erweiterung (Issue #50, Paket 1b — 2026-09-27)

| File | Change Type | Description |
|------|-------------|-------------|
| `SmartCart/Views/Prices/ReceiptReviewCard.swift` | MODIFY | Neue reine Funktion `isSelectedIgnoringCustom(_:for:)` (Regel 12); `isSelected(_:)` der View auf sie zurückgeführt (reine Umformung, kein Verhaltensunterschied); Regel 2 in `selectionOptions` auf Markierungsbasis inkl. Platzierung der erhaltenen KI-Zeile vor dem namensgleichen `.listMatch`; Regel 5 auf Markierungsbasis; in `applyCustomNameOrFallback` beide Leer-Tests getrimmt (Eingangs-Guard und `previousSelection.name`). Keine andere Funktion, kein anderer View-Zustand. |
| `RestockTests/ReceiptReviewCardTests.swift` | MODIFY | Neun neue/umbenannte Unit-Tests (siehe Test Plan). Darunter die **Umbenennung und Neufassung** von `testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName` — dessen Fixture IST der F001-Zustand, seine Erwartung „keine separate KI-Zeile" ist mit Paket 1b falsch. |
| `RestockUITests/ReceiptReviewUITests.swift` | MODIFY | Ein neuer UI-Test für AC-18 (`testWhitespaceOnlyCustomNameKeepsPreviousItemName`), Einstieg über den BESTEHENDEN Seed — kein neuer Seed, keine Änderung an `SmartCartApp.swift`. |

- Files: **3** — innerhalb des Ziels „max. 4-5 Dateien".
- LoC: ≈ **+105 / −18** — deutlich unter dem Standard-Limit von ±250 LoC. Aufschlüsselung:
  `ReceiptReviewCard.swift` ≈ +35/−12 (Hilfsfunktion 14 Zeilen, Regel 2 ≈ 8, Regel 5 ≈ 2, Guard 2,
  Rest Kommentare mit Spec-Verweisen); `ReceiptReviewCardTests.swift` ≈ +55/−6;
  `ReceiptReviewUITests.swift` ≈ +15. Das LoC-Gate zählt Testcode als Produktivcode (Memory
  `loc-gate-zaehlt-testcode-als-produktiv`) — Reihenfolge in `/50-implement`: erst
  `ReceiptReviewCard.swift` committen und bauen, dann die Testdateien.
- Risk Level: **NIEDRIG bis MITTEL.** Niedrig, weil alle Änderungen in reinen, ohne SwiftUI
  testbaren Funktionen einer Datei liegen und `save()`, die Wire-Formate und die Services
  unberührt bleiben. Mittel, weil Regel 2 die Zusammensetzung der Options-Liste in einer bisher
  anders behandelten Konstellation ändert (ein bestehender Unit-Test muss neu gefasst werden) und
  weil `isSelected` — die Grundlage des Guards aus Regel 9 — umgeformt wird.
- **Ausdrücklich NICHT geändert:** `ReceiptResolutionService.swift`, `ReceiptScannerView.swift`
  (auch nicht `isSavable`/`save()`), `SmartCartApp.swift`, `project.pbxproj` (keine neuen Dateien).

### Warum der Wurzelfix im Service bewusst NICHT hier stattfindet

Die naheliegende Alternative zu F001 ist der Fix an der Wurzel: in
`ReceiptResolutionService.resolve` den `matchedItemID`-Nachgriff (`:130-140`) **nach** Stufe 5 mit
dem KI-Namen wiederholen, damit eine KI-Zeile ihre Artikel-Identität bekommt und
`isSelected(.listMatch)`… — verworfen für Paket 1b, aus drei Gründen:

1. Er reicht in zwei weitere Invarianten hinein: `matchedItemID` entscheidet in `save()`, auf
   WELCHEN Artikel der Preis geschrieben wird (`ReceiptScannerView.swift:642-645`, `:709`). Eine
   neue automatische Zuordnung ist eine Änderung am Lernverhalten, nicht an der Anzeige — und
   Invariante 1 („`save()`-Semantik unverändert") sowie AC-12 hängen daran.
2. Er widerspricht der bestehenden, bewussten Trennung „breiter Vorschlags-Pool, engere
   automatische Übernahme" (`ReceiptResolutionService.swift:96`): ein unabgehakter Artikel wird
   heute absichtlich NICHT automatisch zugeordnet.
3. Er behebt die Anzeige-Lücke nicht vollständig: eine Zeile, die die KI auf einen Namen auflöst,
   der zu keinem Artikel passt, bliebe weiterhin ohne markierte Zeile, wenn Regel 5 auf
   Namensbasis bleibt.

**Folge-Issue vorgeschlagen:** „Stufe 5: Artikel-Zuordnung nach der KI-Auflösung nachziehen
(`ReceiptResolutionService`)" — eigene Spec, eigene Abwägung gegen Invariante 1/AC-12, eigener
Test-Nachweis am Lernverhalten. Paket 1b bleibt eine reine Anzeige-/Markierungs-Korrektur.

---

## Test Plan (Issue #50, Paket 1b — TDD RED, wird in `/40-tdd-red` geschrieben)

**Unit — `RestockTests/ReceiptReviewCardTests.swift`:**

- [ ] **Regel 12, `.listMatch`:** GIVEN eine Zeile mit `matchedItemID == s.itemID`,
  `name == s.name`, `resolvedByAI == false` WHEN `isSelectedIgnoringCustom(.listMatch(s), for:)`
  THEN `true`; für jede Einzelabweichung (anderer `itemID`, anderer Name, `resolvedByAI == true`)
  THEN `false`. Test: `testIsSelectedIgnoringCustomMarksListMatchOnlyWithSameItemAndName`.
- [ ] **Regel 12, `.aiSuggestion`:** GIVEN `resolvedByAI == true`, `aiSuggestedName == "Butter"`,
  `name == "butter"` WHEN `isSelectedIgnoringCustom(.aiSuggestion(name: "Egal"), for:)` THEN `true`
  (der gemerkte KI-Name schlägt den Options-Namen, case-insensitiv); mit `resolvedByAI == false`
  THEN `false`. Test: `testIsSelectedIgnoringCustomMarksAiSuggestionOnlyWhenResolvedByAI`.
- [ ] **Regel 12, `.currentName`:** GIVEN `name == "Milch"`, beliebige `matchedItemID`/`resolvedByAI`
  WHEN `isSelectedIgnoringCustom(.currentName(name: "milch"), for:)` THEN `true` — allein über den
  Namen. Test: `testIsSelectedIgnoringCustomMarksCurrentNameByNameAlone`.
- [ ] **Regel 12, `.custom`:** GIVEN eine beliebige Zeile WHEN
  `isSelectedIgnoringCustom(.custom, for:)` THEN immer `false` — `customActive` ist View-Zustand
  und darf in der reinen Funktion nicht auftauchen; die View ergänzt ihn.
  Test: `testIsSelectedIgnoringCustomNeverMarksTheCustomRow`.
- [ ] **Regel 12, genau eine Markierung (Struktur-Nachweis):** GIVEN jede der Fixtures dieser
  Datei mit nicht-leerem `name` WHEN `selectionOptions(for:)` berechnet und über das Ergebnis mit
  `isSelectedIgnoringCustom` gezählt wird THEN ist die Anzahl markierter Optionen genau 1.
  Test: `testEveryNamedFixtureEndsWithExactlyOneMarkedOption`.
- [ ] **Regel 2, Dedup entfällt bei nicht markierbarem Listen-Treffer (F001):** GIVEN
  `resolvedByAI == true`, `matchedItemID == nil`, `name == aiSuggestedName == "Vollmilch"`,
  `suggestions[0].name == "vollmilch"` WHEN `selectionOptions(for:)` THEN existiert die
  `.aiSuggestion`-Zeile weiterhin, sie ist die einzige markierte Option, und der namensgleiche
  `.listMatch` steht direkt dahinter.
  Test: `testAiSuggestionSurvivesDedupWhenTheNameEqualListMatchIsNotSelectable` —
  **ersetzt/benennt** `testAiSuggestionIsDroppedWhenAListMatchCarriesTheSameName` um, dessen
  Fixture genau dieser Zustand ist und dessen alte Erwartung („keine separate KI-Zeile") mit
  Paket 1b falsch wird.
- [ ] **Regel 2, Dedup greift weiterhin:** GIVEN `resolvedByAI == false`,
  `matchedItemID == suggestions[0].itemID`, `name == suggestions[0].name == aiSuggestedName` WHEN
  `selectionOptions(for:)` THEN existiert KEINE `.aiSuggestion`-Zeile, der `.listMatch` trägt die
  Markierung, und der Name steht nur einmal zur Auswahl (Invariante 3 unverändert).
  Test: `testAiSuggestionIsDroppedWhenTheNameEqualListMatchIsSelected`.
- [ ] **Regel 2, Platzierung übersteht die Kappung:** GIVEN den F001-Zustand MIT drei
  `.listMatch`-Kandidaten, von denen der erste namensgleich zum KI-Namen ist WHEN
  `selectionOptions(for:)` THEN ist `options[0]` die `.aiSuggestion` (markiert), `options.count == 4`
  (3 inhaltliche + `.custom`, Invariante 5), und der namensgleiche `.listMatch` ist weiterhin
  enthalten. Test: `testRetainedAiSuggestionStandsFirstAndSurvivesTheCapWithThreeListMatches`.
- [ ] **Regel 5 auf Markierungsbasis, itemID-Mismatch:** GIVEN `name == "Butter"`,
  `matchedItemID == <fremde id>`, kein `aiSuggestedName`, `suggestions[0].name == "Butter"` mit
  ANDERER `itemID` WHEN `selectionOptions(for:)` THEN ist `options[0]` `.currentName("Butter")` und
  markiert; der namensgleiche `.listMatch` bleibt zusätzlich in der Liste. Deckt die bisher als
  „vorbestehende, ungeprüfte Randbedingung" geführte Lücke ab.
  Test: `testCurrentNameIsInsertedWhenTheNameEqualListMatchCarriesADifferentItemID`.
- [ ] **Regel 5, Regression Namensbasis:** GIVEN `name == "vollmilch"`,
  `matchedItemID == vollmilch.itemID`, `suggestions` enthält „Vollmilch" WHEN
  `selectionOptions(for:)` THEN wird KEINE `.currentName`-Zeile eingefügt (der markierte Treffer
  steht vorn) — beweist, dass die Markierungsbasis die bisherigen Fälle nicht aufbläht.
  Test: `testNoCurrentNameRowWhenTheNameEqualListMatchIsSelected`.
- [ ] **Regel 10 getrimmt (F002):** GIVEN `previousSelection = ("Vollmilch", <id>, false)` WHEN
  `applyCustomNameOrFallback(&line, name: "   ", previousSelection:)` THEN gilt
  `line.name == "Vollmilch"`, `matchedItemID == <id>`, `resolvedByAI == false` — derselbe Rückfall
  wie bei `""`. Test: `testApplyCustomNameOrFallbackRestoresPreviousSelectionOnWhitespaceOnlyName`.
- [ ] **Regel 10 getrimmt, Verteidigungs-Rückfall:** GIVEN `previousSelection = ("  ", nil, false)`
  und `line.originalName == "BTR"` WHEN mit `" "` aufgerufen wird THEN gilt `line.name == "BTR"`,
  `matchedItemID == nil`, `resolvedByAI == false` — ein festgehaltenes Leerzeichen gilt nicht als
  gültiger Rückfall.
  Test: `testApplyCustomNameOrFallbackFallsBackToOriginalNameWhenPreviousSelectionIsWhitespaceOnly`.

**UI — `RestockUITests/ReceiptReviewUITests.swift`:**

- [ ] **AC-18:** GIVEN die KI-Zeile des bestehenden Seeds (`receiptReview.line.0`, Name „Frische
  Vollmilch 3,5 %") WHEN „Anderer Name …" angetippt, das Feld vollständig geleert und dann ein
  einzelnes Leerzeichen eingegeben wird THEN zeigt `receiptReview.line.0.checkbox` weiterhin
  „Position übernehmen: Frische Vollmilch 3,5 %".
  Test: `testWhitespaceOnlyCustomNameKeepsPreviousItemName`.

**Bestehende Tests, unverändert (bestätigt für Paket 1b):**
`testAiLineWithTwoSuggestionsOffersFourOptionsWithAiFirst` (kein namensgleicher Listen-Treffer,
Regel-2-Zweig wird nicht betreten), `testPreselectedListMatchIsSortedFirstRegardlessOfCase`
(markierter Treffer, Regel 5 greift nicht), `testFiveSuggestionsAreCappedToThreeListMatches` und
`testCurrentNameIsOfferedAndPreselectedWhenNoCandidateMatches` (nichts markiert — Regel 5 greift
wie bisher), `testEmptyCurrentNameDoesNotAddExtraOptionWhenNoCandidateMatches` (leerer Name, Regel 5
greift nicht), `testLineWithoutSuggestionsAndWithoutAiKeepsCurrentName`, alle
`applySelection`/`applyCustomName`-Tests, die drei Regel-10-Tests aus Paket 1, die zwei
`isSavable`-Tests, sowie die vier Options-Index-UI-Tests (kein Seed trifft den neuen Regel-2-Zweig,
siehe Ersetzung (L)).

**Grenzen des Nachweises, ausdrücklich benannt:**

1. **`isSelected(_:)` ist `private` in der View und bleibt es.** Die Verhaltensgleichheit der
   Umformung ist deshalb nicht direkt unit-testbar; sie ist in Regel 12 Zeile für Zeile belegt und
   wird indirekt durch die bestehenden UI-Tests gesichert
   (`testTappingListMatchSelectsThatOption`, `testCustomNameOptionOpensFocusedTextField`,
   `testTypingCustomNameIsAppliedWithEveryKeystroke`,
   `testUnresolvedLineEndsWithExactlyOneSelectedOptionAfterAiReresolution`). Eine
   `internal`-Öffnung nur für den Test wäre die Alternative — verworfen, weil sie View-Zustand in
   die Testschnittstelle zieht, statt die reine Funktion zu prüfen.
2. **F001 bekommt keinen UI-Nachweis.** Stufe 5 braucht Apple Intelligence, das im Simulator nicht
   verfügbar ist; der vorhandene Seed erreicht nur den Wörterbuch-Zweig (`resolvedByAI == false`).
   Der Nachweis läuft deshalb auf Funktionsebene (`selectionOptions` + `isSelectedIgnoringCustom`
   gegen eine Fixture mit `resolvedByAI == true`, `matchedItemID == nil`). Ein UI-Nachweis würde
   einen dritten Seed in `SmartCartApp.swift` brauchen — außerhalb des Scopes von Paket 1b, als
   Folge-Issue vorgemerkt.

---

## Alternativen (verworfen)

- **Spec-Wortlaut präzisieren statt Code ändern** (Adversary-Remediation (c) zu F001): AC-14 und
  Invariante 6 ausdrücklich auf `resolvedByAI == false` einschränken und den KI-Dedup-Fall
  namentlich in die „Known Limitations" aufnehmen. Kostet keine Zeile Code und wäre in einer Stunde
  erledigt. **Verworfen durch PO-Entscheidung 2026-09-27:** Der gemeldete Fehler („keine Option
  markiert", Punkt 4 aus Issue #50) bliebe für einen Alltagsfall sichtbar — ein unabgehakter
  Artikel auf der Liste plus eine abgekürzte Bonzeile ist kein Randfall, sondern der Normalfall
  eines noch nicht eingekauften Wochenbedarfs. Die Spec würde damit den Fehler dokumentieren,
  statt ihn zu beheben.
- **`isSelected(.listMatch)` um den Dedup-Fall erweitern** (Adversary-Remediation (a)): markiert,
  wenn `line.resolvedByAI && line.name ≟ suggestion.name && line.aiSuggestedName ≟ suggestion.name`.
  Verworfen: Eine Listen-Zeile („auf deiner Liste") würde dann eine Markierung tragen, die
  inhaltlich dem KI-Namen gehört — die KI-Kennzeichnung verschwände genau dort, wo sie den Zustand
  erklärt (Invariante 3), und der Nutzer hielte die Zeile für eine bestehende Artikel-Verknüpfung,
  die `matchedItemID == nil` gerade nicht ist. Zudem verteilt es die Markierungs-Regel weiter auf
  Sonderfälle, statt sie an einer Stelle zu bündeln.
- **Wurzelfix in `ReceiptResolutionService`** (`matchedItemID` nach Stufe 5 nachziehen): eigener
  Abschnitt oben unter „Scope-Erweiterung", mit drei Gründen und als Folge-Issue vorgeschlagen.
- **Engere Dedup-Bedingung in Regel 2** (KI-Zeile nur erhalten, wenn SIE selbst markiert ist,
  statt: wenn der Listen-Treffer es nicht ist): vermeidet die Doppelnennung in der Konstellation
  „weder noch markiert". Verworfen — zwei Bedingungen an derselben Stelle sind schwerer zu prüfen
  als eine, und die Doppelnennung ist an der Quellenangabe unterscheidbar und wird durch die
  markierte `.currentName`-Zeile aus Regel 5 ohnehin eingeordnet. Bleibt die naheliegende
  Nachschärfung, falls die Doppelnennung im Betrieb auffällt.
- **Kopfzeile/Summe/`canSave` auf `isSavable` umstellen** (Adversary-Alternative zu F002): würde
  eine Position mit leerem Namen sichtbar aus der Auswahl nehmen. Verworfen — größerer Eingriff,
  berührt AC-10/AC-11 und damit zwei bestätigte ACs, und behandelt das Symptom (Zählung) statt der
  Ursache (zwei verschiedene Leer-Begriffe). Der getrimmte Guard ist eine Zeile.
- **Regel 9 zusätzlich an `matchedItemID`/`resolvedByAI` hängen** (`.onChange` auf beide Felder),
  um die Restlücke aus Invariante 6 zu schließen. NICHT Teil von Paket 1b: Der PO hat F001 und F002
  beauftragt, nicht eine dritte Zusage; die Lücke ist unten als Known Limitation benannt und
  braucht einen eigenen, reproduzierten Fall, bevor eine weitere `onChange`-Quelle die Karte
  nachführt (jede zusätzliche Neuberechnung ist ein Kandidat für „springt unter dem Finger").

## Known Limitations (Ergänzungen und Korrekturen zur Hauptspec)

- **BEHOBEN durch Paket 1b — vormals „Issue #37/#50, vorbestehende, ungeprüfte Randbedingung"
  (Hauptspec Z. 973-980):** Der dort beschriebene Fall (ein `.listMatch` trägt denselben Namen wie
  `line.name`, sein `suggestion.itemID` weicht aber von `line.matchedItemID` ab — zwei verschiedene
  Artikel mit gleichem Namen im selben Laden) führte zu einer Karte ohne markierte Zeile. Regel 5
  greift seit Paket 1b auf Markierungsbasis und fügt dort den geltenden Namen als markierte
  `.currentName`-Zeile ein; Nachweis:
  `testCurrentNameIsInsertedWhenTheNameEqualListMatchCarriesADifferentItemID`. Der Absatz bleibt
  als Historie stehen und wird auf „behoben" umgeschrieben, nicht gelöscht — er ist die Herkunft
  der Einschränkung, die Invariante 6 bis Paket 1a trug.
- **Verbleibende Lücke von Invariante 6 (neu benannt, Paket 1b):** Regel 9 führt die eingefrorene
  Liste an `.onChange(of: line.name)` nach. Eine externe Änderung, die `matchedItemID` oder
  `resolvedByAI` ändert, `line.name` aber byte-gleich lässt, löst das Nachführen nicht aus — eine
  vorher markierte `.listMatch`-Zeile kann dadurch ihre Markierung verlieren, ohne dass neu
  gerechnet wird. Konkret erreichbar (konstruiert, nicht beobachtet): ein abgehakter Artikel heißt
  exakt wie der Bontext („BTR"), Stufe 3 übernimmt ihn samt `matchedItemID`, die Heuristik
  `linesNeedingAIReresolution` hält die Zeile wegen `name == originalName` dennoch für unaufgelöst,
  und Stufe 5 liefert denselben Namen zurück (`matchedItemID = nil`, `resolvedByAI = true`).
  Folge-Issue: Regel 9 auch an diese beiden Felder hängen (siehe „Alternativen").
- **F003 (LOW, vorbestehend seit Issue #37, Folge-Issue wird angelegt):** `applySelection` setzt im
  `.currentName`-Zweig NUR `line.name` (`ReceiptReviewCard.swift:470-471`) und lässt eine zuvor
  gesetzte, fremde `matchedItemID` stehen. Wer zuerst einen Listen-Treffer und danach die
  `.currentName`-Zeile antippt, behält dessen Artikel-Identität; `save()` schreibt den Preis dann
  über `matchedItem` auf den falschen Artikel (`ReceiptScannerView.swift:642-645`, `:709`). Von
  Paket 1b nicht berührt — Paket 1b erzeugt `.currentName`-Zeilen allerdings in mehr
  Konstellationen (Regel 5 auf Markierungsbasis), die Exposition steigt also. Folge-Issue:
  `.currentName` entweder wie einen eigenen Namen behandeln (`matchedItemID = nil`,
  `resolvedByAI = false`) oder die Konservierung ausdrücklich spezifizieren.
- **F004 (LOW, vorbestehend, Folge-Issue wird angelegt):** Solange `customActive` gilt, ersetzt
  `optionRow` die `.custom`-Zeile durch das Textfeld; der `.isSelected`-Trait und der gefüllte
  Radiopunkt hängen nur an den Nicht-Custom-Zeilen. Eine Zählung „genau ein gefüllter
  Auswahlkreis" liefert während der Eingabe eines eigenen Namens 0, obwohl die Eingabe inhaltlich
  die geltende Auswahl ist (`isSelected(.custom) == true`). AC-14 nennt diesen Fall seit Paket 1b
  ausdrücklich als Ausnahme. Folge-Issue: Trait und gefüllten Punkt an die aktive Custom-Zeile
  führen.
- **Doppelnennung eines Namens ist seit Paket 1b möglich** (Regel 2 erhält die KI-Zeile, Regel 5
  fügt den geltenden Namen ein): bis zu zwei Zeilen mit demselben Text, unterscheidbar nur an der
  rechten Quellenangabe („KI-Vorschlag" / „auf deiner Liste" / ohne). Bewusst in Kauf genommen —
  eine markierte Zeile ist wichtiger als eine doppelfreie Liste; siehe die verworfene Alternative
  „engere Dedup-Bedingung".
- Die Hauptspec-Punkte zu Mengen-Editor, Vorschlags-Qualität (#29), #28-Abhängigkeit, Scroll-Länge,
  dem Issue-#37-Teilfall „weniger als 3 Kandidaten" und der Zeile, die MIT leerem `line.name` aus
  der Auflösung kommt, bleiben unverändert gültig. Nur zwei Formulierungen darin sind
  nachzuziehen: der Issue-#37-Teilfall spricht von „passt keiner zu `line.name`" — das heißt seit
  Paket 1b „ist keiner markiert"; und der Punkt zum leeren Namen nennt als einzigen produktiven
  Weg „das Feld bis auf null Zeichen leeren" — seit Paket 1b „leeren oder auf reine Leerzeichen
  reduzieren".

## Ergänzungen zu „Definition of Done" der Hauptspec

- **(Issue #50, Paket 1b)** Erkennt die App den Namen einer Position nachträglich selbst und steht
  dieser Name auch schon auf der Liste, ist die Zeile mit diesem Namen angehakt und als Vorschlag
  der App erkennbar — der Listeneintrag bleibt zusätzlich antippbar, um die Position damit zu
  verknüpfen.
- **(Issue #50, Paket 1b)** Ein Feld „Anderer Name …", das nur noch Leerzeichen enthält, verhält
  sich wie ein leeres Feld: die Position behält ihren vorherigen Namen, statt angehakt zu bleiben
  und beim Speichern still zu verschwinden.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — im Projekt existiert kein formales ADR-Verzeichnis (`docs/adr/` fehlt), wie
  in der Hauptspec und ihrer Vorgänger-Spec festgehalten.
- **Rationale:** Paket 1b verschiebt keine Architekturgrenze. Es zieht eine bereits doppelt
  vorhandene Regel (welche Zeile ist markiert?) in eine reine Funktion zusammen und führt zwei
  bestehende Regeln darauf zurück. Kein Datenmodell, kein Wire-Format, kein Service und kein
  Speicherpfad wird berührt; die einzige nennenswerte Entscheidung — den Wurzelfix im Service
  NICHT hier zu machen — ist oben mit drei Gründen begründet und als Folge-Issue vorgeschlagen.

## Changelog

- 2026-09-27: Paket 1b angelegt. Adversary-Urteil AMBIGUOUS zu Paket 1 (F001 HIGH, F002 MEDIUM),
  PO-Auftrag zur Behebung beider. Neue Regel 12 (`isSelectedIgnoringCustom` als einzige
  Markierungs-Quelle), Regel 2 und Regel 5 auf Markierungsbasis, Regel 3 ausdrücklich zur reinen
  Anzeige-Reihenfolge erklärt, Regel 10 auf denselben getrimmten Leer-Begriff wie `isSavable`
  gebracht, Regel 11 zur Verteidigung in der Tiefe erklärt. Invariante 3 verstärkt, Invariante 6
  ohne Einschränkung auf Zuweisungswege neu gefasst (mit einer benannten Restlücke), Invariante 5
  um die Index-Belegung ergänzt. AC-4/AC-14/AC-15 präzisiert, AC-17 und AC-18 neu. Der bisher
  offene Punkt „Issue #37/#50, vorbestehende, ungeprüfte Randbedingung" ist behoben. F003/F004 als
  Folge-Issues vorgemerkt, ebenso der Wurzelfix im `ReceiptResolutionService` und ein UI-Seed für
  den KI-Zweig. Approval offen — keine Freigabe durch diesen Nachtrag.
