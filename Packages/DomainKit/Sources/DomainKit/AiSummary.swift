import Foundation

public struct AiSummaryResponse: Codable, Sendable {
    public let data: AiSummaryData
    public let generatedAt: Int64
    public let cache: String?
}

public struct AiSummaryData: Codable, Sendable {
    public let ratingConsensus: String
    public let keywords: [String]
    public let pros: [String]
    public let cons: [String]
    public let representative: [RepresentativeReview]

    enum CodingKeys: String, CodingKey {
        case ratingConsensus = "rating_consensus"
        case keywords, pros, cons, representative
    }
}

public struct RepresentativeReview: Codable, Sendable {
    public let text: String
    public let sentiment: String
}

public extension AiSummaryData {
    /// Check if the summary has actual content (not just "数据不足")
    var hasContent: Bool {
        ratingConsensus != "数据不足" && (keywords.count > 0 || pros.count > 0 || cons.count > 0)
    }
}
