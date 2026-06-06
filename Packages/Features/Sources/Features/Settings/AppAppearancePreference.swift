import SwiftUI

public enum AppAppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public static let storageKey = "com.yourtj.course.appearancePreference"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "自动"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public static func resolve(_ rawValue: String) -> AppAppearancePreference {
        AppAppearancePreference(rawValue: rawValue) ?? .system
    }
}
