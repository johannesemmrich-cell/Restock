#!/usr/bin/env swift
//
// Erzeugt das synthetische Lidl-Plus-Bon-Bild für den CI-Lauf von
// `scripts/run-share-extension-uitest.sh` (Issue #99, Paket 4). Das echte Bon-Bild bleibt aus
// Datenschutzgründen außerhalb des Repos; dieses Bild ist die Zeile-für-Zeile-Abschrift von
// `GeneratedReceipt.makeTallImage` in `RestockTests/ReceiptTextRecognizerTests.swift` (1206 × 9000 px,
// Menlo 40, Zeilenabstand 66, 18 Positionen, Endsumme 68,69). Artikelliste und Endsumme müssen dort
// und hier gleich sein; `scripts/test_ci_share_extension.py` prüft das.
//
// Aufruf:  swift scripts/make-test-receipt-image.swift <ausgabe.png>
//
import AppKit
import Foundation
import Vision

let items: [(name: String, price: String)] = [
    ("Bananen lose", "1,29 A"), ("Nektarinen", "1,89 A"), ("Gouda Scheiben", "2,45 A"),
    ("Schlagsahne", "0,89 A"), ("Penne Rigate", "0,69 A"), ("Spaghetti", "0,69 A"),
    ("Eier Freiland", "2,29 A"), ("Haferflocken", "0,85 A"), ("Olivenoel nativ", "4,99 A"),
    ("Mandelkerne", "2,49 A"), ("Broetchen Laugen", "0,78 A"), ("Joghurt Natur", "0,59 A"),
    ("Butter mild", "2,19 A"), ("Tomaten Rispe", "1,99 A"), ("Gurke", "0,79 A"),
    ("Kaffee Bohnen", "8,99 A"), ("Mineralwasser", "1,49 A"), ("Zahnpasta", "1,29 A"),
]
let total = "68,69"
let width = 1206
let height = 9000

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("Aufruf: swift make-test-receipt-image.swift <ausgabe.png>\n".data(using: .utf8)!)
    exit(2)
}
let outputPath = CommandLine.arguments[1]

guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write("Kein Zeichenkontext\n".data(using: .utf8)!)
    exit(1)
}
context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Ursprung oben links wie bei UIGraphicsImageRenderer: Die Bitmap ist y-aufwärts, deshalb erst die
// Transformation kippen und dann AppKit sagen, dass der Kontext gekippt ist. `flipped: true` allein
// kippt NICHT (Lauf 39603940444: Erweiterung lief, erkannte aber nichts — Verdacht: Text stand auf
// dem Kopf); die Selbstprüfung unten belegt die Lesbarkeit vor dem Lauf.
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
let font = NSFont(name: "Menlo-Regular", size: 40) ?? NSFont.monospacedSystemFont(ofSize: 40, weight: .regular)
let gap: CGFloat = 66
let nameX = CGFloat(width) * 0.05
let priceRight = CGFloat(width) * 0.93
var y: CGFloat = 160

func draw(_ text: String, right: Bool = false, blue: Bool = false) {
    let color: NSColor = blue ? NSColor(red: 0, green: 0.3, blue: 0.8, alpha: 1) : .black
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let w = (text as NSString).size(withAttributes: attrs).width
    (text as NSString).draw(at: NSPoint(x: right ? priceRight - w : nameX, y: y), withAttributes: attrs)
}

for header in ["LIDL Musterfiliale", "Musterstrasse 1", "12345 Musterstadt", "EUR"] { draw(header); y += gap }
y += gap
for item in items {
    draw(item.name); draw(item.price, right: true); y += gap
    draw("Lidl Plus Rabatt", blue: true); draw("-0,08", right: true, blue: true); y += gap
}
y += gap
draw("Zu zahlen"); draw(total, right: true); y += gap
draw("Kreditkarte"); draw(total, right: true); y += gap * 2
var i = 0
while y < CGFloat(height) - 150 { draw("TSE Signatur \(1000 + i) Kasse \(i % 7)"); y += gap; i += 1 }
NSGraphicsContext.current = nil

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG konnte nicht erzeugt werden\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write("Schreiben fehlgeschlagen: \(error)\n".data(using: .utf8)!)
    exit(1)
}
print("Testbon geschrieben: \(outputPath) (\(width)×\(height) px, \(items.count) Positionen, Endsumme \(total))")

// Selbstprüfung mit der Texterkennung des Runners, nur auf dem oberen Streifen (2 × Breite): Ein
// Ganzbild-Durchgang verliert bei so hohen Bildern den Großteil des Textes (Issue #120), der Streifen
// zeigt aber, ob Schrift und Ausrichtung stimmen. Scheitert laut, damit der Teilen-Lauf nicht an
// einem unlesbaren Bild statt an der Erweiterung scheitert.
let cropHeight = min(height, width * 2)
guard let topCrop = image.cropping(to: CGRect(x: 0, y: 0, width: width, height: cropHeight)) else {
    FileHandle.standardError.write("Selbstprüfung: Ausschnitt konnte nicht erzeugt werden\n".data(using: .utf8)!)
    exit(1)
}
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["de-DE"]
request.usesLanguageCorrection = false
do {
    try VNImageRequestHandler(cgImage: topCrop, options: [:]).perform([request])
} catch {
    FileHandle.standardError.write("Selbstprüfung: Texterkennung fehlgeschlagen: \(error)\n".data(using: .utf8)!)
    exit(1)
}
let texts = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
let expectedNames = items.prefix(8).map { $0.name }
let foundNames = expectedNames.filter { name in texts.contains { $0.contains(name) } }
let headerFound = texts.contains { $0.contains("Musterfiliale") }
print("Selbstprüfung (Vision, obere \(cropHeight) px): \(texts.count) Textblöcke, "
      + "\(foundNames.count)/\(expectedNames.count) der ersten Artikelnamen, Kopfzeile: \(headerFound ? "ja" : "nein")")
if !headerFound || foundNames.count < 6 {
    FileHandle.standardError.write(("Selbstprüfung FEHLGESCHLAGEN — erkannte Blöcke: "
        + texts.prefix(12).joined(separator: " | ") + "\n").data(using: .utf8)!)
    exit(1)
}
