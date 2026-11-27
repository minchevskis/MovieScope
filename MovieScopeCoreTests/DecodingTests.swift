@testable import MovieScopeCore
import XCTest

/// Every captured TMDB fixture must decode into its DTO.
final class DecodingTests: XCTestCase {
    func test_decode_trendingPage1_hasResultsAndTotalPages() throws {
        let page = try FixtureLoader.decode(PageDTO<MediaListItemDTO>.self, from: "trending_movie_week_p1")

        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.totalPages, 2)
        XCTAssertEqual(page.results.count, 8)
        XCTAssertEqual(page.results.first?.id, 1_003_596)
    }

    func test_decode_trendingPage2_isSecondPage() throws {
        let page = try FixtureLoader.decode(PageDTO<MediaListItemDTO>.self, from: "trending_movie_week_p2")

        XCTAssertEqual(page.page, 2)
        XCTAssertFalse(page.results.isEmpty)
    }

    func test_decode_searchMovieAndTV() throws {
        let movies = try FixtureLoader.decode(PageDTO<MediaListItemDTO>.self, from: "search_movie")
        let shows = try FixtureLoader.decode(PageDTO<MediaListItemDTO>.self, from: "search_tv")

        XCTAssertNotNil(movies.results.first?.title)
        XCTAssertNotNil(shows.results.first?.name)
        XCTAssertEqual(shows.results.first?.id, 1396)
    }

    func test_decode_movieDetails_includesCreditsAndReviews() throws {
        let details = try FixtureLoader.decode(MovieDetailsDTO.self, from: "movie_details")

        XCTAssertEqual(details.id, 1_003_596)
        XCTAssertFalse(details.credits?.cast.isEmpty ?? true)
        XCTAssertTrue(details.credits?.crew.contains { $0.job == "Director" } ?? false)
        XCTAssertNotNil(details.reviews)
    }

    func test_decode_tvDetails_includesCreatedBy() throws {
        let details = try FixtureLoader.decode(TVDetailsDTO.self, from: "tv_details")

        XCTAssertEqual(details.createdBy?.first?.name, "Vince Gilligan")
        XCTAssertEqual(details.reviews?.results.count, 5)
        XCTAssertEqual(details.networks?.first?.name, "AMC")
    }

    func test_decode_configuration_hasImageSizes() throws {
        let configuration = try FixtureLoader.decode(ConfigurationDTO.self, from: "configuration")

        XCTAssertEqual(configuration.images.secureBaseUrl, "https://image.tmdb.org/t/p/")
        XCTAssertTrue(configuration.images.posterSizes.contains("w342"))
        XCTAssertTrue(configuration.images.profileSizes.contains("h632"))
    }
}
