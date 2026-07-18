import SwiftUI
import SwiftData
import Vision
import UIKit

// MARK: - Editable line model

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if phase == .review && !parsedLines.filter(\.isIncluded).isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { save() }
                            .fontWeight(.semibold)
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
                .foregroundStyle(Color.brand.opacity(0.5))

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
                    .buttonStyle(.borderedProminent)
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
                    Text("Tippe auf einen Namen um ihn zu korrigieren – z. B. \"MDHSZ\" → \"Mozzarella\".")
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
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    // perform() can throw synchronously before the request's completion handler
                    // ever runs — without this, the continuation would never resume and the
                    // "Bon wird ausgelesen…" spinner would spin forever.
                    continuation.resume(returning: [])
                }
            }
            let parsed = ReceiptParserService.parse(lines)
            await MainActor.run {
                parsedLines = parsed.map { line in
                    // Gelernte Kürzel-Zuordnung anwenden: "Beurrier ext" → "Butter", wenn der
                    // User das bei einem früheren Scan so korrigiert hat.
                    let learnedName = ReceiptAliasService.shared.resolve(line.name)
                    return EditableReceiptLine(
                        name: learnedName ?? line.name,
                        price: line.price,
                        originalName: line.name,
                        quantity: line.quantity,
                        unit: line.unit
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

            // Try to update an existing recent record for this store rather than creating a duplicate.
            let match = allRecords.first { record in
                record.storeName.lowercased() == storeNameLower &&
                record.date >= cutoff &&
                (record.itemName.lowercased().contains(lineLower) ||
                 lineLower.contains(record.itemName.lowercased()))
            }

            // Learn price for this store — overwrites previous learned price for this item.
            // `learnedPrices` must stay per-unit (it seeds `ShoppingItem.estimatedPrice`, which
            // is canonically per-unit), but a receipt line's price is the line TOTAL. Die Menge
            // kommt mengenbewusst bevorzugt vom Bon selbst (Mengenzeile "2 x 1.25€" oder
            // Multipack-Token "6X1.5L" → `line.quantity`), sonst vom abgehakten Artikel
            // (`match.quantityAmount`); Fallback ist 1, dann ist der Preis bereits per-unit.
            let quantity = line.quantity > 1 ? line.quantity : (match?.quantityAmount ?? 1)
            store.learnedPrices[lineLower] = quantity > 0 ? line.price / quantity : line.price

            if let match {
                match.actualPrice = line.price
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
        HStack(spacing: 10) {
            Toggle("", isOn: $line.isIncluded)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    TextField("Artikelname", text: $line.name)
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
