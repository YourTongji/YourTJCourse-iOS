import Foundation

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let data: [T]
    public let page: Int
    public let limit: Int
    public let hasMore: Bool
    public let total: Int?
    public let totalPages: Int?

    public init(
        data: [T],
        page: Int,
        limit: Int,
        hasMore: Bool,
        total: Int? = nil,
        totalPages: Int? = nil
    ) {
        self.data = data
        self.page = page
        self.limit = limit
        self.hasMore = hasMore
        self.total = total
        self.totalPages = totalPages
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case page
        case limit
        case hasMore
        case hasMoreSnake = "has_more"
        case total
        case totalPages
        case totalPagesSnake = "total_pages"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedData = try container.decode([T].self, forKey: .data)
        let decodedPage = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        let decodedLimit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? decodedData.count
        let decodedTotal = try container.decodeIfPresent(Int.self, forKey: .total)
        let decodedTotalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
            ?? container.decodeIfPresent(Int.self, forKey: .totalPagesSnake)
        let decodedHasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasMoreSnake)
            ?? false

        data = decodedData
        page = decodedPage
        limit = decodedLimit
        total = decodedTotal
        totalPages = decodedTotalPages
        if let decodedTotalPages {
            hasMore = decodedPage < decodedTotalPages
        } else {
            hasMore = decodedHasMore
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(page, forKey: .page)
        try container.encode(limit, forKey: .limit)
        try container.encode(hasMore, forKey: .hasMore)
        try container.encodeIfPresent(total, forKey: .total)
        try container.encodeIfPresent(totalPages, forKey: .totalPages)
    }
}
