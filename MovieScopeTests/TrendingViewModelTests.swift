@testable import MovieScope
import MovieScopeCore
import XCTest

@MainActor
final class TrendingViewModelTests: XCTestCase {
    func test_onAppear_loadsFirstPageOnce() async {
        let service = FakeTMDBService()
        await service.setTrending(page: 1, .success(stubPage(1, of: 3, ids: 0..<20)))
        let sut = TrendingViewModel(service: service)

        await sut.onAppear()
        await sut.onAppear()

        let calls = await service.trendingCalls
        XCTAssertEqual(calls, [1])
        XCTAssertEqual(sut.items.count, 20)
        XCTAssertEqual(sut.phase, .loaded)
    }

    func test_itemDisplayed_nearEnd_loadsNextPage() async {
        let sut = await loadedSUT()

        await sut.itemDisplayed(at: 14)

        let calls = await service.trendingCalls
        XCTAssertEqual(calls, [1, 2])
        XCTAssertEqual(sut.items.count, 40)
    }

    func test_itemDisplayed_farFromEnd_doesNotLoad() async {
        let sut = await loadedSUT()

        await sut.itemDisplayed(at: 13)

        let calls = await service.trendingCalls
        XCTAssertEqual(calls, [1])
    }

    func test_unauthorized_showsTokenMessage_andDoesNotRetryAutomatically() async {
        let service = FakeTMDBService()
        await service.setTrending(page: 1, .failure(APIError.unauthorized))
        let sut = TrendingViewModel(service: service)

        await sut.onAppear()
        await sut.itemDisplayed(at: 0)

        XCTAssertEqual(sut.errorMessage, "Your TMDB token was rejected. Check Config/Secrets.xcconfig.")
        let calls = await service.trendingCalls
        XCTAssertEqual(calls, [1])
    }

    func test_retry_afterFailure_loadsAgain() async {
        let service = FakeTMDBService()
        await service.setTrending(page: 1, .failure(APIError.transport(.timedOut)))
        let sut = TrendingViewModel(service: service)
        await sut.onAppear()

        await service.setTrending(page: 1, .success(stubPage(1, of: 1, ids: 0..<3)))
        await sut.retry()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.items.map(\.id.id), [0, 1, 2])
    }

    func test_refresh_replacesItems() async {
        let sut = await loadedSUT()
        await service.setTrending(page: 1, .success(stubPage(1, of: 1, ids: 100..<102)))

        await sut.refresh()

        XCTAssertEqual(sut.items.map(\.id.id), [100, 101])
        XCTAssertEqual(sut.phase, .exhausted)
    }

    // MARK: - Helpers

    private let service = FakeTMDBService()

    private func loadedSUT() async -> TrendingViewModel {
        await service.setTrending(page: 1, .success(stubPage(1, of: 3, ids: 0..<20)))
        await service.setTrending(page: 2, .success(stubPage(2, of: 3, ids: 20..<40)))
        let sut = TrendingViewModel(service: service)
        await sut.onAppear()
        return sut
    }
}

@MainActor
final class TrendingLayoutTests: XCTestCase {
    func test_columnCount_iPhonePortrait_is2() {
        XCTAssertEqual(TrendingLayout.columnCount(containerWidth: 393), 2)
    }

    func test_columnCount_iPadPortrait_is4() {
        XCTAssertEqual(TrendingLayout.columnCount(containerWidth: 820), 4)
    }

    func test_columnCount_iPadLandscape_isAtLeast5() {
        XCTAssertGreaterThanOrEqual(TrendingLayout.columnCount(containerWidth: 1366), 5)
    }

    func test_columnCount_neverBelowOne() {
        XCTAssertEqual(TrendingLayout.columnCount(containerWidth: 100), 1)
        XCTAssertEqual(TrendingLayout.columnCount(containerWidth: 0), 1)
    }

    func test_gridItemWidth_splitsAvailableWidthBetweenColumns() {
        // 393 - 2 × 16 insets = 361; minus one 12 pt gap = 349; two columns → 174.5
        XCTAssertEqual(TrendingLayout.gridItemWidth(containerWidth: 393), 174.5, accuracy: 0.01)
    }
}

@MainActor
final class TrendingSnapshotBuilderTests: XCTestCase {
    func test_snapshot_splitsFeaturedAndGrid_withUniqueIDs() {
        let items = (0..<12).map { MediaSummary.stub($0) }

        let snapshot = TrendingSnapshotBuilder.snapshot(for: items)

        XCTAssertEqual(snapshot.sectionIdentifiers, [.featured, .grid])
        XCTAssertEqual(snapshot.numberOfItems(inSection: .featured), 5)
        XCTAssertEqual(snapshot.numberOfItems(inSection: .grid), 7)
        XCTAssertEqual(Set(snapshot.itemIdentifiers).count, 12)
    }

    func test_snapshot_fewerItemsThanFeatured_omitsGrid() {
        let snapshot = TrendingSnapshotBuilder.snapshot(for: (0..<3).map { MediaSummary.stub($0) })

        XCTAssertEqual(snapshot.sectionIdentifiers, [.featured])
        XCTAssertEqual(snapshot.numberOfItems, 3)
    }

    func test_snapshot_noItems_hasNoSections() {
        XCTAssertTrue(TrendingSnapshotBuilder.snapshot(for: []).sectionIdentifiers.isEmpty)
    }

    func test_snapshot_sameIDDifferentKind_areDistinct() {
        let items = [MediaSummary.stub(1, kind: .movie), MediaSummary.stub(1, kind: .tv)]

        XCTAssertEqual(Set(TrendingSnapshotBuilder.snapshot(for: items).itemIdentifiers).count, 2)
    }
}
