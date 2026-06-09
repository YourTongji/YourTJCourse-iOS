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
    public private(set) var successMessage: String?
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

    /// Returns true if the app is currently in maintenance mode and writes should be blocked.
    private var isBlockedByMaintenance: Bool {
        MaintenanceMonitor.shared.isEnabled
    }

    public func submit(captchaToken: String) async {
        if isBlockedByMaintenance {
            error = "系统正在维护中，暂时无法提交评价"
            return
        }

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
                    semester: normalizedSemester,
                    turnstileToken: captchaToken,
                    reviewerName: normalizedReviewerName,
                    reviewerAvatar: normalizedReviewerAvatar,
                    walletUserHash: wallet?.userHash
                )

                var message = "评价提交成功"
                if let reviewId = response.reviewId, let wallet {
                    let token = HMACHelper.editToken(
                        reviewId: reviewId, userSecret: wallet.userSecret)
                    do {
                        let tokenResponse = try await reviewRepo.setEditToken(
                            reviewId: reviewId,
                            editToken: token,
                            walletUserHash: wallet.userHash
                        )
                        message = successMessage(for: tokenResponse.creditReward)
                    } catch {
                        logger.error("Failed to bind edit token: \(error.localizedDescription)")
                        message = "评价已提交，但钱包绑定失败：\(error.localizedDescription)"
                    }
                }
                successMessage = message
                success = true

            case .edit:
                guard let review = existingReview else {
                    throw APIError.invalidResponse
                }

                guard let wallet else {
                    throw APIError.unauthorized
                }

                let editToken = HMACHelper.editToken(reviewId: review.id, userSecret: wallet.userSecret)

                let _ = try await reviewRepo.updateReview(
                    reviewId: review.id,
                    rating: rating,
                    comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                    semester: normalizedSemester,
                    turnstileToken: captchaToken,
                    editToken: editToken,
                    walletUserHash: wallet.userHash,
                    reviewerName: normalizedReviewerName,
                    reviewerAvatar: normalizedReviewerAvatar
                )
                successMessage = "评价修改成功"
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

    public func dismissSuccess() {
        successMessage = nil
    }

    private var normalizedSemester: String {
        let value = semester.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "其他" : value
    }

    private var normalizedReviewerName: String? {
        reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var normalizedReviewerAvatar: String? {
        reviewerAvatar.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func successMessage(for reward: CreditRewardStatus?) -> String {
        guard let reward else { return "评价提交成功" }
        if reward.ok {
            return "评价提交成功，评课激励 +10 已发放到积分钱包"
        }
        if reward.skipped == true {
            return "评价提交成功"
        }
        let suffix = reward.error.map { "：\($0)" } ?? ""
        return "评价提交成功，但评课激励发放失败\(suffix)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
