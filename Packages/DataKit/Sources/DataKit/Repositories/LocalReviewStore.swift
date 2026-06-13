import Foundation
import DomainKit

public struct LocalReviewStore: Sendable {
    private let mineKey: String
    private let favoriteKey: String
    private let hiddenKey: String

    public init(
        mineKey: String = "com.yourtj.course.localReviews.mine",
        favoriteKey: String = "com.yourtj.course.localReviews.favorites",
        hiddenKey: String = "com.yourtj.course.localReviews.hidden"
    ) {
        self.mineKey = mineKey
        self.favoriteKey = favoriteKey
        self.hiddenKey = hiddenKey
    }

    public func loadMine() -> [MyReviewEntry] {
        load(mineKey)
    }

    public func loadFavorites() -> [MyReviewEntry] {
        load(favoriteKey)
    }

    public func loadHidden() -> [MyReviewEntry] {
        load(hiddenKey)
    }

    public func loadFavoriteIds() -> Set<Int> {
        Set(loadFavorites().map(\.id))
    }

    public func upsertMine(_ entry: MyReviewEntry) {
        upsert(entry, key: mineKey)
    }

    public func upsertFavorite(_ entry: MyReviewEntry) {
        upsert(entry, key: favoriteKey)
    }

    public func upsertHidden(_ entry: MyReviewEntry) {
        upsert(entry, key: hiddenKey)
    }

    public func removeFavorite(reviewId: Int) {
        remove(reviewId: reviewId, key: favoriteKey)
    }

    public func removeHidden(reviewId: Int) {
        remove(reviewId: reviewId, key: hiddenKey)
    }

    public func updateMineReview(_ review: Review) {
        let entries = loadMine().map { entry in
            entry.id == review.id ? entry.updatingReview(review) : entry
        }
        persist(entries, key: mineKey)
    }

    private func load(_ key: String) -> [MyReviewEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([MyReviewEntry].self, from: data)
                .sorted { $0.savedAt > $1.savedAt }
        } catch {
            return []
        }
    }

    private func upsert(_ entry: MyReviewEntry, key: String) {
        var entries = load(key).filter { $0.id != entry.id }
        entries.insert(entry, at: 0)
        persist(entries, key: key)
    }

    private func remove(reviewId: Int, key: String) {
        persist(load(key).filter { $0.id != reviewId }, key: key)
    }

    private func persist(_ entries: [MyReviewEntry], key: String) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
