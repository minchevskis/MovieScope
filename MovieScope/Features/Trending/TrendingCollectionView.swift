import MovieScopeCore
import SwiftUI

/// Bridges the UIKit `TrendingViewController` into SwiftUI. SwiftUI owns the
/// state (via `TrendingViewModel`); the controller only renders it and reports
/// user events back through closures.
struct TrendingCollectionView: UIViewControllerRepresentable {
    let items: [MediaSummary]
    let phase: LoadPhase
    let favorites: Set<MediaID>
    let imageProvider: ImageProvider
    let onSelect: (MediaSummary) -> Void
    let onDisplayIndex: (Int) -> Void
    let onRefresh: () -> Void
    let onRetry: () -> Void

    func makeUIViewController(context: Context) -> TrendingViewController {
        TrendingViewController(imageProvider: imageProvider)
    }

    func updateUIViewController(_ controller: TrendingViewController, context: Context) {
        controller.onSelect = onSelect
        controller.onDisplayIndex = onDisplayIndex
        controller.onRefresh = onRefresh
        controller.onRetry = onRetry
        controller.update(items: items, phase: phase, favorites: favorites)
    }
}
