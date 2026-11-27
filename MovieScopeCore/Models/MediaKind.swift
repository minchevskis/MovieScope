/// The two kinds of titles the app shows. TMDB serves them from separate
/// endpoints with slightly different fields (`title` vs `name`, etc.).
public enum MediaKind: String, Sendable, Codable, CaseIterable {
    case movie
    case tv
}

/// Stable identity for a title. TMDB doesn't document whether movie and TV ids
/// can collide, so identity always includes the kind.
public struct MediaID: Hashable, Sendable, Codable {
    public let kind: MediaKind
    public let id: Int

    public init(kind: MediaKind, id: Int) {
        self.kind = kind
        self.id = id
    }
}
