@testable import MovieScope
import MovieScopeCore
import UIKit
import XCTest

/// Cards show a symbol where artwork is missing or still loading, behind the
/// artwork so a loaded image covers it.
@MainActor
final class MediaCellTests: XCTestCase {
    func test_featuredCell_hasPlaceholderBehindArtwork() throws {
        try assertPlaceholderBehindArtwork(in: FeaturedCell(frame: CGRect(x: 0, y: 0, width: 340, height: 190)))
    }

    func test_gridCell_hasPlaceholderBehindArtwork() throws {
        try assertPlaceholderBehindArtwork(in: MediaGridCell(frame: CGRect(x: 0, y: 0, width: 170, height: 340)))
    }

    /// The brief: every entity shows a title, an image and a short description.
    func test_featuredCell_showsShortDescription() {
        let cell = FeaturedCell(frame: CGRect(x: 0, y: 0, width: 340, height: 220))

        cell.configure(with: .stub(0), isFavorite: false, imageProvider: Self.offlineImageProvider())

        let texts = descendants(of: cell.contentView).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(texts.contains("Overview 0"), "Labels shown: \(texts)")
    }

    func test_featuredCell_withoutOverview_saysSo() {
        let cell = FeaturedCell(frame: CGRect(x: 0, y: 0, width: 340, height: 220))
        let summary = MediaSummary.stub(0)
        let blank = MediaSummary(
            id: summary.id, title: summary.title, overview: "", posterPath: nil, backdropPath: nil,
            voteAverage: 0, voteCount: 0, releaseDate: nil
        )

        cell.configure(with: blank, isFavorite: false, imageProvider: Self.offlineImageProvider())

        let texts = descendants(of: cell.contentView).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(texts.contains("No description available."), "Labels shown: \(texts)")
    }

    private static func offlineImageProvider() -> ImageProvider {
        ImageProvider(
            pipeline: ImagePipeline(transport: NoNetworkTransport()),
            configurationStore: ImageConfigurationStore(
                service: FakeTMDBService(),
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
            )
        )
    }

    private func assertPlaceholderBehindArtwork(
        in cell: UICollectionViewCell,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let placeholders = descendants(of: cell.contentView).compactMap { $0 as? ArtworkPlaceholderView }
        XCTAssertEqual(placeholders.count, 1, file: file, line: line)
        let placeholder = try XCTUnwrap(placeholders.first, file: file, line: line)
        let siblings = try XCTUnwrap(placeholder.superview, file: file, line: line).subviews
        let artworkIndex = try XCTUnwrap(siblings.firstIndex { $0 is SizeReportingImageView }, file: file, line: line)
        let placeholderIndex = try XCTUnwrap(siblings.firstIndex(of: placeholder), file: file, line: line)
        XCTAssertLessThan(placeholderIndex, artworkIndex, "The placeholder sits behind the artwork", file: file, line: line)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}

private struct NoNetworkTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}
