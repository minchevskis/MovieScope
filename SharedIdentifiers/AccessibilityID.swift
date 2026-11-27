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

    enum MissingToken {
        static let screen = "missingToken.screen"
    }
}
