@testable import MovieScopeCore
import XCTest

final class LogTests: XCTestCase {
    func test_redacted_hidesAuthorizationValue() {
        let redacted = Log.redacted([
            "Authorization": "Bearer secret-token",
            "Accept": "application/json"
        ])

        XCTAssertEqual(redacted["Authorization"], "Bearer <redacted>")
        XCTAssertEqual(redacted["Accept"], "application/json")
        XCTAssertFalse(redacted.values.contains { $0.contains("secret-token") })
    }
}
