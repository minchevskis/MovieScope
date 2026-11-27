@testable import MovieScopeCore
import XCTest

final class SmokeTests: XCTestCase {
    func test_coreModule_isImportable() {
        XCTAssertEqual(Log.subsystem, "io.github.minchevskis.MovieScopeCore")
    }
}
