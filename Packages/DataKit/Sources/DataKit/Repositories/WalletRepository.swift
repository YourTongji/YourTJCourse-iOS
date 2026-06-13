import Foundation
import DomainKit

/// Manages the Credit wallet lifecycle: local derivation, Keychain persistence,
/// and registration/summary calls to the Credit core service.
public struct WalletRepository: Sendable {
    private let creditClient: CreditAPIClient

    public init(creditClient: CreditAPIClient = .shared) {
        self.creditClient = creditClient
    }

    // MARK: - Wallet Generation

    /// Generates a deterministic Credit wallet from the same student ID + PIN
    /// algorithm used by `YourTJ-Credit-Serverless/shared/utils/wallet.ts`.
    public func generateWallet(studentId: String, pin: String) throws -> WalletCredentials {
        let wallet = try MnemonicHelper.generate(studentId: studentId, pin: pin)
        return WalletCredentials(
            mnemonic: wallet.mnemonic,
            userHash: wallet.userHash,
            userSecret: wallet.userSecret
        )
    }

    /// Restores wallet credentials from a three-word Credit mnemonic.
    public func restoreWallet(from mnemonic: String) throws -> WalletCredentials {
        let wallet = try MnemonicHelper.restore(mnemonic: mnemonic)
        return WalletCredentials(
            mnemonic: wallet.mnemonic,
            userHash: wallet.userHash,
            userSecret: wallet.userSecret
        )
    }

    public func normalizeMnemonic(_ phrase: String) -> String {
        MnemonicHelper.normalize(phrase)
    }

    // MARK: - Keychain Persistence

    /// Persists wallet credentials to the secure Keychain.
    public func saveWallet(_ wallet: WalletCredentials) throws {
        try KeychainManager.save(key: "wallet_mnemonic", value: wallet.mnemonic, useBiometrics: true)
        try KeychainManager.save(key: "wallet_userHash", value: wallet.userHash)
        try KeychainManager.save(key: "wallet_userSecret", value: wallet.userSecret)
    }

    /// Loads wallet credentials from the Keychain.
    public func loadWallet() -> WalletCredentials? {
        guard
            let userHash = try? KeychainManager.read(key: "wallet_userHash"),
            let userSecret = try? KeychainManager.read(key: "wallet_userSecret"),
            !userHash.isEmpty,
            !userSecret.isEmpty
        else {
            return nil
        }
        return WalletCredentials(mnemonic: "", userHash: userHash, userSecret: userSecret)
    }

    /// Checks whether a wallet exists in the Keychain.
    public func hasWallet() -> Bool {
        loadWallet() != nil
    }

    /// Deletes all wallet credentials from the Keychain.
    public func deleteWallet() throws {
        try KeychainManager.delete(key: "wallet_mnemonic")
        try KeychainManager.delete(key: "wallet_userHash")
        try KeychainManager.delete(key: "wallet_userSecret")
    }

    // MARK: - Credit Service

    @discardableResult
    public func registerWallet(_ wallet: WalletCredentials) async throws -> CreditWallet {
        try await creditClient.registerWallet(userHash: wallet.userHash, userSecret: wallet.userSecret)
    }

    public func fetchWallet(userHash: String) async throws -> CreditWallet {
        try await creditClient.fetchWallet(userHash: userHash)
    }

    public func fetchBalance(userHash: String) async throws -> WalletBalance {
        try await creditClient.fetchBalance(userHash: userHash)
    }

    public func fetchJCourseSummary(userHash: String) async throws -> WalletSummary {
        try await creditClient.fetchJCourseSummary(userHash: userHash)
    }

    public func fetchTransactionHistory(userHash: String, page: Int = 1, limit: Int = 20) async throws -> PaginatedResponse<WalletTransaction> {
        try await creditClient.fetchTransactionHistory(userHash: userHash, page: page, limit: limit)
    }
}
