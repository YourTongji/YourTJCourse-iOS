import Testing
import Foundation
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
