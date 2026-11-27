import MovieScopeCore
import SwiftUI

/// Main screen: weekly trending movies.
struct TrendingScreen<Destination: View>: View {
    let imageProvider: ImageProvider
    let favorites: Set<MediaID>
    @ViewBuilder let destination: (MediaSummary) -> Destination

    @State private var viewModel: TrendingViewModel
    @State private var selection: MediaSummary?

    init(
        service: any TMDBService,
        imageProvider: ImageProvider,
        favorites: Set<MediaID> = [],
        @ViewBuilder destination: @escaping (MediaSummary) -> Destination
    ) {
        self.imageProvider = imageProvider
        self.favorites = favorites
        self.destination = destination
        _viewModel = State(initialValue: TrendingViewModel(service: service))
    }

    var body: some View {
        content
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selection) { summary in
                destination(summary)
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
                onSelect: { selection = $0 },
                onDisplayIndex: { index in Task { await viewModel.itemDisplayed(at: index) } },
                onRefresh: { Task { await viewModel.refresh() } },
                onRetry: { Task { await viewModel.retry() } }
            )
            .ignoresSafeArea()
        }
    }
}
