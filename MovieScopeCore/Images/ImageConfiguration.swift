import Foundation

/// TMDB's image hosting details from `/configuration`: the base URL and the
/// fixed sizes available per image category.
public struct ImageConfiguration: Sendable, Codable, Equatable {
    public let secureBaseURL: URL
    public let posterSizes: [String]
    public let backdropSizes: [String]
    public let profileSizes: [String]

    public init(secureBaseURL: URL, posterSizes: [String], backdropSizes: [String], profileSizes: [String]) {
        self.secureBaseURL = secureBaseURL
        self.posterSizes = posterSizes
        self.backdropSizes = backdropSizes
        self.profileSizes = profileSizes
    }
}
