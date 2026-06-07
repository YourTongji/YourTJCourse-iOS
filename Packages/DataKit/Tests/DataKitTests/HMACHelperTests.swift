import Testing
import Foundation
import DomainKit
@testable import DataKit

@Test func editTokenMatchesBackendContract() {
    let token = HMACHelper.editToken(reviewId: 123, userSecret: "test-secret")
    #expect(token == "ef6017d89fd9ce0e4247732ec8c74ba4a930b9bad50ecd19df8bdc6a6ae15da6")
}

@Test func likeResponseDecodesServerLikeState() throws {
    let json = """
    {
      "success": true,
      "liked": true,
      "like_count": 12
    }
    """

    let response = try JSONDecoder().decode(LikeResponse.self, from: Data(json.utf8))

    #expect(response.success == true)
    #expect(response.liked == true)
    #expect(response.likeCount == 12)
}

@Test func favoriteStorePersistsAndTogglesCourses() {
    let key = "CourseFavoriteStoreTests.\(UUID().uuidString)"
    let store = CourseFavoriteStore(key: key)
    defer { UserDefaults.standard.removeObject(forKey: key) }

    let favorite = FavoriteCourse(
        id: 42,
        code: "320001",
        name: "大学体育",
        teacherName: "张老师",
        department: "体育教学部",
        rating: 4.6,
        reviewCount: 18,
        credit: 1
    )

    #expect(store.load().isEmpty)
    #expect(store.toggle(favorite) == true)
    #expect(store.isFavorite(courseId: 42))
    #expect(store.isFavorite(courseCode: "320001"))
    #expect(store.load().first?.name == "大学体育")
    #expect(store.toggle(favorite) == false)
    #expect(!store.isFavorite(courseId: 42))
}
