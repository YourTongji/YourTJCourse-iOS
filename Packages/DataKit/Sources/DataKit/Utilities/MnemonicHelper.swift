import Foundation
import CryptoKit
import Security

public enum MnemonicError: Error, Sendable, LocalizedError {
    case entropyUnavailable(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .entropyUnavailable(let status):
            "安全随机数生成失败 (OSStatus: \(status))"
        }
    }
}

public enum MnemonicHelper: Sendable {
    /// Generates a random 12-word BIP39 mnemonic phrase.
    ///
    /// Uses 128 bits of entropy (`SecRandomCopyBytes`).
    /// This is a simplified implementation; for production use
    /// a dedicated BIP39 library with proper checksum validation.
    public static func generate() throws -> [String] {
        var entropy = [UInt8](repeating: 0, count: 16) // 128 bits
        let status = SecRandomCopyBytes(kSecRandomDefault, entropy.count, &entropy)
        guard status == errSecSuccess else {
            throw MnemonicError.entropyUnavailable(status)
        }

        // Append checksum: first (entropyBits / 32) bits of SHA-256
        let hash = Data(SHA256.hash(data: Data(entropy)))
        let checksumBits = entropy.count * 8 / 32 // = 4 for 128-bit

        // Combine entropy + checksum into a bit array
        var bits: [Bool] = []
        for byte in entropy {
            for bit in 0..<8 {
                bits.append((byte >> (7 - bit)) & 1 == 1)
            }
        }
        for i in 0..<checksumBits {
            bits.append((hash[i / 8] >> (7 - (i % 8))) & 1 == 1)
        }

        // Split into 11-bit indices and map to words
        let words = BIP39Wordlist.english
        var mnemonic: [String] = []
        for i in stride(from: 0, to: bits.count, by: 11) {
            var index = 0
            for j in 0..<11 where i + j < bits.count {
                if bits[i + j] {
                    index |= 1 << (10 - j)
                }
            }
            mnemonic.append(words[index])
        }

        return mnemonic
    }

    /// Derives wallet identifiers from a mnemonic phrase.
    ///
    /// - `userHash`: Hex-encoded SHA-256 of the space-joined mnemonic.
    /// - `userSecret`: First 64 hex characters of the SHA-512 digest.
    public static func deriveWallet(from mnemonic: [String]) -> (userHash: String, userSecret: String) {
        let phrase = mnemonic.joined(separator: " ")
        let phraseData = Data(phrase.utf8)

        let hash = SHA256.hash(data: phraseData)
        let userHash = hash.map { String(format: "%02x", $0) }.joined()

        let hash512 = SHA512.hash(data: phraseData)
        let userSecret = hash512.map { String(format: "%02x", $0) }.joined().prefix(64).string

        return (userHash, userSecret)
    }

    /// Validates that a phrase contains exactly 12 known BIP39 words.
    public static func validate(_ phrase: String) -> Bool {
        let words = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard words.count == 12 else { return false }

        let wordSet = Set(BIP39Wordlist.english)
        return words.allSatisfy { wordSet.contains($0) }
    }
}

// MARK: - Substring helper

private extension String.SubSequence {
    var string: String { String(self) }
}
