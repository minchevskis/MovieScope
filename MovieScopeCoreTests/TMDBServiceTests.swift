import Foundation
@testable import MovieScopeCore
import XCTest

/// `TMDBClient`'s `TMDBService` conformance: which endpoint each call hits and
/// what it maps the response to.
final class TMDBServiceTests: XCTestCase {
    func test_trendingMovies_requestsWeekWindowAndPage() async throws {
        let (sut, transport) = try makeSUT(fixture: "trending_movie_week_p1")

        let page = try await sut.trendingMovies(page: 1)

        let url = try await requestedURL(transport)
        XCTAssertEqual(url.path, "/3/trending/movie/week")
        XCTAssertEqual(url.queryValues["page"], "1")
        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.totalPages, 2)
        XCTAssertEqual(page.items.first?.id, MediaID(kind: .movie, id: 1_003_596))
    }

    func test_searchMovies_hitsSearchMovieWithIncludeAdultFalse() async throws {
        let (sut, transport) = try makeSUT(fixture: "search_movie")

        let page = try await sut.search(.movie, query: "batman", page: 1)

        let url = try await requestedURL(transport)
        XCTAssertEqual(url.path, "/3/search/movie")
        XCTAssertEqual(url.queryValues["query"], "batman")
        XCTAssertEqual(url.queryValues["include_adult"], "false")
        XCTAssertTrue(page.items.allSatisfy { $0.id.kind == .movie })
    }

    func test_searchTV_hitsSearchTVWithIncludeAdultFalse() async throws {
        let (sut, transport) = try makeSUT(fixture: "search_tv")

        let page = try await sut.search(.tv, query: "breaking", page: 3)

        let url = try await requestedURL(transport)
        XCTAssertEqual(url.path, "/3/search/tv")
        XCTAssertEqual(url.queryValues["page"], "3")
        XCTAssertEqual(url.queryValues["include_adult"], "false")
        XCTAssertEqual(page.items.first?.id, MediaID(kind: .tv, id: 1396))
    }

    func test_detailsMovie_appendsCreditsAndReviews() async throws {
        let (sut, transport) = try makeSUT(fixture: "movie_details")

        let details = try await sut.details(for: MediaID(kind: .movie, id: 1_003_596))

        let url = try await requestedURL(transport)
        XCTAssertEqual(url.path, "/3/movie/1003596")
        XCTAssertEqual(url.queryValues["append_to_response"], "credits,reviews")
        XCTAssertEqual(details.summary.title, "Avengers: Doomsday")
        XCTAssertFalse(details.directors.isEmpty)
    }

    func test_detailsTV_returnsCreators() async throws {
        let (sut, transport) = try makeSUT(fixture: "tv_details")

        let details = try await sut.details(for: MediaID(kind: .tv, id: 1396))

        let url = try await requestedURL(transport)
        XCTAssertEqual(url.path, "/3/tv/1396")
        XCTAssertEqual(details.creators.first?.name, "Vince Gilligan")
    }

    func test_imageConfiguration_mapsSizes() async throws {
        let (sut, _) = try makeSUT(fixture: "configuration")

        let configuration = try await sut.imageConfiguration()

        XCTAssertEqual(configuration.secureBaseURL.absoluteString, "https://image.tmdb.org/t/p/")
        XCTAssertEqual(configuration.backdropSizes, ["w300", "w780", "w1280", "original"])
    }

    // MARK: - Helpers

    private func makeSUT(fixture: String) throws -> (TMDBClient, FakeTransport) {
        let transport = FakeTransport([.response(status: 200, body: try FixtureLoader.data(fixture))])
        let client = TMDBClient(transport: transport, credentials: StaticCredentialProvider("token"))
        return (client, transport)
    }

    private func requestedURL(_ transport: FakeTransport) async throws -> URLComponents {
        let requests = await transport.requests
        let url = try XCTUnwrap(requests.first?.url)
        return try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    }
}

private extension URLComponents {
    var queryValues: [String: String] {
        Dictionary((percentEncodedQueryItems ?? []).map {
            ($0.name, $0.value?.removingPercentEncoding ?? "")
        }, uniquingKeysWith: { first, _ in first })
    }
}
