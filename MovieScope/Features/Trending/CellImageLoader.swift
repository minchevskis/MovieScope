import MovieScopeCore
import UIKit

/// Loads a TMDB image into a reusable cell's image view at the view's rendered
/// size, protecting against the classic reuse bug: a slow image for a previous
/// item landing in a cell that now shows a different item.
///
/// Protection is twofold: `reset()` (called from `prepareForReuse`) cancels the
/// task, and a finished load is applied only if its key is still current.
@MainActor
final class CellImageLoader {
    private struct Key: Equatable {
        let path: String?
        let size: CGSize
        let scale: CGFloat
    }

    private var task: Task<Void, Never>?
    private var currentKey: Key?

    func load(
        path: String?,
        category: ImageCategory,
        into imageView: UIImageView,
        provider: ImageProvider?,
        scale: CGFloat
    ) {
        let size = CGSize(width: imageView.bounds.width.rounded(), height: imageView.bounds.height.rounded())
        guard let provider, size.width > 0, size.height > 0 else { return }
        let key = Key(path: path, size: size, scale: scale)
        guard key != currentKey else { return }
        task?.cancel()
        currentKey = key
        imageView.image = nil
        task = Task { [weak self, weak imageView] in
            let image = try? await provider.image(path: path, category: category, pointSize: size, scale: scale)
            guard let self, let imageView, !Task.isCancelled, self.currentKey == key, let image else { return }
            let options: UIView.AnimationOptions = [.transitionCrossDissolve, .allowUserInteraction]
            UIView.transition(with: imageView, duration: 0.2, options: options) {
                imageView.image = image
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        currentKey = nil
    }
}

/// An image view that reports its own layout, so a cell can start loading only
/// once the view has its final size. A cell's `layoutSubviews` runs before its
/// nested subviews are laid out, when their bounds may still be zero.
final class SizeReportingImageView: UIImageView {
    var onLayout: () -> Void = {}

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout()
    }
}
