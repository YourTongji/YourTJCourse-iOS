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
        data = try container.decode([T].self, forKey: .data)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? data.count
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasMoreSnake)
            ?? false
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
            ?? container.decodeIfPresent(Int.self, forKey: .totalPagesSnake)
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
