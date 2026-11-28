import MovieScopeCore
import SwiftUI

/// Scrollable details for a movie or TV show. The view model comes from the
/// screen that pushed it, which created it when the title was tapped.
struct DetailsScreen<Accessory: View>: View {
    let viewModel: DetailsViewModel
    @ViewBuilder let accessory: (MediaSummary) -> Accessory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let summary = viewModel.summary {
                    DetailsHeaderView(summary: summary, details: viewModel.details)
                }
                content
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let summary = viewModel.summary {
                ToolbarItem(placement: .topBarTrailing) { accessory(summary) }
            }
        }
        .task { await viewModel.load() }
        .accessibilityIdentifier(AccessibilityID.Details.screen)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        case let .failed(message):
            ErrorStateView(message: message) { Task { await viewModel.retry() } }
        case let .loaded(details):
            DetailsBody(details: details)
        }
    }
}

extension DetailsScreen where Accessory == EmptyView {
    init(viewModel: DetailsViewModel) {
        self.init(viewModel: viewModel) { _ in EmptyView() }
    }
}

/// The sections below the header, once details are loaded.
private struct DetailsBody: View {
    let details: MediaDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            RatingView(average: details.summary.voteAverage, votes: details.summary.voteCount)
                .padding(.horizontal)
            if !details.summary.overview.isEmpty {
                DetailsSection("Overview") {
                    Text(details.summary.overview)
                        .font(.body)
                        .accessibilityIdentifier(AccessibilityID.Details.overview)
                }
            }
            PeopleSection(details: details)
            if !details.cast.isEmpty {
                CastSection(cast: details.cast)
            }
            if !details.reviews.isEmpty {
                ReviewsSection(reviews: details.reviews)
            }
            FactsSection(details: details)
        }
    }
}

/// A titled block with standard padding.
struct DetailsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
