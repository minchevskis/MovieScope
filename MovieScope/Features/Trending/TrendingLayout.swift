import MovieScopeCore
import UIKit

enum TrendingSection: Int, Sendable, CaseIterable {
    /// The top trending titles as large backdrop cards in a paging row.
    case featured
    /// Everything else in an adaptive grid of posters.
    case grid
}

/// The custom compositional layout of the Trending screen.
///
/// - Featured: wide backdrop cards in an orthogonally paging row of fixed height.
/// - Grid: as many columns as fit at a minimum card width, recomputed from the
///   container width on rotation, iPad multitasking and size changes. Cells
///   self-size, so Dynamic Type works.
enum TrendingLayout {
    nonisolated static let minimumItemWidth: CGFloat = 160
    /// Wider cards at accessibility text sizes (one column on iPhone).
    nonisolated static let accessibilityMinimumItemWidth: CGFloat = 300
    nonisolated static let spacing: CGFloat = 12
    nonisolated static let horizontalInset: CGFloat = 16
    nonisolated static let featuredHeight: CGFloat = 220

    nonisolated static func columnCount(
        containerWidth: CGFloat,
        minimumItemWidth: CGFloat = minimumItemWidth,
        spacing: CGFloat = spacing,
        insets: CGFloat = horizontalInset
    ) -> Int {
        let available = containerWidth - insets * 2
        return max(1, Int((available + spacing) / (minimumItemWidth + spacing)))
    }

    /// The width of one grid card; the poster fills it (2:3).
    nonisolated static func gridItemWidth(
        containerWidth: CGFloat,
        minimumItemWidth: CGFloat = minimumItemWidth
    ) -> CGFloat {
        let columns = CGFloat(columnCount(containerWidth: containerWidth, minimumItemWidth: minimumItemWidth))
        let available = containerWidth - horizontalInset * 2
        return (available - spacing * (columns - 1)) / columns
    }

    static func make(section: @escaping @MainActor (Int) -> TrendingSection?) -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { index, environment in
            switch section(index) {
            case .featured: featuredSection(environment: environment)
            case .grid: gridSection(environment: environment)
            case nil: nil
            }
        }
    }

    private static func featuredSection(environment: any NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let isWide = environment.traitCollection.horizontalSizeClass == .regular
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(
                widthDimension: .fractionalWidth(isWide ? 0.48 : 0.86),
                heightDimension: .absolute(featuredHeight)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = spacing
        section.contentInsets = .init(top: 4, leading: horizontalInset, bottom: 24, trailing: horizontalInset)
        section.boundarySupplementaryItems = [header()]
        return section
    }

    private static func gridSection(environment: any NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let columns = columnCount(
            containerWidth: environment.container.effectiveContentSize.width,
            minimumItemWidth: minimumItemWidth(for: environment.traitCollection)
        )
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1 / CGFloat(columns)),
            heightDimension: .estimated(320)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(320)),
            repeatingSubitem: item,
            count: columns
        )
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = .init(top: 4, leading: horizontalInset, bottom: 16, trailing: horizontalInset)
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80)),
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [header(), footer]
        return section
    }

    static func minimumItemWidth(for traits: UITraitCollection) -> CGFloat {
        traits.preferredContentSizeCategory.isAccessibilityCategory ? accessibilityMinimumItemWidth : minimumItemWidth
    }

    private static func header() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}

/// Builds the diffable snapshot. Item identifiers are `MediaID`s (not whole
/// models, as Apple recommends), and each title appears in exactly one section,
/// because diffable data sources require unique identifiers.
enum TrendingSnapshotBuilder {
    static let featuredCount = 5

    static func snapshot(
        for items: [MediaSummary],
        featuredCount: Int = featuredCount
    ) -> NSDiffableDataSourceSnapshot<TrendingSection, MediaID> {
        var snapshot = NSDiffableDataSourceSnapshot<TrendingSection, MediaID>()
        let featured = items.prefix(featuredCount).map(\.id)
        let grid = items.dropFirst(featuredCount).map(\.id)
        if !featured.isEmpty {
            snapshot.appendSections([.featured])
            snapshot.appendItems(featured, toSection: .featured)
        }
        if !grid.isEmpty {
            snapshot.appendSections([.grid])
            snapshot.appendItems(grid, toSection: .grid)
        }
        return snapshot
    }
}
