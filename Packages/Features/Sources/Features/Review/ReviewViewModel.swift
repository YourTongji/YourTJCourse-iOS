import Foundation
import Observation
import DomainKit
import DataKit
import Platform

@MainActor
@Observable
public final class ReviewViewModel {
    // Form fields
    public var rating: Int = 0
    public var comment: String = ""
    public var semester: String = ""
    public var reviewerName: String = ""
    public var reviewerAvatar: String = ""

    // State
    public private(set) var isSubmitting = false
    public private(set) var error: String?
    public private(set) var success = false
    public private(set) var needsCaptcha = true

    let courseId: Int
    let existingReview: Review?  // nil for new, non-nil for editing
    let mode: ReviewMode

    private let reviewRepo: ReviewRepository
    private let walletRepo: WalletRepository
    private let logger = AppLogger(category: "Review")

    public enum ReviewMode: Sendable {
        case create
        case edit
    }

    public init(
        courseId: Int,
        existingReview: Review? = nil,
        reviewRepo: ReviewRepository = ReviewRepository(),
        walletRepo: WalletRepository = WalletRepository()
    ) {
        self.courseId = courseId
        self.existingReview = existingReview
        self.mode = existingReview != nil ? .edit : .create
        self.reviewRepo = reviewRepo
        self.walletRepo = walletRepo

        if let review = existingReview {
            rating = review.rating
            comment = review.comment
            semester = review.semester
            reviewerName = review.reviewerName ?? ""
            reviewerAvatar = review.reviewerAvatar ?? ""
        }
    }

    public var isValid: Bool {
        rating > 0
            && !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && comment.count <= 10000
    }

    public var remainingChars: Int {
        10000 - comment.count
    }

    public func submit(captchaToken: String) async {
        guard isValid else {
            error = "请填写评分和评价内容"
            return
        }

        isSubmitting = true
        error = nil

        do {
            let wallet = walletRepo.loadWallet()

            switch mode {
            case .create:
                let response = try await reviewRepo.createReview(
                    courseId: courseId,
                    rating: rating,
                    comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                    semester: semester,
                    turnstileToken: captchaToken,
                    reviewerName: reviewerName.isEmpty ? nil : reviewerName,
                    reviewerAvatar: reviewerAvatar.isEmpty ? nil : reviewerAvatar,
                    walletUserHash: wallet?.userHash
                )

                // If wallet exists, set edit token automatically
                if let reviewId = response.reviewId, let wallet {
                    let token = HMACHelper.editToken(
                        reviewId: reviewId, userSecret: wallet.userSecret)
                    let _ = try? await reviewRepo.setEditToken(
                        reviewId: reviewId,
                        editToken: token,
                        walletUserHash: wallet.userHash
                    )
                }
                success = true

            case .edit:
                guard let review = existingReview else { return }

                let editToken: String? = wallet.map { wallet in
                    HMACHelper.editToken(reviewId: review.id, userSecret: wallet.userSecret)
                }

                let _ = try await reviewRepo.updateReview(
                    reviewId: review.id,
                    rating: rating,
                    comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                    semester: semester,
                    turnstileToken: captchaToken,
                    editToken: editToken,
                    walletUserHash: wallet?.userHash,
                    reviewerName: reviewerName.isEmpty ? nil : reviewerName,
                    reviewerAvatar: reviewerAvatar.isEmpty ? nil : reviewerAvatar
                )
                success = true
            }
        } catch {
            logger.error("Failed to submit review: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }

    public func dismissError() {
        error = nil
    }
}
