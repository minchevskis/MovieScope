@testable import MovieScopeCore
import XCTest

final class ImageSizeSelectorTests: XCTestCase {
    private let posterSizes = ["w92", "w154", "w185", "w342", "w500", "w780", "original"]

    func test_size_exactMatch() {
        XCTAssertEqual(ImageSizeSelector.size(from: posterSizes, pixelWidth: 342), "w342")
    }

    func test_size_betweenSizes_roundsUp() {
        XCTAssertEqual(ImageSizeSelector.size(from: posterSizes, pixelWidth: 300), "w342")
    }

    func test_size_largerThanAll_usesLargestWidthToken() {
        XCTAssertEqual(ImageSizeSelector.size(from: posterSizes, pixelWidth: 2000), "w780")
    }

    func test_size_ignoresHeightAndOriginalTokens() {
        let profileSizes = ["w45", "w185", "h632", "original"]

        XCTAssertEqual(ImageSizeSelector.size(from: profileSizes, pixelWidth: 40), "w45")
        XCTAssertEqual(ImageSizeSelector.size(from: profileSizes, pixelWidth: 150), "w185")
        XCTAssertEqual(ImageSizeSelector.size(from: profileSizes, pixelWidth: 600), "w185")
    }

    func test_size_noWidthTokens_returnsOriginal() {
        XCTAssertEqual(ImageSizeSelector.size(from: ["original"], pixelWidth: 300), "original")
        XCTAssertEqual(ImageSizeSelector.size(from: [], pixelWidth: 300), "original")
    }

    func test_url_nilOrEmptyPath_isNil() {
        XCTAssertNil(ImageConfiguration.fallback.url(for: nil, category: .poster, pixelWidth: 300))
        XCTAssertNil(ImageConfiguration.fallback.url(for: "", category: .poster, pixelWidth: 300))
    }

    func test_url_buildsBaseSizeAndPath() {
        let url = ImageConfiguration.fallback.url(for: "/abc.jpg", category: .backdrop, pixelWidth: 700)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w780/abc.jpg")
    }

    func test_fallback_matchesLiveConfigurationFixture() throws {
        let live = try FixtureLoader.decode(ConfigurationDTO.self, from: "configuration").toConfiguration()

        XCTAssertEqual(ImageConfiguration.fallback, live)
    }
}
