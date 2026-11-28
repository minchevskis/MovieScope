@testable import MovieScope
import MovieScopeCore
import UIKit
import XCTest

@MainActor
final class ImageProviderTests: XCTestCase {
    private static let size = CGSize(width: 100, height: 150)

    /// Both calls look up the image configuration before reaching the pipeline.
    /// A cancel that overtook its prefetch would find nothing to cancel, and the
    /// download would keep running.
    func test_cancelRightAfterPrefetch_cancelsTheDownload() async {
        let transport = HangingTransport()
        let sut = ImageProvider(
            pipeline: ImagePipeline(transport: transport),
            configurationStore: ImageConfigurationStore(
                service: FakeTMDBService(),
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
            )
        )
        // A longer prefetch takes more lookups than the one-path cancel after it.
        let paths = (0..<5).map { "/poster\($0).jpg" }

        sut.prefetch(paths: paths, category: .poster, pointSize: Self.size, scale: 2)
        sut.cancelPrefetch(paths: [paths[0]], category: .poster, pointSize: Self.size, scale: 2)

        let cancelled = await eventually { await transport.cancelledFiles.contains("poster0.jpg") }
        XCTAssertTrue(cancelled, "The cancelled prefetch kept downloading")
    }

    private func eventually(_ condition: () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }
}

/// Never answers; records which downloads started and which were cancelled.
private actor HangingTransport: HTTPTransport {
    private(set) var startedFiles: [String] = []
    private(set) var cancelledFiles: [String] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let file = request.url?.lastPathComponent ?? ""
        startedFiles.append(file)
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            cancelledFiles.append(file)
            throw error
        }
        throw URLError(.timedOut)
    }
}
