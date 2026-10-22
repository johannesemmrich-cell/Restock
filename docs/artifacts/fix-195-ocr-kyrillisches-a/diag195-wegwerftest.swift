
// Wegwerf-Diagnose #195 (nur in der Scratchpad-Kopie): Rohblöcke je Streifen und Varianten der Vision-Anfrage.
final class Diag195Tests: XCTestCase {
    private func escaped(_ s: String) -> String {
        s.unicodeScalars.map { $0.value > 127 ? "\\u{\(String($0.value, radix: 16))}" : String($0) }.joined()
    }

    private func run(_ label: String, configure: (VNRecognizeTextRequest) -> Void) {
        let image = GeneratedReceipt.makeTallImage()
        var tileIndex = 0
        let blocks = ReceiptTextRecognizer.recognizeBlocks(in: image, orientation: .up) { img, orientation in
            let request = ReceiptTextRecognizer.makeRequest()
            configure(request)
            try VNImageRequestHandler(cgImage: img, orientation: orientation, options: [:]).perform([request])
            let result = (request.results ?? []).compactMap { o in
                o.topCandidates(1).first.map { (text: $0.string, box: o.boundingBox) }
            }
            print("DIAG|\(label)|tile \(tileIndex) h=\(img.height): \(result.count) blocks")
            for b in result {
                print("DIAG|\(label)|  t\(tileIndex) y=\(String(format: "%.3f", b.box.midY)) x=\(String(format: "%.2f", b.box.minX)) \(escaped(b.text))")
            }
            tileIndex += 1
            return result
        }
        let lines = ReceiptParserService.reconstructLines(blocks)
        let parsed = ReceiptParserService.parse(lines)
        let total = ReceiptParserService.detectedTotal(from: lines)
        print("DIAG|\(label)|SUMMARY blocks=\(blocks.count) lines=\(lines.count) positions=\(parsed.count) total=\(String(describing: total))")
        for l in lines { print("DIAG|\(label)|L| \(escaped("\(l)"))") }
        print("DIAG|\(label)|NAMES \(parsed.map(\.name))")
    }

    func test_diag_1_heute() { run("heute") { _ in } }
    func test_diag_2_rev2() { run("rev2") { $0.revision = VNRecognizeTextRequestRevision2 } }
    func test_diag_3_fast() { run("fast") { $0.recognitionLevel = .fast } }
    func test_diag_4_deOnly() { run("deOnly") { $0.recognitionLanguages = ["de-DE"] } }
    func test_diag_5_langCorr() { run("langCorr") { $0.usesLanguageCorrection = true } }
    func test_diag_6_minHeight() { run("minH") { $0.minimumTextHeight = 0.005 } }
}
