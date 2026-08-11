import UIKit

/// Pure, I/O-free JPEG compression for item photos. No CloudKit/SwiftData dependency — fully
/// unit-testable without a simulator camera or network access.
enum PhotoCompressor {
    /// Resizes to at most `maxDimension` on the longer side, then JPEG-encodes, stepping quality
    /// down until the result is under `sizeCap` bytes or the lowest quality step is reached.
    static func compress(_ image: UIImage, maxDimension: CGFloat = 1600, sizeCap: Int = 500_000) -> Data? {
        let resized = resized(image, maxDimension: maxDimension)
        for quality in [0.6, 0.4, 0.25] {
            guard let data = resized.jpegData(compressionQuality: quality) else { continue }
            if data.count <= sizeCap { return data }
        }
        return resized.jpegData(compressionQuality: 0.25)
    }

    /// `format.scale = 1` is essential here: `UIGraphicsImageRenderer(size:)` otherwise defaults
    /// to the main screen's scale factor (2x/3x), which would render (and then JPEG-encode) a
    /// bitmap up to 3x larger per side than `targetSize` — silently defeating both `maxDimension`
    /// and the whole point of compressing before upload.
    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longerSide = max(image.size.width, image.size.height)
        guard longerSide > maxDimension else { return image }
        let scale = maxDimension / longerSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
