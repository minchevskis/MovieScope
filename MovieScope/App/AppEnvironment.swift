import Foundation

/// Launch-time switches read from the process environment. Xcode schemes set
/// them when running from Xcode, and UI tests set them through `launchEnvironment`.
/// None of them are secrets.
nonisolated struct AppEnvironment: Equatable {
    /// Serve bundled fixtures instead of calling TMDB (UI tests, offline demos).
    let usesFixtures: Bool
    /// Wipe persisted state (favorites, cached configuration) at launch.
    let resetsState: Bool
    /// Behave as if no token were configured (to show the setup screen).
    let forcesMissingToken: Bool
    /// The app is the host process of a unit-test bundle; skip building the UI.
    let isHostingUnitTests: Bool
    /// UI tests only: in fixture mode, the first request for trending page 2 fails.
    let failsSecondTrendingPageOnce: Bool
    let logLevel: String

    init(processEnvironment: [String: String]) {
        usesFixtures = processEnvironment["MOVIESCOPE_FIXTURES"] == "1"
        resetsState = processEnvironment["MOVIESCOPE_RESET_STATE"] == "1"
        forcesMissingToken = processEnvironment["MOVIESCOPE_FORCE_NO_TOKEN"] == "1"
        isHostingUnitTests = processEnvironment["XCTestConfigurationFilePath"] != nil
        failsSecondTrendingPageOnce = processEnvironment["MOVIESCOPE_FIXTURES_FAIL_PAGE_2"] == "1"
        logLevel = processEnvironment["MOVIESCOPE_LOG_LEVEL"] ?? "info"
    }
}
