import XCTest
import UIKit
@testable import Restock

final class PhotoCompressorTests: XCTestCase {
    /// `format.scale = 1` matches a real photo from `UIImagePickerController` (scale 1), so the
    /// resulting `.size` is directly comparable in pixels to `maxDimension` — without this, the
    /// simulator's screen scale (2x/3x) would inflate the raw bitmap this helper produces.
    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testCompressorProducesDataUnderSizeCap() throws {
        let image = makeImage(width: 3000, height: 2000)
        let data = try XCTUnwrap(PhotoCompressor.compress(image, maxDimension: 1600, sizeCap: 500_000))
        XCTAssertLessThanOrEqual(data.count, 500_000)
    }

    func testCompressorDownsizesLargeImage() throws {
        let image = makeImage(width: 3200, height: 1600)
        let data = try XCTUnwrap(PhotoCompressor.compress(image, maxDimension: 1600, sizeCap: 500_000))
        let result = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(result.size.width, result.size.height), 1600)
    }

    func testCompressorLeavesSmallImageDimensionsUnchanged() throws {
        let image = makeImage(width: 200, height: 150)
        let data = try XCTUnwrap(PhotoCompressor.compress(image, maxDimension: 1600, sizeCap: 500_000))
        let result = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(result.size.width, 200, accuracy: 1)
        XCTAssertEqual(result.size.height, 150, accuracy: 1)
    }
}
