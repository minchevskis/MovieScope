@testable import MovieScopeCore
import XCTest

final class SleeperTests: XCTestCase {
    func test_taskSleeper_returnsAfterDuration() async throws {
        let clock = ContinuousClock()
        let start = clock.now

        try await TaskSleeper().sleep(for: .milliseconds(20))

        XCTAssertGreaterThanOrEqual(clock.now - start, .milliseconds(20))
    }

    func test_taskSleeper_throwsWhenCancelled() async {
        let task = Task { try await TaskSleeper().sleep(for: .seconds(10)) }
        task.cancel()

        let result = await task.result

        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
    }
}
