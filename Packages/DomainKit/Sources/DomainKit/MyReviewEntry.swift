import Foundation

public struct MyReviewEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: Int
    public let courseId: Int
    public let courseName: String
    public let courseCode: String
    public let teacherName: String
    public let courseRating: Double
    public let reviewCount: Int
    public let semester: String
    public let rating: Int
    public let comment: String
    public let createdAt: String
    public let likeCount: Int
    public let liked: Bool
    public let canEdit: Bool
    public let reviewerName: String?
    public let reviewerAvatar: String?
    public let savedAt: String

    public var review: Review {
        Review(
            id: id, sqid: String(id), courseId: courseId, semester: semester,
            rating: rating, comment: comment, createdAt: createdAt,
            likeCount: likeCount, liked: liked, canEdit: canEdit,
            reviewerName: reviewerName, reviewerAvatar: reviewerAvatar
        )
    }

    public init(
        id: Int,
        courseId: Int,
        courseName: String,
        courseCode: String,
        teacherName: String,
        courseRating: Double,
        reviewCount: Int,
        semester: String,
        rating: Int,
        comment: String,
        createdAt: String,
        likeCount: Int,
        liked: Bool,
        canEdit: Bool,
        reviewerName: String?,
        reviewerAvatar: String?,
        savedAt: String = Date.now.ISO8601Format()
    ) {
        self.id = id
        self.courseId = courseId
        self.courseName = courseName
        self.courseCode = courseCode
        self.teacherName = teacherName
        self.courseRating = courseRating
        self.reviewCount = reviewCount
        self.semester = semester
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.liked = liked
        self.canEdit = canEdit
        self.reviewerName = reviewerName
        self.reviewerAvatar = reviewerAvatar
        self.savedAt = savedAt
    }

    public init(course: CourseDetail, review: Review, savedAt: String = Date.now.ISO8601Format()) {
        self.init(
            id: review.id,
            courseId: course.id,
            courseName: course.name,
            courseCode: course.code,
            teacherName: course.teacherName,
            courseRating: course.rating,
            reviewCount: course.reviewCount,
            semester: review.semester,
            rating: review.rating,
            comment: review.comment,
            createdAt: review.createdAt,
            likeCount: review.likeCount,
            liked: review.liked,
            canEdit: review.canEdit,
            reviewerName: review.reviewerName,
            reviewerAvatar: review.reviewerAvatar,
            savedAt: savedAt
        )
    }

    public func updatingReview(
        _ review: Review,
        reviewCount: Int? = nil,
        savedAt: String = Date.now.ISO8601Format()
    ) -> MyReviewEntry {
        MyReviewEntry(
            id: review.id,
            courseId: courseId,
            courseName: courseName,
            courseCode: courseCode,
            teacherName: teacherName,
            courseRating: courseRating,
            reviewCount: reviewCount ?? self.reviewCount,
            semester: review.semester,
            rating: review.rating,
            comment: review.comment,
            createdAt: review.createdAt,
            likeCount: review.likeCount,
            liked: review.liked,
            canEdit: review.canEdit,
            reviewerName: review.reviewerName,
            reviewerAvatar: review.reviewerAvatar,
            savedAt: savedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, courseId = "course_id", semester, rating, comment
        case createdAt = "created_at", likeCount = "like_count"
        case liked, canEdit = "can_edit", reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
        case courseName = "course_name", courseCode = "course_code"
        case teacherName = "teacher_name", courseRating = "course_rating"
        case reviewCount = "review_count", savedAt = "saved_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        courseId = try c.decode(Int.self, forKey: .courseId)
        courseName = try c.decodeIfPresent(String.self, forKey: .courseName) ?? "未知课程"
        courseCode = try c.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        teacherName = try c.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        courseRating = try c.decodeIfPresent(Double.self, forKey: .courseRating) ?? 0
        reviewCount = try c.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        semester = try c.decodeIfPresent(String.self, forKey: .semester) ?? ""
        rating = try c.decode(Int.self, forKey: .rating)
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
        createdAt = try c.decodeStringOrNumberIfPresent(forKey: .createdAt) ?? ""
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        liked = try c.decodeBoolOrIntIfPresent(forKey: .liked) ?? false
        canEdit = try c.decodeBoolOrIntIfPresent(forKey: .canEdit) ?? false
        reviewerName = try c.decodeIfPresent(String.self, forKey: .reviewerName)?.nonEmptyTrimmed
        reviewerAvatar = try c.decodeIfPresent(String.self, forKey: .reviewerAvatar)?.nonEmptyTrimmed
        savedAt = try c.decodeIfPresent(String.self, forKey: .savedAt) ?? Date.now.ISO8601Format()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MyReviewEntry, rhs: MyReviewEntry) -> Bool {
        lhs.id == rhs.id
    }
}
