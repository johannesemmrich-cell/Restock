import UIKit
import SwiftUI
import SwiftData
import Vision
import UniformTypeIdentifiers

/// Principal-Klasse der Share Extension (siehe `NSExtensionPrincipalClass` in Info.plist) —
/// reine Hülle, die die eigentliche Arbeit an eine SwiftUI-Ansicht delegiert. `extensionContext`
/// wird von UIKit automatisch gesetzt, sobald das System diesen View Controller wegen eines
/// geteilten Bildes instanziiert.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let hosting = UIHostingController(rootView: ShareReceiptView(extensionContext: extensionContext))
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }
}

/// Kompakte Bestätigungs-Ansicht: Spinner während der Erkennung, danach Erfolg/Fehler +
/// "In Restock öffnen". Die eigentliche Korrektur-Oberfläche ist bewusst NICHT hier nachgebaut —
/// das bleibt die bestehende, ausgereifte Review-Ansicht in der Haupt-App (`ReceiptScannerView`),
/// die über den Handoff (`ReceiptShareHandoff`) vorbefüllt geöffnet wird.
struct ShareReceiptView: View {
    let extensionContext: NSExtensionContext?

    private enum LoadState {
        case loading
        case success(storeName: String?, itemCount: Int)
        case noItemsFound
        case error(String)
    }

    @State private var state: LoadState = .loading

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .loading:
                ProgressView()
                Text("Bon wird erkannt …")
                    .foregroundStyle(.secondary)
                // Unklar, ob das System um diesen View Controller herum eigenes Abbrechen-Chrome
                // zeigt (anders als bei SLComposeServiceViewController, das eins geschenkt bekommt
                // — hier nicht verwendet). Sicherheitshalber einen eigenen Button, damit der
                // Teilen-Dialog während der Erkennung nie ohne Ausweg wirkt.
                Button("Abbrechen") { cancel() }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)

            case .success(let storeName, let itemCount):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text(storeName.map { "\(itemCount) Positionen bei \($0) erkannt" }
                     ?? "\(itemCount) Positionen erkannt")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button {
                    openApp()
                } label: {
                    Text("In Restock öffnen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Fertig") { finish() }
                    .buttonStyle(.bordered)

            case .noItemsFound:
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Keine Positionen erkannt")
                    .font(.headline)
                Text("Versuche es mit einem schärferen Bild.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Schließen") { cancel() }
                    .buttonStyle(.bordered)

            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Schließen") { cancel() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .task { await process() }
    }

    // MARK: - Verarbeitung

    private func process() async {
        guard let image = await loadSharedImage() else {
            state = .error("Kein Bild gefunden.")
            return
        }
        guard let cgImage = image.cgImage else {
            state = .error("Bild konnte nicht verarbeitet werden.")
            return
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let lines = await recognizeText(cgImage: cgImage, orientation: orientation)
        let parsed = ReceiptParserService.parse(lines)
        guard !parsed.isEmpty else {
            state = .noItemsFound
            return
        }

        guard let container = SharedModelContainer.make() else {
            state = .error("Kein Zugriff auf die Restock-Daten.")
            return
        }
        let context = container.mainContext
        let activeStores = (try? context.fetch(FetchDescriptor<Store>(predicate: #Predicate { $0.isActive }))) ?? []
        let detectedStore = AssignmentService.detectStore(fromReceiptLines: lines, candidates: activeStores)
            ?? activeStores.first
        let allRecords = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []

        // Ohne irgendeinen konfigurierten Laden (seltener Fall — z. B. ganz frische Installation)
        // ist keine sinnvolle Auflösung gegen Kaufhistorie/abgehakte Artikel möglich; die App
        // selbst braucht ohnehin einen Store, um ReceiptScannerView zu öffnen — dann eben mit den
        // rohen OCR-Namen, unaufgelöst, statt der Extension hier eine Laden-Auswahl nachzubauen.
        let resolvedLines: [ResolvedReceiptLine]
        if let detectedStore {
            resolvedLines = await ReceiptResolutionService.resolve(parsed: parsed, store: detectedStore, allRecords: allRecords)
        } else {
            resolvedLines = parsed.map { line in
                ResolvedReceiptLine(
                    name: line.name, originalName: line.name, price: line.price,
                    quantity: line.quantity, unit: line.unit, suggestions: [], matchedItemID: nil
                )
            }
        }

        let payload = SharedReceiptPayload(
            storeID: detectedStore?.id,
            lines: resolvedLines,
            rawLines: lines,
            detectedTotal: ReceiptParserService.detectedTotal(from: lines)
        )
        ReceiptShareHandoff.store(payload)
        state = .success(storeName: detectedStore?.name, itemCount: resolvedLines.count)
    }

    /// Exakt dieselben Vision-Einstellungen wie `ReceiptScannerView.process()` — dieselbe
    /// Erkennungsqualität, keine abgespeckte Zweitversion.
    private func recognizeText(cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = req.results as? [VNRecognizedTextObservation] ?? []
                let blocks: [(text: String, box: CGRect)] = obs.compactMap { o in
                    guard let candidate = o.topCandidates(1).first else { return nil }
                    return (text: candidate.string, box: o.boundingBox)
                }
                continuation.resume(returning: ReceiptParserService.reconstructLines(blocks))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
            request.usesLanguageCorrection = false
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    private func loadSharedImage() async -> UIImage? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
              })
        else { return nil }

        return await withCheckedContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                // Je nach Quell-App liefert der Item-Provider ein Bild als Datei-URL, als
                // rohes UIImage oder als Data — alle drei Formen defensiv abdecken.
                if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else if let data = item as? Data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Aktionen

    private func openApp() {
        guard let url = URL(string: "restock://receiptscan") else { finish(); return }
        // `open(_:completionHandler:)` ist der dafür vorgesehene Weg für Extensions, die
        // enthaltende App zu öffnen — schließt den Teilen-Dialog UND aktiviert Restock.
        extensionContext?.open(url) { [self] _ in finish() }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        let error = NSError(domain: "de.johannesemmrich.Restock.ShareExtension", code: 1)
        extensionContext?.cancelRequest(withError: error)
    }
}
