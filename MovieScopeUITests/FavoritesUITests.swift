import XCTest

@MainActor
final class FavoritesUITests: XCTestCase {
    func test_favoriteFromDetails_appearsInFavoritesTab_andMarksTheCard() {
        let app = AppLauncher.launch()
        let first = app.cells[AccessibilityID.Trending.item(0)]
        first.waitToAppear()
        first.tap()

        let heart = app.buttons[AccessibilityID.Details.favoriteButton].firstMatch
        heart.waitToAppear()
        heart.tap()
        XCTAssertTrue(heart.waitForLabel(containing: "Remove from Favorites"))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(first.waitForLabel(containing: "favorite"), "The trending card shows the favorite state")

        app.openTab(AccessibilityID.Root.favoritesTab, title: "Favorites")
        let saved = app.buttons[AccessibilityID.Favorites.item(0)]
        saved.waitToAppear()
        XCTAssertTrue(saved.label.contains("Avengers: Doomsday"))
        attachScreenshot(of: app, named: "favorites")
    }

    func test_favorites_emptyState() {
        let app = AppLauncher.launch()
        app.openTab(AccessibilityID.Root.favoritesTab, title: "Favorites")

        app.descendants(matching: .any)[AccessibilityID.Favorites.empty].firstMatch.waitToAppear()
    }
}
