import Foundation
@testable import MovieScopeCore
import XCTest

final class FavoritesStoreTests: XCTestCase {
    func test_store_emptyInitially() async {
        let sut = FavoritesStore(fileURL: temporaryFileURL())

        let items = await sut.all()

        XCTAssertTrue(items.isEmpty)
    }

    func test_store_setAddsThenRemoves() async throws {
        let sut = FavoritesStore(fileURL: temporaryFileURL())
        let item = favorite(1)

        try await sut.set(item, isFavorite: true)
        let afterAdd = await sut.all()
        try await sut.set(item, isFavorite: false)
        let afterRemove = await sut.all()

        XCTAssertEqual(afterAdd, [item])
        XCTAssertTrue(afterRemove.isEmpty)
    }

    func test_store_setIsSafeToRepeat() async throws {
        let sut = FavoritesStore(fileURL: temporaryFileURL())
        let original = favorite(1, addedAt: Date(timeIntervalSince1970: 100))

        try await sut.set(original, isFavorite: true)
        try await sut.set(favorite(1, addedAt: Date(timeIntervalSince1970: 900)), isFavorite: true)
        try await sut.set(favorite(2), isFavorite: false)

        let items = await sut.all()
        XCTAssertEqual(items, [original], "Re-adding keeps one copy with its original date; removing an absent one is a no-op")
    }

    func test_store_persistsAcrossInstances() async throws {
        let fileURL = temporaryFileURL()
        try await FavoritesStore(fileURL: fileURL).set(favorite(1), isFavorite: true)

        let reloaded = await FavoritesStore(fileURL: fileURL).all()

        XCTAssertEqual(reloaded.map(\.id), [MediaID(kind: .movie, id: 1)])
        XCTAssertEqual(reloaded.first?.title, "Title 1")
    }

    func test_store_corruptFile_recoversToEmpty_andSaves() async throws {
        let fileURL = temporaryFileURL()
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ broken".utf8).write(to: fileURL)
        let sut = FavoritesStore(fileURL: fileURL)

        let initial = await sut.all()
        try await sut.set(favorite(2), isFavorite: true)

        XCTAssertTrue(initial.isEmpty)
        let reloaded = await FavoritesStore(fileURL: fileURL).all()
        XCTAssertEqual(reloaded.map(\.id.id), [2])
    }

    func test_store_allNewestFirst() async throws {
        let sut = FavoritesStore(fileURL: temporaryFileURL())
        try await sut.set(favorite(1, addedAt: Date(timeIntervalSince1970: 100)), isFavorite: true)
        try await sut.set(favorite(2, addedAt: Date(timeIntervalSince1970: 300)), isFavorite: true)
        try await sut.set(favorite(3, addedAt: Date(timeIntervalSince1970: 200)), isFavorite: true)

        let ids = await sut.all().map(\.id.id)

        XCTAssertEqual(ids, [2, 3, 1])
    }

    func test_store_movieAndTVWithSameNumber_areDistinct() async throws {
        let sut = FavoritesStore(fileURL: temporaryFileURL())
        try await sut.set(favorite(7, kind: .movie), isFavorite: true)
        try await sut.set(favorite(7, kind: .tv), isFavorite: true)

        let count = await sut.all().count

        XCTAssertEqual(count, 2)
    }

    func test_favoriteItem_fromSummary_keepsListFieldsAndYear() {
        let summary = MediaSummary(
            id: MediaID(kind: .tv, id: 9), title: "Show", overview: "o", posterPath: "/p.jpg", backdropPath: nil,
            voteAverage: 8, voteCount: 10, releaseDate: Date(timeIntervalSince1970: 1_704_067_200)
        )

        let item = FavoriteItem(summary: summary, addedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(item.id, summary.id)
        XCTAssertEqual(item.posterPath, "/p.jpg")
        XCTAssertEqual(item.year, 2024)
        XCTAssertEqual(item.summary.title, "Show")
    }

    func test_favoriteItem_placeholderSummary_keepsYear() {
        // Removing a favorite and re-adding it from a details screen that hasn't
        // loaded yet builds the new item from this placeholder.
        let item = favorite(1)

        let readded = FavoriteItem(summary: item.summary, addedAt: Date(timeIntervalSince1970: 50))

        XCTAssertEqual(readded.year, 2024)
        XCTAssertNil(favorite(2, year: nil).summary.releaseDate)
    }

    // MARK: - Helpers

    private func favorite(
        _ id: Int,
        kind: MediaKind = .movie,
        year: Int? = 2024,
        addedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> FavoriteItem {
        FavoriteItem(id: MediaID(kind: kind, id: id), title: "Title \(id)", posterPath: "/p\(id).jpg", year: year, addedAt: addedAt)
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("favorites.json")
    }
}
