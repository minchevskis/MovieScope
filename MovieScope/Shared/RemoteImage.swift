import MovieScopeCore
import SwiftUI

/// Shows a TMDB image fetched at the size it is rendered at. Loading restarts
/// when the path or rendered size changes, and is cancelled automatically when
/// the view disappears.
struct RemoteImage: View {
    let path: String?
    let category: ImageCategory
    /// Show any cached variant of the same artwork immediately (low-res first).
    var usesCachedPreview = false

    @Environment(\.imageProvider) private var imageProvider
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var renderedSize: CGSize = .zero

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: placeholderSymbol)
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
            .clipped()
            .onGeometryChange(for: CGSize.self) { proxy in
                // Whole points only, so sub-point layout jitter doesn't restart loads.
                CGSize(width: proxy.size.width.rounded(), height: proxy.size.height.rounded())
            } action: { size in
                renderedSize = size
            }
            .task(id: LoadKey(path: path, size: renderedSize, scale: displayScale)) {
                await load()
            }
            .accessibilityHidden(true)
    }

    private var placeholderSymbol: String {
        category == .profile ? "person.fill" : "film"
    }

    private func load() async {
        guard let imageProvider, renderedSize.width > 0 else { return }
        if usesCachedPreview, image == nil, let preview = await imageProvider.cachedPreview(path: path) {
            image = preview
        }
        do {
            let loaded = try await imageProvider.image(
                path: path,
                category: category,
                pointSize: renderedSize,
                scale: displayScale
            )
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        } catch {
            // Keep the placeholder; failures are logged by the core.
        }
    }

    private struct LoadKey: Equatable {
        let path: String?
        let size: CGSize
        let scale: CGFloat
    }
}
