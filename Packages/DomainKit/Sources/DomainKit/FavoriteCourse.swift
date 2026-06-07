import Foundation

public struct FavoriteCourse: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let code: String
    public let name: String
    public let teacherName: String
    public let department: String
    public let rating: Double
    public let reviewCount: Int
    public let credit: Double
    public let savedAt: Date

    public init(
        id: Int,
        code: String,
        name: String,
        teacherName: String,
        department: String,
        rating: Double,
        reviewCount: Int,
        credit: Double,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.teacherName = teacherName
        self.department = department
        self.rating = rating
        self.reviewCount = reviewCount
        self.credit = credit
        self.savedAt = savedAt
    }

    public init(course: CourseDetail, savedAt: Date = Date()) {
        self.init(
            id: course.id,
            code: course.code,
            name: course.name,
            teacherName: course.teacherName,
            department: course.department,
            rating: course.rating,
            reviewCount: course.reviewCount,
            credit: course.credit,
            savedAt: savedAt
        )
    }
}
