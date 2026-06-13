import Foundation
import Observation
import DataKit
import DomainKit

@MainActor
@Observable
final class MyReviewDetailViewModel {
    private(set) var entry: MyReviewEntry
    private(set) var isLikeUpdating = false
    private(set) var notice: ReviewDetailNotice?
    var editingEntry: MyReviewEntry?

    private let reviewId: Int
    private let localReviewStore: LocalReviewStore
    private let hiddenReviewStore: HiddenReviewStore
    private let reviewRepo: ReviewRepository
    private let config: APIConfig

    init(
        entry: MyReviewEntry,
        localReviewStore: LocalReviewStore = .init(),
        hiddenReviewStore: HiddenReviewStore = .init(),
        reviewRepo: ReviewRepository = .init(),
        config: APIConfig = .default
    ) {
        self.entry = entry
        self.reviewId = entry.id
        self.localReviewStore = localReviewStore
        self.hiddenReviewStore = hiddenReviewStore
        self.reviewRepo = reviewRepo
        self.config = config
    }

    func reloadEntry() {
        guard let currentEntry = localReviewStore.loadMine().first(where: { $0.id == reviewId }) else {
            return
        }
        entry = currentEntry
    }

    func toggleLike() async {
        guard !isLikeUpdating else { return }

        let originalReview = entry.review
        let targetLiked = !originalReview.liked
        let optimisticLikeCount = max(0, originalReview.likeCount + (targetLiked ? 1 : -1))
        updateEntry(with: originalReview.updatingLikeState(liked: targetLiked, likeCount: optimisticLikeCount))

        isLikeUpdating = true
        defer { isLikeUpdating = false }

        do {
            let response: LikeResponse
            if targetLiked {
                response = try await reviewRepo.likeReview(reviewId: reviewId, clientId: config.clientId)
            } else {
                response = try await reviewRepo.unlikeReview(reviewId: reviewId, clientId: config.clientId)
            }

            guard response.success else {
                throw APIError.invalidResponse
            }

            updateEntry(
                with: originalReview.updatingLikeState(
                    liked: response.liked,
                    likeCount: response.likeCount
                )
            )
        } catch {
            updateEntry(with: originalReview)
            notice = ReviewDetailNotice(title: "点赞失败", message: error.localizedDescription)
        }
    }

    func hideReview() {
        localReviewStore.upsertHidden(entry)
        var hiddenReviewIds = hiddenReviewStore.load()
        hiddenReviewIds.insert(reviewId)
        hiddenReviewStore.save(hiddenReviewIds)
        notice = ReviewDetailNotice(title: "已隐藏", message: "这条评价不会再显示在本机课程详情页。")
    }

    func reportReview(reason: ReportReason) async {
        do {
            let response = try await reviewRepo.reportReview(
                reviewId: reviewId,
                reason: reason,
                clientId: config.clientId
            )
            notice = response.success
                ? ReviewDetailNotice(title: "举报成功", message: "感谢您的举报，我们会尽快处理。")
                : ReviewDetailNotice(title: "举报失败", message: "请稍后再试。")
        } catch {
            notice = ReviewDetailNotice(title: "举报失败", message: error.localizedDescription)
        }
    }

    func dismissNotice() {
        notice = nil
    }

    private func updateEntry(with review: Review) {
        entry = entry.updatingReview(review, savedAt: entry.savedAt)
        localReviewStore.upsertMine(entry)
    }
}

struct ReviewDetailNotice: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}
