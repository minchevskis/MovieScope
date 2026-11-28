import MovieScopeCore
import UIKit

/// UIKit Trending grid: `UICollectionView` + custom compositional layout +
/// diffable data source keyed by `MediaID`, with prefetching and pull-to-refresh.
/// Hosted in SwiftUI through `TrendingCollectionView`.
final class TrendingViewController: UIViewController {
    var onSelect: (MediaSummary) -> Void = { _ in }
    var onDisplayIndex: (Int) -> Void = { _ in }
    var onRefresh: () -> Void = {}
    var onRetry: () -> Void = {}
    var onToggleFavorite: (MediaSummary) -> Void = { _ in }

    private let imageProvider: ImageProvider
    private var itemsByID: [MediaID: MediaSummary] = [:]
    private var indexByID: [MediaID: Int] = [:]
    private var orderedIDs: [MediaID] = []
    private var favorites: Set<MediaID> = []
    private var phase: LoadPhase = .idle

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var dataSource = makeDataSource()
    private let refreshControl = UIRefreshControl()

    init(imageProvider: ImageProvider) {
        self.imageProvider = imageProvider
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.frame = view.bounds
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.accessibilityIdentifier = AccessibilityID.Trending.collection
        collectionView.register(MediaGridCell.self, forCellWithReuseIdentifier: MediaGridCell.reuseIdentifier)
        collectionView.register(FeaturedCell.self, forCellWithReuseIdentifier: FeaturedCell.reuseIdentifier)
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.reuseIdentifier
        )
        collectionView.register(
            LoadingFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LoadingFooterView.reuseIdentifier
        )
        refreshControl.addAction(UIAction { [weak self] _ in self?.onRefresh() }, for: .valueChanged)
        collectionView.refreshControl = refreshControl
        view.addSubview(collectionView)
    }

    /// Applies new state from SwiftUI. Cheap when nothing changed.
    func update(items: [MediaSummary], phase: LoadPhase, favorites: Set<MediaID>) {
        let ids = items.map(\.id)
        // Same titles can come back with new content (a refresh with new ratings).
        if ids != orderedIDs || items.contains(where: { itemsByID[$0.id] != $0 }) {
            let snapshot = TrendingSnapshotBuilder.snapshot(for: items, previous: itemsByID)
            itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            indexByID = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let isFirstLoad = orderedIDs.isEmpty
            orderedIDs = ids
            dataSource.apply(snapshot, animatingDifferences: !isFirstLoad)
        }
        if favorites != self.favorites {
            let changed = favorites.symmetricDifference(self.favorites)
            self.favorites = favorites
            reconfigure(changed)
        }
        if phase != self.phase {
            self.phase = phase
            updateFooters()
            if !phase.isLoading, refreshControl.isRefreshing {
                refreshControl.endRefreshing()
            }
        }
    }

    // MARK: - Layout and data source

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        TrendingLayout.make { [weak self] index in
            self?.dataSource.sectionIdentifier(for: index)
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<TrendingSection, MediaID> {
        let dataSource = UICollectionViewDiffableDataSource<TrendingSection, MediaID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, id in
            self?.cell(in: collectionView, at: indexPath, for: id)
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            self?.supplementaryView(in: collectionView, kind: kind, at: indexPath)
        }
        return dataSource
    }

    private func cell(
        in collectionView: UICollectionView,
        at indexPath: IndexPath,
        for id: MediaID
    ) -> UICollectionViewCell? {
        guard let summary = itemsByID[id] else { return nil }
        let isFavorite = favorites.contains(id)
        let identifier = AccessibilityID.Trending.item(indexByID[id] ?? indexPath.item)
        switch dataSource.sectionIdentifier(for: indexPath.section) {
        case .featured:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FeaturedCell.reuseIdentifier,
                for: indexPath
            )
            (cell as? FeaturedCell)?.configure(with: summary, isFavorite: isFavorite, imageProvider: imageProvider)
            cell.accessibilityIdentifier = identifier
            return cell
        case .grid, nil:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: MediaGridCell.reuseIdentifier,
                for: indexPath
            )
            (cell as? MediaGridCell)?.configure(with: summary, isFavorite: isFavorite, imageProvider: imageProvider)
            cell.accessibilityIdentifier = identifier
            return cell
        }
    }

    private func supplementaryView(
        in collectionView: UICollectionView,
        kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView? {
        if kind == UICollectionView.elementKindSectionFooter {
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LoadingFooterView.reuseIdentifier,
                for: indexPath
            )
            (footer as? LoadingFooterView)?.configure(phase: phase) { [weak self] in self?.onRetry() }
            return footer
        }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: SectionHeaderView.reuseIdentifier,
            for: indexPath
        )
        let isFeatured = dataSource.sectionIdentifier(for: indexPath.section) == .featured
        (header as? SectionHeaderView)?.configure(title: isFeatured ? "Top This Week" : "Trending Now")
        return header
    }

    private func reconfigure(_ ids: Set<MediaID>) {
        var snapshot = dataSource.snapshot()
        let present = ids.filter { snapshot.indexOfItem($0) != nil }
        guard !present.isEmpty else { return }
        snapshot.reconfigureItems(Array(present))
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateFooters() {
        let kind = UICollectionView.elementKindSectionFooter
        for case let footer as LoadingFooterView in collectionView.visibleSupplementaryViews(ofKind: kind) {
            footer.configure(phase: phase) { [weak self] in self?.onRetry() }
        }
        // The footer's content changed height (spinner ↔ message + button): re-measure it.
        let indexPaths = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind)
        guard !indexPaths.isEmpty else { return }
        let context = UICollectionViewLayoutInvalidationContext()
        context.invalidateSupplementaryElements(ofKind: kind, at: indexPaths)
        collectionView.collectionViewLayout.invalidateLayout(with: context)
    }

    /// Poster size of a grid cell at the current width; prefetches must use
    /// the same size the cells render at, so they hit the same cache entries.
    private var gridPosterSize: CGSize {
        let width = TrendingLayout.gridItemWidth(
            containerWidth: collectionView.bounds.width,
            minimumItemWidth: TrendingLayout.minimumItemWidth(for: traitCollection)
        )
        return CGSize(width: width.rounded(), height: (width * 1.5).rounded())
    }

    private func gridPosterPaths(at indexPaths: [IndexPath]) -> [String] {
        indexPaths.compactMap { indexPath in
            guard dataSource.sectionIdentifier(for: indexPath.section) == .grid,
                  let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
            return itemsByID[id]?.posterPath
        }
    }
}

extension TrendingViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let summary = itemsByID[id] else { return }
        onSelect(summary)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let id = dataSource.itemIdentifier(for: indexPath),
              let summary = itemsByID[id] else { return nil }
        let isFavorite = favorites.contains(id)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let toggle = UIAction(
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                image: UIImage(systemName: isFavorite ? "heart.slash" : "heart"),
                attributes: isFavorite ? .destructive : []
            ) { _ in
                self?.onToggleFavorite(summary)
            }
            return UIMenu(children: [toggle])
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let index = indexByID[id] else { return }
        onDisplayIndex(index)
    }
}

extension TrendingViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let paths = gridPosterPaths(at: indexPaths)
        guard !paths.isEmpty else { return }
        imageProvider.prefetch(
            paths: paths,
            category: .poster,
            pointSize: gridPosterSize,
            scale: traitCollection.displayScale
        )
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let paths = gridPosterPaths(at: indexPaths)
        guard !paths.isEmpty else { return }
        imageProvider.cancelPrefetch(
            paths: paths,
            category: .poster,
            pointSize: gridPosterSize,
            scale: traitCollection.displayScale
        )
    }
}
