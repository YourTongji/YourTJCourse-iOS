import Foundation
import DomainKit

public struct SchedulerRepository: Sendable {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    public func getCalendars() async throws -> [SchedulerCalendar] {
        let response: PKEnvelope<[SchedulerCalendar]> = try await client.get("/api/getAllCalendar")
        return try unwrap(response) ?? []
    }

    public func getCampuses() async throws -> [SchedulerCampus] {
        let response: PKEnvelope<[SchedulerCampus]> = try await client.get("/api/getAllCampus")
        return try unwrap(response) ?? []
    }

    public func getFaculties() async throws -> [SchedulerFaculty] {
        let response: PKEnvelope<[SchedulerFaculty]> = try await client.get("/api/getAllFaculty")
        return try unwrap(response) ?? []
    }

    public func getOptionalCourseTypes(calendarId: Int) async throws -> [SchedulerCourseNature] {
        let body = CalendarRequest(calendarId: calendarId)
        let response: PKEnvelope<[SchedulerCourseNature]> = try await client.post(
            "/api/findOptionalCourseType",
            body: body
        )
        return try unwrap(response) ?? []
    }

    public func findGrades(calendarId: Int) async throws -> [Int] {
        let body = CalendarRequest(calendarId: calendarId)
        let response: PKEnvelope<GradeListResponse> = try await client.post(
            "/api/findGradeByCalendarId",
            body: body
        )
        return try unwrap(response)?.gradeList ?? []
    }

    public func findMajors(calendarId: Int, grade: Int) async throws -> [SchedulerMajor] {
        let body = MajorRequest(calendarId: calendarId, grade: grade)
        let response: PKEnvelope<[SchedulerMajor]> = try await client.post(
            "/api/findMajorByGrade",
            body: body
        )
        return try unwrap(response) ?? []
    }

    public func findCoursesByMajor(calendarId: Int, grade: Int, code: String) async throws -> [SchedulerMajorCourse] {
        let body = MajorCourseRequest(calendarId: calendarId, grade: grade, code: code)
        let response: PKEnvelope<[SchedulerMajorCourse]> = try await client.post(
            "/api/findCourseByMajor",
            body: body
        )
        return try unwrap(response) ?? []
    }

    public func searchCourses(
        calendarId: Int,
        courseName: String = "",
        courseCode: String = "",
        teacherName: String = "",
        teacherCode: String = "",
        campus: String = "",
        faculty: String = ""
    ) async throws -> SchedulerSearchResponse {
        let body = CourseSearchRequest(
            calendarId: calendarId,
            courseName: courseName,
            courseCode: courseCode,
            teacherName: teacherName,
            teacherCode: teacherCode,
            campus: campus,
            faculty: faculty
        )
        let response: PKEnvelope<SchedulerSearchResponse> = try await client.post(
            "/api/findCourseBySearch",
            body: body
        )
        return try unwrap(response) ?? SchedulerSearchResponse(courses: [])
    }

    public func findCourseDetails(calendarId: Int, courseCode: String) async throws -> [SchedulerTeachingClass] {
        let body = CourseDetailRequest(calendarId: calendarId, courseCode: courseCode)
        let response: PKEnvelope<[SchedulerTeachingClass]> = try await client.post(
            "/api/findCourseDetailByCode",
            body: body
        )
        return try unwrap(response) ?? []
    }

    /// Batch fetch teaching class details for multiple course codes.
    /// Used by the sync engine to compare old vs new data efficiently.
    public func findCourseDetailsBatch(calendarId: Int, courseCodes: [String]) async throws -> [String: [SchedulerTeachingClass]] {
        var result: [String: [SchedulerTeachingClass]] = [:]
        for code in courseCodes {
            if let details = try? await findCourseDetails(calendarId: calendarId, courseCode: code) {
                result[code] = details
            }
        }
        return result
    }

    public func findCoursesByTime(calendarId: Int, day: Int, section: Int) async throws -> [SchedulerCourseSummary] {
        let body = CourseTimeRequest(calendarId: calendarId, day: day, section: section)
        let response: PKEnvelope<[SchedulerCourseSummary]> = try await client.post(
            "/api/findCourseByTime",
            body: body
        )
        return try unwrap(response) ?? []
    }

    public func getLatestUpdateTime() async throws -> String? {
        let response: PKEnvelope<String> = try await client.get("/api/getLatestUpdateTime")
        return try unwrap(response)
    }

    private func unwrap<T>(_ envelope: PKEnvelope<T>) throws -> T? {
        guard (200...299).contains(envelope.code) else {
            throw APIError.httpError(statusCode: envelope.code, message: envelope.msg)
        }
        return envelope.data
    }
}

private struct PKEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let code: Int
    let msg: String?
    let data: T?
}

private struct CalendarRequest: Encodable, Sendable {
    let calendarId: Int
}

private struct GradeListResponse: Decodable, Sendable {
    let gradeList: [Int]
}

private struct MajorRequest: Encodable, Sendable {
    let calendarId: Int
    let grade: Int
}

private struct MajorCourseRequest: Encodable, Sendable {
    let calendarId: Int
    let grade: Int
    let code: String
}

private struct CourseSearchRequest: Encodable, Sendable {
    let calendarId: Int
    let courseName: String
    let courseCode: String
    let teacherName: String
    let teacherCode: String
    let campus: String
    let faculty: String
}

private struct CourseDetailRequest: Encodable, Sendable {
    let calendarId: Int
    let courseCode: String
}

private struct CourseTimeRequest: Encodable, Sendable {
    let calendarId: Int
    let day: Int
    let section: Int
}
