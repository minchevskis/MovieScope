import Foundation
@testable import MovieScope
import MovieScopeCore
import XCTest

final class FormattersTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func test_rating_oneDecimal() {
        XCTAssertEqual(Formatters.rating(7.84, locale: english), "7.8")
        XCTAssertEqual(Formatters.rating(10, locale: english), "10.0")
    }

    func test_votes_groupsThousands_andPluralizes() {
        XCTAssertEqual(Formatters.votes(12_345, locale: english), "12,345 votes")
        XCTAssertEqual(Formatters.votes(1, locale: english), "1 vote")
    }

    func test_runtime_hoursAndMinutes() {
        XCTAssertEqual(Formatters.runtime(minutes: 135), "2h 15m")
        XCTAssertEqual(Formatters.runtime(minutes: 45), "45m")
        XCTAssertEqual(Formatters.runtime(minutes: 120), "2h")
    }

    func test_year_usesUTCAndHandlesNil() {
        XCTAssertNil(Formatters.year(nil))
        XCTAssertEqual(Formatters.year(Date(timeIntervalSince1970: 1_704_067_200)), "2024") // 2024-01-01T00:00Z
    }

    func test_money_usesWholeDollars() {
        XCTAssertEqual(Formatters.money(250_000_000, locale: english), "$250,000,000")
    }

    func test_languageName_fromCode() {
        XCTAssertEqual(Formatters.languageName("en", locale: english), "English")
        XCTAssertEqual(Formatters.languageName("zz-unknown", locale: english), "ZZ-UNKNOWN")
    }
}

final class ErrorMessageTests: XCTestCase {
    func test_unauthorized_pointsToTokenFile() {
        XCTAssertEqual(
            APIError.unauthorized.userMessage,
            "Your TMDB token was rejected. Check Config/Secrets.xcconfig."
        )
    }

    func test_offline_mentionsConnection() {
        XCTAssertEqual(
            APIError.transport(.notConnectedToInternet).userMessage,
            "You appear to be offline. Check your connection and try again."
        )
    }

    func test_otherErrors_haveGenericMessage() {
        XCTAssertEqual(APIError.server(status: 503).userMessage, "TMDB couldn't be reached. Please try again.")
        XCTAssertEqual(APIError.decoding("x").userMessage, "TMDB sent something unexpected. Please try again.")
    }
}
