import Foundation

public struct WalletCredentials: Codable, Equatable, Sendable {
    public let mnemonic: String
    public let userHash: String
    public let userSecret: String

    public init(mnemonic: String, userHash: String, userSecret: String) {
        self.mnemonic = mnemonic
        self.userHash = userHash
        self.userSecret = userSecret
    }
}

public struct WalletRegistration: Codable, Sendable {
    public let userHash: String
    public let userSecret: String
    public let mnemonic: String

    public init(userHash: String, userSecret: String, mnemonic: String) {
        self.userHash = userHash
        self.userSecret = userSecret
        self.mnemonic = mnemonic
    }

    private enum CodingKeys: String, CodingKey {
        case userHash = "user_hash"
        case userSecret = "user_secret"
        case mnemonic
    }
}

public struct CreditWallet: Codable, Equatable, Sendable {
    public let userHash: String
    public let balance: Int
    public let createdAt: Date?
    public let lastActiveAt: Date?

    public init(userHash: String, balance: Int, createdAt: Date? = nil, lastActiveAt: Date? = nil) {
        self.userHash = userHash
        self.balance = balance
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }

    private enum CodingKeys: String, CodingKey {
        case userHash, balance, createdAt, lastActiveAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userHash = try container.decode(String.self, forKey: .userHash)
        balance = try container.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        createdAt = Self.decodeMillisecondsDate(from: container, key: .createdAt)
        lastActiveAt = Self.decodeMillisecondsDate(from: container, key: .lastActiveAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userHash, forKey: .userHash)
        try container.encode(balance, forKey: .balance)
        try container.encodeIfPresent(createdAt.map { Int($0.timeIntervalSince1970 * 1000) }, forKey: .createdAt)
        try container.encodeIfPresent(lastActiveAt.map { Int($0.timeIntervalSince1970 * 1000) }, forKey: .lastActiveAt)
    }

    private static func decodeMillisecondsDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Date? {
        if let milliseconds = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        }
        return nil
    }
}

public struct WalletBalance: Codable, Sendable {
    public let balance: Int
    public let totalEarned: Int?

    public init(balance: Int, totalEarned: Int? = nil) {
        self.balance = balance
        self.totalEarned = totalEarned
    }

    private enum CodingKeys: String, CodingKey {
        case balance
        case totalEarned = "total_earned"
    }
}

public struct WalletSummary: Codable, Sendable {
    public let userHash: String?
    public let balance: Int
    public let date: String?
    public let today: WalletTodaySummary
    public let totalEarned: Int?
    public let totalSpent: Int?

    public init(
        userHash: String? = nil,
        balance: Int,
        date: String? = nil,
        today: WalletTodaySummary = .init(),
        totalEarned: Int? = nil,
        totalSpent: Int? = nil
    ) {
        self.userHash = userHash
        self.balance = balance
        self.date = date
        self.today = today
        self.totalEarned = totalEarned
        self.totalSpent = totalSpent
    }

    private enum CodingKeys: String, CodingKey {
        case userHash, balance, date, today
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userHash = try container.decodeIfPresent(String.self, forKey: .userHash)
        balance = try container.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        date = try container.decodeIfPresent(String.self, forKey: .date)
        today = try container.decodeIfPresent(WalletTodaySummary.self, forKey: .today) ?? .init()
        totalEarned = try container.decodeIfPresent(Int.self, forKey: .totalEarned)
        totalSpent = try container.decodeIfPresent(Int.self, forKey: .totalSpent)
    }
}

public struct WalletTodaySummary: Codable, Equatable, Sendable {
    public let reviewReward: Int
    public let likePendingDelta: Int
    public let likePendingPoints: Int
    public let likePendingPositive: Int
    public let likePendingNegative: Int

    public init(
        reviewReward: Int = 0,
        likePendingDelta: Int = 0,
        likePendingPoints: Int = 0,
        likePendingPositive: Int = 0,
        likePendingNegative: Int = 0
    ) {
        self.reviewReward = reviewReward
        self.likePendingDelta = likePendingDelta
        self.likePendingPoints = likePendingPoints
        self.likePendingPositive = likePendingPositive
        self.likePendingNegative = likePendingNegative
    }

    private enum CodingKeys: String, CodingKey {
        case reviewReward, likePendingDelta, likePendingPoints, likePendingPositive, likePendingNegative
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviewReward = try container.decodeIfPresent(Int.self, forKey: .reviewReward) ?? 0
        likePendingDelta = try container.decodeIfPresent(Int.self, forKey: .likePendingDelta) ?? 0
        likePendingPoints = try container.decodeIfPresent(Int.self, forKey: .likePendingPoints) ?? likePendingDelta * 3
        likePendingPositive = try container.decodeIfPresent(Int.self, forKey: .likePendingPositive) ?? 0
        likePendingNegative = try container.decodeIfPresent(Int.self, forKey: .likePendingNegative) ?? 0
    }
}
