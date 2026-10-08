import Foundation
import Vision
import AppKit

// Wegwerf-Messskript #120: dieselbe Vision-Anfrage wie ReceiptScannerView.process (accurate, Sprachen, ohne Korrektur).
let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("Bild nicht lesbar"); exit(1) }
print("Bild \(cg.width)x\(cg.height)")
var blocks: [(String, CGRect)] = []
let req = VNRecognizeTextRequest { r, _ in
    let obs = r.results as? [VNRecognizedTextObservation] ?? []
    for o in obs { if let c = o.topCandidates(1).first { blocks.append((c.string, o.boundingBox)) } }
}
req.recognitionLevel = .accurate
req.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
req.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:]).perform([req])
print("Blöcke: \(blocks.count)")
for (t, b) in blocks.sorted(by: { $0.1.midY > $1.1.midY }) {
    print(String(format: "y=%.3f x=%.3f w=%.3f h=%.4f | %@", b.midY, b.minX, b.width, b.height, t))
}
