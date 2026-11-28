import MovieScopeCore
import UIKit

/// A grid card: poster (2:3) with rating and favorite badges, title and a short
/// description. Pure UIKit; self-sizing with Auto Layout and Dynamic Type.
final class MediaGridCell: UICollectionViewCell {
    static let reuseIdentifier = "MediaGridCell"

    private let posterView = SizeReportingImageView()
    private let placeholderView = ArtworkPlaceholderView()
    private let ratingBadge = RatingBadgeView()
    private let favoriteBadge = UIImageView(image: UIImage(systemName: "heart.fill"))
    private let titleLabel = UILabel()
    private let overviewLabel = UILabel()
    private let imageLoader = CellImageLoader()

    private var posterPath: String?
    private weak var imageProvider: ImageProvider?
    private var summary: MediaSummary?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with summary: MediaSummary, isFavorite: Bool, imageProvider: ImageProvider) {
        self.summary = summary
        self.imageProvider = imageProvider
        posterPath = summary.posterPath
        titleLabel.text = summary.title
        overviewLabel.text = summary.cardDescription
        ratingBadge.setRating(summary.voteAverage, votes: summary.voteCount)
        setFavorite(isFavorite)
        loadPoster()
    }

    func setFavorite(_ isFavorite: Bool) {
        favoriteBadge.isHidden = !isFavorite
        if let summary {
            accessibilityLabel = MediaAccessibility.label(for: summary, isFavorite: isFavorite)
        }
    }

    private func loadPoster() {
        imageLoader.load(
            path: posterPath,
            category: .poster,
            into: posterView,
            provider: imageProvider,
            scale: traitCollection.displayScale
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoader.reset()
        posterView.image = nil
        summary = nil
    }

    override var isHighlighted: Bool {
        didSet {
            let appearance = Motion.pressedAppearance(
                isPressed: isHighlighted,
                reduceMotion: UIAccessibility.isReduceMotionEnabled
            )
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.contentView.transform = appearance.transform
                self.contentView.alpha = appearance.alpha
            }
        }
    }

    // MARK: - Layout

    private func configureHierarchy() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.onLayout = { [weak self] in self?.loadPoster() }

        configureBadgesAndLabels()

        // Back to front: placeholder symbol, poster (covers it once loaded), badges.
        let posterContainer = UIView()
        posterContainer.backgroundColor = .secondarySystemFill
        posterContainer.layer.cornerRadius = 12
        posterContainer.layer.cornerCurve = .continuous
        posterContainer.clipsToBounds = true
        for view in [placeholderView, posterView, ratingBadge, favoriteBadge] {
            view.translatesAutoresizingMaskIntoConstraints = false
            posterContainer.addSubview(view)
        }

        layoutContent(posterContainer: posterContainer)
    }

    private func configureBadgesAndLabels() {
        favoriteBadge.tintColor = .systemPink
        favoriteBadge.isHidden = true
        favoriteBadge.preferredSymbolConfiguration = .init(textStyle: .headline)
        favoriteBadge.layer.shadowColor = UIColor.black.cgColor
        favoriteBadge.layer.shadowOpacity = 0.4
        favoriteBadge.layer.shadowRadius = 3
        favoriteBadge.layer.shadowOffset = .zero

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        overviewLabel.font = .preferredFont(forTextStyle: .subheadline)
        overviewLabel.adjustsFontForContentSizeCategory = true
        overviewLabel.textColor = .secondaryLabel
        overviewLabel.numberOfLines = 3
    }

    private func layoutContent(posterContainer: UIView) {
        let stack = UIStackView(arrangedSubviews: [posterContainer, titleLabel, overviewLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: posterContainer)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let aspect = posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 1.5)
        aspect.priority = .required - 1
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            posterView.topAnchor.constraint(equalTo: posterContainer.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: posterContainer.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: posterContainer.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: posterContainer.bottomAnchor),
            aspect,
            placeholderView.centerXAnchor.constraint(equalTo: posterView.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: posterView.centerYAnchor),
            placeholderView.widthAnchor.constraint(equalToConstant: 32),
            placeholderView.heightAnchor.constraint(equalToConstant: 32),
            ratingBadge.leadingAnchor.constraint(equalTo: posterView.leadingAnchor, constant: 8),
            ratingBadge.bottomAnchor.constraint(equalTo: posterView.bottomAnchor, constant: -8),
            favoriteBadge.topAnchor.constraint(equalTo: posterView.topAnchor, constant: 8),
            favoriteBadge.trailingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: -8)
        ])
    }
}

/// VoiceOver text for a title card.
extension MediaSummary {
    /// A card's short description: the overview, or a note when TMDB has none.
    var cardDescription: String {
        overview.isEmpty ? "No description available." : overview
    }
}

enum MediaAccessibility {
    static func label(for summary: MediaSummary, isFavorite: Bool) -> String {
        var parts = [summary.title]
        if summary.voteCount > 0 {
            parts.append("rated \(Formatters.rating(summary.voteAverage)) out of 10")
        }
        if isFavorite {
            parts.append("favorite")
        }
        return parts.joined(separator: ", ")
    }
}
