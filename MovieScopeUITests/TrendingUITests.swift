import XCTest

@MainActor
final class TrendingUITests: XCTestCase {
    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        try await super.tearDown()
    }

    func test_trending_showsCells_andLoadsSecondPageOnScroll() {
        let app = AppLauncher.launch()
        let collection = app.collectionViews[AccessibilityID.Trending.collection]
        collection.waitToAppear()

        XCTAssertTrue(app.cells[AccessibilityID.Trending.item(0)].waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells[AccessibilityID.Trending.item(0)].label.hasPrefix("Avengers: Doomsday"), true)
        attachScreenshot(of: app, named: "trending")

        // Page 1 has 8 titles; index 12 only exists once page 2 has been loaded.
        let secondPageItem = app.cells[AccessibilityID.Trending.item(12)]
        XCTAssertTrue(app.scroll(collection, toReveal: secondPageItem), "Page 2 did not load while scrolling")
    }

    func test_trending_gridAdaptsColumnsToOrientation() throws {
        let app = AppLauncher.launch()
        let first = app.cells[AccessibilityID.Trending.item(5)]
        let third = app.cells[AccessibilityID.Trending.item(7)]
        first.waitToAppear()
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "iPad shows 4+ columns in both orientations")

        XCTAssertGreaterThan(third.frame.minY, first.frame.minY, "Portrait iPhone: two columns, third card wraps")

        XCUIDevice.shared.orientation = .landscapeLeft
        let sameRow = NSPredicate { _, _ in abs(third.frame.minY - first.frame.minY) < 1 }
        let rotated = expectation(for: sameRow, evaluatedWith: nil)
        wait(for: [rotated], timeout: 5)
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "rotation animation settles")], timeout: 1)
        attachScreenshot(of: app, named: "trending-landscape")
    }
}
