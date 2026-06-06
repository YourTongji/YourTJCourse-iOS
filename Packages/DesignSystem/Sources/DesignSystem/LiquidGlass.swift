import SwiftUI

// MARK: - Glass Effect Modifier

/// Applies a cyan-tinted glass effect when running on iOS 26+,
/// falling back to `ultraThinMaterial` on iOS 18.
///
/// Respects accessibility transparency and contrast settings by
/// using an opaque background when needed.
@available(iOS 18, *)
public struct GlassEffectModifier: ViewModifier {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        if reduceTransparency || increaseContrast {
            // Opaque fallback: solid cyan-tinted background
            content
                .background(
                    AppColors.accessibleGlassTint(
                        reduceTransparency: reduceTransparency,
                        increaseContrast: increaseContrast
                    )
                )
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(.cyan).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    private var increaseContrast: Bool {
        colorSchemeContrast == .increased
    }
}

// MARK: - Glass Container

/// A view that groups children inside a shared glass backdrop using
/// `GlassEffectContainer` on iOS 26, or individual `ultraThinMaterial`
/// backgrounds per child on iOS 18.
@available(iOS 18, *)
public struct GlassContainer<Content: View>: View {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let spacing: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    public init(
        spacing: CGFloat = 8,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        if reduceTransparency || increaseContrast {
            // Opaque fallback
            VStack(spacing: spacing) {
                content
            }
            .padding()
            .background(
                AppColors.accessibleGlassTint(
                    reduceTransparency: reduceTransparency,
                    increaseContrast: increaseContrast
                )
            )
            .clipShape(.rect(cornerRadius: cornerRadius))
        } else if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            VStack(spacing: spacing) {
                content
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }

    private var increaseContrast: Bool {
        colorSchemeContrast == .increased
    }
}

// MARK: - View Extensions

@available(iOS 18, *)
extension View {

    /// Wraps this view in a cyan-tinted glass backdrop.
    /// Use on navigation / controls layer elements only
    /// (TabBar, Toolbar, search bar, FAB, sheet handles).
    public func glassContainer(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassEffectModifier(cornerRadius: cornerRadius))
    }

    /// Applies the standard content-card style: a solid background
    /// with soft shadow (no glass). Cards should never use glass.
    public func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }

    // NOTE: On iOS 26+, the native View.glassEffectID(_:in:) is
    // available directly. No wrapper needed.
}

// MARK: - Card Style Modifier

/// Solid-background card with soft shadow.
/// This is the standard container for content cards (courses, reviews, etc.).
@available(iOS 18, *)
public struct CardStyleModifier: ViewModifier {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        content
            .padding()
            .background(AppColors.accessibleCardBackground(reduceTransparency: reduceTransparency))
            .clipShape(.rect(cornerRadius: 16))
            .shadow(
                color: AppShadows.card.color,
                radius: AppShadows.card.radius,
                x: AppShadows.card.x,
                y: AppShadows.card.y
            )
    }
}

// MARK: - Glass Button Style

/// A button style mimicking the iOS 26 `.glass` and `.glassProminent` styles,
/// with a fallback for iOS 18.
@available(iOS 18, *)
public struct GlassButtonStyle: ButtonStyle {

    public enum Style {
        case regular
        case prominent
    }

    private let style: Style

    public init(style: Style = .regular) {
        self.style = style
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundStyle(style == .prominent ? .white : AppColors.cyan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(backgroundView(isPressed: configuration.isPressed))
            .clipShape(.rect(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.interactiveSpring, value: configuration.isPressed)
    }

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        if #available(iOS 26, *) {
            if style == .prominent {
                Color.cyan
                    .opacity(isPressed ? 0.8 : 1.0)
                    .glassEffect(.regular.tint(.cyan), in: .rect(cornerRadius: 14))
            } else {
                Color.clear
                    .glassEffect(.regular.tint(.cyan), in: .rect(cornerRadius: 14))
            }
        } else {
            if style == .prominent {
                Color.cyan
                    .opacity(isPressed ? 0.8 : 1.0)
            } else {
                Color.clear
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            }
        }
    }
}

@available(iOS 18, *)
extension ButtonStyle where Self == GlassButtonStyle {

    /// A glass-styled button with thin material background.
    public static var glass: GlassButtonStyle { GlassButtonStyle(style: .regular) }

    /// A prominent glass-styled button with solid cyan fill.
    public static var glassProminent: GlassButtonStyle { GlassButtonStyle(style: .prominent) }
}

// MARK: - Previews

#Preview("Glass Effect") {
    VStack(spacing: 16) {
        Text("Glass Container")
            .padding(40)
            .glassContainer(cornerRadius: 24)

        Text("Glass Button (regular)")
            .padding()
            .glassContainer(cornerRadius: 14)

        Button("Glass Prominent") {}
            .buttonStyle(.glassProminent)
            .padding(.horizontal)

        Button("Glass Regular") {}
            .buttonStyle(.glass)
            .padding(.horizontal)
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Card Style") {
    VStack(spacing: 12) {
        Text("Course Card")
            .font(AppTypography.headline)
        Text("This is a content card with solid background and soft shadow.")
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textSecondary)
    }
    .cardStyle()
    .padding()
    .background(AppColors.background)
}
