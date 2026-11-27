import MovieScopeCore
import SwiftUI

/// Backdrop with the poster, title and key facts. Poster and text sit side by
/// side in regular width (iPad, large iPhones in landscape).
struct DetailsHeaderView: View {
    let summary: MediaSummary
    let details: MediaDetails?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RemoteImage(path: summary.backdropPath ?? summary.posterPath, category: .backdrop)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                }

            Group {
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        poster.frame(width: 160)
                        titleBlock
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 16) {
                        poster.frame(width: 110)
                        titleBlock
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, -64)
        }
    }

    private var poster: some View {
        RemoteImage(path: summary.posterPath, category: .poster)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let tagline = details?.tagline {
                Text(tagline)
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
            }
            if let details {
                Text(DetailsFormatting.metadataLine(for: details))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Average rating out of 10 and vote count, on glass (iOS 26) or material.
struct RatingView: View {
    let average: Double
    let votes: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: votes > 0 ? "star.fill" : "star")
                .foregroundStyle(.yellow)
            if votes > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Formatters.rating(average))
                        .font(.title2.bold())
                    Text("/ 10")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 20)
                Text(Formatters.votes(votes))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not rated yet")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassOrMaterial()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DetailsFormatting.ratingDescription(average: average, votes: votes))
        .accessibilityIdentifier(AccessibilityID.Details.rating)
    }
}
