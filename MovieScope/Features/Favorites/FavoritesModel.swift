import Foundation
import MovieScopeCore
import Observation
import os

/// UI-side state of favorites, shared by every screen through the environment.
/// The `FavoritesStore` actor owns persistence; this model mirrors it on the
/// main actor and updates optimistically. If a save fails, only that title is
/// put back to what is actually saved, and only if no newer tap on the same
/// title is in flight (that tap's own save settles it).
@MainActor
@Observable
final class FavoritesModel {
    private(set) var items: [FavoriteItem] = []
    private(set) var ids: Set<MediaID> = []

    @ObservationIgnored private let store: any FavoritesStoring
    @ObservationIgnored private let now: () -> Date
    /// The latest tap per title, to tell whether a failed save is still the
    /// one that decides what the title shows.
    @ObservationIgnored private var latestChange: [MediaID: Int] = [:]
    @ObservationIgnored private var changeCount = 0

    init(store: any FavoritesStoring, now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    func load() async {
        set(await store.all())
    }

    func isFavorite(_ id: MediaID) -> Bool {
        ids.contains(id)
    }

    func toggle(_ summary: MediaSummary) async {
        let makesFavorite = !ids.contains(summary.id)
        let item = items.first { $0.id == summary.id } ?? FavoriteItem(summary: summary, addedAt: now())
        apply(item, isFavorite: makesFavorite)
        changeCount += 1
        let change = changeCount
        latestChange[item.id] = change
        do {
            try await store.set(item, isFavorite: makesFavorite)
            if latestChange[item.id] == change { latestChange[item.id] = nil }
        } catch {
            Logger(subsystem: "io.github.minchevskis.MovieScope", category: "favorites")
                .error("Couldn't save favorite: \(error.localizedDescription)")
            await restoreSavedState(of: item, ifStillLatest: change)
        }
    }

    private func restoreSavedState(of item: FavoriteItem, ifStillLatest change: Int) async {
        guard latestChange[item.id] == change else { return }
        let saved = await store.all().first { $0.id == item.id }
        guard latestChange[item.id] == change else { return }
        latestChange[item.id] = nil
        apply(saved ?? item, isFavorite: saved != nil)
    }

    /// Adds or removes one title, keeping the list newest first.
    private func apply(_ item: FavoriteItem, isFavorite: Bool) {
        var newItems = items.filter { $0.id != item.id }
        if isFavorite {
            let index = newItems.firstIndex { $0.addedAt < item.addedAt } ?? newItems.endIndex
            newItems.insert(item, at: index)
        }
        set(newItems)
    }

    private func set(_ newItems: [FavoriteItem]) {
        items = newItems
        ids = Set(newItems.map(\.id))
    }
}
