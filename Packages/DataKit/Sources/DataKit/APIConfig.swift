import Foundation

public struct APIConfig: Sendable {
    public let apiBase: String
    public let creditApiBase: String
    public let clientId: String

    public static let `default` = APIConfig(
        apiBase: Self.value(for: "API_BASE") ?? "https://jcourse.yourtj.de",
        creditApiBase: Self.value(for: "CREDIT_API_BASE") ?? "https://core.credit.yourtj.de",
        clientId: Self.loadOrCreateClientId()
    )

    private static func value(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static func loadOrCreateClientId() -> String {
        let key = "com.yourtj.course.clientId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
