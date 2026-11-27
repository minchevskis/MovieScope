import MovieScopeCore
import SwiftUI

/// Search movies or TV shows. The Movies / TV Shows scope appears as soon as
/// the search field is focused, so the kind can be chosen before typing.
struct SearchScreen<Destination: View>: View {
    let favorites: Set<MediaID>
    @ViewBuilder let destination: (MediaSummary) -> Destination

    @State private var viewModel: SearchViewModel
    @State private var selection: MediaSummary?
    @State private var isSearchPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        service: any TMDBService,
        favorites: Set<MediaID> = [],
        @ViewBuilder destination: @escaping (MediaSummary) -> Destination
    ) {
        self.favorites = favorites
        self.destination = destination
        _viewModel = State(initialValue: SearchViewModel(service: service))
    }

    var body: some View {
        content
            .navigationTitle("Search")
            .searchable(
                text: $viewModel.query,
                isPresented: $isSearchPresented,
                placement: searchPlacement,
                prompt: "Movies or TV shows"
            )
            .searchScopes($viewModel.scope, activation: .onSearchPresentation) {
                Text("Movies").tag(MediaKind.movie)
                Text("TV Shows").tag(MediaKind.tv)
            }
            .navigationDestination(item: $selection) { summary in
                destination(summary)
            }
            // A dedicated search tab opens ready to type, with the scopes visible
            // (iPadOS otherwise collapses the field into a toolbar button).
            .onAppear { isSearchPresented = true }
    }

    /// iPhone keeps the system placement (bottom field on iOS 26). iPad pins the
    /// field and its scopes under the navigation bar instead of collapsing them
    /// into a toolbar button.
    private var searchPlacement: SearchFieldPlacement {
        horizontalSizeClass == .regular ? .navigationBarDrawer(displayMode: .always) : .automatic
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "Search Movies & TV",
                systemImage: "magnifyingglass",
                description: Text("Choose Movies or TV Shows, then type at least two characters.")
            )
            .accessibilityIdentifier(AccessibilityID.Search.idle)
        case .loading:
            LoadingStateView()
        case .empty:
            ContentUnavailableView.search(text: viewModel.activeQuery ?? viewModel.query)
                .accessibilityIdentifier(AccessibilityID.Search.empty)
        case let .failed(message):
            ErrorStateView(message: message) { Task { await viewModel.retry() } }
        case .results:
            results
        }
    }

    private var results: some View {
        List {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, summary in
                Button {
                    selection = summary
                } label: {
                    SearchResultRow(summary: summary, isFavorite: favorites.contains(summary.id))
                }
                .accessibilityIdentifier(AccessibilityID.Search.row(index))
                .onAppear {
                    Task { await viewModel.itemDisplayed(at: index) }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Search.list)
    }
}

/// One search result: thumbnail, title, year and kind, and a short overview.
struct SearchResultRow: View {
    let summary: MediaSummary
    let isFavorite: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(path: summary.posterPath, category: .poster)
                .frame(width: 60, height: 90)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !summary.overview.isEmpty {
                    Text(summary.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let kind = summary.id.kind == .movie ? "Movie" : "TV Show"
        return [Formatters.year(summary.releaseDate), kind].compactMap { $0 }.joined(separator: " · ")
    }
}
