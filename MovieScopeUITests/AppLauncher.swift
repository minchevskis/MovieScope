import XCTest

/// Launches the app for UI tests. Fixture mode serves bundled TMDB responses,
/// so tests are deterministic and need neither network nor a token.
@MainActor
enum AppLauncher {
    static func launch(fixtures: Bool = true, resetState: Bool = true, forceNoToken: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if fixtures { app.launchEnvironment["MOVIESCOPE_FIXTURES"] = "1" }
        if resetState { app.launchEnvironment["MOVIESCOPE_RESET_STATE"] = "1" }
        if forceNoToken { app.launchEnvironment["MOVIESCOPE_FORCE_NO_TOKEN"] = "1" }
        app.launch()
        return app
    }
}

@MainActor
extension XCUIApplication {
    /// Selects a top-level tab. iOS 26 exposes the tab's accessibility
    /// identifier (iPhone tab bar, iPad top bar); iOS 18 only its title.
    func openTab(_ identifier: String, title: String) {
        let byIdentifier = buttons[identifier].firstMatch
        if byIdentifier.waitForExistence(timeout: 3) {
            byIdentifier.tap()
            return
        }
        let byTitle = tabBars.buttons[title].firstMatch
        XCTAssertTrue(byTitle.waitForExistence(timeout: 3), "Tab \(title) not found")
        byTitle.tap()
    }

    /// Swipes up until `element` is visible, up to `maxSwipes` times.
    @discardableResult
    func scroll(_ container: XCUIElement, toReveal element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes where !element.isHittable {
            container.swipeUp()
        }
        return element.isHittable
    }
}

extension XCTestCase {
    /// Keeps a named screenshot in the test results (used to review screens and for the README).
    @MainActor
    func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElement {
    func waitToAppear(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout), "\(self) did not appear", file: file, line: line)
    }
}
