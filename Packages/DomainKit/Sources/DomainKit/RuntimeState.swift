import Foundation

public struct RuntimeState: Codable, Sendable {
    public let maintenance: MaintenanceState
    public let announcements: [Announcement]

    public init(maintenance: MaintenanceState, announcements: [Announcement]) {
        self.maintenance = maintenance
        self.announcements = announcements
    }
}

public struct MaintenanceState: Codable, Sendable {
    public let enabled: Bool
    public let config: MaintenanceConfig?

    public init(enabled: Bool, config: MaintenanceConfig? = nil) {
        self.enabled = enabled
        self.config = config
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case config
    }
}

public struct MaintenanceConfig: Codable, Equatable, Sendable {
    public let title: String?
    public let message: String?
    public let estimatedDowntime: String?

    public init(title: String? = nil, message: String? = nil, estimatedDowntime: String? = nil) {
        self.title = title
        self.message = message
        self.estimatedDowntime = estimatedDowntime
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case message
        case estimatedDowntime = "estimated_downtime"
    }
}

public struct Announcement: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let content: String
    public let createdAt: String?

    public init(id: String, title: String, content: String, createdAt: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case createdAt = "created_at"
    }
}
