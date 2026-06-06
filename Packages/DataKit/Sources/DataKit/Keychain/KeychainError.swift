import Foundation

public enum KeychainError: Error, Sendable, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case unexpectedData

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "密钥保存失败 (OSStatus: \(status))"
        case .readFailed(let status):
            "密钥读取失败 (OSStatus: \(status))"
        case .deleteFailed(let status):
            "密钥删除失败 (OSStatus: \(status))"
        case .itemNotFound:
            "密钥未找到"
        case .unexpectedData:
            "密钥数据格式异常"
        }
    }
}
