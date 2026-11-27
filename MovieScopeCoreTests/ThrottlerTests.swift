@testable import MovieScopeCore
import XCTest

@MainActor
final class ThrottlerTests: XCTestCase {
    func test_firstValue_firesImmediately() {
        let (sut, recorder, _) = makeSUT()

        sut.send("a")

        XCTAssertEqual(recorder.values, ["a"])
    }

    func test_burst_deliversFirstThenLatest() async {
        let (sut, recorder, sleeper) = makeSUT()
        let trailing = recorder.expectation(count: 2, in: self)

        sut.send("a")
        sut.send("b")
        sut.send("c")
        XCTAssertEqual(recorder.values, ["a"])
        await sleeper.waitForSleepers(1)
        await sleeper.advance()

        await fulfillment(of: [trailing], timeout: 1)
        XCTAssertEqual(recorder.values, ["a", "c"])
    }

    func test_noPending_noTrailingFire() async {
        let (sut, recorder, sleeper) = makeSUT()
        let unexpectedFire = recorder.expectation(count: 2, in: self)
        unexpectedFire.isInverted = true

        sut.send("a")
        await sleeper.waitForSleepers(1)
        await sleeper.advance()

        await fulfillment(of: [unexpectedFire], timeout: 0.3)
        XCTAssertEqual(recorder.values, ["a"])
    }

    func test_afterQuietWindow_nextValueFiresImmediately() async {
        let (sut, recorder, sleeper) = makeSUT()
        sut.send("a")
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await waitUntil { !sut.isWindowOpen }

        sut.send("b")

        XCTAssertEqual(recorder.values, ["a", "b"])
    }

    func test_trailingValue_opensNewWindow() async {
        let (sut, recorder, sleeper) = makeSUT()
        let secondFire = recorder.expectation(count: 2, in: self)
        sut.send("a")
        sut.send("b")
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await fulfillment(of: [secondFire], timeout: 1)

        sut.send("c")

        XCTAssertEqual(recorder.values, ["a", "b"], "c waits for the window opened by b")
        let thirdFire = recorder.expectation(count: 3, in: self)
        await sleeper.waitForSleepers(1)
        await sleeper.advance()
        await fulfillment(of: [thirdFire], timeout: 1)
        XCTAssertEqual(recorder.values, ["a", "b", "c"])
    }

    func test_cancel_dropsPending() async {
        let (sut, recorder, sleeper) = makeSUT()
        let unexpectedFire = recorder.expectation(count: 2, in: self)
        unexpectedFire.isInverted = true

        sut.send("a")
        sut.send("b")
        await sleeper.waitForSleepers(1)
        sut.cancel()
        await sleeper.advance()

        await fulfillment(of: [unexpectedFire], timeout: 0.3)
        XCTAssertEqual(recorder.values, ["a"])
    }

    func test_flush_firesPendingImmediately() {
        let (sut, recorder, _) = makeSUT()

        sut.send("a")
        sut.send("b")
        sut.flush()

        XCTAssertEqual(recorder.values, ["a", "b"])
    }

    func test_usesConfiguredInterval() async {
        let (sut, _, sleeper) = makeSUT(interval: .milliseconds(400))

        sut.send("a")
        await sleeper.waitForSleepers(1)

        let durations = await sleeper.requestedDurations
        XCTAssertEqual(durations, [.milliseconds(400)])
    }

    // MARK: - Helpers

    private func makeSUT(interval: Duration = .milliseconds(400)) -> (Throttler<String>, Recorder, ControlledSleeper) {
        let recorder = Recorder()
        let sleeper = ControlledSleeper()
        let sut = Throttler<String>(interval: interval, sleeper: sleeper) { recorder.record($0) }
        return (sut, recorder, sleeper)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while await !condition(), ContinuousClock.now < deadline {
            await Task.yield()
        }
    }
}

@MainActor
private final class Recorder {
    private(set) var values: [String] = []
    private var expectations: [(count: Int, expectation: XCTestExpectation)] = []

    func record(_ value: String) {
        values.append(value)
        for entry in expectations where entry.count == values.count {
            entry.expectation.fulfill()
        }
    }

    /// An expectation fulfilled when the action has fired `count` times.
    func expectation(count: Int, in testCase: XCTestCase) -> XCTestExpectation {
        let expectation = testCase.expectation(description: "fired \(count) times")
        expectations.append((count, expectation))
        return expectation
    }
}
