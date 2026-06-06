import Foundation
import Testing
@testable import DomainKit

@Test func detectsTeachingClassTimeConflictsByDaySectionAndWeek() {
    let first = teachingClass(day: 1, sections: [1, 2], weeks: [1, 2, 3, 4])
    let overlapping = teachingClass(day: 1, sections: [2, 3], weeks: [4, 5, 6])
    let differentWeek = teachingClass(day: 1, sections: [2, 3], weeks: [7, 8])
    let differentDay = teachingClass(day: 2, sections: [1, 2], weeks: [1, 2, 3, 4])

    #expect(first.conflicts(with: overlapping))
    #expect(!first.conflicts(with: differentWeek))
    #expect(!first.conflicts(with: differentDay))
}

@Test func treatsUnknownWeeksAsPotentialConflicts() {
    let knownWeeks = teachingClass(day: 3, sections: [5, 6], weeks: [1, 2])
    let unknownWeeks = teachingClass(day: 3, sections: [6, 7], weeks: nil)

    #expect(knownWeeks.conflicts(with: unknownWeeks))
}

@Test func selectedClassCodableRoundTrips() throws {
    let selected = SchedulerSelectedClass(
        course: SchedulerCourseSummary(
            courseCode: "122004",
            courseName: "高等数学",
            faculty: "数学科学学院",
            facultyI18n: "数学科学学院",
            courseNature: ["公共基础课"],
            campus: ["四平路校区"],
            credit: 5
        ),
        teachingClass: teachingClass(day: 1, sections: [1, 2], weeks: [1, 2, 3])
    )

    let data = try JSONEncoder().encode([selected])
    let decoded = try JSONDecoder().decode([SchedulerSelectedClass].self, from: data)

    #expect(decoded == [selected])
}

private func teachingClass(day: Int, sections: [Int], weeks: [Int]?) -> SchedulerTeachingClass {
    SchedulerTeachingClass(
        code: "\(day)-\(sections.map(String.init).joined())-\(weeks?.count ?? 0)",
        teachers: [],
        campus: "四平路校区",
        teachingLanguage: "中文",
        arrangementInfo: [
            SchedulerArrangement(
                arrangementText: "星期\(day) \(sections)",
                occupyDay: day,
                occupyTime: sections,
                occupyWeek: weeks,
                occupyRoom: nil,
                teacherAndCode: nil
            )
        ]
    )
}
