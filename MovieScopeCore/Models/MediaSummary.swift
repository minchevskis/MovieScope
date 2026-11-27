import Foundation

/// A movie or TV show as shown in lists (trending, search, favorites).
public struct MediaSummary: Identifiable, Hashable, Sendable {
    public let id: MediaID
    public let title: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double
    public let voteCount: Int
    public let releaseDate: Date?

    public init(
        id: MediaID,
        title: String,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        voteAverage: Double,
        voteCount: Int,
        releaseDate: Date?
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.releaseDate = releaseDate
    }
}

/// One page of results from a paginated TMDB endpoint.
public struct Page<Item: Sendable>: Sendable {
    public let page: Int
    public let totalPages: Int
    public let items: [Item]

    public init(page: Int, totalPages: Int, items: [Item]) {
        self.page = page
        self.totalPages = totalPages
        self.items = items
    }
}

extension Page: Equatable where Item: Equatable {}
