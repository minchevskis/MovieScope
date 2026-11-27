/// The accumulated items of a paginated list, plus which page comes next.
///
/// Pages are merged by identity: an item already present is skipped and the
/// first occurrence keeps its position. Ranked lists such as "trending" can
/// shift between page requests, and a diffable data source requires every
/// identifier to be unique.
public struct PaginatedCollection<Item: Identifiable & Sendable>: Sendable where Item.ID: Sendable {
    /// TMDB rejects page numbers above 500 (HTTP 400), whatever `total_pages` says.
    public static var maximumPage: Int { 500 }

    public private(set) var items: [Item] = []
    /// The next page to request, or `nil` once the list is exhausted.
    public private(set) var nextPage: Int? = 1
    private var seenIDs: Set<Item.ID> = []

    public var canLoadMore: Bool { nextPage != nil }

    public init() {}

    public mutating func append(_ page: Page<Item>) {
        for item in page.items where seenIDs.insert(item.id).inserted {
            items.append(item)
        }
        let lastPage = min(page.totalPages, Self.maximumPage)
        nextPage = page.page < lastPage ? page.page + 1 : nil
    }

    public mutating func reset() {
        self = PaginatedCollection()
    }
}
