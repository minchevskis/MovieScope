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
                        service: dependencies.service,
                        imageProvider: dependencies.imageProvider,
                        favorites: dependencies.favorites.ids,
                        onToggleFavorite: toggleFavorite,
                        destination: details
                    )
                    .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.trendingTab)

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchScreen(
                        service: dependencies.service,
                        favorites: dependencies.favorites.ids,
                        destination: details
                    )
                    .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.searchTab)

            Tab("Favorites", systemImage: "heart") {
                NavigationStack {
                    FavoritesScreen(destination: details)
                        .aboutToolbar()
                }
            }
            .accessibilityIdentifier(AccessibilityID.Root.favoritesTab)
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private func details(for summary: MediaSummary) -> some View {
        DetailsScreen(id: summary.id, placeholder: summary, service: dependencies.service) { summary in
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
