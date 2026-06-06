import SwiftUI

// MARK: - App Colors

/// Centralized design tokens for the YOURTJ Liquid Glass theme.
/// Brand color is cyan, matching the web frontend.
public enum AppColors {

    // MARK: Brand

    /// Primary brand cyan — the main accent color across the app.
    public static let cyan = Color.cyan

    /// Darkened cyan for pressed states, borders, or high-contrast text.
    public static let cyanDark = Color(red: 0.0, green: 0.5, blue: 0.6)

    /// Lighter cyan for backgrounds, tinted containers, or subtle highlights.
    public static let cyanLight = Color(red: 0.8, green: 0.96, blue: 1.0)

    // MARK: Backgrounds

    /// Main app background.
    public static let background: Color = {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #else
        Color.gray.opacity(0.1)
        #endif
    }()

    /// Card / surface background — solid, never glass.
    public static let cardBackground: Color = {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #else
        Color.gray.opacity(0.15)
        #endif
    }()

    // MARK: Text

    /// Primary text color.
    public static let textPrimary: Color = {
        #if canImport(UIKit)
        Color(.label)
        #else
        Color.primary
        #endif
    }()

    /// Secondary / subtitle text color.
    public static let textSecondary: Color = {
        #if canImport(UIKit)
        Color(.secondaryLabel)
        #else
        Color.secondary
        #endif
    }()

    // MARK: Semantic

    /// Semantic accent (alias for brand cyan in most contexts).
    public static let accent = cyan

    /// Positive / success color.
    public static let positive = Color.green

    /// Negative / destructive color.
    public static let negative = Color.red

    // MARK: Glass

    /// Tint applied to glass material layers.
    public static let glassTint = Color.cyan.opacity(0.15)

    // MARK: Accessibility Helpers

    /// Returns a high-contrast variant of the brand cyan when
    /// `reduceTransparency` or `increaseContrast` is active.
    /// - Parameter reduceTransparency: Whether the user prefers reduced transparency.
    /// - Parameter increaseContrast: Whether the user wants increased contrast.
    /// - Returns: An opaque, high-contrast color when appropriate.
    @MainActor
    public static func accessibleCyan(
        reduceTransparency: Bool,
        increaseContrast: Bool
    ) -> Color {
        if reduceTransparency || increaseContrast {
            return Color(red: 0.0, green: 0.55, blue: 0.7)
        }
        return cyan
    }

    /// Returns an accessible card background when transparency is reduced.
    @MainActor
    public static func accessibleCardBackground(reduceTransparency: Bool) -> Color {
        if reduceTransparency {
            #if canImport(UIKit)
            return Color(.systemBackground)
            #else
            return Color.clear
            #endif
        }
        return cardBackground
    }

    /// Returns an accessible glass tint when transparency is reduced or contrast is increased.
    @MainActor
    public static func accessibleGlassTint(
        reduceTransparency: Bool,
        increaseContrast: Bool
    ) -> Color {
        if reduceTransparency || increaseContrast {
            return AppColors.cyan.opacity(0.35)
        }
        return glassTint
    }
}

// MARK: - App Typography

/// Typography tokens for the YOURTJ app.
/// Uses the standard SF Pro font family provided by SwiftUI.
public enum AppTypography {

    /// Large screen title.
    public static let largeTitle = Font.largeTitle.weight(.bold)

    /// Section title.
    public static let title = Font.title.weight(.semibold)

    /// Subtitle / card title.
    public static let headline = Font.headline.weight(.semibold)

    /// Body text.
    public static let body = Font.body

    /// Secondary / caption text.
    public static let caption = Font.caption.weight(.medium)

    /// Small label text (tags, badges).
    public static let smallLabel: Font = {
        #if canImport(UIKit)
        Font.caption2.weight(.medium)
        #else
        Font.caption.weight(.medium)
        #endif
    }()
}

// MARK: - App Shadows

/// Shadow presets for the YOURTJ app.
public enum AppShadows {

    /// Soft shadow for content cards.
    public static let card: Shadow = .init(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

    /// Slightly stronger shadow for elevated elements.
    public static let elevated: Shadow = .init(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)

    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }
}
