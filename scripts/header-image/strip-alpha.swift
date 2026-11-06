// Kopfbild (Issue #241): entfernt den Alphakanal eines PNG (Ergebnis: RGB, PNG-Farbtyp 2) und prüft die Pixel
// außerhalb des Sicherheitsbereichs (mittlere 84 % Breite, 76 % Höhe) gegen die Hintergrundfarbe.
// Aufruf: strip-alpha <eingabe.png> <ausgabe.png> <RRGGBB>
// Ausgabe (eine Zeile): "size=WxH alpha_in=<bool> corner=RRGGBB outside_non_bg=<n> outside_total=<n>"
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 4, let bg = UInt32(args[3], radix: 16) else { fail("Aufruf: strip-alpha <in.png> <out.png> <RRGGBB>") }
let bgR = UInt8((bg >> 16) & 0xFF), bgG = UInt8((bg >> 8) & 0xFF), bgB = UInt8(bg & 0xFF)

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fail("Kann \(args[1]) nicht lesen") }
let w = image.width, h = image.height
let alphaIn: Bool = {
    switch image.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast: return false
    default: return true
    }
}()

let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("Kein Zeichenkontext") }
// Erst die Hintergrundfarbe, dann das Bild: eventuelle Transparenz wird zur Hintergrundfarbe, nie zu Schwarz.
ctx.setFillColor(CGColor(colorSpace: space, components: [CGFloat(bgR) / 255, CGFloat(bgG) / 255, CGFloat(bgB) / 255, 1])
                 ?? CGColor(gray: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

guard let data = ctx.data else { fail("Keine Pixeldaten") }
let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
let x0 = Int((Double(w) * 0.08).rounded(.down)), x1 = Int((Double(w) * 0.92).rounded(.up))
let y0 = Int((Double(h) * 0.12).rounded(.down)), y1 = Int((Double(h) * 0.88).rounded(.up))
var outsideNonBg = 0, outsideTotal = 0
for y in 0..<h {
    let rowInside = y >= y0 && y < y1
    for x in 0..<w where !(rowInside && x >= x0 && x < x1) {
        outsideTotal += 1
        let i = (y * w + x) * 4
        if px[i] != bgR || px[i + 1] != bgG || px[i + 2] != bgB { outsideNonBg += 1 }
    }
}
let corner = String(format: "%02X%02X%02X", px[0], px[1], px[2])

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("Kann \(args[2]) nicht schreiben") }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { fail("PNG-Schreiben fehlgeschlagen") }
print("size=\(w)x\(h) alpha_in=\(alphaIn) corner=\(corner) outside_non_bg=\(outsideNonBg) outside_total=\(outsideTotal)")
