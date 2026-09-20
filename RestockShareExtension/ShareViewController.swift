import UIKit
import SwiftUI
import SwiftData
import Vision
import PDFKit
import UniformTypeIdentifiers
import UserNotifications

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
        /// `storeConfidentlyDetected` unterscheidet einen echten Treffer aus dem Bon-Text von
        /// einem reinen Besuchsfrequenz-Notnagel — der Erfolgstext unten formuliert das jeweils
        /// explizit aus, statt beide Fälle gleich "erkannt" klingen zu lassen (Nutzerbericht
        /// 20.09.2026: intransparent, wenn die Zuordnung eigentlich nur geraten war).
        case success(storeName: String?, storeConfidentlyDetected: Bool, itemCount: Int)
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

            case .success(let storeName, let storeConfidentlyDetected, let itemCount):
                Image(systemName: storeConfidentlyDetected ? "checkmark.circle.fill" : "questionmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(storeConfidentlyDetected ? .green : .orange)
                Text(successTitle(storeName: storeName, storeConfidentlyDetected: storeConfidentlyDetected, itemCount: itemCount))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if !storeConfidentlyDetected {
                    Text("Laden im Bon nicht sicher erkannt — bitte in Restock prüfen und ggf. korrigieren.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                // iOS erlaubt nur Today-Widgets offiziell, die eigene App per
                // extensionContext?.open(...) zu öffnen — bei Share Extensions schlägt das in
                // der Praxis unzuverlässig fehl (bestätigt: Apple DTS, mehrere Entwickler-Foren-
                // Threads). openApp() unten wird trotzdem als Bonus versucht, aber verlässlich
                // ist nur, dass Restock die Position beim nächsten manuellen Öffnen selbst
                // findet (HomeView.checkPendingReceiptScan, läuft bei jedem App-Start).
                Text("Als Nächstes: Restock öffnen, um die Positionen zu bestätigen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    openApp()
                } label: {
                    Text("Fertig")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

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

    /// @MainActor statt einzelner `MainActor.run`-Wraps (anders als das Schwester-Pattern in
    /// `ReceiptScannerView.process(_:)`): erzwingt, dass nach JEDEM `await` — insbesondere nach
    /// `recognizeText()`, dessen Continuation aus einem Vision-Completion-Handler auf einem
    /// beliebigen Hintergrund-Thread resumed wird — die Ausführung wieder auf den Main Actor
    /// hoppt, bevor `state` mutiert wird. Ohne das lief `state = .success(...)` (und die anderen
    /// Zuweisungen) je nach Timing/Gerät auf einem Hintergrund-Thread weiter — undefiniertes
    /// SwiftUI-Rendering (kein Crash, aber die Erfolgs-Animation blieb bei manchen Nutzern
    /// stillschweigend aus, gemeldet 19.08.2026).
    @MainActor
    private func process() async {
        guard let attachment = await loadSharedAttachment() else {
            state = .error("Kein Bild oder PDF gefunden.")
            return
        }

        let lines: [String]
        switch attachment {
        case .image(let image):
            guard let cgImage = image.cgImage else {
                state = .error("Bild konnte nicht verarbeitet werden.")
                return
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            lines = await recognizeText(cgImage: cgImage, orientation: orientation)
        case .pdfLines(let pdfLines):
            lines = pdfLines
        }

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
        // Echter Treffer aus dem Bon-Text vs. reiner Besuchsfrequenz-Notnagel, wenn die
        // Text-Erkennung nichts über der Schwelle findet — `storeConfidentlyDetected` unten macht
        // diesen Unterschied jetzt bis in die Erfolgsmeldung UND das App-seitige Review sichtbar,
        // statt beide Fälle identisch als "erkannt" zu behandeln (Nutzerbericht 20.09.2026: keine
        // Rückmeldung, wenn die Zuordnung eigentlich nur geraten war, keine Korrekturmöglichkeit).
        let confidentStore = AssignmentService.detectStore(fromReceiptLines: lines, candidates: activeStores)
        let detectedStore = confidentStore ?? activeStores.max(by: { $0.visitsPerWeek < $1.visitsPerWeek })
        let storeConfidentlyDetected = confidentStore != nil
        let allRecords = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []

        // Ohne irgendeinen konfigurierten Laden (seltener Fall — z. B. ganz frische Installation)
        // ist keine sinnvolle Auflösung gegen Kaufhistorie/abgehakte Artikel möglich; die App
        // selbst braucht ohnehin einen Store, um ReceiptScannerView zu öffnen — dann eben mit den
        // rohen OCR-Namen, unaufgelöst, statt der Extension hier eine Laden-Auswahl nachzubauen.
        let resolvedLines: [ResolvedReceiptLine]
        if let detectedStore {
            // allowAIResolution: false — SystemLanguageModel braucht mehr Speicher, als eine Share
            // Extension zuverlässig zugesprochen bekommt (siehe ReceiptResolutionService-Doku);
            // unaufgelöste Namen landen unverändert bei ReceiptScannerView in der Haupt-App.
            resolvedLines = await ReceiptResolutionService.resolve(parsed: parsed, store: detectedStore, allRecords: allRecords, allowAIResolution: false)
        } else {
            resolvedLines = parsed.map { line in
                ResolvedReceiptLine(
                    name: line.name, originalName: line.name, price: line.price,
                    quantity: line.quantity, unit: line.unit, weightBasis: line.weightBasis,
                    suggestions: [], matchedItemID: nil
                )
            }
        }

        let payload = SharedReceiptPayload(
            storeID: detectedStore?.id,
            storeConfidentlyDetected: storeConfidentlyDetected,
            lines: resolvedLines,
            rawLines: lines,
            detectedTotal: ReceiptParserService.detectedTotal(from: lines)
        )
        ReceiptShareHandoff.store(payload)
        await requestNotificationPermissionIfNeeded()
        scheduleOpenReminder(storeName: detectedStore?.name, storeConfidentlyDetected: storeConfidentlyDetected, itemCount: resolvedLines.count)
        state = .success(storeName: detectedStore?.name, storeConfidentlyDetected: storeConfidentlyDetected, itemCount: resolvedLines.count)
    }

    private func successTitle(storeName: String?, storeConfidentlyDetected: Bool, itemCount: Int) -> String {
        guard let storeName else { return "\(itemCount) Positionen erkannt — kein Laden zugeordnet" }
        return storeConfidentlyDetected
            ? "\(itemCount) Positionen bei \(storeName) erkannt"
            : "\(itemCount) Positionen erkannt — vermutlich \(storeName)"
    }

    /// Fragt die Notification-Berechtigung aktiv an, wenn noch nie danach gefragt wurde
    /// (`.notDetermined`) — sonst schlägt `scheduleOpenReminder()`s `add(_:)` unten lautlos fehl,
    /// ohne dass der Nutzer je ein Berechtigungs-Dialog gesehen hätte, und die einzige noch
    /// verbleibende Rückmeldung ist die schon geschlossene Teilen-Ansicht hier (Nutzerbericht
    /// 20.09.2026). Eine bereits erteilte ODER bereits abgelehnte Berechtigung wird nicht erneut
    /// angefragt — iOS würde den System-Dialog bei `.denied` ohnehin nicht mehr zeigen.
    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Extensions dürfen die eigene App nicht öffnen (siehe openApp()), aber Apple erlaubt und
    /// empfiehlt ausdrücklich lokale Benachrichtigungen, um die Aufmerksamkeit des Nutzers zu
    /// bekommen — Antippen einer Mitteilung darf die App öffnen, ein direkter Aufruf aus der
    /// Extension nicht. Bewusst NICHT über den gemeinsamen NotificationService (App-Ziel) —
    /// der hängt an ConsumptionPattern/HabitService, unnötiger Ballast für diese Extension.
    /// Ohne erteilte Berechtigung schlägt `add` einfach lautlos fehl (kein Crash, kein Fehler
    /// sichtbar) — HomeView.checkPendingReceiptScan() bleibt so oder so der verlässliche Weg,
    /// sobald der Nutzer Restock von sich aus öffnet.
    private func scheduleOpenReminder(storeName: String?, storeConfidentlyDetected: Bool, itemCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = storeConfidentlyDetected ? "Bon erkannt" : "Bon erkannt — Laden bitte prüfen"
        switch (storeName, storeConfidentlyDetected) {
        case (let name?, true):
            content.body = "\(itemCount) Positionen bei \(name) — zum Bestätigen antippen."
        case (let name?, false):
            content.body = "\(itemCount) Positionen erkannt, Laden vermutlich \(name) — zum Prüfen antippen."
        case (nil, _):
            content.body = "\(itemCount) Positionen erkannt, kein Laden zugeordnet — zum Prüfen antippen."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "share-receipt-pending", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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

    private enum SharedAttachment {
        case image(UIImage)
        /// Bereits in Zeilen gesplitteter Text, direkt aus dem PDF extrahiert — kein Vision-OCR
        /// nötig, weil ein digitaler eBon (z. B. Rewe) echten Text statt eines Fotos enthält.
        case pdfLines([String])
    }

    /// Bild ODER PDF laden — Lidl Plus teilt einen Bon offenbar als Screenshot/Bild, Rewes
    /// digitaler eBon kommt dagegen als PDF (`NSExtensionActivationRule` in Info.plist erlaubt seit
    /// diesem Fix beides). PDF wird zuerst geprüft, da ein PDF-Attachment i.d.R. NICHT gleichzeitig
    /// `UTType.image` erfüllt.
    private func loadSharedAttachment() async -> SharedAttachment? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
                  $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
              })
        else { return nil }

        if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            return await withCheckedContinuation { continuation in
                attachment.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                    let data: Data?
                    if let url = item as? URL { data = try? Data(contentsOf: url) }
                    else if let d = item as? Data { data = d }
                    else { data = nil }
                    guard let data, let document = PDFDocument(data: data) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let lines = Self.extractLines(from: document)
                    continuation.resume(returning: lines.isEmpty ? nil : .pdfLines(lines))
                }
            }
        }

        return await withCheckedContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                // Je nach Quell-App liefert der Item-Provider ein Bild als Datei-URL, als
                // rohes UIImage oder als Data — alle drei Formen defensiv abdecken.
                if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    continuation.resume(returning: .image(image))
                } else if let image = item as? UIImage {
                    continuation.resume(returning: .image(image))
                } else if let data = item as? Data, let image = UIImage(data: data) {
                    continuation.resume(returning: .image(image))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Textzeilen pro PDF-Seite, in der vom PDF selbst vorgegebenen Zeilenreihenfolge —
    /// `ReceiptParserService.parse` erwartet ohnehin bereits zeilengetrennten Text (normalerweise
    /// aus Visions Bounding-Box-Rekonstruktion), ein digitales PDF liefert das direkt.
    private static func extractLines(from document: PDFDocument) -> [String] {
        var lines: [String] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex), let text = page.string else { continue }
            lines.append(contentsOf: text.components(separatedBy: .newlines))
        }
        return lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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
