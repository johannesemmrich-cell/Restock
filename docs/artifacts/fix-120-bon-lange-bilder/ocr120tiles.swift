import Foundation
import Vision
import AppKit

// Wegwerf-Messskript #120: gleiche Vision-Einstellungen wie die App, aber je Streifen statt ganzes Bild.
let path = CommandLine.arguments[1]
let tileH = Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "2400")!
let overlap = 300
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("Bild nicht lesbar"); exit(1) }
let W = cg.width, H = cg.height
print("Bild \(W)x\(H), Streifenhöhe \(tileH), Überlappung \(overlap)")
var total = 0
var lines: [(Double, String)] = []   // globale y (0 = oben) für Sortierung
var y = 0
while y < H {
    let h = min(tileH, H - y)
    guard let tile = cg.cropping(to: CGRect(x: 0, y: y, width: W, height: h)) else { break }
    var n = 0
    let req = VNRecognizeTextRequest { r, _ in
        let obs = r.results as? [VNRecognizedTextObservation] ?? []
        for o in obs {
            guard let c = o.topCandidates(1).first else { continue }
            let topInTile = (1.0 - Double(o.boundingBox.midY)) * Double(h)
            lines.append((Double(y) + topInTile, c.string)); n += 1
        }
    }
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
    req.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: tile, orientation: .up, options: [:]).perform([req])
    print("Streifen y=\(y) h=\(h): \(n) Blöcke")
    total += n
    if y + h >= H { break }
    y += tileH - overlap
}
print("Summe Blöcke (mit Doppelten im Überlappungsbereich): \(total)")
for (gy, t) in lines.sorted(by: { $0.0 < $1.0 }) { print(String(format: "%7.0f | %@", gy, t)) }
