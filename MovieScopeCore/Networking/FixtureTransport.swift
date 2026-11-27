import Foundation
import Synchronization

/// Serves captured TMDB responses (`*.fixture.json`) and generated artwork
/// instead of hitting the network. The app uses it when launched with
/// `MOVIESCOPE_FIXTURES=1` (UI tests), so UI tests are deterministic and need
/// no token.
public struct FixtureTransport: HTTPTransport {
    private static let fixtureNames = [
        "trending_movie_week_p1", "trending_movie_week_p2",
        "search_movie", "search_tv",
        "movie_details", "tv_details",
        "configuration"
    ]

    private let fixtures: [String: Data]
    private let failures: FailureBudget

    /// Loads every fixture from `bundle` up front. Requests listed in
    /// `failingOnce` (path plus `?page=N`, e.g. `/3/trending/movie/week?page=2`)
    /// fail with HTTP 503 the first time, to exercise retry UI in UI tests.
    public init(bundle: Bundle, failingOnce: Set<String> = []) {
        failures = FailureBudget(failingOnce)
        var fixtures: [String: Data] = [:]
        for name in Self.fixtureNames {
            if let url = bundle.url(forResource: name, withExtension: "fixture.json"),
               let data = try? Data(contentsOf: url) {
                fixtures[name] = data
            }
        }
        self.fixtures = fixtures
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw APIError.invalidRequest }
        if url.host() == "image.tmdb.org" {
            let seed = url.lastPathComponent.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            let artwork = PlaceholderImageFactory.pngData(width: 342, height: 513, seed: seed)
            return try respond(url, status: 200, body: artwork)
        }
        if failures.consume(Self.failureKey(for: url)) {
            return try respond(url, status: 503, body: Data(#"{"status_code":503,"success":false}"#.utf8))
        }
        guard let name = fixtureName(for: url), let body = fixtures[name] else {
            return try respond(url, status: 404, body: Data(#"{"status_code":34,"success":false}"#.utf8))
        }
        return try respond(url, status: 200, body: body)
    }

    private func fixtureName(for url: URL) -> String? {
        let path = url.path()
        switch path {
        case "/3/trending/movie/week":
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value ?? "1"
            return "trending_movie_week_p\(page)"
        case "/3/search/movie": return "search_movie"
        case "/3/search/tv": return "search_tv"
        case "/3/configuration": return "configuration"
        case _ where path.hasPrefix("/3/movie/"): return "movie_details"
        case _ where path.hasPrefix("/3/tv/"): return "tv_details"
        default: return nil
        }
    }

    private static func failureKey(for url: URL) -> String {
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "page" }?.value
        return url.path() + (page.map { "?page=" + $0 } ?? "")
    }

    private func respond(_ url: URL, status: Int, body: Data) throws -> (Data, HTTPURLResponse) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else { throw APIError.invalidResponse }
        return (body, response)
    }
}

/// Requests that should fail once; thread-safe so the transport stays `Sendable`.
private final class FailureBudget: Sendable {
    private let remaining: Mutex<Set<String>>

    init(_ keys: Set<String>) {
        remaining = Mutex(keys)
    }

    func consume(_ key: String) -> Bool {
        remaining.withLock { $0.remove(key) != nil }
    }
}
