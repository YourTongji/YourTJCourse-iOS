import SwiftUI

// MARK: - SemesterTag

/// A small, pill-shaped badge indicating a semester label.
///
/// Uses a cyan tint with reduced opacity, respecting
/// accessibility transparency settings.
public struct SemesterTag: View {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let label: String

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(AppTypography.smallLabel)
            .foregroundStyle(AppColors.cyanDark)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                reduceTransparency
                    ? AppColors.cyanLight
                    : AppColors.cyanLight.opacity(0.6)
            )
            .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("SemesterTag") {
    HStack(spacing: 6) {
        SemesterTag(label: "2024-2025-1")
        SemesterTag(label: "2023-2024-2")
        SemesterTag(label: "短学期")
    }
    .padding()
    .background(AppColors.background)
}
