import Foundation

public enum ReportReason: String, Codable, CaseIterable, Sendable {
    case spam
    case harassment
    case misinformation
    case other
}
