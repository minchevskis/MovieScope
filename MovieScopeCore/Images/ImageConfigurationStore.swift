import Foundation

/// Provides the current `ImageConfiguration`, fetching `/configuration` at most
/// once per `maxAge` (default 7 days; TMDB documents no refresh interval).
///
/// Lookup order: fresh copy in memory or on disk → network fetch (persisted) →
/// stale copy → built-in `ImageConfiguration.fallback`. It never throws:
/// images must still load when the configuration endpoint is unreachable.
public actor ImageConfigurationStore {
    private struct Stored: Codable {
        let configuration: ImageConfiguration
        let fetchedAt: Date
    }

    private let service: any TMDBService
    private let fileURL: URL
    private let maxAge: TimeInterval
    private let now: @Sendable () -> Date

    private var cached: Stored?
    private var didLoadFromDisk = false
    private var inFlight: Task<ImageConfiguration, Never>?

    public init(
        service: any TMDBService,
        fileURL: URL,
        maxAge: TimeInterval = 7 * 24 * 3600,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.fileURL = fileURL
        self.maxAge = maxAge
        self.now = now
    }

    public func current() async -> ImageConfiguration {
        loadFromDiskIfNeeded()
        if let cached, now().timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached.configuration
        }
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await refresh() }
        inFlight = task
        let configuration = await task.value
        inFlight = nil
        return configuration
    }

    private func refresh() async -> ImageConfiguration {
        do {
            let configuration = try await service.imageConfiguration()
            let stored = Stored(configuration: configuration, fetchedAt: now())
            cached = stored
            do {
                try Self.persist(stored.configuration, fetchedAt: stored.fetchedAt, to: fileURL)
            } catch {
                Log.storage.error("Couldn't persist image configuration: \(error.localizedDescription)")
            }
            return configuration
        } catch {
            Log.network.error("Image configuration fetch failed: \(String(describing: error))")
            return cached?.configuration ?? .fallback
        }
    }

    private func loadFromDiskIfNeeded() {
        guard !didLoadFromDisk else { return }
        didLoadFromDisk = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        cached = try? JSONDecoder().decode(Stored.self, from: data)
    }

    static func persist(_ configuration: ImageConfiguration, fetchedAt: Date, to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(Stored(configuration: configuration, fetchedAt: fetchedAt))
        try data.write(to: fileURL, options: .atomic)
    }
}
