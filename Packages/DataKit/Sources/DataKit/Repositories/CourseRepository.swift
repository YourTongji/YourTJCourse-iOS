import Foundation
import DomainKit

/// Provides typed access to course listing, detail, and search endpoints.
public struct CourseRepository: Sendable {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Course List with Search / Filter

    /// Fetches a paginated list of courses matching the given filters.
    ///
    /// - Parameters:
    ///   - query: Free-text search query.
    ///   - departments: Comma-separated department filter.
    ///   - onlyWithReviews: Only include courses that have at least one review.
    ///   - courseName: Filter by course name.
    ///   - courseCode: Filter by course code.
    ///   - teacherName: Filter by teacher name.
    ///   - campus: Filter by campus.
    ///   - faculty: Filter by faculty.
    ///   - page: Page number (1-based).
    ///   - limit: Items per page (max 50).
    ///   - includeTotal: Whether the response includes total count and total pages.
    /// - Returns: A paginated response of `Course` items.
    public func getCourses(
        query: String? = nil,
        departments: String? = nil,
        onlyWithReviews: Bool = false,
        courseName: String? = nil,
        courseCode: String? = nil,
        teacherName: String? = nil,
        campus: String? = nil,
        faculty: String? = nil,
        page: Int = 1,
        limit: Int = 20,
        includeTotal: Bool = false
    ) async throws -> PaginatedResponse<Course> {
        var items: [URLQueryItem] = []
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if let d = departments, !d.isEmpty { items.append(URLQueryItem(name: "departments", value: d)) }
        if onlyWithReviews { items.append(URLQueryItem(name: "onlyWithReviews", value: "true")) }
        if let cn = courseName, !cn.isEmpty { items.append(URLQueryItem(name: "courseName", value: cn)) }
        if let cc = courseCode, !cc.isEmpty { items.append(URLQueryItem(name: "courseCode", value: cc)) }
        if let tn = teacherName, !tn.isEmpty { items.append(URLQueryItem(name: "teacherName", value: tn)) }
        if let c = campus, !c.isEmpty { items.append(URLQueryItem(name: "campus", value: c)) }
        if let f = faculty, !f.isEmpty { items.append(URLQueryItem(name: "faculty", value: f)) }
        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "limit", value: String(min(limit, 50))))
        if includeTotal { items.append(URLQueryItem(name: "includeTotal", value: "true")) }

        return try await client.get("/api/courses", query: items)
    }

    // MARK: - Course Detail

    /// Fetches detailed information for a specific course, including its reviews.
    ///
    /// - Parameters:
    ///   - id: The course ID.
    ///   - clientId: Optional client ID for tracking like status.
    /// - Returns: A `CourseDetail` with reviews and metadata.
    public func getCourseDetail(id: Int, clientId: String? = nil) async throws -> CourseDetail {
        var items: [URLQueryItem] = []
        if let cid = clientId, !cid.isEmpty {
            items.append(URLQueryItem(name: "clientId", value: cid))
        }
        return try await client.get("/api/course/\(id)", query: items)
    }

    // MARK: - Related Courses

    /// Fetches courses related to the given course (same teacher's other courses
    /// and same course taught by other teachers).
    /// - Parameter id: The course ID.
    /// - Returns: A `RelatedCourses` grouping.
    public func getRelatedCourses(id: Int) async throws -> RelatedCourses {
        try await client.get("/api/course/\(id)/related")
    }

    // MARK: - Lookup by Course Code

    /// Looks up a course by its code, optionally filtering by teacher.
    /// - Parameters:
    ///   - code: The course code.
    ///   - teacherName: Optional teacher name filter.
    ///   - teacherCode: Optional teacher code filter.
    /// - Returns: A `CourseDetail` if found.
    public func getCourseByCode(
        code: String,
        teacherName: String? = nil,
        teacherCode: String? = nil
    ) async throws -> CourseDetail {
        var items: [URLQueryItem] = []
        if let tn = teacherName { items.append(URLQueryItem(name: "teacherName", value: tn)) }
        if let tc = teacherCode { items.append(URLQueryItem(name: "teacherCode", value: tc)) }
        return try await client.get("/api/course/by-code/\(code)", query: items)
    }
}
