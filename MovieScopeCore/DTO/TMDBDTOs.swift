import Foundation

// Wire formats of the TMDB v3 responses the app uses. Decoded with
// `.convertFromSnakeCase`. Internal: the rest of the app only sees domain models.
// Fields TMDB may omit or null are optional.

struct PageDTO<Item: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let totalPages: Int
    let results: [Item]
}

/// A list entry from trending or search; movies use `title`/`releaseDate`,
/// TV shows use `name`/`firstAirDate`.
struct MediaListItemDTO: Decodable, Sendable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let releaseDate: String?
    let firstAirDate: String?
}

struct NamedDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

struct PersonDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let profilePath: String?
}

struct CastDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
}

struct CrewDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
}

struct CreditsDTO: Decodable, Sendable {
    let cast: [CastDTO]
    let crew: [CrewDTO]
}

struct ReviewDTO: Decodable, Sendable {
    struct AuthorDetails: Decodable, Sendable {
        let rating: Double?
    }

    let id: String
    let author: String
    let authorDetails: AuthorDetails?
    let content: String
    let createdAt: String?
}

struct ReviewsDTO: Decodable, Sendable {
    let results: [ReviewDTO]
}

struct MovieDetailsDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let releaseDate: String?
    let tagline: String?
    let genres: [NamedDTO]?
    let runtime: Int?
    let status: String?
    let originalLanguage: String?
    let budget: Int?
    let revenue: Int?
    let credits: CreditsDTO?
    let reviews: ReviewsDTO?
}

struct TVDetailsDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let firstAirDate: String?
    let tagline: String?
    let genres: [NamedDTO]?
    let episodeRunTime: [Int]?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let status: String?
    let originalLanguage: String?
    let networks: [NamedDTO]?
    let createdBy: [PersonDTO]?
    let credits: CreditsDTO?
    let reviews: ReviewsDTO?
}

struct ConfigurationDTO: Decodable, Sendable {
    struct Images: Decodable, Sendable {
        let secureBaseUrl: String
        let posterSizes: [String]
        let backdropSizes: [String]
        let profileSizes: [String]
    }

    let images: Images
}
