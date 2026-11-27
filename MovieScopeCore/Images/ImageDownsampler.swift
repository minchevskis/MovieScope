import CoreGraphics
import Foundation
import ImageIO

public enum ImageDecodingError: Error, Equatable {
    case undecodable
}

/// Decodes image data directly at the size it will be shown.
///
/// ImageIO's thumbnail API streams the source and never materialises the full
/// image, avoiding the memory spike of decoding first and scaling afterwards
/// (WWDC18 "iOS Memory Deep Dive"). Available on every platform the core supports.
public enum ImageDownsampler {
    public static func downsample(_ data: Data, maxPixelSize: Int) throws -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ImageDecodingError.undecodable
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize)
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ImageDecodingError.undecodable
        }
        return image
    }
}
