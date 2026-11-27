import Foundation
import MovieScopeCore
import Observation
import os

/// UI-side state of favorites, shared by every screen through the environment.
/// The `FavoritesStore` actor owns persistence; this model mirrors it on the
/// main actor and updates optimistically, reverting if a save fails.
@MainActor
@Observable
final class FavoritesModel {
    private(set) var items: [FavoriteItem] = []
    private(set) var ids: Set<MediaID> = []

    @ObservationIgnored private let store: any FavoritesStoring
    @ObservationIgnored private let now: () -> Date

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
        let previous = items
        let item = items.first { $0.id == summary.id } ?? FavoriteItem(summary: summary, addedAt: now())
        if ids.contains(item.id) {
            set(items.filter { $0.id != item.id })
        } else {
            set([item] + items)
        }
        do {
            try await store.toggle(item)
        } catch {
            Logger(subsystem: "io.github.minchevskis.MovieScope", category: "favorites")
                .error("Couldn't save favorite: \(error.localizedDescription)")
            set(previous)
        }
    }

    private func set(_ newItems: [FavoriteItem]) {
        items = newItems
        ids = Set(newItems.map(\.id))
    }
}
