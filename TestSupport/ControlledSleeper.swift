import Foundation
import MovieScopeCore
import XCTest

/// A `Sleeper` whose sleeps only end when the test calls `advance()`, making
/// time-based behaviour (throttling, retries) fully deterministic.
/// Shared by the Core and app unit-test targets.
actor ControlledSleeper: Sleeper {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private(set) var requestedDurations: [Duration] = []
    private var waiters: [Waiter] = []

    var pendingCount: Int { waiters.count }

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    /// Ends the oldest pending sleep.
    func advance() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().continuation.resume()
    }

    /// Suspends until at least `count` sleeps are pending (or fails after 2 s).
    func waitForSleepers(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while waiters.count < count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Expected \(count) pending sleeps, saw \(waiters.count)", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
