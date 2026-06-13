import Foundation
import Testing
import DomainKit
@testable import DataKit

@Test func localReviewStorePersistsMineAndHiddenReviews() {
    let suffix = UUID().uuidString
    let mineKey = "LocalReviewStoreTests.mine.\(suffix)"
    let favoriteKey = "LocalReviewStoreTests.favorite.\(suffix)"
    let hiddenKey = "LocalReviewStoreTests.hidden.\(suffix)"
    let store = LocalReviewStore(
        mineKey: mineKey,
        favoriteKey: favoriteKey,
        hiddenKey: hiddenKey
    )
    defer {
        UserDefaults.standard.removeObject(forKey: mineKey)
        UserDefaults.standard.removeObject(forKey: favoriteKey)
        UserDefaults.standard.removeObject(forKey: hiddenKey)
    }

    let entry = MyReviewEntry(
        id: 42,
        courseId: 7,
        courseName: "高等数学",
        courseCode: "MATH101",
        teacherName: "张老师",
        courseRating: 4.5,
        reviewCount: 12,
        semester: "2025-2026-1",
        rating: 5,
        comment: "讲得很清楚",
        createdAt: "2026-01-01T00:00:00Z",
        likeCount: 0,
        liked: false,
        canEdit: true,
        reviewerName: "同学",
        reviewerAvatar: nil,
        savedAt: "2026-01-02T00:00:00Z"
    )

    store.upsertMine(entry)
    store.upsertHidden(entry)

    #expect(store.loadMine().map(\.id) == [42])
    #expect(store.loadHidden().map(\.id) == [42])

    let updated = entry.review.updatingLikeState(liked: true, likeCount: 1)
    store.updateMineReview(updated)

    #expect(store.loadMine().first?.liked == true)
    #expect(store.loadMine().first?.likeCount == 1)

    store.removeHidden(reviewId: 42)

    #expect(store.loadHidden().isEmpty)
}
