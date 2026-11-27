@testable import MovieScope
import XCTest

final class SmokeTests: XCTestCase {
    func test_appModule_isImportable() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "MovieScopeEnvironment") as? String, "dev")
    }
}
