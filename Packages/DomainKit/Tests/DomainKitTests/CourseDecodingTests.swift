import Foundation
import Testing
@testable import DomainKit

@Test func decodesProductionCourseListResponse() throws {
    let json = """
    {
      "data": [
        {
          "id": 2849,
          "code": "360027",
          "name": "新概念武器",
          "rating": 5,
          "review_count": 32,
          "is_legacy": 0,
          "teacher_name": "袁品仕",
          "department": "武装部",
          "credit": 1.5,
          "semester_names": "2025-2026学年第2学期",
          "semesters": ["2025-2026学年第2学期"]
        }
      ],
      "page": 1,
      "limit": 20,
      "hasMore": false,
      "total": 8918,
      "totalPages": 446
    }
    """

    let response = try JSONDecoder().decode(PaginatedResponse<Course>.self, from: Data(json.utf8))

    #expect(response.data.first?.credit == 1.5)
    #expect(response.data.first?.rating == 5)
    #expect(response.hasMore == true)
    #expect(response.total == 8918)
    #expect(response.totalPages == 446)
}

@Test func decodesProductionCourseDetailResponse() throws {
    let json = """
    {
      "id": 2849,
      "code": "360027",
      "name": "新概念武器",
      "credit": 1.5,
      "department": "武装部",
      "teacher_id": 2782,
      "review_count": 32,
      "review_avg": 5,
      "is_legacy": 0,
      "is_icu": 0,
      "teacher_name": "袁品仕",
      "semesters": ["2025-2026学年第2学期"],
      "reviews": [
        {
          "sqid": "hJqd",
          "id": 16668,
          "course_id": 2849,
          "semester": "2025-2026第一学期",
          "rating": 5,
          "comment": "课程内容",
          "score": "优",
          "created_at": 1772885683,
          "approve_count": 0,
          "disapprove_count": 0,
          "is_hidden": 0,
          "is_legacy": 0,
          "is_icu": 1,
          "reviewer_name": "",
          "reviewer_avatar": "",
          "like_count": 0,
          "liked": false,
          "can_edit": true
        }
      ]
    }
    """

    let detail = try JSONDecoder().decode(CourseDetail.self, from: Data(json.utf8))

    #expect(detail.credit == 1.5)
    #expect(detail.rating == 5)
    #expect(detail.isLegacy == false)
    #expect(detail.isIcu == false)
    #expect(detail.reviews.first?.createdAt == "1772885683")
    #expect(detail.reviews.first?.canEdit == true)
}

@Test func decodesProductionRelatedCoursesResponse() throws {
    let json = """
    {
      "teacher_other_courses": [
        {
          "id": 11172,
          "code": "36002902",
          "name": "军事理论",
          "teacher_name": "袁品仕",
          "review_avg": 4.52,
          "review_count": 25
        }
      ],
      "same_course_other_teachers": []
    }
    """

    let related = try JSONDecoder().decode(RelatedCourses.self, from: Data(json.utf8))

    #expect(related.teacherOtherCourses.first?.rating == 4.52)
    #expect(related.teacherOtherCourses.first?.department == "")
    #expect(related.teacherOtherCourses.first?.credit == 0)
}
