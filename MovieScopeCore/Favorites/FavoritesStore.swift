import Foundation

/// A saved favorite: enough of the title to show it offline in the Favorites
/// list, without a network request.
public struct FavoriteItem: Codable, Hashable, Sendable, Identifiable {
    public let id: MediaID
    public let title: String
    public let posterPath: String?
    public let year: Int?
    public let addedAt: Date

    public init(id: MediaID, title: String, posterPath: String?, year: Int?, addedAt: Date) {
        self.id = id
        self.title = title
        self.posterPath = posterPath
        self.year = year
        self.addedAt = addedAt
    }

    public init(summary: MediaSummary, addedAt: Date) {
        self.init(
            id: summary.id,
            title: summary.title,
            posterPath: summary.posterPath,
            year: summary.releaseDate.map { Self.utcCalendar.component(.year, from: $0) },
            addedAt: addedAt
        )
    }

    /// A list-level summary, used as the details placeholder while it loads.
    /// Only the year is stored, so the release date is 1 January of that year
    /// (in UTC, like every TMDB date). The app only ever shows its year, and
    /// re-adding the favorite from this placeholder keeps the year.
    public var summary: MediaSummary {
        MediaSummary(
            id: id,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: 0,
            voteCount: 0,
            releaseDate: year.flatMap { Self.utcCalendar.date(from: DateComponents(year: $0, month: 1, day: 1)) }
        )
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
}

public protocol FavoritesStoring: Sendable {
    /// All favorites, newest first.
    func all() async -> [FavoriteItem]
    /// Saves `item` as a favorite, or removes it. It states the wanted result
    /// instead of flipping the current one, so it is safe to repeat, and a save
    /// that follows a failed one can't invert it.
    func set(_ item: FavoriteItem, isFavorite: Bool) async throws
}

/// Persists favorites as one JSON file. The actor serializes every read and
/// write, so concurrent saves can't lose updates. A corrupt file is treated
/// as empty (and replaced on the next save) rather than crashing the app.
public actor FavoritesStore: FavoritesStoring {
    private let fileURL: URL
    private var cache: [FavoriteItem]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func all() -> [FavoriteItem] {
        loaded().sorted { $0.addedAt > $1.addedAt }
    }

    public func set(_ item: FavoriteItem, isFavorite: Bool) throws {
        var items = loaded()
        switch (items.firstIndex { $0.id == item.id }, isFavorite) {
        case (nil, true):
            items.append(item)
        case let (index?, false):
            items.remove(at: index)
        default:
            return // Already as wanted; an existing favorite keeps its date.
        }
        try save(items)
        cache = items
    }

    private func loaded() -> [FavoriteItem] {
        if let cache { return cache }
        let items: [FavoriteItem]
        if let data = try? Data(contentsOf: fileURL) {
            do {
                items = try Self.decoder.decode([FavoriteItem].self, from: data)
            } catch {
                Log.storage.error("Favorites file is unreadable; starting empty: \(error.localizedDescription)")
                items = []
            }
        } else {
            items = []
        }
        cache = items
        return items
    }

    private func save(_ items: [FavoriteItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.encoder.encode(items).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
