import CoreGraphics
import CoreImage
import Vision

/// Bon-Texterkennung (Issue #120, Spec `docs/specs/services/receipt-text-recognizer-tiling.md`).
///
/// Vision verliert bei Bildern mit extremem Seitenverhältnis (z. B. Lidl-Plus-Bon 1206 × 9089 px) den
/// Großteil des Textes, wenn das ganze Bild in einem Zug erkannt wird. Solche Bilder werden daher in
/// überlappende Streifen geschnitten, je Streifen erkannt, die Boxen in Gesamtbild-Koordinaten
/// umgerechnet und Duplikate der Überlappung entfernt. Normale Bon-Fotos bleiben im Einzelzug.
/// Rückgabe in der Form, die `ReceiptParserService.reconstructLines` erwartet.
enum ReceiptTextRecognizer {
    typealias Block = (text: String, box: CGRect)

    /// Höhe/Breite über dieser Schwelle -> Streifen (normale Bon-Fotos ca. 1,3 bis 2, Problembild ca. 7,5).
    static let tilingAspectThreshold: CGFloat = 2.5
    /// Streifenhöhe und Überlappung als Vielfache der Bildbreite (am Problembild gemessen: 2400 / 300 px).
    static let tileHeightFactor: CGFloat = 2
    static let overlapFactor: CGFloat = 0.25
    /// Duplikat: gleicher Text und Mittelpunkt-Abstand unter diesem Bruchteil der kleineren Texthöhe.
    static let duplicateDistanceFactor: CGFloat = 0.5

    static func needsTiling(imageSize: CGSize) -> Bool {
        guard imageSize.width > 0, imageSize.height > 0 else { return false }
        return imageSize.height / imageSize.width > tilingAspectThreshold
    }

    /// Streifen als Pixel-Rechtecke (Ursprung oben links wie `CGImage.cropping`), volle Breite,
    /// lückenlos und überlappend; der letzte endet genau am Bildende.
    static func tiles(imageSize: CGSize) -> [CGRect] {
        guard imageSize.width > 0, imageSize.height > 0 else { return [] }
        guard needsTiling(imageSize: imageSize) else { return [CGRect(origin: .zero, size: imageSize)] }
        let width = imageSize.width, height = imageSize.height
        let tileHeight = (tileHeightFactor * width).rounded()
        let step = tileHeight - (overlapFactor * width).rounded()
        var result: [CGRect] = []
        var top: CGFloat = 0
        while top + tileHeight < height {
            result.append(CGRect(x: 0, y: top, width: width, height: tileHeight))
            top += step
        }
        result.append(CGRect(x: 0, y: top, width: width, height: height - top))
        return result
    }

    /// Vision-Box (normiert, Ursprung unten links, bezogen auf den Streifen) -> normierte Box des
    /// Gesamtbildes (Ursprung unten links).
    static func globalBox(_ box: CGRect, tile: CGRect, imageSize: CGSize) -> CGRect {
        let height = imageSize.height
        let y = (height - tile.maxY + box.minY * tile.height) / height
        return CGRect(x: box.minX, y: y, width: box.width, height: box.height * tile.height / height)
    }

    /// Entfernt Duplikate aus den Überlappungsbereichen: gleicher (getrimmter) Text und Mittelpunkt-Abstand
    /// im Gesamtbild unter `duplicateDistanceFactor` × Texthöhe des kleineren Blocks. Der erste bleibt.
    static func removingDuplicates(_ blocks: [Block], imageSize: CGSize) -> [Block] {
        var kept: [Block] = []
        for block in blocks {
            let isDuplicate = kept.contains { other in
                guard other.text.trimmingCharacters(in: .whitespaces)
                        == block.text.trimmingCharacters(in: .whitespaces) else { return false }
                let dx = (other.box.midX - block.box.midX) * imageSize.width
                let dy = (other.box.midY - block.box.midY) * imageSize.height
                let minHeight = min(other.box.height, block.box.height) * imageSize.height
                return hypot(dx, dy) < duplicateDistanceFactor * minHeight
            }
            if !isDuplicate { kept.append(block) }
        }
        return kept
    }

    /// Anfrage mit den bisherigen Einstellungen aus `ReceiptScannerView.process(_:)`.
    static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
        // Bons bestehen aus Abkürzungen ("SHAK.MOUTARDE", "DBLE CCTRE") — Sprachkorrektur
        // würde sie zu Wörterbuch-Wörtern "verbessern" und damit verfälschen.
        request.usesLanguageCorrection = false
        return request
    }

    /// Erkennung (Streifen oder Einzelzug). Wirft Vision, bleibt der betroffene Streifen leer.
    static func recognizeBlocks(in cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [Block] {
        recognizeBlocks(in: cgImage, orientation: orientation, recognize: recognizeSingle)
    }

    /// Einhängbare Fassung der Bild-Erkennung: `recognize` bekommt Bild und Ausrichtung je Durchgang.
    static func recognizeBlocks(in cgImage: CGImage, orientation: CGImagePropertyOrientation,
                                recognize: (CGImage, CGImagePropertyOrientation) throws -> [Block]) -> [Block] {
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        // Einzelzug wie vor #120: Original-Bild, Original-Ausrichtung, kein Zuschnitt. Ebenso, wenn sich
        // ein gedrehtes Bild nicht aufrichten lässt.
        // Die Streifen-Geometrie bezieht sich auf das ausgerichtete Bild; geschnitten wird nur ein
        // aufrechtes Bild (`.up`), gedrehte Bilder mit Bedarf werden vorher aufgerichtet.
        guard needsTiling(imageSize: orientedSize(pixelSize, orientation)),
              let upright = orientation == .up ? cgImage : uprightImage(cgImage, orientation: orientation)
        else { return (try? recognize(cgImage, orientation)) ?? [] }
        return recognizeBlocks(imageSize: CGSize(width: upright.width, height: upright.height),
                               crop: { upright.cropping(to: $0) },
                               recognize: { try recognize($0, .up) })
    }

    /// Einhängbare Fassung: `crop` je Streifen, `recognize` liefert die Blöcke eines Streifens (Box
    /// bezogen auf den Streifen) oder wirft. Streifen nacheinander; ein gescheiterter bleibt leer.
    static func recognizeBlocks(imageSize: CGSize, crop: (CGRect) -> CGImage?,
                                recognize: (CGImage) throws -> [Block]) -> [Block] {
        let tileRects = tiles(imageSize: imageSize)
        let isSinglePass = tileRects.count == 1
        let blocks = tileRects.flatMap { tile -> [Block] in
            guard let image = crop(tile), let local = try? recognize(image) else { return [] }
            // Einzelzug: Boxen beziehen sich schon auf das Gesamtbild, Ergebnis bleibt wie bisher.
            if isSinglePass { return local }
            return local.map { (text: $0.text, box: globalBox($0.box, tile: tile, imageSize: imageSize)) }
        }
        return isSinglePass ? blocks : removingDuplicates(blocks, imageSize: imageSize)
    }

    private static func recognizeSingle(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> [Block] {
        let request = makeRequest()
        // WICHTIG: orientation muss mitgegeben werden — sonst verwirft Vision die
        // UIImage.imageOrientation-Metadaten und interpretiert Hochkant-Fotos (der
        // Sensor liefert die Pixel meist quer, iOS taggt nur die Rotation) als quer
        // liegenden Text. Ergebnis: "Keine Positionen erkannt" trotz gutem Foto.
        try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
        // Vision liefert bei Spaltenlayout (Name links, Preis rechts) getrennte Blöcke statt fertiger
        // Zeilen — `reconstructLines` setzt sie anhand der BoundingBoxen zu Bon-Zeilen zusammen.
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { (text: $0.string, box: observation.boundingBox) }
        }
    }

    private static func orientedSize(_ size: CGSize, _ orientation: CGImagePropertyOrientation) -> CGSize {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored: return CGSize(width: size.height, height: size.width)
        default: return size
        }
    }

    private static func uprightImage(_ image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
        let oriented = CIImage(cgImage: image).oriented(orientation)
        return CIContext().createCGImage(oriented, from: oriented.extent)
    }
}
