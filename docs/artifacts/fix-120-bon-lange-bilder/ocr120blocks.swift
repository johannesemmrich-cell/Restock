import Foundation
import Vision
import AppKit

// Wegwerf-Messskript #120: Blöcke je Streifen (oder Ganzbild bei tileH=0) als JSON mit globalen, normierten Boxen
// (Vision-Konvention: Ursprung unten links), Duplikate aus der Überlappung entfernt.
let path = CommandLine.arguments[1]
let tileH = Int(CommandLine.arguments[2])!
let outPath = CommandLine.arguments[3]
let overlap = 300
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("Bild nicht lesbar"); exit(1) }
let W = Double(cg.width), H = Double(cg.height)
var out: [[String: Any]] = []
var y = 0
let step = tileH == 0 ? Int(H) : tileH
while Double(y) < H {
    let h = tileH == 0 ? Int(H) : min(tileH, Int(H) - y)
    guard let tile = cg.cropping(to: CGRect(x: 0, y: y, width: Int(W), height: h)) else { break }
    let req = VNRecognizeTextRequest { r, _ in
        for o in (r.results as? [VNRecognizedTextObservation] ?? []) {
            guard let c = o.topCandidates(1).first else { continue }
            let b = o.boundingBox
            let topPx = Double(y) + (1.0 - Double(b.maxY)) * Double(h)
            let bottomPx = topPx + Double(b.height) * Double(h)
            let gMinY = 1.0 - bottomPx / H
            let dup = out.contains { ($0["t"] as? String) == c.string && abs(($0["y"] as! Double) - gMinY) * H < 15 }
            if dup { continue }
            out.append(["t": c.string, "x": Double(b.minX), "y": gMinY, "w": Double(b.width), "h": Double(b.height) * Double(h) / H])
        }
    }
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
    req.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: tile, orientation: .up, options: [:]).perform([req])
    if y + h >= Int(H) { break }
    y += step - overlap
}
let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted])
try data.write(to: URL(fileURLWithPath: outPath))
print("Blöcke: \(out.count)")
