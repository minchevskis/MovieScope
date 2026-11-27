import CoreGraphics
import Foundation

/// Identifies one image at one display size.
public struct ImageRequest: Hashable, Sendable {
    public let url: URL
    public let maxPixelSize: Int

    public init(url: URL, maxPixelSize: Int) {
        self.url = url
        self.maxPixelSize = maxPixelSize
    }
}

/// Loads, downsamples and caches images.
///
/// - Memory cache: decoded, downsampled `CGImage`s in an actor-owned `NSCache`
///   (`NSCache` isn't `Sendable`, so it never leaves the actor).
/// - Disk cache: the transport's `URLSession` / `URLCache`.
/// - De-duplication: concurrent requests for the same image share one download.
/// - Cancellation: the download is cancelled when its last waiter goes away.
/// - Bounded concurrency through `RequestLimiter`.
/// - Decoding runs off the actor, so the pipeline never blocks while decoding.
public actor ImagePipeline {
    private struct InFlight {
        let id: UUID
        let task: Task<CGImage, any Error>
        var waiters: Set<UUID>
    }

    private let transport: any HTTPTransport
    private let limiter: RequestLimiter
    private let memoryCache = NSCache<NSString, CGImage>()
    private var inFlight: [ImageRequest: InFlight] = [:]
    private var prefetchWaiters: [ImageRequest: UUID] = [:]

    public init(
        transport: any HTTPTransport,
        limiter: RequestLimiter = RequestLimiter(maxConcurrent: 6),
        memoryCostLimit: Int = 100 * 1024 * 1024
    ) {
        self.transport = transport
        self.limiter = limiter
        memoryCache.totalCostLimit = memoryCostLimit
    }

    public func image(for request: ImageRequest) async throws -> CGImage {
        if let cached = cachedImage(for: request) { return cached }
        let waiter = UUID()
        let task = join(request, waiter: waiter)
        defer { leave(request, waiter: waiter) }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.leave(request, waiter: waiter) }
        }
    }

    public func cachedImage(for request: ImageRequest) -> CGImage? {
        memoryCache.object(forKey: Self.cacheKey(for: request))
    }

    /// Starts downloading images expected to be needed soon (e.g. rows about to
    /// scroll into view). Results land in the memory cache.
    public func prefetch(_ requests: [ImageRequest]) {
        for request in requests where cachedImage(for: request) == nil && prefetchWaiters[request] == nil {
            let waiter = UUID()
            prefetchWaiters[request] = waiter
            _ = join(request, waiter: waiter)
        }
    }

    /// Cancels prefetches that are no longer needed, unless someone else is
    /// also waiting for the same image.
    public func cancelPrefetch(_ requests: [ImageRequest]) {
        for request in requests {
            guard let waiter = prefetchWaiters.removeValue(forKey: request) else { continue }
            leave(request, waiter: waiter)
        }
    }

    // MARK: - In-flight bookkeeping

    private func join(_ request: ImageRequest, waiter: UUID) -> Task<CGImage, any Error> {
        if var entry = inFlight[request] {
            entry.waiters.insert(waiter)
            inFlight[request] = entry
            return entry.task
        }
        let id = UUID()
        let transport = transport
        let limiter = limiter
        let task = Task { @concurrent in
            do {
                let image = try await Self.fetchAndDecode(request, transport: transport, limiter: limiter)
                await self.finish(request, id: id, image: image)
                return image
            } catch {
                await self.finish(request, id: id, image: nil)
                throw error
            }
        }
        inFlight[request] = InFlight(id: id, task: task, waiters: [waiter])
        return task
    }

    private func leave(_ request: ImageRequest, waiter: UUID) {
        guard var entry = inFlight[request], entry.waiters.remove(waiter) != nil else { return }
        if entry.waiters.isEmpty {
            entry.task.cancel()
            inFlight[request] = nil
        } else {
            inFlight[request] = entry
        }
    }

    private func finish(_ request: ImageRequest, id: UUID, image: CGImage?) {
        if let image {
            memoryCache.setObject(image, forKey: Self.cacheKey(for: request), cost: image.bytesPerRow * image.height)
        }
        if inFlight[request]?.id == id {
            inFlight[request] = nil
        }
        prefetchWaiters[request] = nil
    }

    // MARK: - Loading (off the actor)

    private static func fetchAndDecode(
        _ request: ImageRequest,
        transport: any HTTPTransport,
        limiter: RequestLimiter
    ) async throws -> CGImage {
        let data = try await limiter.run {
            let (data, response) = try await transport.data(for: URLRequest(url: request.url))
            switch response.statusCode {
            case 200..<300: return data
            case 404: throw APIError.notFound
            default: throw APIError.server(status: response.statusCode)
            }
        }
        try Task.checkCancellation()
        return try ImageDownsampler.downsample(data, maxPixelSize: request.maxPixelSize)
    }

    private static func cacheKey(for request: ImageRequest) -> NSString {
        "\(request.url.absoluteString)#\(request.maxPixelSize)" as NSString
    }
}
