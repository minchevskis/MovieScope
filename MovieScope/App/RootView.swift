import MovieScopeCore
import SwiftUI

/// Top-level navigation: a tab bar on iPhone that becomes a sidebar on iPad.
struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        if dependencies.hasCredentials {
            TabView {
                Tab("Trending", systemImage: "flame") {
                    NavigationStack {
                        TrendingScreen(
                            service: dependencies.service,
                            imageProvider: dependencies.imageProvider
                        ) { summary in
                            DetailsScreen(id: summary.id, placeholder: summary, service: dependencies.service)
                        }
                        .aboutToolbar()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Root.trendingTab)

                Tab("Search", systemImage: "magnifyingglass", role: .search) {
                    NavigationStack {
                        ContentUnavailableView("Search", systemImage: "magnifyingglass")
                            .aboutToolbar()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Root.searchTab)

                Tab("Favorites", systemImage: "heart") {
                    NavigationStack {
                        ContentUnavailableView("Favorites", systemImage: "heart")
                            .aboutToolbar()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Root.favoritesTab)
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            MissingTokenView()
        }
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
