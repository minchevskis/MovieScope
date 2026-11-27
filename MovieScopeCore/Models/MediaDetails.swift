import Foundation

public struct Person: Hashable, Sendable {
    public let id: Int
    public let name: String
    public let profilePath: String?

    public init(id: Int, name: String, profilePath: String?) {
        self.id = id
        self.name = name
        self.profilePath = profilePath
    }
}

public struct CastMember: Hashable, Sendable {
    public let person: Person
    public let character: String

    public init(person: Person, character: String) {
        self.person = person
        self.character = character
    }
}

public struct Review: Hashable, Sendable, Identifiable {
    public let id: String
    public let author: String
    public let rating: Double?
    public let content: String
    public let createdAt: Date?

    public init(id: String, author: String, rating: Double?, content: String, createdAt: Date?) {
        self.id = id
        self.author = author
        self.rating = rating
        self.content = content
        self.createdAt = createdAt
    }
}

/// Everything the details screen shows for a movie or TV show. Fields that only
/// apply to one kind (runtime and budget vs seasons and networks) are optional
/// or empty for the other.
public struct MediaDetails: Sendable, Equatable {
    public let summary: MediaSummary
    public let tagline: String?
    public let genres: [String]
    public let runtimeMinutes: Int?
    public let seasonCount: Int?
    public let episodeCount: Int?
    public let status: String?
    public let originalLanguage: String?
    public let budget: Int?
    public let revenue: Int?
    public let networks: [String]
    public let directors: [Person]
    public let writers: [Person]
    public let creators: [Person]
    public let cast: [CastMember]
    public let reviews: [Review]

    public init(
        summary: MediaSummary,
        tagline: String? = nil,
        genres: [String] = [],
        runtimeMinutes: Int? = nil,
        seasonCount: Int? = nil,
        episodeCount: Int? = nil,
        status: String? = nil,
        originalLanguage: String? = nil,
        budget: Int? = nil,
        revenue: Int? = nil,
        networks: [String] = [],
        directors: [Person] = [],
        writers: [Person] = [],
        creators: [Person] = [],
        cast: [CastMember] = [],
        reviews: [Review] = []
    ) {
        self.summary = summary
        self.tagline = tagline
        self.genres = genres
        self.runtimeMinutes = runtimeMinutes
        self.seasonCount = seasonCount
        self.episodeCount = episodeCount
        self.status = status
        self.originalLanguage = originalLanguage
        self.budget = budget
        self.revenue = revenue
        self.networks = networks
        self.directors = directors
        self.writers = writers
        self.creators = creators
        self.cast = cast
        self.reviews = reviews
    }
}
