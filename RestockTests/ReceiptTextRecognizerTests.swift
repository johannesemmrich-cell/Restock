import XCTest
import UIKit
import Vision
@testable import Restock

/// Issue #120 (Spec `docs/specs/services/receipt-text-recognizer-tiling.md`): Ein sehr hohes Bon-Bild
/// (Lidl Plus, 1206 × 9089 px) verliert im Einzelzug der Vision-Erkennung den Großteil des Textes.
/// `ReceiptTextRecognizer` schneidet solche Bilder in überlappende Streifen.
///
/// Festlegungen dieser Tests (die Spec lässt sie offen):
/// - `enum ReceiptTextRecognizer` mit
///   `needsTiling(imageSize:) -> Bool`, `tiles(imageSize:) -> [CGRect]`,
///   `globalBox(_:tile:imageSize:) -> CGRect`,
///   `removingDuplicates(_:imageSize:) -> [(text: String, box: CGRect)]`,
///   `recognizeBlocks(in:orientation:) -> [(text: String, box: CGRect)]`,
///   `makeRequest() -> VNRecognizeTextRequest` (Anfrage mit den Einstellungen von heute, AC-9),
///   `recognizeBlocks(imageSize:crop:recognize:)` — einhängbare Fassung für T9/T10: `crop` wird für
///   JEDEN Streifen aufgerufen (auch für den einen Gesamtbild-Streifen), `recognize` liefert die
///   Vision-Blöcke eines Streifens (Box bezogen auf den Streifen) oder wirft.
/// - Bildgröße 0 (Breite oder Höhe): `tiles` liefert `[]` (kein Streifen der Höhe 0), die Erkennung
///   ruft nichts auf und gibt `[]` zurück.
/// - Toleranzen: Streifenhöhe 2 × Breite und Überlappung 0,25 × Breite je ± 5 % (ganzzahlig gerundet).
///
/// Testplan-Zuordnung: T1–T10 hier. T11 (ganze Unit-Suite), T12 (ganze UI-Suite auf Restock-Validate),
/// T13 (Release-Build) und T14 (`git diff --stat` gegen den Tip-Commit) sind Befehlsprüfungen der
/// Phasen 6/7 und kein XCTest.
final class ReceiptTextRecognizerTests: XCTestCase {

    private typealias Block = (text: String, box: CGRect)
    private let tall = CGSize(width: 1206, height: 9089)

    // MARK: - T1 (AC-1, AC-2): erzeugtes hohes Bild, Einzelzug verliert Text, Streifen nicht

    func test_T1_erzeugtesHohesBild_streifenErkennenAlleArtikelUndEndsumme() {
        let image = GeneratedReceipt.makeTallImage()
        let singleLines = ReceiptParserService.reconstructLines(GeneratedReceipt.singlePassBlocks(image))
        let tiledLines = ReceiptParserService.reconstructLines(
            ReceiptTextRecognizer.recognizeBlocks(in: image, orientation: .up))
        let single = ReceiptParserService.parse(singleLines)
        let tiled = ReceiptParserService.parse(tiledLines)

        // Ist-Zustand (Messung Simulator: Einzelzug 11 Positionen ohne Endsumme, Streifen 18 + 68,69).
        XCTAssertLessThan(single.count, GeneratedReceipt.items.count, "Einzelzug verliert Text nicht mehr — Bild prüfen")
        // Alle Artikelzeilen da, keine doppelten aus der Überlappung, jeder Preis genau einmal. Namen: OCR darf
        // höchstens einen Buchstaben verlesen (beobachtet: „Lahnpasta“ bei um 1 px verschobener Streifenkante).
        XCTAssertEqual(tiled.count, GeneratedReceipt.items.count, "keine doppelten Positionen aus der Überlappung")
        let expectedPrices = GeneratedReceipt.items.map { Double($0.price.dropLast(2).replacingOccurrences(of: ",", with: "."))! }
        XCTAssertEqual(tiled.map(\.price).sorted(), expectedPrices.sorted())
        let exactNames = Set(tiled.map(\.name)).intersection(GeneratedReceipt.items.map(\.name))
        XCTAssertGreaterThanOrEqual(exactNames.count, GeneratedReceipt.items.count - 1, "\(tiled.map(\.name))")
        XCTAssertEqual(ReceiptParserService.detectedTotal(from: tiledLines) ?? 0, GeneratedReceipt.total, accuracy: 0.001)
    }

    // MARK: - T2 (AC-3): Schwelle

    func test_T2_needsTiling_schwelleExklusiv2Komma5() {
        let cases: [(CGSize, Bool)] = [
            (tall, true), (CGSize(width: 1206, height: 3100), true),
            (CGSize(width: 1000, height: 1500), false), (CGSize(width: 1000, height: 2000), false),
            (CGSize(width: 1000, height: 2500), false), (CGSize(width: 1000, height: 2501), true),
            (.zero, false), (CGSize(width: 0, height: 900), false), (CGSize(width: 900, height: 0), false),
        ]
        for (size, expected) in cases {
            XCTAssertEqual(ReceiptTextRecognizer.needsTiling(imageSize: size), expected, "\(size)")
        }
    }

    // MARK: - T3 (AC-4, AC-5): Streifen des Problembilds

    func test_T3_tiles_problembild_lueckenlosUeberlappendBisBildende() {
        let tiles = ReceiptTextRecognizer.tiles(imageSize: tall)
        XCTAssertGreaterThan(tiles.count, 1)
        XCTAssertEqual(tiles.first?.minY, 0)
        XCTAssertEqual(tiles.last?.maxY, tall.height)
        for (i, t) in tiles.enumerated() where i < tiles.count - 1 {
            XCTAssertEqual(t.height, 2 * tall.width, accuracy: 0.05 * 2 * tall.width, "Streifen \(i)")
        }
        assertTileInvariants(tiles, size: tall)
    }

    // MARK: - T4 (AC-4, AC-5): Ränder

    func test_T4_tiles_raender_keineHoeheNullKeinReinerUeberlappungsstreifen() {
        let w: CGFloat = 1000
        var heights: [CGFloat] = [2001, 2250, 2501, 3750, 3751, 4001, 10]
        heights += stride(from: CGFloat(2501), through: 12000, by: 37).map { $0 }
        for h in heights {
            let size = CGSize(width: w, height: h)
            let tiles = ReceiptTextRecognizer.tiles(imageSize: size)
            if ReceiptTextRecognizer.needsTiling(imageSize: size) {
                assertTileInvariants(tiles, size: size)
            } else {
                XCTAssertEqual(tiles, [CGRect(origin: .zero, size: size)], "ohne Bedarf genau ein Streifen, h=\(h)")
            }
        }
        XCTAssertEqual(ReceiptTextRecognizer.tiles(imageSize: CGSize(width: 1000, height: 1500)),
                       [CGRect(x: 0, y: 0, width: 1000, height: 1500)])
        XCTAssertEqual(ReceiptTextRecognizer.tiles(imageSize: .zero), [], "Bildgröße 0 → kein Streifen")
    }

    private func assertTileInvariants(_ tiles: [CGRect], size: CGSize, line: UInt = #line) {
        let overlapTarget = 0.25 * size.width
        XCTAssertEqual(tiles.first?.minY, 0, line: line)
        XCTAssertEqual(tiles.last?.maxY, size.height, "letzter endet am Bildende (h=\(size.height))", line: line)
        for (i, t) in tiles.enumerated() {
            XCTAssertEqual(t.minX, 0, line: line); XCTAssertEqual(t.width, size.width, line: line)
            XCTAssertGreaterThan(t.height, 0, line: line)
            XCTAssertEqual(t.minY, t.minY.rounded(), "ganzzahlig", line: line)
            XCTAssertEqual(t.height, t.height.rounded(), "ganzzahlig", line: line)
            guard i > 0 else { continue }
            let prev = tiles[i - 1]
            let overlap = prev.maxY - t.minY
            XCTAssertGreaterThanOrEqual(overlap, 0.95 * overlapTarget, "kein Spalt, Überlappung (h=\(size.height), \(i))", line: line)
            if i < tiles.count - 1 {
                XCTAssertEqual(overlap, overlapTarget, accuracy: 0.05 * overlapTarget, line: line)
            }
            XCTAssertGreaterThan(t.maxY, prev.maxY, "Streifen \(i) besteht nur aus Überlappung (h=\(size.height))", line: line)
        }
    }

    // MARK: - T5 (AC-6): Umrechnung

    func test_T5_globalBox_ersterMittlererLetzterStreifen() {
        let H = tall.height
        let first = CGRect(x: 0, y: 0, width: 1206, height: 2412)
        let middle = CGRect(x: 0, y: 2111, width: 1206, height: 2412)
        let last = CGRect(x: 0, y: 6677, width: 1206, height: 2412)
        let box = CGRect(x: 0.1, y: 0.5, width: 0.4, height: 0.02)

        let g1 = ReceiptTextRecognizer.globalBox(box, tile: first, imageSize: tall)
        XCTAssertEqual(g1.minY, (H - 2412 + 0.5 * 2412) / H, accuracy: 1e-9)
        XCTAssertEqual(g1.height, 0.02 * 2412 / H, accuracy: 1e-9)
        XCTAssertEqual(g1.minX, 0.1, accuracy: 1e-12); XCTAssertEqual(g1.width, 0.4, accuracy: 1e-12)

        let g2 = ReceiptTextRecognizer.globalBox(CGRect(x: 0.6, y: 0.25, width: 0.3, height: 0.02), tile: middle, imageSize: tall)
        XCTAssertEqual(g2.minY, (H - 4523 + 0.25 * 2412) / H, accuracy: 1e-9)
        XCTAssertEqual(g2.minX, 0.6, accuracy: 1e-12); XCTAssertEqual(g2.width, 0.3, accuracy: 1e-12)

        // Rand: Unterkante des letzten Streifens = Bildunterkante (0), Oberkante des ersten = Bildoberkante (1).
        XCTAssertEqual(ReceiptTextRecognizer.globalBox(CGRect(x: 0, y: 0, width: 1, height: 0.02), tile: last, imageSize: tall).minY,
                       0, accuracy: 1e-9)
        XCTAssertEqual(ReceiptTextRecognizer.globalBox(CGRect(x: 0, y: 0.98, width: 1, height: 0.02), tile: first, imageSize: tall).maxY,
                       1, accuracy: 1e-9)
        XCTAssertEqual(ReceiptTextRecognizer.globalBox(CGRect(x: 0, y: 0.98, width: 1, height: 0.02), tile: last, imageSize: tall).maxY,
                       (H - 6677) / H, accuracy: 1e-9)
    }

    // MARK: - T6 (AC-7), T7 (AC-8): Duplikate

    /// Block mit Oberkante `top` (Pixel von oben) und 40 px Texthöhe, in normierten Gesamtbild-Koordinaten.
    private func block(_ text: String, top: CGFloat, x: CGFloat = 0.05) -> Block {
        (text: text, box: CGRect(x: x, y: (tall.height - top - 40) / tall.height, width: 0.3, height: 40 / tall.height))
    }

    func test_T6_removingDuplicates_gleicheZeileAusZweiStreifen_bleibtEinmal() {
        for shift: CGFloat in [3, 8] {
            let result = ReceiptTextRecognizer.removingDuplicates(
                [block("Bio Eier 2,49", top: 2200), block("Bio Eier 2,49", top: 2200 + shift)], imageSize: tall)
            XCTAssertEqual(result.count, 1, "Verschiebung \(shift) px")
        }
    }

    func test_T7_removingDuplicates_echteWiederholungUndAndererText_bleibenBeide() {
        let repeated = ReceiptTextRecognizer.removingDuplicates(
            [block("Bio Eier 2,49", top: 3000), block("Bio Eier 2,49", top: 3040)], imageSize: tall)
        XCTAssertEqual(repeated.count, 2, "zwei gleiche Artikel in getrennten Zeilen")
        let different = ReceiptTextRecognizer.removingDuplicates(
            [block("Bio Eier", top: 3000), block("2,49 A", top: 3002, x: 0.77)], imageSize: tall)
        XCTAssertEqual(different.count, 2, "naher Mittelpunkt, anderer Text")
    }

    // MARK: - T8: synthetische Streifen-Blöcke ergeben dieselben Positionen wie das Gesamtbild

    func test_T8_streifenBloecke_ergebenGleichePositionenWieGesamtbild() {
        let tiles = ReceiptTextRecognizer.tiles(imageSize: tall)
        XCTAssertGreaterThanOrEqual(tiles.count, 3)
        guard tiles.count >= 3 else { return }
        let tops: [CGFloat] = [300, 1500, tiles[0].maxY - 150, tiles[1].maxY - 120, tiles[1].minY + 900, tall.height - 200]
        let names = ["Vollmilch", "Butter mild", "Gouda Scheiben", "Roggenbrot", "Eier Freiland", "Weizenmehl"]
        var global: [Block] = []
        for (i, top) in tops.enumerated() {
            global.append(block(names[i], top: top))
            global.append(block("\(i + 1),49 A", top: top, x: 0.77))
        }
        var fromTiles: [Block] = []
        for (ti, tile) in tiles.enumerated() {
            let jitter: CGFloat = ti.isMultiple(of: 2) ? 0 : 2
            for (i, top) in tops.enumerated() where top >= tile.minY && top + 40 <= tile.maxY {
                for (text, x) in [(names[i], CGFloat(0.05)), ("\(i + 1),49 A", CGFloat(0.77))] {
                    let local = CGRect(x: x, y: (tile.maxY - top - 40 + jitter) / tile.height,
                                       width: 0.3, height: 40 / tile.height)
                    fromTiles.append((text: text, box: ReceiptTextRecognizer.globalBox(local, tile: tile, imageSize: tall)))
                }
            }
        }
        let merged = ReceiptTextRecognizer.removingDuplicates(fromTiles, imageSize: tall)
        let expected = ReceiptParserService.parse(ReceiptParserService.reconstructLines(global))
        let actual = ReceiptParserService.parse(ReceiptParserService.reconstructLines(merged))
        XCTAssertEqual(expected.count, tops.count)
        XCTAssertEqual(actual.map(\.name), expected.map(\.name))
        XCTAssertEqual(actual.map(\.price), expected.map(\.price))
    }

    // MARK: - T9 (AC-9, AC-10): normales Bild bleibt im Einzelzug, Einstellungen wie heute

    func test_T9_anfrage_einstellungenWieHeute() {
        let request = ReceiptTextRecognizer.makeRequest()
        XCTAssertEqual(request.recognitionLevel, .accurate)
        XCTAssertEqual(request.recognitionLanguages, ["de-DE", "fr-FR", "en-US"])
        XCTAssertFalse(request.usesLanguageCorrection)
    }

    func test_T9_normalesBild_einDurchgangUndGleichesErgebnisWieBisher() {
        let image = GeneratedReceipt.makeTallImage(width: 1206, height: 1800)
        let size = CGSize(width: image.width, height: image.height)
        var calls: [CGSize] = []
        _ = ReceiptTextRecognizer.recognizeBlocks(imageSize: size, crop: { _ in image }, recognize: { tile in
            calls.append(CGSize(width: tile.width, height: tile.height)); return []
        })
        XCTAssertEqual(calls, [size], "genau ein Durchgang auf dem Gesamtbild")

        let now = ReceiptTextRecognizer.recognizeBlocks(in: image, orientation: .up).map(\.text)
        let before = GeneratedReceipt.singlePassBlocks(image).map(\.text)
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(now.sorted(), before.sorted())
    }

    // MARK: - T10 (AC-11): Fehler einzelner Streifen, Bildgröße 0

    func test_T10_fehlerInStreifen_uebrigeLaufenWeiter_groesseNullLeer() {
        let dummy = GeneratedReceipt.makeTallImage(width: 4, height: 4, withFooter: false)
        let tiles = ReceiptTextRecognizer.tiles(imageSize: tall)
        XCTAssertGreaterThanOrEqual(tiles.count, 3)
        struct VisionFailure: Error {}
        var cropped: [CGRect] = []
        let result = ReceiptTextRecognizer.recognizeBlocks(imageSize: tall, crop: { rect in
            cropped.append(rect)
            return rect == tiles[1] ? nil : dummy
        }, recognize: { _ in
            let index = cropped.count - 1
            if index == 2 { throw VisionFailure() }
            return [(text: "Streifen \(index)", box: CGRect(x: 0.1, y: 0.5, width: 0.3, height: 0.01))]
        })
        XCTAssertEqual(cropped, tiles, "alle Streifen werden versucht")
        let texts = Set(result.map(\.text))
        XCTAssertTrue(texts.contains("Streifen 0"))
        XCTAssertFalse(texts.contains("Streifen 1"), "Zuschnitt nil → Streifen leer")
        XCTAssertFalse(texts.contains("Streifen 2"), "Vision wirft → Streifen leer")
        XCTAssertTrue(texts.contains("Streifen \(tiles.count - 1)"), "übrige Streifen laufen weiter")

        var called = false
        let empty = ReceiptTextRecognizer.recognizeBlocks(imageSize: .zero, crop: { _ in called = true; return dummy },
                                                          recognize: { _ in called = true; return [] })
        XCTAssertTrue(empty.isEmpty); XCTAssertFalse(called)
    }
}

/// Erzeugtes Bon-Bild (Lidl-Plus-Stil) und die Einzelzug-Erkennung genau wie der bisherige
/// `ReceiptScannerView.process(_:)`. Messung Ist-Zustand:
/// `docs/artifacts/fix-120-bon-lange-bilder/ist-zustand-erzeugtes-bild.txt`.
enum GeneratedReceipt {
    static let total = 68.69
    static let items: [(name: String, price: String)] = [
        ("Bananen lose", "1,29 A"), ("Nektarinen", "1,89 A"), ("Gouda Scheiben", "2,45 A"),
        ("Schlagsahne", "0,89 A"), ("Penne Rigate", "0,69 A"), ("Spaghetti", "0,69 A"),
        ("Eier Freiland", "2,29 A"), ("Haferflocken", "0,85 A"), ("Olivenoel nativ", "4,99 A"),
        ("Mandelkerne", "2,49 A"), ("Broetchen Laugen", "0,78 A"), ("Joghurt Natur", "0,59 A"),
        ("Butter mild", "2,19 A"), ("Tomaten Rispe", "1,99 A"), ("Gurke", "0,79 A"),
        ("Kaffee Bohnen", "8,99 A"), ("Mineralwasser", "1,49 A"), ("Zahnpasta", "1,29 A"),
    ]

    /// Menlo 40 pt bei Skalierung 1, Zeilenabstand 66 px, Namen bei x = 0,05, Preise rechtsbündig bis
    /// x = 0,93, unter jedem Artikel eine blaue „Lidl Plus Rabatt -0,08“-Zeile, danach Endsumme und
    /// TSE-Füllzeilen bis zum Bildende. Was unterhalb von `height` liegt, wird abgeschnitten.
    static func makeTallImage(width: Int = 1206, height: Int = 9000, withFooter: Bool = true) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        let font = UIFont(name: "Menlo-Regular", size: 40) ?? .monospacedSystemFont(ofSize: 40, weight: .regular)
        let gap: CGFloat = 66
        let nameX = CGFloat(width) * 0.05, priceRight = CGFloat(width) * 0.93
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            guard withFooter else { return }
            var y: CGFloat = 160
            func draw(_ text: String, right: Bool = false, blue: Bool = false) {
                let color: UIColor = blue ? UIColor(red: 0, green: 0.3, blue: 0.8, alpha: 1) : .black
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let w = (text as NSString).size(withAttributes: attrs).width
                (text as NSString).draw(at: CGPoint(x: right ? priceRight - w : nameX, y: y), withAttributes: attrs)
            }
            for header in ["LIDL Musterfiliale", "Musterstrasse 1", "12345 Musterstadt", "EUR"] { draw(header); y += gap }
            y += gap
            for item in items {
                draw(item.name); draw(item.price, right: true); y += gap
                draw("Lidl Plus Rabatt", blue: true); draw("-0,08", right: true, blue: true); y += gap
            }
            y += gap
            draw("Zu zahlen"); draw("68,69", right: true); y += gap
            draw("Kreditkarte"); draw("68,69", right: true); y += gap * 2
            var i = 0
            while y < CGFloat(height) - 150 { draw("TSE Signatur \(1000 + i) Kasse \(i % 7)"); y += gap; i += 1 }
        }
        return image.cgImage!
    }

    /// Kopie der bisherigen Einzelzug-Anfrage aus `ReceiptScannerView.process(_:)`.
    static func singlePassBlocks(_ image: CGImage) -> [(text: String, box: CGRect)] {
        var blocks: [(text: String, box: CGRect)] = []
        let request = VNRecognizeTextRequest { req, _ in
            for o in (req.results as? [VNRecognizedTextObservation] ?? []) {
                if let c = o.topCandidates(1).first { blocks.append((text: c.string, box: o.boundingBox)) }
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
        return blocks
    }
}
