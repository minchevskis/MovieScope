import UIKit

/// "★ 7.8" capsule shown over artwork. Uses UIKit's Liquid Glass effect on
/// iOS 26 and a blur on earlier versions.
final class RatingBadgeView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let effectView = UIVisualEffectView(effect: Self.backgroundEffect())
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.clipsToBounds = true
        effectView.layer.cornerCurve = .continuous
        addSubview(effectView)

        label.font = .preferredFont(forTextStyle: .caption1).withTraits(.traitBold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -8)
        ])
        self.effectView = effectView
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private weak var effectView: UIVisualEffectView?

    func setRating(_ rating: Double, votes: Int) {
        isHidden = votes == 0
        label.text = "★ \(Formatters.rating(rating))"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView?.layer.cornerRadius = bounds.height / 2
    }

    private static func backgroundEffect() -> UIVisualEffect {
        if #available(iOS 26, *) {
            return UIGlassEffect()
        }
        return UIBlurEffect(style: .systemThinMaterial)
    }
}
