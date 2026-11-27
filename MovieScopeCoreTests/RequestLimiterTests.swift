@testable import MovieScopeCore
import XCTest

final class RequestLimiterTests: XCTestCase {
    func test_limiter_neverExceedsMax() async throws {
        let sut = RequestLimiter(maxConcurrent: 3)
        let counter = ConcurrencyCounter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await sut.run {
                        await counter.enter()
                        try await Task.sleep(for: .milliseconds(5))
                        await counter.leave()
                    }
                }
            }
            try await group.waitForAll()
        }

        let peak = await counter.peak
        let completed = await counter.completed
        XCTAssertEqual(peak, 3)
        XCTAssertEqual(completed, 20)
    }

    func test_limiter_cancelledWaiter_throwsAndLeavesQueue() async throws {
        let sut = RequestLimiter(maxConcurrent: 1)
        let gate = ControlledSleeper()
        let blocker = Task { try await sut.run { try await gate.sleep(for: .zero) } }
        await gate.waitForSleepers(1)

        let waiting = Task { try await sut.run { "should not run" } }
        await Task.yield()
        waiting.cancel()

        do {
            _ = try await waiting.value
            XCTFail("A cancelled waiter must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        await gate.advance()
        try await blocker.value
        let next = try await sut.run { "runs" }
        XCTAssertEqual(next, "runs", "The queue must not be stuck after a cancelled waiter")
    }

    func test_limiter_operationError_releasesSlot() async throws {
        struct Failure: Error {}
        let sut = RequestLimiter(maxConcurrent: 1)

        do {
            _ = try await sut.run { () async throws -> Int in throw Failure() }
        } catch {}
        let value = try await sut.run { 42 }

        XCTAssertEqual(value, 42)
    }
}

private actor ConcurrencyCounter {
    private var active = 0
    private(set) var peak = 0
    private(set) var completed = 0

    func enter() {
        active += 1
        peak = max(peak, active)
    }

    func leave() {
        active -= 1
        completed += 1
    }
}
