import Observation

/// Where a paginated list currently stands.
public enum LoadPhase: Equatable, Sendable {
    case idle
    case loadingFirstPage
    case loadingNextPage
    case loaded
    case exhausted
    case failed(APIError)

    public var isLoading: Bool {
        self == .loadingFirstPage || self == .loadingNextPage
    }
}

/// Drives infinite scrolling for any paginated source: it requests pages,
/// merges them via `PaginatedCollection`, and exposes observable state for the UI.
///
/// Guarantees:
/// - at most one request in flight (repeated `loadNextPage()` calls are ignored)
/// - a failed page is only requested again through `retry()`, never by scrolling
/// - `reset(fetch:)` and `refresh()` cancel the in-flight request and drop its
///   result, so a stale response can never land in a newer list
@MainActor
@Observable
public final class PaginationController<Item: Identifiable & Sendable> where Item.ID: Sendable {
    public typealias Fetch = @Sendable (Int) async throws -> Page<Item>

    public private(set) var items: [Item] = []
    public private(set) var phase: LoadPhase = .idle

    @ObservationIgnored private var collection = PaginatedCollection<Item>()
    @ObservationIgnored private var fetch: Fetch
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var failedPage: Int?

    public init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    /// Loads page 1 if nothing is loaded yet (or the first load failed).
    public func loadFirstPage() async {
        guard items.isEmpty, phase == .idle || isFailed else { return }
        await load(page: 1, replacingItems: false)
    }

    /// Loads the next page when the list is idle and has more to load.
    public func loadNextPage() async {
        guard !items.isEmpty, phase == .loaded, let next = collection.nextPage else { return }
        await load(page: next, replacingItems: false)
    }

    /// Repeats the request that failed.
    public func retry() async {
        guard isFailed, let page = failedPage else { return }
        await load(page: page, replacingItems: false)
    }

    /// Reloads from page 1. Current items stay visible until the new page arrives.
    public func refresh() async {
        cancelInFlight()
        await load(page: 1, replacingItems: true)
    }

    /// Starts over with a different source (e.g. a new search query).
    /// Doesn't load anything by itself.
    public func reset(fetch: @escaping Fetch) {
        cancelInFlight()
        self.fetch = fetch
        collection.reset()
        items = []
        phase = .idle
        failedPage = nil
    }

    // MARK: - Private

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func cancelInFlight() {
        generation += 1
        inFlight?.cancel()
        inFlight = nil
    }

    private func load(page: Int, replacingItems: Bool) async {
        let generation = generation
        let fetch = fetch
        phase = items.isEmpty || replacingItems ? .loadingFirstPage : .loadingNextPage
        let task = Task {
            do {
                let result = try await fetch(page)
                apply(result, generation: generation, replacingItems: replacingItems)
            } catch {
                fail(with: APIError(error), page: page, generation: generation)
            }
        }
        inFlight = task
        await task.value
    }

    private func apply(_ page: Page<Item>, generation: Int, replacingItems: Bool) {
        guard generation == self.generation else { return }
        if replacingItems { collection.reset() }
        collection.append(page)
        items = collection.items
        phase = collection.canLoadMore ? .loaded : .exhausted
        failedPage = nil
        inFlight = nil
    }

    private func fail(with error: APIError, page: Int, generation: Int) {
        guard generation == self.generation, error != .cancelled else { return }
        phase = .failed(error)
        failedPage = page
        inFlight = nil
    }
}
