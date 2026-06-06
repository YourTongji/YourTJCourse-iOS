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
    public private(set) var isLoading = true
    public private(set) var error: String?

    let courseId: Int
    private let courseRepo: CourseRepository
    private let reviewRepo: ReviewRepository
    private let config = APIConfig.default
    private let logger = AppLogger(category: "CourseDetail")

    public init(courseId: Int, courseRepo: CourseRepository = .init(), reviewRepo: ReviewRepository = .init()) {
        self.courseId = courseId
        self.courseRepo = courseRepo
        self.reviewRepo = reviewRepo
    }

    public func load() async {
        isLoading = true
        error = nil
        do {
            async let detail = courseRepo.getCourseDetail(id: courseId, clientId: config.clientId)
            async let related = courseRepo.getRelatedCourses(id: courseId)
            let (d, r) = try await (detail, related)
            courseDetail = d
            relatedCourses = r
        } catch {
            logger.error("Failed to load course detail: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        isLoading = false
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
