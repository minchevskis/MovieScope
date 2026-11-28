import MovieScopeCore
import UIKit

/// A wide backdrop card for the featured row, with the title over a gradient.
final class FeaturedCell: UICollectionViewCell {
    static let reuseIdentifier = "FeaturedCell"

    private let backdropView = SizeReportingImageView()
    private let placeholderView = ArtworkPlaceholderView()
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let ratingBadge = RatingBadgeView()
    private let favoriteBadge = UIImageView(image: UIImage(systemName: "heart.fill"))
    private let imageLoader = CellImageLoader()

    private var backdropPath: String?
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
        backdropPath = summary.backdropPath ?? summary.posterPath
        titleLabel.text = summary.title
        ratingBadge.setRating(summary.voteAverage, votes: summary.voteCount)
        setFavorite(isFavorite)
        loadBackdrop()
    }

    func setFavorite(_ isFavorite: Bool) {
        favoriteBadge.isHidden = !isFavorite
        if let summary {
            accessibilityLabel = MediaAccessibility.label(for: summary, isFavorite: isFavorite)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    private func loadBackdrop() {
        imageLoader.load(
            path: backdropPath,
            category: summary?.backdropPath == nil ? .poster : .backdrop,
            into: backdropView,
            provider: imageProvider,
            scale: traitCollection.displayScale
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoader.reset()
        backdropView.image = nil
        summary = nil
    }

    private func configureHierarchy() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        contentView.backgroundColor = .secondarySystemFill

        backdropView.contentMode = .scaleAspectFill
        backdropView.clipsToBounds = true
        backdropView.onLayout = { [weak self] in self?.loadBackdrop() }
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor]
        gradientLayer.locations = [0.45, 1]

        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7

        favoriteBadge.tintColor = .systemPink
        favoriteBadge.isHidden = true
        favoriteBadge.preferredSymbolConfiguration = .init(textStyle: .title3)

        // Back to front: placeholder symbol, backdrop (covers it once loaded), text and badges.
        for view in [placeholderView, backdropView, titleLabel, ratingBadge, favoriteBadge] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        contentView.layer.insertSublayer(gradientLayer, above: backdropView.layer)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            placeholderView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -16),
            placeholderView.widthAnchor.constraint(equalToConstant: 44),
            placeholderView.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: ratingBadge.leadingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            ratingBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ratingBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            favoriteBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            favoriteBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
        ratingBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
