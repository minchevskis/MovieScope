import Foundation
import MovieScopeCore

/// Display formatting shared by the screens. Locale is injectable for tests.
nonisolated enum Formatters {
    static func rating(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    static func votes(_ count: Int, locale: Locale = .current) -> String {
        let number = count.formatted(.number.locale(locale))
        return count == 1 ? "\(number) vote" : "\(number) votes"
    }

    static func runtime(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _): return "\(remainder)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(remainder)m"
        }
    }

    /// TMDB dates are calendar days stored as UTC midnight.
    static func year(_ date: Date?) -> String? {
        guard let date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return String(calendar.component(.year, from: date))
    }

    static func money(_ amount: Int, locale: Locale = .current) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(locale))
    }

    static func languageName(_ code: String, locale: Locale = .current) -> String {
        locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code.uppercased()
    }
}

extension APIError {
    /// A short, user-facing explanation for error states.
    nonisolated var userMessage: String {
        switch self {
        case .missingCredentials:
            "Add your TMDB token to Config/Secrets.xcconfig to load content."
        case .unauthorized:
            "Your TMDB token was rejected. Check Config/Secrets.xcconfig."
        case .transport(.notConnectedToInternet), .transport(.networkConnectionLost), .transport(.dataNotAllowed):
            "You appear to be offline. Check your connection and try again."
        case .rateLimited:
            "TMDB is busy right now. Please try again in a moment."
        case .decoding, .invalidResponse:
            "TMDB sent something unexpected. Please try again."
        default:
            "TMDB couldn't be reached. Please try again."
        }
    }
}
