import Foundation
import Security
import LocalAuthentication

public enum KeychainManager: Sendable {
    private static let service = "com.yourtj.course.keychain"

    // MARK: - Public API

    /// Saves a value to the keychain.
    /// - Parameters:
    ///   - key: The account key to store under.
    ///   - value: The string value to store.
    ///   - useBiometrics: If true, require biometric authentication on read.
    public static func save(key: String, value: String, useBiometrics: Bool = false) throws {
        try delete(key: key)

        var attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        if useBiometrics {
            var cfError: Unmanaged<CFError>?
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &cfError
            )
            guard let accessControl else {
                let errorCode = cfError.map { CFErrorGetCode($0.takeRetainedValue()) } ?? -1
                throw KeychainError.saveFailed(OSStatus(errorCode))
            }
            attributes[kSecAttrAccessControl] = accessControl
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Reads a value from the keychain.
    /// - Parameter key: The account key to look up.
    /// - Returns: The stored string, or `nil` if the item does not exist.
    public static func read(key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        // If biometrics were used at save time, SecItemCopyMatching
        // automatically prompts for biometrics — we don't need an
        // explicit LAContext unless we want to customize the prompt.
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return String(data: data, encoding: .utf8)

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.readFailed(status)
        }
    }

    /// Deletes a single keychain entry.
    public static func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Removes **all** keychain entries for this service.
    public static func clearAll() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
