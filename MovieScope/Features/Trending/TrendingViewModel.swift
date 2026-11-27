import MovieScopeCore
import Observation

/// State and actions for the Trending screen: weekly trending movies with
/// infinite scrolling.
@MainActor
@Observable
final class TrendingViewModel {
    /// Load the next page when an item this close to the end is displayed.
    static let nextPageThreshold = 6

    private let pagination: PaginationController<MediaSummary>

    init(service: any TMDBService) {
        pagination = PaginationController { page in
            try await service.trendingMovies(page: page)
        }
    }

    var items: [MediaSummary] { pagination.items }
    var phase: LoadPhase { pagination.phase }

    var errorMessage: String? {
        guard case let .failed(error) = phase else { return nil }
        return error.userMessage
    }

    func onAppear() async {
        await pagination.loadFirstPage()
    }

    func itemDisplayed(at index: Int) async {
        guard index >= items.count - Self.nextPageThreshold else { return }
        await pagination.loadNextPage()
    }

    func refresh() async {
        await pagination.refresh()
    }

    func retry() async {
        await pagination.retry()
    }
}
