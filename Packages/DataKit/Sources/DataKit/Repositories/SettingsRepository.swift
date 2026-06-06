import Foundation
import DomainKit

/// Provides typed access to app runtime settings and configuration endpoints.
public struct SettingsRepository: Sendable {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    /// Fetches the current runtime state, including maintenance mode and announcements.
    /// - Returns: A `RuntimeState` with maintenance config and active announcements.
    public func getRuntimeState() async throws -> RuntimeState {
        try await client.get("/api/settings/runtime-state")
    }

    /// Fetches the list of academic departments.
    /// - Returns: An array of department name strings.
    public func getDepartments() async throws -> [String] {
        let response: DepartmentResponse = try await client.get("/api/departments")
        return response.departments
    }
}

private struct DepartmentResponse: Codable, Sendable {
    let departments: [String]
}
