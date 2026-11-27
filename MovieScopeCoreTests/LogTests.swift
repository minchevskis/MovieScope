import Foundation
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

    func test_requestLogLine_hasPathAndStatus_butNoToken() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://api.themoviedb.org/3/search/movie?query=dune")))
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")

        let line = Log.requestLine(for: request, status: 200)

        XCTAssertTrue(line.contains("/3/search/movie"))
        XCTAssertTrue(line.contains("200"))
        XCTAssertTrue(line.contains("Bearer <redacted>"))
        XCTAssertFalse(line.contains("secret-token"))
    }
}
