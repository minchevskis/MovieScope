import MovieScopeCore
import SwiftUI
import UIKit

/// App-side front for the image pipeline: turns "this TMDB path at this
/// on-screen size" into the right sized request and a `UIImage`.
@MainActor
final class ImageProvider {
    private let pipeline: ImagePipeline
    private let configurationStore: ImageConfigurationStore

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

    func prefetch(paths: [String], category: ImageCategory, pointSize: CGSize, scale: CGFloat) {
        Task {
            let requests = await requests(paths: paths, category: category, pointSize: pointSize, scale: scale)
            await pipeline.prefetch(requests)
        }
    }

    func cancelPrefetch(paths: [String], category: ImageCategory, pointSize: CGSize, scale: CGFloat) {
        Task {
            let requests = await requests(paths: paths, category: category, pointSize: pointSize, scale: scale)
            await pipeline.cancelPrefetch(requests)
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
        let pixelWidth = pointSize.width * scale
        guard pixelWidth > 0 else { return nil }
        let configuration = await configurationStore.current()
        guard let url = configuration.url(for: path, category: category, pixelWidth: pixelWidth) else { return nil }
        let maxPixelSize = Int((max(pointSize.width, pointSize.height) * scale).rounded(.up))
        return ImageRequest(url: url, maxPixelSize: maxPixelSize)
    }
}

extension EnvironmentValues {
    @Entry var imageProvider: ImageProvider?
}
