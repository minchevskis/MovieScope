import Foundation
import MovieScopeCore
import Observation

/// Loads the full details of one movie or TV show. While loading, the screen
/// shows what it already knows from the list (the placeholder summary).
@MainActor
@Observable
final class DetailsViewModel {
    enum State: Equatable {
        case loading
        case loaded(MediaDetails)
        case failed(String)
    }

    let id: MediaID
    private(set) var state: State = .loading

    private let placeholder: MediaSummary?
    private let service: any TMDBService

    init(id: MediaID, placeholder: MediaSummary?, service: any TMDBService) {
        self.id = id
        self.placeholder = placeholder
        self.service = service
    }

    var details: MediaDetails? {
        guard case let .loaded(details) = state else { return nil }
        return details
    }

    /// The best summary available: the loaded one, else the list placeholder.
    var summary: MediaSummary? { details?.summary ?? placeholder }

    var title: String { summary?.title ?? "" }

    func load() async {
        guard details == nil else { return }
        await fetch()
    }

    func retry() async {
        await fetch()
    }

    private func fetch() async {
        state = .loading
        do {
            state = .loaded(try await service.details(for: id))
        } catch {
            let apiError = APIError(error)
            guard apiError != .cancelled else { return }
            state = .failed(apiError.userMessage)
        }
    }
}

/// Text built from details for the header.
nonisolated enum DetailsFormatting {
    /// "2024 · 2h 15m · Action, Sci-Fi" for movies; "5 seasons · 62 episodes" for TV.
    static func metadataLine(for details: MediaDetails) -> String {
        var parts: [String] = []
        if let year = Formatters.year(details.summary.releaseDate) {
            parts.append(year)
        }
        switch details.summary.id.kind {
        case .movie:
            if let minutes = details.runtimeMinutes {
                parts.append(Formatters.runtime(minutes: minutes))
            }
        case .tv:
            if let seasons = details.seasonCount {
                parts.append(seasons == 1 ? "1 season" : "\(seasons) seasons")
            }
            if let episodes = details.episodeCount {
                parts.append(episodes == 1 ? "1 episode" : "\(episodes) episodes")
            }
        }
        if !details.genres.isEmpty {
            parts.append(details.genres.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    /// Spoken/visible rating summary; unreleased titles have no votes yet.
    static func ratingDescription(average: Double, votes: Int, locale: Locale = .current) -> String {
        guard votes > 0 else { return "Not rated yet" }
        let score = Formatters.rating(average, locale: locale)
        return "Rated \(score) out of 10 from \(Formatters.votes(votes, locale: locale))"
    }
}
