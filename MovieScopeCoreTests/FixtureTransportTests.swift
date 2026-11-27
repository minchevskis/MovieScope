import Foundation
@testable import MovieScopeCore
import XCTest

final class FixtureTransportTests: XCTestCase {
    private let sut = FixtureTransport(bundle: FixtureLoader.bundle)

    func test_trendingPage2_returnsPage2Fixture() async throws {
        let (data, response) = try await sut.data(for: request("https://api.themoviedb.org/3/trending/movie/week?page=2"))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(data, try FixtureLoader.data("trending_movie_week_p2"))
    }

    func test_trendingPageBeyondFixtures_returns404() async throws {
        let (_, response) = try await sut.data(for: request("https://api.themoviedb.org/3/trending/movie/week?page=3"))

        XCTAssertEqual(response.statusCode, 404)
    }

    func test_routesSearchDetailsAndConfiguration() async throws {
        let routes = [
            "https://api.themoviedb.org/3/search/movie?query=x": "search_movie",
            "https://api.themoviedb.org/3/search/tv?query=x": "search_tv",
            "https://api.themoviedb.org/3/movie/42?append_to_response=credits,reviews": "movie_details",
            "https://api.themoviedb.org/3/tv/7": "tv_details",
            "https://api.themoviedb.org/3/configuration": "configuration"
        ]
        for (url, fixture) in routes {
            let (data, response) = try await sut.data(for: request(url))
            XCTAssertEqual(response.statusCode, 200, url)
            XCTAssertEqual(data, try FixtureLoader.data(fixture), url)
        }
    }

    func test_unknownPath_returns404() async throws {
        let (_, response) = try await sut.data(for: request("https://api.themoviedb.org/3/person/1"))

        XCTAssertEqual(response.statusCode, 404)
    }

    func test_imageHost_returnsDecodablePNG() async throws {
        let (data, response) = try await sut.data(for: request("https://image.tmdb.org/t/p/w342/abc.jpg"))

        XCTAssertEqual(response.statusCode, 200)
        let image = try ImageDownsampler.downsample(data, maxPixelSize: 100)
        XCTAssertEqual(image.height, 100)
    }

    func test_sameImagePath_isDeterministic() async throws {
        let first = try await sut.data(for: request("https://image.tmdb.org/t/p/w342/abc.jpg")).0
        let second = try await sut.data(for: request("https://image.tmdb.org/t/p/w92/abc.jpg")).0

        XCTAssertEqual(first, second)
    }

    private func request(_ string: String) throws -> URLRequest {
        URLRequest(url: try XCTUnwrap(URL(string: string)))
    }

    func test_failingOncePath_failsFirstRequestThenSucceeds() async throws {
        let sut = FixtureTransport(bundle: FixtureLoader.bundle, failingOnce: ["/3/trending/movie/week?page=2"])
        let request = try request("https://api.themoviedb.org/3/trending/movie/week?page=2&language=en-US")

        let first = try await sut.data(for: request).1.statusCode
        let second = try await sut.data(for: request).1.statusCode

        XCTAssertEqual(first, 503)
        XCTAssertEqual(second, 200)
    }
}
