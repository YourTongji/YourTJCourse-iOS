import Testing
@testable import DataKit

@Test func editTokenMatchesBackendContract() {
    let token = HMACHelper.editToken(reviewId: 123, userSecret: "test-secret")
    #expect(token == "ef6017d89fd9ce0e4247732ec8c74ba4a930b9bad50ecd19df8bdc6a6ae15da6")
}
