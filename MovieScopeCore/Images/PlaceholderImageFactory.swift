import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Generates deterministic PNG images: test data for the image pipeline and the
/// artwork served by `FixtureTransport` in UI-test mode. No binary assets needed.
public enum PlaceholderImageFactory {
    public static func pngData(width: Int, height: Int, seed: Int = 0) -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: max(1, width),
            height: max(1, height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return Data() }

        let hue = CGFloat(abs(seed) % 360) / 360
        let top = color(hue: hue, brightness: 0.55, in: colorSpace)
        let bottom = color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), brightness: 0.25, in: colorSpace)
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        }

        guard let image = context.makeImage() else { return Data() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func color(hue: CGFloat, brightness: CGFloat, in space: CGColorSpace) -> CGColor {
        // Simple HSV → RGB with fixed saturation, avoiding platform colour types.
        let saturation: CGFloat = 0.6
        let sector = hue * 6
        let fraction = sector - floor(sector)
        let low = brightness * (1 - saturation)
        let falling = brightness * (1 - saturation * fraction)
        let rising = brightness * (1 - saturation * (1 - fraction))
        let rgb: [CGFloat]
        switch Int(sector) % 6 {
        case 0: rgb = [brightness, rising, low]
        case 1: rgb = [falling, brightness, low]
        case 2: rgb = [low, brightness, rising]
        case 3: rgb = [low, falling, brightness]
        case 4: rgb = [rising, low, brightness]
        default: rgb = [brightness, low, falling]
        }
        return CGColor(colorSpace: space, components: rgb + [1]) ?? CGColor(gray: brightness, alpha: 1)
    }
}
