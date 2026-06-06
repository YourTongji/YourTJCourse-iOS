import Foundation
import CryptoKit

public enum MnemonicError: Error, Sendable, LocalizedError {
    case invalidStudentId
    case invalidPin
    case invalidMnemonic
    case unknownMnemonicWord(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStudentId:
            "学号格式无效（应为 7-10 位数字）"
        case .invalidPin:
            "PIN 码长度必须在 6-32 位之间"
        case .invalidMnemonic:
            "助记词格式无效（应为 3 个词）"
        case .unknownMnemonicWord(let word):
            "词库中不存在词语：\(word)"
        }
    }
}

public enum MnemonicHelper: Sendable {
    private static let salt = "tongji-course-salt-2026"
    private static let iterations = 100_000
    private static let keyLength = 32

    public static func generate(studentId: String, pin: String) throws -> (mnemonic: String, userHash: String, userSecret: String) {
        let normalizedStudentId = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateStudentId(normalizedStudentId) else { throw MnemonicError.invalidStudentId }
        guard validatePin(pin) else { throw MnemonicError.invalidPin }

        let initialKey = pbkdf2(input: "\(normalizedStudentId):\(pin)")
        let mnemonic = mnemonic(from: initialKey, wordlist: CreditWordlist.words)
        return try restore(mnemonic: mnemonic)
    }

    public static func restore(mnemonic: String) throws -> (mnemonic: String, userHash: String, userSecret: String) {
        let normalized = normalize(mnemonic)
        guard validate(normalized) else { throw MnemonicError.invalidMnemonic }

        let words = normalized.components(separatedBy: "-")
        let wordlist = CreditWordlist.words
        for word in words where !wordlist.contains(word) {
            throw MnemonicError.unknownMnemonicWord(word)
        }

        let derivedKey = pbkdf2(input: normalized)
        let userHash = SHA256.hash(data: derivedKey).map { String(format: "%02x", $0) }.joined()
        let userSecret = derivedKey.base64EncodedString()
        return (normalized, userHash, userSecret)
    }

    public static func normalize(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: "-")
            .replacingOccurrences(of: ",", with: "-")
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-")))
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    public static func validate(_ phrase: String) -> Bool {
        let words = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
        return words.count == 3 && words.allSatisfy { !$0.isEmpty }
    }

    public static func validateStudentId(_ studentId: String) -> Bool {
        studentId.range(of: #"^\d{7,10}$"#, options: .regularExpression) != nil
    }

    public static func validatePin(_ pin: String) -> Bool {
        (6...32).contains(pin.count)
    }

    private static func mnemonic(from key: Data, wordlist: [String]) -> String {
        var words: [String] = []
        for index in 0..<3 {
            let offset = index * 2
            let value = (Int(key[offset]) << 8) | Int(key[offset + 1])
            words.append(wordlist[value % wordlist.count])
        }
        return words.joined(separator: "-")
    }

    private static func pbkdf2(input: String) -> Data {
        pbkdf2SHA256(
            password: Data(input.utf8),
            salt: Data(salt.utf8),
            iterations: iterations,
            keyByteCount: keyLength
        )
    }

    private static func pbkdf2SHA256(
        password: Data,
        salt: Data,
        iterations: Int,
        keyByteCount: Int
    ) -> Data {
        let key = SymmetricKey(data: password)
        let hashByteCount = SHA256.byteCount
        let blockCount = Int(ceil(Double(keyByteCount) / Double(hashByteCount)))
        var derived = Data()

        for blockIndex in 1...blockCount {
            var blockSalt = salt
            blockSalt.append(contentsOf: [
                UInt8((blockIndex >> 24) & 0xff),
                UInt8((blockIndex >> 16) & 0xff),
                UInt8((blockIndex >> 8) & 0xff),
                UInt8(blockIndex & 0xff),
            ])

            var u = Data(HMAC<SHA256>.authenticationCode(for: blockSalt, using: key))
            var output = u

            if iterations > 1 {
                for _ in 1..<iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for byteIndex in 0..<output.count {
                        output[byteIndex] ^= u[byteIndex]
                    }
                }
            }

            derived.append(output)
        }

        return derived.prefix(keyByteCount)
    }
}
