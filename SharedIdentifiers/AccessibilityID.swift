// Shared by the app and the UI test target so identifiers can't drift apart.
nonisolated enum AccessibilityID {
    enum Root {
        static let trendingTab = "root.tab.trending"
        static let searchTab = "root.tab.search"
        static let favoritesTab = "root.tab.favorites"
        static let aboutButton = "root.about"
    }

    enum State {
        static let loading = "state.loading"
        static let error = "state.error"
        static let retryButton = "state.retry"
    }

    enum About {
        static let screen = "about.screen"
        static let attribution = "about.attribution"
    }

    enum Trending {
        static let collection = "trending.collection"
        static let retryNextPage = "trending.retryNextPage"
        static let nextPageSpinner = "trending.nextPageSpinner"

        static func item(_ index: Int) -> String { "trending.item.\(index)" }
    }

    enum Details {
        static let screen = "details.screen"
        static let rating = "details.rating"
        static let overview = "details.overview"
        static let people = "details.people"
        static let cast = "details.cast"
        static let reviews = "details.reviews"
        static let facts = "details.facts"
        static let favoriteButton = "details.favorite"
    }

    enum Search {
        static let idle = "search.idle"
        static let empty = "search.empty"
        static let list = "search.list"
        static let retryNextPage = "search.retryNextPage"

        static func row(_ index: Int) -> String { "search.row.\(index)" }
    }

    enum Favorites {
        static let empty = "favorites.empty"

        static func item(_ index: Int) -> String { "favorites.item.\(index)" }
    }

    enum MissingToken {
        static let screen = "missingToken.screen"
    }
}
