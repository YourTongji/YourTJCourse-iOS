import Foundation
import DomainKit

/// Provides typed access to review creation, editing, liking, and reporting endpoints.
///
/// Use `HMACHelper.editToken(reviewId:userSecret:)` to compute the `editToken`
/// required for review updates.
public struct ReviewRepository: Sendable {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Create Review

    /// Creates a new review for the specified course.
    /// - Parameters:
    ///   - courseId: The course ID.
    ///   - rating: Rating score (typically 1-5).
    ///   - comment: Review body in markdown.
    ///   - semester: Semester string in "YYYY-S" format.
    ///   - turnstileToken: Cloudflare Turnstile / captcha token.
    ///   - reviewerName: Optional display name.
    ///   - reviewerAvatar: Optional avatar URL.
    ///   - walletUserHash: Optional wallet user hash for credit rewards.
    /// - Returns: A `CreateReviewResponse` indicating success and any credit reward status.
    public func createReview(
        courseId: Int,
        rating: Int,
        comment: String,
        semester: String,
        turnstileToken: String,
        reviewerName: String? = nil,
        reviewerAvatar: String? = nil,
        walletUserHash: String? = nil
    ) async throws -> CreateReviewResponse {
        let body = CreateReviewRequest(
            courseId: courseId,
            rating: rating,
            comment: comment,
            semester: semester,
            turnstileToken: turnstileToken,
            reviewerName: reviewerName,
            reviewerAvatar: reviewerAvatar,
            walletUserHash: walletUserHash
        )
        return try await client.post("/api/review", body: body)
    }

    // MARK: - Set Edit Token

    /// Registers an edit token for a review, authorizing future edits.
    ///
    /// The `editToken` should be computed via
    /// `HMACHelper.editToken(reviewId:userSecret:)`.
    /// - Parameters:
    ///   - reviewId: The review ID.
    ///   - editToken: The HMAC-SHA256 edit token.
    ///   - walletUserHash: The wallet user hash for authorization.
    /// - Returns: The server response, including any credit reward status.
    public func setEditToken(reviewId: Int, editToken: String, walletUserHash: String) async throws -> EditTokenResponse {
        let body = EditTokenRequest(editToken: editToken, walletUserHash: walletUserHash)
        return try await client.patch("/api/review/\(reviewId)/edit-token", body: body)
    }

    // MARK: - Update Review

    /// Updates an existing review. Requires a valid `editToken` previously set via `setEditToken`.
    /// - Parameters:
    ///   - reviewId: The review ID.
    ///   - rating: Updated rating.
    ///   - comment: Updated comment body.
    ///   - semester: Updated semester string.
    ///   - turnstileToken: New captcha token.
    ///   - editToken: Optional edit token (will be sent if provided).
    ///   - walletUserHash: Optional wallet user hash.
    ///   - reviewerName: Optional updated display name.
    ///   - reviewerAvatar: Optional updated avatar URL.
    /// - Returns: `true` if the update succeeded.
    public func updateReview(
        reviewId: Int,
        rating: Int,
        comment: String,
        semester: String,
        turnstileToken: String,
        editToken: String? = nil,
        walletUserHash: String? = nil,
        reviewerName: String? = nil,
        reviewerAvatar: String? = nil
    ) async throws -> Bool {
        let body = UpdateReviewRequest(
            rating: rating,
            comment: comment,
            semester: semester,
            turnstileToken: turnstileToken,
            editToken: editToken,
            walletUserHash: walletUserHash,
            reviewerName: reviewerName,
            reviewerAvatar: reviewerAvatar
        )
        let response: SuccessResponse = try await client.put("/api/review/\(reviewId)", body: body)
        return response.success
    }

    // MARK: - Like / Unlike

    /// Likes a review.
    /// - Parameters:
    ///   - reviewId: The review ID.
    ///   - clientId: The local client ID for tracking.
    /// - Returns: A `LikeResponse` with the updated like state.
    public func likeReview(reviewId: Int, clientId: String) async throws -> LikeResponse {
        let body = LikeRequest(clientId: clientId)
        return try await client.post("/api/review/\(reviewId)/like", body: body)
    }

    /// Removes a like from a review.
    /// - Parameters:
    ///   - reviewId: The review ID.
    ///   - clientId: The local client ID for tracking.
    /// - Returns: A `LikeResponse` with the updated like state.
    public func unlikeReview(reviewId: Int, clientId: String) async throws -> LikeResponse {
        let body = LikeRequest(clientId: clientId)
        return try await client.delete("/api/review/\(reviewId)/like", body: body)
    }

    // MARK: - Report Review (App Store compliance)

    /// Reports a review for moderation.
    ///
    /// Required for App Store compliance (Guideline 1.2 — user-generated content).
    /// - Parameters:
    ///   - reviewId: The review ID to report.
    ///   - reason: The reason for reporting.
    ///   - clientId: The local client ID for abuse tracking.
    /// - Returns: A `ReportResponse` with the report ID if accepted.
    public func reportReview(reviewId: Int, reason: ReportReason, clientId: String) async throws -> ReportResponse {
        let body = ReportRequest(reason: reason.rawValue, clientId: clientId)
        return try await client.post("/api/review/\(reviewId)/report", body: body)
    }

    // MARK: - My Reviews

    /// Fetches all reviews authored by the given wallet user.
    public func getMyReviews(walletUserHash: String) async throws -> [MyReviewEntry] {
        let items = [URLQueryItem(name: "walletUserHash", value: walletUserHash)]
        return try await client.get("/api/reviews/mine", query: items)
    }
}

// MARK: - Request Types (private)

private struct CreateReviewRequest: Codable, Sendable {
    let courseId: Int
    let rating: Int
    let comment: String
    let semester: String
    let turnstileToken: String
    let reviewerName: String?
    let reviewerAvatar: String?
    let walletUserHash: String?

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case rating, comment, semester
        case turnstileToken = "turnstile_token"
        case reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
        case walletUserHash
    }
}

private struct EditTokenRequest: Codable, Sendable {
    let editToken: String
    let walletUserHash: String

    enum CodingKeys: String, CodingKey {
        case editToken = "edit_token"
        case walletUserHash
    }
}

private struct UpdateReviewRequest: Codable, Sendable {
    let rating: Int
    let comment: String
    let semester: String
    let turnstileToken: String
    let editToken: String?
    let walletUserHash: String?
    let reviewerName: String?
    let reviewerAvatar: String?

    enum CodingKeys: String, CodingKey {
        case rating, comment, semester
        case turnstileToken = "turnstile_token"
        case editToken = "edit_token"
        case walletUserHash
        case reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
    }
}

private struct LikeRequest: Codable, Sendable {
    let clientId: String

    enum CodingKeys: String, CodingKey {
        case clientId = "clientId"
    }
}

private struct ReportRequest: Codable, Sendable {
    let reason: String
    let clientId: String

    enum CodingKeys: String, CodingKey {
        case reason, clientId
    }
}

private struct SuccessResponse: Codable, Sendable {
    let success: Bool
}

// MARK: - Response Types (public)

public struct CreateReviewResponse: Codable, Sendable {
    public let success: Bool
    public let reviewId: Int?
    public let creditReward: CreditRewardStatus?

    enum CodingKeys: String, CodingKey {
        case success, reviewId, creditReward
    }
}

public struct CreditRewardStatus: Codable, Sendable {
    public let ok: Bool
    public let skipped: Bool?
    public let error: String?
}

public struct EditTokenResponse: Codable, Sendable {
    public let success: Bool
    public let creditReward: CreditRewardStatus?
}

public struct LikeResponse: Codable, Sendable {
    public let success: Bool
    public let liked: Bool
    public let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case success, liked
        case likeCount = "like_count"
    }
}

public struct ReportResponse: Codable, Sendable {
    public let success: Bool
    public let reportId: Int?
}
