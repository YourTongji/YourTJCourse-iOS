import Foundation

public struct Review: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let sqid: String
    public let courseId: Int
    public let semester: String
    public let rating: Int
    public let comment: String
    public let createdAt: String
    public let likeCount: Int
    public let liked: Bool
    public let reviewerName: String?
    public let reviewerAvatar: String?

    public init(
        id: Int,
        sqid: String,
        courseId: Int,
        semester: String,
        rating: Int,
        comment: String,
        createdAt: String,
        likeCount: Int,
        liked: Bool,
        reviewerName: String? = nil,
        reviewerAvatar: String? = nil
    ) {
        self.id = id
        self.sqid = sqid
        self.courseId = courseId
        self.semester = semester
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.liked = liked
        self.reviewerName = reviewerName
        self.reviewerAvatar = reviewerAvatar
    }

    public func updatingLikeState(liked: Bool, likeCount: Int) -> Review {
        Review(
            id: id,
            sqid: sqid,
            courseId: courseId,
            semester: semester,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            likeCount: likeCount,
            liked: liked,
            reviewerName: reviewerName,
            reviewerAvatar: reviewerAvatar
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(sqid)
    }

    public static func == (lhs: Review, rhs: Review) -> Bool {
        lhs.id == rhs.id && lhs.sqid == rhs.sqid
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sqid
        case courseId = "course_id"
        case semester
        case rating
        case comment
        case createdAt = "created_at"
        case likeCount = "like_count"
        case liked
        case reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
    }
}
