import SwiftUI
import VisionKit
import AVFoundation

// MARK: - Scanner Sheet

struct BarcodeScannerSheet: View {
    let onResult: (String, String?) -> Void  // (barcode, productName?)
    @Environment(\.dismiss) private var dismiss
    @State private var isLooking = false
    @State private var scannedCode: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScannerRepresentable { barcode in
                        guard scannedCode == nil else { return }
                        scannedCode = barcode
                        Haptics.success()
                        Task {
                            let name = await ProductLookup.lookup(barcode: barcode)
                            onResult(barcode, name)
                            dismiss()
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Kamera nicht verfügbar",
                        systemImage: "camera.slash",
                        description: Text("Barcode-Scanner wird auf diesem Gerät nicht unterstützt.")
                    )
                }

                if scannedCode != nil {
                    ProgressView("Produkt wird gesucht…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Barcode scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip(prominent: false) }
                        .buttonStyle(.pressable)
}
            }
        }
    }
}

// MARK: - UIKit wrapper

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .barcode(let b) = item, let value = b.payloadStringValue {
                onBarcode(value)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            if let first = items.first, case .barcode(let b) = first, let value = b.payloadStringValue {
                onBarcode(value)
            }
        }
    }
}

// MARK: - Product Lookup

enum ProductLookup {
    static func lookup(barcode: String) async -> String? {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode)?fields=product_name,product_name_de"
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let product = json["product"] as? [String: Any] else { return nil }
        let deName = product["product_name_de"] as? String ?? ""
        let name = product["product_name"] as? String ?? ""
        let result = deName.isEmpty ? name : deName
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : result
    }
}
