/// Decides which requests may run: at most `maxConcurrent` at once, high
/// priority before low, and first come, first served within a priority.
/// A request still waiting can be promoted or removed.
///
/// It's a plain value with no concurrency of its own. Its owner (the image
/// pipeline actor) keeps it next to the state that decides priorities, so
/// promoting a request can never race the request being queued.
struct RequestQueue<ID: Hashable> {
    enum Priority {
        /// Needed now, such as an image on screen.
        case high
        /// Needed soon, such as a prefetch.
        case low
    }

    let maxConcurrent: Int
    private var running: Set<ID> = []
    private var high: [ID] = []
    private var low: [ID] = []

    init(maxConcurrent: Int) {
        precondition(maxConcurrent > 0, "maxConcurrent must be positive")
        self.maxConcurrent = maxConcurrent
    }

    /// Adds a request. Returns `true` when it may start right away.
    @discardableResult
    mutating func enqueue(_ id: ID, priority: Priority) -> Bool {
        if running.count < maxConcurrent {
            running.insert(id)
            return true
        }
        switch priority {
        case .high: high.append(id)
        case .low: low.append(id)
        }
        return false
    }

    func isRunning(_ id: ID) -> Bool {
        running.contains(id)
    }

    func isQueued(_ id: ID) -> Bool {
        high.contains(id) || low.contains(id)
    }

    /// Moves a waiting low-priority request to the back of the high-priority line.
    mutating func promote(_ id: ID) {
        guard let index = low.firstIndex(of: id) else { return }
        high.append(low.remove(at: index))
    }

    /// Drops a request that hasn't started. A running request frees its slot
    /// only through `finish`.
    mutating func remove(_ id: ID) {
        high.removeAll { $0 == id }
        low.removeAll { $0 == id }
    }

    /// Frees the slot of a finished request and returns the request that
    /// starts in its place, if any.
    mutating func finish(_ id: ID) -> ID? {
        guard running.remove(id) != nil else { return nil }
        let next = high.isEmpty ? (low.isEmpty ? nil : low.removeFirst()) : high.removeFirst()
        if let next { running.insert(next) }
        return next
    }
}
