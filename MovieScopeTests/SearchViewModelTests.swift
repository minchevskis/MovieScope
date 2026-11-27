@testable import MovieScope
import MovieScopeCore
import Observation
import XCTest

@MainActor
final class SearchViewModelTests: XCTestCase {
    private let service = FakeTMDBService()
    private let sleeper = ControlledSleeper()

    func test_typingBurst_searchesFirstThenLatest() async {
        let sut = makeSUT()

        sut.query = "ba"
        sut.query = "bat"
        sut.query = "batm"
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await service.waitForSearchCalls(2)

        let queries = await service.searchCalls.map(\.query)
        XCTAssertEqual(queries, ["ba", "batm"], "'bat' is superseded within the throttle window")
    }

    func test_shortQuery_staysIdle_noRequest() async {
        let sut = makeSUT()

        sut.query = "b"
        await Task.yield()

        XCTAssertEqual(sut.state, .idle)
        let calls = await service.searchCalls
        XCTAssertTrue(calls.isEmpty)
    }

    func test_whitespaceOnlyQuery_staysIdle_noRequest() async {
        let sut = makeSUT()

        sut.query = "   "
        await Task.yield()

        XCTAssertEqual(sut.state, .idle)
        let calls = await service.searchCalls
        XCTAssertTrue(calls.isEmpty)
    }

    func test_query_isTrimmedBeforeSearching() async {
        let sut = makeSUT()

        sut.query = "  dune "
        await service.waitForSearchCalls(1)

        let queries = await service.searchCalls.map(\.query)
        XCTAssertEqual(queries, ["dune"])
    }

    func test_scopeSwitch_searchesImmediatelyWithNewKind() async {
        let sut = makeSUT()
        sut.query = "batman"
        await service.waitForSearchCalls(1)

        sut.scope = .tv
        await service.waitForSearchCalls(2)

        let kinds = await service.searchCalls.map(\.kind)
        XCTAssertEqual(kinds, [.movie, .tv])
    }

    func test_results_areShownWithResultsState() async {
        await service.setSearch(.movie, query: "dune", .success(stubPage(1, of: 1, ids: 0..<3)))
        let sut = makeSUT()

        sut.query = "dune"
        await waitUntil { sut.state == .results }

        XCTAssertEqual(sut.items.map(\.id.id), [0, 1, 2])
    }

    func test_noResults_setsEmpty() async {
        let sut = makeSUT()

        sut.query = "zzzzzz"
        await waitUntil { sut.state == .empty }

        XCTAssertTrue(sut.items.isEmpty)
    }

    func test_failure_setsFailedMessage() async {
        await service.setSearch(.movie, query: "dune", .failure(APIError.unauthorized))
        let sut = makeSUT()

        sut.query = "dune"
        await waitUntil { sut.state != .loading && sut.state != .idle }

        XCTAssertEqual(sut.state, .failed("Your TMDB token was rejected. Check Config/Secrets.xcconfig."))
    }

    func test_staleFirstPage_notApplied() async {
        await service.setHoldsResponses(true)
        await service.setSearch(.movie, query: "batman", .success(stubPage(1, of: 1, ids: 0..<2)))
        await service.setSearch(.movie, query: "superman", .success(stubPage(1, of: 1, ids: 10..<12)))
        let sut = makeSUT()
        sut.query = "batman"
        await service.waitForSearchCalls(1)
        sut.query = "superman"
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await service.waitForSearchCalls(2)
        await service.releaseSearch(.movie, query: "superman")
        await waitUntil { sut.state == .results }

        let staleApplied = expectation(description: "stale batman results applied")
        staleApplied.isInverted = true
        withObservationTracking { _ = sut.items } onChange: { staleApplied.fulfill() }
        await service.releaseSearch(.movie, query: "batman")

        await fulfillment(of: [staleApplied], timeout: 0.3)
        XCTAssertEqual(sut.items.map(\.id.id), [10, 11])
    }

    func test_staleNextPage_notAppended() async {
        await service.setSearch(.movie, query: "batman", .success(stubPage(1, of: 2, ids: 0..<10)))
        await service.setSearch(.movie, query: "batman", page: 2, .success(stubPage(2, of: 2, ids: 10..<20)))
        await service.setSearch(.movie, query: "superman", .success(stubPage(1, of: 1, ids: 50..<52)))
        let sut = makeSUT()
        sut.query = "batman"
        await waitUntil { sut.state == .results }

        await service.setHoldsResponses(true)
        let nextPage = Task { await sut.itemDisplayed(at: 9) }
        await service.waitForSearchCalls(2)
        await service.setHoldsResponses(false)
        sut.query = "superman"
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await waitUntil { sut.items.map(\.id.id) == [50, 51] }
        await service.releaseSearch(.movie, query: "batman", page: 2)
        await nextPage.value

        XCTAssertEqual(sut.items.map(\.id.id), [50, 51], "Page 2 of the old query must not be appended")
    }

    func test_itemDisplayed_nearEnd_requestsNextPageForSameQueryAndKind() async {
        await service.setSearch(.tv, query: "breaking", .success(stubPage(1, of: 2, ids: 0..<10, kind: .tv)))
        let sut = makeSUT()
        sut.scope = .tv
        sut.query = "breaking"
        await waitUntil { sut.state == .results }

        await sut.itemDisplayed(at: 4)

        let last = await service.searchCalls.last
        XCTAssertEqual(last, FakeTMDBService.SearchCall(kind: .tv, query: "breaking", page: 2))
    }

    func test_clearingQuery_returnsToIdle() async {
        await service.setSearch(.movie, query: "dune", .success(stubPage(1, of: 1, ids: 0..<3)))
        let sut = makeSUT()
        sut.query = "dune"
        await waitUntil { sut.state == .results }
        await sleeper.waitForSleepers(1)
        await sleeper.advance()

        sut.query = ""
        await waitUntil { sut.state == .idle }

        XCTAssertTrue(sut.items.isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT() -> SearchViewModel {
        SearchViewModel(service: service, throttleInterval: .milliseconds(400), sleeper: sleeper)
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Condition not met within 2 s", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }
}
