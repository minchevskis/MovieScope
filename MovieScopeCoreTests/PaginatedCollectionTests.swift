@testable import MovieScopeCore
import XCTest

final class PaginatedCollectionTests: XCTestCase {
    func test_append_dedupesOverlappingPages_preservingOrder() {
        var sut = PaginatedCollection<TestItem>()

        sut.append(testPage(1, of: 3, ids: [1, 2, 3]))
        sut.append(testPage(2, of: 3, ids: [3, 4]))

        XCTAssertEqual(sut.items.map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(sut.nextPage, 3)
    }

    func test_append_keepsFirstOccurrenceOfDuplicate() {
        var sut = PaginatedCollection<TestItem>()

        sut.append(Page(page: 1, totalPages: 2, items: [TestItem(id: 1, label: "first")]))
        sut.append(Page(page: 2, totalPages: 2, items: [TestItem(id: 1, label: "second")]))

        XCTAssertEqual(sut.items, [TestItem(id: 1, label: "first")])
    }

    func test_append_lastPage_setsNextPageNil() {
        var sut = PaginatedCollection<TestItem>()

        sut.append(testPage(2, of: 2, ids: [1]))

        XCTAssertNil(sut.nextPage)
        XCTAssertFalse(sut.canLoadMore)
    }

    func test_append_capsAtTMDBMaximumPage() {
        var sut = PaginatedCollection<TestItem>()

        sut.append(testPage(500, of: 1000, ids: [1]))

        XCTAssertNil(sut.nextPage, "TMDB rejects pages above 500")
    }

    func test_append_emptyResult_isExhausted() {
        var sut = PaginatedCollection<TestItem>()

        sut.append(testPage(1, of: 0, ids: []))

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertFalse(sut.canLoadMore)
    }

    func test_reset_startsOverAtPageOne() {
        var sut = PaginatedCollection<TestItem>()
        sut.append(testPage(1, of: 1, ids: [1]))

        sut.reset()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.nextPage, 1)
    }
}
