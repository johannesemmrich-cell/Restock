import SwiftUI
import SwiftData
import Vision
import UIKit

// MARK: - Editable line model

/// Ein antippbarer Vorschlag für eine Bon-Zeile, hergeleitet aus den gerade abgehakten Artikeln
/// dieses Stores (siehe `ReceiptParserService.completedItemCandidates`). Trägt `itemID` (nicht
/// nur den Namen) mit, damit zwei gleichnamige abgehakte Artikel unterscheidbar bleiben.
struct ReceiptSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let itemID: UUID
}

struct EditableReceiptLine: Identifiable {
    let id = UUID()
    var name: String
    var price: Double        // Zeilen-GESAMTpreis
    var isIncluded = true
    /// Roher Bon-Text vor Anwendung gelernter Kürzel-Zuordnungen — Schlüssel für
    /// `ReceiptAliasService.learn(...)`, wenn der User den Namen im Review korrigiert.
    var originalName: String = ""
    var quantity: Double = 1 // Stückzahl (Mengenzeile "2 x 1.25€" / Multipack "6X1.5L")
    var unit: String = ""    // Größe aus dem Namen, z. B. "1,5l", "400g"
    /// Antippbare Alternativen aus den gerade abgehakten Artikeln dieses Stores — z. B. wenn die
    /// automatische Auflösung danebenliegt (kryptische Bon-Kürzel wie "MDHSZ" für "Mozzarella"
    /// lassen sich durch keine Text-Ähnlichkeit zuverlässig auflösen). Tippen setzt nur `name`;
    /// `originalName` bleibt unverändert, das Kürzel-Lernen in `save()` funktioniert dadurch
    /// identisch zu einer manuellen Texteingabe.
    var suggestions: [ReceiptSuggestion] = []
    /// Gesetzt, wenn diese Zeile einem konkreten, gerade abgehakten `ShoppingItem` zugeordnet
    /// wurde (automatisch oder per Vorschlags-Chip) — `save()` schreibt den gelernten Preis dann
    /// direkt auf DIESES Item zurück (statt nur `store.learnedPrices` für künftige Artikel zu
    /// lernen), und nutzt für die PurchaseRecord-Zuordnung dessen eigene Historie statt der
    /// unscharfen 7-Tage-Suche. Wird zurückgesetzt, sobald der Name danach frei überschrieben
    /// wird — sonst bliebe ein manuell korrigierter Name fälschlich mit der alten Identität
    /// verknüpft.
    var matchedItemID: UUID? = nil
}

// MARK: - Main Scanner View

struct ReceiptScannerView: View {
    @Bindable var store: Store

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PurchaseRecord.date, order: .reverse) private var allRecords: [PurchaseRecord]

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var parsedLines: [EditableReceiptLine] = []
    @State private var phase: Phase = .capture

    enum Phase { case capture, processing, review }

    private var selectedTotal: Double {
        parsedLines.filter(\.isIncluded).reduce(0.0) { $0 + $1.price }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .capture:    captureView
                case .processing: processingView
                case .review:     reviewView
                }
            }
            .navigationTitle("Bon scannen — \(store.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip() }
                        .buttonStyle(.pressable)
                }
                if phase == .review && !parsedLines.filter(\.isIncluded).isEmpty {
                    ChipToolbarItem(placement: .confirmationAction) {
                        Button { save() } label: { Text("Speichern").toolbarChip(prominent: true) }
                            .buttonStyle(.pressable)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerRepresentable(sourceType: .camera) { image in
                guard let image else { return }
                process(image)
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePickerRepresentable(sourceType: .photoLibrary) { image in
                guard let image else { return }
                process(image)
            }
        }
        .devFeedback(context: "Bon scannen")
    }

    // MARK: - Phase views

    private var captureView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("Kassenbon scannen")
                    .font(.headline)
                Text("Fotografiere deinen Kassenbon oder wähle ein Bild aus der Fotobibliothek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        Haptics.impact(.light)
                        showCamera = true
                    } label: {
                        Label("Foto aufnehmen", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.restockPrimary)
                }

                Button {
                    Haptics.impact(.light)
                    showPhotoLibrary = true
                } label: {
                    Label("Aus Fotos wählen", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Bon wird ausgelesen…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewView: some View {
        List {
            if parsedLines.isEmpty {
                ContentUnavailableView(
                    "Keine Positionen erkannt",
                    systemImage: "doc.text",
                    description: Text("Versuche ein klareres, gut beleuchtetes Foto.")
                )
                .listRowBackground(Color.clear)

                Section {
                    Button {
                        showPhotoLibrary = true
                        phase = .capture
                    } label: {
                        Label("Neues Foto wählen", systemImage: "arrow.uturn.left")
                    }
                }
            } else {
                Section {
                    ForEach($parsedLines) { $line in
                        ReceiptLineRow(line: $line)
                    }
                } header: {
                    Text("Gefunden: \(parsedLines.count) Positionen")
                } footer: {
                    Text("Tippe auf einen Namen um ihn zu korrigieren – z. B. \"MDHSZ\" → \"Mozzarella\" – oder tippe einen Vorschlag an.")
                }

                Section {
                    HStack {
                        Text("Ausgewählt")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(selectedTotal, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button {
                        phase = .capture
                    } label: {
                        Label("Neues Foto", systemImage: "arrow.uturn.left")
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func process(_ image: UIImage) {
        phase = .processing
        Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else {
                await MainActor.run { parsedLines = []; phase = .review }
                return
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let lines: [String] = await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { req, _ in
                    let obs = req.results as? [VNRecognizedTextObservation] ?? []
                    // Vision liefert bei Spaltenlayout (Name links, Preis rechts) getrennte
                    // Blöcke statt fertiger Zeilen — anhand der BoundingBoxen zu physischen
                    // Bon-Zeilen zusammensetzen, sonst findet der Parser keine Name+Preis-Paare.
                    let blocks: [(text: String, box: CGRect)] = obs.compactMap { o in
                        guard let candidate = o.topCandidates(1).first else { return nil }
                        return (text: candidate.string, box: o.boundingBox)
                    }
                    continuation.resume(returning: ReceiptParserService.reconstructLines(blocks))
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
                // Bons bestehen aus Abkürzungen ("SHAK.MOUTARDE", "DBLE CCTRE") — Sprachkorrektur
                // würde sie zu Wörterbuch-Wörtern "verbessern" und damit verfälschen.
                request.usesLanguageCorrection = false
                do {
                    // WICHTIG: orientation muss mitgegeben werden — sonst verwirft Vision die
                    // UIImage.imageOrientation-Metadaten und interpretiert Hochkant-Fotos (der
                    // Sensor liefert die Pixel meist quer, iOS taggt nur die Rotation) als quer
                    // liegenden Text. Ergebnis: "Keine Positionen erkannt" trotz gutem Foto.
                    try VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    ).perform([request])
                } catch {
                    // perform() can throw synchronously before the request's completion handler
                    // ever runs — without this, the continuation would never resume and the
                    // "Bon wird ausgelesen…" spinner would spin forever.
                    continuation.resume(returning: [])
                }
            }
            let parsed = ReceiptParserService.parse(lines)

            // Kürzel → echter Name, mehrstufig (erste treffende Stufe gewinnt):
            // 1) gelernter Alias (frühere User-Korrektur) 2) statisches Abkürzungswörterbuch
            // 3) Fuzzy-Match gegen die gerade abgehakten Artikel dieses Stores (stärkeres Signal
            // als Stufe 4, weil exakt auf diesen Einkauf bezogen) 4) Fuzzy-Match gegen die
            // Kaufhistorie an diesem Store 5) optional Apple Intelligence (iOS 26+) 6) unverändert
            // (heutiges Verhalten).
            // Stufen 1-4 laufen bewusst gemeinsam auf dem MainActor: ReceiptAliasService ist eine
            // simple, nicht threadsichere Klasse (kein Lock/Actor) — würde resolve() hier parallel
            // zu einem gleichzeitigen learn()-Aufruf aus save() (läuft immer auf dem MainActor)
            // laufen, wäre das ein Race auf demselben Dictionary. Historie-/Store-Zugriff
            // (PurchaseRecord/ShoppingItem) gehört aus demselben Grund ebenfalls auf den
            // MainActor. Nur Stufe 5 (Apple Intelligence) ist echt langsam/asynchron und läuft
            // deshalb separat.
            var (resolvedNames, needsAI, suggestionsByIndex, matchedItemIDs) = await MainActor.run { () -> ([Int: String], [Int], [Int: [ReceiptSuggestion]], [Int: UUID]) in
                var resolvedNames: [Int: String] = [:]
                var needsAI: [Int] = []
                var suggestionsByIndex: [Int: [ReceiptSuggestion]] = [:]
                var matchedItemIDs: [Int: UUID] = [:]
                let storeName = store.name
                let completedItems = store.completedItems
                // Verhindert, dass zwei Bon-Zeilen automatisch denselben abgehakten Artikel
                // beanspruchen (z. B. zwei OCR-Kürzel, die beide am ehesten zu "Milch" passen) —
                // fällt stattdessen auf den nächstbesten noch unverbrauchten Kandidaten zurück.
                // Gilt NUR für die automatische Übernahme; die Vorschlags-Chips unten bleiben
                // absichtlich unabhängig davon (siehe Kommentar dort).
                var consumedItemIDs: Set<UUID> = []

                for (index, line) in parsed.enumerated() {
                    let candidates = completedItems.isEmpty ? [] :
                        ReceiptParserService.completedItemCandidates(for: line.name, in: completedItems, linePrice: line.price)

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
                    suggestionsByIndex[index] = candidates
                        .filter { $0.item.name.caseInsensitiveCompare(resolvedName) != .orderedSame }
                        .map { ReceiptSuggestion(name: $0.item.name, itemID: $0.item.id) }
                }
                return (resolvedNames, needsAI, suggestionsByIndex, matchedItemIDs)
            }

            if !needsAI.isEmpty, ReceiptNameAIResolver.isAIAvailable() {
                await withTaskGroup(of: (Int, String?).self) { group in
                    for index in needsAI {
                        let raw = parsed[index].name
                        group.addTask {
                            (index, await ReceiptNameAIResolver.shared.expand(raw))
                        }
                    }
                    for await (index, suggestion) in group {
                        if let suggestion { resolvedNames[index] = suggestion }
                    }
                }
            }

            // Unveränderliche Kopie vor dem letzten MainActor-Hop — sonst warnt Swift zurecht vor
            // dem Zugriff auf ein eingefangenes `var` aus nebenläufig ausführbarem Code.
            let finalNames = resolvedNames
            let finalSuggestions = suggestionsByIndex
            let finalMatchedItemIDs = matchedItemIDs
            await MainActor.run {
                parsedLines = parsed.enumerated().map { index, line in
                    EditableReceiptLine(
                        name: finalNames[index] ?? line.name,
                        price: line.price,
                        originalName: line.name,
                        quantity: line.quantity,
                        unit: line.unit,
                        suggestions: finalSuggestions[index] ?? [],
                        matchedItemID: finalMatchedItemIDs[index]
                    )
                }
                phase = .review
            }
        }
    }

    private func save() {
        let included = parsedLines.filter { $0.isIncluded && $0.price > 0 }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let storeNameLower = store.name.lowercased()

        for line in included {
            let lineLower = line.name.lowercased()

            // Kürzel-Lernen: weicht der finale Name vom rohen Bon-Text ab (User hat die Position
            // umbenannt oder eine früher gelernte Zuordnung bestätigt), Mapping für künftige
            // Scans merken — beim nächsten Bon erscheint das Kürzel direkt als richtiger Artikel.
            if !line.originalName.isEmpty {
                ReceiptAliasService.shared.learn(receiptText: line.originalName, itemName: line.name)
            }

            // Ist diese Zeile einem konkreten, gerade abgehakten Artikel zugeordnet (automatisch
            // oder per Vorschlags-Chip), dessen eigene Historie bevorzugen — präziser als die
            // unscharfe 7-Tage-Suche, weil die Identität schon feststeht statt nur über den Namen
            // erraten zu werden. Kein eigener unbepreister Datensatz vorhanden → laxe, rein auf
            // Substring basierende 7-Tage/Store-Suche über ALLE Datensätze als Fallback.
            let matchedItem = line.matchedItemID.flatMap { id in store.items.first { $0.id == id } }
            let ownUnpricedRecord = matchedItem?.purchaseRecords
                .filter({ $0.actualPrice == nil })
                .max(by: { $0.date < $1.date })
            let looseMatch = allRecords.first { record in
                record.storeName.lowercased() == storeNameLower &&
                record.date >= cutoff &&
                (record.itemName.lowercased().contains(lineLower) ||
                 lineLower.contains(record.itemName.lowercased()))
            }
            // `looseMatch` hat KEINERLEI Namens-Ähnlichkeitsprüfung — reines `contains` kann einen
            // komplett anderen Artikel treffen (z. B. "Milch" matcht einen bestehenden
            // "Kondensmilch"-Datensatz). Für `ownUnpricedRecord` ist die Identität schon über
            // `matchedItemID` verifiziert, aber `looseMatch` wird unten für ZWEI Schreibvorgänge auf
            // einem fremden Datensatz benutzt (Preis UND — neu — Datum), deshalb dieselbe Schwelle
            // wie bei der automatischen Vorschlags-Übernahme verlangen, statt ihn blind zu
            // vertrauen. Kein Treffer über der Schwelle → wie "kein Match" behandeln (unten wird
            // dann ein neuer Datensatz angelegt statt einen fremden zu verfälschen).
            let match: PurchaseRecord? = {
                if let ownUnpricedRecord { return ownUnpricedRecord }
                guard let looseMatch else { return nil }
                let score = ReceiptParserService.lcsSimilarity(line.name, looseMatch.itemName)
                return score >= ReceiptParserService.completedItemAutoApplyThreshold ? looseMatch : nil
            }()

            // Learn price for this store — overwrites previous learned price for this item.
            // `learnedPrices` must stay per-unit (it seeds `ShoppingItem.estimatedPrice`, which
            // is canonically per-unit), but a receipt line's price is the line TOTAL. Die Menge
            // kommt mengenbewusst bevorzugt vom Bon selbst (Mengenzeile "2 x 1.25€" oder
            // Multipack-Token "6X1.5L" → `line.quantity`), sonst vom abgehakten Artikel
            // (`match.quantityAmount`); Fallback ist 1, dann ist der Preis bereits per-unit.
            let quantity = line.quantity > 1 ? line.quantity : (match?.quantityAmount ?? 1)
            let perUnitPrice = quantity > 0 ? line.price / quantity : line.price
            store.learnedPrices[lineLower] = perUnitPrice

            // Direkt auf den bereits gelisteten Artikel zurückschreiben — sonst lernt ein Scan nur
            // für KÜNFTIG neu erstellte Artikel (über `learnedPrices`), während der schon
            // abgehakte Artikel auf der aktuellen Liste weiterhin gar keinen oder einen veralteten
            // geschätzten Preis zeigt, obwohl der Bon ihn gerade korrekt erkannt hat. Bevorzugt
            // `matchedItem` (aus der Kandidaten-Suche mit dem aufgelösten Namen), fällt aber auf
            // `match.item` zurück — `match` ist an dieser Stelle bereits namensgeprüft (entweder
            // über `matchedItemID` oder die LCS-Schwelle oben), das PurchaseRecord kennt über die
            // Kaufhistorie oft denselben, noch existierenden Artikel, auch wenn `matchedItemID`
            // z. B. wegen einer OCR-Verwucherung des Namens nicht griff. Ohne diesen Fallback
            // bekommt der PurchaseRecord (und damit die Ausgaben-Ansicht) einen Preis, während der
            // Artikel auf der Liste selbst weiterhin keinen zeigt — genau das gemeldete
            // Mandeln-Symptom.
            let itemToUpdate = matchedItem ?? match?.item
            if let itemToUpdate {
                itemToUpdate.estimatedPrice = perUnitPrice
                itemToUpdate.estimatedPriceIsAutoDerived = false
            }

            if let match {
                match.actualPrice = line.price
                // Ein Bon-Scan ist die verlässlichste verfügbare Evidenz für das tatsächliche
                // Kaufdatum — verlässlicher als der Zeitpunkt, an dem der Artikel in der App
                // abgehakt wurde (kann beim Planen Tage vorher liegen). Ohne dieses Update behält
                // ein aktualisierter Datensatz sein altes Abhak-Datum, während andere Positionen
                // desselben Bons als neu eingefügte Datensätze das heutige Datum bekommen — ein
                // einzelner Bon würde dann in der tageweisen Ausgaben-Gruppierung (PriceOverviewView
                // .TripKey) auf mehrere "Einkäufe" auseinanderfallen.
                match.date = Date()
            } else {
                modelContext.insert(PurchaseRecord(
                    itemName: line.name,
                    storeName: store.name,
                    quantityAmount: line.quantity,
                    unit: line.unit,
                    actualPrice: line.price
                ))
            }
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Receipt Line Row

private struct ReceiptLineRow: View {
    @Binding var line: EditableReceiptLine

    /// "6 × 0,20 € · 1,5l" — Menge, Stückpreis und Größe aus dem Bon, falls erkannt.
    private var detailText: String? {
        var parts: [String] = []
        if line.quantity > 1 {
            let unitPrice = line.price / line.quantity
            let formatted = unitPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR"))
            parts.append("\(Int(line.quantity)) × \(formatted)")
        }
        if !line.unit.isEmpty { parts.append(line.unit) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Toggle("", isOn: $line.isIncluded)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        // Eigenes Binding statt $line.name direkt: eine manuelle Korrektur hier
                        // löst die Artikel-Identität aus einem automatischen Match/Chip-Tap wieder
                        // — sonst bliebe `matchedItemID` fälschlich mit dem alten, jetzt
                        // überschriebenen Namen verknüpft, und save() würde den gelernten Preis
                        // auf den falschen Artikel zurückschreiben.
                        TextField("Artikelname", text: Binding(
                            get: { line.name },
                            set: { newValue in
                                line.name = newValue
                                line.matchedItemID = nil
                            }
                        ))
                            .font(.system(size: 15))
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    if let detailText {
                        Text(detailText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(line.isIncluded ? 1 : 0.4)

                Spacer()

                HStack(spacing: 2) {
                    Text(Locale.current.currencySymbol ?? "€")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    TextField("0,00", value: $line.price, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 62)
                        .font(.system(size: 14, weight: .medium))
                }
                .opacity(line.isIncluded ? 1 : 0.4)
            }

            // Antippbare Alternativen aus den gerade abgehakten Artikeln dieses Stores — nur
            // sichtbar, wenn es einen plausiblen, noch nicht übernommenen Kandidaten gibt (siehe
            // ReceiptParserService.completedItemCandidates). Gleiche Bausteine wie die
            // Mengen-Vorschlags-Chips in HomeView (RCRadius.tag/Color.surface/.hairline,
            // .buttonStyle(.pressable), Haptics.impact).
            if !line.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(line.suggestions) { suggestion in
                            Button {
                                line.name = suggestion.name
                                line.matchedItemID = suggestion.itemID
                                Haptics.impact(.light)
                            } label: {
                                Text(suggestion.name)
                                    .lineLimit(1)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.tag))
                                    .overlay(RoundedRectangle(cornerRadius: RCRadius.tag).strokeBorder(Color.hairline))
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .opacity(line.isIncluded ? 1 : 0.4)
            }
        }
    }
}

// MARK: - UIImagePickerController wrapper

private struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerRepresentable
        init(_ parent: ImagePickerRepresentable) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            parent.completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.completion(nil)
        }
    }
}
