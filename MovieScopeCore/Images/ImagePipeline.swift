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
/// - Bounded concurrency: at most `maxConcurrentDownloads` at once (TMDB allows
///   about 40 requests per second). Images on screen go before prefetches, and
///   a queued prefetch that comes on screen moves up the line.
/// - Decoding runs off the actor, so the pipeline never blocks while decoding.
public actor ImagePipeline {
    private struct InFlight {
        let id: UUID
        let task: Task<CGImage, any Error>
        var waiters: Set<UUID>
    }

    private let transport: any HTTPTransport
    private let memoryCache = NSCache<NSString, CGImage>()
    private var inFlight: [ImageRequest: InFlight] = [:]
    private var prefetchWaiters: [ImageRequest: UUID] = [:]
    /// Which downloads may run; keyed by `InFlight.id`.
    private var queue: RequestQueue<UUID>
    /// Downloads waiting for a slot, resumed when `queue` lets them start.
    private var slotWaiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    /// Decoded variants per TMDB file name (e.g. `abc.jpg` at several sizes).
    private var variants = ImageVariantIndex()

    public init(
        transport: any HTTPTransport,
        maxConcurrentDownloads: Int = 6,
        memoryCostLimit: Int = 100 * 1024 * 1024
    ) {
        self.transport = transport
        queue = RequestQueue(maxConcurrent: maxConcurrentDownloads)
        memoryCache.totalCostLimit = memoryCostLimit
    }

    public func image(for request: ImageRequest) async throws -> CGImage {
        if let cached = cachedImage(for: request) { return cached }
        let waiter = UUID()
        let task = join(request, waiter: waiter, priority: .high)
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

    /// The largest variant of an image already in memory, whatever size it was
    /// loaded at. Used as an instant low-resolution preview while the size a
    /// new screen needs is loading (e.g. the grid poster on the details screen).
    public func largestCachedImage(forImagePath path: String) -> CGImage? {
        let cached = variants.cachedVariants(forImagePath: path, isCached: isInMemory)
        // The cache may evict between the check and the read, hence compactMap.
        return cached.lazy.compactMap { self.cachedImage(for: $0) }.first
    }

    /// Whether the memory cache still holds a request's image (it evicts freely).
    private var isInMemory: (ImageRequest) -> Bool {
        let cache = memoryCache
        return { cache.object(forKey: Self.cacheKey(for: $0)) != nil }
    }

    /// Starts downloading images expected to be needed soon (e.g. rows about to
    /// scroll into view). Results land in the memory cache.
    public func prefetch(_ requests: [ImageRequest]) {
        for request in requests where cachedImage(for: request) == nil && prefetchWaiters[request] == nil {
            let waiter = UUID()
            prefetchWaiters[request] = waiter
            _ = join(request, waiter: waiter, priority: .low)
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

    private func join(
        _ request: ImageRequest,
        waiter: UUID,
        priority: RequestQueue<UUID>.Priority
    ) -> Task<CGImage, any Error> {
        if var entry = inFlight[request] {
            entry.waiters.insert(waiter)
            inFlight[request] = entry
            // A prefetch still waiting in line is needed now: move it up.
            if priority == .high { queue.promote(entry.id) }
            return entry.task
        }
        let id = UUID()
        queue.enqueue(id, priority: priority)
        let transport = transport
        let task = Task { @concurrent in
            do {
                try await self.waitForSlot(id)
                let image = try await Self.fetchAndDecode(request, transport: transport)
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

    /// Returns once download `id` may start. Throws if it left the line first.
    private func waitForSlot(_ id: UUID) async throws {
        if queue.isRunning(id) { return }
        guard queue.isQueued(id) else { throw CancellationError() }
        try await withCheckedThrowingContinuation { continuation in
            slotWaiters[id] = continuation
        }
    }

    private func leave(_ request: ImageRequest, waiter: UUID) {
        guard var entry = inFlight[request], entry.waiters.remove(waiter) != nil else { return }
        if entry.waiters.isEmpty {
            entry.task.cancel()
            inFlight[request] = nil
            // A download that hasn't started gives up its place in line.
            queue.remove(entry.id)
            slotWaiters.removeValue(forKey: entry.id)?.resume(throwing: CancellationError())
        } else {
            inFlight[request] = entry
        }
    }

    private func finish(_ request: ImageRequest, id: UUID, image: CGImage?) {
        // Whatever happened to this download, its slot goes to the next one in line.
        if let next = queue.finish(id) {
            slotWaiters.removeValue(forKey: next)?.resume()
        }
        if let image {
            memoryCache.setObject(image, forKey: Self.cacheKey(for: request), cost: image.bytesPerRow * image.height)
            variants.insert(request, isCached: isInMemory)
        }
        // Only the download that is still current may clear the bookkeeping: a
        // cancelled one can finish after a new prefetch of the same image started,
        // and must not orphan that prefetch (it could no longer be cancelled).
        guard let entry = inFlight[request], entry.id == id else { return }
        inFlight[request] = nil
        if let waiter = prefetchWaiters[request], entry.waiters.contains(waiter) {
            prefetchWaiters[request] = nil
        }
    }

    // MARK: - Loading (off the actor)

    private static func fetchAndDecode(_ request: ImageRequest, transport: any HTTPTransport) async throws -> CGImage {
        try Task.checkCancellation()
        let (data, response) = try await transport.data(for: URLRequest(url: request.url))
        switch response.statusCode {
        case 200..<300: break
        case 404: throw APIError.notFound
        default: throw APIError.server(status: response.statusCode)
        }
        try Task.checkCancellation()
        return try ImageDownsampler.downsample(data, maxPixelSize: request.maxPixelSize)
    }

    private static func cacheKey(for request: ImageRequest) -> NSString {
        "\(request.url.absoluteString)#\(request.maxPixelSize)" as NSString
    }
}
