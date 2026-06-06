import SwiftUI

// MARK: - LoadingView

/// A centered loading indicator with an optional message displayed below.
public struct LoadingView: View {

    private let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            if let message {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("LoadingView - With Message") {
    LoadingView(message: "加载中…")
}

#Preview("LoadingView - No Message") {
    LoadingView()
}
