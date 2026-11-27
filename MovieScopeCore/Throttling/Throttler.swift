/// Rate-limits a stream of values to at most one action per `interval`.
///
/// - The first value after a quiet period fires immediately (leading edge).
/// - Values arriving during the window replace each other; only the latest is kept.
/// - When the window ends, the latest pending value fires (trailing edge) and
///   opens a new window, so the final value of a burst is never lost.
///
/// Used by search: results update while typing, at most once per interval, and
/// always end with the full query. Unlike debouncing, this never waits for the
/// user to stop typing before showing anything.
@MainActor
public final class Throttler<Value: Sendable> {
    private let interval: Duration
    private let sleeper: any Sleeper
    private let action: @MainActor (Value) -> Void

    private var pending: Value?
    private var window: Task<Void, Never>?
    private var windowID = 0

    public init(
        interval: Duration,
        sleeper: any Sleeper = TaskSleeper(),
        action: @escaping @MainActor (Value) -> Void
    ) {
        self.interval = interval
        self.sleeper = sleeper
        self.action = action
    }

    /// Submits a value: fires now if no window is open, otherwise keeps it as
    /// the pending value for the end of the window.
    public func send(_ value: Value) {
        if window == nil {
            action(value)
            openWindow()
        } else {
            pending = value
        }
    }

    /// Fires the pending value immediately, if any. The current window stays open.
    public func flush() {
        guard let value = pending else { return }
        pending = nil
        action(value)
    }

    /// Drops the pending value and closes the window.
    public func cancel() {
        pending = nil
        window?.cancel()
        window = nil
        windowID += 1
    }

    private func openWindow() {
        windowID += 1
        let id = windowID
        let sleeper = sleeper
        let interval = interval
        // Only the wait happens off the main actor; ending the window touches
        // main-actor state, so it hops back.
        window = Task { @concurrent [weak self] in
            do {
                try await sleeper.sleep(for: interval)
            } catch {
                return
            }
            await self?.windowEnded(id: id)
        }
    }

    private func windowEnded(id: Int) {
        guard id == windowID else { return }
        window = nil
        guard let value = pending else { return }
        pending = nil
        action(value)
        openWindow()
    }
}
