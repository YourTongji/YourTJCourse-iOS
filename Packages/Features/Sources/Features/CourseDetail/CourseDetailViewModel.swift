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
    public private(set) var isSummaryLoading = false
    public private(set) var isLoading = true
    public private(set) var error: String?
    public private(set) var hiddenReviewIds: Set<Int>

    let courseId: Int
    private let courseRepo: CourseRepository
    private let reviewRepo: ReviewRepository
    private let walletRepo: WalletRepository
    private let hiddenReviewStore: HiddenReviewStore
    private let config = APIConfig.default
    private let logger = AppLogger(category: "CourseDetail")

    public init(
        courseId: Int,
        courseRepo: CourseRepository = .init(),
        reviewRepo: ReviewRepository = .init(),
        walletRepo: WalletRepository = .init(),
        hiddenReviewStore: HiddenReviewStore = .init()
    ) {
        self.courseId = courseId
        self.courseRepo = courseRepo
        self.reviewRepo = reviewRepo
        self.walletRepo = walletRepo
        self.hiddenReviewStore = hiddenReviewStore
        self.hiddenReviewIds = hiddenReviewStore.load()
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
        do {
            let walletUserHash = walletRepo.loadWallet()?.userHash
            courseDetail = try await courseRepo.getCourseDetail(
                id: courseId,
                clientId: config.clientId,
                walletUserHash: walletUserHash
            )
            do {
                relatedCourses = try await courseRepo.getRelatedCourses(id: courseId)
            } catch {
                relatedCourses = nil
                logger.error("Failed to load related courses: \(error.localizedDescription)")
            }
        } catch {
            logger.error("Failed to load course detail: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        isLoading = false

        // Fetch AI summary — optional content, silence errors
        await loadAiSummary()
    }

    private func loadAiSummary() async {
        isSummaryLoading = true
        do {
            let response = try await courseRepo.getAiSummary(courseId: courseId)
            aiSummary = response.data
        } catch {
            logger.error("Failed to load AI summary: \(error.localizedDescription)")
        }
        isSummaryLoading = false
    }

    public func dismissSummary() {
        aiSummary = nil
    }

    public func refresh() async {
        await load()
    }

    public func toggleLike(for reviewId: Int) async {
        guard let review = courseDetail?.reviews.first(where: { $0.id == reviewId }) else { return }

        do {
            if review.liked {
                let response = try await reviewRepo.unlikeReview(reviewId: reviewId, clientId: config.clientId)
                updateReview(reviewId: reviewId, liked: false, likeCount: response.likeCount)
            } else {
                let response = try await reviewRepo.likeReview(reviewId: reviewId, clientId: config.clientId)
                updateReview(reviewId: reviewId, liked: true, likeCount: response.likeCount)
            }
        } catch {
            logger.error("Failed to toggle like: \(error.localizedDescription)")
            await load()
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

    private func updateReview(reviewId: Int, liked: Bool, likeCount: Int) {
        guard let detail = courseDetail,
              let review = detail.reviews.first(where: { $0.id == reviewId }) else {
            return
        }

        courseDetail = detail.replacingReview(
            review.updatingLikeState(liked: liked, likeCount: likeCount)
        )
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
