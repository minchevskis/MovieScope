import MovieScopeCore
import SwiftUI

/// Top-level navigation: a tab bar on iPhone that becomes a sidebar on iPad.
struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        if dependencies.hasCredentials {
            tabs
                .task { await dependencies.favorites.load() }
        } else {
            MissingTokenView()
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Trending", systemImage: "flame") {
                NavigationStack {
                    TrendingScreen(
                        viewModel: dependencies.trending,
                        imageProvider: dependencies.imageProvider,
                        favorites: dependencies.favorites.ids,
                        onToggleFavorite: toggleFavorite,
                        makeDetails: dependencies.makeDetails(for:),
                        destination: details
                    )
                    .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.trendingTab)

            // A plain tab on purpose: with `role: .search`, iOS 26 merges the field
            // into the tab bar and shows the Movies / TV Shows scopes only the
            // first time search opens (SearchUITests covers reopening).
            Tab("Search", systemImage: "magnifyingglass") {
                NavigationStack {
                    SearchScreen(
                        viewModel: dependencies.search,
                        favorites: dependencies.favorites.ids,
                        makeDetails: dependencies.makeDetails(for:),
                        destination: details
                    )
                    .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.searchTab)

            Tab("Favorites", systemImage: "heart") {
                NavigationStack {
                    FavoritesScreen(makeDetails: dependencies.makeDetails(for:), destination: details)
                        .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.favoritesTab)
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private func details(_ viewModel: DetailsViewModel) -> some View {
        DetailsScreen(viewModel: viewModel) { summary in
            FavoriteButton(summary: summary)
        }
    }

    private func toggleFavorite(_ summary: MediaSummary) {
        Task { await dependencies.favorites.toggle(summary) }
    }
}

private struct AboutToolbar: ViewModifier {
    @State private var showsAbout = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("About", systemImage: "info.circle") { showsAbout = true }
                        .accessibilityIdentifier(AccessibilityID.Root.aboutButton)
                }
            }
            .sheet(isPresented: $showsAbout) { AboutScreen() }
    }
}

extension View {
    /// Adds the "About" toolbar button that presents the attribution screen.
    func aboutToolbar() -> some View {
        modifier(AboutToolbar())
    }
}
