/// Abstracts waiting so time-based logic (retries, throttling) can be tested
/// deterministically without real delays.
public protocol Sleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

/// Production sleeper backed by `Task.sleep`. Throws `CancellationError` when
/// the surrounding task is cancelled.
public struct TaskSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
