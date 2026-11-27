import XCTest

/// A user flow first captured with Xcode 26's UI test recorder (see the raw
/// recording in git history), then edited:
/// - recorder menu tokens replaced by the accessibility identifiers it offered
/// - incidental gestures dropped (a sideways swipe on the first card, taps on
///   empty space, a trailing long press)
/// - tab selection and back navigation that also work on iOS 18 and iPad
/// - assertions added after every step
@MainActor
final class RecordedFlowUITests: XCTestCase {
    func test_recorded_browseTrendingToDetailsThenSearch() {
        let app = AppLauncher.launch()

        // Trending → details of the first featured title.
        let firstCard = app.cells[AccessibilityID.Trending.item(0)]
        firstCard.waitToAppear()
        firstCard.tap()
        let details = app.scrollViews[AccessibilityID.Details.screen].firstMatch
        details.waitToAppear()
        XCTAssertTrue(app.staticTexts["Avengers: Doomsday"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.rating].firstMatch.exists)

        // Scroll the details, then go back to Trending.
        details.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.cast].firstMatch.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap() // "BackButton" only exists on iOS 26
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5), "Back returns to the Trending grid")

        // Search for a movie and open the first result.
        app.openTab(AccessibilityID.Root.searchTab, title: "Search")
        let field = app.searchFields["Movies or TV shows"].firstMatch
        field.waitToAppear()
        field.tap()
        field.typeText("batman")
        let firstResult = app.buttons[AccessibilityID.Search.row(0)]
        firstResult.waitToAppear()
        XCTAssertTrue(firstResult.label.hasPrefix("The Batman"))
        firstResult.tap()
        app.scrollViews[AccessibilityID.Details.screen].firstMatch.waitToAppear()
    }
}
