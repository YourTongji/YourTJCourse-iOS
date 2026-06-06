import Foundation
import DomainKit
import os

public struct CreditAPIClient: Sendable {
    public static let shared = CreditAPIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger: Logger

    public init(
        baseURL: String = APIConfig.default.creditApiBase,
        session: URLSession = .shared
    ) {
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        if normalized == "https://credit.yourtj.de" || normalized.hasPrefix("https://credit.yourtj.de/") {
            self.baseURL = "https://core.credit.yourtj.de"
        } else {
            self.baseURL = normalized
        }
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.logger = Logger(subsystem: "com.yourtj.course", category: "CreditAPIClient")
    }

    public func registerWallet(userHash: String, userSecret: String) async throws -> CreditWallet {
        try await post(
            "/api/wallet/register",
            body: RegisterWalletRequest(userHash: userHash, userSecret: userSecret)
        )
    }

    public func fetchWallet(userHash: String) async throws -> CreditWallet {
        try await get("/api/wallet/\(userHash.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userHash)")
    }

    public func fetchBalance(userHash: String) async throws -> WalletBalance {
        try await get("/api/wallet/\(userHash.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userHash)/balance")
    }

    public func fetchJCourseSummary(userHash: String, date: String? = nil) async throws -> WalletSummary {
        var items = [URLQueryItem(name: "userHash", value: userHash)]
        if let date {
            items.append(URLQueryItem(name: "date", value: date))
        }
        return try await get("/api/integration/jcourse/summary", query: items)
    }

    private func get<T: Decodable & Sendable>(
        _ path: String,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await request(path: path, method: "GET", query: items)
        return try decodeEnvelope(data, for: path)
    }

    private func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String,
        body: Body,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await request(path: path, method: "POST", body: body, query: items)
        return try decodeEnvelope(data, for: path)
    }

    private func request(
        path: String,
        method: String,
        body: (any Encodable & Sendable)? = nil,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        logger.debug("[\(method)] \(self.redactedURLForLogging(url))")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError
            where error.code == .notConnectedToInternet || error.code == .networkConnectionLost
        {
            throw APIError.networkError(error)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        logger.debug("\(method) \(self.redactedURLForLogging(url)) → \(http.statusCode) (\(data.count) bytes)")
        guard (200...299).contains(http.statusCode) else {
            throw decodeError(data, statusCode: http.statusCode)
        }
        return data
    }

    private func decodeEnvelope<T: Decodable>(_ data: Data, for path: String) throws -> T {
        do {
            let response = try decoder.decode(CreditAPIResponse<T>.self, from: data)
            if response.success, let data = response.data {
                return data
            }
            throw APIError.httpError(statusCode: 200, message: response.error ?? response.message)
        } catch let error as APIError {
            throw error
        } catch {
            logger.error("Credit decoding failed for \(path): \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    private func decodeError(_ data: Data, statusCode: Int) -> APIError {
        if let response = try? decoder.decode(CreditAPIResponse<EmptyData>.self, from: data) {
            return APIError.httpError(statusCode: statusCode, message: response.error ?? response.message)
        }
        return APIError.httpError(statusCode: statusCode, message: nil)
    }

    private func redactedURLForLogging(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path
        }
        if components.query != nil {
            components.percentEncodedQuery = "redacted"
        }
        return components.string ?? url.path
    }
}

private struct CreditAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

private struct RegisterWalletRequest: Encodable, Sendable {
    let userHash: String
    let userSecret: String
}

private struct EmptyData: Decodable {}

private struct AnyEncodable: Encodable, Sendable {
    private let wrapped: any Encodable & Sendable

    init(_ wrapped: any Encodable & Sendable) {
        self.wrapped = wrapped
    }

    func encode(to encoder: any Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
