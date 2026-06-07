import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class CourseDetailViewModel {
    public private(set) var courseDetail: CourseDetail?
    public private(set) var relatedCourses: RelatedCourses?
    public private(set) var aiSummary: AiSummaryData?
    public private(set) var aiSummaryError: String?
    public private(set) var isAiSummaryDismissed = false
    public private(set) var isSummaryLoading = false
    public private(set) var isLoading = true
    public private(set) var error: String?
    public private(set) var hiddenReviewIds: Set<Int>
    public private(set) var togglingLikeReviewIds: Set<Int> = []
    public private(set) var isFavorite = false

    let courseId: Int
    /// When false, the "same teacher / same course other teachers" related section
    /// is neither fetched nor shown. Used when the caller already picked a specific
    /// teaching class (e.g. from the scheduler) and only wants that class's reviews.
    private let loadsRelatedCourses: Bool
    private let courseRepo: CourseRepository
    private let reviewRepo: ReviewRepository
    private let walletRepo: WalletRepository
    private let hiddenReviewStore: HiddenReviewStore
    private let favoriteStore: CourseFavoriteStore
    private let config = APIConfig.default
    private let logger = AppLogger(category: "CourseDetail")

    public init(
        courseId: Int,
        loadsRelatedCourses: Bool = true,
        courseRepo: CourseRepository = .init(),
        reviewRepo: ReviewRepository = .init(),
        walletRepo: WalletRepository = .init(),
        hiddenReviewStore: HiddenReviewStore = .init(),
        favoriteStore: CourseFavoriteStore = .init()
    ) {
        self.courseId = courseId
        self.loadsRelatedCourses = loadsRelatedCourses
        self.courseRepo = courseRepo
        self.reviewRepo = reviewRepo
        self.walletRepo = walletRepo
        self.hiddenReviewStore = hiddenReviewStore
        self.favoriteStore = favoriteStore
        self.hiddenReviewIds = hiddenReviewStore.load()
        self.isFavorite = favoriteStore.isFavorite(courseId: courseId)
    }

    public var visibleReviews: [Review] {
        courseDetail?.reviews.filter { !hiddenReviewIds.contains($0.id) } ?? []
    }

    public var canAttemptReviewEdits: Bool {
        walletRepo.hasWallet()
    }

    public func load() async {
        isLoading = true
        error = nil
        var didLoadDetail = false
        do {
            let walletUserHash = walletRepo.loadWallet()?.userHash
            courseDetail = try await courseRepo.getCourseDetail(
                id: courseId,
                clientId: config.clientId,
                walletUserHash: walletUserHash
            )
            if let courseDetail {
                isFavorite = favoriteStore.isFavorite(courseId: courseDetail.id)
            }
            didLoadDetail = true
            if loadsRelatedCourses {
                do {
                    relatedCourses = try await courseRepo.getRelatedCourses(id: courseId)
                } catch {
                    relatedCourses = nil
                    logger.error("Failed to load related courses: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to load course detail: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        isLoading = false

        if didLoadDetail {
            await loadAiSummary()
        }
    }

    public func generateAiSummary() async {
        await loadAiSummary(refresh: true)
    }

    private func loadAiSummary(refresh: Bool = false) async {
        guard !isSummaryLoading else { return }
        isSummaryLoading = true
        aiSummaryError = nil
        isAiSummaryDismissed = false
        defer { isSummaryLoading = false }

        do {
            let response = try await courseRepo.getAiSummary(courseId: courseId, refresh: refresh)
            aiSummary = response.data
        } catch {
            logger.error("Failed to load AI summary: \(error.localizedDescription)")
            aiSummaryError = error.localizedDescription
        }
    }

    public func dismissSummary() {
        aiSummary = nil
        aiSummaryError = nil
        isAiSummaryDismissed = true
    }

    public func refresh() async {
        await load()
    }

    public func toggleLike(for reviewId: Int) async {
        guard let review = courseDetail?.reviews.first(where: { $0.id == reviewId }) else { return }
        guard !togglingLikeReviewIds.contains(reviewId) else { return }

        togglingLikeReviewIds.insert(reviewId)
        let targetLiked = !review.liked
        let optimisticLikeCount = max(0, review.likeCount + (targetLiked ? 1 : -1))
        updateReview(review.updatingLikeState(liked: targetLiked, likeCount: optimisticLikeCount))
        defer { togglingLikeReviewIds.remove(reviewId) }

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

            updateReview(review.updatingLikeState(liked: response.liked, likeCount: response.likeCount))
        } catch {
            logger.error("Failed to toggle like: \(error.localizedDescription)")
            updateReview(review)
        }
    }

    public func reportReview(reviewId: Int, reason: ReportReason) async -> Bool {
        do {
            let _ = try await reviewRepo.reportReview(reviewId: reviewId, reason: reason, clientId: config.clientId)
            return true
        } catch {
            logger.error("Failed to report review: \(error.localizedDescription)")
            return false
        }
    }

    public func hideReview(reviewId: Int) {
        hiddenReviewIds.insert(reviewId)
        hiddenReviewStore.save(hiddenReviewIds)
    }

    public func toggleFavorite() {
        guard let courseDetail else { return }
        isFavorite = favoriteStore.toggle(FavoriteCourse(course: courseDetail))
    }

    private func updateReview(_ review: Review) {
        guard let detail = courseDetail else {
            return
        }

        courseDetail = detail.replacingReview(review)
    }
}

public struct HiddenReviewStore: Sendable {
    private let key: String

    public init(key: String = "com.yourtj.course.hiddenReviewIds") {
        self.key = key
    }

    public func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }

    public func save(_ reviewIds: Set<Int>) {
        UserDefaults.standard.set(reviewIds.sorted(), forKey: key)
    }
}
