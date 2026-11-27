import Foundation

/// Caps how many operations run at once; extra callers wait in FIFO order.
///
/// The image pipeline uses it to bound concurrent downloads (TMDB allows about
/// 40 requests per second), so a fast scroll can't flood the network.
/// A waiter that is cancelled leaves the queue and throws `CancellationError`.
public actor RequestLimiter {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let maxConcurrent: Int
    private var running = 0
    private var waiters: [Waiter] = []

    public init(maxConcurrent: Int) {
        precondition(maxConcurrent > 0, "maxConcurrent must be positive")
        self.maxConcurrent = maxConcurrent
    }

    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        try await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async throws {
        if running < maxConcurrent {
            running += 1
            return
        }
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
            Task { await self.removeWaiter(id) }
        }
    }

    /// Hands the slot to the next waiter, or frees it.
    private func release() {
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    private func removeWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
