import Foundation
import MovieScopeCore
import Observation

/// Search for movies or TV shows. The kind is chosen up front with a scope.
///
/// Typing is throttled (see `Throttler`): the first query fires immediately,
/// then at most one search per `throttleInterval`, always ending with the
/// latest text. Each new search replaces the previous one; `PaginationController`
/// cancels the old request and drops its late responses (first page or next page).
@MainActor
@Observable
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results
        case empty
        case failed(String)
    }

    static let minimumQueryLength = 2

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            throttler?.send(query)
        }
    }

    var scope: MediaKind = .movie {
        didSet {
            guard scope != oldValue else { return }
            // A scope change is a deliberate choice: search right away.
            throttler?.cancel()
            search(query)
        }
    }

    private(set) var activeQuery: String?

    @ObservationIgnored private let service: any TMDBService
    @ObservationIgnored private let pagination: PaginationController<MediaSummary>
    @ObservationIgnored private var throttler: Throttler<String>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(
        service: any TMDBService,
        throttleInterval: Duration = .milliseconds(400),
        sleeper: any Sleeper = TaskSleeper()
    ) {
        self.service = service
        pagination = PaginationController { _ in Page(page: 1, totalPages: 0, items: []) }
        throttler = Throttler(interval: throttleInterval, sleeper: sleeper) { [weak self] text in
            self?.search(text)
        }
    }

    var items: [MediaSummary] { pagination.items }

    var state: State {
        guard activeQuery != nil else { return .idle }
        switch pagination.phase {
        case .idle, .loadingFirstPage:
            return .loading
        case let .failed(error) where pagination.items.isEmpty:
            return .failed(error.userMessage)
        case .loaded, .exhausted, .loadingNextPage, .failed:
            return pagination.items.isEmpty ? .empty : .results
        }
    }

    func itemDisplayed(at index: Int) async {
        guard index >= items.count - TrendingViewModel.nextPageThreshold else { return }
        await pagination.loadNextPage()
    }

    func retry() async {
        await pagination.retry()
    }

    /// Starts a new search (or clears results for a too-short query).
    private func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        guard trimmed.count >= Self.minimumQueryLength else {
            activeQuery = nil
            pagination.reset { _ in Page(page: 1, totalPages: 0, items: []) }
            return
        }
        activeQuery = trimmed
        let kind = scope
        let service = service
        pagination.reset { page in
            try await service.search(kind, query: trimmed, page: page)
        }
        searchTask = Task { await pagination.loadFirstPage() }
    }
}
