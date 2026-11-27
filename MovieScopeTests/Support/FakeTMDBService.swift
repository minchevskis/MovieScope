import Foundation
import MovieScopeCore
import XCTest

/// A scriptable `TMDBService` for view-model tests.
///
/// Responses are immediate by default. With `holdsResponses` on, each call
/// suspends until the test releases it, so ordering and staleness can be tested.
actor FakeTMDBService: TMDBService {
    struct SearchCall: Equatable, Sendable {
        let kind: MediaKind
        let query: String
        let page: Int
    }

    private var trendingResults: [Int: Result<Page<MediaSummary>, any Error>] = [:]
    private var searchResults: [String: Result<Page<MediaSummary>, any Error>] = [:]
    private var detailsResults: [MediaID: Result<MediaDetails, any Error>] = [:]
    private var held: [String: CheckedContinuation<Void, Never>] = [:]

    private(set) var trendingCalls: [Int] = []
    private(set) var searchCalls: [SearchCall] = []
    private(set) var detailsCalls: [MediaID] = []
    var holdsResponses = false

    func setHoldsResponses(_ value: Bool) { holdsResponses = value }

    func setTrending(page: Int, _ result: Result<Page<MediaSummary>, any Error>) {
        trendingResults[page] = result
    }

    /// Result for any search whose kind, query and page match.
    func setSearch(_ kind: MediaKind, query: String, page: Int = 1, _ result: Result<Page<MediaSummary>, any Error>) {
        searchResults[Self.key(kind, query, page)] = result
    }

    func setDetails(_ id: MediaID, _ result: Result<MediaDetails, any Error>) {
        detailsResults[id] = result
    }

    /// Lets a held search response through.
    func releaseSearch(_ kind: MediaKind, query: String, page: Int = 1) {
        held.removeValue(forKey: Self.key(kind, query, page))?.resume()
    }

    func waitForSearchCalls(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while searchCalls.count < count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Expected \(count) search calls, saw \(searchCalls.count)", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }

    // MARK: - TMDBService

    func trendingMovies(page: Int) async throws -> Page<MediaSummary> {
        trendingCalls.append(page)
        return try (trendingResults[page] ?? .failure(APIError.notFound)).get()
    }

    func search(_ kind: MediaKind, query: String, page: Int) async throws -> Page<MediaSummary> {
        searchCalls.append(SearchCall(kind: kind, query: query, page: page))
        let key = Self.key(kind, query, page)
        if holdsResponses {
            await withCheckedContinuation { held[key] = $0 }
        }
        // Deliberately ignores cancellation: a stale response still arrives, so
        // tests prove the generation guard drops it (not just Task cancellation).
        return try (searchResults[key] ?? .success(Page(page: page, totalPages: 1, items: []))).get()
    }

    func details(for id: MediaID) async throws -> MediaDetails {
        detailsCalls.append(id)
        return try (detailsResults[id] ?? .failure(APIError.notFound)).get()
    }

    func imageConfiguration() async throws -> ImageConfiguration { .fallback }

    private static func key(_ kind: MediaKind, _ query: String, _ page: Int) -> String {
        "\(kind.rawValue)|\(query)|\(page)"
    }
}

extension MediaSummary {
    static func stub(_ id: Int, kind: MediaKind = .movie, title: String? = nil) -> MediaSummary {
        MediaSummary(
            id: MediaID(kind: kind, id: id),
            title: title ?? "Title \(id)",
            overview: "Overview \(id)",
            posterPath: "/poster\(id).jpg",
            backdropPath: "/backdrop\(id).jpg",
            voteAverage: 7.5,
            voteCount: 100,
            releaseDate: nil
        )
    }
}

func stubPage(_ number: Int, of total: Int, ids: Range<Int>, kind: MediaKind = .movie) -> Page<MediaSummary> {
    Page(page: number, totalPages: total, items: ids.map { MediaSummary.stub($0, kind: kind) })
}
