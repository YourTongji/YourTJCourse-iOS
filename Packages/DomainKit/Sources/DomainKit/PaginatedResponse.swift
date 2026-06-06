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
        case hasMore = "has_more"
        case total
        case totalPages = "total_pages"
    }
}
