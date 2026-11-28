import Foundation

/// A typed description of one TMDB API call. The generic parameter ties the
/// request to the type its response decodes into, so call sites can't mismatch them.
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    let path: String
    let queryItems: [URLQueryItem]

    init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }
}
