import XCTest

/// Renders the main screens at the largest accessibility text size to catch
/// clipped or overlapping text (screenshots are kept for review).
@MainActor
final class AccessibilityUITests: XCTestCase {
    func test_largestDynamicType_trendingAndDetailsRender() {
        let app = XCUIApplication()
        app.launchEnvironment["MOVIESCOPE_FIXTURES"] = "1"
        app.launchEnvironment["MOVIESCOPE_RESET_STATE"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let first = app.cells[AccessibilityID.Trending.item(0)]
        first.waitToAppear()
        attachScreenshot(of: app, named: "a11y-trending")

        first.tap()
        app.descendants(matching: .any)[AccessibilityID.Details.rating].firstMatch.waitToAppear()
        attachScreenshot(of: app, named: "a11y-details")
    }
}
