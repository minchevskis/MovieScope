@testable import MovieScope
import MovieScopeCore
import UIKit
import XCTest

@MainActor
final class TrendingViewControllerTests: XCTestCase {
    func test_refreshWithSameTitles_newContentIsUsed() {
        let sut = TrendingViewController(imageProvider: Self.offlineImageProvider())
        sut.loadViewIfNeeded()
        let original = (0..<3).map { MediaSummary.stub($0) }
        sut.update(items: original, phase: .loaded, favorites: [])

        // Pull to refresh returns the same titles, one with a new rating.
        var refreshed = original
        refreshed[0] = MediaSummary.stub(0).rated(8.9, votes: 4_000)
        sut.update(items: refreshed, phase: .loaded, favorites: [])

        var selected: MediaSummary?
        sut.onSelect = { selected = $0 }
        sut.collectionView(UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()),
                           didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(selected?.voteAverage, 8.9)
    }

    private static func offlineImageProvider() -> ImageProvider {
        ImageProvider(
            pipeline: ImagePipeline(transport: OfflineTransport()),
            configurationStore: ImageConfigurationStore(
                service: FakeTMDBService(),
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
            )
        )
    }
}

private struct OfflineTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

extension MediaSummary {
    func rated(_ voteAverage: Double, votes: Int) -> MediaSummary {
        MediaSummary(
            id: id, title: title, overview: overview, posterPath: posterPath, backdropPath: backdropPath,
            voteAverage: voteAverage, voteCount: votes, releaseDate: releaseDate
        )
    }
}
