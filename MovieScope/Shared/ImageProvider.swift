import MovieScopeCore
import SwiftUI
import UIKit

/// App-side front for the image pipeline: turns "this TMDB path at this
/// on-screen size" into the right sized request and a `UIImage`.
@MainActor
final class ImageProvider {
    private let pipeline: ImagePipeline
    private let configurationStore: ImageConfigurationStore
    /// The latest prefetch or cancel. Each one waits for the one before it.
    private var lastPrefetchChange: Task<Void, Never>?

    init(pipeline: ImagePipeline, configurationStore: ImageConfigurationStore) {
        self.pipeline = pipeline
        self.configurationStore = configurationStore
    }

    /// Loads `path` sized for a view of `pointSize` points on a `scale`x screen.
    /// Returns `nil` when there is no image to load.
    func image(path: String?, category: ImageCategory, pointSize: CGSize, scale: CGFloat) async throws -> UIImage? {
        guard let request = await request(path: path, category: category, pointSize: pointSize, scale: scale) else {
            return nil
        }
        let image = try await pipeline.image(for: request)
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    /// Any already-decoded variant of `path`, for showing instantly while the
    /// right size loads. Never triggers a download.
    func cachedPreview(path: String?) async -> UIImage? {
        guard let path, !path.isEmpty, let image = await pipeline.largestCachedImage(forImagePath: path) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    func prefetch(paths: [String], category: ImageCategory, pointSize: CGSize, scale: CGFloat) {
        inOrder {
            let requests = await self.requests(paths: paths, category: category, pointSize: pointSize, scale: scale)
            await self.pipeline.prefetch(requests)
        }
    }

    func cancelPrefetch(paths: [String], category: ImageCategory, pointSize: CGSize, scale: CGFloat) {
        inOrder {
            let requests = await self.requests(paths: paths, category: category, pointSize: pointSize, scale: scale)
            await self.pipeline.cancelPrefetch(requests)
        }
    }

    /// Runs prefetch changes one after another, in the order they were made.
    /// Each starts with an async configuration lookup, so separate tasks could
    /// finish out of order, and a cancel that overtook its prefetch would leave
    /// that download running.
    private func inOrder(_ change: @escaping @MainActor () async -> Void) {
        let previous = lastPrefetchChange
        lastPrefetchChange = Task {
            await previous?.value
            await change()
        }
    }

    private func requests(
        paths: [String],
        category: ImageCategory,
        pointSize: CGSize,
        scale: CGFloat
    ) async -> [ImageRequest] {
        var result: [ImageRequest] = []
        for path in paths {
            if let request = await request(path: path, category: category, pointSize: pointSize, scale: scale) {
                result.append(request)
            }
        }
        return result
    }

    private func request(
        path: String?,
        category: ImageCategory,
        pointSize: CGSize,
        scale: CGFloat
    ) async -> ImageRequest? {
        guard pointSize.width > 0, pointSize.height > 0 else { return nil }
        // Aspect-fill: the image must cover the whole view, not just fit its longest side.
        let covering = ImageSizeSelector.coveringSize(for: pointSize, aspectRatio: category.aspectRatio)
        let configuration = await configurationStore.current()
        guard let url = configuration.url(for: path, category: category, pixelWidth: covering.width * scale) else {
            return nil
        }
        let maxPixelSize = Int((max(covering.width, covering.height) * scale).rounded(.up))
        return ImageRequest(url: url, maxPixelSize: maxPixelSize)
    }
}

extension EnvironmentValues {
    @Entry var imageProvider: ImageProvider?
}
