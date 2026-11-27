import CoreGraphics
import Foundation

/// The kinds of TMDB images, each with its own list of available sizes.
public enum ImageCategory: Sendable {
    case poster
    case backdrop
    case profile

    /// Width ÷ height of TMDB images in this category.
    public var aspectRatio: CGFloat {
        switch self {
        case .poster, .profile: 2.0 / 3.0
        case .backdrop: 16.0 / 9.0
        }
    }
}

/// Picks the TMDB size token for an image rendered at a given pixel width.
public enum ImageSizeSelector {
    /// The size an image of `aspectRatio` must have to completely cover a view
    /// of `viewSize` with aspect-fill (e.g. a 2:3 portrait in a square circle
    /// must be taller than the view, or it is upscaled and looks soft).
    public static func coveringSize(for viewSize: CGSize, aspectRatio: CGFloat) -> CGSize {
        guard aspectRatio > 0 else { return viewSize }
        let width = max(viewSize.width, viewSize.height * aspectRatio)
        return CGSize(width: width, height: width / aspectRatio)
    }

    /// Returns the smallest width token (`"wNNN"`) at least `pixelWidth` wide.
    /// Falls back to the largest width token when none is wide enough, and to
    /// `"original"` when the list has no width tokens at all.
    /// Height-based tokens (`"h632"`) and `"original"` are never chosen when a
    /// width token exists: `original` can be many megabytes.
    public static func size(from sizes: [String], pixelWidth: CGFloat) -> String {
        let widths = sizes.compactMap { token -> (token: String, width: Int)? in
            guard token.hasPrefix("w"), let width = Int(token.dropFirst()) else { return nil }
            return (token, width)
        }
        .sorted { $0.width < $1.width }

        guard let largest = widths.last else { return "original" }
        return widths.first { CGFloat($0.width) >= pixelWidth }?.token ?? largest.token
    }
}

extension ImageConfiguration {
    /// Used until `/configuration` has been fetched once, or when it can't be.
    /// Matches TMDB's live values (verified against the captured fixture in tests).
    public static let fallback = ImageConfiguration(
        secureBaseURL: URL(string: "https://image.tmdb.org/t/p/") ?? URL(fileURLWithPath: "/"),
        posterSizes: ["w92", "w154", "w185", "w342", "w500", "w780", "original"],
        backdropSizes: ["w300", "w780", "w1280", "original"],
        profileSizes: ["w45", "w185", "h632", "original"]
    )

    public func sizes(for category: ImageCategory) -> [String] {
        switch category {
        case .poster: posterSizes
        case .backdrop: backdropSizes
        case .profile: profileSizes
        }
    }

    /// The URL of `path` at the right size for an image rendered `pixelWidth`
    /// pixels wide. Returns `nil` when TMDB has no image (`nil` or empty path).
    public func url(for path: String?, category: ImageCategory, pixelWidth: CGFloat) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let size = ImageSizeSelector.size(from: sizes(for: category), pixelWidth: pixelWidth)
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return secureBaseURL.appendingPathComponent(size).appendingPathComponent(relative)
    }
}
