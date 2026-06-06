import Foundation

public struct RuntimeState: Codable, Sendable {
    public let maintenance: MaintenanceState
    public let announcements: [Announcement]
    public let updatedAt: Int64?

    public init(maintenance: MaintenanceState, announcements: [Announcement], updatedAt: Int64? = nil) {
        self.maintenance = maintenance
        self.announcements = announcements
        self.updatedAt = updatedAt
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
    public let progress: [MaintenanceProgressStep]
    public let lastUpdated: String?

    public init(
        title: String? = nil,
        message: String? = nil,
        estimatedDowntime: String? = nil,
        progress: [MaintenanceProgressStep] = [],
        lastUpdated: String? = nil
    ) {
        self.title = title
        self.message = message
        self.estimatedDowntime = estimatedDowntime
        self.progress = progress
        self.lastUpdated = lastUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case message
        case eta
        case estimatedDowntime = "estimated_downtime"
        case progress
        case lastUpdated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        estimatedDowntime = try container.decodeIfPresent(String.self, forKey: .estimatedDowntime)
            ?? container.decodeIfPresent(String.self, forKey: .eta)
        progress = try container.decodeIfPresent([MaintenanceProgressStep].self, forKey: .progress) ?? []
        lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(estimatedDowntime, forKey: .estimatedDowntime)
        if !progress.isEmpty {
            try container.encode(progress, forKey: .progress)
        }
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
    }
}

public struct MaintenanceProgressStep: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let done: Bool
    public let active: Bool

    public init(id: String, label: String, done: Bool, active: Bool) {
        self.id = id
        self.label = label
        self.done = done
        self.active = active
    }
}

public struct Announcement: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let title: String
    public let content: String
    public let enabled: Bool
    public let createdAt: String?

    public init(
        id: String,
        title: String? = nil,
        type: String = "info",
        content: String,
        enabled: Bool = true,
        createdAt: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title ?? Announcement.defaultTitle(for: type)
        self.content = content
        self.enabled = enabled
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case content
        case enabled
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "info"
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? Announcement.defaultTitle(for: type)
        content = try container.decode(String.self, forKey: .content)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    private static func defaultTitle(for type: String) -> String {
        switch type {
        case "success":
            "更新"
        case "warning":
            "提醒"
        case "error":
            "重要通知"
        default:
            "通知"
        }
    }
}
