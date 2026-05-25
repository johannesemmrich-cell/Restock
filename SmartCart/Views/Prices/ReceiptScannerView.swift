import SwiftUI
import SwiftData
import Vision
import UIKit

// MARK: - Editable line model

struct EditableReceiptLine: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var isIncluded = true
}

// MARK: - Main Scanner View

struct ReceiptScannerView: View {
    let storeName: String

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
            .navigationTitle("Bon scannen — \(storeName)")
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
                Section("Gefunden: \(parsedLines.count) Positionen") {
                    ForEach($parsedLines) { $line in
                        ReceiptLineRow(line: $line)
                    }
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
                    continuation.resume(returning: obs.compactMap { $0.topCandidates(1).first?.string })
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["de-DE", "en-US"]
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            }
            let parsed = ReceiptParserService.parse(lines)
            await MainActor.run {
                parsedLines = parsed.map { EditableReceiptLine(name: $0.name, price: $0.price) }
                phase = .review
            }
        }
    }

    private func save() {
        let included = parsedLines.filter { $0.isIncluded && $0.price > 0 }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)

        for line in included {
            let lineLower = line.name.lowercased()

            // Try to update an existing recent record for this store rather than creating a duplicate.
            let match = allRecords.first { record in
                record.storeName.lowercased() == storeName.lowercased() &&
                record.date >= cutoff &&
                (record.itemName.lowercased().contains(lineLower) ||
                 lineLower.contains(record.itemName.lowercased()))
            }

            if let match {
                match.actualPrice = line.price
            } else {
                modelContext.insert(PurchaseRecord(
                    itemName: line.name,
                    storeName: storeName,
                    quantityAmount: 1,
                    unit: "",
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

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $line.isIncluded)
                .labelsHidden()

            TextField("Artikel", text: $line.name)
                .font(.system(size: 15))
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
