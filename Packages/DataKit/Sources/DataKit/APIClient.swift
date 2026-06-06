import Foundation
import os

public final class APIClient: Sendable {
    public static let shared = APIClient()

    private let session: URLSession
    private let config: APIConfig
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger: Logger

    private init() {
        self.config = .default

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,   // 20 MB
            diskCapacity: 100 * 1024 * 1024,     // 100 MB
            diskPath: "com.yourtj.course.apicache"
        )
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.logger = Logger(subsystem: "com.yourtj.course", category: "APIClient")
    }

    // MARK: - Public Typed Methods

    public func get<T: Decodable & Sendable>(
        _ path: String,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await getData(path, query: items)
        return try decode(data, for: path)
    }

    public func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await postData(path, body: body, query: items)
        return try decode(data, for: path)
    }

    public func patch<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await patchData(path, body: body, query: items)
        return try decode(data, for: path)
    }

    public func put<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await putData(path, body: body, query: items)
        return try decode(data, for: path)
    }

    public func delete<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await deleteData(path, body: body, query: items)
        return try decode(data, for: path)
    }

    // MARK: - Raw Data Methods

    public func getData(
        _ path: String,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: "GET",
            query: items
        )
    }

    public func postData<B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: "POST",
            body: body,
            query: items
        )
    }

    public func patchData<B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: "PATCH",
            body: body,
            query: items
        )
    }

    public func putData<B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: "PUT",
            body: body,
            query: items
        )
    }

    public func deleteData<B: Encodable & Sendable>(
        _ path: String,
        body: B,
        query items: [URLQueryItem] = []
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: "DELETE",
            body: body,
            query: items
        )
    }

    // MARK: - Internal Request Building

    /// Performs a request with an optional JSON-encoded body.
    private func performRequest(
        path: String,
        method: String,
        body: (any Encodable & Sendable)? = nil,
        query items: [URLQueryItem]
    ) async throws -> Data {
        guard var components = URLComponents(string: config.apiBase + path) else {
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
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw APIError.decodingError(error)
            }
        }

        logger.debug("[\(method)] \(url.absoluteString)")

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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        logger.debug("\(method) \(url.absoluteString) → \(httpResponse.statusCode) (\(data.count) bytes)")

        try validate(statusCode: httpResponse.statusCode)
        return data
    }

    /// Performs a body-less request (GET, etc.). Routes to the main performRequest.
    private func performRequest(
        path: String,
        method: String,
        query items: [URLQueryItem]
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: method,
            body: nil as (any Encodable & Sendable)?,
            query: items
        )
    }

    /// Performs a request with a typed body. Routes to the main performRequest.
    private func performRequest<B: Encodable & Sendable>(
        path: String,
        method: String,
        body: B,
        query items: [URLQueryItem]
    ) async throws -> Data {
        try await performRequest(
            path: path,
            method: method,
            body: body as (any Encodable & Sendable)?,
            query: items
        )
    }

    // MARK: - Response Handling

    private func validate(statusCode: Int) throws {
        switch statusCode {
        case 200...299:
            return
        case 400:
            throw APIError.httpError(statusCode: statusCode, message: "请求参数错误")
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.captchaFailed
        case 404:
            throw APIError.notFound
        case 409:
            throw APIError.conflict
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(statusCode: statusCode, message: nil)
        }
    }

    private func decode<T: Decodable>(_ data: Data, for path: String) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding failed for \(path): \(error.localizedDescription)")
            if let body = String(data: data, encoding: .utf8) {
                logger.error("Response body: \(body.prefix(500))")
            }
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Type Erasure Helper

/// Erases the concrete Encodable type so we can pass heterogeneous bodies
/// through the same internal method.
private struct AnyEncodable: Encodable, Sendable {
    private let wrapped: any Encodable & Sendable

    init(_ wrapped: any Encodable & Sendable) {
        self.wrapped = wrapped
    }

    func encode(to encoder: any Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
