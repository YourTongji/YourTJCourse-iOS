import SwiftUI

public struct AppActionButtonLabel: View {
    private let title: String
    private let systemImage: String?
    private let isLoading: Bool

    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack(spacing: 7) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

public struct AppActionButtonStyle: ButtonStyle {
    public enum Role {
        case primary
        case secondary
        case destructive
    }

    public enum Size {
        case regular
        case compact
    }

    @Environment(\.isEnabled) private var isEnabled

    private let role: Role
    private let size: Size
    private let fillsWidth: Bool

    public init(
        role: Role = .primary,
        size: Size = .regular,
        fillsWidth: Bool = true
    ) {
        self.role = role
        self.size = size
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foregroundColor)
            .tint(foregroundColor)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: role == .primary ? 0 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var font: Font {
        switch size {
        case .regular:
            .subheadline.weight(.semibold)
        case .compact:
            .caption.weight(.semibold)
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .regular: 36
        case .compact: 28
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: 12
        case .compact: 9
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: 7
        case .compact: 4
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .regular: 10
        case .compact: 8
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return AppColors.textSecondary }

        switch role {
        case .primary:
            return .white
        case .secondary:
            return AppColors.cyan
        case .destructive:
            return AppColors.negative
        }
    }

    private var backgroundColor: Color {
        guard isEnabled else { return Color.secondary.opacity(0.12) }

        switch role {
        case .primary:
            return AppColors.cyan
        case .secondary:
            return AppColors.cyan.opacity(0.08)
        case .destructive:
            return AppColors.negative.opacity(0.08)
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return Color.secondary.opacity(0.18) }

        switch role {
        case .primary:
            return .clear
        case .secondary:
            return AppColors.cyan.opacity(0.35)
        case .destructive:
            return AppColors.negative.opacity(0.35)
        }
    }
}

public extension ButtonStyle where Self == AppActionButtonStyle {
    static var appPrimaryAction: AppActionButtonStyle {
        AppActionButtonStyle(role: .primary)
    }

    static var appSecondaryAction: AppActionButtonStyle {
        AppActionButtonStyle(role: .secondary)
    }

    static var appDestructiveAction: AppActionButtonStyle {
        AppActionButtonStyle(role: .destructive)
    }
}

#Preview("App Action Buttons") {
    VStack(spacing: 12) {
        Button {} label: {
            AppActionButtonLabel("主要操作", systemImage: "checkmark")
        }
        .buttonStyle(.appPrimaryAction)

        Button {} label: {
            AppActionButtonLabel("次要操作", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.appSecondaryAction)

        Button {} label: {
            AppActionButtonLabel("紧凑操作", systemImage: "plus")
        }
        .buttonStyle(AppActionButtonStyle(role: .secondary, size: .compact, fillsWidth: false))
    }
    .padding()
    .background(AppColors.background)
}
