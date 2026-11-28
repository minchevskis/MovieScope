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

    func test_model_failedSave_keepsOtherTitlesChanges() async {
        let store = ScriptedFavoritesStore()
        let sut = FavoritesModel(store: store)

        let addFirst = Task { await sut.toggle(.stub(1)) }
        await store.waitForPendingSaves(1)
        let addSecond = Task { await sut.toggle(.stub(2)) }
        await store.waitForPendingSaves(2)
        await store.finishNextSave(succeeding: false)
        await addFirst.value
        await store.finishNextSave(succeeding: true)
        await addSecond.value

        XCTAssertEqual(sut.ids, [MediaID(kind: .movie, id: 2)], "Only the title whose save failed is reverted")
        let stored = await store.all()
        XCTAssertEqual(Set(stored.map(\.id)), sut.ids)
    }

    func test_model_rapidTogglesWithFailedFirstSave_matchStore() async {
        let store = ScriptedFavoritesStore()
        let sut = FavoritesModel(store: store)

        let add = Task { await sut.toggle(.stub(1)) }
        await store.waitForPendingSaves(1)
        let remove = Task { await sut.toggle(.stub(1)) }
        await store.waitForPendingSaves(2)
        await store.finishNextSave(succeeding: false)
        await add.value
        await store.finishNextSave(succeeding: true)
        await remove.value

        let stored = await store.all()
        XCTAssertTrue(sut.ids.isEmpty, "The last tap (remove) wins")
        XCTAssertEqual(Set(stored.map(\.id)), sut.ids, "The UI never disagrees with what is saved")
    }

    func test_model_rapidTogglesBothFailing_matchStore() async {
        let store = ScriptedFavoritesStore()
        let sut = FavoritesModel(store: store)

        let add = Task { await sut.toggle(.stub(1)) }
        await store.waitForPendingSaves(1)
        let remove = Task { await sut.toggle(.stub(1)) }
        await store.waitForPendingSaves(2)
        await store.finishNextSave(succeeding: false)
        await add.value
        await store.finishNextSave(succeeding: false)
        await remove.value

        let stored = await store.all()
        XCTAssertEqual(Set(stored.map(\.id)), sut.ids)
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

/// A store whose saves stay pending until the test finishes them, one at a
/// time and in order, each succeeding or failing.
private actor ScriptedFavoritesStore: FavoritesStoring {
    private struct PendingSave {
        let item: FavoriteItem
        let isFavorite: Bool
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var items: [FavoriteItem] = []
    private var pending: [PendingSave] = []

    func all() -> [FavoriteItem] {
        items.sorted { $0.addedAt > $1.addedAt }
    }

    func set(_ item: FavoriteItem, isFavorite: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            pending.append(PendingSave(item: item, isFavorite: isFavorite, continuation: continuation))
        }
    }

    func finishNextSave(succeeding: Bool) {
        let save = pending.removeFirst()
        guard succeeding else {
            save.continuation.resume(throwing: CocoaError(.fileWriteNoPermission))
            return
        }
        items.removeAll { $0.id == save.item.id }
        if save.isFavorite { items.append(save.item) }
        save.continuation.resume()
    }

    func waitForPendingSaves(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while pending.count < count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Expected \(count) pending saves, have \(pending.count)", file: file, line: line)
                return
            }
            await Task.yield()
        }
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

    func set(_ item: FavoriteItem, isFavorite: Bool) throws {
        if failsWrites { throw CocoaError(.fileWriteNoPermission) }
        items.removeAll { $0.id == item.id }
        if isFavorite { items.append(item) }
    }
}
