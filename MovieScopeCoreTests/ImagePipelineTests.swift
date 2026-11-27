import Foundation
@testable import MovieScopeCore
import XCTest

final class ImageDownsamplerTests: XCTestCase {
    func test_downsample_respectsMaxPixelSize() throws {
        let data = PlaceholderImageFactory.pngData(width: 1000, height: 1500)

        let image = try ImageDownsampler.downsample(data, maxPixelSize: 300)

        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 300)
    }

    func test_downsample_invalidData_throws() {
        XCTAssertThrowsError(try ImageDownsampler.downsample(Data("nope".utf8), maxPixelSize: 100))
    }

    func test_placeholderFactory_isDeterministic() {
        XCTAssertEqual(
            PlaceholderImageFactory.pngData(width: 10, height: 10, seed: 3),
            PlaceholderImageFactory.pngData(width: 10, height: 10, seed: 3)
        )
    }
}

final class ImagePipelineTests: XCTestCase {
    private let posterURL = URL(fileURLWithPath: "/t/p/w342/poster.jpg")
    private let png = PlaceholderImageFactory.pngData(width: 342, height: 513)

    func test_pipeline_memoryHit_skipsTransport() async throws {
        let transport = FakeTransport([.response(status: 200, body: png)])
        let sut = ImagePipeline(transport: transport)
        let request = ImageRequest(url: posterURL, maxPixelSize: 300)

        _ = try await sut.image(for: request)
        let second = try await sut.image(for: request)

        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(second.height, 300)
    }

    func test_pipeline_concurrentSameRequest_fetchesOnce() async throws {
        let transport = ControlledTransport()
        let sut = ImagePipeline(transport: transport)
        let request = ImageRequest(url: posterURL, maxPixelSize: 300)

        async let first = sut.image(for: request)
        async let second = sut.image(for: request)
        await transport.waitForRequests(1)
        await transport.respond(to: posterURL, body: png)
        let images = try await [first, second]

        let urls = await transport.requestedURLs
        XCTAssertEqual(urls, [posterURL])
        XCTAssertEqual(images.count, 2)
    }

    func test_pipeline_cancellingOnlyWaiter_cancelsDownload() async throws {
        let transport = ControlledTransport()
        let sut = ImagePipeline(transport: transport)

        let request = ImageRequest(url: posterURL, maxPixelSize: 300)
        let task = Task { try await sut.image(for: request) }
        await transport.waitForRequests(1)
        task.cancel()

        await transport.waitForCancellations(1)
        let result = await task.result
        XCTAssertThrowsError(try result.get())
    }

    func test_pipeline_prefetch_populatesCache() async throws {
        let transport = FakeTransport([.response(status: 200, body: png)])
        let sut = ImagePipeline(transport: transport)
        let request = ImageRequest(url: posterURL, maxPixelSize: 300)

        await sut.prefetch([request])
        await waitUntil { await sut.cachedImage(for: request) != nil }

        let image = try await sut.image(for: request)
        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(image.height, 300)
    }

    func test_pipeline_cancelPrefetch_cancelsDownload() async {
        let transport = ControlledTransport()
        let sut = ImagePipeline(transport: transport)
        let request = ImageRequest(url: posterURL, maxPixelSize: 300)

        await sut.prefetch([request])
        await transport.waitForRequests(1)
        await sut.cancelPrefetch([request])

        await transport.waitForCancellations(1)
        let cached = await sut.cachedImage(for: request)
        XCTAssertNil(cached)
    }

    func test_pipeline_httpError_throws() async {
        let sut = ImagePipeline(transport: FakeTransport([.response(status: 404, body: Data())]))

        let request = ImageRequest(url: posterURL, maxPixelSize: 300)
        await assertThrows(APIError.notFound) {
            _ = try await sut.image(for: request)
        }
    }

    func test_pipeline_differentSizes_areCachedSeparately() async throws {
        let transport = FakeTransport([.response(status: 200, body: png), .response(status: 200, body: png)])
        let sut = ImagePipeline(transport: transport)

        let small = try await sut.image(for: ImageRequest(url: posterURL, maxPixelSize: 100))
        let large = try await sut.image(for: ImageRequest(url: posterURL, maxPixelSize: 400))

        XCTAssertEqual(small.height, 100)
        XCTAssertEqual(large.height, 400)
    }

    func test_largestCachedImage_returnsBiggestVariantForPath() async throws {
        let transport = FakeTransport([.response(status: 200, body: png), .response(status: 200, body: png)])
        let sut = ImagePipeline(transport: transport)
        let smallURL = URL(fileURLWithPath: "/t/p/w92/poster.jpg")
        _ = try await sut.image(for: ImageRequest(url: smallURL, maxPixelSize: 100))
        _ = try await sut.image(for: ImageRequest(url: posterURL, maxPixelSize: 300))

        let preview = await sut.largestCachedImage(forImagePath: "/poster.jpg")

        XCTAssertEqual(preview?.height, 300)
    }

    func test_largestCachedImage_unknownPath_isNil() async {
        let preview = await ImagePipeline(transport: FakeTransport()).largestCachedImage(forImagePath: "/missing.jpg")

        XCTAssertNil(preview)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while await !condition(), ContinuousClock.now < deadline {
            await Task.yield()
        }
    }
}
