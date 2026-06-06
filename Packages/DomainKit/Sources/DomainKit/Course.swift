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
    public let credit: Double
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
        credit: Double,
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
        case reviewAverage = "review_avg"
        case reviewCount = "review_count"
        case isLegacy = "is_legacy"
        case teacherName = "teacher_name"
        case department
        case credit
        case semesters
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
        isLegacy = try container.decodeIntOrBoolIfPresent(forKey: .isLegacy) ?? 0
        teacherName = try container.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        credit = try container.decodeIfPresent(Double.self, forKey: .credit) ?? 0
        semesters = try container.decodeIfPresent([String].self, forKey: .semesters) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encode(name, forKey: .name)
        try container.encode(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encode(isLegacy, forKey: .isLegacy)
        try container.encode(teacherName, forKey: .teacherName)
        try container.encode(department, forKey: .department)
        try container.encode(credit, forKey: .credit)
        try container.encode(semesters, forKey: .semesters)
    }
}

extension KeyedDecodingContainer {
    func decodeIntOrBoolIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? 1 : 0
        }
        return nil
    }

    func decodeBoolOrIntIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        return nil
    }

    func decodeStringOrNumberIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
