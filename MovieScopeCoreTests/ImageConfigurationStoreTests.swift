import Foundation
@testable import MovieScopeCore
import XCTest

final class ImageConfigurationStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 3600

    func test_store_noCache_fetchesAndPersists() async throws {
        let fileURL = temporaryFileURL()
        let service = StubConfigurationService([.success(Self.remote)])
        let sut = makeSUT(service: service, fileURL: fileURL)

        let configuration = await sut.current()

        XCTAssertEqual(configuration, Self.remote)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path()))
        let calls = await service.configurationCalls
        XCTAssertEqual(calls, 1)
    }

    func test_store_freshCache_doesNotFetch() async throws {
        let fileURL = temporaryFileURL()
        try ImageConfigurationStore.persist(Self.remote, fetchedAt: now.addingTimeInterval(-day), to: fileURL)
        let service = StubConfigurationService([])
        let sut = makeSUT(service: service, fileURL: fileURL)

        let configuration = await sut.current()

        XCTAssertEqual(configuration, Self.remote)
        let calls = await service.configurationCalls
        XCTAssertEqual(calls, 0)
    }

    func test_store_staleCache_fetchesAndPersists() async throws {
        let fileURL = temporaryFileURL()
        try ImageConfigurationStore.persist(Self.remote, fetchedAt: now.addingTimeInterval(-8 * day), to: fileURL)
        let refreshed = ImageConfiguration(secureBaseURL: Self.remote.secureBaseURL, posterSizes: ["w500"], backdropSizes: [], profileSizes: [])
        let service = StubConfigurationService([.success(refreshed)])
        let sut = makeSUT(service: service, fileURL: fileURL)

        let configuration = await sut.current()

        XCTAssertEqual(configuration, refreshed)
        let reloaded = makeSUT(service: StubConfigurationService([]), fileURL: fileURL)
        let persisted = await reloaded.current()
        XCTAssertEqual(persisted, refreshed)
    }

    func test_store_fetchFails_returnsStaleThenFallback() async throws {
        let staleURL = temporaryFileURL()
        try ImageConfigurationStore.persist(Self.remote, fetchedAt: now.addingTimeInterval(-30 * day), to: staleURL)
        let withStale = makeSUT(service: StubConfigurationService([.failure(APIError.transport(.notConnectedToInternet))]), fileURL: staleURL)
        let withoutCache = makeSUT(service: StubConfigurationService([.failure(APIError.unauthorized)]), fileURL: temporaryFileURL())

        let stale = await withStale.current()
        let fallback = await withoutCache.current()

        XCTAssertEqual(stale, Self.remote)
        XCTAssertEqual(fallback, .fallback)
    }

    func test_store_concurrentCalls_fetchOnce() async {
        let service = StubConfigurationService([.success(Self.remote), .success(Self.remote)])
        let sut = makeSUT(service: service, fileURL: temporaryFileURL())

        async let first = sut.current()
        async let second = sut.current()
        _ = await (first, second)

        let calls = await service.configurationCalls
        XCTAssertEqual(calls, 1)
    }

    func test_store_corruptFile_isIgnored() async throws {
        let fileURL = temporaryFileURL()
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        let service = StubConfigurationService([.success(Self.remote)])

        let configuration = await makeSUT(service: service, fileURL: fileURL).current()

        XCTAssertEqual(configuration, Self.remote)
    }

    // MARK: - Helpers

    private static let remote = ImageConfiguration(
        secureBaseURL: URL(fileURLWithPath: "/remote/"),
        posterSizes: ["w92", "w342"],
        backdropSizes: ["w780"],
        profileSizes: ["w185"]
    )

    private func makeSUT(service: StubConfigurationService, fileURL: URL) -> ImageConfigurationStore {
        let now = now
        return ImageConfigurationStore(service: service, fileURL: fileURL, now: { now })
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("image-configuration.json")
    }
}
