import Foundation

/// Live transport built on `URLSession`'s async API. Cancelling the calling task
/// cancels the underlying data task.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }
}

extension URLSession {
    /// Session for image downloads with its own `URLCache` (20 MB memory, 200 MB disk).
    /// TMDB's image CDN sends long-lived `Cache-Control` headers, so this cache
    /// serves repeat images without hitting the network.
    public static let images: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("ImageCache", isDirectory: true)
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }()
}
