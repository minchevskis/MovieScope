import Foundation

/// Parses the two date formats TMDB uses. Empty or malformed strings yield `nil`;
/// TMDB often sends `""` for unknown release dates.
enum TMDBDateParser {
    private static let dayStyle = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
    private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractionalTimestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// `yyyy-MM-dd`, interpreted in UTC.
    static func day(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return try? dayStyle.parse(string)
    }

    /// ISO 8601 timestamps such as `2024-01-02T03:04:05.678Z`.
    static func timestamp(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return (try? fractionalTimestampStyle.parse(string)) ?? (try? timestampStyle.parse(string))
    }
}
