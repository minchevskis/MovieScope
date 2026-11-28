import XCTest

@MainActor
final class DetailsUITests: XCTestCase {
    func test_details_showsRatingPeopleCastAndFacts() {
        let app = AppLauncher.launch()
        let first = app.cells[AccessibilityID.Trending.item(0)]
        first.waitToAppear()

        first.tap()

        app.descendants(matching: .any)[AccessibilityID.Details.rating].firstMatch.waitToAppear()
        XCTAssertTrue(app.staticTexts["Avengers: Doomsday"].firstMatch.exists)
        attachScreenshot(of: app, named: "details-movie")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.people].firstMatch.exists)
        let scrollView = app.scrollViews.firstMatch
        let facts = app.descendants(matching: .any)[AccessibilityID.Details.facts].firstMatch
        app.scroll(scrollView, toReveal: facts)
        XCTAssertTrue(facts.exists)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Details.cast].firstMatch.exists)
    }
}

@MainActor
final class SearchUITests: XCTestCase {
    func test_search_movieThenTVScope_showsResults_andTVDetailsShowReviews() {
        let app = AppLauncher.launch()
        app.openTab(AccessibilityID.Root.searchTab, title: "Search")
        app.descendants(matching: .any)[AccessibilityID.Search.idle].firstMatch.waitToAppear()

        let field = app.searchFields.firstMatch
        field.waitToAppear()
        field.tap()
        field.typeText("batman")
        let firstRow = app.buttons[AccessibilityID.Search.row(0)]
        firstRow.waitToAppear()
        XCTAssertTrue(firstRow.label.contains("The Batman"))
        attachScreenshot(of: app, named: "search-movies")

        app.buttons["TV Shows"].firstMatch.tap()
        let firstShow = app.buttons[AccessibilityID.Search.row(0)]
        XCTAssertTrue(
            firstShow.waitForLabel(containing: "Breaking Bad"),
            "Switching the scope should search TV shows"
        )

        firstShow.tap()
        let reviews = app.descendants(matching: .any)[AccessibilityID.Details.reviews].firstMatch
        app.descendants(matching: .any)[AccessibilityID.Details.rating].firstMatch.waitToAppear()
        app.scroll(app.scrollViews.firstMatch, toReveal: reviews)
        XCTAssertTrue(reviews.exists)
        attachScreenshot(of: app, named: "details-tv-reviews")
    }

    /// The kind must be choosable every time search opens, not only the first
    /// time (iOS 26 showed the scopes once, then never again).
    func test_search_scopesAppearEveryTimeSearchOpens() {
        let app = AppLauncher.launch()
        app.openTab(AccessibilityID.Root.searchTab, title: "Search")
        let field = app.searchFields.firstMatch
        let tvScope = app.buttons["TV Shows"].firstMatch

        for attempt in 1...3 {
            field.waitToAppear()
            field.tap()
            XCTAssertTrue(tvScope.waitForExistence(timeout: 3), "No scopes when search opened (attempt \(attempt))")
            attachScreenshot(of: app, named: "search-open-\(attempt)")
            guard let close = app.searchCloseButton else {
                // iPad pins the field and scopes under the navigation bar. They
                // never hide, so there is no reopening to check.
                return
            }
            close.tap()
            XCTAssertTrue(tvScope.waitForNonExistence(timeout: 3), "Scopes stayed after search closed (attempt \(attempt))")
        }
    }
}

@MainActor
extension XCUIApplication {
    /// The button that closes active search: Close next to the field on iOS 26
    /// iPhone, Cancel on iOS 18. `nil` on iPad, where search stays pinned.
    var searchCloseButton: XCUIElement? {
        ["Close", "Cancel"].lazy.map { self.buttons[$0].firstMatch }.first { $0.exists }
    }
}

@MainActor
final class SetupAndAboutUITests: XCTestCase {
    func test_missingToken_showsSetupInstructions() {
        let app = AppLauncher.launch(forceNoToken: true)

        app.descendants(matching: .any)[AccessibilityID.MissingToken.screen].firstMatch.waitToAppear()
        XCTAssertTrue(app.staticTexts["Add your TMDB token"].exists)
    }

    func test_about_showsTMDBAttribution() {
        let app = AppLauncher.launch()
        let about = app.buttons[AccessibilityID.Root.aboutButton].firstMatch
        about.waitToAppear()

        about.tap()

        let attribution = app.staticTexts[AccessibilityID.About.attribution]
        attribution.waitToAppear()
        XCTAssertTrue(attribution.label.contains("not endorsed, certified, or otherwise approved by TMDB"))
        XCTAssertTrue(app.images["The Movie Database logo"].exists, "The official TMDB logo asset is shown")
        attachScreenshot(of: app, named: "about")
    }
}

extension XCUIElement {
    func waitForLabel(containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
