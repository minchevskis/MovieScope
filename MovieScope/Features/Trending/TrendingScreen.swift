import MovieScopeCore
import SwiftUI

/// Main screen: weekly trending movies.
struct TrendingScreen<Destination: View>: View {
    let viewModel: TrendingViewModel
    let imageProvider: ImageProvider
    var favorites: Set<MediaID> = []
    var onToggleFavorite: (MediaSummary) -> Void = { _ in }
    /// Builds the details view model when a title is tapped.
    let makeDetails: (MediaSummary) -> DetailsViewModel
    @ViewBuilder let destination: (DetailsViewModel) -> Destination

    @State private var selection: DetailsViewModel?

    var body: some View {
        content
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selection) { details in
                destination(details)
            }
            .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty {
            switch viewModel.phase {
            case .failed:
                ErrorStateView(message: viewModel.errorMessage ?? "") { Task { await viewModel.retry() } }
            case .exhausted:
                ContentUnavailableView("Nothing trending right now", systemImage: "film.stack")
            default:
                LoadingStateView()
            }
        } else {
            TrendingCollectionView(
                items: viewModel.items,
                phase: viewModel.phase,
                favorites: favorites,
                imageProvider: imageProvider,
                onSelect: { selection = makeDetails($0) },
                onDisplayIndex: { index in Task { await viewModel.itemDisplayed(at: index) } },
                onRefresh: { Task { await viewModel.refresh() } },
                onRetry: { Task { await viewModel.retry() } },
                onToggleFavorite: onToggleFavorite
            )
            .ignoresSafeArea()
        }
    }
}
