@testable import MovieScope
import MovieScopeCore
import XCTest

final class AppEnvironmentTests: XCTestCase {
    func test_environment_parsesFlags() {
        let sut = AppEnvironment(processEnvironment: [
            "MOVIESCOPE_FIXTURES": "1",
            "MOVIESCOPE_RESET_STATE": "1",
            "MOVIESCOPE_FORCE_NO_TOKEN": "1",
            "MOVIESCOPE_LOG_LEVEL": "debug"
        ])

        XCTAssertTrue(sut.usesFixtures)
        XCTAssertTrue(sut.resetsState)
        XCTAssertTrue(sut.forcesMissingToken)
        XCTAssertEqual(sut.logLevel, "debug")
    }

    func test_environment_defaultsWhenAbsent() {
        let sut = AppEnvironment(processEnvironment: [:])

        XCTAssertFalse(sut.usesFixtures)
        XCTAssertFalse(sut.resetsState)
        XCTAssertFalse(sut.forcesMissingToken)
        XCTAssertFalse(sut.isHostingUnitTests)
        XCTAssertEqual(sut.logLevel, "info")
    }

    func test_environment_flagsOtherThanOne_areOff() {
        let sut = AppEnvironment(processEnvironment: ["MOVIESCOPE_FIXTURES": "yes"])

        XCTAssertFalse(sut.usesFixtures)
    }

    func test_environment_detectsUnitTestHost() {
        let sut = AppEnvironment(processEnvironment: ["XCTestConfigurationFilePath": "/tmp/config.xctestconfiguration"])

        XCTAssertTrue(sut.isHostingUnitTests)
    }
}

@MainActor
final class AppDependenciesTests: XCTestCase {
    func test_fixtureMode_hasCredentials_andServesFixtures() async throws {
        let sut = AppDependencies(environment: AppEnvironment(processEnvironment: ["MOVIESCOPE_FIXTURES": "1"]))

        XCTAssertTrue(sut.hasCredentials)
        let page = try await sut.service.trendingMovies(page: 1)
        XCTAssertEqual(page.items.first?.title, "Avengers: Doomsday")
    }

    func test_forcedMissingToken_hasNoCredentials() {
        let sut = AppDependencies(environment: AppEnvironment(processEnvironment: [
            "MOVIESCOPE_FIXTURES": "1",
            "MOVIESCOPE_FORCE_NO_TOKEN": "1"
        ]))

        XCTAssertFalse(sut.hasCredentials)
    }

    func test_makeDetails_startsFromTheTappedTitle() async {
        let sut = AppDependencies(environment: AppEnvironment(processEnvironment: ["MOVIESCOPE_FIXTURES": "1"]))
        let tapped = MediaSummary.stub(550)

        let details = sut.makeDetails(for: tapped)

        XCTAssertEqual(details.id, tapped.id)
        XCTAssertEqual(details.summary, tapped, "Shows what the list knew while the details load")
    }

    func test_detailsViewModels_areDistinctNavigationTargets() {
        let sut = AppDependencies(environment: AppEnvironment(processEnvironment: ["MOVIESCOPE_FIXTURES": "1"]))
        let first = sut.makeDetails(for: .stub(1))
        let again = sut.makeDetails(for: .stub(1))

        XCTAssertEqual(first, first)
        XCTAssertNotEqual(first, again, "Tapping the same title twice is two separate pushes")
        XCTAssertEqual(Set([first, again, first]).count, 2)
    }
}
