import Foundation
import DomainKit

/// Manages wallet lifecycle — generation, keychain persistence, and restoration.
///
/// WalletRepository handles local wallet operations using `MnemonicHelper` for
/// BIP39 mnemonic generation/derivation and `KeychainManager` for secure storage.
/// Calls to the Credit service API (balance, summary, registration) are intentionally
/// omitted from this layer and should be added via a dedicated `CreditClient` when
/// the Credit service integration is built out.
public struct WalletRepository: Sendable {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Wallet Generation

    /// Generates a new wallet with a random BIP39 mnemonic phrase.
    /// - Returns: A tuple containing the mnemonic words, user hash, and user secret.
    public func generateWallet() throws -> (mnemonic: [String], userHash: String, userSecret: String) {
        let mnemonic = try MnemonicHelper.generate()
        let (hash, secret) = MnemonicHelper.deriveWallet(from: mnemonic)
        return (mnemonic, hash, secret)
    }

    /// Restores wallet credentials from an existing mnemonic phrase.
    /// - Parameter mnemonic: The 12-word BIP39 mnemonic array.
    /// - Returns: A tuple of `(userHash, userSecret)` if valid, or `nil` if the mnemonic
    ///   fails validation.
    public func restoreWallet(from mnemonic: [String]) -> (userHash: String, userSecret: String)? {
        guard MnemonicHelper.validate(mnemonic.joined(separator: " ")) else { return nil }
        return MnemonicHelper.deriveWallet(from: mnemonic)
    }

    // MARK: - Keychain Persistence

    /// Persists wallet credentials to the secure Keychain.
    ///
    /// The mnemonic is stored with biometric protection; the hash and secret
    /// are stored without biometrics for programmatic access.
    /// - Parameters:
    ///   - mnemonic: The BIP39 mnemonic words.
    ///   - userHash: The wallet user hash.
    ///   - userSecret: The wallet user secret.
    public func saveWallet(mnemonic: [String], userHash: String, userSecret: String) throws {
        try KeychainManager.save(key: "wallet_mnemonic", value: mnemonic.joined(separator: " "), useBiometrics: true)
        try KeychainManager.save(key: "wallet_userHash", value: userHash)
        try KeychainManager.save(key: "wallet_userSecret", value: userSecret)
    }

    /// Loads wallet credentials from the Keychain.
    /// - Returns: A tuple of `(userHash, userSecret)` if available, or `nil` if no
    ///   wallet has been saved.
    public func loadWallet() -> (userHash: String, userSecret: String)? {
        guard
            let userHash = try? KeychainManager.read(key: "wallet_userHash"),
            let userSecret = try? KeychainManager.read(key: "wallet_userSecret"),
            !userHash.isEmpty,
            !userSecret.isEmpty
        else {
            return nil
        }
        return (userHash, userSecret)
    }

    /// Checks whether a wallet exists in the Keychain.
    public func hasWallet() -> Bool {
        (try? KeychainManager.read(key: "wallet_userHash")) != nil
    }

    /// Deletes all wallet credentials from the Keychain.
    public func deleteWallet() throws {
        try KeychainManager.delete(key: "wallet_mnemonic")
        try KeychainManager.delete(key: "wallet_userHash")
        try KeychainManager.delete(key: "wallet_userSecret")
    }
}
