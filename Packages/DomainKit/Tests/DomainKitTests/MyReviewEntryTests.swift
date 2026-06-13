import Foundation
import Testing
@testable import DomainKit

@Test func decodesMyReviewEntryWithNumericDateAndIntegerFlags() throws {
    let json = """
    {
      "id": 16668,
      "course_id": 2849,
      "semester": "2025-2026第一学期",
      "rating": 5,
      "comment": "课程内容",
      "created_at": 1772885683,
      "like_count": 7,
      "liked": 1,
      "can_edit": 1,
      "reviewer_name": "   ",
      "reviewer_avatar": "",
      "course_name": "新概念武器",
      "course_code": "360027",
      "teacher_name": "袁品仕"
    }
    """

    let entry = try JSONDecoder().decode(MyReviewEntry.self, from: Data(json.utf8))

    #expect(entry.createdAt == "1772885683")
    #expect(entry.liked == true)
    #expect(entry.canEdit == true)
    #expect(entry.reviewerName == nil)
    #expect(entry.reviewerAvatar == nil)
    #expect(entry.review.createdAt == "1772885683")
    #expect(entry.review.canEdit == true)
}

@Test func decodesWalletTransactionMillisecondTimestamps() throws {
    let json = """
    {
      "id": 42,
      "tx_id": "tx_42",
      "type_name": "review_reward",
      "type_display_name": "评课奖励",
      "from_user_hash": null,
      "to_user_hash": "user_hash",
      "amount": 10,
      "status": "completed",
      "title": "发表评价",
      "description": "奖励",
      "created_at": 1772885683000,
      "completed_at": 1772885684000
    }
    """

    let transaction = try JSONDecoder().decode(WalletTransaction.self, from: Data(json.utf8))

    #expect(transaction.createdAt.timeIntervalSince1970 == 1_772_885_683)
    #expect(transaction.completedAt?.timeIntervalSince1970 == 1_772_885_684)
    #expect(transaction.toUserHash == "user_hash")
    #expect(transaction.amount == 10)
}
