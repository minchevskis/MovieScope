@testable import MovieScopeCore
import XCTest

final class RequestQueueTests: XCTestCase {
    func test_queue_startsUpToMax_thenQueues() {
        var sut = RequestQueue<String>(maxConcurrent: 2)

        XCTAssertTrue(sut.enqueue("a", priority: .low))
        XCTAssertTrue(sut.enqueue("b", priority: .high))
        XCTAssertFalse(sut.enqueue("c", priority: .high))

        XCTAssertTrue(sut.isRunning("a"))
        XCTAssertTrue(sut.isRunning("b"))
        XCTAssertTrue(sut.isQueued("c"))
    }

    func test_queue_finish_startsHighBeforeLow_inArrivalOrder() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)
        sut.enqueue("low1", priority: .low)
        sut.enqueue("high1", priority: .high)
        sut.enqueue("low2", priority: .low)
        sut.enqueue("high2", priority: .high)

        let order = ["running", "high1", "high2", "low1", "low2"].map { sut.finish($0) }

        XCTAssertEqual(order, ["high1", "high2", "low1", "low2", nil])
    }

    func test_queue_promote_movesQueuedLowRequestBehindExistingHighOnes() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)
        sut.enqueue("low1", priority: .low)
        sut.enqueue("high1", priority: .high)
        sut.enqueue("low2", priority: .low)

        sut.promote("low2")

        let order = ["running", "high1", "low2"].map { sut.finish($0) }
        XCTAssertEqual(order, ["high1", "low2", "low1"])
    }

    func test_queue_promote_ignoresRunningAndUnknownRequests() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)
        sut.enqueue("queued", priority: .low)

        sut.promote("running")
        sut.promote("unknown")

        XCTAssertTrue(sut.isRunning("running"))
        XCTAssertEqual(sut.finish("running"), "queued")
    }

    func test_queue_remove_dropsQueuedRequest() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)
        sut.enqueue("queued", priority: .high)

        sut.remove("queued")

        XCTAssertFalse(sut.isQueued("queued"))
        XCTAssertNil(sut.finish("running"))
    }

    func test_queue_remove_leavesRunningRequestToFinish() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)

        sut.remove("running")

        XCTAssertTrue(sut.isRunning("running"), "A running request frees its slot only when it finishes")
        XCTAssertFalse(sut.enqueue("next", priority: .high))
    }

    func test_queue_finishingUnknownRequest_freesNothing() {
        var sut = RequestQueue<String>(maxConcurrent: 1)
        sut.enqueue("running", priority: .low)

        XCTAssertNil(sut.finish("unknown"))

        XCTAssertFalse(sut.enqueue("next", priority: .high), "The only slot is still taken")
    }
}
