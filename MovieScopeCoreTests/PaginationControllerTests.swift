@testable import MovieScopeCore
import Observation
import XCTest

@MainActor
final class PaginationControllerTests: XCTestCase {
    func test_loadFirstPage_appliesItemsAndPhase() async {
        let fetcher = ControlledFetcher()
        let sut = makeSUT(fetcher)

        async let load: Void = sut.loadFirstPage()
        await fetcher.waitForRequests(1)
        XCTAssertEqual(sut.phase, .loadingFirstPage)
        await fetcher.resolve(1, with: .success(testPage(1, of: 2, ids: [1, 2])))
        await load

        XCTAssertEqual(sut.items.map(\.id), [1, 2])
        XCTAssertEqual(sut.phase, .loaded)
    }

    func test_loadNextPage_concurrentCalls_fetchOnce() async {
        let fetcher = ControlledFetcher()
        let sut = await loadedSUT(fetcher, firstPage: testPage(1, of: 3, ids: [1]))

        async let first: Void = sut.loadNextPage()
        async let second: Void = sut.loadNextPage()
        await fetcher.waitForRequests(2)
        await fetcher.resolve(2, with: .success(testPage(2, of: 3, ids: [2])))
        _ = await (first, second)

        let pages = await fetcher.requestedPages
        XCTAssertEqual(pages, [1, 2])
        XCTAssertEqual(sut.items.map(\.id), [1, 2])
    }

    func test_failure_thenRetry_requestsSamePage() async {
        let fetcher = ControlledFetcher()
        let sut = await loadedSUT(fetcher, firstPage: testPage(1, of: 3, ids: [1]))

        async let failing: Void = sut.loadNextPage()
        await fetcher.waitForRequests(2)
        await fetcher.resolve(2, with: .failure(APIError.transport(.timedOut)))
        await failing
        XCTAssertEqual(sut.phase, .failed(.transport(.timedOut)))

        async let retry: Void = sut.retry()
        await fetcher.waitForRequests(3)
        await fetcher.resolve(2, with: .success(testPage(2, of: 3, ids: [2])))
        await retry

        let pages = await fetcher.requestedPages
        XCTAssertEqual(pages, [1, 2, 2])
        XCTAssertEqual(sut.phase, .loaded)
        XCTAssertEqual(sut.items.map(\.id), [1, 2])
    }

    func test_loadNextPage_afterFailure_doesNotFetchUntilRetry() async {
        let fetcher = ControlledFetcher()
        let sut = await loadedSUT(fetcher, firstPage: testPage(1, of: 3, ids: [1]))
        async let failing: Void = sut.loadNextPage()
        await fetcher.waitForRequests(2)
        await fetcher.resolve(2, with: .failure(APIError.server(status: 500)))
        await failing

        await sut.loadNextPage()

        let pages = await fetcher.requestedPages
        XCTAssertEqual(pages, [1, 2], "Scrolling must not hammer a failing endpoint")
    }

    func test_reset_cancelsInFlight_andDropsItsResult() async {
        let fetcher = ControlledFetcher()
        let sut = makeSUT(fetcher)
        async let staleLoad: Void = sut.loadFirstPage()
        await fetcher.waitForRequests(1)

        sut.reset { page in try await fetcher.fetch(page) }
        let staleApplied = expectation(description: "stale page applied")
        staleApplied.isInverted = true
        withObservationTracking { _ = sut.items } onChange: { staleApplied.fulfill() }
        await fetcher.resolve(1, with: .success(testPage(1, of: 1, ids: [99])))
        await staleLoad

        await fulfillment(of: [staleApplied], timeout: 0.3)
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_exhausted_loadNextPage_doesNotFetch() async {
        let fetcher = ControlledFetcher()
        let sut = await loadedSUT(fetcher, firstPage: testPage(1, of: 1, ids: [1]))
        XCTAssertEqual(sut.phase, .exhausted)

        await sut.loadNextPage()

        let pages = await fetcher.requestedPages
        XCTAssertEqual(pages, [1])
    }

    func test_loadNextPage_beforeFirstPage_doesNotFetch() async {
        let fetcher = ControlledFetcher()
        let sut = makeSUT(fetcher)

        await sut.loadNextPage()

        let pages = await fetcher.requestedPages
        XCTAssertTrue(pages.isEmpty)
    }

    func test_refresh_replacesItems() async {
        let fetcher = ControlledFetcher()
        let sut = await loadedSUT(fetcher, firstPage: testPage(1, of: 2, ids: [1, 2]))

        async let refresh: Void = sut.refresh()
        await fetcher.waitForRequests(2)
        XCTAssertEqual(sut.items.map(\.id), [1, 2], "Old items stay visible while refreshing")
        await fetcher.resolve(1, with: .success(testPage(1, of: 2, ids: [5, 6])))
        await refresh

        XCTAssertEqual(sut.items.map(\.id), [5, 6])
        XCTAssertEqual(sut.phase, .loaded)
    }

    func test_nonAPIError_mapsToUnknownTransportFailure() async {
        struct Boom: Error {}
        let fetcher = ControlledFetcher()
        let sut = makeSUT(fetcher)

        async let load: Void = sut.loadFirstPage()
        await fetcher.waitForRequests(1)
        await fetcher.resolve(1, with: .failure(Boom()))
        await load

        XCTAssertEqual(sut.phase, .failed(.transport(.unknown)))
    }

    // MARK: - Helpers

    private func makeSUT(_ fetcher: ControlledFetcher) -> PaginationController<TestItem> {
        PaginationController { page in try await fetcher.fetch(page) }
    }

    private func loadedSUT(_ fetcher: ControlledFetcher, firstPage: Page<TestItem>) async -> PaginationController<TestItem> {
        let sut = makeSUT(fetcher)
        async let load: Void = sut.loadFirstPage()
        await fetcher.waitForRequests(1)
        await fetcher.resolve(1, with: .success(firstPage))
        await load
        return sut
    }
}
