import Foundation
@testable import MovieScopeCore
import XCTest

struct TestItem: Identifiable, Sendable, Equatable {
    let id: Int
    var label = ""
}

func testPage(_ number: Int, of total: Int, ids: [Int]) -> Page<TestItem> {
    Page(page: number, totalPages: total, items: ids.map { TestItem(id: $0) })
}

/// A page fetcher whose responses the test releases explicitly, so ordering and
/// in-flight behaviour can be asserted deterministically.
actor ControlledFetcher {
    private(set) var requestedPages: [Int] = []
    private var pending: [Int: [CheckedContinuation<Page<TestItem>, any Error>]] = [:]

    func fetch(_ page: Int) async throws -> Page<TestItem> {
        requestedPages.append(page)
        return try await withCheckedThrowingContinuation { continuation in
            pending[page, default: []].append(continuation)
        }
    }

    func resolve(_ page: Int, with result: Result<Page<TestItem>, any Error>) {
        pending.removeValue(forKey: page)?.forEach { $0.resume(with: result) }
    }

    /// Suspends until at least `count` fetches have started (or fails after 2 s).
    func waitForRequests(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while requestedPages.count < count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Expected \(count) requests, saw \(requestedPages.count)", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }
}
