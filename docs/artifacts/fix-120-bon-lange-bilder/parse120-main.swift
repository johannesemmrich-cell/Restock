import Foundation
import CoreGraphics

// Wegwerf-Harness #120: ReceiptParserService.reconstructLines + parse auf JSON-Blöcken.
let path = CommandLine.arguments[1]
let arr = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [[String: Any]]
let blocks: [(text: String, box: CGRect)] = arr.map {
    (text: $0["t"] as! String, box: CGRect(x: $0["x"] as! Double, y: $0["y"] as! Double, width: $0["w"] as! Double, height: $0["h"] as! Double))
}
let lines = ReceiptParserService.reconstructLines(blocks)
print("== rekonstruierte Zeilen: \(lines.count)")
for l in lines { print("  | \(l)") }
let parsed = ReceiptParserService.parse(lines)
print("== erkannte Positionen: \(parsed.count)")
for p in parsed { print(String(format: "  %-30@ %8.2f  x%.0f", p.name as NSString, p.price, p.quantity)) }
print("== Summe der Positionen: \(parsed.reduce(0) { $0 + $1.price })  | erkannte Endsumme: \(String(describing: ReceiptParserService.detectedTotal(from: lines)))")
