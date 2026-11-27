import os

/// Central loggers for MovieScopeCore. Never log credentials: headers go through
/// `redacted(_:)` first.
enum Log {
    static let subsystem = "io.github.minchevskis.MovieScopeCore"
    static let network = Logger(subsystem: subsystem, category: "network")
    static let images = Logger(subsystem: subsystem, category: "images")
    static let storage = Logger(subsystem: subsystem, category: "storage")

    /// Returns a copy of `headers` that is safe to log: the `Authorization`
    /// value keeps its scheme but the credential is replaced.
    static func redacted(_ headers: [String: String]) -> [String: String] {
        var copy = headers
        for key in headers.keys where key.caseInsensitiveCompare("Authorization") == .orderedSame {
            let scheme = headers[key]?.split(separator: " ").first.map(String.init) ?? ""
            copy[key] = scheme.isEmpty ? "<redacted>" : "\(scheme) <redacted>"
        }
        return copy
    }
}
