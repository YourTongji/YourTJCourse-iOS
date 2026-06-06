import Foundation

public struct SchedulerCalendar: Codable, Identifiable, Hashable, Sendable {
    public let calendarId: Int
    public let calendarName: String

    public var id: Int { calendarId }

    public init(calendarId: Int, calendarName: String) {
        self.calendarId = calendarId
        self.calendarName = calendarName
    }
}

public struct SchedulerCampus: Codable, Identifiable, Hashable, Sendable {
    public let campusId: String
    public let campusName: String

    public var id: String { campusId.isEmpty ? campusName : campusId }

    public init(campusId: String, campusName: String) {
        self.campusId = campusId
        self.campusName = campusName
    }
}

public struct SchedulerFaculty: Codable, Identifiable, Hashable, Sendable {
    public let facultyId: String
    public let facultyName: String

    public var id: String { facultyId.isEmpty ? facultyName : facultyId }

    public init(facultyId: String, facultyName: String) {
        self.facultyId = facultyId
        self.facultyName = facultyName
    }
}

public struct SchedulerCourseNature: Codable, Identifiable, Hashable, Sendable {
    public let courseLabelId: Int
    public let courseLabelName: String

    public var id: Int { courseLabelId }

    public init(courseLabelId: Int, courseLabelName: String) {
        self.courseLabelId = courseLabelId
        self.courseLabelName = courseLabelName
    }
}

public struct SchedulerMajor: Codable, Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String

    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct SchedulerSearchResponse: Decodable, Sendable {
    public let courses: [SchedulerCourseSummary]
    public let sizeLimit: Int?

    public init(courses: [SchedulerCourseSummary], sizeLimit: Int? = nil) {
        self.courses = courses
        self.sizeLimit = sizeLimit
    }
}

public struct SchedulerCourseSummary: Codable, Identifiable, Hashable, Sendable {
    public let courseCode: String
    public let courseName: String
    public let faculty: String
    public let facultyI18n: String
    public let courseNature: [String]
    public let campus: [String]
    public let credit: Double

    public var id: String {
        [courseCode, courseName, facultyI18n].joined(separator: "|")
    }

    public init(
        courseCode: String,
        courseName: String,
        faculty: String,
        facultyI18n: String,
        courseNature: [String],
        campus: [String],
        credit: Double
    ) {
        self.courseCode = courseCode
        self.courseName = courseName
        self.faculty = faculty
        self.facultyI18n = facultyI18n
        self.courseNature = courseNature
        self.campus = campus
        self.credit = credit
    }

    private enum CodingKeys: String, CodingKey {
        case courseCode, courseName, faculty, facultyI18n, courseNature, campus, campusList = "campus_list", credit
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName) ?? ""
        faculty = try container.decodeIfPresent(String.self, forKey: .faculty) ?? ""
        facultyI18n = try container.decodeIfPresent(String.self, forKey: .facultyI18n) ?? faculty
        courseNature = Self.decodeStringList(from: container, key: .courseNature)
        let campusValue = Self.decodeStringList(from: container, key: .campus)
        campus = campusValue.isEmpty ? Self.decodeStringList(from: container, key: .campusList) : campusValue
        credit = Self.decodeDouble(from: container, key: .credit)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(courseCode, forKey: .courseCode)
        try container.encode(courseName, forKey: .courseName)
        try container.encode(faculty, forKey: .faculty)
        try container.encode(facultyI18n, forKey: .facultyI18n)
        try container.encode(courseNature, forKey: .courseNature)
        try container.encode(campus, forKey: .campus)
        try container.encode(credit, forKey: .credit)
    }
}

public struct SchedulerMajorCourse: Decodable, Identifiable, Hashable, Sendable {
    public let courseCode: String
    public let courseName: String
    public let faculty: String
    public let facultyI18n: String
    public let credit: Double
    public let grade: Int?
    public let courseNature: [String]
    public let courses: [SchedulerTeachingClass]

    public var id: String { "\(courseCode)|\(grade ?? 0)" }

    public var summary: SchedulerCourseSummary {
        SchedulerCourseSummary(
            courseCode: courseCode,
            courseName: courseName,
            faculty: faculty,
            facultyI18n: facultyI18n,
            courseNature: courseNature,
            campus: Array(Set(courses.map(\.campus).filter { !$0.isEmpty })).sorted(),
            credit: credit
        )
    }

    public init(
        courseCode: String,
        courseName: String,
        faculty: String,
        facultyI18n: String,
        credit: Double,
        grade: Int?,
        courseNature: [String],
        courses: [SchedulerTeachingClass]
    ) {
        self.courseCode = courseCode
        self.courseName = courseName
        self.faculty = faculty
        self.facultyI18n = facultyI18n
        self.credit = credit
        self.grade = grade
        self.courseNature = courseNature
        self.courses = courses
    }

    private enum CodingKeys: String, CodingKey {
        case courseCode, courseName, faculty, facultyI18n, credit, grade, courseNature, courses
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName) ?? ""
        faculty = try container.decodeIfPresent(String.self, forKey: .faculty) ?? ""
        facultyI18n = try container.decodeIfPresent(String.self, forKey: .facultyI18n) ?? faculty
        credit = SchedulerCourseSummary.decodeDouble(from: container, key: .credit)
        grade = try container.decodeIfPresent(Int.self, forKey: .grade)
        courseNature = SchedulerCourseSummary.decodeStringList(from: container, key: .courseNature)
        courses = try container.decodeIfPresent([SchedulerTeachingClass].self, forKey: .courses) ?? []
    }
}

public struct SchedulerTeacher: Codable, Hashable, Sendable {
    public let teacherCode: String
    public let teacherName: String

    public init(teacherCode: String, teacherName: String) {
        self.teacherCode = teacherCode
        self.teacherName = teacherName
    }
}

public struct SchedulerArrangement: Codable, Identifiable, Hashable, Sendable {
    public let arrangementText: String
    public let occupyDay: Int?
    public let occupyTime: [Int]?
    public let occupyWeek: [Int]?
    public let occupyRoom: String?
    public let teacherAndCode: String?

    public var id: String { arrangementText }

    public init(
        arrangementText: String,
        occupyDay: Int?,
        occupyTime: [Int]?,
        occupyWeek: [Int]?,
        occupyRoom: String?,
        teacherAndCode: String?
    ) {
        self.arrangementText = arrangementText
        self.occupyDay = occupyDay
        self.occupyTime = occupyTime
        self.occupyWeek = occupyWeek
        self.occupyRoom = occupyRoom
        self.teacherAndCode = teacherAndCode
    }

    public var dayName: String {
        guard let occupyDay else { return "未定" }
        return ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"][safe: occupyDay] ?? "未定"
    }

    public var timeText: String {
        guard let occupyTime, !occupyTime.isEmpty else { return "时间未定" }
        guard let first = occupyTime.first, let last = occupyTime.last else { return "时间未定" }
        return first == last ? "第 \(first) 节" : "第 \(first)-\(last) 节"
    }

    public var weekText: String {
        guard let occupyWeek, !occupyWeek.isEmpty else { return "周次未定" }
        guard let first = occupyWeek.first, let last = occupyWeek.last else { return "周次未定" }
        return first == last ? "第 \(first) 周" : "第 \(first)-\(last) 周"
    }

    public func conflicts(with other: SchedulerArrangement) -> Bool {
        guard occupyDay == other.occupyDay, occupyDay != nil else { return false }
        guard Self.overlaps(occupyTime, other.occupyTime) else { return false }
        return Self.overlaps(occupyWeek, other.occupyWeek, unknownMeansOverlap: true)
    }

    private static func overlaps(_ lhs: [Int]?, _ rhs: [Int]?, unknownMeansOverlap: Bool = false) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else {
            return unknownMeansOverlap
        }
        return !Set(lhs).isDisjoint(with: Set(rhs))
    }
}

public struct SchedulerTeachingClass: Codable, Identifiable, Hashable, Sendable {
    public let code: String
    public let teachers: [SchedulerTeacher]
    public let campus: String
    public let teachingLanguage: String
    public let arrangementInfo: [SchedulerArrangement]

    public var id: String { code }

    public init(
        code: String,
        teachers: [SchedulerTeacher],
        campus: String,
        teachingLanguage: String,
        arrangementInfo: [SchedulerArrangement]
    ) {
        self.code = code
        self.teachers = teachers
        self.campus = campus
        self.teachingLanguage = teachingLanguage
        self.arrangementInfo = arrangementInfo
    }

    public var teacherNames: String {
        let names = teachers.map(\.teacherName).filter { !$0.isEmpty }
        return names.isEmpty ? "教师未定" : names.joined(separator: " / ")
    }

    public var scheduleSummary: String {
        let parts = arrangementInfo.map { "\($0.dayName) \($0.timeText)" }
        return parts.isEmpty ? "时间未定" : parts.joined(separator: "；")
    }

    public func conflicts(with other: SchedulerTeachingClass) -> Bool {
        arrangementInfo.contains { left in
            other.arrangementInfo.contains { right in
                left.conflicts(with: right)
            }
        }
    }
}

public struct SchedulerSelectedClass: Codable, Identifiable, Hashable, Sendable {
    public let course: SchedulerCourseSummary
    public let teachingClass: SchedulerTeachingClass

    public var id: String { "\(course.courseCode)|\(teachingClass.code)" }

    public init(course: SchedulerCourseSummary, teachingClass: SchedulerTeachingClass) {
        self.course = course
        self.teachingClass = teachingClass
    }

    public func conflicts(with other: SchedulerSelectedClass) -> Bool {
        teachingClass.conflicts(with: other.teachingClass)
    }
}

fileprivate extension SchedulerCourseSummary {
    static func decodeStringList<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> [String] {
        if let values = try? container.decodeIfPresent([String].self, forKey: key) {
            return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    static func decodeDouble<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Double {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(value) ?? 0
        }
        return 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
