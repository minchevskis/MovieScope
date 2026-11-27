import Foundation

/// A typed description of one TMDB API call. The generic parameter ties the
/// request to the type its response decodes into, so call sites can't mismatch them.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public let path: String
    public let queryItems: [URLQueryItem]

    public init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }
}
