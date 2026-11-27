import Foundation

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

    /// Loads every fixture from `bundle` up front.
    public init(bundle: Bundle) {
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
