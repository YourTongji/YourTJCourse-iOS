import Foundation

public struct WalletRegistration: Codable, Sendable {
    public let userHash: String
    public let userSecret: String
    public let mnemonic: [String]

    public init(userHash: String, userSecret: String, mnemonic: [String]) {
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
    public let totalEarned: Int
    public let totalSpent: Int

    public init(totalEarned: Int, totalSpent: Int) {
        self.totalEarned = totalEarned
        self.totalSpent = totalSpent
    }

    private enum CodingKeys: String, CodingKey {
        case totalEarned = "total_earned"
        case totalSpent = "total_spent"
    }
}
