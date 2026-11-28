import MovieScopeCore
import SwiftUI

/// Saved favorites. Works offline: everything shown is stored locally, and
/// posters come from the image cache when available.
struct FavoritesScreen<Destination: View>: View {
    /// Builds the details view model when a favorite is tapped.
    let makeDetails: (MediaSummary) -> DetailsViewModel
    @ViewBuilder let destination: (DetailsViewModel) -> Destination

    @Environment(FavoritesModel.self) private var favorites
    @State private var selection: DetailsViewModel?

    var body: some View {
        content
            .navigationTitle("Favorites")
            .navigationDestination(item: $selection) { details in
                destination(details)
            }
    }

    @ViewBuilder
    private var content: some View {
        if favorites.items.isEmpty {
            ContentUnavailableView(
                "No favorites yet",
                systemImage: "heart",
                description: Text("Tap the heart on any movie or TV show to keep it here.")
            )
            .accessibilityIdentifier(AccessibilityID.Favorites.empty)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                    ForEach(Array(favorites.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            selection = makeDetails(item.summary)
                        } label: {
                            FavoriteCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.Favorites.item(index))
                        .contextMenu {
                            Button("Remove from Favorites", systemImage: "heart.slash", role: .destructive) {
                                Task { await favorites.toggle(item.summary) }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

private struct FavoriteCard: View {
    let item: FavoriteItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(path: item.posterPath, category: .poster)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let kind = item.id.kind == .movie ? "Movie" : "TV Show"
        return [item.year.map(String.init), kind].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Heart toggle used in the details toolbar.
struct FavoriteButton: View {
    let summary: MediaSummary

    @Environment(FavoritesModel.self) private var favorites
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isFavorite = favorites.isFavorite(summary.id)
        Button {
            Task { await favorites.toggle(summary) }
        } label: {
            Label(
                isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
            .symbolEffect(.bounce, value: isFavorite)
            .symbolEffectsRemoved(reduceMotion)
        }
        .tint(isFavorite ? .pink : nil)
        .accessibilityIdentifier(AccessibilityID.Details.favoriteButton)
    }
}
