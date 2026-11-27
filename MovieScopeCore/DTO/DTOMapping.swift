import Foundation

// DTO → domain mapping. All TMDB quirks are normalized here, so nothing above
// this layer has to know about them:
// - empty strings mean "unknown"
// - 0 means "unknown" for runtime, budget and revenue
// - credits contain duplicate people across jobs

enum MappingLimits {
    static let cast = 15
    static let reviews = 3
}

extension MediaListItemDTO {
    func toSummary(kind: MediaKind) -> MediaSummary {
        MediaSummary(
            id: MediaID(kind: kind, id: id),
            title: (kind == .movie ? title ?? name : name ?? title) ?? "",
            overview: overview ?? "",
            posterPath: posterPath.nonEmpty,
            backdropPath: backdropPath.nonEmpty,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            releaseDate: TMDBDateParser.day(kind == .movie ? releaseDate : firstAirDate)
        )
    }
}

extension PageDTO where Item == MediaListItemDTO {
    func toPage(kind: MediaKind) -> Page<MediaSummary> {
        Page(page: page, totalPages: totalPages, items: results.map { $0.toSummary(kind: kind) })
    }
}

extension CreditsDTO {
    var directors: [Person] {
        crew.filter { $0.job == "Director" }.uniquePeople()
    }

    var writers: [Person] {
        crew.filter { $0.department == "Writing" }.uniquePeople()
    }

    func cast(limit: Int) -> [CastMember] {
        cast.sorted { ($0.order ?? .max) < ($1.order ?? .max) }
            .prefix(limit)
            .map { CastMember(person: Person(id: $0.id, name: $0.name, profilePath: $0.profilePath.nonEmpty),
                              character: $0.character ?? "") }
    }
}

extension ReviewsDTO {
    func reviews(limit: Int) -> [Review] {
        results.prefix(limit).map {
            Review(
                id: $0.id,
                author: $0.author,
                rating: $0.authorDetails?.rating,
                content: $0.content,
                createdAt: TMDBDateParser.timestamp($0.createdAt)
            )
        }
    }
}

extension MovieDetailsDTO {
    func toDetails() -> MediaDetails {
        let summary = MediaSummary(
            id: MediaID(kind: .movie, id: id),
            title: title,
            overview: overview ?? "",
            posterPath: posterPath.nonEmpty,
            backdropPath: backdropPath.nonEmpty,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            releaseDate: TMDBDateParser.day(releaseDate)
        )
        return MediaDetails(
            summary: summary,
            tagline: tagline.nonEmpty,
            genres: genres?.map(\.name) ?? [],
            runtimeMinutes: runtime.positive,
            status: status.nonEmpty,
            originalLanguage: originalLanguage.nonEmpty,
            budget: budget.positive,
            revenue: revenue.positive,
            directors: credits?.directors ?? [],
            writers: credits?.writers ?? [],
            cast: credits?.cast(limit: MappingLimits.cast) ?? [],
            reviews: reviews?.reviews(limit: MappingLimits.reviews) ?? []
        )
    }
}

extension TVDetailsDTO {
    func toDetails() -> MediaDetails {
        let summary = MediaSummary(
            id: MediaID(kind: .tv, id: id),
            title: name,
            overview: overview ?? "",
            posterPath: posterPath.nonEmpty,
            backdropPath: backdropPath.nonEmpty,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            releaseDate: TMDBDateParser.day(firstAirDate)
        )
        return MediaDetails(
            summary: summary,
            tagline: tagline.nonEmpty,
            genres: genres?.map(\.name) ?? [],
            runtimeMinutes: episodeRunTime?.first.positive,
            seasonCount: numberOfSeasons.positive,
            episodeCount: numberOfEpisodes.positive,
            status: status.nonEmpty,
            originalLanguage: originalLanguage.nonEmpty,
            networks: networks?.map(\.name) ?? [],
            creators: (createdBy ?? []).map { Person(id: $0.id, name: $0.name, profilePath: $0.profilePath.nonEmpty) },
            cast: credits?.cast(limit: MappingLimits.cast) ?? [],
            reviews: reviews?.reviews(limit: MappingLimits.reviews) ?? []
        )
    }
}

extension ConfigurationDTO {
    func toConfiguration() throws -> ImageConfiguration {
        guard let baseURL = URL(string: images.secureBaseUrl) else {
            throw APIError.decoding("Invalid image base URL: \(images.secureBaseUrl)")
        }
        return ImageConfiguration(
            secureBaseURL: baseURL,
            posterSizes: images.posterSizes,
            backdropSizes: images.backdropSizes,
            profileSizes: images.profileSizes
        )
    }
}

private extension Array where Element == CrewDTO {
    /// People in first-seen order, each listed once even if credited for several jobs.
    func uniquePeople() -> [Person] {
        var seen = Set<Int>()
        return compactMap { member in
            guard seen.insert(member.id).inserted else { return nil }
            return Person(id: member.id, name: member.name, profilePath: member.profilePath.nonEmpty)
        }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}

private extension Optional where Wrapped == Int {
    var positive: Int? {
        guard let value = self, value > 0 else { return nil }
        return value
    }
}
