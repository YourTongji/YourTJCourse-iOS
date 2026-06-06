import Foundation

public struct CourseDetail: Codable, Sendable {
    public let id: Int
    public let code: String
    public let name: String
    public let rating: Double
    public let reviewCount: Int
    public let teacherName: String
    public let department: String
    public let credit: Double
    public let semesters: [String]
    public let reviews: [Review]
    public let description: String?
    public let isLegacy: Bool?
    public let isIcu: Bool?

    public init(
        id: Int,
        code: String,
        name: String,
        rating: Double,
        reviewCount: Int,
        teacherName: String,
        department: String,
        credit: Double,
        semesters: [String],
        reviews: [Review],
        description: String? = nil,
        isLegacy: Bool? = nil,
        isIcu: Bool? = nil
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.rating = rating
        self.reviewCount = reviewCount
        self.teacherName = teacherName
        self.department = department
        self.credit = credit
        self.semesters = semesters
        self.reviews = reviews
        self.description = description
        self.isLegacy = isLegacy
        self.isIcu = isIcu
    }

    public func replacingReview(_ review: Review) -> CourseDetail {
        var updatedReviews = reviews
        guard let index = updatedReviews.firstIndex(where: { $0.id == review.id }) else {
            return self
        }
        updatedReviews[index] = review

        return CourseDetail(
            id: id,
            code: code,
            name: name,
            rating: rating,
            reviewCount: reviewCount,
            teacherName: teacherName,
            department: department,
            credit: credit,
            semesters: semesters,
            reviews: updatedReviews,
            description: description,
            isLegacy: isLegacy,
            isIcu: isIcu
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case rating
        case reviewAverage = "review_avg"
        case reviewCount = "review_count"
        case teacherName = "teacher_name"
        case department
        case credit
        case semesters
        case reviews
        case description
        case isLegacy = "is_legacy"
        case isIcu = "is_icu"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
            ?? container.decodeIfPresent(Double.self, forKey: .reviewAverage)
            ?? 0
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        teacherName = try container.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        credit = try container.decodeIfPresent(Double.self, forKey: .credit) ?? 0
        semesters = try container.decodeIfPresent([String].self, forKey: .semesters) ?? []
        reviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isLegacy = try container.decodeBoolOrIntIfPresent(forKey: .isLegacy)
        isIcu = try container.decodeBoolOrIntIfPresent(forKey: .isIcu)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encode(name, forKey: .name)
        try container.encode(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encode(teacherName, forKey: .teacherName)
        try container.encode(department, forKey: .department)
        try container.encode(credit, forKey: .credit)
        try container.encode(semesters, forKey: .semesters)
        try container.encode(reviews, forKey: .reviews)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(isLegacy, forKey: .isLegacy)
        try container.encodeIfPresent(isIcu, forKey: .isIcu)
    }
}

public struct RelatedCourses: Codable, Sendable {
    public let teacherOtherCourses: [Course]
    public let sameCourseOtherTeachers: [Course]

    public init(teacherOtherCourses: [Course], sameCourseOtherTeachers: [Course]) {
        self.teacherOtherCourses = teacherOtherCourses
        self.sameCourseOtherTeachers = sameCourseOtherTeachers
    }

    private enum CodingKeys: String, CodingKey {
        case teacherOtherCourses = "teacher_other_courses"
        case sameCourseOtherTeachers = "same_course_other_teachers"
    }
}
