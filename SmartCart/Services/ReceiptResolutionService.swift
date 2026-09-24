import Foundation

/// Ein antippbarer Vorschlag für eine Bon-Zeile, hergeleitet aus den gerade abgehakten Artikeln
/// dieses Stores (siehe `ReceiptParserService.completedItemCandidates`). Trägt `itemID` (nicht
/// nur den Namen) mit, damit zwei gleichnamige abgehakte Artikel unterscheidbar bleiben. `Codable`,
/// da dieser Typ auch über die Prozessgrenze zur Share Extension hinweg transportiert wird (siehe
/// `ReceiptShareHandoff`).
struct ReceiptSuggestion: Identifiable, Codable {
    let id: UUID
    let name: String
    let itemID: UUID

    init(name: String, itemID: UUID) {
        self.id = UUID()
        self.name = name
        self.itemID = itemID
    }
}

/// Das Ergebnis der Namensauflösung für eine einzelne Bon-Zeile — Zwischenform zwischen dem
/// rohen `ReceiptLine` (reines OCR-Parsing) und der UI-Darstellung. `ReceiptScannerView` macht
/// daraus ein `EditableReceiptLine` (die nur die App braucht: `isIncluded`); die Share Extension
/// reicht das Ergebnis direkt als Teil von `SharedReceiptPayload` weiter. Trägt `originalName`
/// (der rohe OCR-Name VOR der Auflösung) mit, obwohl `name` oft schon davon abweicht — `save()`
/// braucht genau diesen rohen Text fürs Kürzel-Lernen (`ReceiptAliasService.learn`), unabhängig
/// davon, ob die Auflösung in der App selbst oder schon in der Share Extension gelaufen ist.
struct ResolvedReceiptLine: Codable {
    var name: String
    var originalName: String
    var price: Double
    var quantity: Double
    var unit: String
    /// Siehe `ReceiptLine.weightBasis` — durchgereicht bis zum Preis-Lernen in
    /// `ReceiptScannerView.save()`. Optional mit Default, damit ein bereits in der Share-Extension-
    /// Handoff-UserDefaults liegender, älterer `SharedReceiptPayload` (ohne dieses Feld) beim
    /// Decodieren nicht fehlschlägt, sondern einfach `nil` liefert.
    var weightBasis: Double? = nil
    var suggestions: [ReceiptSuggestion]
    var matchedItemID: UUID?
    /// Gesetzt, wenn Stufe 5 (Apple Intelligence) diesen Namen vervollständigt hat — steuert die
    /// Art.-50-Kennzeichnung im Review (`ReceiptReviewCard`, KI-Options-Zeile). Default `false`,
    /// damit ein bereits gespeicherter, älterer `SharedReceiptPayload` ohne dieses Feld nicht am
    /// Decodieren scheitert.
    var resolvedByAI: Bool = false
}

/// Löst OCR-Rohnamen von Bon-Zeilen zu echten Artikelnamen auf. Ausgelagert aus
/// `ReceiptScannerView.process()`, damit sowohl der Kamera-/Fotobibliothek-Scan in der Haupt-App
/// ALS AUCH die Share Extension (geteiltes Bild aus einer anderen App, z. B. Lidl+) dieselbe
/// Erkennungsqualität bekommen, statt dass die Extension eine abgespeckte Zweitversion dieser
/// Logik pflegen müsste.
enum ReceiptResolutionService {
    /// Mehrstufig (erste treffende Stufe gewinnt): 1) gelernter Alias (frühere User-Korrektur)
    /// 2) statisches Abkürzungswörterbuch 3) Fuzzy-Match gegen die gerade abgehakten Artikel
    /// dieses Stores (stärkeres Signal als Stufe 4, weil exakt auf diesen Einkauf bezogen)
    /// 4) Fuzzy-Match gegen die Kaufhistorie an diesem Store 5) optional Apple Intelligence
    /// (iOS 26+) 6) unverändert.
    /// Stufen 1-4 laufen bewusst gemeinsam auf dem MainActor: `ReceiptAliasService` ist eine
    /// simple, nicht threadsichere Klasse (kein Lock/Actor) — würde `resolve()` hier parallel
    /// zu einem gleichzeitigen `learn()`-Aufruf aus `save()` (läuft immer auf dem MainActor)
    /// laufen, wäre das ein Race auf demselben Dictionary. Historie-/Store-Zugriff
    /// (PurchaseRecord/ShoppingItem) gehört aus demselben Grund ebenfalls auf den
    /// MainActor. Nur Stufe 5 (Apple Intelligence) ist echt langsam/asynchron und läuft
    /// deshalb separat.
    ///
    /// `allowAIResolution` schaltet ausschließlich Stufe 5 ab (Stufen 1-4 unverändert aktiv).
    /// Die Share Extension übergibt hier `false`: `SystemLanguageModel` lädt ein mehrere
    /// hundert MB großes On-Device-Modell — App Extensions haben ein deutlich engeres
    /// Speicherlimit als die Haupt-App, das Laden des Modells kann den Extension-Prozess
    /// dadurch vom System lautlos beenden (kein catchable Swift-Error, der Prozess verschwindet
    /// einfach) noch bevor `state` je von `.loading` wegkommt. Kein Funktionsverlust dadurch:
    /// die Extension übergibt ohnehin unaufgelöste Rohnamen an die Haupt-App weiter, die beim
    /// nächsten manuellen Öffnen (`HomeView.checkPendingReceiptScan`) ganz normal in
    /// `ReceiptScannerView` landen — dort läuft Stufe 5 mit vollem App-Speicherbudget.
    static func resolve(parsed: [ReceiptLine], store: Store, allRecords: [PurchaseRecord], allowAIResolution: Bool = true) async -> [ResolvedReceiptLine] {
        var (resolvedNames, needsAI, suggestionsByIndex, matchedItemIDs) = await MainActor.run { () -> ([Int: String], [Int], [Int: [ReceiptSuggestion]], [Int: UUID]) in
            var resolvedNames: [Int: String] = [:]
            var needsAI: [Int] = []
            var suggestionsByIndex: [Int: [ReceiptSuggestion]] = [:]
            var matchedItemIDs: [Int: UUID] = [:]
            let storeName = store.name
            let completedItems = store.completedItems
            // Breiterer Kandidaten-Pool NUR für die Vorschlags-Chips (unten, `suggestionsByIndex`)
            // — umfasst auch noch nicht abgehakte Artikel, damit z. B. ein gerade erst
            // hinzugefügter, noch offener "Mozzarella" beim Scannen als Vorschlag auftaucht statt
            // erst nach dem Abhaken. Die automatische Übernahme (`candidates`/`consumedItemIDs`
            // unten) bleibt bewusst auf `completedItems` beschränkt — ein noch offener Artikel
            // automatisch zu matchen wäre ein zu starker Eingriff, ein antippbarer Vorschlag ist
            // dagegen risikolos.
            let suggestionPool = store.items ?? []
            // Verhindert, dass zwei Bon-Zeilen automatisch denselben abgehakten Artikel
            // beanspruchen (z. B. zwei OCR-Kürzel, die beide am ehesten zu "Milch" passen) —
            // fällt stattdessen auf den nächstbesten noch unverbrauchten Kandidaten zurück.
            // Gilt NUR für die automatische Übernahme; die Vorschlags-Chips unten bleiben
            // absichtlich unabhängig davon (siehe Kommentar dort).
            var consumedItemIDs: Set<UUID> = []

            for (index, line) in parsed.enumerated() {
                let candidates = completedItems.isEmpty ? [] :
                    ReceiptParserService.completedItemCandidates(for: line.name, in: completedItems, linePrice: line.price)
                let suggestionCandidates = suggestionPool.isEmpty ? [] :
                    ReceiptParserService.completedItemCandidates(for: line.name, in: suggestionPool, linePrice: line.price, limit: 3)

                if let alias = ReceiptAliasService.shared.resolve(line.name) {
                    resolvedNames[index] = alias
                } else if let expanded = ReceiptParserService.expandAbbreviations(line.name) {
                    resolvedNames[index] = expanded
                } else if let best = candidates.first(where: {
                    !consumedItemIDs.contains($0.item.id) && $0.score >= ReceiptParserService.completedItemAutoApplyThreshold
                }) {
                    resolvedNames[index] = best.item.name
                    consumedItemIDs.insert(best.item.id)
                    matchedItemIDs[index] = best.item.id
                } else if let historical = ReceiptParserService.historyMatch(for: line.name, in: allRecords, storeName: storeName) {
                    resolvedNames[index] = historical
                } else {
                    needsAI.append(index)
                }

                let resolvedName = resolvedNames[index] ?? line.name

                // matchedItemID unabhängig davon setzen, welche Stufe den Namen aufgelöst hat.
                // Der obige if/else-if-Zweig setzt es NUR im completedItemCandidates-Zweig —
                // löst aber z. B. ein gelernter Alias (aus einem FRÜHEREN Scan desselben Bons,
                // durchaus üblich beim wiederholten Testen) oder die 7-Tage-Kaufhistorie den
                // Namen bereits korrekt auf, wird dieser Zweig nie erreicht: der angezeigte
                // Name stimmt dann zwar, aber die Verknüpfung zum KONKRETEN abgehakten Artikel
                // fehlt — und genau die braucht save(), um den Preis auf die Liste
                // zurückzuschreiben. Deshalb hier als Fallback erneut prüfen, diesmal gegen
                // den AUFGELÖSTEN (sauberen) statt den rohen OCR-Namen — bessere Grundlage für
                // einen Treffer als der ursprüngliche, ggf. kryptische Bon-Text.
                if matchedItemIDs[index] == nil {
                    let resolvedCandidates = resolvedName.caseInsensitiveCompare(line.name) == .orderedSame ? candidates :
                        (completedItems.isEmpty ? [] : ReceiptParserService.completedItemCandidates(for: resolvedName, in: completedItems, linePrice: line.price))
                    if let match = resolvedCandidates.first(where: {
                        !consumedItemIDs.contains($0.item.id) && $0.score >= ReceiptParserService.completedItemAutoApplyThreshold
                    }) {
                        matchedItemIDs[index] = match.item.id
                        consumedItemIDs.insert(match.item.id)
                    }
                }

                // Absichtlich NICHT auf den "else"-Fall beschränkt: auch wenn Alias/Wörterbuch
                // die Zeile schon aufgelöst hat, kann ein abgehakter Artikel noch die
                // genauere Alternative sein (z. B. gelernter Alias "Senf" vs. tatsächlich
                // abgehakt "Dijon-Senf Extra Scharf 200g") — per Tap aufwertbar. Kein
                // Ausschluss über Zeilen hinweg (keine `consumedItemIDs`-Filterung hier):
                // sonst könnte die eine Zeile, die den Artikel WIRKLICH braucht, ihn nicht
                // mehr vorgeschlagen bekommen, nur weil eine andere Zeile ihn (ggf. falsch)
                // schon automatisch beansprucht hat.
                suggestionsByIndex[index] = suggestionCandidates
                    .filter { $0.item.name.caseInsensitiveCompare(resolvedName) != .orderedSame }
                    .map { ReceiptSuggestion(name: $0.item.name, itemID: $0.item.id) }
            }
            return (resolvedNames, needsAI, suggestionsByIndex, matchedItemIDs)
        }

        // Indizes, deren Name tatsächlich von Apple Intelligence stammt (nicht nur versucht —
        // `expand` liefert bei Nichtverfügbarkeit/Timeout/leerer Antwort `nil`, dann bleibt der
        // Roh-Text stehen und es ist kein KI-Vorschlag). Steuert die Art.-50-Kennzeichnung unten.
        var aiResolvedIndices: Set<Int> = []
        if allowAIResolution, !needsAI.isEmpty, ReceiptNameAIResolver.isAIAvailable() {
            // Nur einmal pro Scan aufgebaut (nicht pro Zeile) — reiner Empfehlungs-Kontext für den
            // Prompt, siehe `knownItemNames` unten.
            let knownNames = await MainActor.run { knownItemNames(allRecords: allRecords, store: store) }
            await withTaskGroup(of: (Int, String?).self) { group in
                for index in needsAI {
                    let raw = parsed[index].name
                    group.addTask {
                        (index, await ReceiptNameAIResolver.shared.expand(raw, knownNames: knownNames))
                    }
                }
                for await (index, suggestion) in group {
                    if let suggestion {
                        resolvedNames[index] = suggestion
                        aiResolvedIndices.insert(index)
                    }
                }
            }
        }

        return parsed.enumerated().map { index, line in
            ResolvedReceiptLine(
                name: resolvedNames[index] ?? line.name,
                originalName: line.name,
                price: line.price,
                quantity: line.quantity,
                unit: line.unit,
                weightBasis: line.weightBasis,
                suggestions: suggestionsByIndex[index] ?? [],
                matchedItemID: matchedItemIDs[index],
                resolvedByAI: aiResolvedIndices.contains(index)
            )
        }
    }

    /// Baut den Wortschatz-Kontext für Stufe 5 (Apple Intelligence): dieselben zwei Quellen wie
    /// `QuickAddParser.knownProductSuggestions` (Kaufhistorie über ALLE Stores/Zeit, absteigend
    /// nach Datum, plus aktuelle — auch noch nicht gekaufte — Artikelnamen dieses Stores), aber
    /// ohne Präfix-Filterung, weil hier nicht "was passt zu diesem Tippbeginn" gefragt ist,
    /// sondern "was kennt dieser Nutzer überhaupt". Reiner Empfehlungs-Kontext für den Prompt —
    /// nie eine automatische Übernahme wie bei Stufe 3/4 —, deshalb bewusst bei 40 Einträgen
    /// gedeckelt: klein genug fürs Prompt-/Zeitbudget (25s-Timeout), groß genug, um die
    /// gängigsten eigenen Produktnamen abzudecken.
    static func knownItemNames(allRecords: [PurchaseRecord], store: Store, limit: Int = 40) -> [String] {
        let candidateNames = allRecords.sorted(by: { $0.date > $1.date }).map(\.itemName) + (store.items ?? []).map(\.name)
        var seenLower = Set<String>()
        var result: [String] = []
        for name in candidateNames {
            if result.count == limit { break }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            guard !seenLower.contains(lower) else { continue }
            seenLower.insert(lower)
            result.append(trimmed)
        }
        return result
    }
}
