import Foundation

public struct Course: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let code: String
    public let name: String
    public let rating: Double
    public let reviewCount: Int
    public let isLegacy: Int
    public let teacherName: String
    public let department: String
    public let credit: Int
    public let semesters: [String]

    public init(
        id: Int,
        code: String,
        name: String,
        rating: Double,
        reviewCount: Int,
        isLegacy: Int,
        teacherName: String,
        department: String,
        credit: Int,
        semesters: [String]
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.rating = rating
        self.reviewCount = reviewCount
        self.isLegacy = isLegacy
        self.teacherName = teacherName
        self.department = department
        self.credit = credit
        self.semesters = semesters
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(code)
        hasher.combine(name)
    }

    public static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id && lhs.code == rhs.code && lhs.name == rhs.name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case rating
        case reviewCount = "review_count"
        case isLegacy = "is_legacy"
        case teacherName = "teacher_name"
        case department
        case credit
        case semesters
    }
}
