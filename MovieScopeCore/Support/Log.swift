import os

/// Central loggers for MovieScopeCore. Never log credentials.
enum Log {
    static let subsystem = "io.github.minchevskis.MovieScopeCore"
    static let network = Logger(subsystem: subsystem, category: "network")
}
