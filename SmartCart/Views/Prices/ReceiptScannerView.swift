import SwiftUI
import SwiftData
import Vision
import UIKit

// MARK: - Editable line model

// `ReceiptSuggestion` lebt in `ReceiptResolutionService.swift` — dort auch von der Share
// Extension genutzt, die dieselbe Namensauflösung braucht.

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
    /// Die von Vision rekonstruierten Rohzeilen VOR dem Parsing — nur für die Dev-Feedback-
    /// Diagnose (siehe `.devFeedback` unten) gehalten, damit ein "das ist komisch"-Feedback aus
    /// dem Review automatisch den tatsächlichen OCR-Rohtext mitschickt, statt dass ein einzelner
    /// falsch erkannter oder komplett fehlender Artikel ohne das Originalfoto nicht mehr
    /// nachvollziehbar ist.
    @State private var debugRawLines: [String] = []
    /// Der auf dem Bon selbst aufgedruckte Gesamtbetrag ("zu zahlen"), unabhängig von den
    /// erkannten Positionen — Vergleichswert für `totalMismatchWarning` unten. `nil`, wenn der
    /// Bon keine "zahlen"-Zeile enthielt (z. B. französisches Format) oder kein Betrag daraus
    /// extrahierbar war — dann bleibt die Warnung schlicht aus, statt etwas zu behaupten.
    @State private var detectedTotal: Double?

    enum Phase { case capture, processing, review }

    init(store: Store) {
        self.store = store
    }

    /// Einstiegspunkt für einen per Share Extension bereits erkannten Bon (siehe
    /// `ReceiptShareHandoff`) — startet direkt in `.review`, ohne Foto-Aufnahme/OCR-Schritt,
    /// mit denselben Feldern befüllt, die ein normaler Scan an diesem Punkt hätte. Gleiches
    /// Init-Muster wie `StoreDetailView.init` (State(initialValue:) für vorbefüllte @State).
    init(store: Store, prefilled: SharedReceiptPayload) {
        self.store = store
        _phase = State(initialValue: .review)
        _parsedLines = State(initialValue: prefilled.lines.map { line in
            EditableReceiptLine(
                name: line.name,
                price: line.price,
                originalName: line.originalName,
                quantity: line.quantity,
                unit: line.unit,
                suggestions: line.suggestions,
                matchedItemID: line.matchedItemID
            )
        })
        _debugRawLines = State(initialValue: prefilled.rawLines)
        _detectedTotal = State(initialValue: prefilled.detectedTotal)
    }

    private var selectedTotal: Double {
        parsedLines.filter(\.isIncluded).reduce(0.0) { $0 + $1.price }
    }

    /// Summe ALLER erkannten Positionen, unabhängig vom An/Aus-Toggle — bewusst nicht
    /// `selectedTotal`, weil ein Nutzer einzelne Positionen absichtlich abwählen kann (z. B. weil
    /// er sie nicht in die Preis-Historie übernehmen will); das wäre keine Erkennungslücke.
    private var parsedTotal: Double {
        parsedLines.reduce(0.0) { $0 + $1.price }
    }

    /// Nicht-nil, wenn die erkannten Positionen nicht zur aufgedruckten Bon-Summe passen (mehr als
    /// 1 Cent Differenz, um harmlose Rundung nicht fälschlich zu melden) — macht eine
    /// Erkennungslücke wie eine komplett von Vision übersehene Position (Name UND Zuordnung fehlen,
    /// nicht reparierbar) wenigstens sichtbar, statt sie in der Summe kommentarlos verschwinden zu
    /// lassen.
    private var totalMismatchWarning: String? {
        guard let detectedTotal, abs(parsedTotal - detectedTotal) > 0.01 else { return nil }
        let diff = detectedTotal - parsedTotal
        let diffText = abs(diff).formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR"))
        return diff > 0
            ? "Erkannte Positionen ergeben \(diffText) weniger als die Bon-Summe — vermutlich wurde eine Position nicht erkannt."
            : "Erkannte Positionen ergeben \(diffText) mehr als die Bon-Summe."
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
        .devFeedback(context: debugRawLines.isEmpty
            ? "Bon scannen — \(store.name)"
            : "Bon scannen — \(store.name)\n\nRohzeilen:\n\(debugRawLines.joined(separator: "\n"))")
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

                if let totalMismatchWarning {
                    Section {
                        Label(totalMismatchWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
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
        // Sofort zurücksetzen, nicht erst nach der OCR — sonst könnte ein Feedback-Tap während
        // dieses Scans (oder ein Scan, der schon am fehlenden cgImage scheitert, siehe Guard
        // unten) noch die Rohzeilen des VORHERIGEN Fotos anzeigen.
        debugRawLines = []
        detectedTotal = nil
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
            await MainActor.run {
                debugRawLines = lines
                detectedTotal = ReceiptParserService.detectedTotal(from: lines)
            }
            let parsed = ReceiptParserService.parse(lines)
            // Wiederverwendet von der Share Extension (geteiltes Bild aus einer anderen App) —
            // siehe ReceiptResolutionService.swift für die mehrstufige Auflösungs-Logik selbst.
            let resolved = await ReceiptResolutionService.resolve(parsed: parsed, store: store, allRecords: allRecords)
            await MainActor.run {
                parsedLines = resolved.map { line in
                    EditableReceiptLine(
                        name: line.name,
                        price: line.price,
                        originalName: line.originalName,
                        quantity: line.quantity,
                        unit: line.unit,
                        suggestions: line.suggestions,
                        matchedItemID: line.matchedItemID
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
            //
            // `matchedItemID` ist oft bewusst nil: eine manuelle Namens-Korrektur im Review löscht
            // sie extra (siehe ReceiptLineRow), damit ein automatischer Match/Chip-Tap nicht
            // fälschlich am alten, überschriebenen Namen hängen bleibt. Der gerade korrigierte
            // Name IST aber die verlässlichste verfügbare Evidenz an dieser Stelle — bevor auf die
            // unscharfe 7-Tage-Historie unten zurückgefallen wird, zusätzlich exakt (nicht nur
            // "contains") gegen ALLE Artikel dieses Stores suchen, nicht nur die letzten 7 Tage.
            // Behebt "Maultaschen ohne Preis": der Artikel stand nach der Korrektur schon korrekt
            // benannt auf der Liste, nur die Rück-Zuordnung fand ihn vorher nicht mehr.
            let matchedItem: ShoppingItem? = {
                if let id = line.matchedItemID, let item = store.items?.first(where: { $0.id == id }) {
                    return item
                }
                // Nur bereits abgehakte Artikel — ein Bon belegt einen tatsächlichen Kauf, ein
                // noch offener Artikel mit gleichem Namen (z. B. schon wieder für den nächsten
                // Einkauf vorgemerkt) wurde nicht gekauft. Ohne dieses Filter könnte `max(by:)`
                // bevorzugt den neueren, aber ungekauften Artikel treffen (späteres addedDate als
                // das completedDate des tatsächlich gekauften) und der Bon-Preis würde auf dem
                // falschen Artikel landen, während der echte Kauf weiterhin ohne Preis bleibt.
                return (store.items ?? [])
                    .filter { $0.isCompleted && $0.name.lowercased() == lineLower }
                    .max(by: { ($0.completedDate ?? $0.addedDate) < ($1.completedDate ?? $1.addedDate) })
            }()
            let ownUnpricedRecord = matchedItem?.purchaseRecords?
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
            store.learnedPriceDates[lineLower] = Date()

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
