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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        self.init(
            id: summary.id,
            title: summary.title,
            posterPath: summary.posterPath,
            year: summary.releaseDate.map { calendar.component(.year, from: $0) },
            addedAt: addedAt
        )
    }

    /// A list-level summary, used as the details placeholder while it loads.
    public var summary: MediaSummary {
        MediaSummary(
            id: id,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            voteAverage: 0,
            voteCount: 0,
            releaseDate: nil
        )
    }
}

public protocol FavoritesStoring: Sendable {
    /// All favorites, newest first.
    func all() async -> [FavoriteItem]
    /// Adds the item if absent, removes it if present. Returns `true` when it
    /// is a favorite afterwards.
    @discardableResult
    func toggle(_ item: FavoriteItem) async throws -> Bool
}

/// Persists favorites as one JSON file. The actor serializes every read and
/// write, so concurrent toggles can't lose updates. A corrupt file is treated
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

    @discardableResult
    public func toggle(_ item: FavoriteItem) throws -> Bool {
        var items = loaded()
        let isFavorite: Bool
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            isFavorite = false
        } else {
            items.append(item)
            isFavorite = true
        }
        try save(items)
        cache = items
        return isFavorite
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
