import MovieScopeCore
import UIKit

/// Section title above the featured row and the grid.
final class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String) {
        label.text = title
    }
}

/// Bottom of the grid: a spinner while the next page loads, or an error with
/// a retry button. Empty otherwise.
final class LoadingFooterView: UICollectionReusableView {
    static let reuseIdentifier = "LoadingFooterView"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private let retryButton = UIButton(configuration: .bordered())
    private var onRetry: () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        retryButton.configuration?.title = "Try Again"
        retryButton.accessibilityIdentifier = AccessibilityID.Trending.retryNextPage
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry() }, for: .primaryActionTriggered)
        spinner.accessibilityIdentifier = AccessibilityID.Trending.nextPageSpinner

        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(phase: LoadPhase, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        switch phase {
        case .loadingNextPage:
            spinner.startAnimating()
            spinner.isHidden = false
            messageLabel.isHidden = true
            retryButton.isHidden = true
        case let .failed(error):
            spinner.stopAnimating()
            spinner.isHidden = true
            messageLabel.text = error.userMessage
            messageLabel.isHidden = false
            retryButton.isHidden = false
        default:
            spinner.stopAnimating()
            spinner.isHidden = true
            messageLabel.isHidden = true
            retryButton.isHidden = true
        }
    }
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
