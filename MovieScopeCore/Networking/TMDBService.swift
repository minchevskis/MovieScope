import Foundation

/// Everything the app needs from TMDB, in domain terms. View models depend on
/// this protocol, never on `TMDBClient`, so tests substitute a fake.
public protocol TMDBService: Sendable {
    func trendingMovies(page: Int) async throws -> Page<MediaSummary>
    func search(_ kind: MediaKind, query: String, page: Int) async throws -> Page<MediaSummary>
    func details(for id: MediaID) async throws -> MediaDetails
    func imageConfiguration() async throws -> ImageConfiguration
}

// MARK: - Endpoints

extension Endpoint where Response == PageDTO<MediaListItemDTO> {
    static func trendingMovies(page: Int) -> Endpoint {
        Endpoint(path: "/trending/movie/week", queryItems: [URLQueryItem(name: "page", value: String(page))])
    }

    static func search(_ kind: MediaKind, query: String, page: Int) -> Endpoint {
        Endpoint(path: "/search/\(kind.rawValue)", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ])
    }
}

private let detailsAppendix = URLQueryItem(name: "append_to_response", value: "credits,reviews")

extension Endpoint where Response == MovieDetailsDTO {
    static func movieDetails(id: Int) -> Endpoint {
        Endpoint(path: "/movie/\(id)", queryItems: [detailsAppendix])
    }
}

extension Endpoint where Response == TVDetailsDTO {
    static func tvDetails(id: Int) -> Endpoint {
        Endpoint(path: "/tv/\(id)", queryItems: [detailsAppendix])
    }
}

extension Endpoint where Response == ConfigurationDTO {
    static var configuration: Endpoint { Endpoint(path: "/configuration") }
}

// MARK: - TMDBClient conformance

extension TMDBClient: TMDBService {
    public func trendingMovies(page: Int) async throws -> Page<MediaSummary> {
        try await send(.trendingMovies(page: page)).toPage(kind: .movie)
    }

    public func search(_ kind: MediaKind, query: String, page: Int) async throws -> Page<MediaSummary> {
        try await send(.search(kind, query: query, page: page)).toPage(kind: kind)
    }

    public func details(for id: MediaID) async throws -> MediaDetails {
        switch id.kind {
        case .movie:
            return try await send(.movieDetails(id: id.id)).toDetails()
        case .tv:
            return try await send(.tvDetails(id: id.id)).toDetails()
        }
    }

    public func imageConfiguration() async throws -> ImageConfiguration {
        try await send(.configuration).toConfiguration()
    }
}
