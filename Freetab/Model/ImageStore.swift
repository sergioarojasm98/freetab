import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downscales evidence images before they are stored, so screenshots don't eat the user's iCloud quota.
enum ImageStore {
    static let maxPixelSize = 2048
    static let thumbnailPixelSize = 320

    /// Returns (full, thumbnail) JPEG data, or nil when the input isn't an image.
    static func prepare(_ data: Data) -> (image: Data, thumbnail: Data)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let full = jpeg(from: source, maxPixelSize: maxPixelSize, quality: 0.82),
              let thumb = jpeg(from: source, maxPixelSize: thumbnailPixelSize, quality: 0.7)
        else { return nil }
        return (full, thumb)
    }

    private static func jpeg(from source: CGImageSource, maxPixelSize: Int, quality: Double) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
