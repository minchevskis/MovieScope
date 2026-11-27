@testable import MovieScope
import MovieScopeCore
import UIKit
import XCTest

/// The reused-cell protection: a slow image for a previous item must never land
/// in a cell that now shows another item.
@MainActor
final class CellImageLoaderTests: XCTestCase {
    func test_slowImageForPreviousPath_isNotApplied() async {
        let loader = ControlledImageLoader()
        let sut = CellImageLoader()
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 150))

        sut.load(path: "/a.jpg", category: .poster, into: imageView, provider: loader, scale: 1)
        sut.load(path: "/b.jpg", category: .poster, into: imageView, provider: loader, scale: 1)
        await loader.waitForRequests(2)
        loader.resolve("/a.jpg", with: Self.image(.red))
        await Task.yield()
        XCTAssertNil(imageView.image, "The stale image for /a.jpg must not be shown")

        let expected = Self.image(.blue)
        loader.resolve("/b.jpg", with: expected)
        await waitUntil { imageView.image != nil }
        XCTAssertTrue(imageView.image === expected)
    }

    func test_reset_dropsInFlightImage() async {
        let loader = ControlledImageLoader()
        let sut = CellImageLoader()
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 150))

        sut.load(path: "/a.jpg", category: .poster, into: imageView, provider: loader, scale: 1)
        await loader.waitForRequests(1)
        sut.reset()
        loader.resolve("/a.jpg", with: Self.image(.red))
        await Task.yield()
        await Task.yield()

        XCTAssertNil(imageView.image)
    }

    private static func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
    }
}

@MainActor
private final class ControlledImageLoader: ImageLoading {
    private var pending: [String: CheckedContinuation<UIImage?, any Error>] = [:]
    private(set) var requested: [String] = []

    func image(path: String?, category: ImageCategory, pointSize: CGSize, scale: CGFloat) async throws -> UIImage? {
        let key = path ?? ""
        requested.append(key)
        return try await withCheckedThrowingContinuation { pending[key] = $0 }
    }

    func resolve(_ path: String, with image: UIImage) {
        pending.removeValue(forKey: path)?.resume(returning: image)
    }

    func waitForRequests(_ count: Int) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while requested.count < count, ContinuousClock.now < deadline { await Task.yield() }
    }
}
