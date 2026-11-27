import Foundation
@testable import MovieScope
import MovieScopeCore
import XCTest

@MainActor
final class FavoritesModelTests: XCTestCase {
    func test_model_loadReflectsStore() async {
        let store = InMemoryFavoritesStore(items: [FavoriteItem(summary: .stub(1), addedAt: .distantPast)])
        let sut = FavoritesModel(store: store)

        await sut.load()

        XCTAssertEqual(sut.items.map(\.id), [MediaID(kind: .movie, id: 1)])
        XCTAssertTrue(sut.isFavorite(MediaID(kind: .movie, id: 1)))
    }

    func test_model_toggleUpdatesIdsAndItems() async {
        let sut = FavoritesModel(store: InMemoryFavoritesStore(), now: { Date(timeIntervalSince1970: 42) })

        await sut.toggle(.stub(5))
        XCTAssertEqual(sut.ids, [MediaID(kind: .movie, id: 5)])
        XCTAssertEqual(sut.items.first?.addedAt, Date(timeIntervalSince1970: 42))

        await sut.toggle(.stub(5))
        XCTAssertTrue(sut.ids.isEmpty)
        XCTAssertTrue(sut.items.isEmpty)
    }

    func test_model_toggleFailure_revertsOptimisticChange() async {
        let sut = FavoritesModel(store: InMemoryFavoritesStore(failsWrites: true))

        await sut.toggle(.stub(5))

        XCTAssertTrue(sut.ids.isEmpty, "A failed save must not leave the UI out of sync with disk")
    }

    func test_model_newestFavoriteFirst() async {
        var clock = 0.0
        let sut = FavoritesModel(store: InMemoryFavoritesStore()) {
            clock += 1
            return Date(timeIntervalSince1970: clock)
        }

        await sut.toggle(.stub(1))
        await sut.toggle(.stub(2))

        XCTAssertEqual(sut.items.map(\.id.id), [2, 1])
    }
}

private actor InMemoryFavoritesStore: FavoritesStoring {
    private var items: [FavoriteItem]
    private let failsWrites: Bool

    init(items: [FavoriteItem] = [], failsWrites: Bool = false) {
        self.items = items
        self.failsWrites = failsWrites
    }

    func all() -> [FavoriteItem] {
        items.sorted { $0.addedAt > $1.addedAt }
    }

    func toggle(_ item: FavoriteItem) throws -> Bool {
        if failsWrites { throw CocoaError(.fileWriteNoPermission) }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            return false
        }
        items.append(item)
        return true
    }
}
