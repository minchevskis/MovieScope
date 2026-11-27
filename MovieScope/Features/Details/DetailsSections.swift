import MovieScopeCore
import SwiftUI

/// "Directed by" / "Written by" for movies, "Created by" for TV: the brief's
/// "authors".
struct PeopleSection: View {
    let details: MediaDetails

    var body: some View {
        let rows = [
            ("Directed by", details.directors),
            ("Written by", details.writers),
            ("Created by", details.creators)
        ].filter { !$0.1.isEmpty }

        if !rows.isEmpty {
            DetailsSection(details.summary.id.kind == .tv ? "Creators" : "Filmmakers") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows, id: \.0) { title, people in
                        LabeledContent(title) {
                            Text(people.map(\.name).joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Details.people)
            }
        }
    }
}

/// Top-billed cast in a horizontal row.
struct CastSection: View {
    let cast: [CastMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cast")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(cast, id: \.person.id) { member in
                        CastCard(member: member)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier(AccessibilityID.Details.cast)
    }
}

private struct CastCard: View {
    let member: CastMember

    var body: some View {
        VStack(spacing: 6) {
            RemoteImage(path: member.person.profilePath, category: .profile)
                .frame(width: 76, height: 76)
                .clipShape(.circle)
            Text(member.person.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text(member.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(width: 92)
        .accessibilityElement(children: .combine)
    }
}

/// Up to three reviews with their authors.
struct ReviewsSection: View {
    let reviews: [Review]

    var body: some View {
        DetailsSection("Reviews") {
            VStack(spacing: 12) {
                ForEach(reviews) { review in
                    ReviewCard(review: review)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Details.reviews)
        }
    }
}

private struct ReviewCard: View {
    let review: Review
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(review.author, systemImage: "person.crop.circle")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let rating = review.rating {
                    Text("★ \(Formatters.rating(rating))")
                        .font(.caption.bold())
                }
            }
            Text(review.content)
                .font(.callout)
                .lineLimit(isExpanded ? nil : 4)
            Button(isExpanded ? "Show less" : "Read more") {
                withAnimation(.snappy) { isExpanded.toggle() }
            }
            .font(.caption.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
    }
}

/// Remaining facts: status, language, budget/revenue (movie) or networks (TV).
struct FactsSection: View {
    let details: MediaDetails

    var body: some View {
        DetailsSection("Details") {
            VStack(spacing: 8) {
                if let status = details.status {
                    LabeledContent("Status", value: status)
                }
                if let language = details.originalLanguage {
                    LabeledContent("Original language", value: Formatters.languageName(language))
                }
                if let budget = details.budget {
                    LabeledContent("Budget", value: Formatters.money(budget))
                }
                if let revenue = details.revenue {
                    LabeledContent("Revenue", value: Formatters.money(revenue))
                }
                if !details.networks.isEmpty {
                    LabeledContent("Networks", value: details.networks.joined(separator: ", "))
                }
            }
            .accessibilityIdentifier(AccessibilityID.Details.facts)
        }
    }
}
