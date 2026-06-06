import Foundation

public enum APIError: Error, Sendable, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case notFound
    case rateLimited
    case captchaFailed
    case unauthorized
    case conflict
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "无效的请求地址"
        case .invalidResponse: "服务器响应异常"
        case .httpError(let code, let message): message ?? "请求失败 (\(code))"
        case .decodingError: "数据解析失败"
        case .networkError: "网络连接失败，请检查网络"
        case .notFound: "内容不存在"
        case .rateLimited: "操作过于频繁，请稍后再试"
        case .captchaFailed: "人机验证失败，请重试"
        case .unauthorized: "没有操作权限"
        case .conflict: "冲突操作"
        case .unknown: "未知错误"
        }
    }
}
