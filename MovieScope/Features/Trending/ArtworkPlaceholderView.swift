import UIKit

/// The symbol a card shows where its artwork is missing or still loading.
/// Cards place it behind the artwork, so a loaded image covers it.
final class ArtworkPlaceholderView: UIImageView {
    init() {
        super.init(image: UIImage(systemName: "film"))
        tintColor = .tertiaryLabel
        contentMode = .scaleAspectFit
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
