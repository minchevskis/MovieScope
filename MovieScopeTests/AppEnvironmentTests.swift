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
}
