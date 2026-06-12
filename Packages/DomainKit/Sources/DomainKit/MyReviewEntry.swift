import Foundation

public struct MyReviewEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: Int
    public let courseId: Int
    public let semester: String
    public let rating: Int
    public let comment: String
    public let createdAt: String
    public let likeCount: Int
    public let liked: Bool
    public let canEdit: Bool
    public let reviewerName: String?
    public let reviewerAvatar: String?
    public let courseName: String
    public let courseCode: String
    public let teacherName: String

    public var review: Review {
        Review(
            id: id, sqid: String(id), courseId: courseId, semester: semester,
            rating: rating, comment: comment, createdAt: createdAt,
            likeCount: likeCount, liked: liked, canEdit: canEdit,
            reviewerName: reviewerName, reviewerAvatar: reviewerAvatar
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, courseId = "course_id", semester, rating, comment
        case createdAt = "created_at", likeCount = "like_count"
        case liked, canEdit = "can_edit", reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
        case courseName = "course_name", courseCode = "course_code"
        case teacherName = "teacher_name"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        courseId = try c.decode(Int.self, forKey: .courseId)
        semester = try c.decodeIfPresent(String.self, forKey: .semester) ?? ""
        rating = try c.decode(Int.self, forKey: .rating)
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        liked = try c.decodeIfPresent(Bool.self, forKey: .liked) ?? false
        canEdit = try c.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        reviewerName = try c.decodeIfPresent(String.self, forKey: .reviewerName)?.nonEmptyTrimmed
        reviewerAvatar = try c.decodeIfPresent(String.self, forKey: .reviewerAvatar)?.nonEmptyTrimmed
        courseName = try c.decodeIfPresent(String.self, forKey: .courseName) ?? "未知课程"
        courseCode = try c.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MyReviewEntry, rhs: MyReviewEntry) -> Bool {
        lhs.id == rhs.id
    }
}
